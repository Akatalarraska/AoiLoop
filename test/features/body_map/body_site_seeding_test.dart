import 'package:blauloop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Seeding the standard body sites, and the queries the body map reads
/// placement from.
void main() {
  late TestHarness h;
  late UserProfile profile;
  late ConsumableType sensor;

  final DateTime now = DateTime.utc(2026, 8, 21, 9);

  setUp(() async {
    h = TestHarness.create(now: now);
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'CGM sensor');
  });

  group('ensureDefaults', () {
    test('gives a fresh profile the standard set', () async {
      await h.bodySites.ensureDefaults(profile.id);

      final List<BodySite> sites = await h.bodySites.findAll(profile.id);
      expect(sites, hasLength(BodyRegionX.defaults.length));
      expect(
        sites.map((BodySite s) => s.bodyRegion).toSet(),
        BodyRegionX.defaults.toSet(),
      );
    });

    test('running twice does not double them', () async {
      // It sits on the read path, so it runs on every visit to the body map.
      await h.bodySites.ensureDefaults(profile.id);
      await h.bodySites.ensureDefaults(profile.id);

      expect(
        await h.bodySites.findAll(profile.id),
        hasLength(BodyRegionX.defaults.length),
      );
    });

    test('leaves a profile that already has its own sites alone', () async {
      await h.bodySites.create(
        userProfileId: profile.id,
        bodyRegion: BodyRegion.other,
        customName: 'Left love handle',
      );

      await h.bodySites.ensureDefaults(profile.id);

      final List<BodySite> sites = await h.bodySites.findAll(profile.id);
      expect(sites, hasLength(1));
      expect(sites.single.customName, 'Left love handle');
    });

    test('does not argue with someone who deactivated everything', () async {
      // Turning every site off is the user saying something. An app that put
      // them all back would be overruling them.
      final List<BodySite> seeded = await h.bodySites.ensureDefaults(
        profile.id,
      );
      for (final BodySite site in seeded) {
        await h.bodySites.deactivate(site.id);
      }

      await h.bodySites.ensureDefaults(profile.id);

      expect(await h.bodySites.findActive(profile.id), isEmpty);
      expect(
        await h.bodySites.findAll(profile.id),
        hasLength(BodyRegionX.defaults.length),
      );
    });

    test('sites belong to one profile only', () async {
      final UserProfile other = await h.seedProfile(displayName: 'Other');

      await h.bodySites.ensureDefaults(profile.id);
      await h.bodySites.ensureDefaults(other.id);

      expect(
        await h.bodySites.findAll(profile.id),
        hasLength(BodyRegionX.defaults.length),
      );
      expect(
        await h.bodySites.findAll(other.id),
        hasLength(BodyRegionX.defaults.length),
      );
    });
  });

  group('where things were last put', () {
    Future<BodySite> site(BodyRegion region) =>
        h.bodySites.create(userProfileId: profile.id, bodyRegion: region);

    Future<ConsumableInstance> install(BodySite? at, DateTime when) {
      return h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: when,
        bodySiteId: at?.id,
        status: ConsumableStatus.completed,
      );
    }

    test('reports the most recent install per site', () async {
      final BodySite arm = await site(BodyRegion.leftArm);
      await install(arm, now.subtract(const Duration(days: 30)));
      await install(arm, now.subtract(const Duration(days: 4)));

      final Map<String, DateTime> last = await h.instances
          .lastInstalledByBodySite(profile.id);

      expect(last[arm.id], now.subtract(const Duration(days: 4)));
    });

    test('a site nothing was put on does not appear at all', () async {
      // Absent rather than null, so the body map can tell "never used" from
      // "rested a long time" — they read very differently.
      final BodySite untouched = await site(BodyRegion.rightArm);

      final Map<String, DateTime> last = await h.instances
          .lastInstalledByBodySite(profile.id);

      expect(last.containsKey(untouched.id), isFalse);
    });

    test('an instance with no site is not counted anywhere', () async {
      await install(null, now.subtract(const Duration(days: 1)));

      expect(await h.instances.lastInstalledByBodySite(profile.id), isEmpty);
    });

    test('two consumables can share one region', () async {
      // The reason placement is derived from the instances rather than read
      // from SiteUsages: that table allows a site one occupant at a time,
      // which is true of an exact spot and false of a region. A sensor and a
      // set on the same side of the abdomen is an ordinary week.
      final BodySite belly = await site(BodyRegion.lowerLeftAbdomen);
      final ConsumableType set = await h.seedType(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      );

      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        installedAt: now.subtract(const Duration(days: 2)),
        bodySiteId: belly.id,
      );
      await h.instances.create(
        userProfileId: profile.id,
        consumableTypeId: set.id,
        installedAt: now.subtract(const Duration(days: 1)),
        bodySiteId: belly.id,
      );

      final List<ConsumableInstance> active = await h.instances.findActive(
        profile.id,
      );
      expect(active, hasLength(2));
      expect(
        active.every((ConsumableInstance i) => i.bodySiteId == belly.id),
        isTrue,
      );
    });

    test('a site history comes back most recent first', () async {
      final BodySite arm = await site(BodyRegion.leftArm);
      await install(arm, now.subtract(const Duration(days: 30)));
      await install(arm, now.subtract(const Duration(days: 4)));

      final List<ConsumableInstance> history = await h.instances
          .findForBodySite(arm.id);

      expect(history, hasLength(2));
      expect(history.first.installedAt, now.subtract(const Duration(days: 4)));
    });
  });
}
