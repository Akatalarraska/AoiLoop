import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An injectable source of "now".
///
/// Every date calculation in BlauLoop goes through a [Clock] rather than
/// calling [DateTime.now] directly. The cycle engine, notification scheduler
/// and travel planner are all date arithmetic, and they must be testable at
/// fixed instants, across day boundaries and across time zones.
///
/// Never call `DateTime.now()` in feature code. Read [clockProvider] instead.
abstract interface class Clock {
  /// The current instant in the local time zone.
  DateTime now();

  /// The current instant in UTC. Persisted timestamps use UTC.
  DateTime nowUtc();
}

/// Production clock, backed by the system time.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock pinned to a fixed instant, for tests and previews.
class FixedClock implements Clock {
  FixedClock(this._instant);

  DateTime _instant;

  /// Moves the clock forward (or backward, with a negative [delta]).
  void advance(Duration delta) => _instant = _instant.add(delta);

  /// Jumps the clock to an absolute instant.
  void set(DateTime instant) => _instant = instant;

  @override
  DateTime now() => _instant.isUtc ? _instant.toLocal() : _instant;

  @override
  DateTime nowUtc() => _instant.toUtc();
}

/// The application-wide clock. Override in tests with a [FixedClock].
final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => const SystemClock(),
);
