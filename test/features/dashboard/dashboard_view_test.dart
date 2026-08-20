import 'package:dt1flow/core/database/app_database.dart';
import 'package:dt1flow/features/dashboard/domain/dashboard_view.dart';
import 'package:dt1flow/shared/models/cycle_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The dashboard's ordering rules and its "what is next" answer, tested
/// without pumping a frame.
///
/// The ordering matters more than it looks: Home is read at a glance, and
/// whatever is at the top is what gets acted on. A list that put the sensor
/// due in nine days above the one that expired yesterday would be worse than
/// no list at all.
void main() {
  late TestHarness harness;
  late UserProfile profile;
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  setUp(() async {
    harness = TestHarness.create(now: now);
    profile = await harness.seedProfile();
  });

  /// A type with an instance already installed and due at [due].
  Future<(ConsumableType, ConsumableInstance)> tracked({
    required String name,
    required DateTime? due,
    DateTime? installedAt,
  }) async {
    final ConsumableType type = await harness.seedType(name: name);
    final ConsumableInstance instance = await harness.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: installedAt ?? now.subtract(const Duration(days: 1)),
      expectedChangeAt: due,
    );
    return (type, instance);
  }

  DashboardView viewOf(
    List<ConsumableType> types,
    List<ConsumableInstance> instances,
  ) {
    return DashboardView.from(
      profile: profile,
      types: types,
      instances: instances,
      now: now,
    );
  }

  group('joining types to what is in use', () {
    test('a type with nothing in use still gets a card', () async {
      final ConsumableType type = await harness.seedType(name: 'CGM sensor');

      final DashboardView view = viewOf(<ConsumableType>[
        type,
      ], const <ConsumableInstance>[]);

      expect(view.cards, hasLength(1));
      expect(view.cards.single.hasStarted, isFalse);
      expect(view.cards.single.status, CycleStatus.inactive);
      expect(view.notStartedCount, 1);
    });

    test('a type with an active instance counts down', () async {
      final (ConsumableType type, ConsumableInstance instance) = await tracked(
        name: 'CGM sensor',
        due: now.add(const Duration(days: 3)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[type],
        <ConsumableInstance>[instance],
      );

      expect(view.cards.single.instance, instance);
      expect(view.cards.single.countdown.remaining, const Duration(days: 3));
      expect(view.cards.single.status, CycleStatus.healthy);
    });

    test('an instance whose type is not listed is dropped', () async {
      // A type deactivated while something was still on the body. History
      // keeps it; Home shows what the user asked to track.
      final (ConsumableType _, ConsumableInstance orphan) = await tracked(
        name: 'Retired sensor',
        due: now.add(const Duration(days: 1)),
      );
      final ConsumableType kept = await harness.seedType(name: 'Pod');

      final DashboardView view = viewOf(
        <ConsumableType>[kept],
        <ConsumableInstance>[orphan],
      );

      expect(view.cards, hasLength(1));
      expect(view.cards.single.type.name, 'Pod');
      expect(view.cards.single.hasStarted, isFalse);
    });

    test(
      'an in-use item with no deadline is started but not counting',
      () async {
        final (ConsumableType type, ConsumableInstance instance) =
            await tracked(name: 'Open insulin', due: null);

        final DashboardView view = viewOf(
          <ConsumableType>[type],
          <ConsumableInstance>[instance],
        );

        expect(view.cards.single.hasStarted, isTrue);
        expect(view.cards.single.countdown.isTracked, isFalse);
        expect(view.cards.single.status, CycleStatus.inactive);
      },
    );

    test('no types at all is empty, not a screen of nothing', () {
      final DashboardView view = viewOf(
        const <ConsumableType>[],
        const <ConsumableInstance>[],
      );

      expect(view.isEmpty, isTrue);
      expect(view.nextChange, isNull);
      expect(view.needsAttentionCount, 0);
    });
  });

  group('ordering', () {
    test('the most urgent status comes first', () async {
      final (
        ConsumableType healthyType,
        ConsumableInstance healthy,
      ) = await tracked(
        name: 'Reservoir',
        due: now.add(const Duration(days: 5)),
      );
      final (
        ConsumableType overdueType,
        ConsumableInstance overdue,
      ) = await tracked(
        name: 'Sensor',
        due: now.subtract(const Duration(days: 2)),
      );
      final (ConsumableType soonType, ConsumableInstance soon) = await tracked(
        name: 'Infusion set',
        due: now.add(const Duration(hours: 5)),
      );
      final ConsumableType neverStarted = await harness.seedType(name: 'Pod');

      final DashboardView view = viewOf(
        <ConsumableType>[healthyType, overdueType, soonType, neverStarted],
        <ConsumableInstance>[healthy, overdue, soon],
      );

      expect(view.cards.map((DashboardCard card) => card.type.name), <String>[
        'Sensor',
        'Infusion set',
        'Reservoir',
        'Pod',
      ]);
    });

    test('within one status, the nearest deadline comes first', () async {
      final (ConsumableType laterType, ConsumableInstance later) =
          await tracked(name: 'B set', due: now.add(const Duration(days: 9)));
      final (
        ConsumableType soonerType,
        ConsumableInstance sooner,
      ) = await tracked(
        name: 'A sensor',
        due: now.add(const Duration(days: 2)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[laterType, soonerType],
        <ConsumableInstance>[later, sooner],
      );

      expect(view.cards.map((DashboardCard card) => card.type.name), <String>[
        'A sensor',
        'B set',
      ], reason: 'nearest deadline wins, whatever the names are');
    });

    test('the longest overdue comes first among overdue items', () async {
      final (
        ConsumableType recentType,
        ConsumableInstance recent,
      ) = await tracked(
        name: 'A set',
        due: now.subtract(const Duration(days: 1)),
      );
      final (
        ConsumableType ancientType,
        ConsumableInstance ancient,
      ) = await tracked(
        name: 'B sensor',
        due: now.subtract(const Duration(days: 6)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[recentType, ancientType],
        <ConsumableInstance>[recent, ancient],
      );

      expect(view.cards.first.type.name, 'B sensor');
    });

    test('names break a tie, so the order does not wobble', () async {
      final ConsumableType zeta = await harness.seedType(name: 'Zeta');
      final ConsumableType alpha = await harness.seedType(name: 'alpha');

      final DashboardView view = viewOf(<ConsumableType>[
        zeta,
        alpha,
      ], const <ConsumableInstance>[]);

      expect(view.cards.map((DashboardCard card) => card.type.name), <String>[
        'alpha',
        'Zeta',
      ], reason: 'compared without case, or Z would sort before a');
    });
  });

  group('what to deal with next', () {
    test('is the most urgent, not the chronologically nearest', () async {
      final (
        ConsumableType overdueType,
        ConsumableInstance overdue,
      ) = await tracked(
        name: 'Sensor',
        due: now.subtract(const Duration(days: 2)),
      );
      final (ConsumableType soonType, ConsumableInstance soon) = await tracked(
        name: 'Infusion set',
        due: now.add(const Duration(hours: 1)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[overdueType, soonType],
        <ConsumableInstance>[overdue, soon],
      );

      expect(view.nextChange!.type.name, 'Sensor');
    });

    test('skips cards that are not counting down at all', () async {
      final ConsumableType idle = await harness.seedType(name: 'A pod');
      final (
        ConsumableType runningType,
        ConsumableInstance running,
      ) = await tracked(
        name: 'Z sensor',
        due: now.add(const Duration(days: 4)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[idle, runningType],
        <ConsumableInstance>[running],
      );

      expect(view.cards.first.type.name, 'Z sensor');
      expect(view.nextChange!.type.name, 'Z sensor');
    });

    test('is null when nothing has ever been registered', () async {
      final ConsumableType type = await harness.seedType(name: 'CGM sensor');

      final DashboardView view = viewOf(<ConsumableType>[
        type,
      ], const <ConsumableInstance>[]);

      expect(view.nextChange, isNull);
      expect(
        view.isEmpty,
        isFalse,
        reason: 'there is still a card, it just has no countdown',
      );
    });
  });

  group('how much is asking for something', () {
    test('counts due soon, due now and overdue, and nothing else', () async {
      final (
        ConsumableType healthyType,
        ConsumableInstance healthy,
      ) = await tracked(
        name: 'Reservoir',
        due: now.add(const Duration(days: 5)),
      );
      final (ConsumableType soonType, ConsumableInstance soon) = await tracked(
        name: 'Set',
        due: now.add(const Duration(hours: 5)),
      );
      final (
        ConsumableType overdueType,
        ConsumableInstance overdue,
      ) = await tracked(
        name: 'Sensor',
        due: now.subtract(const Duration(days: 2)),
      );
      final ConsumableType idle = await harness.seedType(name: 'Pod');

      final DashboardView view = viewOf(
        <ConsumableType>[healthyType, soonType, overdueType, idle],
        <ConsumableInstance>[healthy, soon, overdue],
      );

      expect(view.needsAttentionCount, 2);
      expect(view.notStartedCount, 1);
    });

    test('is zero on a good day', () async {
      final (ConsumableType type, ConsumableInstance instance) = await tracked(
        name: 'Sensor',
        due: now.add(const Duration(days: 8)),
      );

      final DashboardView view = viewOf(
        <ConsumableType>[type],
        <ConsumableInstance>[instance],
      );

      expect(view.needsAttentionCount, 0);
    });
  });

  group('the view is a value', () {
    test('two views of the same data at the same instant are equal', () async {
      final (ConsumableType type, ConsumableInstance instance) = await tracked(
        name: 'Sensor',
        due: now.add(const Duration(days: 2)),
      );

      expect(
        viewOf(<ConsumableType>[type], <ConsumableInstance>[instance]),
        viewOf(<ConsumableType>[type], <ConsumableInstance>[instance]),
      );
    });

    test(
      'a later instant is a different view, which is what redraws',
      () async {
        final (
          ConsumableType type,
          ConsumableInstance instance,
        ) = await tracked(
          name: 'Sensor',
          due: now.add(const Duration(days: 2)),
        );

        final DashboardView later = DashboardView.from(
          profile: profile,
          types: <ConsumableType>[type],
          instances: <ConsumableInstance>[instance],
          now: now.add(const Duration(minutes: 1)),
        );

        expect(
          later,
          isNot(viewOf(<ConsumableType>[type], <ConsumableInstance>[instance])),
        );
      },
    );
  });
}
