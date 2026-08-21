import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/consumables/data/consumable_instance_repository.dart';
import '../../../features/consumables/data/consumable_type_repository.dart';
import '../../../features/inventory/data/inventory_repository.dart';
import '../../../features/settings/data/user_profile_repository.dart';
import '../../database/app_database.dart';
import '../../utils/clock.dart';
import '../domain/notification_gateway.dart';
import '../domain/reminder_plan.dart';
import 'local_notification_gateway.dart';
import 'notification_schedule_repository.dart';
import 'reminder_copy.dart';

/// What one synchronisation did.
///
/// Returned rather than discarded because "your reminders are set" and "the
/// OS refused four of them" are different things to be able to tell someone,
/// and only the caller knows whether this run is worth mentioning.
@immutable
class ReminderSync {
  const ReminderSync({
    required this.enabled,
    required this.scheduled,
    required this.refused,
    required this.beyondBudget,
  });

  /// Nothing was scheduled because the OS will not deliver anything.
  static const ReminderSync disabled = ReminderSync(
    enabled: false,
    scheduled: 0,
    refused: 0,
    beyondBudget: 0,
  );

  /// Whether the OS is currently willing to deliver notifications at all.
  final bool enabled;

  /// Reminders the platform accepted.
  final int scheduled;

  /// Reminders the platform refused. Recorded in the ledger as failed, so a
  /// user whose reminders stopped can be told rather than left guessing.
  final int refused;

  /// Reminders that did not fit the platform's pending budget.
  final int beyondBudget;

  bool get isEmpty => scheduled == 0 && refused == 0 && beyondBudget == 0;

  @override
  String toString() =>
      'ReminderSync(enabled: $enabled, scheduled: $scheduled, '
      'refused: $refused, beyondBudget: $beyondBudget)';
}

/// Keeps the operating system's pending notifications in step with what the
/// database says is due.
///
/// Rebuilds rather than patches. Every run cancels what it previously asked
/// for and schedules the whole set again, which costs nothing at this size —
/// the budget is 64 — and is the only approach that stays correct after the
/// things that actually happen to notifications: a permission revoked and
/// restored, a reinstall, a reboot, an OS that quietly dropped some.
///
/// It never throws. Reminders are a courtesy on top of a log; the log is the
/// product. A user who cannot be reminded still needs the change they just
/// made to be recorded.
class NotificationScheduler {
  const NotificationScheduler({
    required this.profiles,
    required this.types,
    required this.instances,
    required this.inventory,
    required this.ledger,
    required this.gateway,
    required this.clock,
  });

  final UserProfileRepository profiles;
  final ConsumableTypeRepository types;
  final ConsumableInstanceRepository instances;

  /// Where expiry dates live. Reminding somebody that a box goes off next
  /// month is the same job as reminding them a sensor is due tomorrow — a
  /// thing they would otherwise find out too late — so it is the same
  /// machinery, the same ledger and the same budget.
  final InventoryRepository inventory;

  final NotificationScheduleRepository ledger;
  final NotificationGateway gateway;
  final Clock clock;

  /// Rebuilds every reminder for [userProfileId].
  ///
  /// Called at startup, after a change is registered, and after the user
  /// grants permission — the three moments when what the OS holds and what
  /// the database says can have drifted apart.
  Future<ReminderSync> synchronize(String userProfileId) async {
    try {
      return await _synchronize(userProfileId);
    } on Object catch (error, stackTrace) {
      debugPrint('NotificationScheduler.synchronize failed: $error');
      assert(() {
        debugPrintStack(stackTrace: stackTrace, maxFrames: 6);
        return true;
      }());
      return ReminderSync.disabled;
    }
  }

