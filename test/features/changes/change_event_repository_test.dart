import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'Sensor');
  });

  Future<ConsumableInstance> install() {
    return h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: h.clock.nowUtc(),
    );
  }

  Future<ChangeEvent> logChange(
    ConsumableInstance instance, {
    ChangeType type = ChangeType.scheduled,
    DateTime? changedAt,
    String? previousInstanceId,
  }) {
    return h.changes.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      changedAt: changedAt ?? h.clock.nowUtc(),
      type: type,
      previousConsumableInstanceId: previousInstanceId,
    );
  }

  test('records what went on and what came off', () async {
    final ConsumableInstance first = await install();
    await h.instances.close(
      first.id,
      removedAt: h.clock.nowUtc(),
      status: ConsumableStatus.completed,
    );
    final ConsumableInstance second = await install();

    final ChangeEvent event = await logChange(
      second,
      previousInstanceId: first.id,
    );

    expect(event.consumableInstanceId, second.id);
    expect(event.previousConsumableInstanceId, first.id);
  });

  test('allows no predecessor, for the first ever change', () async {
    final ChangeEvent event = await logChange(await install());

    expect(event.previousConsumableInstanceId, isNull);
  });

  test('separates when it happened from when it was written down', () async {
    // A 3 a.m. sensor swap entered at breakfast. The difference is sometimes
    // the interesting part.
    final ConsumableInstance instance = await install();
    h.clock.advance(const Duration(hours: 6));

    final ChangeEvent event = await logChange(
      instance,
      changedAt: DateTime.utc(2026, 8, 17, 3, 17),
    );

    expect(event.changedAt, DateTime.utc(2026, 8, 17, 3, 17));
    expect(event.createdAt, DateTime.utc(2026, 8, 17, 15));
  });

  test('records the site a change moved between', () async {
    final BodySite from = await h.bodySites.create(
      userProfileId: profile.id,
      bodyRegion: BodyRegion.leftArm,
    );
    final BodySite to = await h.bodySites.create(
      userProfileId: profile.id,
      bodyRegion: BodyRegion.rightArm,
    );
    final ConsumableInstance instance = await install();

    final ChangeEvent event = await h.changes.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      changedAt: h.clock.nowUtc(),
      type: ChangeType.scheduled,
      previousBodySiteId: from.id,
      newBodySiteId: to.id,
    );

    expect(event.previousBodySiteId, from.id);
    expect(event.newBodySiteId, to.id);
  });

  test('normalises changedAt to UTC', () async {
    final ChangeEvent event = await logChange(
      await install(),
      changedAt: DateTime(2026, 8, 17, 11),
    );

    expect(event.changedAt.isUtc, isTrue);
  });

  group('timeline', () {
    test('lists most recent first', () async {
      final ConsumableInstance instance = await install();
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 10));
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 15));
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 12));

      final List<ChangeEvent> timeline = await h.changes
          .watchTimeline(profile.id)
          .first;

      expect(timeline.map((ChangeEvent e) => e.changedAt), <DateTime>[
        DateTime.utc(2026, 8, 15),
        DateTime.utc(2026, 8, 12),
        DateTime.utc(2026, 8, 10),
      ]);
    });

    test('respects the limit', () async {
      final ConsumableInstance instance = await install();
      for (int i = 1; i <= 5; i++) {
        await logChange(instance, changedAt: DateTime.utc(2026, 8, i));
      }

      final List<ChangeEvent> timeline = await h.changes
          .watchTimeline(profile.id, limit: 2)
          .first;

      expect(timeline, hasLength(2));
    });

    test('is scoped to one profile', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Lucas');
      await logChange(await install());

      expect(await h.changes.watchTimeline(other.id).first, isEmpty);
    });

    test('filters to the requested reasons', () async {
      final ConsumableInstance instance = await install();
      await logChange(instance, type: ChangeType.scheduled);
      await logChange(instance, type: ChangeType.incident);
      await logChange(instance, type: ChangeType.early);

      final List<ChangeEvent> incidents = await h.changes.watchTimelineOfTypes(
        profile.id,
        <ChangeType>{ChangeType.incident},
      ).first;

      expect(incidents, hasLength(1));
      expect(incidents.single.type, ChangeType.incident);
    });

    test('an empty filter yields nothing rather than everything', () async {
      await logChange(await install());

      final List<ChangeEvent> filtered = await h.changes
          .watchTimelineOfTypes(profile.id, const <ChangeType>{})
          .first;

      expect(filtered, isEmpty);
    });
  });

  group('findBetween', () {
    test('includes the start of the range and excludes the end', () async {
      // Half-open, so adjacent calendar days cannot both claim the same event.
      final ConsumableInstance instance = await install();
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 10));
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 11));

      final List<ChangeEvent> found = await h.changes.findBetween(
        profile.id,
        DateTime.utc(2026, 8, 10),
        DateTime.utc(2026, 8, 11),
      );

      expect(found, hasLength(1));
      expect(found.single.changedAt, DateTime.utc(2026, 8, 10));
    });

    test('returns results oldest first, for a calendar', () async {
      final ConsumableInstance instance = await install();
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 15));
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 12));

      final List<ChangeEvent> found = await h.changes.findBetween(
        profile.id,
        DateTime.utc(2026, 8, 1),
        DateTime.utc(2026, 9, 1),
      );

      expect(found.map((ChangeEvent e) => e.changedAt), <DateTime>[
        DateTime.utc(2026, 8, 12),
        DateTime.utc(2026, 8, 15),
      ]);
    });
  });

  group('countByTypeSince', () {
    test('counts each reason separately', () async {
      final ConsumableInstance instance = await install();
      await logChange(instance, type: ChangeType.scheduled);
      await logChange(instance, type: ChangeType.scheduled);
      await logChange(instance, type: ChangeType.incident);

      final Map<ChangeType, int> counts = await h.changes.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 1, 1),
      );

      expect(counts[ChangeType.scheduled], 2);
      expect(counts[ChangeType.incident], 1);
      expect(counts[ChangeType.early], isNull);
    });

    test('ignores anything before the cutoff', () async {
      final ConsumableInstance instance = await install();
      await logChange(instance, changedAt: DateTime.utc(2026, 1, 1));
      await logChange(instance, changedAt: DateTime.utc(2026, 8, 1));

      final Map<ChangeType, int> counts = await h.changes.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 7, 1),
      );

      expect(counts[ChangeType.scheduled], 1);
    });

    test('returns an empty map when there is nothing to count', () async {
      final Map<ChangeType, int> counts = await h.changes.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 1, 1),
      );

      expect(counts, isEmpty);
    });

    test('keeps manual corrections out of the failure counts', () async {
      // A correction is not a change. Letting it inflate the incident count
      // would make the history lie about how often things go wrong.
      final ConsumableInstance instance = await install();
      await logChange(instance, type: ChangeType.manualCorrection);

      final Map<ChangeType, int> counts = await h.changes.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 1, 1),
      );

      expect(counts[ChangeType.manualCorrection], 1);
      expect(counts[ChangeType.incident], isNull);
      expect(counts[ChangeType.scheduled], isNull);
    });
  });
}
