import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/body_map/domain/body_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// The body map's joining, grouping and rest arithmetic, at a fixed instant.
///
/// No frame is pumped. Everything here is a value in and a value out, which is
/// the point of the view living in `domain/` rather than in the widget.
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

  Future<BodySite> site(BodyRegion region) =>
      h.bodySites.create(userProfileId: profile.id, bodyRegion: region);

  BodyMapView build({
    required List<BodySite> sites,
    Map<String, DateTime?> lastUsed = const <String, DateTime?>{},
    Map<String, ConsumableType> occupants = const <String, ConsumableType>{},
  }) {
    return BodyMapView.from(
      sites: sites,
      lastUsedBySite: lastUsed,
      occupantBySite: occupants,
      now: now,
    );
  }

  group('grouping', () {
    test('gathers regions into the area they belong to', () async {
      final BodySite leftArm = await site(BodyRegion.leftArm);
      final BodySite rightArm = await site(BodyRegion.rightArm);
      final BodySite belly = await site(BodyRegion.lowerLeftAbdomen);

      final BodyMapView view = build(
        sites: <BodySite>[belly, rightArm, leftArm],
      );

      expect(view.groups.map((BodyAreaGroup g) => g.area), <BodyArea>[
        BodyArea.arms,
        BodyArea.abdomen,
      ]);
      expect(view.groups.first.cards, hasLength(2));
    });

    test('leaves out an area the profile has no sites in', () async {
      final BodyMapView view = build(
        sites: <BodySite>[await site(BodyRegion.leftThigh)],
      );

      expect(view.groups.single.area, BodyArea.thighs);
    });

    test('keeps left before right, whatever order it was handed', () async {
      final BodySite left = await site(BodyRegion.leftArm);
      final BodySite right = await site(BodyRegion.rightArm);

      // Declaration order, not rest order. A list that reshuffles itself
      // between visits is a list people mistap.
      final BodyMapView view = build(sites: <BodySite>[right, left]);

      expect(
        view.groups.single.cards.map((BodySiteCard c) => c.region),
        <BodyRegion>[BodyRegion.leftArm, BodyRegion.rightArm],
      );
    });

    test('is empty when the profile has no sites', () {
      expect(build(sites: const <BodySite>[]).isEmpty, isTrue);
    });
  });

  group('what a site is doing', () {
    test('reports what is on it', () async {
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        occupants: <String, ConsumableType>{arm.id: sensor},
      );

      final BodySiteCard card = view.cards.single;
      expect(card.isOccupied, isTrue);
      expect(card.occupant?.name, 'CGM sensor');
      expect(view.occupiedCount, 1);
    });

    test('an occupied site is not resting', () async {
      // It is in use. Reporting a duration for it would be answering a
      // question nobody asked.
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        lastUsed: <String, DateTime?>{
          arm.id: now.subtract(const Duration(days: 3)),
        },
        occupants: <String, ConsumableType>{arm.id: sensor},
      );

      expect(view.cards.single.restingFor, isNull);
      expect(view.cards.single.restingDays, isNull);
    });

    test('a never used site is not resting either', () async {
      // "Free for 400 days" and "never used" are different facts, and only the
      // second is true of a site nothing has ever touched.
      final BodyMapView view = build(
        sites: <BodySite>[await site(BodyRegion.leftArm)],
      );

      final BodySiteCard card = view.cards.single;
      expect(card.isUnused, isTrue);
      expect(card.restingFor, isNull);
    });

    test('counts rest from when the last thing went on', () async {
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        lastUsed: <String, DateTime?>{
          arm.id: now.subtract(const Duration(days: 12, hours: 5)),
        },
      );

      expect(view.cards.single.restingFor, const Duration(days: 12, hours: 5));
    });

    test('rounds the days down', () async {
      // Down for the same reason every countdown does: a number rounded in the
      // user's favour tells them a site has rested longer than it has.
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        lastUsed: <String, DateTime?>{
          arm.id: now.subtract(const Duration(days: 6, hours: 23)),
        },
      );

      expect(view.cards.single.restingDays, 6);
    });

    test('never reports a negative rest', () async {
      // Impossible from stored data, nonsense on screen.
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        lastUsed: <String, DateTime?>{arm.id: now.add(const Duration(days: 1))},
      );

      expect(view.cards.single.restingFor, Duration.zero);
    });
  });

  group('longest without use', () {
    test('picks the site that has been free longest', () async {
      final BodySite recent = await site(BodyRegion.leftArm);
      final BodySite older = await site(BodyRegion.rightArm);

      final BodyMapView view = build(
        sites: <BodySite>[recent, older],
        lastUsed: <String, DateTime?>{
          recent.id: now.subtract(const Duration(days: 2)),
          older.id: now.subtract(const Duration(days: 30)),
        },
      );

      expect(view.longestRested?.id, older.id);
    });

    test('a never used site beats any rested one', () async {
      final BodySite rested = await site(BodyRegion.leftArm);
      final BodySite untouched = await site(BodyRegion.rightArm);

      final BodyMapView view = build(
        sites: <BodySite>[rested, untouched],
        lastUsed: <String, DateTime?>{
          rested.id: now.subtract(const Duration(days: 400)),
        },
      );

      expect(view.longestRested?.id, untouched.id);
    });

    test('never picks a site that is in use', () async {
      final BodySite occupied = await site(BodyRegion.leftArm);
      final BodySite free = await site(BodyRegion.rightArm);

      final BodyMapView view = build(
        sites: <BodySite>[occupied, free],
        lastUsed: <String, DateTime?>{
          free.id: now.subtract(const Duration(days: 1)),
        },
        occupants: <String, ConsumableType>{occupied.id: sensor},
      );

      expect(view.longestRested?.id, free.id);
    });

    test('is nothing at all when every site is in use', () async {
      final BodySite arm = await site(BodyRegion.leftArm);

      final BodyMapView view = build(
        sites: <BodySite>[arm],
        occupants: <String, ConsumableType>{arm.id: sensor},
      );

      expect(view.longestRested, isNull);
    });

    test('does not move between builds when two sites tie', () async {
      final BodySite a = await site(BodyRegion.leftArm);
      final BodySite b = await site(BodyRegion.rightArm);
      final DateTime same = now.subtract(const Duration(days: 5));

      BodyMapView viewOf(List<BodySite> sites) => build(
        sites: sites,
        lastUsed: <String, DateTime?>{a.id: same, b.id: same},
      );

      expect(
        viewOf(<BodySite>[a, b]).longestRested?.id,
        viewOf(<BodySite>[b, a]).longestRested?.id,
      );
    });
  });

  group('as a value', () {
    test('finds a card by its site id, and nothing by a stranger', () async {
      final BodySite arm = await site(BodyRegion.leftArm);
      final BodyMapView view = build(sites: <BodySite>[arm]);

      expect(view.cardFor(arm.id)?.id, arm.id);
      expect(view.cardFor('not-a-site'), isNull);
      expect(view.cardFor(null), isNull);
    });

    test('two views of the same facts are equal', () async {
      final List<BodySite> sites = <BodySite>[await site(BodyRegion.leftArm)];

      expect(build(sites: sites), build(sites: sites));
      expect(build(sites: sites).hashCode, build(sites: sites).hashCode);
    });
  });
}
