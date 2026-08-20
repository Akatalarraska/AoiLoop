import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/data/notification_scheduler.dart';
import '../../../shared/models/cycle_status.dart';
import '../../consumables/data/consumable_instance_repository.dart';
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
    this.reminders,
    this.thresholds = CycleStatusThresholds.defaults,
  });

  final AppDatabase db;
  final ConsumableInstanceRepository instances;
  final ChangeEventRepository changes;

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
  CycleSchedule preview({
    required ConsumableType type,
    required DateTime changedAt,
    int? preferredMinuteOfDay,
  }) {
    return CycleSchedule.forInstall(
      installedAt: changedAt,
      duration: _durationOf(type),
      preferredMinuteOfDay: preferredMinuteOfDay,
    );
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
    int? preferredMinuteOfDay,
    bool usePreferredTime = false,
    String? notes,
  }) async {
    final CycleTransition transition = await _write(
      userProfileId: userProfileId,
      type: type,
      changedAt: changedAt,
      preferredMinuteOfDay: preferredMinuteOfDay,
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
    int? preferredMinuteOfDay,
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
        preferredMinuteOfDay: preferredMinuteOfDay,
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
        notes: notes,
      );

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
    reminders: ref.watch(notificationSchedulerProvider),
  );
});
