import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';

/// A repeating source of "now".
///
/// [Clock] answers *what time is it*; a [Ticker] answers *tell me again when
/// it changes*. The dashboard needs the second one: a countdown rendered once
/// at build time is wrong a minute later, and an app people leave open on the
/// kitchen counter would sit there showing "1 hour left" for an afternoon.
///
/// Injected rather than reached for, like the clock, because a widget test
/// that leaves a real periodic timer running fails at teardown with a pending
/// timer rather than a useful message. Tests override [tickerProvider] with a
/// [ManualTicker] and advance time on purpose.
abstract interface class Ticker {
  /// Emits the current local instant immediately, and again on every
  /// subsequent [period] boundary, until the subscription is cancelled.
  Stream<DateTime> ticks(Duration period);
}

/// Production ticker, backed by a [Clock] and a timer.
///
/// Ticks are aligned to wall-clock boundaries rather than to whenever the
/// stream happened to be subscribed: a minute-period ticker fires *on* the
/// minute. Without alignment a countdown reading "3 days left" would flip at
/// some arbitrary offset into the minute, which shows up as two cards
/// changing their minds a few seconds apart.
class ClockTicker implements Ticker {
  const ClockTicker(this.clock);

  final Clock clock;

  @override
  Stream<DateTime> ticks(Duration period) {
    assert(period > Duration.zero, 'A ticker period must be positive.');

    // `Stream.multi` rather than a `StreamController` so the timer belongs to
    // the subscription that created it: two screens watching the same period
    // get their own, and cancelling one cannot silence the other. It also
    // keeps cancellation synchronous — a controller closed from inside its own
    // `onCancel` returns a future that never completes, and `cancel()` would
    // then hang forever on it.
    return Stream<DateTime>.multi((MultiStreamController<DateTime> controller) {
      Timer? timer;

      void scheduleNext() {
        timer = Timer(_untilNextBoundary(period), () {
          controller.add(clock.now());
          scheduleNext();
        });
      }

      controller
        ..add(clock.now())
        ..onCancel = () {
          timer?.cancel();
          timer = null;
        };
      scheduleNext();
    });
  }

  /// How long until the next whole [period] since the epoch.
  ///
  /// Measured in UTC milliseconds, which for any period that divides an hour
  /// lands on the same instant as the local boundary — every real time zone
  /// offset is a whole number of minutes.
  Duration _untilNextBoundary(Duration period) {
    final int periodMs = period.inMilliseconds;
    final int intoPeriod = clock.nowUtc().millisecondsSinceEpoch % periodMs;
    return Duration(milliseconds: periodMs - intoPeriod);
  }
}

/// A ticker that only ticks when a test says so.
///
/// Lives here beside [ClockTicker] for the same reason `FixedClock` lives
/// beside `SystemClock`: the fake is part of the contract, and a seam nobody
/// can substitute is not a seam.
class ManualTicker implements Ticker {
  ManualTicker(this.clock);

  final Clock clock;

  final List<MultiStreamController<DateTime>> _listeners =
      <MultiStreamController<DateTime>>[];

  /// The periods [ticks] has been asked for, in call order. Lets a test assert
  /// on the cadence a screen chose without reaching for a timer.
  final List<Duration> requestedPeriods = <Duration>[];

  @override
  Stream<DateTime> ticks(Duration period) {
    requestedPeriods.add(period);
    return Stream<DateTime>.multi((MultiStreamController<DateTime> controller) {
      _listeners.add(controller);
      controller
        ..add(clock.now())
        ..onCancel = () => _listeners.remove(controller);
    });
  }

  /// Emits the clock's current instant to every live subscription.
  ///
  /// Move the clock first — this reports the time, it does not invent one.
  void tick() {
    // Copied, because a listener that cancels on the tick it receives would
    // otherwise mutate the list being walked.
    for (final MultiStreamController<DateTime> listener
        in List<MultiStreamController<DateTime>>.of(_listeners)) {
      listener.add(clock.now());
    }
  }
}

/// The application-wide ticker. Override in tests with a [ManualTicker].
final Provider<Ticker> tickerProvider = Provider<Ticker>(
  (Ref ref) => ClockTicker(ref.watch(clockProvider)),
);
