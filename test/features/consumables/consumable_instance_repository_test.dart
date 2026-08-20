import 'package:blauloop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;
  late ConsumableType set;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'Sensor');
    set = await h.seedType(
      name: 'Infusion set',
      category: ConsumableCategory.infusionSet,
      defaultDuration: const Duration(days: 3),
    );
  });

  Future<ConsumableInstance> install(
    ConsumableType type, {
    DateTime? installedAt,
    DateTime? expectedChangeAt,
  }) {
    return h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: installedAt ?? h.clock.nowUtc(),
      expectedChangeAt: expectedChangeAt,
    );
  }

  group('creation', () {
    test('starts active with no removal date', () async {
      final ConsumableInstance instance = await install(sensor);

      expect(instance.status, ConsumableStatus.active);
      expect(instance.removedAt, isNull);
    });

    test('normalises timestamps to UTC', () async {
      final ConsumableInstance instance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: DateTime(2026, 8, 17, 11),
        expectedChangeAt: DateTime(2026, 8, 27, 11),
        expirationDate: DateTime(2027, 1, 1),
      );

      expect(instance.installedAt.isUtc, isTrue);
      expect(instance.expectedChangeAt!.isUtc, isTrue);
      expect(instance.expirationDate!.isUtc, isTrue);
    });

    test('captures lot and serial for a future replacement claim', () async {
      // Worth asking at install time — the packaging is gone by the time it
      // fails.
      final ConsumableInstance instance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: h.clock.nowUtc(),
        lotNumber: 'LOT-42',
        serialNumber: 'SN-7',
      );

      expect(instance.lotNumber, 'LOT-42');
      expect(instance.serialNumber, 'SN-7');
    });

    test('allows an instance with no deadline at all', () async {
      final ConsumableInstance instance = await install(sensor);

      expect(instance.expectedChangeAt, isNull);
    });
  });

  group('watchActive', () {
    test('orders by soonest deadline first', () async {
      await install(sensor, expectedChangeAt: DateTime.utc(2026, 8, 27));
      await install(set, expectedChangeAt: DateTime.utc(2026, 8, 20));

      final List<ConsumableInstance> active = await h.instances
          .watchActive(profile.id)
          .first;

      expect(active.map((ConsumableInstance i) => i.consumableTypeId), <String>[
        set.id,
        sensor.id,
      ]);
    });

    test('sorts deadline-less items last, not first', () async {
      // SQLite orders NULL before everything, which would put untimed items at
      // the top of a dashboard meant to lead with what is most urgent.
      await install(sensor);
      await install(set, expectedChangeAt: DateTime.utc(2026, 8, 20));

      final List<ConsumableInstance> active = await h.instances
          .watchActive(profile.id)
          .first;

      expect(active.first.consumableTypeId, set.id);
      expect(active.last.expectedChangeAt, isNull);
    });

    test('excludes closed instances', () async {
      final ConsumableInstance instance = await install(sensor);
      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.completed,
      );

      expect(await h.instances.watchActive(profile.id).first, isEmpty);
    });

    test('is scoped to one profile', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Lucas');
      await install(sensor);

      expect(await h.instances.watchActive(other.id).first, isEmpty);
    });
  });

  group('findActiveForType', () {
    test('returns the one currently in use', () async {
      final ConsumableInstance instance = await install(sensor);

      final ConsumableInstance? found = await h.instances.findActiveForType(
        profile.id,
        sensor.id,
      );

      expect(found?.id, instance.id);
    });

    test('returns null when nothing of that type is on', () async {
      expect(
        await h.instances.findActiveForType(profile.id, sensor.id),
        isNull,
      );
    });

    test('ignores closed instances of the same type', () async {
      final ConsumableInstance instance = await install(sensor);
      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.removedEarly,
      );

      expect(
        await h.instances.findActiveForType(profile.id, sensor.id),
        isNull,
      );
    });
  });

  group('close', () {
    test('records when and how it ended', () async {
      final ConsumableInstance instance = await install(sensor);
      h.clock.advance(const Duration(days: 10));

      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.completed,
      );

      final ConsumableInstance? reloaded = await h.instances.findById(
        instance.id,
      );
      expect(reloaded!.status, ConsumableStatus.completed);
      expect(reloaded.removedAt, DateTime.utc(2026, 8, 27, 9));
    });

    test('distinguishes an early removal from a completed cycle', () async {
      // This is what separates an ordinary change from a failure in every
      // later count.
      final ConsumableInstance instance = await install(sensor);

      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.removedEarly,
      );

      expect(
        (await h.instances.findById(instance.id))!.status,
        ConsumableStatus.removedEarly,
      );
    });

    test('records something discarded without ever being used', () async {
      final ConsumableInstance instance = await install(sensor);

      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.discarded,
      );

      expect(
        (await h.instances.findById(instance.id))!.status,
        ConsumableStatus.discarded,
      );
    });

    test('refuses to close into the active state', () async {
      final ConsumableInstance instance = await install(sensor);

      expect(
        () => h.instances.close(
          instance.id,
          removedAt: h.clock.nowUtc(),
          status: ConsumableStatus.active,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('findDueBefore', () {
    test('includes an instance due exactly at the cutoff', () async {
      // The boundary that matters: "due now" means the moment has arrived, not
      // that it has passed.
      await install(sensor, expectedChangeAt: DateTime.utc(2026, 8, 27, 9));

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2026, 8, 27, 9),
      );

      expect(due, hasLength(1));
    });

    test('excludes an instance due one second after the cutoff', () async {
      await install(
        sensor,
        expectedChangeAt: DateTime.utc(2026, 8, 27, 9, 0, 1),
      );

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2026, 8, 27, 9),
      );

      expect(due, isEmpty);
    });

    test('includes an overdue instance', () async {
      await install(sensor, expectedChangeAt: DateTime.utc(2026, 8, 1));

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2026, 8, 17, 9),
      );

      expect(due, hasLength(1));
    });

    test('ignores instances with no deadline', () async {
      await install(sensor);

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(due, isEmpty);
    });

    test('ignores closed instances, however overdue they look', () async {
      final ConsumableInstance instance = await install(
        sensor,
        expectedChangeAt: DateTime.utc(2026, 1, 1),
      );
      await h.instances.close(
        instance.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.completed,
      );

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(due, isEmpty);
    });

    test('orders soonest first', () async {
      await install(sensor, expectedChangeAt: DateTime.utc(2026, 8, 25));
      await install(set, expectedChangeAt: DateTime.utc(2026, 8, 19));

      final List<ConsumableInstance> due = await h.instances.findDueBefore(
        profile.id,
        DateTime.utc(2026, 9, 1),
      );

      expect(due.map((ConsumableInstance i) => i.consumableTypeId), <String>[
        set.id,
        sensor.id,
      ]);
    });
  });

  group('watchHistory', () {
    test('lists closed instances, most recently removed first', () async {
      final ConsumableInstance first = await install(sensor);
      await h.instances.close(
        first.id,
        removedAt: DateTime.utc(2026, 8, 10),
        status: ConsumableStatus.completed,
      );
      final ConsumableInstance second = await install(sensor);
      await h.instances.close(
        second.id,
        removedAt: DateTime.utc(2026, 8, 15),
        status: ConsumableStatus.completed,
      );

      final List<ConsumableInstance> history = await h.instances
          .watchHistory(profile.id)
          .first;

      expect(history.map((ConsumableInstance i) => i.id), <String>[
        second.id,
        first.id,
      ]);
    });

    test('excludes what is still in use', () async {
      await install(sensor);

      expect(await h.instances.watchHistory(profile.id).first, isEmpty);
    });
  });

  test('setExpectedChangeAt moves the deadline', () async {
    final ConsumableInstance instance = await install(
      sensor,
      expectedChangeAt: DateTime.utc(2026, 8, 27, 3, 17),
    );

    // The engine proposes a shift to the preferred time and the user accepts;
    // nothing moves a date on its own initiative.
    await h.instances.setExpectedChangeAt(
      instance.id,
      DateTime.utc(2026, 8, 27, 19),
    );

    expect(
      (await h.instances.findById(instance.id))!.expectedChangeAt,
      DateTime.utc(2026, 8, 27, 19),
    );
  });
}
