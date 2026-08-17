import 'package:drift/drift.dart';

import '../../../shared/models/profile_enums.dart';
import 'table_mixins.dart';

/// The person whose devices and supplies are being tracked.
///
/// There is exactly one profile in the MVP. The table is shaped for several
/// from the start — every other table carries a `userProfileId` — so that
/// managing a child's profile (release 0.2) is a feature, not a migration of
/// the entire schema.
class UserProfiles extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get displayName => text().withLength(min: 1, max: 80)();

  /// Optional, and only a year. DT1FLOW has no use for a full date of birth,
  /// so it does not ask for one — a year is enough to phrase copy
  /// appropriately for a child.
  IntColumn get birthYear => integer().nullable()();

  /// IANA time zone name, e.g. `Europe/Madrid`.
  ///
  /// Stored rather than read from the OS at each use, because a change to it
  /// must trigger a deliberate recalculation of scheduled reminders rather
  /// than silently shifting every deadline mid-flight.
  TextColumn get timezone => text().withLength(min: 1, max: 64)();

  /// BCP 47 language code, e.g. `es` or `en`.
  TextColumn get languageCode => text().withLength(min: 2, max: 8)();

  /// The hour of day the user prefers to make changes, as minutes since local
  /// midnight. Null means they have not expressed a preference.
  ///
  /// When a sensor fails at 03:17 and is replaced immediately, the next change
  /// would fall at 03:17 forever. DT1FLOW offers to move it here instead — it
  /// asks, and never shifts a date silently.
  IntColumn get preferredChangeMinuteOfDay => integer().nullable()();

  TextColumn get glucoseUnit => textEnum<GlucoseUnit>()();

  TextColumn get treatmentType => textEnum<TreatmentType>()();
}
