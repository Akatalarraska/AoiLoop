import 'package:flutter/foundation.dart';

/// What taking stock for one change actually found.
///
/// Three outcomes matter and a bare number carries two of them. Someone who
/// never set inventory up must not be told they have run out — they have not
/// run out, they are simply not counting — and someone who *is* counting and
/// has hit zero deserves to hear about it while they are still holding their
/// phone.
@immutable
class StockDraw {
  const StockDraw({
    required this.tracked,
    required this.requested,
    required this.shortfall,
    required this.remaining,
  });

  /// Nothing was counted for this consumable, so nothing was taken.
  const StockDraw.untracked()
    : tracked = false,
      requested = 0,
      shortfall = 0,
      remaining = 0;

  /// Whether this consumable has any stock rows at all.
  final bool tracked;

  /// Units the change asked for.
  final int requested;

  /// Units it could not find. Reported rather than thrown, and never taken by
  /// pushing a count negative: running out is an ordinary situation for
  /// somebody managing supplies, and a count that lies about it is worse than
  /// one that admits it.
  final int shortfall;

  /// Units left across every batch afterwards.
  final int remaining;

  /// Whether the user should be told something.
  ///
  /// Only when they are actually counting. The two cases worth a word are
  /// running short during this change, and being on the last one — the second
  /// because a pharmacy trip planned a day early costs nothing and one planned
  /// a day late costs a missed change.
  bool get isWorthMentioning => tracked && (shortfall > 0 || remaining == 0);

  @override
  bool operator ==(Object other) =>
      other is StockDraw &&
      other.tracked == tracked &&
      other.requested == requested &&
      other.shortfall == shortfall &&
      other.remaining == remaining;

  @override
  int get hashCode => Object.hash(tracked, requested, shortfall, remaining);

  @override
  String toString() =>
      'StockDraw(tracked: $tracked, requested: $requested, '
      'shortfall: $shortfall, remaining: $remaining)';
}
