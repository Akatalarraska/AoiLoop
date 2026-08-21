import '../../core/database/app_database.dart';
import '../../features/body_map/domain/body_map_view.dart';
import '../../l10n/generated/app_localizations.dart';

/// Localised copy for [BodySiteCard].
///
/// Lives here rather than on the model for the same reason every other
/// extension in this folder does: `body_map_view.dart` is plain Dart with no
/// Flutter binding, and the grouping and rest arithmetic are worth testing
/// without one.
extension BodySiteCardL10n on BodySiteCard {
  /// The one line that says what this site is doing.
  ///
  /// In use, never used, or free for so many days — in that order, because
  /// that is the order the answers matter in. *Never used* is deliberately not
  /// phrased as a duration: "free for 400 days" and "never used" are different
  /// facts, and only the second is true of a site nothing has ever touched.
  String stateLabel(AppLocalizations l10n) {
    if (occupant case final ConsumableType occupied) {
      return l10n.bodyMapInUse(occupied.name);
    }
    if (isUnused) {
      return l10n.bodyMapNeverUsed;
    }
    return l10n.bodyMapRestingDays(restingDays ?? 0);
  }

  /// What a screen reader announces: the place and its state as one sentence
  /// rather than two unrelated fragments.
  String semanticLabel(AppLocalizations l10n, String region) =>
      l10n.bodyMapSiteSemanticLabel(region, stateLabel(l10n));
}
