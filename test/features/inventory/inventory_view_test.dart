import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/inventory/domain/inventory_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The inventory's totalling, low-stock rule and ordering.
///
/// No frame is pumped: the whole point of the view living in `domain/` is that
/// the arithmetic can be pinned without one.
void main() {
  late TestHarness h;
  late UserProfile profile;

  final DateTime now = DateTime.utc(2026, 8, 21, 9);

  setUp(() async {
    h = TestHarness.create(now: now);
    profile = await h.seedProfile();
  });

  Future<InventoryItem> batch(
    ConsumableType type, {
    int quantity = 0,
    int minimum = 0,
    DateTime? expires,
    String? locationId,
  }) {
    return h.inventory.createItem(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      quantity: quantity,
      minimumQuantity: minimum,
      expirationDate: expires,
      locationId: locationId,
    );
  }

  InventoryView build({
    required List<ConsumableType> types,
    required List<InventoryItem> items,
    List<InventoryLocation> locations = const <InventoryLocation>[],
  }) {
    return InventoryView.from(types: types, items: items, locations: locations);
  }

  group('totals', () {
    test('adds up every batch of a consumable', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');
      final List<InventoryItem> items = <InventoryItem>[
        await batch(sensor, quantity: 3),
        await batch(sensor, quantity: 5),
      ];

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: items,
      );

      expect(view.cards.single.total, 8);
    });

    test('a consumable with no batches is untracked, not empty', () async {
      // Zero is a fact. Unknown is not, and telling somebody they have run out
      // of something they never counted would be an invention.
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: const <InventoryItem>[],
      );

      expect(view.cards.single.level, StockLevel.untracked);
      expect(view.cards.single.isTracked, isFalse);
      expect(view.hasAnyStock, isFalse);
    });

    test('a counted consumable at zero is out', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[await batch(sensor)],
      );

      expect(view.cards.single.level, StockLevel.out);
      expect(view.hasAnyStock, isTrue);
    });
  });

  group('the low-stock rule', () {
    test('warns at or below the level the user set', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView atIt = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[await batch(sensor, quantity: 3, minimum: 3)],
      );
      expect(atIt.cards.single.level, StockLevel.low);
    });

    test('stays quiet above it', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[await batch(sensor, quantity: 4, minimum: 3)],
      );

      expect(view.cards.single.level, StockLevel.ok);
      expect(view.lowCount, 0);
    });

    test('a minimum of zero means never warn me', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[await batch(sensor, quantity: 1)],
      );

      expect(view.cards.single.level, StockLevel.ok);
    });

    test('compares the total, not one carton', () async {
      // The minimum lives on the batch because expiry does, but nobody thinks
      // in per-lot minimums. Two batches of three against a minimum of five is
      // six units, which is not low.
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[
          await batch(sensor, quantity: 3, minimum: 5),
          await batch(sensor, quantity: 3, minimum: 5),
        ],
      );

      expect(view.cards.single.total, 6);
      expect(view.cards.single.level, StockLevel.ok);
    });

    test('takes the highest minimum when batches disagree', () async {
      // A stray older figure must not quietly lower the threshold.
      final ConsumableType sensor = await h.seedType(name: 'Sensor');

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[
          await batch(sensor, quantity: 2, minimum: 1),
          await batch(sensor, quantity: 2, minimum: 5),
        ],
      );

      expect(view.cards.single.minimum, 5);
      expect(view.cards.single.level, StockLevel.low);
    });
  });

  group('ordering', () {
    test('leads with what is missing, then what is short', () async {
      final ConsumableType fine = await h.seedType(name: 'A fine thing');
      final ConsumableType low = await h.seedType(name: 'B low thing');
      final ConsumableType out = await h.seedType(name: 'C empty thing');

      final InventoryView view = build(
        types: <ConsumableType>[fine, low, out],
        items: <InventoryItem>[
          await batch(fine, quantity: 10, minimum: 2),
          await batch(low, quantity: 2, minimum: 2),
          await batch(out),
        ],
      );

      expect(view.cards.map((InventoryCard c) => c.type.name), <String>[
        'C empty thing',
        'B low thing',
        'A fine thing',
      ]);
    });

    test('untracked consumables sort last', () async {
      final ConsumableType counted = await h.seedType(name: 'Z counted');
      final ConsumableType unknown = await h.seedType(name: 'A unknown');

      final InventoryView view = build(
        types: <ConsumableType>[unknown, counted],
        items: <InventoryItem>[await batch(counted, quantity: 5)],
      );

      expect(view.cards.last.type.name, 'A unknown');
    });

    test('batches read soonest expiry first, undated last', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');
      final InventoryItem undated = await batch(sensor, quantity: 1);
      final InventoryItem later = await batch(
        sensor,
        quantity: 1,
        expires: now.add(const Duration(days: 200)),
      );
      final InventoryItem soon = await batch(
        sensor,
        quantity: 1,
        expires: now.add(const Duration(days: 10)),
      );

      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: <InventoryItem>[undated, later, soon],
      );

      expect(view.cards.single.batches.map((InventoryItem i) => i.id), <String>[
        soon.id,
        later.id,
        undated.id,
      ]);
    });
  });

  group('as a value', () {
    test('counts what needs a trip to the pharmacy', () async {
      final ConsumableType low = await h.seedType(name: 'Low');
      final ConsumableType out = await h.seedType(name: 'Out');
      final ConsumableType fine = await h.seedType(name: 'Fine');

      final InventoryView view = build(
        types: <ConsumableType>[low, out, fine],
        items: <InventoryItem>[
          await batch(low, quantity: 1, minimum: 2),
          await batch(out),
          await batch(fine, quantity: 9),
        ],
      );

      expect(view.lowCount, 2);
      expect(view.needingAttention, hasLength(2));
    });

    test('finds a card by its type id, and nothing by a stranger', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');
      final InventoryView view = build(
        types: <ConsumableType>[sensor],
        items: const <InventoryItem>[],
      );

      expect(view.cardFor(sensor.id)?.id, sensor.id);
      expect(view.cardFor('not-a-type'), isNull);
    });

    test('two views of the same facts are equal', () async {
      final ConsumableType sensor = await h.seedType(name: 'Sensor');
      final List<InventoryItem> items = <InventoryItem>[
        await batch(sensor, quantity: 4),
      ];

      final InventoryView a = build(
        types: <ConsumableType>[sensor],
        items: items,
      );
      final InventoryView b = build(
        types: <ConsumableType>[sensor],
        items: items,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