  Future<ReminderSync> _synchronize(String userProfileId) async {
    final DateTime now = clock.nowUtc();

    // Anything whose moment has passed either fired or was dropped. The OS
    // gives no reliable delivery callback, so this is the only honest way to
    // stop those rows claiming a slot forever.
    await ledger.reconcilePastDue(userProfileId, now);

    await _withdrawPending(userProfileId);

    if (!await gateway.areEnabled()) {
      return ReminderSync.disabled;
    }

    final UserProfile? profile = await profiles.findById(userProfileId);
    if (profile == null) {
      return ReminderSync.disabled;
    }

    final List<_Reminder> wanted = await _plan(profile, now);
    const int budget = NotificationScheduleRepository.platformPendingLimit;
    final List<_Reminder> affordable = wanted.take(budget).toList();

    final ReminderCopy copy = await ReminderCopy.forLanguage(
      profile.languageCode,
    );

    int scheduled = 0;
    int refused = 0;

    for (int index = 0; index < affordable.length; index++) {
      final _Reminder reminder = affordable[index];

      // Platform ids are handed out fresh each run, from 1. Every pending
      // notification was just withdrawn, so nothing is left to collide with —
      // and if a cancel silently failed, reusing its id replaces the stale
      // reminder rather than leaving a duplicate. Self-healing beats unique.
      final int platformId = index + 1;

      final bool accepted = await gateway.schedule(
        PendingNotification(
          platformId: platformId,
          kind: reminder.moment.kind,
          at: reminder.moment.at,
          title: copy.title(reminder.moment.kind, reminder.typeName),
          body: copy.body(reminder.moment.kind, reminder.dueAt),
          payload: reminder.instanceId,
        ),
      );

      await ledger.create(
        userProfileId: userProfileId,
        type: reminder.moment.kind,
        scheduledAt: reminder.moment.at,
        platformNotificationId: platformId,
        consumableInstanceId: reminder.instanceId,
        status: accepted
            ? NotificationStatus.pending
            : NotificationStatus.failed,
      );

      accepted ? scheduled++ : refused++;
    }

    return ReminderSync(
      enabled: true,
      scheduled: scheduled,
      refused: refused,
      beyondBudget: wanted.length - affordable.length,
    );
  }

  /// Withdraws every reminder this app previously asked the OS to hold.
  ///
  /// By stored platform id rather than `cancelAll`, so a notification BlauLoop
  /// did not schedule is never cancelled on its behalf.
  Future<void> _withdrawPending(String userProfileId) async {
    final List<NotificationSchedule> pending = await ledger.findPending(
      userProfileId,
    );
    for (final NotificationSchedule row in pending) {
      await gateway.cancel(row.platformNotificationId);
      await ledger.markStatus(row.id, NotificationStatus.cancelled);
    }
  }

  /// Every reminder worth holding, soonest first.
  ///
  /// Sorted before the budget is applied, so when there are more reminders
  /// than slots the ones that survive are the ones arriving first. Someone
  /// with ten consumables needs to hear about tomorrow, not about next month.
  Future<List<_Reminder>> _plan(UserProfile profile, DateTime now) async {
    final List<ConsumableInstance> active = await instances.findActive(
      profile.id,
    );

    final List<_Reminder> reminders = <_Reminder>[
      ...await _expiryReminders(profile, now),
    ];
    for (final ConsumableInstance instance in active) {
      final ConsumableType? type = await types.findById(
        instance.consumableTypeId,
      );
      if (type == null || !type.tracksCycle) {
        continue;
      }

      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: instance.expectedChangeAt,
        offsets: type.defaultReminderOffsets,
        now: now,
      );

      for (final ReminderMoment moment in plan.moments) {
        reminders.add(
          _Reminder(
            moment: moment,
            instanceId: instance.id,
            typeName: type.name,
            dueAt: instance.expectedChangeAt!,
          ),
        );
      }
    }

