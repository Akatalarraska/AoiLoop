import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/data/notification_scheduler.dart';
import '../../../shared/models/cycle_status.dart';
import '../../consumables/data/consumable_instance_repository.dart';
import '../../incidents/data/incident_repository.dart';
import '../../incidents/domain/incident_report.dart';
import '../domain/cycle_schedule.dart';
import 'change_event_repository.dart';

/// What one registered change did.
///
/// Returned rather than discarded so a caller can tell the user what happened
/// — "your sensor ran its full ten days" reads differently from "you replaced
/// it four days early", and both are in here.
@immutable
class CycleTransition {
  const CycleTransition({
    required this.closed,
    required this.opened,
    required this.event,
    required this.schedule,
  });

  /// The instance that came off. Null for the first change of a type, when
  /// there was nothing in use to close.
  final ConsumableInstance? closed;

  /// The instance now in use.
  final ConsumableInstance opened;

  /// The row linking the two.
  final ChangeEvent event;

  /// The dates the new cycle was opened with, including the offer that was
  /// on the table.
  final CycleSchedule schedule;

  /// Whether this replaced something rather than starting from nothing.
  bool get replacedSomething => closed != null;
}

/// What one reported incident did.
///
/// The incident row is the only part that always exists. Whether anything came
/// off, and whether anything went on in its place, is the user's answer to
/// [IncidentOutcome] — so both are nullable here rather than being implied.
@immutable
class IncidentRecord {
  const IncidentRecord({
    required this.incident,
    required this.failed,
    this.replacement,
    this.event,
    this.schedule,
  });

  /// The row recording what went wrong.
  final Incident incident;

  /// The instance the incident is about, as it was *before* the write. Read it
  /// for what failed, not for its current status.
  final ConsumableInstance failed;

  /// What went on instead, when the user replaced it there and then.
  final ConsumableInstance? replacement;

  /// The change linking the two. Written only alongside a [replacement]:
  /// nothing was installed otherwise, and a change event has to point at
  /// something that was.
  final ChangeEvent? event;

  /// The dates the replacement cycle was opened with.
  final CycleSchedule? schedule;

  /// Whether the user is now wearing something again.
  bool get wasReplaced => replacement != null;
}

/// Closes one cycle and opens the next, in a single transaction.
///
/// This is the only thing in BlauLoop allowed to write a change. The dashboard
/// reads the rows it produces and needs no telling: `watchActive` is a Drift
/// stream, so closing one instance and opening another refreshes Home on its
/// own.
///
/// It lives in `data/` rather than `domain/` for the same reason
/// `OnboardingService` does — it orchestrates repositories inside a
/// transaction. The arithmetic it applies is pure and lives next door in
/// [CycleSchedule], which is where the dates are actually tested.
class CycleEngine {
  const CycleEngine({
    required this.db,
    required this.instances,
    required this.changes,
    required this.incidents,
    this.reminders,
    this.thresholds = CycleStatusThresholds.defaults,
  });

  final AppDatabase db;
  final ConsumableInstanceRepository instances;
  final ChangeEventRepository changes;

  /// Where a failure gets written down.
  ///
  /// Reporting one is a cycle transition with a reason attached, so it belongs
  /// to the same transaction and the same on-time rule as an ordinary change.
  /// Giving incidents their own engine would mean a second copy of
  /// [_wasOnTime], and two copies of that rule is how the app ends up
  /// contradicting itself in writing.
  final IncidentRepository incidents;

  /// Rebuilds the reminders after a change. Null where notifications are not
  /// wired up, which is every test that is only interested in the rows.
  ///
  /// The old cycle's reminders are no longer true the moment it is closed, and
  /// firing them would tell someone to do a thing they have already done.
  final NotificationScheduler? reminders;

  /// Shared with the dashboard, so that what Home *called* due soon is what
  /// the history *records* as an on-time change. Two boundaries would drift
  /// apart and the app would contradict itself in writing.
  final CycleStatusThresholds thresholds;

