import 'package:blauloop/core/notifications/domain/reminder_plan.dart';
import 'package:blauloop/shared/models/notification_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which moments an expiring batch deserves a warning at.
///
/// Pure Dart, pinned at exact instants. The half of notifications that can go
/// wrong is which moments get chosen, and this is the half testable without a
/// device.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 21, 9);

  /// The hour of the day expiry reminders land on, as a readable local.
  const int hour = ReminderPlan.reminderHourUtc;

  ReminderPlan planFor(
    DateTime? expiresOn, {
    List<Duration> leadTimes = ReminderPlan.defaultExpiryLeadTimes,
  }) {
    return ReminderPlan.forExpiry(
      expiresOn: expiresOn,
      leadTimes: leadTimes,
      now: now,
    );
  }

  group('what it plans', () {
    test('warns ahead of the date and again on it', () async {
      final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1));

      expect(plan.moments, hasLength(3));
      expect(plan.moments.map((ReminderMoment m) => m.kind), <NotificationKind>[
        NotificationKind.expiringSoon,
        NotificationKind.expiringSoon,
        NotificationKind.expired,
      ]);
    });

    test('the last one is the day it expires, not a warning about it', () {
      // Two different sentences rather than the same one said again. "In a
      // week" is something to plan around; "as of today" is something to act
      // on.
      final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1));

      expect(plan.moments.last.kind, NotificationKind.expired);
      expect(plan.moments.last.at, DateTime.utc(2026, 12, 1, hour));
      expect(plan.moments.last.leadTime, Duration.zero);
    });

    test('places every moment at the same hour of the day', () {
      // Expiry is a calendar date, so something has to choose a time. Midnight
      // either wakes somebody up or is buried under the overnight pile.
      final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1));

      for (final ReminderMoment moment in plan.moments) {
        expect(moment.at.hour, hour, reason: '$moment');
      }
    });

    test('counts the lead times back from the expiry date', () {
      final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1));

      expect(plan.moments.first.at, DateTime.utc(2026, 11, 1, hour));
      expect(plan.moments.first.leadTime, const Duration(days: 30));
    });

    test('ignores the hour on a stored expiry timestamp', () {
      // The date comes off a box, which states a day and nothing finer.
      final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1, 23, 47));

      expect(plan.moments.last.at, DateTime.utc(2026, 12, 1, hour));
    });
  });

  group('what it refuses to plan', () {
    test('nothing at all without a date', () {
      expect(planFor(null).isEmpty, isTrue);
    });

    test('nothing for a date already behind the clock', () {
      // A notification dated in the past either never fires or fires the
      // instant it is registered.
      expect(planFor(now.subtract(const Duration(days: 3))).isEmpty, isTrue);
    });

    test('drops only the leads that have passed, keeping the rest', () {
      // Twenty days out: the thirty-day warning is gone, the seven-day one and
      // the day itself are still ahead.
      final ReminderPlan plan = planFor(now.add(const Duration(days: 20)));

      expect(plan.moments, hasLength(2));
      expect(plan.moments.first.leadTime, const Duration(days: 7));
      expect(plan.moments.last.kind, NotificationKind.expired);
    });

    test('a zero lead time never becomes a second warning', () {
      // The day itself is already covered, and by a different sentence.
      final ReminderPlan plan = planFor(
        DateTime.utc(2026, 12, 1),
        leadTimes: <Duration>[Duration.zero, const Duration(days: 7)],
      );

      expect(
        plan.moments.where(
          (ReminderMoment m) => m.kind == NotificationKind.expired,
        ),
        hasLength(1),
      );
      expect(plan.moments, hasLength(2));
    });

    test('two identical lead times spend one slot, not two', () {
      final ReminderPlan plan = planFor(
        DateTime.utc(2026, 12, 1),
        leadTimes: <Duration>[const Duration(days: 7), const Duration(days: 7)],
      );

      expect(plan.moments, hasLength(2));
    });
  });

  test('the moments come back soonest first', () {
    // The order the budget is spent in.
    final ReminderPlan plan = planFor(DateTime.utc(2026, 12, 1));

    for (int i = 1; i < plan.moments.length; i++) {
      expect(
        plan.moments[i].at.isAfter(plan.moments[i - 1].at),
        isTrue,
        reason: 'moment $i is not after ${i - 1}',
      );
    }
  });

  test('the default lead times are weeks, not hours', () {
    // The action is a pharmacy trip, not a two-minute change.
    for (final Duration lead in ReminderPlan.defaultExpiryLeadTimes) {
      expect(lead.inDays, greaterThanOrEqualTo(7));
    }
  });
}