    reminders.sort((_Reminder a, _Reminder b) {
      final int byTime = a.moment.at.compareTo(b.moment.at);
      // A stable tiebreak, so two consumables due at the same instant do not
      // swap which of them survives the budget between runs.
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
    return reminders;
  }

  /// Warnings about stock going off.
  ///
  /// Grouped by consumable and date rather than emitted per batch. Somebody
  /// with four cartons that all expire on the same day wants one sentence, not
  /// four identical ones spending four slots of a budget of 64.
  ///
  /// Batches with nothing left in them are skipped: an empty row is a record
  /// of a box that is gone, and warning that it is about to go off would be
  /// warning about nothing.
  Future<List<_Reminder>> _expiryReminders(
    UserProfile profile,
    DateTime now,
  ) async {
    final List<InventoryItem> batches = await inventory.findExpiringBefore(
      profile.id,
      // Everything dated, however far out. A cutoff here would have to be
      // expressed in expiry dates while the thing worth bounding is *warning*
      // dates, and the two are a lead time apart: a 31 day cutoff silently
      // loses the thirty-day warning for a box going off in six weeks, which
      // is exactly the warning that box needs.
      //
      // Nothing is needed in its place. The budget is the limit, it is spent
      // soonest-first, and that is already the rule cycle reminders live by —
      // a change due tomorrow outranks a carton going off next year without
      // anything special being said about it.
      _endOfTime,
    );
    if (batches.isEmpty) {
      return const <_Reminder>[];
    }

    // One entry per consumable and date.
    final Map<String, InventoryItem> groups = <String, InventoryItem>{};
    for (final InventoryItem batch in batches) {
      final DateTime date = batch.expirationDate!.toUtc();
      groups.putIfAbsent(
        '${batch.consumableTypeId}@${date.year}-${date.month}-${date.day}',
        () => batch,
      );
    }

    final List<_Reminder> reminders = <_Reminder>[];
    for (final MapEntry<String, InventoryItem> entry in groups.entries) {
      final ConsumableType? type = await types.findById(
        entry.value.consumableTypeId,
      );
      if (type == null) {
        continue;
      }

      final ReminderPlan plan = ReminderPlan.forExpiry(
        expiresOn: entry.value.expirationDate,
        leadTimes: ReminderPlan.defaultExpiryLeadTimes,
        now: now,
      );

      for (final ReminderMoment moment in plan.moments) {
        reminders.add(
          _Reminder(
            moment: moment,
            // Not tied to an instance: this is about a box on a shelf, not
            // about anything anyone is wearing. The ledger column is nullable
            // for exactly this.
            instanceId: null,
            groupKey: entry.key,
            typeName: type.name,
            dueAt: entry.value.expirationDate!,
          ),
        );
      }
    }
    return reminders;
  }

  /// Far enough out to mean "every dated batch".
  ///
  /// `findExpiringBefore` wants a cutoff and there is no useful one to give
  /// it, so this stands in for its absence rather than pretending to be a
  /// policy.
  static final DateTime _endOfTime = DateTime.utc(9999);
}

/// One planned reminder, joined to what it is about.
@immutable
class _Reminder {
  const _Reminder({
    required this.moment,
    required this.instanceId,
    required this.typeName,
    required this.dueAt,
    this.groupKey,
  });

  final ReminderMoment moment;

  /// The instance this is about, or null for a warning about stock on a
  /// shelf rather than something being worn.
  final String? instanceId;

  final String typeName;

  /// Identity for a reminder that has no instance behind it.
  final String? groupKey;

  /// A stable tiebreak, whichever of the two this reminder came from. Without
  /// one, two reminders landing at the same instant could swap which of them
  /// survives the budget between runs.
  String get key => groupKey ?? instanceId ?? '';

  /// The deadline the reminder is warning about, as opposed to when the
  /// reminder itself fires.
  final DateTime dueAt;
}

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((Ref ref) {
      return NotificationScheduler(
        profiles: ref.watch(userProfileRepositoryProvider),
        types: ref.watch(consumableTypeRepositoryProvider),
        instances: ref.watch(consumableInstanceRepositoryProvider),
        inventory: ref.watch(inventoryRepositoryProvider),
        ledger: ref.watch(notificationScheduleRepositoryProvider),
        gateway: ref.watch(notificationGatewayProvider),
        clock: ref.watch(clockProvider),
      );
    });
