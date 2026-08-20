import 'package:blauloop/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// The clock is the seam that makes every date calculation in BlauLoop
/// testable — cycle countdowns, preferred change time, notification offsets,
/// travel windows. If it misbehaves, every one of those does too.
void main() {
  group('SystemClock', () {
    test('now() and nowUtc() describe the same instant', () {
      const Clock clock = SystemClock();

      final DateTime local = clock.now();
      final DateTime utc = clock.nowUtc();

      expect(utc.isUtc, isTrue);
      expect(local.isUtc, isFalse);
      // Two separate reads of the system clock, so allow a small delta.
      expect(
        utc.difference(local.toUtc()).abs(),
        lessThan(const Duration(seconds: 1)),
      );
    });
  });

  group('FixedClock', () {
    test('stays pinned across repeated reads', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 17, 11));

      expect(clock.nowUtc(), DateTime.utc(2026, 8, 17, 11));
      expect(clock.nowUtc(), DateTime.utc(2026, 8, 17, 11));
    });

    test('advance moves forward by the given duration', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 17, 11));

      clock.advance(const Duration(hours: 25));

      expect(clock.nowUtc(), DateTime.utc(2026, 8, 18, 12));
    });

    test('advance accepts a negative duration', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 17, 11));

      clock.advance(const Duration(hours: -12));

      expect(clock.nowUtc(), DateTime.utc(2026, 8, 16, 23));
    });

    test('crosses a day boundary without drifting', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 17, 23, 30));

      clock.advance(const Duration(minutes: 45));

      expect(clock.nowUtc(), DateTime.utc(2026, 8, 18, 0, 15));
    });

    test('handles a leap day', () {
      final FixedClock clock = FixedClock(DateTime.utc(2028, 2, 28, 12));

      clock.advance(const Duration(days: 1));

      expect(clock.nowUtc(), DateTime.utc(2028, 2, 29, 12));
    });

    test('set jumps to an absolute instant', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 1, 1));

      clock.set(DateTime.utc(2026, 12, 31, 18, 5));

      expect(clock.nowUtc(), DateTime.utc(2026, 12, 31, 18, 5));
    });

    test('nowUtc is UTC and now is local, for either input flavour', () {
      final FixedClock fromUtc = FixedClock(DateTime.utc(2026, 8, 17, 11));
      final FixedClock fromLocal = FixedClock(DateTime(2026, 8, 17, 11));

      expect(fromUtc.nowUtc().isUtc, isTrue);
      expect(fromUtc.now().isUtc, isFalse);
      expect(fromLocal.nowUtc().isUtc, isTrue);
      expect(fromLocal.now().isUtc, isFalse);

      // Converting back and forth must not shift the instant.
      expect(fromUtc.now().toUtc(), DateTime.utc(2026, 8, 17, 11));
      expect(fromLocal.nowUtc().toLocal(), DateTime(2026, 8, 17, 11));
    });
  });
}
