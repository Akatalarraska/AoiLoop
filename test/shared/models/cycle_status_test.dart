import 'package:aoiloop/shared/models/cycle_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CycleStatus', () {
    test('needsAttention covers exactly the actionable states', () {
      expect(CycleStatus.dueSoon.needsAttention, isTrue);
      expect(CycleStatus.dueNow.needsAttention, isTrue);
      expect(CycleStatus.overdue.needsAttention, isTrue);

      expect(CycleStatus.healthy.needsAttention, isFalse);
      expect(CycleStatus.inactive.needsAttention, isFalse);
    });

    test('urgencyRank orders most urgent first', () {
      final List<CycleStatus> sorted =
          <CycleStatus>[
            CycleStatus.healthy,
            CycleStatus.inactive,
            CycleStatus.overdue,
            CycleStatus.dueSoon,
            CycleStatus.dueNow,
          ]..sort(
            (CycleStatus a, CycleStatus b) =>
                a.urgencyRank.compareTo(b.urgencyRank),
          );

      expect(sorted, <CycleStatus>[
        CycleStatus.overdue,
        CycleStatus.dueNow,
        CycleStatus.dueSoon,
        CycleStatus.healthy,
        CycleStatus.inactive,
      ]);
    });

    test('urgencyRank is a total order with no ties', () {
      final Set<int> ranks = CycleStatus.values
          .map((CycleStatus s) => s.urgencyRank)
          .toSet();

      expect(ranks.length, CycleStatus.values.length);
    });
  });

  group('CycleStatusThresholds', () {
    test('defaults to a 24 hour dueSoon window', () {
      expect(CycleStatusThresholds.defaults.dueSoon, const Duration(hours: 24));
    });

    test('defaults to a 2 hour grace before something counts as overdue', () {
      expect(
        CycleStatusThresholds.defaults.overdueAfter,
        const Duration(hours: 2),
      );
    });

    test('the grace is positive, or dueNow would be unreachable', () {
      // Read literally the spec gives dueNow a zero-width window. The grace is
      // what makes it a status a user can actually be in.
      expect(
        CycleStatusThresholds.defaults.overdueAfter,
        greaterThan(Duration.zero),
      );
    });

    test('copyWith overrides only what is given', () {
      const CycleStatusThresholds custom = CycleStatusThresholds();

      final CycleStatusThresholds widened = custom.copyWith(
        dueSoon: const Duration(hours: 48),
      );

      expect(widened.dueSoon, const Duration(hours: 48));
      expect(
        widened.overdueAfter,
        custom.overdueAfter,
        reason: 'the field that was not passed must be carried over',
      );
      expect(custom.dueSoon, const Duration(hours: 24));
    });

    test('equality is by value, so it is safe in provider state', () {
      expect(
        const CycleStatusThresholds(dueSoon: Duration(hours: 6)),
        const CycleStatusThresholds(dueSoon: Duration(hours: 6)),
      );
      expect(
        const CycleStatusThresholds(dueSoon: Duration(hours: 6)).hashCode,
        const CycleStatusThresholds(dueSoon: Duration(hours: 6)).hashCode,
      );
      expect(
        const CycleStatusThresholds(dueSoon: Duration(hours: 6)),
        isNot(const CycleStatusThresholds(dueSoon: Duration(hours: 12))),
      );
      expect(
        const CycleStatusThresholds(overdueAfter: Duration(hours: 1)),
        isNot(const CycleStatusThresholds(overdueAfter: Duration(hours: 12))),
        reason: 'both fields have to take part, or a change to one is lost',
      );
    });
  });
}
