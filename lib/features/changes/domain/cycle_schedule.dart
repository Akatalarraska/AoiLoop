import 'package:flutter/foundation.dart';

/// The dates one cycle will run between, and the shift BlauLoop is willing to
/// offer on the end of it.
///
/// Like `CycleCountdown`, this is deliberately plain Dart: no Flutter widgets,
/// no database, no clock of its own. Everything it knows arrives as an
/// argument, so every boundary it draws can be tested at an exact instant.
/// `CycleCountdown` answers *how far through is this*; this answers *when
/// should the next one end*, and they are the two halves of the same
/// arithmetic.
///
/// The type carries two end dates rather than one because the preferred
/// change time is an **offer**. A sensor replaced at 03:17 would otherwise
/// hand the user 03:17 forever, and BlauLoop would rather show both dates and
/// let them pick than quietly move a deadline they never asked to move.
@immutable
class CycleSchedule {
  const CycleSchedule({
    required this.installedAt,
    required this.naturalChangeAt,
    required this.preferredChangeAt,
  });

  /// The schedule for something installed at [installedAt].
  ///
  /// [duration] is the type's expected life, null for an item that is counted
  /// rather than timed — a box of strips has no deadline to compute.
  /// [preferredMinuteOfDay] is the profile's preferred change time as minutes
  /// since local midnight, null when they never expressed one.
  ///
  /// All instants are handled in UTC; [preferredMinuteOfDay] is interpreted
  /// against the device's local zone. That is a knowing simplification: the
  /// profile stores an IANA zone name but the app carries no tz database yet,
  /// so local *is* the profile's zone for every user who is not mid-flight.
  /// Phase 5 brings real zone arithmetic and this is the one place it lands.
  factory CycleSchedule.forInstall({
    required DateTime installedAt,
    required Duration? duration,
    int? preferredMinuteOfDay,
  }) {
    final DateTime installed = installedAt.toUtc();

    if (duration == null || duration <= Duration.zero) {
      return CycleSchedule(
        installedAt: installed,
        naturalChangeAt: null,
        preferredChangeAt: null,
      );
    }

    final DateTime natural = installed.add(duration);

    return CycleSchedule(
      installedAt: installed,
      naturalChangeAt: natural,
      preferredChangeAt: _preferredChangeAt(
        installedAt: installed,
        naturalChangeAt: natural,
        preferredMinuteOfDay: preferredMinuteOfDay,
      ),
    );
  }

  /// When the cycle began. UTC.
  final DateTime installedAt;

  /// Install plus the type's expected life. UTC. Null when the type has no
  /// wear cycle, which is what makes an instance untracked.
  final DateTime? naturalChangeAt;

  /// The same deadline moved to the user's preferred time of day. UTC.
  ///
  /// Null when there is nothing worth offering: no preference recorded, no
  /// deadline to move, the deadline already falls at the preferred time, or
  /// the shift would land at or before the install.
  final DateTime? preferredChangeAt;

  /// Whether this cycle counts down at all.
  bool get isTracked => naturalChangeAt != null;

  /// Whether there is a preferred-time shift to put in front of the user.
  bool get offersPreferredTime => preferredChangeAt != null;

  /// How much earlier the preferred time falls than the natural deadline.
  ///
  /// Always positive when present — the offer never extends a cycle. Null
  /// when there is no offer.
  Duration? get broughtForwardBy => preferredChangeAt == null
      ? null
      : naturalChangeAt!.difference(preferredChangeAt!);

  /// The deadline to actually store.
  ///
  /// [usePreferredTime] is the user's answer to the offer. Asking for the
  /// preferred time when none is on the table yields the natural deadline
  /// rather than an error, so a stale checkbox cannot produce a wrong date.
  DateTime? changeAt({required bool usePreferredTime}) => usePreferredTime
      ? (preferredChangeAt ?? naturalChangeAt)
      : naturalChangeAt;

  /// The preferred time on or before [naturalChangeAt], or null if there is
  /// nothing sensible to propose.
  ///
  /// **The offer never runs past the natural deadline.** Given a 10 day
  /// sensor due at 03:17 and a preferred time of 09:00, the candidates are
  /// 09:00 that morning — six hours *beyond* what the manufacturer rates the
  /// sensor for — and 09:00 the morning before, which is eighteen hours
  /// short. BlauLoop takes the shorter cycle every time. Proposing that
  /// someone wear a consumable past its rated life is the one thing a tracker
  /// must not do, and it is not the app's call to make on their behalf.
  static DateTime? _preferredChangeAt({
    required DateTime installedAt,
    required DateTime naturalChangeAt,
    required int? preferredMinuteOfDay,
  }) {
    if (preferredMinuteOfDay == null) {
      return null;
    }

    final DateTime localDue = naturalChangeAt.toLocal();
    final int hour = preferredMinuteOfDay ~/ Duration.minutesPerHour;
    final int minute = preferredMinuteOfDay % Duration.minutesPerHour;

    // Built as wall-clock components rather than by subtracting a Duration:
    // a day is not always 24 hours, and the user asked for 09:00, not for
    // "23 hours before the deadline" on the morning the clocks go back.
    DateTime candidate = DateTime(
      localDue.year,
      localDue.month,
      localDue.day,
      hour,
      minute,
    );
    if (candidate.isAfter(localDue)) {
      candidate = DateTime(
        localDue.year,
        localDue.month,
        localDue.day - 1,
        hour,
        minute,
      );
    }

    final DateTime shifted = candidate.toUtc();

    // A cycle shorter than nothing is not an offer, it is a bug the user
    // would have to notice. Short-lived items simply keep their own deadline.
    if (!shifted.isAfter(installedAt)) {
      return null;
    }
    if (!shifted.isBefore(naturalChangeAt)) {
      return null;
    }
    return shifted;
  }

  @override
  bool operator ==(Object other) =>
      other is CycleSchedule &&
      other.installedAt == installedAt &&
      other.naturalChangeAt == naturalChangeAt &&
      other.preferredChangeAt == preferredChangeAt;

  @override
  int get hashCode =>
      Object.hash(installedAt, naturalChangeAt, preferredChangeAt);

  @override
  String toString() =>
      'CycleSchedule(installedAt: $installedAt, naturalChangeAt: '
      '$naturalChangeAt, preferredChangeAt: $preferredChangeAt)';
}
