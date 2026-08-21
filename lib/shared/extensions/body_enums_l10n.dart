import '../../l10n/generated/app_localizations.dart';
import '../models/body_enums.dart';

/// Localised copy for [BodyRegion].
///
/// Lives here rather than on the enum so `body_enums.dart` stays pure Dart:
/// the enum is persisted and reasoned about in tests that never build a
/// widget, and it must not drag Flutter in.
extension BodyRegionL10n on BodyRegion {
  String label(AppLocalizations l10n) => switch (this) {
    BodyRegion.leftArm => l10n.bodyRegionLeftArm,
    BodyRegion.rightArm => l10n.bodyRegionRightArm,
    BodyRegion.upperLeftAbdomen => l10n.bodyRegionUpperLeftAbdomen,
    BodyRegion.upperRightAbdomen => l10n.bodyRegionUpperRightAbdomen,
    BodyRegion.lowerLeftAbdomen => l10n.bodyRegionLowerLeftAbdomen,
    BodyRegion.lowerRightAbdomen => l10n.bodyRegionLowerRightAbdomen,
    BodyRegion.leftThigh => l10n.bodyRegionLeftThigh,
    BodyRegion.rightThigh => l10n.bodyRegionRightThigh,
    BodyRegion.leftButtock => l10n.bodyRegionLeftButtock,
    BodyRegion.rightButtock => l10n.bodyRegionRightButtock,
    BodyRegion.other => l10n.bodyRegionOther,
  };
}

/// Localised copy for [BodyArea].
extension BodyAreaL10n on BodyArea {
  String label(AppLocalizations l10n) => switch (this) {
    BodyArea.arms => l10n.bodyAreaArms,
    BodyArea.abdomen => l10n.bodyAreaAbdomen,
    BodyArea.thighs => l10n.bodyAreaThighs,
    BodyArea.buttocks => l10n.bodyAreaButtocks,
    BodyArea.other => l10n.bodyAreaOther,
  };
}
