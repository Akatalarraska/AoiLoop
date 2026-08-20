import 'package:aoiloop/shared/models/cycle_countdown.dart';
import 'package:aoiloop/shared/models/cycle_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every countdown AoiLoop shows comes out of this class, so its boundaries
/// are pinned here rather than inferred from a rendered widget. The interesting
/// cases are all on the edges: the instant a deadline arrives, the instant the
/// grace period runs out, and the moment a status changes without anything
/// having been written to the database.
void main() {
  final DateTime installed = DateTime.utc(2026, 8, 10, 8);
  final DateTime due = DateTime.utc(2026, 8, 20, 8);

  CycleCountdown at(DateTime now, {CycleStatusThresholds? thresholds}) {
    return CycleCountdown.at(
      installedAt: installed,
      expectedChangeAt: due,
      now: now,
      thresholds: thresholds ?? CycleStatusThresholds.defaults,
    );
  }

  group('status boundaries', () {
    test('is healthy while more than the dueSoon window remains', () {
      // 24 hours and one second before the deadline.
      expect(
        at(DateTime.utc(2026, 8, 19, 7, 59, 59)).status,
        CycleStatus.healthy,
      );
    });

    test('turns dueSoon exactly at the window, not a second later', () {
      expect(at(DateTime.utc(2026, 8, 19, 8)).status, CycleStatus.dueSoon);
    });

    test('stays dueSoon until the deadline itself', () {
      expect(
        at(DateTime.utc(2026, 8, 20, 7, 59, 59)).status,
        CycleStatus.dueSoon,
      );
    });

    test('is dueNow the moment the deadline arrives', () {
      expect(at(due).status, CycleStatus.dueNow);
    });

    test('is still dueNow just inside the grace period', () {
      expect(
        at(DateTime.utc(2026, 8, 20, 9, 59, 59)).status,
        CycleStatus.dueNow,
      );
    });

    test('is overdue once the grace period has run out', () {
      expect(at(DateTime.utc(2026, 8, 20, 10)).status, CycleStatus.overdue);
    });

    test('honours a custom dueSoon window', () {
      const CycleStatusThresholds wide = CycleStatusThresholds(
        dueSoon: Duration(days: 2),
      );

      expect(
        at(DateTime.utc(2026, 8, 18, 12), thresholds: wide).status,
        CycleStatus.dueSoon,
      );
      expect(
        at(DateTime.utc(2026, 8, 18, 12)).status,
        CycleStatus.healthy,
        reason: 'the default window is narrower and should still disagree',
      );
    });

    test('honours a custom overdue grace', () {
      const CycleStatusThresholds strict = CycleStatusThresholds(
        overdueAfter: Duration.zero,
      );

      expect(at(due, thresholds: strict).status, CycleStatus.overdue);
    });
  });

  group('remaining time', () {
    test('counts down towards the deadline', () {
      expect(
        at(DateTime.utc(2026, 8, 18, 8)).remaining,
        const Duration(days: 2),
      );
    });

    test('goes negative past the deadline rather than clamping', () {
      expect(
        at(DateTime.utc(2026, 8, 21, 8)).remaining,
        const Duration(days: -1),
      );
    });

    test('timeLeft and overdueBy are the two readings of that one number', () {
      final CycleCountdown before = at(DateTime.utc(2026, 8, 18, 8));
      expect(before.timeLeft, const Duration(days: 2));
      expect(before.overdueBy, isNull);
      expect(before.hasPassed, isFalse);

      final CycleCountdown after = at(DateTime.utc(2026, 8, 22, 8));
      expect(after.timeLeft, isNull);
      expect(after.overdueBy, const Duration(days: 2));
      expect(after.hasPassed, isTrue);
    });

    test('the deadline itself counts as passed', () {
      expect(at(due).hasPassed, isTrue);
      expect(at(due).remaining, Duration.zero);
    });
  });

  group('progress', () {
    test('is zero at the moment of installation', () {
      expect(at(installed).progress, 0);
    });

    test('is a half at the midpoint of a ten day life', () {
      expect(at(DateTime.utc(2026, 8, 15, 8)).progress, 0.5);
    });

    test('is one at the deadline', () {
      expect(at(due).progress, 1);
    });

    test('clamps rather than overflowing once overdue', () {
      expect(at(DateTime.utc(2026, 9, 20, 8)).progress, 1);
    });

    test('clamps rather than going negative before installation', () {
      // A clock that has been moved backwards, or a change back-dated after
      // the fact. Neither should draw a bar running the wrong way.
      expect(at(DateTime.utc(2026, 8, 1, 8)).progress, 0);
    });

    test('is null when the deadline is not after the install', () {
      final CycleCountdown zeroLength = CycleCountdown.at(
        installedAt: due,
        expectedChangeAt: due,
        now: due,
      );

      expect(zeroLength.progress, isNull);
      expect(
        zeroLength.status,
        CycleStatus.dueNow,
        reason: 'a zero length cycle still has a real deadline',
      );
    });
  });

  group('nothing in use', () {
    test('a null deadline is inactive, not overdue', () {
      final CycleCountdown countdown = CycleCountdown.at(
        installedAt: installed,
        expectedChangeAt: null,
        now: DateTime.utc(2026, 12, 31),
      );

      expect(countdown.status, CycleStatus.inactive);
      expect(countdown, CycleCountdown.inactive);
    });

    test('an inactive countdown reports no numbers at all', () {
      expect(CycleCountdown.inactive.remaining, isNull);
      expect(CycleCountdown.inactive.progress, isNull);
      expect(CycleCountdown.inactive.timeLeft, isNull);
      expect(CycleCountdown.inactive.overdueBy, isNull);
      expect(CycleCountdown.inactive.isTracked, isFalse);
      expect(CycleCountdown.inactive.hasPassed, isFalse);
    });
  });

  group('time zones', () {
    test('compares instants, not wall clocks', () {
      // The same moment, named two ways. A countdown that disagreed with
      // itself here would drift by the user's UTC offset.
      final DateTime utc = DateTime.utc(2026, 8, 18, 8);
      final CycleCountdown fromUtc = at(utc);
      final CycleCountdown fromLocal = at(utc.toLocal());

      expect(fromLocal.remaining, fromUtc.remaining);
      expect(fromLocal.status, fromUtc.status);
    });
  });

  test('is a value, so an unchanged countdown does not rebuild the screen', () {
    expect(at(DateTime.utc(2026, 8, 18, 8)), at(DateTime.utc(2026, 8, 18, 8)));
    expect(
      at(DateTime.utc(2026, 8, 18, 8)).hashCode,
      at(DateTime.utc(2026, 8, 18, 8)).hashCode,
    );
    expect(
      at(DateTime.utc(2026, 8, 18, 8)),
      isNot(at(DateTime.utc(2026, 8, 18, 9))),
    );
  });
}
