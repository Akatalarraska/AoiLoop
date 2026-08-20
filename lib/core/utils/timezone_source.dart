import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';

/// The time zone a profile is created in.
///
/// Separate from [Clock] because they answer different questions and change
/// for different reasons: the clock moves constantly, the zone moves when the
/// user travels or the OS setting changes — and a zone change has to trigger a
/// deliberate recalculation of every scheduled reminder rather than silently
/// shifting deadlines. Phase 5 owns that recalculation; this interface is the
/// seam it will plug into.
abstract interface class TimezoneSource {
  /// An identifier for the current zone, suitable for storing on a profile.
  String currentZone();
}

/// Best effort from what Dart alone exposes.
///
/// Dart has no IANA zone lookup, and `DateTime.timeZoneName` returns a local
/// abbreviation — "CEST", "CST" — that cannot be resolved back to a zone,
/// because those abbreviations are not unique across the world. So an
/// abbreviation is only accepted when it already looks like an IANA name
/// (`Europe/Madrid`), and otherwise a fixed-offset identifier is stored:
/// `UTC+02:00` is at least unambiguous about what it means.
///
/// Phase 5 replaces this with a platform lookup and migrates stored offsets to
/// real zone names. Keeping the interface here means that change touches one
/// file rather than the profile repository, onboarding and the scheduler.
class SystemTimezoneSource implements TimezoneSource {
  const SystemTimezoneSource({this.clock = const SystemClock()});

  final Clock clock;

  @override
  String currentZone() {
    final DateTime now = clock.now();
    final String name = now.timeZoneName;
    if (name.contains('/')) {
      return name;
    }
    return fixedOffsetId(now.timeZoneOffset);
  }

  /// Formats an offset as `UTC`, `UTC+02:00` or `UTC-03:30`.
  static String fixedOffsetId(Duration offset) {
    if (offset == Duration.zero) {
      return 'UTC';
    }
    final Duration magnitude = offset.abs();
    final String sign = offset.isNegative ? '-' : '+';
    final String hours = magnitude.inHours.toString().padLeft(2, '0');
    final String minutes = (magnitude.inMinutes % Duration.minutesPerHour)
        .toString()
        .padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }
}

/// A real IANA zone name, read from the platform once at startup.
///
/// The lookup is asynchronous and [TimezoneSource] is not, deliberately:
/// callers ask this question while building a profile or scheduling a
/// reminder, and neither is a place to await a platform channel. So the answer
/// is resolved once during startup and held.
///
/// Falls back to [SystemTimezoneSource] until it has one, and permanently if
/// the platform never answers. `UTC+02:00` is a worse identifier than
/// `Europe/Madrid`, but it is unambiguous about what it means, and a profile
/// with an approximate zone beats a startup that failed.
class PlatformTimezoneSource implements TimezoneSource {
  const PlatformTimezoneSource({required this.zone});

  /// The IANA name the platform reported, e.g. `Europe/Madrid`.
  final String zone;

  @override
  String currentZone() => zone;
}

/// The application-wide time zone source.
///
/// Overridden during startup with a [PlatformTimezoneSource] once the platform
/// has answered, and in tests with a fixed one. The default is the best guess
/// Dart alone can make.
final Provider<TimezoneSource> timezoneSourceProvider =
    Provider<TimezoneSource>(
      (Ref ref) => SystemTimezoneSource(clock: ref.watch(clockProvider)),
    );
