import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/cycle_countdown.dart';
import '../../../shared/models/cycle_status.dart';

/// One consumable type, and whatever is currently in use for it.
///
/// The dashboard is built from *types*, not from instances. A user who has
/// just finished onboarding owns five tracked types and zero instances, and a
/// dashboard driven by instances would greet them with an empty screen — the
/// exact moment they are deciding whether the app was worth installing. Every
/// type they chose gets a card; the ones with nothing in use say so.
@immutable
class DashboardCard {
  const DashboardCard({
    required this.type,
    required this.instance,
    required this.countdown,
  });

  final ConsumableType type;

  /// What is in use right now, or null if nothing is.
  final ConsumableInstance? instance;

  final CycleCountdown countdown;

  CycleStatus get status => countdown.status;

  /// Whether a change has ever been registered for this type.
  ///
  /// Distinct from [CycleCountdown.isTracked]: a type can have an instance
  /// with no deadline, which is in use but not counting down.
  bool get hasStarted => instance != null;

  /// Stable across rebuilds, so cards keep their widget state when the list
  /// reorders around them.
  String get id => type.id;

  @override
  bool operator ==(Object other) =>
      other is DashboardCard &&
      other.type == type &&
      other.instance == instance &&
      other.countdown == countdown;

  @override
  int get hashCode => Object.hash(type, instance, countdown);
}

/// Everything the dashboard renders, already joined, sorted and dated.
///
/// Assembled by [DashboardView.from] rather than by the widget, so the
/// ordering rules and the "what is next" question are unit-testable without
/// pumping a frame.
@immutable
class DashboardView {
  const DashboardView({
    required this.profile,
    required this.cards,
    required this.now,
  });

  /// Joins types to their active instances and orders the result.
  ///
  /// [instances] may contain rows for types that are not in [types] — a type
  /// deactivated while something was still in use. Those are dropped: the
  /// dashboard shows what the user asked to track, and history keeps the rest.
  factory DashboardView.from({
    required UserProfile profile,
    required List<ConsumableType> types,
    required List<ConsumableInstance> instances,
    required DateTime now,
    CycleStatusThresholds thresholds = CycleStatusThresholds.defaults,
  }) {
    final Map<String, ConsumableInstance> byType = <String, ConsumableInstance>{
      for (final ConsumableInstance instance in instances)
        instance.consumableTypeId: instance,
    };

    DashboardCard cardFor(ConsumableType type) {
      final ConsumableInstance? instance = byType[type.id];
      return DashboardCard(
        type: type,
        instance: instance,
        countdown: instance == null
            ? CycleCountdown.inactive
            : CycleCountdown.at(
                installedAt: instance.installedAt,
                expectedChangeAt: instance.expectedChangeAt,
                now: now,
                thresholds: thresholds,
              ),
      );
    }

    final List<DashboardCard> cards = types.map(cardFor).toList()
      ..sort(_byUrgencyThenDeadline);

    return DashboardView(profile: profile, cards: cards, now: now);
  }

  final UserProfile profile;

  /// Every tracked type, most urgent first.
  final List<DashboardCard> cards;

  /// The instant these countdowns were computed at. Held so the view is a
  /// value — two views built a minute apart are not equal, which is what
  /// makes the screen rebuild.
  final DateTime now;

  bool get isEmpty => cards.isEmpty;

  /// The change to deal with next.
  ///
  /// "Next" by urgency, not by calendar: someone with a sensor two days
  /// overdue and a set due tomorrow should be pointed at the sensor. Null
  /// when nothing is counting down, which after onboarding is the normal
  /// case until the first change is registered.
  DashboardCard? get nextChange {
    for (final DashboardCard card in cards) {
      if (card.countdown.isTracked) {
        return card;
      }
    }
    return null;
  }

  /// How many cards are asking for something. Drives the badge on the
  /// summary, and reads as zero on a good day.
  int get needsAttentionCount =>
      cards.where((DashboardCard card) => card.status.needsAttention).length;

  /// Cards for types nothing has ever been registered against.
  int get notStartedCount =>
      cards.where((DashboardCard card) => !card.hasStarted).length;

  /// Urgency first, then the nearest deadline, then the name.
  ///
  /// The name is the last tiebreak rather than the first so that the list
  /// stays stable: two cards in the same state with the same deadline should
  /// not swap places between rebuilds.
  static int _byUrgencyThenDeadline(DashboardCard a, DashboardCard b) {
    final int urgency = a.status.urgencyRank.compareTo(b.status.urgencyRank);
    if (urgency != 0) {
      return urgency;
    }

    final Duration? left = a.countdown.remaining;
    final Duration? right = b.countdown.remaining;
    if (left != null && right != null && left != right) {
      return left.compareTo(right);
    }

    final int name = a.type.name.toLowerCase().compareTo(
      b.type.name.toLowerCase(),
    );
    return name != 0 ? name : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardView &&
      other.profile == profile &&
      other.now == now &&
      listEquals(other.cards, cards);

  @override
  int get hashCode => Object.hash(profile, now, Object.hashAll(cards));
}
