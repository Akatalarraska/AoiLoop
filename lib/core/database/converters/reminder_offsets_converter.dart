import 'package:drift/drift.dart';

/// Stores a list of reminder lead times as a comma-separated list of minutes.
///
/// Reminder offsets are a short, ordered list of small durations — 48h, 24h,
/// 6h, 1h, 0 — so a compact text column beats a join table, and stays
/// readable if anyone ever opens the database by hand.
///
/// Values are normalised on write: sorted longest-lead-first and deduplicated,
/// so `[1h, 24h, 1h]` and `[24h, 1h]` are the same stored value. That keeps
/// equality checks meaningful and stops duplicate notifications being
/// scheduled for the same moment.
class ReminderOffsetsConverter extends TypeConverter<List<Duration>, String> {
  const ReminderOffsetsConverter();

  @override
  List<Duration> fromSql(String fromDb) {
    if (fromDb.isEmpty) {
      return const <Duration>[];
    }
    return fromDb
        .split(',')
        .map((String part) => Duration(minutes: int.parse(part)))
        .toList(growable: false);
  }

  @override
  String toSql(List<Duration> value) =>
      normalize(value)
          .map((Duration offset) => offset.inMinutes.toString())
          .join(',');

  /// Sorted longest-lead-first and deduplicated.
  ///
  /// Negative offsets are dropped: a reminder cannot lead a deadline by a
  /// negative amount, and silently scheduling one in the past would produce a
  /// notification that either never fires or fires immediately.
  static List<Duration> normalize(List<Duration> offsets) {
    final Set<int> minutes = <int>{
      for (final Duration offset in offsets)
        if (!offset.isNegative) offset.inMinutes,
    };
    final List<int> sorted = minutes.toList()
      ..sort((int a, int b) => b.compareTo(a));
    return <Duration>[for (final int value in sorted) Duration(minutes: value)];
  }
}
