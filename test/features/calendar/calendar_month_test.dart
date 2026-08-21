import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/calendar/domain/calendar_month.dart';
import 'package:blauloop/features/history/domain/history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The month grid: which squares it has, what lands on them, and what it
/// refuses to put in the past.
///
/// The awkward parts here are arithmetic rather than layout, which is why they
/// live in `domain/` and are pinned without a frame.
void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;
  late ConsumableInstance instance;

  /// A Friday, so the lead-in arithmetic has something to actually do.
  final DateTime today = DateTime(2026, 8, 21);

  setUp(() async {
    h = TestHarness.create(now: today.toUtc());
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'CGM sensor');
    instance = await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: DateTime.utc(2026, 8, 1),
    );
  });

  Future<ChangeEntry> change(DateTime at) async {
    return ChangeEntry(
      event: await h.changes.create(
        userProfileId: profile.id,
        consumableInstanceId: instance.id,
        changedAt: at,
        type: ChangeType.scheduled,
      ),
      type: sensor,
    );
  }

  Future<IncidentEntry> incident(DateTime at) async {
    return IncidentEntry(
      incident: await h.incidents.create(
        userProfileId: profile.id,
        consumableInstanceId: instance.id,
        occurredAt: at,
        type: IncidentType.occlusion,
      ),
      type: sensor,
    );
  }

  /// A deadline, on a type of its own.
  ///
  /// Its own type because only one instance of a type can be active at a time
  /// — a partial unique index enforces it — and the setUp already put one in
  /// use for the sensor.
  Future<ChangeDue> due(DateTime on) async {
    final ConsumableType type = await h.seedType(name: 'Due ${on.day}');
    return ChangeDue(
      instance: await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: type.id,
        installedAt: today.subtract(const Duration(days: 2)),
        expectedChangeAt: on,
      ),
      type: type,
    );
  }

  CalendarMonth build({
    DateTime? month,
    List<HistoryEntry> entries = const <HistoryEntry>[],
    List<CalendarExpectation> expectations = const <CalendarExpectation>[],
    int firstWeekday = DateTime.monday,
  }) {
    return CalendarMonth.from(
      month: month ?? DateTime(2026, 8),
      entries: entries,
      expectations: expectations,
      today: today,
      firstWeekday: firstWeekday,
    );
  }

  group('the grid', () {
    test('is always six rows of seven', () {
      // A grid that grew and shrank between months would make everything below
      // it jump, and a month can genuinely need six rows.
      for (int month = 1; month <= 12; month++) {
        expect(
          build(month: DateTime(2026, month)).days,
          hasLength(42),
          reason: 'month $month',
        );
      }
    });

    test('starts on the locale first day of the week', () {
      expect(build(firstWeekday: DateTime.monday).days.first.weekday, 1);
      expect(build(firstWeekday: DateTime.sunday).days.first.weekday, 7);
      expect(build(firstWeekday: DateTime.saturday).days.first.weekday, 6);
    });

    test('leads in with the days it needs and no more', () {
      // 1 August 2026 is a Saturday. On a Monday-first grid that is five days
      // of July in front of it; on a Saturday-first grid, none at all.
      expect(
        build(firstWeekday: DateTime.monday).days.first.day,
        DateTime(2026, 7, 27),
      );
      expect(
        build(firstWeekday: DateTime.saturday).days.first.day,
        DateTime(2026, 8),
      );
    });

    test('every day of the month is in it exactly once', () {
      final List<CalendarDay> inMonth = build().daysInMonth;

      expect(inMonth, hasLength(31));
      expect(inMonth.first.day, DateTime(2026, 8));
      expect(inMonth.last.day, DateTime(2026, 8, 31));
    });

    test('marks the neighbours as not belonging to the month', () {
      final CalendarMonth month = build();

      expect(month.days.first.isInMonth, isFalse);
      expect(month.days.last.isInMonth, isFalse);
    });

    test('knows which day is today without reading a clock', () {
      expect(build().today, today);
    });

    test('names the month either side', () {
      final CalendarMonth month = build(month: DateTime(2026));

      expect(month.previousMonth, DateTime(2025, 12));
      expect(month.nextMonth, DateTime(2026, 2));
    });
  });

  group('what lands on a day', () {
    test('a change goes on the day it happened', () async {
      final ChangeEntry entry = await change(DateTime.utc(2026, 8, 12, 10));

      final CalendarMonth month = build(entries: <HistoryEntry>[entry]);

      expect(month.dayOn(entry.localDay)!.entries.single.id, entry.id);
      expect(month.entryCount, 1);
    });

    test('several things on one day are all there, newest first', () async {
      final ChangeEntry morning = await change(DateTime.utc(2026, 8, 12, 8));
      final IncidentEntry evening = await incident(
        DateTime.utc(2026, 8, 12, 20),
      );

      final CalendarMonth month = build(
        entries: <HistoryEntry>[morning, evening],
      );

      final CalendarDay day = month.dayOn(morning.localDay)!;
      expect(day.entries, hasLength(2));
      expect(day.entries.first.id, evening.id);
    });

    test('a day with a problem says so', () async {
      final IncidentEntry entry = await incident(DateTime.utc(2026, 8, 12));

      final CalendarMonth month = build(entries: <HistoryEntry>[entry]);

      expect(month.dayOn(entry.localDay)!.hasProblem, isTrue);
    });

    test('a day with only a change does not', () async {
      final ChangeEntry entry = await change(DateTime.utc(2026, 8, 12));

      final CalendarMonth month = build(entries: <HistoryEntry>[entry]);

      expect(month.dayOn(entry.localDay)!.hasProblem, isFalse);
    });

    test('an empty day is empty', () {
      expect(build().dayOn(DateTime(2026, 8, 12))!.hasAnything, isFalse);
    });
  });

  group('what it expects', () {
    test('a deadline ahead of today is marked', () async {
      final ChangeDue expectation = await due(
        today.add(const Duration(days: 4)).toUtc(),
      );

      final CalendarMonth month = build(
        expectations: <CalendarExpectation>[expectation],
      );

      expect(
        month.dayOn(expectation.localDay)!.expectations.single.id,
        expectation.id,
      );
    });

    test('today itself still counts as ahead', () async {
      final ChangeDue expectation = await due(today.toUtc());

      final CalendarMonth month = build(
        expectations: <CalendarExpectation>[expectation],
      );

      expect(month.dayOn(today)!.expectations, hasLength(1));
    });

    test('a deadline in the past is dropped', () async {
      // Either it happened, in which case there is a real entry for it, or it
      // did not, in which case Home is already saying so. A stale marker here
      // would only disagree with one of them.
      final ChangeDue expectation = await due(
        today.subtract(const Duration(days: 3)).toUtc(),
      );

      final CalendarMonth month = build(
        expectations: <CalendarExpectation>[expectation],
      );

      expect(month.dayOn(expectation.localDay)!.expectations, isEmpty);
    });

    test('stock going off is expected too', () async {
      final InventoryItem batch = await h.inventory.createItem(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        quantity: 4,
        expirationDate: today.add(const Duration(days: 10)).toUtc(),
      );
      final StockExpires expectation = StockExpires(batch: batch, type: sensor);

      final CalendarMonth month = build(
        expectations: <CalendarExpectation>[expectation],
      );

      expect(month.dayOn(expectation.localDay)!.expectations, hasLength(1));
    });

    test(
      'an expectation is never confused for something that happened',
      () async {
        // A history entry is a record; an expectation is a date the app worked
        // out, and it moves the moment the user does anything.
        final ChangeDue expectation = await due(
          today.add(const Duration(days: 4)).toUtc(),
        );

        final CalendarMonth month = build(
          expectations: <CalendarExpectation>[expectation],
        );

        final CalendarDay day = month.dayOn(expectation.localDay)!;
        expect(day.entries, isEmpty);
        expect(day.hasAnything, isTrue);
        expect(month.entryCount, 0);
      },
    );
  });

  test('two grids of the same facts are equal', () async {
    final List<HistoryEntry> entries = <HistoryEntry>[
      await change(DateTime.utc(2026, 8, 12)),
    ];

    expect(build(entries: entries), build(entries: entries));
    expect(build(entries: entries).hashCode, build(entries: entries).hashCode);
  });
}

/// Reads the weekday off a calendar square, for the grid-start assertions.
extension on CalendarDay {
  int get weekday => day.weekday;
}
