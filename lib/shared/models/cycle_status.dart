/// The lifecycle state of a cyclic consumable (sensor, infusion set,
/// reservoir, pod, transmitter…).
///
/// This enum is the shared vocabulary between the cycle engine (added in
/// Phase 4), the dashboard and the theme. It is deliberately plain Dart with
/// no Flutter dependency so it can be unit tested in isolation.
///
/// A status is derived, never stored. `CycleCountdown` maps a deadline and an
/// instant onto one of these; nothing writes a status to the database, so a
/// row cannot go stale by sitting still.
///
/// A status is **never** communicated by colour alone. Every surface that
/// renders a status must also render an icon and a localised label — see
/// `StatusPalette` and `StatusChip`.
enum CycleStatus {
  /// Comfortably within its expected lifetime.
  healthy,

  /// Approaching the expected change date.
  dueSoon,

  /// The expected change date has been reached.
  dueNow,

  /// The expected change date has passed.
  overdue,

  /// Not currently tracked: no active instance, or tracking disabled.
  inactive;

  /// Whether this status should draw the user's attention.
  bool get needsAttention =>
      this == CycleStatus.dueSoon ||
      this == CycleStatus.dueNow ||
      this == CycleStatus.overdue;

  /// Ordering used to surface the most urgent card first on the dashboard.
  /// Lower sorts earlier.
  int get urgencyRank => switch (this) {
    CycleStatus.overdue => 0,
    CycleStatus.dueNow => 1,
    CycleStatus.dueSoon => 2,
    CycleStatus.healthy => 3,
    CycleStatus.inactive => 4,
  };
}

/// Configurable boundaries between [CycleStatus] values.
///
/// Defaults match the product spec, but the type exists so the thresholds can
/// become a per-user setting later without touching call sites.
///
/// Only carries configuration — the logic that applies it lives in
/// `CycleCountdown`.
class CycleStatusThresholds {
  const CycleStatusThresholds({
    this.dueSoon = const Duration(hours: 24),
    this.overdueAfter = const Duration(hours: 6),
  });

  /// Remaining time at or below which a consumable becomes
  /// [CycleStatus.dueSoon]. Above it, [CycleStatus.healthy].
  final Duration dueSoon;

  /// How long past its deadline a consumable stays [CycleStatus.dueNow]
  /// before becoming [CycleStatus.overdue].
  ///
  /// Read literally, "the date has been reached" and "the date has passed"
  /// meet at a single instant, which would make [CycleStatus.dueNow] a status
  /// no one ever sees. A grace period is what makes it mean something: a
  /// change is *due now* for the part of the day you would reasonably get to
  /// it, and *overdue* once it has clearly slipped. Six hours is the default
  /// because a set that came due over breakfast should not be shouting by
  /// lunch, and one still on at bedtime should be.
  final Duration overdueAfter;

  static const CycleStatusThresholds defaults = CycleStatusThresholds();

  CycleStatusThresholds copyWith({Duration? dueSoon, Duration? overdueAfter}) =>
      CycleStatusThresholds(
        dueSoon: dueSoon ?? this.dueSoon,
        overdueAfter: overdueAfter ?? this.overdueAfter,
      );

  @override
  bool operator ==(Object other) =>
      other is CycleStatusThresholds &&
      other.dueSoon == dueSoon &&
      other.overdueAfter == overdueAfter;

  @override
  int get hashCode => Object.hash(dueSoon, overdueAfter);

  @override
  String toString() =>
      'CycleStatusThresholds(dueSoon: $dueSoon, overdueAfter: $overdueAfter)';
}
