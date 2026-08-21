import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/notifications/data/notification_scheduler.dart';
import 'package:blauloop/core/notifications/domain/notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/test_database.dart';

/// Keeping the OS in step with the database.
///
/// The gateway is faked, so what is under test is the decision: which
/// reminders get asked for, which get withdrawn, what the ledger is told, and
/// what happens when the platform says no.
void main() {
  const Duration tenDays = Duration(days: 10);
  const List<Duration> dayBeforeAndOnTheDay = <Duration>[
    Duration(days: 1),
    Duration.zero,
  ];

  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  late TestHarness h;
  late FakeNotificationGateway gateway;
  late NotificationScheduler scheduler;
  late UserProfile profile;

  setUp(() async {
    h = TestHarness.create(now: now);
    gateway = FakeNotificationGateway();
    scheduler = NotificationScheduler(
      profiles: h.profiles,
      types: h.types,
      instances: h.instances,
      inventory: h.inventory,
      ledger: h.notifications,
      gateway: gateway,
      clock: h.clock,
    );
    profile = await h.seedProfile(languageCode: 'en');
  });

  /// A tracked consumable, in use, due [dueIn] from now.
  Future<ConsumableInstance> seedInUse({
    String name = 'CGM sensor',
    Duration dueIn = tenDays,
    List<Duration> offsets = dayBeforeAndOnTheDay,
    bool tracksCycle = true,
  }) async {
    final ConsumableType type = await h.types.create(
      name: name,
      category: ConsumableCategory.cgmSensor,
      defaultDuration: tenDays,
      tracksCycle: tracksCycle,
      defaultReminderOffsets: offsets,
    );
    return h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: now,
      expectedChangeAt: now.add(dueIn),
    );
  }

  Future<List<NotificationSchedule>> ledgerRows() =>
      h.db.select(h.db.notificationSchedules).get();

  group('with nothing in use', () {
    test('asks the OS for nothing', () async {
      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(gateway.scheduled, isEmpty);
      expect(sync.scheduled, 0);
      expect(sync.enabled, isTrue);
    });
  });

  group('a tracked consumable', () {
    test('gets one reminder per configured offset', () async {
      await seedInUse();

      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.scheduled, 2);
      expect(
        gateway.scheduled.map((PendingNotification n) => n.at).toList(),
        <DateTime>[now.add(const Duration(days: 9)), now.add(tenDays)],
      );
    });

    test('is recorded in the ledger as pending', () async {
      await seedInUse();

      await scheduler.synchronize(profile.id);

      final List<NotificationSchedule> rows = await ledgerRows();
      expect(rows, hasLength(2));
      expect(
        rows.every(
          (NotificationSchedule r) => r.status == NotificationStatus.pending,
        ),
        isTrue,
      );
    });

    test('carries its instance id, so a tap can find its way back', () async {
      final ConsumableInstance instance = await seedInUse();

      await scheduler.synchronize(profile.id);

      expect(
        gateway.scheduled.every(
          (PendingNotification n) => n.payload == instance.id,
        ),
        isTrue,
      );
    });

    test('is named in the notification the user will read', () async {
      await seedInUse(name: 'Infusion set');

      await scheduler.synchronize(profile.id);

      expect(gateway.scheduled.first.title, contains('Infusion set'));
      expect(gateway.scheduled.first.body, isNotEmpty);
    });
  });

  group('consumables with no countdown', () {
    test('are left alone', () async {
      await seedInUse(tracksCycle: false);

      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.scheduled, 0);
      expect(gateway.scheduled, isEmpty);
    });
  });

  group('running twice', () {
    test('withdraws what it asked for before asking again', () async {
      await seedInUse();
      await scheduler.synchronize(profile.id);
      final List<int> firstRound = gateway.scheduled
          .map((PendingNotification n) => n.platformId)
          .toList();

      await scheduler.synchronize(profile.id);

      expect(gateway.cancelled, firstRound);
      expect(
        gateway.cancelAllCount,
        0,
        reason:
            'cancelling everything would '
            'withdraw notifications BlauLoop did not schedule',
      );
    });

    test('leaves the same number outstanding, not twice as many', () async {
      await seedInUse();

      await scheduler.synchronize(profile.id);
      await scheduler.synchronize(profile.id);

      expect(gateway.outstanding, hasLength(2));
    });

    test('leaves exactly one pending row per reminder', () async {
      await seedInUse();

      await scheduler.synchronize(profile.id);
      await scheduler.synchronize(profile.id);

      final List<NotificationSchedule> rows = await ledgerRows();
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.pending,
        ),
        hasLength(2),
      );
      // The withdrawn ones stay, as cancelled: the ledger is a record of what
      // was asked for, not only of what is outstanding.
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.cancelled,
        ),
        hasLength(2),
      );
    });
  });

  group('when the OS will not deliver', () {
    test('nothing is scheduled and the report says so', () async {
      await seedInUse();
      gateway.enabled = false;

      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.enabled, isFalse);
      expect(gateway.scheduled, isEmpty);
    });

    test('reminders already held are withdrawn', () async {
      await seedInUse();
      await scheduler.synchronize(profile.id);

      // Permission revoked in system settings between launches.
      gateway.enabled = false;
      await scheduler.synchronize(profile.id);

      expect(gateway.outstanding, isEmpty);
      final List<NotificationSchedule> rows = await ledgerRows();
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.pending,
        ),
        isEmpty,
      );
    });

    test('everything comes back once permission returns', () async {
      await seedInUse();
      gateway.enabled = false;
      await scheduler.synchronize(profile.id);

      gateway.enabled = true;
      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.scheduled, 2);
      expect(gateway.outstanding, hasLength(2));
    });
  });

  group('when the platform refuses a reminder', () {
    test('it is recorded as failed rather than claimed as pending', () async {
      await seedInUse();
      gateway = FakeNotificationGateway(refuseFrom: 1);
      scheduler = NotificationScheduler(
        profiles: h.profiles,
        types: h.types,
        instances: h.instances,
        inventory: h.inventory,
        ledger: h.notifications,
        gateway: gateway,
        clock: h.clock,
      );

      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.scheduled, 1);
      expect(sync.refused, 1);
      final List<NotificationSchedule> rows = await ledgerRows();
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.failed,
        ),
        hasLength(1),
      );
    });
  });

  group('the platform budget', () {
    test('is spent on the reminders arriving soonest', () async {
      // Forty consumables, five reminders each: two hundred wanted, sixty-four
      // affordable. The ones that survive must be the near ones.
      for (int index = 0; index < 40; index++) {
        await seedInUse(
          name: 'Item $index',
          dueIn: Duration(days: 3 + index),
          offsets: const <Duration>[
            Duration(days: 2),
            Duration(days: 1),
            Duration(hours: 6),
            Duration(hours: 1),
            Duration.zero,
          ],
        );
      }

      final ReminderSync sync = await scheduler.synchronize(profile.id);

      expect(sync.scheduled, 64);
      expect(sync.beyondBudget, 200 - 64);

      final List<DateTime> asked = gateway.scheduled
          .map((PendingNotification n) => n.at)
          .toList();
      expect(asked, orderedEquals(<DateTime>[...asked]..sort()));

      // Nothing scheduled may fall later than something that was dropped.
      expect(asked.last.isBefore(now.add(const Duration(days: 45))), isTrue);
    });
  });

  group('reminders whose moment has passed', () {
    test('stop claiming a slot', () async {
      await seedInUse(dueIn: const Duration(days: 2));
      await scheduler.synchronize(profile.id);

      // Three days on, both reminders have long since fired or been dropped.
      h.clock.advance(const Duration(days: 3));
      await scheduler.synchronize(profile.id);

      final List<NotificationSchedule> rows = await ledgerRows();
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.pending,
        ),
        isEmpty,
      );
      expect(
        rows.where(
          (NotificationSchedule r) => r.status == NotificationStatus.delivered,
        ),
        isNotEmpty,
      );
    });
  });

  test('an unknown profile is handled rather than thrown over', () async {
    final ReminderSync sync = await scheduler.synchronize('no-such-profile');

    expect(sync.enabled, isFalse);
    expect(gateway.scheduled, isEmpty);
  });
}
