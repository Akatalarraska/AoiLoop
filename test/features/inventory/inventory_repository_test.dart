import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'Sensor');
  });

  Future<InventoryItem> stock({
    int quantity = 0,
    int minimumQuantity = 0,
    String? lotNumber,
    DateTime? expirationDate,
    String? locationId,
  }) {
    return h.inventory.createItem(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      quantity: quantity,
      minimumQuantity: minimumQuantity,
      lotNumber: lotNumber,
      expirationDate: expirationDate,
      locationId: locationId,
    );
  }

  group('locations', () {
    test('creates a location with a default icon', () async {
      final InventoryLocation location = await h.inventory.createLocation(
        userProfileId: profile.id,
        name: "Mum's house",
      );

      expect(location.name, "Mum's house");
      expect(location.icon, 'box');
      expect(location.active, isTrue);
    });

    test('supports several locations for one profile', () async {
      // A child between two homes and a school is the situation DT1FLOW
      // exists for.
      for (final String name in <String>[
        "Mum's house",
        "Dad's house",
        'School',
        'Backpack',
      ]) {
        await h.inventory.createLocation(userProfileId: profile.id, name: name);
      }

      expect(await h.inventory.watchLocations(profile.id).first, hasLength(4));
    });

    test('deactivating hides a location but keeps the row', () async {
      final InventoryLocation location = await h.inventory.createLocation(
        userProfileId: profile.id,
        name: 'Old',
      );

      await h.inventory.deactivateLocation(location.id);

      expect(await h.inventory.watchLocations(profile.id).first, isEmpty);
    });

    test('deleting a location leaves its stock, unfiled', () async {
      final InventoryLocation location = await h.inventory.createLocation(
        userProfileId: profile.id,
        name: 'School',
      );
      final InventoryItem item = await stock(
        quantity: 3,
        locationId: location.id,
      );

      await (h.db.delete(
        h.db.inventoryLocations,
      )..where(($InventoryLocationsTable t) => t.id.equals(location.id))).go();

      final InventoryItem? reloaded = await h.inventory.findById(item.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.locationId, isNull);
      expect(reloaded.quantity, 3);
    });
  });

  group('manual adjustment', () {
    test('sets an exact quantity', () async {
      // Always available. The person holding the supplies is the authority;
      // automatic counting is only a convenience.
      final InventoryItem item = await stock(quantity: 5);

      await h.inventory.setQuantity(item.id, 12);

      expect((await h.inventory.findById(item.id))!.quantity, 12);
    });

    test('allows correcting down to zero', () async {
      final InventoryItem item = await stock(quantity: 5);

      await h.inventory.setQuantity(item.id, 0);

      expect((await h.inventory.findById(item.id))!.quantity, 0);
    });

    test('rejects a negative quantity', () async {
      final InventoryItem item = await stock(quantity: 5);

      expect(
        () => h.inventory.setQuantity(item.id, -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a negative minimum', () async {
      final InventoryItem item = await stock();

      expect(
        () => h.inventory.setMinimumQuantity(item.id, -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refreshes updatedAt', () async {
      final InventoryItem item = await stock(quantity: 5);
      h.clock.advance(const Duration(hours: 2));

      await h.inventory.setQuantity(item.id, 6);

      expect(
        (await h.inventory.findById(item.id))!.updatedAt,
        DateTime.utc(2026, 8, 17, 11),
      );
    });

    test('restock adds to what is already there', () async {
      final InventoryItem item = await stock(quantity: 2);

      await h.inventory.restock(item.id, 10);

      expect((await h.inventory.findById(item.id))!.quantity, 12);
    });

    test('restock rejects a negative amount', () async {
      final InventoryItem item = await stock(quantity: 2);

      expect(
        () => h.inventory.restock(item.id, -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('consume', () {
    test('takes one unit by default', () async {
      final InventoryItem item = await stock(quantity: 5);

      final int short = await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
      );

      expect(short, 0);
      expect((await h.inventory.findById(item.id))!.quantity, 4);
    });

    test('takes from the batch expiring soonest first', () async {
      final InventoryItem soon = await stock(
        quantity: 2,
        lotNumber: 'A',
        expirationDate: DateTime.utc(2026, 9, 1),
      );
      final InventoryItem later = await stock(
        quantity: 5,
        lotNumber: 'B',
        expirationDate: DateTime.utc(2027, 1, 1),
      );

      await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
      );

      expect((await h.inventory.findById(soon.id))!.quantity, 1);
      expect((await h.inventory.findById(later.id))!.quantity, 5);
    });

    test('spills into the next batch when one runs out', () async {
      final InventoryItem soon = await stock(
        quantity: 2,
        expirationDate: DateTime.utc(2026, 9, 1),
      );
      final InventoryItem later = await stock(
        quantity: 5,
        expirationDate: DateTime.utc(2027, 1, 1),
      );

      final int short = await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 4,
      );

      expect(short, 0);
      expect((await h.inventory.findById(soon.id))!.quantity, 0);
      expect((await h.inventory.findById(later.id))!.quantity, 3);
    });

    test('batches with no expiry are consumed last', () async {
      final InventoryItem dated = await stock(
        quantity: 3,
        expirationDate: DateTime.utc(2026, 9, 1),
      );
      final InventoryItem undated = await stock(quantity: 3);

      await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 2,
      );

      expect((await h.inventory.findById(dated.id))!.quantity, 1);
      expect((await h.inventory.findById(undated.id))!.quantity, 3);
    });

    test('reports a shortfall rather than going negative', () async {
      // Running out is normal for someone managing supplies. The count stays
      // truthful and the caller decides whether to say anything.
      final InventoryItem item = await stock(quantity: 2);

      final int short = await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 5,
      );

      expect(short, 3);
      expect((await h.inventory.findById(item.id))!.quantity, 0);
    });

    test('reports the full amount when there is no stock at all', () async {
      final int short = await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 2,
      );

      expect(short, 2);
    });

    test('consuming zero changes nothing', () async {
      final InventoryItem item = await stock(quantity: 3);

      final int short = await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 0,
      );

      expect(short, 0);
      expect((await h.inventory.findById(item.id))!.quantity, 3);
    });

    test('rejects a negative amount', () async {
      expect(
        () => h.inventory.consume(
          userProfileId: profile.id,
          consumableTypeId: sensor.id,
          amount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('does not touch another profile stock', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Lucas');
      final InventoryItem mine = await stock(quantity: 5);
      final InventoryItem theirs = await h.inventory.createItem(
        userProfileId: other.id,
        consumableTypeId: sensor.id,
        quantity: 5,
      );

      await h.inventory.consume(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        amount: 2,
      );

      expect((await h.inventory.findById(mine.id))!.quantity, 3);
      expect((await h.inventory.findById(theirs.id))!.quantity, 5);
    });
  });

  group('totals and warnings', () {
    test('totals across every batch and location', () async {
      await stock(quantity: 3, lotNumber: 'A');
      await stock(quantity: 4, lotNumber: 'B');

      expect(await h.inventory.totalQuantity(profile.id, sensor.id), 7);
    });

    test('totals zero when nothing is recorded', () async {
      expect(await h.inventory.totalQuantity(profile.id, sensor.id), 0);
    });

    test('warns at the minimum, not only below it', () async {
      await stock(quantity: 2, minimumQuantity: 2);

      expect(await h.inventory.findLowStock(profile.id), hasLength(1));
    });

    test('warns below the minimum', () async {
      await stock(quantity: 1, minimumQuantity: 2);

      expect(await h.inventory.findLowStock(profile.id), hasLength(1));
    });

    test('does not warn above the minimum', () async {
      await stock(quantity: 3, minimumQuantity: 2);

      expect(await h.inventory.findLowStock(profile.id), isEmpty);
    });

    test('a minimum of zero means do not warn me', () async {
      await stock(minimumQuantity: 0);

      expect(await h.inventory.findLowStock(profile.id), isEmpty);
    });

    test('warns when stock has run out entirely', () async {
      await stock(quantity: 0, minimumQuantity: 1);

      expect(await h.inventory.findLowStock(profile.id), hasLength(1));
    });
  });

  group('expiry', () {
    test('finds batches expiring on or before the cutoff', () async {
      await stock(quantity: 2, expirationDate: DateTime.utc(2026, 9, 1));
      await stock(quantity: 2, expirationDate: DateTime.utc(2027, 1, 1));

      final List<InventoryItem> expiring = await h.inventory.findExpiringBefore(
        profile.id,
        DateTime.utc(2026, 10, 1),
      );

      expect(expiring, hasLength(1));
    });

    test('includes a batch expiring exactly on the cutoff', () async {
      await stock(quantity: 2, expirationDate: DateTime.utc(2026, 10, 1));

      final List<InventoryItem> expiring = await h.inventory.findExpiringBefore(
        profile.id,
        DateTime.utc(2026, 10, 1),
      );

      expect(expiring, hasLength(1));
    });

    test('ignores empty batches', () async {
      // A lot with nothing left in it cannot expire on anyone.
      await stock(quantity: 0, expirationDate: DateTime.utc(2026, 9, 1));

      final List<InventoryItem> expiring = await h.inventory.findExpiringBefore(
        profile.id,
        DateTime.utc(2026, 10, 1),
      );

      expect(expiring, isEmpty);
    });

    test('ignores batches with no expiry recorded', () async {
      await stock(quantity: 5);

      final List<InventoryItem> expiring = await h.inventory.findExpiringBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(expiring, isEmpty);
    });

    test('orders soonest first', () async {
      await stock(quantity: 1, expirationDate: DateTime.utc(2026, 12, 1));
      await stock(quantity: 1, expirationDate: DateTime.utc(2026, 9, 1));

      final List<InventoryItem> expiring = await h.inventory.findExpiringBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(expiring.map((InventoryItem i) => i.expirationDate), <DateTime>[
        DateTime.utc(2026, 9, 1),
        DateTime.utc(2026, 12, 1),
      ]);
    });
  });
}
