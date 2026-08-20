import 'package:drift/drift.dart';

import 'consumable_types.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// Somewhere supplies are kept: home, backpack, school, dad's house, work.
///
/// Multiple locations are in the schema from Phase 1 even though the UI for
/// them lands in Phase 8, because a divorced family or a child at school is
/// exactly the situation AoiLoop exists for, and retrofitting locations onto
/// a flat count later would mean migrating every row.
@TableIndex(name: 'idx_inventory_locations_profile', columns: {#userProfileId})
class InventoryLocations extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Identifier of an icon in the app's own set, not a font code point, so
  /// changing the icon set does not corrupt saved rows.
  TextColumn get icon =>
      text().withLength(max: 40).withDefault(const Constant<String>('box'))();

  BoolColumn get active => boolean().withDefault(const Constant<bool>(true))();
}

/// A quantity of one consumable type, in one location, optionally from one
/// lot with one expiry date.
///
/// Modelled as a row per lot rather than a single running total, because
/// expiry tracking (release 0.4) is per-lot: "you have 8 sensors, 3 of which
/// expire next month" is the useful answer, and it is unreachable from a
/// single number.
@TableIndex(
  name: 'idx_inventory_items_profile_type',
  columns: {#userProfileId, #consumableTypeId},
)
@TableIndex(name: 'idx_inventory_items_expiration', columns: {#expirationDate})
class InventoryItems extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get consumableTypeId =>
      text().references(ConsumableTypes, #id, onDelete: KeyAction.restrict)();

  /// Null means "not filed anywhere in particular", which is where most people
  /// start before they set up locations.
  TextColumn get locationId => text().nullable().references(
    InventoryLocations,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Units in stock. Constrained to be non-negative by a check below: a
  /// negative count is always a bug, and letting it persist would quietly
  /// corrupt the low-stock warning that the user relies on.
  IntColumn get quantity => integer().withDefault(const Constant<int>(0))();

  /// Warn at or below this. Zero disables the warning.
  IntColumn get minimumQuantity =>
      integer().withDefault(const Constant<int>(0))();

  TextColumn get lotNumber => text().nullable().withLength(max: 60)();

  DateTimeColumn get expirationDate => dateTime().nullable()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (quantity >= 0)',
    'CHECK (minimum_quantity >= 0)',
  ];
}
