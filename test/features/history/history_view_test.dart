import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/history/domain/history_entry.dart';
import 'package:blauloop/features/history/domain/history_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The timeline's merge, ordering, grouping and filters, at fixed instants.
void main() {
  /// Labelling *Today* and *Yesterday* is date arithmetic, so the day it is
  /// measured against is passed in rather than read off a clock.
  final DateTime today = DateTime(2026, 8, 21);

  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;
  late ConsumableType set;
  late ConsumableInstance instance;
  late ConsumableInstance previous;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 21, 9));
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'CGM sensor');
    set = await h.seedType(
      name: 'Infusion set',
      category: ConsumableCategory.infusionSet,
    );
    // A real row, because `previousConsumableInstanceId` is a foreign key and
    // a made-up id is refused by the database rather than by the test.
    previous = await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: DateTime.utc(2026, 7, 20),
      status: ConsumableStatus.completed,
    );
    instance = await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: DateTime.utc(2026, 8, 1),
    );
  });

  Future<ChangeEntry> change({
    DateTime? at,
    ConsumableType? type,
    ChangeType reason = ChangeType.scheduled,
    String? notes,
  }) async {
    final ChangeEvent event = await h.changes.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      changedAt: at ?? DateTime.utc(2026, 8, 20, 10),
      type: reason,
      previousConsumableInstanceId: previous.id,
      notes: notes,
    );
    return ChangeEntry(event: event, type: type ?? sensor);
  }

  Future<IncidentEntry> incident({
    DateTime? at,
    ConsumableType? type,
    IncidentType reason = IncidentType.occlusion,
  }) async {
    final Incident row = await h.incidents.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      occurredAt: at ?? DateTime.utc(2026, 8, 20, 14),
      type: reason,
    );
    return IncidentEntry(incident: row, type: type ?? sensor);
  }

  group('merging the two sources', () {
    test('a timeline carries changes and problems together', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[await change(), await incident()],
      );

      expect(view.totalEntries, 2);
      expect(view.entries.whereType<ChangeEntry>(), hasLength(1));
      expect(view.entries.whereType<IncidentEntry>(), hasLength(1));
    });

    test('a problem the user rode out is still in the history', () async {
      // It wrote an Incidents row and no change event, because nothing was
      // installed. A timeline reading only changes would drop it silently,
      // which is the worst way for a history to be wrong.
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await incident(reason: IncidentType.irritation),
        ],
      );

      expect(view.totalEntries, 1);
      expect(view.entries.single, isA<IncidentEntry>());
    });
  });

  group('ordering', () {
    test('newest first', () async {
      final ChangeEntry older = await change(at: DateTime.utc(2026, 8, 10));
      final ChangeEntry newer = await change(at: DateTime.utc(2026, 8, 18));

      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[older, newer],
      );

      expect(view.entries.first.id, newer.id);
    });

    test('a change and a problem on one day sort by the hour', () async {
      final ChangeEntry morning = await change(
        at: DateTime.utc(2026, 8, 20, 8),
      );
      final IncidentEntry evening = await incident(
        at: DateTime.utc(2026, 8, 20, 19),
      );

      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[morning, evening],
      );

      expect(view.days.single.entries.first.id, evening.id);
    });

    test(
      'two entries at the same instant do not swap between rebuilds',
      () async {
        final DateTime same = DateTime.utc(2026, 8, 20, 12);
        final ChangeEntry a = await change(at: same);
        final IncidentEntry b = await incident(at: same);

        expect(
          HistoryView.from(
            today: today,
            entries: <HistoryEntry>[a, b],
          ).entries.first.id,
          HistoryView.from(
            today: today,
            entries: <HistoryEntry>[b, a],
          ).entries.first.id,
        );
      },
    );
  });

  group('grouping by day', () {
    test('one heading per day, newest day first', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await change(at: DateTime.utc(2026, 8, 18, 9)),
          await change(at: DateTime.utc(2026, 8, 20, 9)),
          await change(at: DateTime.utc(2026, 8, 20, 20)),
        ],
      );

      expect(view.days, hasLength(2));
      expect(view.days.first.entries, hasLength(2));
      expect(view.days.first.day.isAfter(view.days.last.day), isTrue);
    });

    test('the day is the local one, not the UTC one', () async {
      // A change logged late on Tuesday belongs to Tuesday for the person who
      // made it, whatever UTC calls it.
      final ChangeEntry entry = await change(
        at: DateTime.utc(2026, 8, 20, 23, 30),
      );
      final DateTime local = entry.occurredAt.toLocal();

      expect(entry.localDay, DateTime(local.year, local.month, local.day));
    });
  });

  group('filters', () {
    test('changes only leaves the problems out', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[await change(), await incident()],
        filter: HistoryFilter.changes,
      );

      expect(view.totalEntries, 1);
      expect(view.entries.single, isA<ChangeEntry>());
    });

    test('problems only leaves the changes out', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[await change(), await incident()],
        filter: HistoryFilter.problems,
      );

      expect(view.totalEntries, 1);
      expect(view.entries.single, isA<IncidentEntry>());
    });

    test('narrowing to one consumable drops the others', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await change(),
          await change(type: set),
          await incident(type: set),
        ],
        consumableTypeId: set.id,
      );

      expect(view.totalEntries, 2);
      expect(
        view.entries.every((HistoryEntry e) => e.type.id == set.id),
        isTrue,
      );
    });

    test('the two filters apply together', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await change(type: set),
          await incident(type: set),
          await incident(),
        ],
        filter: HistoryFilter.problems,
        consumableTypeId: set.id,
      );

      expect(view.totalEntries, 1);
      expect(view.entries.single.type.id, set.id);
    });

    test(
      'a filter that matches nothing gives an empty view, not a crash',
      () async {
        final HistoryView view = HistoryView.from(
          today: today,
          entries: <HistoryEntry>[await change()],
          filter: HistoryFilter.problems,
        );

        expect(view.isEmpty, isTrue);
        expect(view.days, isEmpty);
      },
    );
  });

  group('what an entry says about itself', () {
    test('a change carries its reason and its note', () async {
      final ChangeEntry entry = await change(
        reason: ChangeType.early,
        notes: 'going swimming',
      );

      expect(entry.reason, ChangeType.early);
      expect(entry.notes, 'going swimming');
    });

    test('a problem carries its reason', () async {
      final IncidentEntry entry = await incident(
        reason: IncidentType.adhesiveFailure,
      );

      expect(entry.reason, IncidentType.adhesiveFailure);
    });

    test('a first ever change knows it replaced nothing', () async {
      final ChangeEvent event = await h.changes.create(
        userProfileId: profile.id,
        consumableInstanceId: instance.id,
        changedAt: DateTime.utc(2026, 8, 1),
        type: ChangeType.scheduled,
      );

      expect(ChangeEntry(event: event, type: sensor).isFirstEver, isTrue);
      expect((await change()).isFirstEver, isFalse);
    });
  });

  group('date headings', () {
    test('today reads as today', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[await change(at: today.toUtc())],
      );

      expect(view.days.single.isToday, isTrue);
      expect(view.days.single.isYesterday, isFalse);
    });

    test('the day before reads as yesterday', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await change(at: today.subtract(const Duration(days: 1)).toUtc()),
        ],
      );

      expect(view.days.single.isYesterday, isTrue);
      expect(view.days.single.isToday, isFalse);
    });

    test('anything older is neither, and gets a date instead', () async {
      final HistoryView view = HistoryView.from(
        today: today,
        entries: <HistoryEntry>[
          await change(at: today.subtract(const Duration(days: 5)).toUtc()),
        ],
      );

      expect(view.days.single.isToday, isFalse);
      expect(view.days.single.isYesterday, isFalse);
    });
  });

  test('two views of the same facts are equal', () async {
    final List<HistoryEntry> entries = <HistoryEntry>[
      await change(),
      await incident(),
    ];

    expect(
      HistoryView.from(today: today, entries: entries),
      HistoryView.from(today: today, entries: entries),
    );
    expect(
      HistoryView.from(today: today, entries: entries).hashCode,
      HistoryView.from(today: today, entries: entries).hashCode,
    );
  });
}
