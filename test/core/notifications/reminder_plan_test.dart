import 'package:blauloop/core/notifications/domain/reminder_plan.dart';
import 'package:blauloop/shared/models/notification_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which moments a cycle deserves a reminder at.
///
/// The half of notifications that can actually be wrong, and the half that
/// needs no device to test.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 17, 9);
  final DateTime dueIn10Days = DateTime.utc(2026, 8, 27, 9);

  /// The offsets onboarding ticks by default, plus the two it offers.
  const List<Duration> everyOffset = <Duration>[
    Duration(days: 2),
    Duration(days: 1),
    Duration(hours: 6),
    Duration(hours: 1),
    Duration.zero,
  ];

  group('with nothing to warn about', () {
    test('an untracked cycle has no reminders', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: null,
        offsets: everyOffset,
        now: now,
      );

      expect(plan.isEmpty, isTrue);
    });

    test('no offsets means the user asked for silence', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: const <Duration>[],
        now: now,
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  group('the moments chosen', () {
    test('are the deadline less each offset', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: everyOffset,
        now: now,
      );

      expect(plan.moments.map((ReminderMoment m) => m.at).toList(), <DateTime>[
        DateTime.utc(2026, 8, 25, 9), // 48h
        DateTime.utc(2026, 8, 26, 9), // 24h
        DateTime.utc(2026, 8, 27, 3), // 6h
        DateTime.utc(2026, 8, 27, 8), // 1h
        DateTime.utc(2026, 8, 27, 9), // on the due date
      ]);
    });

    test('arrive in chronological order', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        // Deliberately unsorted. The budget is spent in order, so the order
        // has to come from the plan and not from how the caller wrote a list.
        offsets: const <Duration>[
          Duration(hours: 1),
          Duration(days: 2),
          Duration.zero,
        ],
        now: now,
      );

      final List<DateTime> moments = plan.moments
          .map((ReminderMoment m) => m.at)
          .toList();
      expect(moments, orderedEquals(<DateTime>[...moments]..sort()));
    });

    test('separate the due date from the ones leading up to it', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: everyOffset,
        now: now,
      );

      expect(plan.moments.last.kind, NotificationKind.cycleDue);
      expect(plan.moments.last.leadTime, Duration.zero);
      for (final ReminderMoment moment in plan.moments.take(4)) {
        expect(moment.kind, NotificationKind.cycleReminder);
      }
    });
  });

  group('moments already behind the clock', () {
    test('are dropped rather than scheduled', () {
      // Six hours from the deadline: the 48h and 24h reminders are in the
      // past, and a notification dated behind the clock either never fires or
      // fires the instant it is registered.
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: everyOffset,
        now: DateTime.utc(2026, 8, 27, 3, 30),
      );

      expect(
        plan.moments.map((ReminderMoment m) => m.leadTime).toList(),
        <Duration>[const Duration(hours: 1), Duration.zero],
      );
    });

    test('leave nothing at all once the deadline has passed', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: everyOffset,
        now: dueIn10Days.add(const Duration(minutes: 1)),
      );

      expect(plan.isEmpty, isTrue);
    });

    test('treat the exact instant as past', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: const <Duration>[Duration.zero],
        now: dueIn10Days,
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  group('offsets that would waste a slot', () {
    test('duplicates collapse to one reminder', () {
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: const <Duration>[
          Duration(days: 1),
          Duration(days: 1),
          Duration(minutes: 1440),
        ],
        now: now,
      );

      expect(plan.length, 1);
    });

    test('negative offsets are refused', () {
      // A reminder cannot lead a deadline by a negative amount; scheduling one
      // would put a notification *after* the change was due.
      final ReminderPlan plan = ReminderPlan.forCycle(
        expectedChangeAt: dueIn10Days,
        offsets: const <Duration>[Duration(hours: -6), Duration.zero],
        now: now,
      );

      expect(plan.length, 1);
      expect(plan.moments.single.leadTime, Duration.zero);
    });
  });

  test('is a value, so two plans of the same moments are equal', () {
    ReminderPlan build() => ReminderPlan.forCycle(
      expectedChangeAt: dueIn10Days,
      offsets: everyOffset,
      now: now,
    );

    expect(build(), build());
    expect(build().hashCode, build().hashCode);
  });
}
