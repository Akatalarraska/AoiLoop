import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
  });

  group('creation', () {
    test('stores the fields onboarding collects', () async {
      final UserProfile profile = await h.profiles.create(
        displayName: 'Lucas',
        timezone: 'Europe/Madrid',
        languageCode: 'es',
        glucoseUnit: GlucoseUnit.mgPerDl,
        treatmentType: TreatmentType.pumpAndCgm,
        birthYear: 2014,
        preferredChangeMinuteOfDay: 19 * 60,
      );

      expect(profile.displayName, 'Lucas');
      expect(profile.timezone, 'Europe/Madrid');
      expect(profile.languageCode, 'es');
      expect(profile.glucoseUnit, GlucoseUnit.mgPerDl);
      expect(profile.treatmentType, TreatmentType.pumpAndCgm);
      expect(profile.birthYear, 2014);
      expect(profile.preferredChangeMinuteOfDay, 19 * 60);
    });

    test('leaves optional fields null when they are not supplied', () async {
      // Onboarding must be skippable. A profile with only the essentials is a
      // valid profile.
      final UserProfile profile = await h.seedProfile();

      expect(profile.birthYear, isNull);
      expect(profile.preferredChangeMinuteOfDay, isNull);
    });

    test('stamps createdAt and updatedAt from the clock, in UTC', () async {
      final UserProfile profile = await h.seedProfile();

      expect(profile.createdAt, DateTime.utc(2026, 8, 17, 9));
      expect(profile.updatedAt, DateTime.utc(2026, 8, 17, 9));
      expect(profile.createdAt.isUtc, isTrue);
    });

    test(
      'stores the enum by name, so reordering it cannot rewrite data',
      () async {
        await h.seedProfile();

        final List<QueryRow> rows = await h.db
            .customSelect(
              'SELECT glucose_unit, treatment_type FROM user_profiles',
            )
            .get();

        expect(rows.single.read<String>('glucose_unit'), 'mgPerDl');
        expect(rows.single.read<String>('treatment_type'), 'pumpAndCgm');
      },
    );
  });

  group('reading', () {
    test('watchPrimary emits null before onboarding has run', () async {
      // This is how the router decides to send a first-time user to
      // onboarding.
      expect(await h.profiles.watchPrimary().first, isNull);
    });

    test('watchPrimary emits the profile once it exists', () async {
      final UserProfile created = await h.seedProfile(displayName: 'Ana');

      final UserProfile? seen = await h.profiles.watchPrimary().first;

      expect(seen?.id, created.id);
      expect(seen?.displayName, 'Ana');
    });

    test(
      'watchPrimary returns the oldest profile, not an arbitrary one',
      () async {
        final UserProfile first = await h.seedProfile(displayName: 'Me');
        h.clock.advance(const Duration(days: 1));
        await h.seedProfile(displayName: 'Lucas');

        final UserProfile? primary = await h.profiles.watchPrimary().first;

        expect(primary?.id, first.id);
      },
    );

    test('watchAll lists every profile oldest first', () async {
      await h.seedProfile(displayName: 'Me');
      h.clock.advance(const Duration(days: 1));
      await h.seedProfile(displayName: 'Lucas');

      final List<UserProfile> all = await h.profiles.watchAll().first;

      expect(all.map((UserProfile p) => p.displayName), <String>[
        'Me',
        'Lucas',
      ]);
    });

    test('findById returns null for an unknown id', () async {
      expect(await h.profiles.findById('nope'), isNull);
    });
  });

  group('updating', () {
    test('refreshes updatedAt but leaves createdAt alone', () async {
      final UserProfile profile = await h.seedProfile();
      h.clock.advance(const Duration(hours: 5));

      await h.profiles.update(
        profile.id,
        const UserProfilesCompanion(displayName: Value<String>('Renamed')),
      );

      final UserProfile? reloaded = await h.profiles.findById(profile.id);
      expect(reloaded!.displayName, 'Renamed');
      expect(reloaded.createdAt, DateTime.utc(2026, 8, 17, 9));
      expect(reloaded.updatedAt, DateTime.utc(2026, 8, 17, 14));
    });

    test('a partial update leaves untouched fields alone', () async {
      final UserProfile profile = await h.seedProfile(
        preferredChangeMinuteOfDay: 19 * 60,
      );

      await h.profiles.update(
        profile.id,
        const UserProfilesCompanion(languageCode: Value<String>('en')),
      );

      final UserProfile? reloaded = await h.profiles.findById(profile.id);
      expect(reloaded!.languageCode, 'en');
      expect(reloaded.preferredChangeMinuteOfDay, 19 * 60);
    });

    test('sets the preferred change time', () async {
      final UserProfile profile = await h.seedProfile();

      await h.profiles.setPreferredChangeMinuteOfDay(profile.id, 11 * 60 + 30);

      final UserProfile? reloaded = await h.profiles.findById(profile.id);
      expect(reloaded!.preferredChangeMinuteOfDay, 690);
    });

    test('clears the preferred change time with null', () async {
      final UserProfile profile = await h.seedProfile(
        preferredChangeMinuteOfDay: 690,
      );

      await h.profiles.setPreferredChangeMinuteOfDay(profile.id, null);

      final UserProfile? reloaded = await h.profiles.findById(profile.id);
      expect(reloaded!.preferredChangeMinuteOfDay, isNull);
    });

    test('accepts both ends of the day', () async {
      final UserProfile profile = await h.seedProfile();

      await h.profiles.setPreferredChangeMinuteOfDay(profile.id, 0);
      expect(
        (await h.profiles.findById(profile.id))!.preferredChangeMinuteOfDay,
        0,
      );

      await h.profiles.setPreferredChangeMinuteOfDay(profile.id, 1439);
      expect(
        (await h.profiles.findById(profile.id))!.preferredChangeMinuteOfDay,
        1439,
      );
    });

    test('rejects a minute outside a single day', () async {
      final UserProfile profile = await h.seedProfile();

      expect(
        () => h.profiles.setPreferredChangeMinuteOfDay(profile.id, 1440),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => h.profiles.setPreferredChangeMinuteOfDay(profile.id, -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
