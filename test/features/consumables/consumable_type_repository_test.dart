import 'package:aoiloop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
  });

  test('creates a cyclic type with a duration', () async {
    final ConsumableType type = await h.types.create(
      name: 'CGM sensor',
      category: ConsumableCategory.cgmSensor,
      defaultDuration: const Duration(days: 10),
    );

    expect(type.name, 'CGM sensor');
    expect(type.defaultDurationMinutes, 14400);
    expect(type.tracksCycle, isTrue);
    expect(type.tracksInventory, isTrue);
    expect(type.isBuiltIn, isFalse);
    expect(type.active, isTrue);
  });

  test('supports a counted item with no wear cycle', () async {
    // A box of test strips is counted, not timed.
    final ConsumableType strips = await h.types.create(
      name: 'Test strips',
      category: ConsumableCategory.testStrip,
      defaultDuration: null,
      tracksCycle: false,
    );

    expect(strips.defaultDurationMinutes, isNull);
    expect(strips.tracksCycle, isFalse);
    expect(strips.tracksInventory, isTrue);
  });

  test('stores durations that are not whole days', () async {
    // Real products: a set is 72 hours, a pod is 72 hours plus a grace period.
    final ConsumableType pod = await h.types.create(
      name: 'Pod',
      category: ConsumableCategory.pod,
      defaultDuration: const Duration(hours: 80),
    );

    expect(pod.defaultDurationMinutes, 4800);
  });

  test('round-trips reminder offsets, normalised', () async {
    final ConsumableType type = await h.types.create(
      name: 'Sensor',
      category: ConsumableCategory.cgmSensor,
      defaultReminderOffsets: const <Duration>[
        Duration(hours: 1),
        Duration(hours: 48),
        Duration(hours: 24),
        Duration(hours: 1),
      ],
    );

    expect(type.defaultReminderOffsets, const <Duration>[
      Duration(hours: 48),
      Duration(hours: 24),
      Duration(hours: 1),
    ]);
  });

  test('defaults to no reminder offsets', () async {
    final ConsumableType type = await h.seedType();

    expect(type.defaultReminderOffsets, isEmpty);
  });

  test('watchCyclic lists only types that have a countdown', () async {
    await h.seedType(name: 'Sensor');
    await h.types.create(
      name: 'Test strips',
      category: ConsumableCategory.testStrip,
      tracksCycle: false,
    );

    final List<ConsumableType> cyclic = await h.types.watchCyclic().first;

    expect(cyclic.map((ConsumableType t) => t.name), <String>['Sensor']);
  });

  test('watchActive sorts by name', () async {
    await h.seedType(name: 'Reservoir');
    await h.seedType(name: 'Infusion set');
    await h.seedType(name: 'Sensor');

    final List<ConsumableType> types = await h.types.watchActive().first;

    expect(types.map((ConsumableType t) => t.name), <String>[
      'Infusion set',
      'Reservoir',
      'Sensor',
    ]);
  });

  test('deactivating hides the type but keeps the row', () async {
    final ConsumableType type = await h.seedType();

    await h.types.deactivate(type.id);

    expect(await h.types.watchActive().first, isEmpty);
    expect(await h.types.findById(type.id), isNotNull);
  });

  test(
    'changing the duration does not touch instances already in use',
    () async {
      // A user who discovers their sensors only last 7 days must not have
      // yesterday's deadline silently rewritten underneath them.
      final UserProfile profile = await h.seedProfile();
      final ConsumableType type = await h.seedType();
      final ConsumableInstance instance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: type.id,
        installedAt: DateTime.utc(2026, 8, 17, 9),
        expectedChangeAt: DateTime.utc(2026, 8, 27, 9),
      );

      await h.types.setDefaultDuration(type.id, const Duration(days: 7));

      final ConsumableInstance? reloaded = await h.instances.findById(
        instance.id,
      );
      expect(reloaded!.expectedChangeAt, DateTime.utc(2026, 8, 27, 9));
    },
  );

  test('setDefaultDuration accepts null, for items with no cycle', () async {
    final ConsumableType type = await h.seedType();

    await h.types.setDefaultDuration(type.id, null);

    expect((await h.types.findById(type.id))!.defaultDurationMinutes, isNull);
  });

  test('setReminderOffsets replaces the whole set', () async {
    final ConsumableType type = await h.types.create(
      name: 'Sensor',
      category: ConsumableCategory.cgmSensor,
      defaultReminderOffsets: const <Duration>[Duration(hours: 24)],
    );

    await h.types.setReminderOffsets(type.id, const <Duration>[
      Duration(hours: 6),
      Duration.zero,
    ]);

    expect(
      (await h.types.findById(type.id))!.defaultReminderOffsets,
      const <Duration>[Duration(hours: 6), Duration.zero],
    );
  });

  test('updating refreshes updatedAt', () async {
    final ConsumableType type = await h.seedType();
    h.clock.advance(const Duration(hours: 3));

    await h.types.setDefaultDuration(type.id, const Duration(days: 7));

    final ConsumableType? reloaded = await h.types.findById(type.id);
    expect(reloaded!.updatedAt, DateTime.utc(2026, 8, 17, 12));
    expect(reloaded.createdAt, DateTime.utc(2026, 8, 17, 9));
  });

  test('findByCategory ignores deactivated types', () async {
    final ConsumableType type = await h.seedType();
    await h.types.deactivate(type.id);

    expect(await h.types.findByCategory(ConsumableCategory.cgmSensor), isEmpty);
  });

  test('countAll counts every type, active or not', () async {
    await h.seedType(name: 'A');
    final ConsumableType b = await h.seedType(name: 'B');
    await h.types.deactivate(b.id);

    expect(await h.types.countAll(), 2);
  });

  test('countAll returns zero on an empty database', () async {
    expect(await h.types.countAll(), 0);
  });
}