  /// The dates a change registered now would produce, without writing
  /// anything.
  ///
  /// The register-change sheet shows the user their next deadline before they
  /// commit to it, which means computing it twice: once for the preview and
  /// once for the write. Both go through here, so the date on the button is
  /// the date in the database.
  ///
  /// [profileMinuteOfDay] is the profile-wide preference. It is the fallback,
  /// not the answer: [_preferredMinuteOf] gives the type its own time first.
  CycleSchedule preview({
    required ConsumableType type,
    required DateTime changedAt,
    int? profileMinuteOfDay,
  }) {
    return CycleSchedule.forInstall(
      installedAt: changedAt,
      duration: _durationOf(type),
      preferredMinuteOfDay: _preferredMinuteOf(type, profileMinuteOfDay),
    );
  }

  /// Whether replacing [current] at [changedAt] would go into the history as
  /// an early removal.
  ///
  /// Exists so the register-change sheet can ask *why* at the moment the
  /// answer is cheap, without keeping its own copy of the boundary. A second
  /// copy would drift, and then the sheet would ask for a reason for a change
  /// the history went on to record as routine.
  ///
  /// Null, or an instance with no deadline, is never early: there was no date
  /// to miss.
  bool wouldBeEarly(ConsumableInstance? current, DateTime changedAt) {
    return current != null && !_wasOnTime(current, changedAt.toUtc());
  }

  /// Records that [type] was replaced at [changedAt].
  ///
  /// Closes whatever was in use, opens a new instance with the computed
  /// deadline, and writes the [ChangeEvent] that links them. All three in one
  /// transaction: a half-applied change would leave either two active
  /// instances of one type — which the partial unique index rejects outright
  /// — or none at all, and a dashboard that lost a countdown it was showing a
  /// second ago is worse than one that never had it.
  ///
  /// [usePreferredTime] is the user's answer to the offer in
  /// [CycleSchedule.preferredChangeAt]. It is ignored when there is no offer.
  ///
  /// Throws [ValidationFailure] if [changedAt] falls before the install it
  /// would be closing — a change cannot precede the thing it replaced.
  Future<CycleTransition> registerChange({
    required String userProfileId,
    required ConsumableType type,
    required DateTime changedAt,
    int? profileMinuteOfDay,
    bool usePreferredTime = false,
    String? notes,
  }) async {
    final CycleTransition transition = await _write(
      userProfileId: userProfileId,
      type: type,
      changedAt: changedAt,
      profileMinuteOfDay: profileMinuteOfDay,
      usePreferredTime: usePreferredTime,
      notes: notes,
    );

    // Outside the transaction on purpose. Rescheduling talks to the operating
    // system, and holding a database transaction open across a platform
    // channel is how a write ends up waiting on a permission dialog. It is
    // also allowed to fail: the change is recorded either way, because the log
    // is the product and the reminders are a courtesy on top of it.
    await reminders?.synchronize(userProfileId);

    return transition;
  }

  Future<CycleTransition> _write({
    required String userProfileId,
    required ConsumableType type,
    required DateTime changedAt,
    int? profileMinuteOfDay,
    bool usePreferredTime = false,
    String? notes,
  }) {
    final DateTime changed = changedAt.toUtc();

    return db.transaction(() async {
      final ConsumableInstance? previous = await instances.findActiveForType(
        userProfileId,
        type.id,
      );

      if (previous != null && changed.isBefore(previous.installedAt)) {
        throw const ValidationFailure('changedAt');
      }

      final CycleSchedule schedule = preview(
        type: type,
        changedAt: changed,
        profileMinuteOfDay: profileMinuteOfDay,
      );

      final bool onTime = _wasOnTime(previous, changed);

      if (previous != null) {
        await instances.close(
          previous.id,
          removedAt: changed,
          status: onTime
              ? ConsumableStatus.completed
              : ConsumableStatus.removedEarly,
        );
      }

      final ConsumableInstance opened = await instances.create(
        userProfileId: userProfileId,
        consumableTypeId: type.id,
        installedAt: changed,
        expectedChangeAt: schedule.changeAt(usePreferredTime: usePreferredTime),
        // Carried over so a site, a device or a pod keeps its association
        // across a routine change. Choosing a *different* site is the body
        // map's job, in Phase 7.
        deviceId: previous?.deviceId,
        bodySiteId: previous?.bodySiteId,
      );

      // The note goes on the change, not on the instance it opened. "Going
      // swimming" is a fact about the swap; hung on the new sensor it would
      // read as a remark about a consumable that has not done anything yet.
      final ChangeEvent event = await changes.create(
        userProfileId: userProfileId,
        consumableInstanceId: opened.id,
        previousConsumableInstanceId: previous?.id,
        changedAt: changed,
        type: onTime ? ChangeType.scheduled : ChangeType.early,
        previousBodySiteId: previous?.bodySiteId,
        newBodySiteId: opened.bodySiteId,
        notes: notes,
      );

      return CycleTransition(
        closed: previous,
        opened: opened,
        event: event,
        schedule: schedule,
      );
    });
  }

