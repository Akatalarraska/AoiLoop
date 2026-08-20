import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/features/onboarding/domain/onboarding_draft.dart';
import 'package:blauloop/shared/models/profile_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The draft is what stands between a half-finished form and a database write.
/// These tests are about the two things it must get right: knowing when it is
/// safe to write, and not throwing away answers the user already gave.
void main() {
  group('submittable', () {
    test('needs a name and a treatment type', () {
      const OnboardingDraft empty = OnboardingDraft();
      expect(empty.isSubmittable, isFalse);

      expect(
        empty.copyWith(displayName: 'Robert').isSubmittable,
        isFalse,
        reason: 'a name alone does not decide what to track',
      );
      expect(
        empty.copyWith(treatmentType: TreatmentType.pumpOnly).isSubmittable,
        isFalse,
        reason: 'the profile row needs a name',
      );
      expect(
        empty
            .copyWith(
              displayName: 'Robert',
              treatmentType: TreatmentType.pumpOnly,
            )
            .isSubmittable,
        isTrue,
      );
    });

    test('whitespace is not a name', () {
      expect(
        const OnboardingDraft(
          displayName: '   ',
          treatmentType: TreatmentType.pumpOnly,
        ).isSubmittable,
        isFalse,
      );
    });
  });

  group('treatment type', () {
    test('adopting one selects the consumables that go with it', () {
      final OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
        TreatmentType.podAndCgm,
      );

      expect(draft.treatmentType, TreatmentType.podAndCgm);
      expect(draft.selectedConsumables, contains(ConsumablePresetKey.pod));
      expect(
        draft.selectedConsumables,
        contains(ConsumablePresetKey.cgmSensor),
      );
    });

    test('changing it replaces a selection that no longer applies', () {
      final OnboardingDraft pump = const OnboardingDraft().withTreatmentType(
        TreatmentType.pumpAndCgm,
      );
      final OnboardingDraft pod = pump.withTreatmentType(
        TreatmentType.podAndCgm,
      );

      expect(
        pod.selectedConsumables,
        isNot(contains(ConsumablePresetKey.infusionSet)),
        reason: 'a pod user has no infusion set to change',
      );
      expect(pod.selectedConsumables, contains(ConsumablePresetKey.pod));
    });

    test('re-picking the same answer keeps the choices made since', () {
      final OnboardingDraft draft = const OnboardingDraft()
          .withTreatmentType(TreatmentType.pumpAndCgm)
          .toggleConsumable(ConsumablePresetKey.reservoir)
          .withDuration(ConsumablePresetKey.cgmSensor, const Duration(days: 7));

      final OnboardingDraft again = draft.withTreatmentType(
        TreatmentType.pumpAndCgm,
      );

      expect(again, same(draft));
      expect(
        again.selectedConsumables,
        isNot(contains(ConsumablePresetKey.reservoir)),
      );
      expect(
        again.durationFor(ConsumablePresetKey.cgmSensor),
        const Duration(days: 7),
      );
    });

    test('changing it forgets durations that were tuned for the old kit', () {
      final OnboardingDraft draft = const OnboardingDraft()
          .withTreatmentType(TreatmentType.pumpAndCgm)
          .withDuration(ConsumablePresetKey.cgmSensor, const Duration(days: 7))
          .withTreatmentType(TreatmentType.podAndCgm);

      expect(
        draft.durationFor(ConsumablePresetKey.cgmSensor),
        const Duration(days: 10),
      );
    });
  });

  group('selection', () {
    test('toggling adds and removes', () {
      const OnboardingDraft draft = OnboardingDraft();

      final OnboardingDraft added = draft.toggleConsumable(
        ConsumablePresetKey.lancet,
      );
      expect(added.selectedConsumables, <ConsumablePresetKey>{
        ConsumablePresetKey.lancet,
      });

      expect(
        added.toggleConsumable(ConsumablePresetKey.lancet).selectedConsumables,
        isEmpty,
      );
    });

    test('selected presets come back in catalogue order, not tap order', () {
      final OnboardingDraft draft = const OnboardingDraft()
          .toggleConsumable(ConsumablePresetKey.lancet)
          .toggleConsumable(ConsumablePresetKey.cgmSensor);

      expect(
        draft.selectedPresets.map((ConsumablePreset p) => p.key),
        <ConsumablePresetKey>[
          ConsumablePresetKey.cgmSensor,
          ConsumablePresetKey.lancet,
        ],
      );
    });

    test('only timed selections count as cyclic', () {
      final OnboardingDraft draft = const OnboardingDraft()
          .toggleConsumable(ConsumablePresetKey.cgmSensor)
          .toggleConsumable(ConsumablePresetKey.testStrip);

      expect(
        draft.selectedCyclicPresets.map((ConsumablePreset p) => p.key),
        <ConsumablePresetKey>[ConsumablePresetKey.cgmSensor],
      );
    });
  });

  group('durations', () {
    test('fall back to the preset default', () {
      expect(
        const OnboardingDraft().durationFor(ConsumablePresetKey.infusionSet),
        const Duration(days: 3),
      );
    });

    test('an override wins', () {
      expect(
        const OnboardingDraft()
            .withDuration(
              ConsumablePresetKey.infusionSet,
              const Duration(days: 2),
            )
            .durationFor(ConsumablePresetKey.infusionSet),
        const Duration(days: 2),
      );
    });

    test('a counted item has no duration to report', () {
      expect(
        const OnboardingDraft().durationFor(ConsumablePresetKey.testStrip),
        isNull,
      );
    });
  });

  group('reminder offsets', () {
    test('default to one day before and on time', () {
      expect(const OnboardingDraft().reminderOffsets, const <Duration>[
        Duration(days: 1),
        Duration.zero,
      ]);
    });

    test('every default is one of the offsets the step offers', () {
      expect(
        OnboardingDraft.defaultReminderOffsets,
        everyElement(isIn(OnboardingDraft.availableReminderOffsets)),
      );
    });
  });

  group('value semantics', () {
    test('two drafts with the same answers are equal', () {
      final OnboardingDraft one = const OnboardingDraft()
          .copyWith(displayName: 'Robert')
          .withTreatmentType(TreatmentType.pumpOnly);
      final OnboardingDraft two = const OnboardingDraft()
          .copyWith(displayName: 'Robert')
          .withTreatmentType(TreatmentType.pumpOnly);

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('a different selection is a different draft', () {
      final OnboardingDraft base = const OnboardingDraft().withTreatmentType(
        TreatmentType.pumpOnly,
      );

      expect(base.toggleConsumable(ConsumablePresetKey.lancet), isNot(base));
    });

    test('clearing an optional answer really clears it', () {
      final OnboardingDraft draft = const OnboardingDraft().copyWith(
        birthYear: 1992,
        preferredChangeMinuteOfDay: 20 * 60,
      );

      expect(draft.copyWith(clearBirthYear: true).birthYear, isNull);
      expect(
        draft
            .copyWith(clearPreferredChangeTime: true)
            .preferredChangeMinuteOfDay,
        isNull,
      );
    });
  });

  group('draft device', () {
    test('needs both a manufacturer and a model to be written', () {
      expect(const DraftDevice().isUsable, isFalse);
      expect(const DraftDevice(manufacturer: 'Dexcom').isUsable, isFalse);
      expect(
        const DraftDevice(manufacturer: 'Dexcom', model: 'G7').isUsable,
        isTrue,
      );
    });

    test('whitespace does not make a device', () {
      expect(
        const DraftDevice(manufacturer: ' ', model: ' ').isUsable,
        isFalse,
      );
      expect(const DraftDevice(manufacturer: '  ', model: '').isEmpty, isTrue);
    });
  });

  group('change times per consumable', () {
    const OnboardingDraft general = OnboardingDraft(
      preferredChangeMinuteOfDay: 20 * 60,
    );

    test('a consumable with no override shows the general time', () {
      expect(
        general.effectiveChangeTimeFor(ConsumablePresetKey.cgmSensor),
        20 * 60,
      );
    });

    test('but stores null, so it goes on following it', () {
      expect(
        general.changeTimeOverrideFor(ConsumablePresetKey.cgmSensor),
        null,
      );
    });

    test('an override wins for both showing and storing', () {
      final OnboardingDraft pinned = general.copyWith(
        changeTimeOverrides: const <ConsumablePresetKey, int>{
          ConsumablePresetKey.cgmSensor: 8 * 60,
        },
      );

      expect(
        pinned.effectiveChangeTimeFor(ConsumablePresetKey.cgmSensor),
        8 * 60,
      );
      expect(
        pinned.changeTimeOverrideFor(ConsumablePresetKey.cgmSensor),
        8 * 60,
      );
      expect(
        pinned.effectiveChangeTimeFor(ConsumablePresetKey.pod),
        20 * 60,
        reason: 'one override must not leak onto the others',
      );
    });

    test('with no general time and no override there is nothing to show', () {
      expect(
        const OnboardingDraft().effectiveChangeTimeFor(
          ConsumablePresetKey.cgmSensor,
        ),
        null,
      );
    });

    test('an override survives copyWith of an unrelated field', () {
      final OnboardingDraft pinned = general.copyWith(
        changeTimeOverrides: const <ConsumablePresetKey, int>{
          ConsumablePresetKey.pod: 8 * 60,
        },
      );

      expect(
        pinned
            .copyWith(displayName: 'Robert')
            .changeTimeOverrideFor(ConsumablePresetKey.pod),
        8 * 60,
      );
    });

    test('drafts differing only by an override are not equal', () {
      expect(
        general.copyWith(
          changeTimeOverrides: const <ConsumablePresetKey, int>{
            ConsumablePresetKey.pod: 8 * 60,
          },
        ),
        isNot(general),
      );
    });
  });
}
