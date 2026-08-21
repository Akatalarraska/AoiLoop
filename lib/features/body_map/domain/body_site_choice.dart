import 'package:flutter/foundation.dart';

/// Where a change puts the new one.
///
/// A value rather than a bare `String?`, because three answers have to be told
/// apart and a nullable id only carries two: *put it here*, *do not record a
/// place at all*, and *I did not say* — which means wherever the last one was.
///
/// Collapsing the last two is a real bug rather than a tidiness point. It
/// makes "leave it unrecorded" silently keep the previous site, so the app
/// records a placement the user has just declined to give it.
@immutable
class BodySiteChoice {
  /// Record this site.
  const BodySiteChoice(this.siteId);

  /// Record no site at all. Tracking placement is a courtesy the app offers,
  /// not a toll it charges for logging a change.
  const BodySiteChoice.none() : siteId = null;

  final String? siteId;

  @override
  bool operator ==(Object other) =>
      other is BodySiteChoice && other.siteId == siteId;

  @override
  int get hashCode => siteId.hashCode;
}
