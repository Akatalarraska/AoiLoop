import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';
import '../domain/stock_draw.dart';

/// Reads and writes supply counts and the places they are kept.
///
/// Quantities are never allowed below zero — a CHECK constraint refuses it at
/// the database. A negative count is always a bug, and a silently negative one
/// would quietly break the low-stock warning the user relies on.
class InventoryRepository extends Repository {
  const InventoryRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  // --- Locations ----------------------------------------------------------

  Stream<List<InventoryLocation>> watchLocations(String userProfileId) {
    return (db.select(db.inventoryLocations)
          ..where(
            ($InventoryLocationsTable t) =>
                t.userProfileId.equals(userProfileId) & t.active.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<$InventoryLocationsTable>>[
            ($InventoryLocationsTable t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<InventoryLocation> createLocation({
    required String userProfileId,
    required String name,
    String icon = 'box',
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.inventoryLocations)
        .insertReturning(
          InventoryLocationsCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            name: name,
            icon: Value<String>(icon),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> deactivateLocation(String id) async {
    await (db.update(
      db.inventoryLocations,
    )..where(($InventoryLocationsTable t) => t.id.equals(id))).write(
      InventoryLocationsCompanion(
        active: const Value<bool>(false),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  // --- Items --------------------------------------------------------------

  Stream<List<InventoryItem>> watchItems(String userProfileId) {
    return (db.select(db.inventoryItems)
          ..where(
            ($InventoryItemsTable t) => t.userProfileId.equals(userProfileId),
          )
          ..orderBy(<OrderClauseGenerator<$InventoryItemsTable>>[
            ($InventoryItemsTable t) =>
                OrderingTerm.asc(t.expirationDate, nulls: NullsOrder.last),
          ]))
        .watch();
  }

  Future<InventoryItem?> findById(String id) {
    return (db.select(
      db.inventoryItems,
    )..where(($InventoryItemsTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<InventoryItem>> findByType(
    String userProfileId,
    String consumableTypeId,
  ) {
    return (db.select(db.inventoryItems)
          ..where(
            ($InventoryItemsTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.consumableTypeId.equals(consumableTypeId),
          )
          // Oldest expiry first, so consumption takes from the batch that will
          // go off soonest.
          ..orderBy(<OrderClauseGenerator<$InventoryItemsTable>>[
            ($InventoryItemsTable t) =>
                OrderingTerm.asc(t.expirationDate, nulls: NullsOrder.last),
          ]))
        .get();
  }

  Future<InventoryItem> createItem({
    required String userProfileId,
    required String consumableTypeId,
    int quantity = 0,
    int minimumQuantity = 0,
    String? locationId,
    String? lotNumber,
    DateTime? expirationDate,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.inventoryItems)
        .insertReturning(
          InventoryItemsCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            consumableTypeId: consumableTypeId,
            quantity: Value<int>(quantity),
            minimumQuantity: Value<int>(minimumQuantity),
            locationId: Value<String?>(locationId),
            lotNumber: Value<String?>(lotNumber),
            expirationDate: Value<DateTime?>(expirationDate?.toUtc()),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  /// Sets an exact quantity, as the user correcting the count by hand.
  ///
  /// Always available. Automatic decrementing is a convenience, and a
  /// convenience the user cannot override is a trap — counts drift, boxes get
  /// borrowed, and the person holding the supplies is the authority.
  Future<void> setQuantity(String id, int quantity) async {
    if (quantity < 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Inventory quantity cannot be negative',
      );
    }
    await (db.update(
      db.inventoryItems,
    )..where(($InventoryItemsTable t) => t.id.equals(id))).write(
      InventoryItemsCompanion(
        quantity: Value<int>(quantity),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  Future<void> setMinimumQuantity(String id, int minimumQuantity) async {
    if (minimumQuantity < 0) {
      throw ArgumentError.value(
        minimumQuantity,
        'minimumQuantity',
        'Minimum quantity cannot be negative',
      );
    }
    await (db.update(
      db.inventoryItems,
    )..where(($InventoryItemsTable t) => t.id.equals(id))).write(
      InventoryItemsCompanion(
        minimumQuantity: Value<int>(minimumQuantity),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Takes [amount] units of a consumable type out of stock.
  ///
  /// Consumes from the batch expiring soonest first, spilling into later
  /// batches when one runs out. Returns how many units it could not find.
  ///
  /// A shortfall is reported rather than thrown, and rather than pushing a
  /// count negative: running out is a normal situation for someone managing
  /// supplies, and the caller decides whether it is worth telling the user
  /// about. The count stays truthful either way.
  Future<int> consume({
    required String userProfileId,
    required String consumableTypeId,
    int amount = 1,
  }) async {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'Cannot consume a negative');
    }
    if (amount == 0) {
      return 0;
    }

    return db.transaction(() async {
      final List<InventoryItem> batches = await findByType(
        userProfileId,
        consumableTypeId,
      );

      int remaining = amount;
      final DateTime timestamp = now;

      for (final InventoryItem batch in batches) {
        if (remaining == 0) {
          break;
        }
        final int taken = batch.quantity < remaining
            ? batch.quantity
            : remaining;
        if (taken == 0) {
          continue;
        }
        await (db.update(
          db.inventoryItems,
        )..where(($InventoryItemsTable t) => t.id.equals(batch.id))).write(
          InventoryItemsCompanion(
            quantity: Value<int>(batch.quantity - taken),
            updatedAt: Value<DateTime>(timestamp),
          ),
        );
        remaining -= taken;
      }

      return remaining;
    });
  }

  /// Takes stock for one registered change, and says what it found.
  ///
  /// The difference from [consume] is the distinction it preserves: a
  /// consumable with no batches at all is *not counted*, which is not the same
  /// as counted and empty. Telling someone who never set inventory up that
  /// they have run out would be an invention.
  Future<StockDraw> draw({
    required String userProfileId,
    required String consumableTypeId,
    int amount = 1,
  }) async {
    final List<InventoryItem> before = await findByType(
      userProfileId,
      consumableTypeId,
    );
    if (before.isEmpty) {
      return const StockDraw.untracked();
    }

    final int shortfall = await consume(
      userProfileId: userProfileId,
      consumableTypeId: consumableTypeId,
      amount: amount,
    );

    return StockDraw(
      tracked: true,
      requested: amount,
      shortfall: shortfall,
      remaining: await totalQuantity(userProfileId, consumableTypeId),
    );
  }

  /// Sets the level to warn at for a whole consumable type.
  ///
  /// The column lives on the batch because expiry does, but nobody thinks in
  /// per-lot minimums — "warn me below five sensors" is about the sensors, not
  /// about one carton. So the figure is written to every batch of the type,
  /// which keeps it identical wherever it is read from.
  ///
  /// A type with no batches gets an empty one, so a minimum can be set before
  /// any stock exists. The alternative is refusing to take the answer until
  /// the user has typed a quantity they may not know yet.
  Future<void> setTypeMinimum({
    required String userProfileId,
    required String consumableTypeId,
    required int minimum,
  }) async {
    if (minimum < 0) {
      throw ArgumentError.value(
        minimum,
        'minimum',
        'Minimum quantity cannot be negative',
      );
    }

    await db.transaction(() async {
      final List<InventoryItem> batches = await findByType(
        userProfileId,
        consumableTypeId,
      );

      if (batches.isEmpty) {
        await createItem(
          userProfileId: userProfileId,
          consumableTypeId: consumableTypeId,
          minimumQuantity: minimum,
        );
        return;
      }

      for (final InventoryItem batch in batches) {
        await setMinimumQuantity(batch.id, minimum);
      }
    });
  }

  /// Adds [amount] units to a specific batch.
  Future<void> restock(String id, int amount) async {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'Cannot restock a negative');
    }
    await db.transaction(() async {
      final InventoryItem? item = await findById(id);
      if (item == null) {
        return;
      }
      await setQuantity(id, item.quantity + amount);
    });
  }

  /// Total units of a consumable type across every batch and location.
  Future<int> totalQuantity(
    String userProfileId,
    String consumableTypeId,
  ) async {
    final Expression<int> total = db.inventoryItems.quantity.sum();
    final TypedResult row =
        await (db.selectOnly(db.inventoryItems)
              ..addColumns(<Expression<Object>>[total])
              ..where(
                db.inventoryItems.userProfileId.equals(userProfileId) &
                    db.inventoryItems.consumableTypeId.equals(consumableTypeId),
              ))
            .getSingle();
    return row.read(total) ?? 0;
  }

  /// Batches at or below their own minimum, where a minimum was set.
  ///
  /// A minimum of zero means "do not warn me", so those never appear.
  Future<List<InventoryItem>> findLowStock(String userProfileId) {
    return (db.select(db.inventoryItems)..where(
          ($InventoryItemsTable t) =>
              t.userProfileId.equals(userProfileId) &
              t.minimumQuantity.isBiggerThanValue(0) &
              t.quantity.isSmallerOrEqual(t.minimumQuantity),
        ))
        .get();
  }

  /// Batches expiring on or before [cutoff], soonest first.
  Future<List<InventoryItem>> findExpiringBefore(
    String userProfileId,
    DateTime cutoff,
  ) {
    return (db.select(db.inventoryItems)
          ..where(
            ($InventoryItemsTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.quantity.isBiggerThanValue(0) &
                t.expirationDate.isNotNull() &
                t.expirationDate.isSmallerOrEqualValue(cutoff.toUtc()),
          )
          ..orderBy(<OrderClauseGenerator<$InventoryItemsTable>>[
            ($InventoryItemsTable t) => OrderingTerm.asc(t.expirationDate),
          ]))
        .get();
  }

  Future<void> deleteItem(String id) async {
    await (db.delete(
      db.inventoryItems,
    )..where(($InventoryItemsTable t) => t.id.equals(id))).go();
  }
}

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>((Ref ref) {
      return InventoryRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
