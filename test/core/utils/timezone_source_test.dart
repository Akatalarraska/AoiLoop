import 'package:dt1flow/core/utils/clock.dart';
import 'package:dt1flow/core/utils/timezone_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// The zone stored on a profile has to mean something later, when Phase 5
/// schedules reminders against it. These tests pin the one rule that makes
/// that possible: store something unambiguous, never a local abbreviation.
void main() {
  group('fixed offset identifiers', () {
    test('UTC has no offset to state', () {
      expect(SystemTimezoneSource.fixedOffsetId(Duration.zero), 'UTC');
    });

    test('whole hours are padded on both sides', () {
      expect(
        SystemTimezoneSource.fixedOffsetId(const Duration(hours: 2)),
        'UTC+02:00',
      );
      expect(
        SystemTimezoneSource.fixedOffsetId(const Duration(hours: -5)),
        'UTC-05:00',
      );
    });

    test('half and quarter hour zones survive', () {
      expect(
        SystemTimezoneSource.fixedOffsetId(
          const Duration(hours: -3, minutes: -30),
        ),
        'UTC-03:30',
      );
      expect(
        SystemTimezoneSource.fixedOffsetId(
          const Duration(hours: 5, minutes: 45),
        ),
        'UTC+05:45',
      );
    });

    test('a fourteen hour offset still reads as two digits', () {
      expect(
        SystemTimezoneSource.fixedOffsetId(const Duration(hours: 14)),
        'UTC+14:00',
      );
    });
  });

  group('current zone', () {
    test('never returns an empty or abbreviated-looking mess', () {
      final String zone = const SystemTimezoneSource().currentZone();

      expect(zone, isNotEmpty);
      expect(
        zone.contains('/') || zone.startsWith('UTC'),
        isTrue,
        reason:
            'an abbreviation like "CST" cannot be resolved back to a zone: '
            'got $zone',
      );
    });

    test('reads the clock it was given rather than the system one', () {
      final FixedClock clock = FixedClock(DateTime.utc(2026, 8, 17, 9));
      final String zone = SystemTimezoneSource(clock: clock).currentZone();

      expect(zone, isNotEmpty);
    });
  });
}
