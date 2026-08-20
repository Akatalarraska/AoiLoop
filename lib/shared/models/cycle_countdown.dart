import 'cycle_status.dart';

/// How far through its life one consumable is, at one instant.
///
/// This is the whole of BlauLoop's countdown arithmetic, and it is deliberately
/// plain Dart: no Flutter, no database, no clock of its own. Everything it
/// knows comes in as arguments, so every boundary it draws — on track, due
/// soon, due now, overdue — can be tested at an exact instant rather than
/// approached with a `pumpAndSettle` and some hope.
///
/// It derives, and never stores. The deadline on a `ConsumableInstance` is
/// written once by the cycle engine and never moves on its own; the status is
/// recomputed from it whenever anything asks. That split is what lets a phone
/// sit in a drawer for a week and still be right when it comes out.
class CycleCountdown {
  const CycleCountdown._({
    required this.status,
    required this.remaining,
    required this.progress,
  });

  /// Nothing is being tracked: no instance in use, or one with no deadline.
  ///
  /// Distinct from a finished countdown. "You have not started a sensor" and
  /// "your sensor expired" are different sentences, and a dashboard that
  /// blurs them is one that gets ignored.
  static const CycleCountdown inactive = CycleCountdown._(
    status: CycleStatus.inactive,
    remaining: null,
    progress: null,
  );

  /// The countdown for a consumable installed at [installedAt] and due at
  /// [expectedChangeAt], evaluated at [now].
  ///
  /// A null [expectedChangeAt] yields [inactive] — an item that is counted
  /// rather than timed has no deadline to miss.
  ///
  /// All three instants are compared as absolute points in time, so it does
  /// not matter whether callers pass UTC (as the database returns) or local
  /// (as the ticker emits).
  factory CycleCountdown.at({
    required DateTime installedAt,
    required DateTime? expectedChangeAt,
    required DateTime now,
    CycleStatusThresholds thresholds = CycleStatusThresholds.defaults,
  }) {
    if (expectedChangeAt == null) {
      return inactive;
    }

    final Duration remaining = expectedChangeAt.difference(now);
    final Duration total = expectedChangeAt.difference(installedAt);

    return CycleCountdown._(
      status: _statusFor(remaining, thresholds),
      remaining: remaining,
      progress: _progressFor(remaining: remaining, total: total),
    );
  }

  /// Which of the five states this is in.
  final CycleStatus status;

  /// Time left before the change is due. Negative once it has passed, and
  /// null when [status] is [CycleStatus.inactive].
  ///
  /// Signed rather than clamped so that "due in 3 hours" and "3 hours late"
  /// are the same number read two ways, and nothing downstream has to carry a
  /// separate "is it late" flag that could disagree with it.
  final Duration? remaining;

  /// How much of the expected life has been used, from 0 to 1 inclusive.
  ///
  /// Clamped at both ends: a progress bar is a picture of the wear cycle, and
  /// one that overflows its track past the deadline says nothing the status
  /// does not already say more clearly. Null when [status] is
  /// [CycleStatus.inactive], and also when the deadline is not after the
  /// install — a zero-length cycle has no fraction to report.
  final double? progress;

  /// Whether a countdown is running at all.
  bool get isTracked => status != CycleStatus.inactive;

  /// Whether the deadline has passed. False for an untracked consumable,
  /// which has no deadline to be past.
  bool get hasPassed => remaining != null && remaining! <= Duration.zero;

  /// Time left, floored at zero — what to show when counting down.
  Duration? get timeLeft =>
      remaining == null || remaining! < Duration.zero ? null : remaining;

  /// Time since the deadline, when it has passed. Null before it.
  Duration? get overdueBy =>
      remaining != null && remaining! < Duration.zero ? -remaining! : null;

  static CycleStatus _statusFor(
    Duration remaining,
    CycleStatusThresholds thresholds,
  ) {
    if (remaining > thresholds.dueSoon) {
      return CycleStatus.healthy;
    }
    if (remaining > Duration.zero) {
      return CycleStatus.dueSoon;
    }
    if (remaining > -thresholds.overdueAfter) {
      return CycleStatus.dueNow;
    }
    return CycleStatus.overdue;
  }

  static double? _progressFor({
    required Duration remaining,
    required Duration total,
  }) {
    if (total <= Duration.zero) {
      return null;
    }
    final double used =
        (total - remaining).inMilliseconds / total.inMilliseconds;
    return used.clamp(0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is CycleCountdown &&
      other.status == status &&
      other.remaining == remaining &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(status, remaining, progress);

  @override
  String toString() =>
      'CycleCountdown($status, remaining: $remaining, progress: $progress)';
}
