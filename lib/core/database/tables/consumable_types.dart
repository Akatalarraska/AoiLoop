import 'package:drift/drift.dart';

import '../../../shared/models/consumable_enums.dart';
import '../converters/reminder_offsets_converter.dart';
import 'table_mixins.dart';

/// A *kind* of consumable — "Dexcom G7 sensor", "Medtronic reservoir",
/// "my overpatches" — as opposed to a specific one in use.
///
/// This is where the user's settings for a product live: how long it lasts,
/// whether it has a countdown at all, whether to count stock, and when to be
/// reminded. `ConsumableInstances` then records each individual unit.
///
/// There is no `userProfileId` here on purpose. A type describes a product,
/// and a family sharing the same sensors should share one definition of it.
/// [isBuiltIn] separates the presets AoiLoop ships from types the user
/// created.
@TableIndex(name: 'idx_consumable_types_active', columns: {#active})
class ConsumableTypes extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get name => text().withLength(min: 1, max: 80)();

  TextColumn get category => textEnum<ConsumableCategory>()();

  /// Expected life, in minutes. Null when the item has no wear cycle — a box
  /// of test strips is counted, not timed.
  ///
  /// Minutes rather than days because real durations are not whole days:
  /// a sensor is 10 days, a set is 72 hours, a pod is 72 hours plus an 8 hour
  /// grace period.
  IntColumn get defaultDurationMinutes => integer().nullable()();

  /// Whether this type gets a countdown and reminders.
  BoolColumn get tracksCycle =>
      boolean().withDefault(const Constant<bool>(true))();

  /// Whether stock of this type is counted in inventory.
  BoolColumn get tracksInventory =>
      boolean().withDefault(const Constant<bool>(true))();

  /// Lead times for reminders before the expected change, normalised
  /// longest-first. An entry of `Duration.zero` means "at the moment it is
  /// due".
  TextColumn get defaultReminderOffsets => text()
      .map(const ReminderOffsetsConverter())
      .withDefault(const Constant<String>(''))();

  /// True for presets AoiLoop ships, false for types the user created.
  ///
  /// Built-in types can be edited — a user whose clinic gets 7 days out of a
  /// 10 day sensor should be able to say so — but they are never deleted, so
  /// history keeps its labels.
  BoolColumn get isBuiltIn =>
      boolean().withDefault(const Constant<bool>(false))();

  /// Hidden from pickers when false. Deactivated rather than deleted, so past
  /// changes referencing this type still render.
  BoolColumn get active => boolean().withDefault(const Constant<bool>(true))();
}
