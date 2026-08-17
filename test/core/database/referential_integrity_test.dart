import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../../support/test_database.dart';

/// The constraints that keep a health log from quietly becoming fiction.
///
/// Each of these is enforced by the database rather than by application code,
/// so it holds even when two writes race — a caregiver logging a change on one
/// device while a reminder-driven flow is open on another.
void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensorType;

  setUp(() async {
    h = TestHarness.create();
    profile = await h.seedProfile();
    sensorType = await h.seedType();
  });

  group('foreign keys', () {
    test(
      'a change event cannot reference an instance that does not exist',
      () async {
        await expectLater(
          h.changes.create(
            userProfileId: profile.id,
            consumableInstanceId: 'ghost-000000000000000000000000001',
            changedAt: h.clock.nowUtc(),
            type: ChangeType.scheduled,
          ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'an instance cannot reference a consumable type that does not exist',
      () async {
        await expectLater(
          h.instances.create(
            userProfileId: profile.id,
            consumableTypeId: 'ghost-000000000000000000000000001',
            installedAt: h.clock.nowUtc(),
          ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('deleting a profile cascades to everything belonging to it', () async {
      final ConsumableInstance instance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );
      await h.changes.create(
        userProfileId: profile.id,
        consumableInstanceId: instance.id,
        changedAt: h.clock.nowUtc(),
        type: ChangeType.scheduled,
      );
      await h.incidents.create(
        userProfileId: profile.id,
        consumableInstanceId: instance.id,
        occurredAt: h.clock.nowUtc(),
        type: IncidentType.adhesiveFailure,
      );

      await h.profiles.delete(profile.id);

      expect(await h.instances.findById(instance.id), isNull);
      expect(await h.db.select(h.db.changeEvents).get(), isEmpty);
      expect(await h.db.select(h.db.incidents).get(), isEmpty);
    });

    test('a consumable type with history cannot be deleted', () async {
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );

      // RESTRICT, not CASCADE. Deleting a type the user once used would erase
      // the changes they recorded — the type is deactivated instead.
      await expectLater(
        (h.db.delete(
          h.db.consumableTypes,
        )..where(($ConsumableTypesTable t) => t.id.equals(sensorType.id))).go(),
        throwsA(isA<SqliteException>()),
      );
    });

    test('deleting a device leaves its instances, unlinked', () async {
      final Device pump = await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'P1',
      );
      final ConsumableInstance instance = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
        deviceId: pump.id,
      );

      await (h.db.delete(
        h.db.devices,
      )..where(($DevicesTable t) => t.id.equals(pump.id))).go();

      // SET NULL: losing the pump must not lose the record that a set was
      // changed.
      final ConsumableInstance? reloaded = await h.instances.findById(
        instance.id,
      );
      expect(reloaded, isNotNull);
      expect(reloaded!.deviceId, isNull);
    });
  });

  group('one active instance per consumable type', () {
    test('a second active instance of the same type is rejected', () async {
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );

      // You are not wearing two sensors.
      await expectLater(
        h.instances.create(
          userProfileId: profile.id,
          consumableTypeId: sensorType.id,
          installedAt: h.clock.nowUtc(),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a new instance is allowed once the previous one is closed', () async {
      final ConsumableInstance first = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );

      await h.instances.close(
        first.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.completed,
      );

      final ConsumableInstance second = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );

      expect(second.id, isNot(first.id));
    });

    test('closed instances of the same type may pile up freely', () async {
      for (int i = 0; i < 3; i++) {
        final ConsumableInstance instance = await h.instances.create(
          userProfileId: profile.id,
          consumableTypeId: sensorType.id,
          installedAt: h.clock.nowUtc(),
        );
        await h.instances.close(
          instance.id,
          removedAt: h.clock.nowUtc(),
          status: ConsumableStatus.completed,
        );
        h.clock.advance(const Duration(days: 10));
      }

      final List<ConsumableInstance> all = await h.db
          .select(h.db.consumableInstances)
          .get();
      expect(all, hasLength(3));
    });

    test('two different types may each be active at once', () async {
      final ConsumableType setType = await h.seedType(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
        defaultDuration: const Duration(days: 3),
      );

      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );
      final ConsumableInstance set = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: setType.id,
        installedAt: h.clock.nowUtc(),
      );

      expect(set.status, ConsumableStatus.active);
      expect(await h.instances.watchActive(profile.id).first, hasLength(2));
    });

    test('two profiles may each wear the same type of sensor', () async {
      final UserProfile child = await h.seedProfile(displayName: 'Lucas');

      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );
      final ConsumableInstance childSensor = await h.instances.create(
        userProfileId: child.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );

      expect(childSensor.userProfileId, child.id);
    });
  });

  group('one open usage per body site', () {
    test('a site cannot be occupied by two things at once', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.leftArm,
      );
      final ConsumableInstance first = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
        bodySiteId: site.id,
      );
      final ConsumableType setType = await h.seedType(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      );
      final ConsumableInstance second = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: setType.id,
        installedAt: h.clock.nowUtc(),
        bodySiteId: site.id,
      );

      await h.siteUsages.open(
        bodySiteId: site.id,
        consumableInstanceId: first.id,
        startedAt: h.clock.nowUtc(),
      );

      await expectLater(
        h.siteUsages.open(
          bodySiteId: site.id,
          consumableInstanceId: second.id,
          startedAt: h.clock.nowUtc(),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('the site frees up once the usage is closed', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.leftArm,
      );
      final ConsumableInstance first = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );
      await h.siteUsages.open(
        bodySiteId: site.id,
        consumableInstanceId: first.id,
        startedAt: h.clock.nowUtc(),
      );

      h.clock.advance(const Duration(days: 10));
      await h.siteUsages.closeForInstance(first.id, endedAt: h.clock.nowUtc());
      await h.instances.close(
        first.id,
        removedAt: h.clock.nowUtc(),
        status: ConsumableStatus.completed,
      );

      final ConsumableInstance second = await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensorType.id,
        installedAt: h.clock.nowUtc(),
      );
      final SiteUsage reopened = await h.siteUsages.open(
        bodySiteId: site.id,
        consumableInstanceId: second.id,
        startedAt: h.clock.nowUtc(),
      );

      expect(reopened.endedAt, isNull);
      expect(await h.siteUsages.findForSite(site.id), hasLength(2));
    });
  });

  group('quantity constraints', () {
    test('the database refuses a negative stock count', () async {
      await expectLater(
        h.db.customStatement(
          'INSERT INTO inventory_items '
          '(id, user_profile_id, consumable_type_id, quantity, '
          'minimum_quantity, created_at, updated_at) '
          "VALUES ('bad-0000000000000000000000000001', '${profile.id}', "
          "'${sensorType.id}', -1, 0, '2026-08-17T09:00:00.000Z', "
          "'2026-08-17T09:00:00.000Z')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
