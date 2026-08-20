import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/consumables/data/consumable_instance_repository.dart';
import '../../../features/consumables/data/consumable_type_repository.dart';
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
    required this.ledger,
    required this.gateway,
    required this.clock,
  });

  final UserProfileRepository profiles;
  final ConsumableTypeRepository types;
  final ConsumableInstanceRepository instances;
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
  /// By stored platform id rather than `cancelAll`, so a notification AoiLoop
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
    if (active.isEmpty) {
      return const <_Reminder>[];
    }

    final List<_Reminder> reminders = <_Reminder>[];
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
      return byTime != 0 ? byTime : a.instanceId.compareTo(b.instanceId);
    });
    return reminders;
  }
}

/// One planned reminder, joined to what it is about.
@immutable
class _Reminder {
  const _Reminder({
    required this.moment,
    required this.instanceId,
    required this.typeName,
    required this.dueAt,
  });

  final ReminderMoment moment;
  final String instanceId;
  final String typeName;

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
        ledger: ref.watch(notificationScheduleRepositoryProvider),
        gateway: ref.watch(notificationGatewayProvider),
        clock: ref.watch(clockProvider),
      );
    });
