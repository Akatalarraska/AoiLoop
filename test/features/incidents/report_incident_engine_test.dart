import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/errors/app_failure.dart';
import 'package:blauloop/features/changes/data/cycle_engine.dart';
import 'package:blauloop/features/incidents/domain/incident_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The incident half of the cycle engine, at fixed instants.
///
/// Every assertion here is about what ended up in the database, because that
/// is the product: a report the app half-wrote would be worse than one it
/// refused to write at all.
void main() {
  late TestHarness h;
  late CycleEngine engine;
  late UserProfile profile;
  late ConsumableType sensor;

  const Duration tenDays = Duration(days: 10);

  /// When the instance under test went on. Local, because a user picks local
  /// times; the engine is what converts.
  final DateTime installedAt = DateTime(2026, 8, 11, 12);

  setUp(() async {
    h = TestHarness.create(now: installedAt.toUtc());
    engine = h.cycleEngine();
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'Sensor', defaultDuration: tenDays);
  });

  /// Puts something on, so there is a cycle for a failure to interrupt.
  Future<ConsumableInstance> install({DateTime? at, DateTime? due}) {
    final DateTime moment = at ?? installedAt;
    return h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: moment,
      expectedChangeAt: due ?? moment.add(tenDays),
    );
  }

  Future<IncidentRecord> report({
    IncidentType type = IncidentType.occlusion,
    IncidentOutcome outcome = IncidentOutcome.replaced,
    DateTime? occurredAt,
    DateTime? replacedAt,
    String? notes,
    int? profileMinuteOfDay,
    bool usePreferredTime = false,
  }) {
    return engine.reportIncident(
      userProfileId: profile.id,
      type: sensor,
      report: IncidentReport(
        type: type,
        occurredAt: occurredAt ?? installedAt.add(const Duration(days: 3)),
        outcome: outcome,
        notes: notes,
      ),
      replacedAt: replacedAt,
      profileMinuteOfDay: profileMinuteOfDay,
      usePreferredTime: usePreferredTime,
    );
  }

  Future<List<Incident>> allIncidents() => h.db.select(h.db.incidents).get();
  Future<List<ChangeEvent>> allChanges() =>
      h.db.select(h.db.changeEvents).get();

  group('the incident row', () {
    test('is written whatever the user did next', () async {
      // A type each, because "kept in use" leaves its instance active and a
      // second active instance of one type is what the partial unique index
      // exists to refuse.
      for (final IncidentOutcome outcome in IncidentOutcome.values) {
        final ConsumableType type = await h.seedType(
          name: outcome.name,
          defaultDuration: tenDays,
        );
        await h.instances.create(
          userProfileId: profile.id,
          consumableTypeId: type.id,
          installedAt: installedAt,
          expectedChangeAt: installedAt.add(tenDays),
        );
        await engine.reportIncident(
          userProfileId: profile.id,
          type: type,
          report: IncidentReport(
            type: IncidentType.occlusion,
            occurredAt: installedAt.add(const Duration(days: 3)),
            outcome: outcome,
          ),
        );
      }

      expect(await allIncidents(), hasLength(IncidentOutcome.values.length));
    });

    test(
      'points at the instance that failed, not at its replacement',
      () async {
        final ConsumableInstance failed = await install();

        final IncidentRecord record = await report();

        expect(record.incident.consumableInstanceId, failed.id);
        expect(record.replacement!.id, isNot(failed.id));
      },
    );

    test(
      'keeps the moment it happened, not the moment it was logged',
      () async {
        await install();
        final DateTime occurredAt = installedAt.add(const Duration(days: 2));

        // The clock is still sitting at the install. A report written up later
        // must not quietly take "now" for "when".
        final IncidentRecord record = await report(occurredAt: occurredAt);

        expect(record.incident.occurredAt, occurredAt.toUtc());
        expect(record.incident.createdAt, h.clock.now().toUtc());
      },
    );

    test('carries the reason and the note the user gave', () async {
      await install();

      final IncidentRecord record = await report(
        type: IncidentType.adhesiveFailure,
        notes: '  lifted in the shower  ',
      );

      expect(record.incident.type, IncidentType.adhesiveFailure);
      expect(record.incident.notes, 'lifted in the shower');
    });
  });

  group('kept in use', () {
    test('leaves the cycle exactly as it was', () async {
      final ConsumableInstance before = await install();

      await report(outcome: IncidentOutcome.keptInUse);

      final ConsumableInstance? after = await h.instances.findById(before.id);
      expect(after, before);
    });

    test('records nothing as a change', () async {
      await install();

      final IncidentRecord record = await report(
        outcome: IncidentOutcome.keptInUse,
      );

      expect(record.wasReplaced, isFalse);
      expect(record.event, isNull);
      expect(await allChanges(), isEmpty);
    });
  });

  group('removed without a replacement', () {
    test('closes the instance and opens nothing', () async {
      final ConsumableInstance failed = await install();
      final DateTime occurredAt = installedAt.add(const Duration(days: 3));

      final IncidentRecord record = await report(
        outcome: IncidentOutcome.removed,
        occurredAt: occurredAt,
      );

      final ConsumableInstance? closed = await h.instances.findById(failed.id);
      expect(closed!.status, ConsumableStatus.removedEarly);
      expect(closed.removedAt, occurredAt.toUtc());
      expect(record.replacement, isNull);
      expect(await h.instances.findActive(profile.id), isEmpty);
    });

    test('writes no change event, because nothing was installed', () async {
      await install();

      await report(outcome: IncidentOutcome.removed);

      expect(await allChanges(), isEmpty);
    });
  });

  group('replaced', () {
    test('closes one, opens the next, and links them', () async {
      final ConsumableInstance failed = await install();
      final DateTime occurredAt = installedAt.add(const Duration(days: 3));

      final IncidentRecord record = await report(occurredAt: occurredAt);

      expect(record.failed.id, failed.id);
      expect(record.replacement!.installedAt, occurredAt.toUtc());
      expect(record.event!.previousConsumableInstanceId, failed.id);
      expect(record.event!.consumableInstanceId, record.replacement!.id);
    });

    test('records the change as an incident, not as an early swap', () async {
      // The distinction is the whole point of the type: a set changed early
      // for a holiday and one changed early because it occluded are not the
      // same event, and a history that conflated them would be useless.
      await install();

      final IncidentRecord record = await report();

      expect(record.event!.type, ChangeType.incident);
    });

    test('dates the new deadline from the replacement', () async {
      await install();
      final DateTime occurredAt = installedAt.add(const Duration(days: 3));

      final IncidentRecord record = await report(occurredAt: occurredAt);

      expect(
        record.replacement!.expectedChangeAt,
        occurredAt.add(tenDays).toUtc(),
      );
    });

    test('accepts a replacement fitted later than the failure', () async {
      await install();
      final DateTime occurredAt = installedAt.add(const Duration(days: 3));
      final DateTime replacedAt = occurredAt.add(const Duration(hours: 6));

      final IncidentRecord record = await report(
        occurredAt: occurredAt,
        replacedAt: replacedAt,
      );

      // Six hours of difference is six hours of deadline. Taking the failure
      // for both would put the next change out by a quarter of a day.
      expect(record.incident.occurredAt, occurredAt.toUtc());
      expect(record.replacement!.installedAt, replacedAt.toUtc());
      expect(
        record.replacement!.expectedChangeAt,
        replacedAt.add(tenDays).toUtc(),
      );
    });

    test('carries the device and the site across', () async {
      final Device pump = await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Test',
        model: 'One',
      );
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.upperLeftAbdomen,
      );
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: installedAt,
        expectedChangeAt: installedAt.add(tenDays),
        deviceId: pump.id,
        bodySiteId: site.id,
      );

      final IncidentRecord record = await report();

      // The hardware is still the same hardware. Choosing a *different* site
      // after a reaction is the body map's job, in Phase 7.
      expect(record.replacement!.deviceId, pump.id);
      expect(record.replacement!.bodySiteId, site.id);
      expect(record.event!.previousBodySiteId, site.id);
    });

    test('honours the preferred change time when it is accepted', () async {
      await install();
      final DateTime occurredAt = DateTime(2026, 8, 14, 3, 17);

      final IncidentRecord record = await report(
        occurredAt: occurredAt,
        profileMinuteOfDay: 9 * 60,
        usePreferredTime: true,
      );

      expect(record.schedule!.offersPreferredTime, isTrue);
      expect(record.replacement!.expectedChangeAt, isNotNull);
      expect(
        record.replacement!.expectedChangeAt!.isBefore(
          occurredAt.add(tenDays).toUtc(),
        ),
        isTrue,
      );
    });
  });

  group('how the failed instance is closed', () {
    test('is an early removal when it had life left', () async {
      final ConsumableInstance failed = await install();

      await report(occurredAt: installedAt.add(const Duration(days: 3)));

      final ConsumableInstance? closed = await h.instances.findById(failed.id);
      expect(closed!.status, ConsumableStatus.removedEarly);
    });

    test('is completed when it had already run its course', () async {
      // A set that occludes an hour after its deadline did its job. Recording
      // that as an early removal would put a mark in someone's history for a
      // consumable that lasted exactly as long as it was meant to.
      final ConsumableInstance failed = await install();

      await report(
        occurredAt: installedAt.add(tenDays).add(const Duration(hours: 1)),
      );

      final ConsumableInstance? closed = await h.instances.findById(failed.id);
      expect(closed!.status, ConsumableStatus.completed);
    });

    test('is completed from the moment the app called it due soon', () async {
      // Shares the dashboard's own 24 hour threshold, so what Home *called*
      // due soon is what the history *records* as having run its course.
      final ConsumableInstance failed = await install();

      await report(
        occurredAt: installedAt.add(tenDays).subtract(const Duration(hours: 2)),
      );

      final ConsumableInstance? closed = await h.instances.findById(failed.id);
      expect(closed!.status, ConsumableStatus.completed);
    });

    test('an instance with no deadline never counts as early', () async {
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: installedAt,
      );

      final IncidentRecord record = await report();

      final ConsumableInstance? closed = await h.instances.findById(
        record.failed.id,
      );
      expect(closed!.status, ConsumableStatus.completed);
    });
  });

  group('what it refuses', () {
    test('a failure on something that is not in use', () async {
      // Reachable when the card the sheet was opened from went stale.
      expect(
        () => report(),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            'instance',
          ),
        ),
      );
    });

    test('a failure dated before the install it is about', () async {
      await install();

      expect(
        () =>
            report(occurredAt: installedAt.subtract(const Duration(hours: 1))),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            'occurredAt',
          ),
        ),
      );
    });

    test('a replacement fitted before the failure happened', () async {
      await install();
      final DateTime occurredAt = installedAt.add(const Duration(days: 3));

      expect(
        () => report(
          occurredAt: occurredAt,
          replacedAt: occurredAt.subtract(const Duration(hours: 1)),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            'replacedAt',
          ),
        ),
      );
    });

    test('and leaves the database exactly as it was', () async {
      final ConsumableInstance before = await install();

      await expectLater(
        () => report(occurredAt: installedAt.subtract(const Duration(days: 1))),
        throwsA(isA<ValidationFailure>()),
      );

      // The whole reason this is one transaction: a rejected report that had
      // already written the incident row would leave a failure recorded
      // against a cycle that never ended.
      expect(await allIncidents(), isEmpty);
      expect(await allChanges(), isEmpty);
      expect(await h.instances.findById(before.id), before);
    });
  });
}