  /// Records that something went wrong with whatever is in use for [type].
  ///
  /// The incident row is always written. What happens to the cycle follows
  /// [IncidentReport.outcome]: nothing at all when the user is still wearing
  /// it, a closed instance when they took it off, and a closed instance plus
  /// a fresh one plus the [ChangeEvent] linking them when they replaced it.
  /// All of it in one transaction, for the reason [registerChange] gives.
  ///
  /// The failed instance is closed as *completed* rather than *removed early*
  /// when it had already run its course. A set that occluded on day three is
  /// an early removal; one that occluded an hour after its deadline is not,
  /// and recording it as one would put a mark in someone's history for a
  /// consumable that did its job.
  ///
  /// [replacedAt] is when the new one went on, for the case where a report is
  /// written up after the fact and the two moments are not the same. It
  /// defaults to [IncidentReport.occurredAt], which is what they are when a
  /// failure is dealt with as it happens.
  ///
  /// Throws [ValidationFailure] if nothing is in use for [type], if the
  /// incident predates the install it is about, or if the replacement predates
  /// the incident.
  Future<IncidentRecord> reportIncident({
    required String userProfileId,
    required ConsumableType type,
    required IncidentReport report,
    DateTime? replacedAt,
    int? profileMinuteOfDay,
    bool usePreferredTime = false,
  }) async {
    final IncidentRecord record = await _writeIncident(
      userProfileId: userProfileId,
      type: type,
      report: report.trimmed(),
      replacedAt: replacedAt,
      profileMinuteOfDay: profileMinuteOfDay,
      usePreferredTime: usePreferredTime,
    );

    // Only when the cycle actually moved. A user who logged an irritated site
    // and left the sensor on has the same deadline they had a second ago, and
    // rebuilding the whole reminder set to arrive at the same answer is a
    // platform round-trip spent for nothing.
    if (report.outcome.closesCycle) {
      await reminders?.synchronize(userProfileId);
    }

    return record;
  }

