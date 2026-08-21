import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/changes/data/cycle_engine.dart';
import 'package:blauloop/features/incidents/domain/incident_report.dart';
import 'package:blauloop/features/inventory/domain/stock_draw.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Taking a unit out of the cupboard when a change is registered.
///
/// The count is a convenience on top of the log, and two rules keep it honest:
/// it never goes negative, and it never claims to know anything about a
/// consumable nobody is counting.
void main() {
  late TestHarness h;
  late CycleEngine engine;
  late UserProfile profile;
  late ConsumableType sensor;

  final DateTime installedAt = DateTime(2026, 8, 11, 12);

  setUp(() async {
    h = TestHarness.create(now: installedAt.toUtc());
    engine = h.cycleEngine();
    profile = await h.seedProfile();
    sensor = await h.seedType(
      name: 'Sensor',
      defaultDuration: const Duration(days: 10),
    );
  });

  Future<InventoryItem> stock(
    int quantity, {
    ConsumableType? type,
    DateTime? expires,
  }) {
    return h.inventory.createItem(
      userProfileId: profile.id,
      consumableTypeId: (type ?? sensor).id,
      quantity: quantity,
      expirationDate: expires,
    );
  }

  Future<CycleTransition> change({ConsumableType? type}) {
    return engine.registerChange(
      userProfileId: profile.id,
      type: type ?? sensor,
      changedAt: installedAt.add(const Duration(days: 3)),
    );
  }

  Future<int> total({ConsumableType? type}) =>
      h.inventory.totalQuantity(profile.id, (type ?? sensor).id);

  group('registering a change', () {
    test('takes exactly one unit out of stock', () async {
      await stock(5);

      final CycleTransition transition = await change();

      expect(await total(), 4);
      expect(transition.stock.tracked, isTrue);
      expect(transition.stock.requested, 1);
      expect(transition.stock.shortfall, 0);
      expect(transition.stock.remaining, 4);
    });

    test('takes from the batch expiring soonest', () async {
      final InventoryItem later = await stock(
        2,
        expires: installedAt.add(const Duration(days: 300)),
      );
      final InventoryItem soon = await stock(
        2,
        expires: installedAt.add(const Duration(days: 20)),
      );

      await change();

      expect((await h.inventory.findById(soon.id))!.quantity, 1);
      expect((await h.inventory.findById(later.id))!.quantity, 2);
    });

    test('spills into the next batch when one runs out', () async {
      final InventoryItem soon = await stock(
        1,
        expires: installedAt.add(const Duration(days: 20)),
      );
      final InventoryItem later = await stock(
        3,
        expires: installedAt.add(const Duration(days: 300)),
      );

      await engine.registerChange(
        userProfileId: profile.id,
        type: sensor,
        changedAt: installedAt.add(const Duration(days: 3)),
      );
      // A second change, which has to reach past the emptied batch.
      await engine.registerChange(
        userProfileId: profile.id,
        type: sensor,
        changedAt: installedAt.add(const Duration(days: 6)),
      );

      expect((await h.inventory.findById(soon.id))!.quantity, 0);
      expect((await h.inventory.findById(later.id))!.quantity, 3 - 1);
    });
  });

  group('running out', () {
    test('reports a shortfall rather than going negative', () async {
      // A negative count would quietly break the low-stock warning the user
      // relies on, and the CHECK constraint would refuse it anyway.
      await stock(0);

      final CycleTransition transition = await change();

      expect(await total(), 0);
      expect(transition.stock.shortfall, 1);
      expect(transition.stock.isWorthMentioning, isTrue);
    });

    test('records the change anyway', () async {
      // The log is the product; the count is a convenience on top of it. A
      // change refused because the cupboard was empty would lose the one fact
      // that actually matters.
      await stock(0);

      await change();

      expect(
        await h.instances.findActiveForType(profile.id, sensor.id),
        isNotNull,
      );
      expect(await h.db.select(h.db.changeEvents).get(), hasLength(1));
    });

    test('says so when that was the last one', () async {
      await stock(1);

      final CycleTransition transition = await change();

      expect(transition.stock.remaining, 0);
      expect(transition.stock.shortfall, 0);
      // Worth a word: a pharmacy trip planned a day early costs nothing and
      // one planned a day late costs a missed change.
      expect(transition.stock.isWorthMentioning, isTrue);
    });

    test('stays quiet while there is still some left', () async {
      await stock(5);

      final CycleTransition transition = await change();

      expect(transition.stock.isWorthMentioning, isFalse);
    });
  });

  group('consumables nobody is counting', () {
    test(
      'a type with no batches is left alone and reported as untracked',
      () async {
        final CycleTransition transition = await change();

        expect(transition.stock, const StockDraw.untracked());
        expect(transition.stock.isWorthMentioning, isFalse);
        expect(await h.db.select(h.db.inventoryItems).get(), isEmpty);
      },
    );

    test('a type with counting switched off is never touched', () async {
      // `tracksInventory` is the user's answer to whether they want this
      // counted. Creating and decrementing a row behind their back would be
      // overruling them.
      final ConsumableType strips = await h.seedType(
        name: 'Test strips',
        category: ConsumableCategory.testStrip,
        tracksInventory: false,
        defaultDuration: null,
      );
      await stock(10, type: strips);

      final CycleTransition transition = await change(type: strips);

      expect(await total(type: strips), 10);
      expect(transition.stock.tracked, isFalse);
    });
  });

  group('reporting a failure', () {
    Future<IncidentRecord> report(IncidentOutcome outcome) {
      return engine.reportIncident(
        userProfileId: profile.id,
        type: sensor,
        report: IncidentReport(
          type: IncidentType.occlusion,
          occurredAt: installedAt.add(const Duration(days: 3)),
          outcome: outcome,
        ),
      );
    }

    setUp(() async {
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: installedAt,
        expectedChangeAt: installedAt.add(const Duration(days: 10)),
      );
    });

    test('a replacement takes one out, like any other change', () async {
      await stock(5);

      final IncidentRecord record = await report(IncidentOutcome.replaced);

      expect(await total(), 4);
      expect(record.stock.remaining, 4);
    });

    test('taking it off without replacing takes nothing', () async {
      // Nothing new went on. The failed one left the cupboard when it was
      // installed, and charging for it twice would be a second lie.
      await stock(5);

      final IncidentRecord record = await report(IncidentOutcome.removed);

      expect(await total(), 5);
      expect(record.stock.tracked, isFalse);
    });

    test('keeping it on takes nothing either', () async {
      await stock(5);

      await report(IncidentOutcome.keptInUse);

      expect(await total(), 5);
    });
  });
}
