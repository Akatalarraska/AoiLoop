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
/// [isBuiltIn] separates the presets BlauLoop ships from types the user
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

  /// The time of day changes of *this* type should land on, as minutes since
  /// local midnight. Null means "whatever the profile prefers".
  ///
  /// Null is inheritance, not absence. The profile's
  /// `preferredChangeMinuteOfDay` stays the live default rather than being
  /// copied in here at creation, so a user who later moves their general
  /// change time moves every type they never singled out — which is the only
  /// behaviour that makes the word *default* mean anything.
  ///
  /// It exists because one hour does not fit every product. A sensor is
  /// comfortably changed on a Sunday morning; a set at 22:00 before bed. A
  /// single profile-wide time forces one of the two to be wrong, and a
  /// deadline the user quietly disagrees with is a deadline they start
  /// ignoring.
  IntColumn get preferredChangeMinuteOfDay => integer().nullable()();

  /// Lead times for reminders before the expected change, normalised
  /// longest-first. An entry of `Duration.zero` means "at the moment it is
  /// due".
  TextColumn get defaultReminderOffsets => text()
      .map(const ReminderOffsetsConverter())
      .withDefault(const Constant<String>(''))();

  /// True for presets BlauLoop ships, false for types the user created.
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