  Future<IncidentRecord> _writeIncident({
    required String userProfileId,
    required ConsumableType type,
    required IncidentReport report,
    DateTime? replacedAt,
    int? profileMinuteOfDay,
    bool usePreferredTime = false,
  }) {
    final DateTime occurred = report.occurredAt.toUtc();
    final DateTime replaced = (replacedAt ?? report.occurredAt).toUtc();

    return db.transaction(() async {
      final ConsumableInstance? failed = await instances.findActiveForType(
        userProfileId,
        type.id,
      );

      // Nothing to report a failure against. Reachable if the card the sheet
      // was opened from went stale — a change registered on another screen
      // between the tap and the save.
      if (failed == null) {
        throw const ValidationFailure('instance');
      }
      if (occurred.isBefore(failed.installedAt)) {
        throw const ValidationFailure('occurredAt');
      }
      if (replaced.isBefore(occurred)) {
        throw const ValidationFailure('replacedAt');
      }

      final Incident incident = await incidents.create(
        userProfileId: userProfileId,
        consumableInstanceId: failed.id,
        occurredAt: occurred,
        type: report.type,
        notes: report.notes,
      );

      if (!report.outcome.closesCycle) {
        return IncidentRecord(incident: incident, failed: failed);
      }

      await instances.close(
        failed.id,
        removedAt: occurred,
        status: _wasOnTime(failed, occurred)
            ? ConsumableStatus.completed
            : ConsumableStatus.removedEarly,
      );

      if (!report.outcome.opensCycle) {
        return IncidentRecord(incident: incident, failed: failed);
      }

      final CycleSchedule schedule = preview(
        type: type,
        changedAt: replaced,
        profileMinuteOfDay: profileMinuteOfDay,
      );

      final ConsumableInstance opened = await instances.create(
        userProfileId: userProfileId,
        consumableTypeId: type.id,
        installedAt: replaced,
        expectedChangeAt: schedule.changeAt(usePreferredTime: usePreferredTime),
        // Carried over for the same reason an ordinary change carries them:
        // the pump and the pod are still the same hardware. A site that just
        // reacted badly is a different matter, and choosing a new one is the
        // body map's job in Phase 7.
        deviceId: failed.deviceId,
        bodySiteId: failed.bodySiteId,
      );

      final ChangeEvent event = await changes.create(
        userProfileId: userProfileId,
        consumableInstanceId: opened.id,
        previousConsumableInstanceId: failed.id,
        changedAt: replaced,
        type: ChangeType.incident,
        previousBodySiteId: failed.bodySiteId,
        newBodySiteId: opened.bodySiteId,
        notes: report.notes,
      );

      return IncidentRecord(
        incident: incident,
        failed: failed,
        replacement: opened,
        event: event,
        schedule: schedule,
      );
    });
  }

  /// Whether replacing [previous] at [changedAt] counts as running its course.
  ///
  /// A change is on time from the moment the card says *due soon*. Someone
  /// who swaps a sensor the evening before it expires did not fail at
  /// anything, and recording that as an early removal would put a mark in
  /// their history for following the app's own prompt.
  ///
  /// The first change of a type, and any instance with no deadline, count as
  /// on time: there was no date to miss.
  bool _wasOnTime(ConsumableInstance? previous, DateTime changedAt) {
    final DateTime? due = previous?.expectedChangeAt;
    if (due == null) {
      return true;
    }
    return !changedAt.isBefore(due.subtract(thresholds.dueSoon));
  }

  /// The preferred change time that applies to [type]: its own if it has one,
  /// otherwise the profile's [profileMinuteOfDay].
  ///
  /// Null on the type means *inherit*, not *no preference* — that is the whole
  /// point of the column being nullable. So the two are not interchangeable
  /// and the order matters: a sensor told to land at 09:00 keeps 09:00 even
  /// though the profile says 20:00, and a type nobody singled out follows the
  /// profile wherever it moves.
  static int? _preferredMinuteOf(ConsumableType type, int? profileMinuteOfDay) {
    return type.preferredChangeMinuteOfDay ?? profileMinuteOfDay;
  }

  /// A type's expected life, or null when it is counted rather than timed.
  ///
  /// `tracksCycle` is checked as well as the duration: a user who turned the
  /// countdown off for a product still wants their changes logged, they just
  /// do not want to be told when the next one is due.
  static Duration? _durationOf(ConsumableType type) {
    final int? minutes = type.defaultDurationMinutes;
    if (!type.tracksCycle || minutes == null) {
      return null;
    }
    return Duration(minutes: minutes);
  }
}

final Provider<CycleEngine> cycleEngineProvider = Provider<CycleEngine>((
  Ref ref,
) {
  return CycleEngine(
    db: ref.watch(appDatabaseProvider),
    instances: ref.watch(consumableInstanceRepositoryProvider),
    changes: ref.watch(changeEventRepositoryProvider),
    incidents: ref.watch(incidentRepositoryProvider),
    reminders: ref.watch(notificationSchedulerProvider),
  );
});
