/// The lifecycle state of a cyclic consumable (sensor, infusion set,
/// reservoir, pod, transmitter…).
///
/// This enum is the shared vocabulary between the cycle engine (added in
/// Phase 4), the dashboard and the theme. It is deliberately plain Dart with
/// no Flutter dependency so it can be unit tested in isolation.
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
/// Only carries configuration — the logic that maps a remaining [Duration] to
/// a [CycleStatus] lives in the cycle engine (Phase 4).
class CycleStatusThresholds {
  const CycleStatusThresholds({this.dueSoon = const Duration(hours: 24)});

  /// Remaining time at or below which a consumable becomes
  /// [CycleStatus.dueSoon]. Above it, [CycleStatus.healthy].
  final Duration dueSoon;

  static const CycleStatusThresholds defaults = CycleStatusThresholds();

  CycleStatusThresholds copyWith({Duration? dueSoon}) =>
      CycleStatusThresholds(dueSoon: dueSoon ?? this.dueSoon);

  @override
  bool operator ==(Object other) =>
      other is CycleStatusThresholds && other.dueSoon == dueSoon;

  @override
  int get hashCode => dueSoon.hashCode;

  @override
  String toString() => 'CycleStatusThresholds(dueSoon: $dueSoon)';
}
