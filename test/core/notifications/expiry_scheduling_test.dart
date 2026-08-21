import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/notifications/data/notification_scheduler.dart';
import 'package:blauloop/core/notifications/domain/notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/test_database.dart';

/// Expiry reminders through the scheduler, against a fake gateway.
///
/// The moments themselves are pinned next door. What these add is the joining:
/// that stock reaches the same machinery, the same ledger and the same budget
/// as a cycle reminder, and that it says the right thing when it gets there.
void main() {
  late TestHarness h;
  late FakeNotificationGateway gateway;
  late NotificationScheduler scheduler;
  late UserProfile profile;
  late ConsumableType sensor;

  final DateTime now = DateTime.utc(2026, 8, 21, 9);

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
    sensor = await h.seedType(name: 'CGM sensor');
  });

  Future<InventoryItem> stock({
    required DateTime? expires,
    int quantity = 4,
    ConsumableType? type,
  }) {
    return h.inventory.createItem(
      userProfileId: profile.id,
      consumableTypeId: (type ?? sensor).id,
      quantity: quantity,
      expirationDate: expires,
    );
  }

  List<PendingNotification> expiryOnes() => gateway.scheduled
      .where(
        (PendingNotification n) =>
            n.kind == NotificationKind.expiringSoon ||
            n.kind == NotificationKind.expired,
      )
      .toList();

  group('what reaches the operating system', () {
    test(
      'a batch going off is warned about, then reported as expired',
      () async {
        await stock(expires: now.add(const Duration(days: 45)));

        await scheduler.synchronize(profile.id);

        expect(expiryOnes(), hasLength(3));
        expect(expiryOnes().last.kind, NotificationKind.expired);
      },
    );

    test('the copy names the consumable and carries the date', () async {
      await stock(expires: DateTime.utc(2026, 12, 1));

      await scheduler.synchronize(profile.id);

      final PendingNotification expired = expiryOnes().last;
      expect(expired.title, contains('CGM sensor'));
      // A date rather than a countdown: a notification sits in the shade until
      // somebody looks at it, and "in 7 days" is a lie by then.
      expect(expired.body, contains('Dec'));
      // A day and no hour. The box states a date and nothing finer.
      expect(expired.body, isNot(contains(':')));
    });

    test('lands in the ledger, so a rebuild can withdraw it', () async {
      await stock(expires: now.add(const Duration(days: 10)));

      await scheduler.synchronize(profile.id);

      final List<NotificationSchedule> rows = await h.notifications.findPending(
        profile.id,
      );
      expect(rows, isNotEmpty);
      // Not about anything anybody is wearing, so the instance link is null.
      expect(
        rows.every((NotificationSchedule r) => r.consumableInstanceId == null),
        isTrue,
      );
    });
  });

  group('what it leaves alone', () {
    test('a batch with no expiry date', () async {
      await stock(expires: null);

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), isEmpty);
    });

    test('an empty batch', () async {
      // The row records a box that is gone. Warning that it is about to go off
      // would be warning about nothing.
      await stock(expires: now.add(const Duration(days: 10)), quantity: 0);

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), isEmpty);
    });

    test('a date already behind the clock', () async {
      await stock(expires: now.subtract(const Duration(days: 5)));

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), isEmpty);
    });
  });

  group('how far ahead it plans', () {
    test('a box going off in six weeks still gets its earliest warning', () {
      // The bug a cutoff expressed in expiry dates causes: the batch itself is
      // beyond the window, but its thirty-day warning is a fortnight away.
      return () async {
        await stock(expires: now.add(const Duration(days: 45)));

        await scheduler.synchronize(profile.id);

        expect(expiryOnes(), hasLength(3));
      }();
    });

    test('a date years out is planned too, and simply sorts last', () async {
      // No horizon of its own. The budget is the limit and it is spent
      // soonest-first, which is already the rule cycle reminders live by.
      await stock(expires: now.add(const Duration(days: 400)));

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), hasLength(3));
      expect(
        expiryOnes().first.at.isAfter(now.add(const Duration(days: 300))),
        isTrue,
      );
    });
  });

  group('several boxes', () {
    test('four cartons on one date get one warning, not four', () async {
      // Four identical sentences would spend four slots of a budget of 64 and
      // tell the user the same thing each time.
      final DateTime date = now.add(const Duration(days: 20));
      for (int i = 0; i < 4; i++) {
        await stock(expires: date);
      }

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), hasLength(2));
    });

    test('two different dates get their own warnings', () async {
      await stock(expires: now.add(const Duration(days: 10)));
      await stock(expires: now.add(const Duration(days: 25)));

      await scheduler.synchronize(profile.id);

      expect(expiryOnes().length, greaterThan(2));
    });

    test('two consumables on the same date are told apart', () async {
      final ConsumableType set = await h.seedType(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      );
      final DateTime date = now.add(const Duration(days: 20));
      await stock(expires: date);
      await stock(expires: date, type: set);

      await scheduler.synchronize(profile.id);

      final Set<String> named = expiryOnes()
          .map((PendingNotification n) => n.title)
          .toSet();
      expect(named.any((String t) => t.contains('CGM sensor')), isTrue);
      expect(named.any((String t) => t.contains('Infusion set')), isTrue);
    });
  });

  group('alongside the cycle reminders', () {
    test('both kinds are scheduled together, soonest first', () async {
      // Its own offsets, because `seedType` leaves them empty and a type with
      // no offsets has no cycle reminders to schedule.
      final ConsumableType timed = await h.types.create(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
        defaultDuration: const Duration(days: 3),
        defaultReminderOffsets: <Duration>[
          const Duration(hours: 24),
          Duration.zero,
        ],
      );
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: timed.id,
        installedAt: now.subtract(const Duration(days: 1)),
        expectedChangeAt: now.add(const Duration(days: 2)),
      );
      await stock(expires: now.add(const Duration(days: 20)));

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), isNotEmpty);
      expect(
        gateway.scheduled.any(
          (PendingNotification n) =>
              n.kind == NotificationKind.cycleReminder ||
              n.kind == NotificationKind.cycleDue,
        ),
        isTrue,
      );

      // The budget is spent in order, so a change due in two days outranks a
      // box going off in twenty.
      for (int i = 1; i < gateway.scheduled.length; i++) {
        expect(
          gateway.scheduled[i].at.isBefore(gateway.scheduled[i - 1].at),
          isFalse,
        );
      }
    });

    test('stock is warned about even with nothing in use', () async {
      // The early return used to give up before it reached the cupboard.
      await stock(expires: now.add(const Duration(days: 20)));

      await scheduler.synchronize(profile.id);

      expect(expiryOnes(), isNotEmpty);
    });
  });
}
