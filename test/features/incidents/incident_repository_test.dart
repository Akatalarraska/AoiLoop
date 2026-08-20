import 'package:aoiloop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableInstance instance;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
    final ConsumableType sensor = await h.seedType(name: 'Sensor');
    instance = await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: h.clock.nowUtc(),
    );
  });

  Future<Incident> log({
    IncidentType type = IncidentType.adhesiveFailure,
    DateTime? occurredAt,
    String? notes,
    String? photoPath,
  }) {
    return h.incidents.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      occurredAt: occurredAt ?? h.clock.nowUtc(),
      type: type,
      notes: notes,
      photoPath: photoPath,
    );
  }

  test('records what went wrong and when', () async {
    final Incident incident = await log(
      type: IncidentType.bentCannula,
      notes: 'Bent on insertion',
    );

    expect(incident.type, IncidentType.bentCannula);
    expect(incident.notes, 'Bent on insertion');
    expect(incident.consumableInstanceId, instance.id);
  });

  test('separates when it happened from when it was logged', () async {
    h.clock.advance(const Duration(hours: 8));

    final Incident incident = await log(
      occurredAt: DateTime.utc(2026, 8, 17, 3),
    );

    expect(incident.occurredAt, DateTime.utc(2026, 8, 17, 3));
    expect(incident.createdAt, DateTime.utc(2026, 8, 17, 17));
  });

  test('normalises occurredAt to UTC', () async {
    final Incident incident = await log(occurredAt: DateTime(2026, 8, 17, 3));

    expect(incident.occurredAt.isUtc, isTrue);
  });

  test('stores a photo path relative to app storage', () async {
    // Relative, because iOS changes the application container path between
    // installs and an absolute path would break.
    final Incident incident = await log(photoPath: 'incidents/abc.jpg');

    expect(incident.photoPath, 'incidents/abc.jpg');
  });

  test('notes and photo are optional', () async {
    final Incident incident = await log();

    expect(incident.notes, isNull);
    expect(incident.photoPath, isNull);
  });

  test('several incidents can attach to one instance', () async {
    // A site can be painful and then the adhesive can lift. Both are true.
    await log(type: IncidentType.pain, occurredAt: DateTime.utc(2026, 8, 17));
    await log(
      type: IncidentType.adhesiveFailure,
      occurredAt: DateTime.utc(2026, 8, 18),
    );

    final List<Incident> found = await h.incidents.findForInstance(instance.id);

    expect(found, hasLength(2));
    expect(found.first.type, IncidentType.pain);
  });

  test('watchRecent lists newest first', () async {
    await log(occurredAt: DateTime.utc(2026, 8, 10));
    await log(occurredAt: DateTime.utc(2026, 8, 15));

    final List<Incident> recent = await h.incidents
        .watchRecent(profile.id)
        .first;

    expect(recent.first.occurredAt, DateTime.utc(2026, 8, 15));
  });

  test('watchRecent is scoped to one profile', () async {
    final UserProfile other = await h.seedProfile(displayName: 'Lucas');
    await log();

    expect(await h.incidents.watchRecent(other.id).first, isEmpty);
  });

  test('deleting an incident leaves the instance intact', () async {
    final Incident incident = await log();

    await h.incidents.delete(incident.id);

    expect(await h.incidents.findById(incident.id), isNull);
    expect(await h.instances.findById(instance.id), isNotNull);
  });

  group('countByTypeSince', () {
    test('counts each failure kind separately', () async {
      await log(type: IncidentType.adhesiveFailure);
      await log(type: IncidentType.adhesiveFailure);
      await log(type: IncidentType.signalLoss);

      final Map<IncidentType, int> counts = await h.incidents.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 1, 1),
      );

      expect(counts[IncidentType.adhesiveFailure], 2);
      expect(counts[IncidentType.signalLoss], 1);
    });

    test('ignores anything before the cutoff', () async {
      await log(occurredAt: DateTime.utc(2026, 1, 1));
      await log(occurredAt: DateTime.utc(2026, 8, 1));

      final Map<IncidentType, int> counts = await h.incidents.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 7, 1),
      );

      expect(counts.values.fold<int>(0, (int a, int b) => a + b), 1);
    });

    test('returns an empty map when nothing has gone wrong', () async {
      final Map<IncidentType, int> counts = await h.incidents.countByTypeSince(
        profile.id,
        DateTime.utc(2026, 1, 1),
      );

      expect(counts, isEmpty);
    });
  });
}
