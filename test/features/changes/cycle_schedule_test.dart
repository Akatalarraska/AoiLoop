import 'package:blauloop/features/changes/domain/cycle_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dates are built as *local* wall-clock values and compared after
/// `toUtc()`, so these tests assert the same thing wherever they run. The
/// preferred change time is a time of day the user reads off their own phone,
/// and pinning it to UTC would test something no user experiences.
void main() {
  const Duration tenDays = Duration(days: 10);
  const int nineAm = 9 * 60;

  group('without a deadline to compute', () {
    test('a type with no duration is untracked', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: null,
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.isTracked, isFalse);
      expect(schedule.naturalChangeAt, isNull);
      expect(schedule.offersPreferredTime, isFalse);
    });

    test('a zero-length duration is untracked rather than instantly due', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: Duration.zero,
      );

      expect(schedule.isTracked, isFalse);
    });
  });

  group('the natural deadline', () {
    test('is the install plus the type duration', () {
      final DateTime installed = DateTime(2026, 8, 17, 3, 17);

      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: installed,
        duration: tenDays,
      );

      expect(schedule.naturalChangeAt, installed.toUtc().add(tenDays));
      expect(schedule.installedAt, installed.toUtc());
    });

    test('stands alone when the user never chose a preferred time', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: tenDays,
      );

      expect(schedule.offersPreferredTime, isFalse);
      expect(schedule.preferredChangeAt, isNull);
      expect(schedule.broughtForwardBy, isNull);
    });
  });

  group('the preferred-time offer', () {
    test('moves a 03:17 deadline back to the previous 09:00', () {
      // The situation the whole feature exists for: a sensor failed in the
      // small hours, and without an offer every future change inherits 03:17.
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: tenDays,
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.preferredChangeAt, DateTime(2026, 8, 26, 9).toUtc());
      expect(schedule.broughtForwardBy, const Duration(hours: 18, minutes: 17));
    });

    test('never proposes a date later than the natural one', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: tenDays,
        preferredMinuteOfDay: nineAm,
      );

      // 09:00 on the 27th would be six hours past what the sensor is rated
      // for. BlauLoop takes the shorter cycle instead, every time.
      expect(
        schedule.preferredChangeAt!.isBefore(schedule.naturalChangeAt!),
        isTrue,
      );
      expect(schedule.broughtForwardBy!.isNegative, isFalse);
    });

    test('stays on the deadline day when the preferred time still fits', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 12),
        duration: tenDays,
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.preferredChangeAt, DateTime(2026, 8, 27, 9).toUtc());
      expect(schedule.broughtForwardBy, const Duration(hours: 3));
    });

    test('is withheld when the deadline already falls at that time', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 9),
        duration: tenDays,
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.preferredChangeAt, isNull);
      expect(schedule.offersPreferredTime, isFalse);
    });

    test('is withheld when the shift would land before the install', () {
      // A one-hour item installed at 10:00 is due at 11:00. The nearest 09:00
      // on or before that is an hour before it went on, which is not an offer,
      // it is a wrong date.
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 10),
        duration: const Duration(hours: 1),
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.preferredChangeAt, isNull);
      expect(schedule.naturalChangeAt, DateTime(2026, 8, 17, 11).toUtc());
    });
  });

  group('choosing which date to store', () {
    test('takes the preferred one when the user accepts the offer', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: tenDays,
        preferredMinuteOfDay: nineAm,
      );

      expect(
        schedule.changeAt(usePreferredTime: true),
        schedule.preferredChangeAt,
      );
      expect(
        schedule.changeAt(usePreferredTime: false),
        schedule.naturalChangeAt,
      );
    });

    test('falls back to the natural date when there was no offer', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: tenDays,
      );

      expect(
        schedule.changeAt(usePreferredTime: true),
        schedule.naturalChangeAt,
      );
    });

    test('has nothing to store for an untracked type', () {
      final CycleSchedule schedule = CycleSchedule.forInstall(
        installedAt: DateTime(2026, 8, 17, 3, 17),
        duration: null,
        preferredMinuteOfDay: nineAm,
      );

      expect(schedule.changeAt(usePreferredTime: true), isNull);
      expect(schedule.changeAt(usePreferredTime: false), isNull);
    });
  });

  test('is a value, so two schedules of the same dates are equal', () {
    CycleSchedule build() => CycleSchedule.forInstall(
      installedAt: DateTime(2026, 8, 17, 3, 17),
      duration: tenDays,
      preferredMinuteOfDay: nineAm,
    );

    expect(build(), build());
    expect(build().hashCode, build().hashCode);
  });
}
