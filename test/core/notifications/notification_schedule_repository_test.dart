import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/notifications/data/notification_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The ledger exists because the platform cannot be trusted to remember.
/// These tests cover the reconciliation behaviour that depends on.
void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableInstance instance;
  int nextPlatformId = 1;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
    final ConsumableType sensor = await h.seedType(name: 'Sensor');
    instance = await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: h.clock.nowUtc(),
    );
    nextPlatformId = 1;
  });

  Future<NotificationSchedule> schedule({
    DateTime? at,
    NotificationKind kind = NotificationKind.cycleReminder,
    String? forInstance,
    bool linkToInstance = true,
  }) {
    return h.notifications.create(
      userProfileId: profile.id,
      type: kind,
      scheduledAt: at ?? DateTime.utc(2026, 8, 26, 9),
      platformNotificationId: nextPlatformId++,
      consumableInstanceId: linkToInstance
          ? (forInstance ?? instance.id)
          : null,
    );
  }

  test('records a pending reminder with its platform handle', () async {
    final NotificationSchedule row = await schedule();

    expect(row.status, NotificationStatus.pending);
    expect(row.platformNotificationId, 1);
    expect(row.consumableInstanceId, instance.id);
  });

  test('keeps the app id and the platform id separate', () async {
    // The app's identity is a UUID; the platform id is only a handle for
    // cancelling. An id-space collision on the OS side must not corrupt the
    // ledger.
    final NotificationSchedule row = await schedule();

    expect(row.id, hasLength(36));
    expect(row.platformNotificationId, isA<int>());
  });

  test('allows a notification not tied to any instance', () async {
    final NotificationSchedule row = await schedule(
      kind: NotificationKind.lowStock,
      linkToInstance: false,
    );

    expect(row.consumableInstanceId, isNull);
  });

  test('normalises the scheduled time to UTC', () async {
    final NotificationSchedule row = await h.notifications.create(
      userProfileId: profile.id,
      type: NotificationKind.cycleDue,
      scheduledAt: DateTime(2026, 8, 26, 11),
      platformNotificationId: 99,
    );

    expect(row.scheduledAt.isUtc, isTrue);
  });

  test('findPending lists soonest first', () async {
    await schedule(at: DateTime.utc(2026, 8, 26, 9));
    await schedule(at: DateTime.utc(2026, 8, 20, 9));

    final List<NotificationSchedule> pending = await h.notifications
        .findPending(profile.id);

    expect(pending.map((NotificationSchedule s) => s.scheduledAt), <DateTime>[
      DateTime.utc(2026, 8, 20, 9),
      DateTime.utc(2026, 8, 26, 9),
    ]);
  });

  group('cancelForInstance', () {
    test(
      'returns the platform ids that now need cancelling with the OS',
      () async {
        await schedule(at: DateTime.utc(2026, 8, 24));
        await schedule(at: DateTime.utc(2026, 8, 25));

        final List<int> toCancel = await h.notifications.cancelForInstance(
          instance.id,
        );

        expect(toCancel, <int>[1, 2]);
      },
    );

    test('marks them cancelled rather than deleting them', () async {
      await schedule();

      await h.notifications.cancelForInstance(instance.id);

      expect(await h.notifications.findPending(profile.id), isEmpty);
      final List<NotificationSchedule> all = await h.db
          .select(h.db.notificationSchedules)
          .get();
      expect(all.single.status, NotificationStatus.cancelled);
    });

    test('is a no-op when there is nothing pending', () async {
      expect(await h.notifications.cancelForInstance(instance.id), isEmpty);
    });

    test('leaves another instance reminders alone', () async {
      final ConsumableType other = await h.seedType(name: 'Set');
      final ConsumableInstance otherInstance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: other.id,
        installedAt: h.clock.nowUtc(),
      );
      await schedule();
      await schedule(forInstance: otherInstance.id);

      await h.notifications.cancelForInstance(instance.id);

      final List<NotificationSchedule> pending = await h.notifications
          .findPending(profile.id);
      expect(pending, hasLength(1));
      expect(pending.single.consumableInstanceId, otherInstance.id);
    });

    test('does not re-cancel something already cancelled', () async {
      await schedule();
      await h.notifications.cancelForInstance(instance.id);

      expect(await h.notifications.cancelForInstance(instance.id), isEmpty);
    });
  });

  group('reconcilePastDue', () {
    test('resolves reminders whose moment has passed', () async {
      // The OS gives no reliable delivery callback. Anything pending whose
      // moment has gone either fired or was dropped; either way it is not
      // pending any more.
      await schedule(at: DateTime.utc(2026, 8, 10));
      await schedule(at: DateTime.utc(2026, 9, 10));

      final int updated = await h.notifications.reconcilePastDue(
        profile.id,
        DateTime.utc(2026, 8, 17, 9),
      );

      expect(updated, 1);
      expect(await h.notifications.findPending(profile.id), hasLength(1));
    });

    test('leaves a reminder due exactly now alone', () async {
      await schedule(at: DateTime.utc(2026, 8, 17, 9));

      final int updated = await h.notifications.reconcilePastDue(
        profile.id,
        DateTime.utc(2026, 8, 17, 9),
      );

      expect(updated, 0);
    });

    test('does not touch already-cancelled rows', () async {
      await schedule(at: DateTime.utc(2026, 8, 10));
      await h.notifications.cancelForInstance(instance.id);

      await h.notifications.reconcilePastDue(
        profile.id,
        DateTime.utc(2026, 8, 17, 9),
      );

      final List<NotificationSchedule> all = await h.db
          .select(h.db.notificationSchedules)
          .get();
      expect(all.single.status, NotificationStatus.cancelled);
    });
  });

  group('platform budget', () {
    test('counts only pending notifications', () async {
      await schedule();
      await schedule();
      await h.notifications.cancelForInstance(instance.id);
      await schedule();

      expect(await h.notifications.countPending(profile.id), 1);
    });

    test('exposes the platform limit that scheduling has to respect', () async {
      // iOS caps an app at 64 pending notifications and silently drops the
      // rest. With five offsets per consumable that limit arrives sooner than
      // it looks, so the scheduler has to know about it.
      expect(NotificationScheduleRepository.platformPendingLimit, 64);
    });

    test('counting is scoped to one profile', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Lucas');
      await schedule();

      expect(await h.notifications.countPending(other.id), 0);
    });
  });

  group('purgeResolvedBefore', () {
    test('removes old resolved rows', () async {
      await schedule(at: DateTime.utc(2026, 1, 1));
      await h.notifications.cancelForInstance(instance.id);

      final int purged = await h.notifications.purgeResolvedBefore(
        DateTime.utc(2026, 6, 1),
      );

      expect(purged, 1);
      expect(await h.db.select(h.db.notificationSchedules).get(), isEmpty);
    });

    test('never removes something still pending', () async {
      await schedule(at: DateTime.utc(2026, 1, 1));

      final int purged = await h.notifications.purgeResolvedBefore(
        DateTime.utc(2026, 6, 1),
      );

      expect(purged, 0);
      expect(await h.notifications.findPending(profile.id), hasLength(1));
    });
  });

  test('cascades away with its instance', () async {
    await schedule();

    await (h.db.delete(
      h.db.consumableInstances,
    )..where(($ConsumableInstancesTable t) => t.id.equals(instance.id))).go();

    expect(await h.db.select(h.db.notificationSchedules).get(), isEmpty);
  });
}
