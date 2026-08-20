import 'package:drift/drift.dart';

import '../../../shared/models/body_enums.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// A place on the body where a consumable can be placed.
///
/// Sites belong to a profile because they are personal: someone may not use
/// their thighs at all, and someone else may have named spots that mean
/// nothing to anyone else.
///
/// AoiLoop records placement and reports usage. It does not recommend sites.
@TableIndex(name: 'idx_body_sites_profile', columns: {#userProfileId})
class BodySites extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get bodyRegion => textEnum<BodyRegion>()();

  /// Usually derivable from [bodyRegion], but stored so that a custom site
  /// (`BodyRegion.other`) can still say which side it is on.
  TextColumn get side => textEnum<BodySide>()();

  /// The user's own name for this spot, when the region is not specific
  /// enough — "left love handle", "high on the arm".
  TextColumn get customName => text().nullable().withLength(max: 60)();

  /// Optional position within the region, 0..1 from the top-left of the body
  /// diagram. Lets the user mark an exact spot without the region enum having
  /// to grow forever.
  RealColumn get normalizedX => real().nullable()();
  RealColumn get normalizedY => real().nullable()();

  /// Deactivated rather than deleted, so past usage keeps its location.
  BoolColumn get active => boolean().withDefault(const Constant<bool>(true))();
}
