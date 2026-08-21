import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// How a consumable's stock is doing.
///
/// Derived, never stored — the same arrangement as `CycleStatus`, and for the
/// same reason: a stored level goes stale the moment a count changes, and a
/// derived one cannot.
enum StockLevel {
  /// Counted, and comfortably above the minimum.
  ok,

  /// Counted, and at or below the minimum the user set.
  low,

  /// Counted, and there are none left.
  out,

  /// Nothing has ever been added, so there is no count to be right or wrong.
  /// Distinct from [out]: zero is a fact, and *unknown* is not.
  untracked;

  bool get needsAttention => this == StockLevel.low || this == StockLevel.out;

  /// Lowest sorts first, so the screen leads with what is missing.
  int get urgencyRank => switch (this) {
    StockLevel.out => 0,
    StockLevel.low => 1,
    StockLevel.ok => 2,
    StockLevel.untracked => 3,
  };
}

/// One consumable type and everything stocked of it.
@immutable
class InventoryCard {
  const InventoryCard({
    required this.type,
    required this.batches,
    required this.total,
    required this.minimum,
  });

  final ConsumableType type;

  /// Every batch of this type, soonest expiry first — the order stock is
  /// consumed in.
  final List<InventoryItem> batches;

  /// Units across every batch and location.
  final int total;

  /// Warn at or below this. Zero means the user does not want warning.
  ///
  /// Read as the **highest** minimum across the batches. The column lives on
  /// the batch because expiry does, but nobody thinks in per-lot minimums —
  /// "warn me below five sensors" is about the sensors, not about a carton.
  /// Writing the same figure to every batch keeps the two readings identical;
  /// taking the maximum is what makes a stray older value harmless rather
  /// than silently lowering the threshold.
  final int minimum;

  StockLevel get level {
    if (batches.isEmpty) {
      return StockLevel.untracked;
    }
    if (total == 0) {
      return StockLevel.out;
    }
    return minimum > 0 && total <= minimum ? StockLevel.low : StockLevel.ok;
  }

  bool get isTracked => batches.isNotEmpty;

  /// How many batches carry an expiry date. Expiry alerts are 0.4; this is
  /// only what the screen needs to decide whether to show the dates at all.
  bool get hasDatedBatches =>
      batches.any((InventoryItem item) => item.expirationDate != null);

  String get id => type.id;

  @override
  bool operator ==(Object other) =>
      other is InventoryCard &&
      other.type == type &&
      other.total == total &&
      other.minimum == minimum &&
      listEquals(other.batches, batches);

  @override
  int get hashCode =>
      Object.hash(type, total, minimum, Object.hashAll(batches));
}

/// Everything the inventory screen renders, already joined and ordered.
///
/// Assembled here rather than in the widget, so the totals, the low-stock rule
/// and the ordering are unit-testable without pumping a frame.
@immutable
class InventoryView {
  const InventoryView({required this.cards, required this.locations});

  /// Joins types to their batches.
  ///
  /// [types] should already be filtered to the ones that count stock; a type
  /// the user turned inventory off for has no business appearing with a total
  /// of zero next to things they actually count.
  factory InventoryView.from({
    required List<ConsumableType> types,
    required List<InventoryItem> items,
    required List<InventoryLocation> locations,
  }) {
    final Map<String, List<InventoryItem>> byType =
        <String, List<InventoryItem>>{};
    for (final InventoryItem item in items) {
      byType
          .putIfAbsent(item.consumableTypeId, () => <InventoryItem>[])
          .add(item);
    }

    InventoryCard cardFor(ConsumableType type) {
      final List<InventoryItem> batches = byType[type.id] ?? <InventoryItem>[];
      batches.sort(_bySoonestExpiry);

      return InventoryCard(
        type: type,
        batches: List<InventoryItem>.unmodifiable(batches),
        total: batches.fold<int>(
          0,
          (int sum, InventoryItem item) => sum + item.quantity,
        ),
        minimum: batches.fold<int>(
          0,
          (int highest, InventoryItem item) =>
              item.minimumQuantity > highest ? item.minimumQuantity : highest,
        ),
      );
    }

    final List<InventoryCard> cards = types.map(cardFor).toList()
      ..sort(_byUrgencyThenName);

    return InventoryView(
      cards: List<InventoryCard>.unmodifiable(cards),
      locations: List<InventoryLocation>.unmodifiable(locations),
    );
  }

  final List<InventoryCard> cards;
  final List<InventoryLocation> locations;

  bool get isEmpty => cards.isEmpty;

  /// Cards asking for a trip to the pharmacy.
  List<InventoryCard> get needingAttention => <InventoryCard>[
    for (final InventoryCard card in cards)
      if (card.level.needsAttention) card,
  ];

  int get lowCount => needingAttention.length;

  /// Whether anything is counted at all. False right up until the user adds
  /// their first box, which is the state every profile starts in.
  bool get hasAnyStock => cards.any((InventoryCard card) => card.isTracked);

  InventoryCard? cardFor(String typeId) {
    for (final InventoryCard card in cards) {
      if (card.id == typeId) {
        return card;
      }
    }
    return null;
  }

  /// Soonest expiry first, which is both the order stock is consumed in and
  /// the order worth reading: the batch about to go off is the one the eye
  /// should land on.
  static int _bySoonestExpiry(InventoryItem a, InventoryItem b) {
    final DateTime? left = a.expirationDate;
    final DateTime? right = b.expirationDate;
    if (left == null && right == null) {
      return a.id.compareTo(b.id);
    }
    // A batch with no date sorts last rather than first. SQLite orders NULL
    // before everything, which would put the undated carton above the one
    // going off next week.
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    final int byDate = left.compareTo(right);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  /// What is missing first, then alphabetically.
  ///
  /// The name is the tiebreak rather than the lead so the list does not
  /// reshuffle itself between rebuilds.
  static int _byUrgencyThenName(InventoryCard a, InventoryCard b) {
    final int urgency = a.level.urgencyRank.compareTo(b.level.urgencyRank);
    if (urgency != 0) {
      return urgency;
    }
    final int name = a.type.name.toLowerCase().compareTo(
      b.type.name.toLowerCase(),
    );
    return name != 0 ? name : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryView &&
      listEquals(other.cards, cards) &&
      listEquals(other.locations, locations);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(cards), Object.hashAll(locations));
}
