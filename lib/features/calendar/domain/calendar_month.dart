import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../history/domain/history_entry.dart';

/// Something the calendar expects on a future date.
///
/// Separate from [HistoryEntry] because the two are different claims. A
/// history entry is a record of what happened; this is a date the app worked
/// out, and it moves the moment the user does anything. Rendering them as the
/// same kind of thing would let a plan read as a fact.
@immutable
sealed class CalendarExpectation {
  const CalendarExpectation({required this.type});

  final ConsumableType type;

  /// When it is expected. UTC.
  ///
  /// A getter rather than a field, for the reason `HistoryEntry.occurredAt` is
  /// one: each kind already carries the date on its own row, and a second copy
  /// in the base is a second thing to keep in step.
  DateTime get on;

  String get id;

  DateTime get localDay {
    final DateTime local = on.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// A consumable is due to be changed.
final class ChangeDue extends CalendarExpectation {
  const ChangeDue({required this.instance, required super.type});

  final ConsumableInstance instance;

  @override
  DateTime get on => instance.expectedChangeAt!;

  @override
  String get id => instance.id;
}

/// Stock goes off.
final class StockExpires extends CalendarExpectation {
  const StockExpires({required this.batch, required super.type});

  final InventoryItem batch;

  @override
  DateTime get on => batch.expirationDate!;

  @override
  String get id => batch.id;
}

/// One square of the grid.
@immutable
class CalendarDay {
  const CalendarDay({
    required this.day,
    required this.entries,
    required this.expectations,
    required this.isInMonth,
  });

  /// Local midnight.
  final DateTime day;

  /// What happened, most recent first.
  final List<HistoryEntry> entries;

  /// What is expected. Empty for any day in the past — a deadline that has
  /// been dealt with is history, and one that has not is on the dashboard
  /// shouting about it.
  final List<CalendarExpectation> expectations;

  /// Whether this square belongs to the month being shown, or is one of the
  /// neighbours that fill the first and last rows.
  final bool isInMonth;

  bool get hasAnything => entries.isNotEmpty || expectations.isNotEmpty;

  bool get hasProblem => entries.any((HistoryEntry e) => e is IncidentEntry);

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.day == day &&
      other.isInMonth == isInMonth &&
      listEquals(other.entries, entries) &&
      listEquals(other.expectations, expectations);

  @override
  int get hashCode => Object.hash(
    day,
    isInMonth,
    Object.hashAll(entries),
    Object.hashAll(expectations),
  );
}

/// A month of squares, each carrying what happened on it and what is expected.
///
/// The grid is built here rather than in the widget because the awkward parts
/// are arithmetic, not layout: which neighbouring days fill the first row, and
/// what a month looks like when it starts on the day the week starts on.
@immutable
class CalendarMonth {
  const CalendarMonth({
    required this.month,
    required this.days,
    required this.today,
  });

  /// Builds the grid for the month containing [month].
  ///
  /// [firstWeekday] is the locale's first day of the week, in
  /// [DateTime.monday]..[DateTime.sunday]. A grid that always started on
  /// Monday would be wrong for half the places this app runs, and the number
  /// comes from the same `intl` data that formats the headings.
  factory CalendarMonth.from({
    required DateTime month,
    required List<HistoryEntry> entries,
    required List<CalendarExpectation> expectations,
    required DateTime today,
    int firstWeekday = DateTime.monday,
  }) {
    final DateTime first = DateTime(month.year, month.month);
    final DateTime startOfToday = DateTime(today.year, today.month, today.day);

    // How many days of the previous month the first row has to show. The
    // modulo keeps it in 0..6 whichever weekday the locale starts on, which is
    // the part that is easy to get wrong and impossible to see in review.
    final int lead = (first.weekday - firstWeekday + 7) % 7;
    final DateTime gridStart = first.subtract(Duration(days: lead));

    final Map<DateTime, List<HistoryEntry>> byDay =
        <DateTime, List<HistoryEntry>>{};
    for (final HistoryEntry entry in entries) {
      byDay.putIfAbsent(entry.localDay, () => <HistoryEntry>[]).add(entry);
    }

    final Map<DateTime, List<CalendarExpectation>> expectedByDay =
        <DateTime, List<CalendarExpectation>>{};
    for (final CalendarExpectation expectation in expectations) {
      // Nothing is "expected" in the past. Either it happened, in which case
      // there is a real entry for it, or it did not, in which case Home is
      // already saying so and a stale marker here would only disagree.
      if (expectation.localDay.isBefore(startOfToday)) {
        continue;
      }
      expectedByDay
          .putIfAbsent(expectation.localDay, () => <CalendarExpectation>[])
          .add(expectation);
    }

    // Six rows, always. A grid that grows and shrinks between months makes
    // everything below it jump, and a month can genuinely need six.
    final List<CalendarDay> days = <CalendarDay>[
      for (int i = 0; i < 42; i++)
        if (DateTime(gridStart.year, gridStart.month, gridStart.day + i)
            case final DateTime day)
          CalendarDay(
            day: day,
            entries: List<HistoryEntry>.unmodifiable(
              (byDay[day] ?? <HistoryEntry>[])..sort(
                (HistoryEntry a, HistoryEntry b) =>
                    b.occurredAt.compareTo(a.occurredAt),
              ),
            ),
            expectations: List<CalendarExpectation>.unmodifiable(
              (expectedByDay[day] ?? <CalendarExpectation>[])..sort(
                (CalendarExpectation a, CalendarExpectation b) =>
                    a.on.compareTo(b.on),
              ),
            ),
            isInMonth: day.month == first.month && day.year == first.year,
          ),
    ];

    return CalendarMonth(
      month: first,
      days: List<CalendarDay>.unmodifiable(days),
      today: startOfToday,
    );
  }

  /// Local midnight on the first of the month being shown.
  final DateTime month;

  /// Forty-two squares, six rows of seven.
  final List<CalendarDay> days;

  /// Local midnight today, so the grid can mark it without reading a clock.
  final DateTime today;

  /// Only the squares that belong to this month.
  List<CalendarDay> get daysInMonth =>
      days.where((CalendarDay day) => day.isInMonth).toList();

  int get entryCount => daysInMonth.fold<int>(
    0,
    (int sum, CalendarDay day) => sum + day.entries.length,
  );

  /// The month before and after, as plain dates. The caller reloads the data
  /// for whichever it moves to, rather than this trying to carry it.
  DateTime get previousMonth => DateTime(month.year, month.month - 1);
  DateTime get nextMonth => DateTime(month.year, month.month + 1);

  CalendarDay? dayOn(DateTime local) {
    final DateTime target = DateTime(local.year, local.month, local.day);
    for (final CalendarDay day in days) {
      if (day.day == target) {
        return day;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth &&
      other.month == month &&
      other.today == today &&
      listEquals(other.days, days);

  @override
  int get hashCode => Object.hash(month, today, Object.hashAll(days));
}
