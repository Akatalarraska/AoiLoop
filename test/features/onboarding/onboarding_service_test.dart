import 'package:aoiloop/core/database/app_database.dart';
import 'package:aoiloop/features/onboarding/data/onboarding_service.dart';
import 'package:aoiloop/features/onboarding/domain/consumable_preset.dart';
import 'package:aoiloop/features/onboarding/domain/onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Everything onboarding collects becomes rows exactly once, here. These tests
/// are about that translation being faithful — and about it being atomic,
/// because a partial write would look like a finished onboarding on the next
/// launch and skip the rest of the questions forever.
void main() {
  late TestHarness harness;
  late OnboardingService service;

  setUp(() {
    harness = TestHarness.create();
    service = OnboardingService(
      db: harness.db,
      profiles: harness.profiles,
      devices: harness.devices,
      types: harness.types,
    );
  });

  Future<UserProfile> complete(
    OnboardingDraft draft, {
    String Function(ConsumablePresetKey key)? presetName,
    String timezone = 'Europe/Madrid',
    String languageCode = 'en',
  }) {
    return service.complete(
      draft: draft,
      presetName: presetName ?? (ConsumablePresetKey key) => 'name-${key.name}',
      timezone: timezone,
      languageCode: languageCode,
    );
  }

  OnboardingDraft draftFor(TreatmentType treatment) {
    return const OnboardingDraft()
        .copyWith(displayName: 'Robert')
        .withTreatmentType(treatment);
  }

  group('profile', () {
    test('carries the answers the user gave', () async {
      final UserProfile profile = await complete(
        draftFor(TreatmentType.pumpAndCgm).copyWith(
          birthYear: 1992,
          glucoseUnit: GlucoseUnit.mmolPerL,
          languageCode: 'es',
          preferredChangeMinuteOfDay: 20 * 60 + 30,
        ),
      );

      expect(profile.displayName, 'Robert');
      expect(profile.birthYear, 1992);
      expect(profile.glucoseUnit, GlucoseUnit.mmolPerL);
      expect(profile.treatmentType, TreatmentType.pumpAndCgm);
      expect(profile.languageCode, 'es');
      expect(profile.timezone, 'Europe/Madrid');
      expect(profile.preferredChangeMinuteOfDay, 1230);
      expect(profile.createdAt, harness.clock.nowUtc());
    });

    test('trims the name', () async {
      final UserProfile profile = await complete(
        draftFor(TreatmentType.pumpOnly).copyWith(displayName: '  Robert  '),
      );

      expect(profile.displayName, 'Robert');
    });

    test(
      'falls back to the system language when the step was skipped',
      () async {
        final UserProfile profile = await complete(
          draftFor(TreatmentType.pumpOnly),
          languageCode: 'es',
        );

        expect(profile.languageCode, 'es');
      },
    );

    test(
      'becomes the primary profile the app will find on the next launch',
      () async {
        final UserProfile written = await complete(
          draftFor(TreatmentType.pumpOnly),
        );

        expect((await harness.profiles.findPrimary())?.id, written.id);
      },
    );

    test('refuses a draft that is not finished', () {
      expect(
        () => complete(const OnboardingDraft(displayName: 'Robert')),
        throwsStateError,
      );
    });
  });

  group('devices', () {
    test('writes the pump and the CGM that were filled in', () async {
      final UserProfile profile = await complete(
        draftFor(TreatmentType.pumpAndCgm).copyWith(
          pump: const DraftDevice(
            manufacturer: 'Tandem',
            model: 't:slim X2',
            serialNumber: ' 12345 ',
          ),
          cgm: const DraftDevice(manufacturer: 'Dexcom', model: 'G7'),
        ),
      );

      final List<Device> devices = await harness.devices
          .watchAll(profile.id)
          .first;

      expect(devices, hasLength(2));
      expect(
        devices.map((Device device) => device.type),
        containsAll(<DeviceType>[DeviceType.pump, DeviceType.cgm]),
      );
      expect(
        devices
            .firstWhere((Device d) => d.type == DeviceType.pump)
            .serialNumber,
        '12345',
      );
    });

    test('a pod user gets a controller, not a pump', () async {
      final UserProfile profile = await complete(
        draftFor(TreatmentType.podOnly).copyWith(
          pump: const DraftDevice(manufacturer: 'Insulet', model: 'Omnipod 5'),
        ),
      );

      final List<Device> devices = await harness.devices
          .watchAll(profile.id)
          .first;

      expect(devices.single.type, DeviceType.podController);
    });

    test(
      'a half-filled device is skipped rather than saved incomplete',
      () async {
        final UserProfile profile = await complete(
          draftFor(TreatmentType.pumpAndCgm).copyWith(
            pump: const DraftDevice(manufacturer: 'Tandem'),
            cgm: const DraftDevice(manufacturer: 'Dexcom', model: 'G7'),
          ),
        );

        final List<Device> devices = await harness.devices
            .watchAll(profile.id)
            .first;

        expect(devices.single.type, DeviceType.cgm);
      },
    );

    test('skipping the step entirely writes no devices', () async {
      final UserProfile profile = await complete(
        draftFor(TreatmentType.pumpAndCgm),
      );

      expect(await harness.devices.watchAll(profile.id).first, isEmpty);
    });
  });

  group('consumable types', () {
    test('one per selection, named in the user\'s language', () async {
      await complete(
        draftFor(TreatmentType.podAndCgm),
        presetName: (ConsumablePresetKey key) => switch (key) {
          ConsumablePresetKey.pod => 'Pod',
          ConsumablePresetKey.cgmSensor => 'Sensor MCG',
          _ => key.name,
        },
      );

      final List<ConsumableType> types = await harness.types
          .watchActive()
          .first;

      expect(types, hasLength(4));
      expect(
        types.map((ConsumableType type) => type.name),
        containsAll(<String>['Pod', 'Sensor MCG']),
      );
      expect(
        types.every((ConsumableType type) => type.isBuiltIn),
        isTrue,
        reason: 'presets are shipped types, not user-invented ones',
      );
    });

    test('timed items keep their duration and reminders', () async {
      await complete(
        draftFor(TreatmentType.pumpAndCgm)
            .withDuration(
              ConsumablePresetKey.cgmSensor,
              const Duration(days: 7),
            )
            .copyWith(
              reminderOffsets: const <Duration>[
                Duration(days: 1),
                Duration(hours: 1),
              ],
            ),
      );

      final ConsumableType sensor = await _typeNamed(harness, 'name-cgmSensor');

      expect(sensor.defaultDurationMinutes, const Duration(days: 7).inMinutes);
      expect(sensor.tracksCycle, isTrue);
      expect(sensor.defaultReminderOffsets, const <Duration>[
        Duration(days: 1),
        Duration(hours: 1),
      ]);
    });

    test('untouched durations keep the preset default', () async {
      await complete(draftFor(TreatmentType.pumpAndCgm));

      final ConsumableType set = await _typeNamed(harness, 'name-infusionSet');

      expect(set.defaultDurationMinutes, const Duration(days: 3).inMinutes);
    });

    test('counted items get no duration and no reminders', () async {
      await complete(draftFor(TreatmentType.pumpAndCgm));

      final ConsumableType strips = await _typeNamed(harness, 'name-testStrip');

      expect(strips.defaultDurationMinutes, isNull);
      expect(strips.tracksCycle, isFalse);
      expect(
        strips.defaultReminderOffsets,
        isEmpty,
        reason: 'a reminder for something with no deadline would never fire',
      );
      expect(strips.tracksInventory, isTrue);
    });

    test('selecting nothing writes nothing', () async {
      OnboardingDraft draft = draftFor(TreatmentType.pumpAndCgm);
      for (final ConsumablePreset preset in draft.selectedPresets) {
        draft = draft.toggleConsumable(preset.key);
      }

      await complete(draft);

      expect(await harness.types.countAll(), 0);
    });
  });

  test('a failure part way through leaves nothing behind', () async {
    await expectLater(
      complete(
        draftFor(TreatmentType.pumpAndCgm),
        // Longer than the column allows, so the insert is rejected once the
        // profile and the earlier types are already in the transaction.
        presetName: (ConsumablePresetKey key) =>
            key == ConsumablePresetKey.testStrip ? 'x' * 200 : key.name,
      ),
      throwsA(anything),
    );

    expect(
      await harness.profiles.findPrimary(),
      isNull,
      reason: 'a profile without its types would look like a finished setup',
    );
    expect(await harness.types.countAll(), 0);
  });
}

Future<ConsumableType> _typeNamed(TestHarness harness, String name) async {
  final List<ConsumableType> types = await harness.types.watchActive().first;
  return types.firstWhere((ConsumableType type) => type.name == name);
}
