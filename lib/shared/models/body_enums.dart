/// Enumerations for the body map.
///
/// BlauLoop records **where things were placed and when**. It does not
/// recommend sites, does not rank them, and does not interpret reactions.
/// The most it will ever say is "least recently used", which is arithmetic,
/// not advice.
///
/// Stored by name. See `profile_enums.dart` for why.
library;

/// A region of the body a consumable can be placed on.
///
/// Regions are coarse on purpose. Finer placement is captured by the optional
/// normalised coordinates on a `BodySite`, so the user can mark an exact spot
/// without the app pretending to a precision it does not have.
enum BodyRegion {
  leftArm,
  rightArm,
  upperLeftAbdomen,
  upperRightAbdomen,
  lowerLeftAbdomen,
  lowerRightAbdomen,
  leftThigh,
  rightThigh,
  leftButtock,
  rightButtock,

  /// Anywhere else the user wants to record, named by them.
  other,
}

/// A group of regions that sit together on the body.
///
/// Exists for one reason: ten regions in a flat list is a wall of text, and
/// the thing a user is actually doing is finding "the arm" and then picking a
/// side. Grouping turns one long scan into two short ones.
///
/// It is presentation vocabulary that happens to be pure Dart, so it lives
/// beside the enum it derives from rather than in a widget.
enum BodyArea {
  arms,
  abdomen,
  thighs,
  buttocks,

  /// Whatever the user named themselves.
  other,
}

extension BodyRegionX on BodyRegion {
  /// The group this region belongs to.
  BodyArea get area => switch (this) {
    BodyRegion.leftArm || BodyRegion.rightArm => BodyArea.arms,
    BodyRegion.upperLeftAbdomen ||
    BodyRegion.upperRightAbdomen ||
    BodyRegion.lowerLeftAbdomen ||
    BodyRegion.lowerRightAbdomen => BodyArea.abdomen,
    BodyRegion.leftThigh || BodyRegion.rightThigh => BodyArea.thighs,
    BodyRegion.leftButtock || BodyRegion.rightButtock => BodyArea.buttocks,
    BodyRegion.other => BodyArea.other,
  };

  /// Which side of the body this region is on, derived from the region itself.
  BodySide get side => switch (this) {
    BodyRegion.leftArm ||
    BodyRegion.upperLeftAbdomen ||
    BodyRegion.lowerLeftAbdomen ||
    BodyRegion.leftThigh ||
    BodyRegion.leftButtock => BodySide.left,
    BodyRegion.rightArm ||
    BodyRegion.upperRightAbdomen ||
    BodyRegion.lowerRightAbdomen ||
    BodyRegion.rightThigh ||
    BodyRegion.rightButtock => BodySide.right,
    BodyRegion.other => BodySide.notApplicable,
  };

  /// Whether this region is seen from the front of the body. Buttocks are the
  /// only rear regions in the default set.
  bool get isFrontView => switch (this) {
    BodyRegion.leftButtock || BodyRegion.rightButtock => false,
    BodyRegion.other => true,
    _ => true,
  };

  /// Regions offered by default when a profile is created.
  static const List<BodyRegion> defaults = <BodyRegion>[
    BodyRegion.leftArm,
    BodyRegion.rightArm,
    BodyRegion.upperLeftAbdomen,
    BodyRegion.upperRightAbdomen,
    BodyRegion.lowerLeftAbdomen,
    BodyRegion.lowerRightAbdomen,
    BodyRegion.leftThigh,
    BodyRegion.rightThigh,
    BodyRegion.leftButtock,
    BodyRegion.rightButtock,
  ];
}

/// Which side of the body a site is on.
enum BodySide {
  left,
  right,

  /// Midline, e.g. central abdomen.
  center,

  /// Not meaningful for this site.
  notApplicable,
}
