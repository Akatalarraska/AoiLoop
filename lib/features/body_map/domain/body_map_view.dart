import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// One place on the body, and what the user's own history says about it.
///
/// Everything here is a fact BlauLoop already holds: what is on it now, when
/// it was last used, how long it has been free since. Nothing here is a
/// suggestion. The app reports; it does not prescribe a site, and the closest
/// it ever comes is ordering by rest, which is arithmetic.
@immutable
class BodySiteCard {
  const BodySiteCard({
    required this.site,
    required this.lastUsedAt,
    required this.restingFor,
    this.occupant,
  });

  final BodySite site;

  /// When something was last *put* on this site, or null if nothing ever was.
  final DateTime? lastUsedAt;

  /// How long the site has been free.
  ///
  /// Null both when the site is occupied and when it has never been used —
  /// two states that are not rest and that read very differently, which is why
  /// neither is quietly reported as a duration.
  final Duration? restingFor;

  /// The consumable type currently on this site, if any.
  ///
  /// The *type*, not the instance: "CGM sensor" is what the user recognises,
  /// and it is the name they themselves gave it.
  final ConsumableType? occupant;

  BodyRegion get region => site.bodyRegion;

  BodyArea get area => region.area;

  bool get isOccupied => occupant != null;

  /// Never had anything on it. Distinct from a long rest: they look identical
  /// if you only report a duration, and they mean different things.
  bool get isUnused => lastUsedAt == null;

  /// Whole days of rest, rounded **down**.
  ///
  /// Down for the same reason every countdown in the app rounds down: a number
  /// rounded in the user's favour is a number that tells them a site has
  /// rested longer than it has.
  int? get restingDays => restingFor?.inDays;

  String get id => site.id;

  @override
  bool operator ==(Object other) =>
      other is BodySiteCard &&
      other.site == site &&
      other.lastUsedAt == lastUsedAt &&
      other.restingFor == restingFor &&
      other.occupant == occupant;

  @override
  int get hashCode => Object.hash(site, lastUsedAt, restingFor, occupant);
}

/// One group of sites, ready to render under a heading.
@immutable
class BodyAreaGroup {
  const BodyAreaGroup({required this.area, required this.cards});

  final BodyArea area;
  final List<BodySiteCard> cards;

  /// How many of this group's sites have something on them right now.
  int get occupiedCount =>
      cards.where((BodySiteCard card) => card.isOccupied).length;

  @override
  bool operator ==(Object other) =>
      other is BodyAreaGroup &&
      other.area == area &&
      listEquals(other.cards, cards);

  @override
  int get hashCode => Object.hash(area, Object.hashAll(cards));
}

/// Everything the body map renders, already joined, grouped and dated.
///
/// Assembled here rather than in the widget, so the grouping and the rest
/// arithmetic are unit-testable at an exact instant without pumping a frame —
/// the same arrangement `DashboardView` uses, for the same reason.
@immutable
class BodyMapView {
  const BodyMapView({
    required this.groups,
    required this.now,
    required this.longestRested,
  });

  /// Joins sites to their usage history and groups them by area.
  ///
  /// [lastUsedBySite] and [occupantBySite] are keyed by site id.
  factory BodyMapView.from({
    required List<BodySite> sites,
    required Map<String, DateTime?> lastUsedBySite,
    required Map<String, ConsumableType> occupantBySite,
    required DateTime now,
  }) {
    BodySiteCard cardFor(BodySite site) {
      final DateTime? lastUsed = lastUsedBySite[site.id];
      final ConsumableType? occupant = occupantBySite[site.id];

      return BodySiteCard(
        site: site,
        lastUsedAt: lastUsed,
        // Only a site that is both free and previously used has a rest to
        // report. A negative one is impossible from stored data but would be
        // nonsense on screen, so it is clamped rather than trusted.
        restingFor: occupant != null || lastUsed == null
            ? null
            : _nonNegative(now.difference(lastUsed)),
        occupant: occupant,
      );
    }

    final List<BodySiteCard> cards = sites.map(cardFor).toList();

    final List<BodyAreaGroup> groups = <BodyAreaGroup>[
      for (final BodyArea area in BodyArea.values)
        if (cards.where((BodySiteCard card) => card.area == area).toList()
            case final List<BodySiteCard> inArea when inArea.isNotEmpty)
          BodyAreaGroup(
            area: area,
            // Declaration order within a group, which puts left before right
            // consistently. Ordering these by rest as well would make the list
            // reshuffle itself between visits, and a control that moves is a
            // control people mistap.
            cards: inArea..sort(_byRegionOrder),
          ),
    ];

    return BodyMapView(
      groups: groups,
      now: now,
      longestRested: _longestRested(cards),
    );
  }

  final List<BodyAreaGroup> groups;

  /// The instant the rests were computed at. Held so the view is a value.
  final DateTime now;

  /// The site that has gone longest without being used, if there is one.
  ///
  /// A never-used site wins over any rested one, because it has by definition
  /// rested longer. This is the **only** ranking BlauLoop performs on body
  /// sites, and it is presented as a fact about the user's own history — not
  /// as a suggestion about where to put anything next.
  ///
  /// Null when every site is occupied, or when there are no sites at all.
  final BodySiteCard? longestRested;

  bool get isEmpty => groups.isEmpty;

  List<BodySiteCard> get cards => <BodySiteCard>[
    for (final BodyAreaGroup group in groups) ...group.cards,
  ];

  int get occupiedCount =>
      cards.where((BodySiteCard card) => card.isOccupied).length;

  /// The card for [siteId], or null if this profile has no such site.
  BodySiteCard? cardFor(String? siteId) {
    if (siteId == null) {
      return null;
    }
    for (final BodySiteCard card in cards) {
      if (card.id == siteId) {
        return card;
      }
    }
    return null;
  }

  static BodySiteCard? _longestRested(List<BodySiteCard> cards) {
    BodySiteCard? best;
    for (final BodySiteCard card in cards) {
      if (card.isOccupied) {
        continue;
      }
      if (best == null || _restsLongerThan(card, best)) {
        best = card;
      }
    }
    return best;
  }

  /// Whether [a] has been free longer than [b].
  ///
  /// Never used beats any rest. Between two never-used sites the tie is broken
  /// by id, so the answer does not move between rebuilds.
  static bool _restsLongerThan(BodySiteCard a, BodySiteCard b) {
    if (a.isUnused || b.isUnused) {
      return a.isUnused && (!b.isUnused || a.id.compareTo(b.id) < 0);
    }
    final Duration left = a.restingFor ?? Duration.zero;
    final Duration right = b.restingFor ?? Duration.zero;
    return left != right ? left > right : a.id.compareTo(b.id) < 0;
  }

  static int _byRegionOrder(BodySiteCard a, BodySiteCard b) {
    final int region = a.region.index.compareTo(b.region.index);
    return region != 0 ? region : a.id.compareTo(b.id);
  }

  static Duration _nonNegative(Duration value) =>
      value.isNegative ? Duration.zero : value;

  @override
  bool operator ==(Object other) =>
      other is BodyMapView &&
      other.now == now &&
      other.longestRested == longestRested &&
      listEquals(other.groups, groups);

  @override
  int get hashCode => Object.hash(now, longestRested, Object.hashAll(groups));
}
