import 'package:blauloop/core/database/app_database.dart';
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

  group('BodySiteRepository', () {
    test('derives the side from the region', () async {
      final BodySite left = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.lowerLeftAbdomen,
      );
      final BodySite right = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.rightThigh,
      );

      expect(left.side, BodySide.left);
      expect(right.side, BodySide.right);
    });

    test('lets a custom site state its own side', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.other,
        side: BodySide.left,
        customName: 'Left love handle',
      );

      expect(site.side, BodySide.left);
      expect(site.customName, 'Left love handle');
    });

    test('stores an optional exact position within the region', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.leftArm,
        normalizedX: 0.25,
        normalizedY: 0.4,
      );

      expect(site.normalizedX, 0.25);
      expect(site.normalizedY, 0.4);
    });

    test('createDefaults sets up the standard body map', () async {
      final List<BodySite> sites = await h.bodySites.createDefaults(profile.id);

      expect(sites, hasLength(BodyRegionX.defaults.length));
      expect(
        sites.map((BodySite s) => s.bodyRegion).toSet(),
        BodyRegionX.defaults.toSet(),
      );
    });

    test('createDefaults is atomic', () async {
      // Onboarding must not be able to leave a profile with half a body map.
      await h.bodySites.createDefaults(profile.id);

      expect(await h.bodySites.findAll(profile.id), hasLength(10));
    });

    test(
      'deactivating keeps the row, so past usage keeps its location',
      () async {
        final BodySite site = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.leftArm,
        );

        await h.bodySites.deactivate(site.id);

        expect(await h.bodySites.watchActive(profile.id).first, isEmpty);
        expect(await h.bodySites.findById(site.id), isNotNull);
      },
    );

    test('sites belong to one profile only', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Lucas');
      await h.bodySites.createDefaults(profile.id);

      expect(await h.bodySites.watchActive(other.id).first, isEmpty);
    });
  });

  group('SiteUsageRepository', () {
    test('opens a usage with no end', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.leftArm,
      );
      final ConsumableInstance instance = await install();

      final SiteUsage usage = await h.siteUsages.open(
        bodySiteId: site.id,
        consumableInstanceId: instance.id,
        startedAt: h.clock.nowUtc(),
      );

      expect(usage.endedAt, isNull);
      expect(await h.siteUsages.findOpenForSite(site.id), isNotNull);
    });

    test('closing by instance frees the site', () async {
      final BodySite site = await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.leftArm,
      );
      final ConsumableInstance instance = await install();
      await h.siteUsages.open(
        bodySiteId: site.id,
        consumableInstanceId: instance.id,
        startedAt: h.clock.nowUtc(),
      );

      h.clock.advance(const Duration(days: 10));
      await h.siteUsages.closeForInstance(
        instance.id,
        endedAt: h.clock.nowUtc(),
      );

      expect(await h.siteUsages.findOpenForSite(site.id), isNull);
      final List<SiteUsage> all = await h.siteUsages.findForSite(site.id);
      expect(all.single.endedAt, DateTime.utc(2026, 8, 27, 9));
    });

    test('closing an instance that occupies nothing is harmless', () async {
      final ConsumableInstance instance = await install();

      await h.siteUsages.closeForInstance(
        instance.id,
        endedAt: h.clock.nowUtc(),
      );

      expect(await h.db.select(h.db.siteUsages).get(), isEmpty);
    });

    group('lastUsedBySite', () {
      test('reports null for a site never used', () async {
        // "Never used" and "rested a long time" look identical if you only
        // report a duration, and they mean different things.
        final BodySite site = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.leftArm,
        );

        final Map<String, DateTime?> lastUsed = await h.siteUsages
            .lastUsedBySite(profile.id);

        expect(lastUsed, containsPair(site.id, isNull));
      });

      test(
        'reports the most recent start for a site used repeatedly',
        () async {
          final BodySite site = await h.bodySites.create(
            userProfileId: profile.id,
            bodyRegion: BodyRegion.leftArm,
          );
          final ConsumableInstance first = await install();
          await h.siteUsages.open(
            bodySiteId: site.id,
            consumableInstanceId: first.id,
            startedAt: DateTime.utc(2026, 7, 1),
          );
          await h.siteUsages.closeForInstance(
            first.id,
            endedAt: DateTime.utc(2026, 7, 10),
          );
          await h.instances.close(
            first.id,
            removedAt: DateTime.utc(2026, 7, 10),
            status: ConsumableStatus.completed,
          );
          final ConsumableInstance second = await install();
          await h.siteUsages.open(
            bodySiteId: site.id,
            consumableInstanceId: second.id,
            startedAt: DateTime.utc(2026, 8, 1),
          );

          final Map<String, DateTime?> lastUsed = await h.siteUsages
              .lastUsedBySite(profile.id);

          expect(lastUsed[site.id], DateTime.utc(2026, 8, 1));
        },
      );

      test('excludes deactivated sites', () async {
        final BodySite site = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.leftArm,
        );
        await h.bodySites.deactivate(site.id);

        expect(await h.siteUsages.lastUsedBySite(profile.id), isEmpty);
      });

      test('is scoped to one profile', () async {
        final UserProfile other = await h.seedProfile(displayName: 'Lucas');
        await h.bodySites.createDefaults(profile.id);

        expect(await h.siteUsages.lastUsedBySite(other.id), isEmpty);
      });
    });

    group('siteIdsByRestDescending', () {
      test('puts never-used sites first', () async {
        final BodySite used = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.leftArm,
        );
        final BodySite never = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.rightArm,
        );
        final ConsumableInstance instance = await install();
        await h.siteUsages.open(
          bodySiteId: used.id,
          consumableInstanceId: instance.id,
          startedAt: DateTime.utc(2026, 8, 1),
        );

        final List<String> ordered = await h.siteUsages.siteIdsByRestDescending(
          profile.id,
        );

        expect(ordered.first, never.id);
        expect(ordered.last, used.id);
      });

      test('orders longest-rested first among used sites', () async {
        final BodySite older = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.leftArm,
        );
        final BodySite recent = await h.bodySites.create(
          userProfileId: profile.id,
          bodyRegion: BodyRegion.rightArm,
        );
        final ConsumableInstance a = await install();
        await h.siteUsages.open(
          bodySiteId: older.id,
          consumableInstanceId: a.id,
          startedAt: DateTime.utc(2026, 6, 1),
        );
        await h.instances.close(
          a.id,
          removedAt: DateTime.utc(2026, 6, 10),
          status: ConsumableStatus.completed,
        );
        final ConsumableInstance b = await install();
        await h.siteUsages.open(
          bodySiteId: recent.id,
          consumableInstanceId: b.id,
          startedAt: DateTime.utc(2026, 8, 1),
        );

        final List<String> ordered = await h.siteUsages.siteIdsByRestDescending(
          profile.id,
        );

        expect(ordered, <String>[older.id, recent.id]);
      });

      test('is a stable ordering when several sites were never used', () async {
        await h.bodySites.createDefaults(profile.id);

        final List<String> first = await h.siteUsages.siteIdsByRestDescending(
          profile.id,
        );
        final List<String> second = await h.siteUsages.siteIdsByRestDescending(
          profile.id,
        );

        expect(first, second);
      });
    });
  });
}
