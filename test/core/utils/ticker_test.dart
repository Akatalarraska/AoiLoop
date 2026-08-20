import 'dart:async';

import 'package:aoiloop/core/utils/clock.dart';
import 'package:aoiloop/core/utils/ticker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ticker is what keeps a countdown honest while the app sits open, so
/// these tests care about two things: that it fires on the wall-clock boundary
/// rather than a period after subscription, and that it stops dead when nobody
/// is listening.
///
/// Two mechanics of the widget tester shape how they are written.
///
/// An empty tree is mounted first, because `pump` with nothing to draw has no
/// frame to wait for and never returns.
///
/// And every subscription is cancelled inside the test body rather than in a
/// teardown, because the "a Timer is still pending" check runs at the end of
/// the body — before teardowns. That check is not in the way here, it *is* the
/// assertion: a ticker whose timer survives its last listener is one that
/// wakes a phone up for nothing.
void main() {
  /// Gives the binding something to pump, so time can be advanced.
  Future<void> mountEmptyTree(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  /// Cancels [subscription] and lets the fake clock settle.
  ///
  /// Awaiting `cancel()` directly deadlocks: it completes on a microtask, and
  /// the fake async zone a widget test runs in only drains microtasks when the
  /// clock is pumped. The cancellation itself is synchronous — the pump is
  /// only there to collect the future.
  Future<void> stop(WidgetTester tester, StreamSubscription<DateTime> s) async {
    unawaited(s.cancel());
    await tester.pump();
  }

  group('ClockTicker', () {
    testWidgets('emits the current instant as soon as it is listened to', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9, 0, 30));
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ClockTicker(clock)
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();

      expect(seen, hasLength(1));
      expect(seen.single, clock.now());

      await stop(tester, subscription);
    });

    testWidgets('fires on the minute, not a minute after subscribing', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      // Subscribed at :30, so the first boundary is 30 seconds away — not the
      // full minute a naive periodic timer would wait.
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9, 0, 30));
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ClockTicker(clock)
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();

      await tester.pump(const Duration(seconds: 29));
      expect(seen, hasLength(1), reason: 'nothing is due before the boundary');

      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));

      expect(seen, hasLength(2));
      expect(seen.last, clock.now());

      await stop(tester, subscription);
    });

    testWidgets('keeps ticking, one event per period', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9));
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ClockTicker(clock)
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();

      for (int minute = 0; minute < 3; minute++) {
        clock.advance(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
      }

      expect(
        seen,
        hasLength(4),
        reason: 'the immediate event plus three ticks',
      );
      expect(seen.last, clock.now());

      await stop(tester, subscription);
    });

    testWidgets('stops scheduling once the subscription is cancelled', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9));
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ClockTicker(clock)
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();

      await stop(tester, subscription);
      clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));

      expect(seen, hasLength(1));
    });

    testWidgets('gives each listener its own timer', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9));
      final Ticker ticker = ClockTicker(clock);
      final List<DateTime> first = <DateTime>[];
      final List<DateTime> second = <DateTime>[];

      final StreamSubscription<DateTime> a = ticker
          .ticks(const Duration(minutes: 1))
          .listen(first.add);
      final StreamSubscription<DateTime> b = ticker
          .ticks(const Duration(minutes: 1))
          .listen(second.add);
      await tester.pump();

      // One screen closing must not stop the countdown on another.
      await stop(tester, a);
      clock.advance(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));

      expect(first, hasLength(1));
      expect(second, hasLength(2));

      await stop(tester, b);
    });
  });

  group('ManualTicker', () {
    testWidgets('emits once on listen, then only when told', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9));
      final ManualTicker ticker = ManualTicker(clock);
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ticker
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();

      expect(seen, hasLength(1));

      await tester.pump(const Duration(hours: 6));
      expect(seen, hasLength(1), reason: 'time passing is not a tick here');

      clock.advance(const Duration(hours: 6));
      ticker.tick();
      await tester.pump();

      expect(seen, hasLength(2));
      expect(seen.last, clock.now());

      await stop(tester, subscription);
    });

    testWidgets('records the period it was asked for', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final ManualTicker ticker = ManualTicker(
        FixedClock(DateTime.utc(2026, 8, 20, 9)),
      );

      final StreamSubscription<DateTime> subscription = ticker
          .ticks(const Duration(minutes: 1))
          .listen((_) {});
      await tester.pump();

      expect(ticker.requestedPeriods, <Duration>[const Duration(minutes: 1)]);

      await stop(tester, subscription);
    });

    testWidgets('stops delivering to a cancelled listener', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 20, 9));
      final ManualTicker ticker = ManualTicker(clock);
      final List<DateTime> seen = <DateTime>[];

      final StreamSubscription<DateTime> subscription = ticker
          .ticks(const Duration(minutes: 1))
          .listen(seen.add);
      await tester.pump();
      await stop(tester, subscription);

      clock.advance(const Duration(hours: 1));
      ticker.tick();
      await tester.pump();

      expect(seen, hasLength(1));
    });

    testWidgets('ticking with nothing listening is harmless', (
      WidgetTester tester,
    ) async {
      await mountEmptyTree(tester);
      final ManualTicker ticker = ManualTicker(
        FixedClock(DateTime.utc(2026, 8, 20, 9)),
      );

      expect(ticker.tick, returnsNormally);
    });
  });
}
