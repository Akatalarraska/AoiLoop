import 'package:flutter/foundation.dart';

import 'history_entry.dart';

/// Which kinds of entry the timeline is showing.
enum HistoryFilter {
  /// Everything, which is what a history is for.
  everything,

  /// Replacements only.
  changes,

  /// Failures only — the view somebody opens when they are trying to work out
  /// whether something keeps going wrong.
  problems;

  bool admits(HistoryEntry entry) => switch (this) {
    HistoryFilter.everything => true,
    HistoryFilter.changes => entry is ChangeEntry,
    HistoryFilter.problems => entry is IncidentEntry,
  };
}

/// A day's worth of entries, ready to render under a date heading.
@immutable
class HistoryDay {
  const HistoryDay({
    required this.day,
    required this.entries,
    this.isToday = false,
    this.isYesterday = false,
  });

  /// Local midnight of the day these belong to.
  final DateTime day;

  /// Most recent first within the day.
  final List<HistoryEntry> entries;

  /// Whether this heading should read *Today* rather than a date.
  ///
  /// Decided here rather than in the widget, because "is this today" is date
  /// arithmetic and every piece of that in BlauLoop is plain Dart tested at a
  /// fixed instant. A widget comparing two dates is the same bug as a widget
  /// computing a deadline, only smaller.
  final bool isToday;

  /// Whether it should read *Yesterday*.
  final bool isYesterday;

  @override
  bool operator ==(Object other) =>
      other is HistoryDay &&
      other.day == day &&
      other.isToday == isToday &&
      other.isYesterday == isYesterday &&
      listEquals(other.entries, entries);

  @override
  int get hashCode =>
      Object.hash(day, isToday, isYesterday, Object.hashAll(entries));
}

/// The timeline, filtered and grouped by day.
///
/// Assembled here rather than in the widget so the merge, the ordering and the
/// filters are unit-testable at exact instants without pumping a frame.
@immutable
class HistoryView {
  const HistoryView({
    required this.days,
    required this.filter,
    required this.consumableTypeId,
    required this.totalEntries,
  });

  /// Merges changes and incidents, applies the filters, and groups by day.
  ///
  /// [consumableTypeId] narrows to one consumable — the view reached by
  /// opening a consumable rather than the History tab. Null means all of them.
  /// [today] is used only to label the headings — *Today*, *Yesterday*, or a
  /// date. Passed in rather than read from a clock, so the grouping is
  /// testable at an exact instant.
  factory HistoryView.from({
    required List<HistoryEntry> entries,
    required DateTime today,
    HistoryFilter filter = HistoryFilter.everything,
    String? consumableTypeId,
  }) {
    final DateTime startOfToday = DateTime(today.year, today.month, today.day);
    final DateTime startOfYesterday = startOfToday.subtract(
      const Duration(days: 1),
    );
    final List<HistoryEntry> kept = <HistoryEntry>[
      for (final HistoryEntry entry in entries)
        if (filter.admits(entry) &&
            (consumableTypeId == null || entry.type.id == consumableTypeId))
          entry,
    ]..sort(_mostRecentFirst);

    final List<HistoryDay> days = <HistoryDay>[];
    for (final HistoryEntry entry in kept) {
      if (days.isNotEmpty && days.last.day == entry.localDay) {
        days.last.entries.add(entry);
        continue;
      }
      days.add(HistoryDay(day: entry.localDay, entries: <HistoryEntry>[entry]));
    }

    return HistoryView(
      days: List<HistoryDay>.unmodifiable(<HistoryDay>[
        for (final HistoryDay day in days)
          HistoryDay(
            day: day.day,
            entries: List<HistoryEntry>.unmodifiable(day.entries),
            isToday: day.day == startOfToday,
            isYesterday: day.day == startOfYesterday,
          ),
      ]),
      filter: filter,
      consumableTypeId: consumableTypeId,
      totalEntries: kept.length,
    );
  }

  /// Most recent day first.
  final List<HistoryDay> days;

  final HistoryFilter filter;

  /// The consumable this view is narrowed to, or null for all of them.
  final String? consumableTypeId;

  final int totalEntries;

  bool get isEmpty => days.isEmpty;

  /// Every entry, still most recent first, with the day grouping flattened.
  List<HistoryEntry> get entries => <HistoryEntry>[
    for (final HistoryDay day in days) ...day.entries,
  ];

  /// Newest first, because a history is read from the top and the thing that
  /// just happened is the thing being looked for.
  ///
  /// The id breaks a tie, so two entries recorded at the same instant do not
  /// swap places between rebuilds.
  static int _mostRecentFirst(HistoryEntry a, HistoryEntry b) {
    final int byTime = b.occurredAt.compareTo(a.occurredAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryView &&
      other.filter == filter &&
      other.consumableTypeId == consumableTypeId &&
      other.totalEntries == totalEntries &&
      listEquals(other.days, days);

  @override
  int get hashCode =>
      Object.hash(filter, consumableTypeId, totalEntries, Object.hashAll(days));
}
