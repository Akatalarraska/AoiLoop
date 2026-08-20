import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/features/onboarding/domain/onboarding_draft.dart';
import 'package:blauloop/features/onboarding/domain/onboarding_step.dart';
import 'package:blauloop/shared/models/profile_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Onboarding hides the questions it cannot ask. These tests describe when a
/// step disappears — an empty step is not a step, it is an obstacle — and make
/// sure the two questions that cannot be skipped stay unskippable.
void main() {
  group('visible steps', () {
    test('before a treatment is chosen the flow assumes the full journey', () {
      // So the progress bar only ever shortens. A flow that grows as you
      // answer reads as a flow that is getting longer the more you do.
      expect(
        OnboardingSteps.visibleFor(const OnboardingDraft()),
        OnboardingStep.values,
      );
    });

    test('someone on injections without a CGM is never asked for hardware', () {
      final OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
        TreatmentType.injectionsOnly,
      );

      expect(
        OnboardingSteps.visibleFor(draft),
        isNot(contains(OnboardingStep.devices)),
      );
    });

    test('a CGM alone is enough to ask about devices', () {
      final OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
        TreatmentType.injectionsAndCgm,
      );

      expect(
        OnboardingSteps.visibleFor(draft),
        contains(OnboardingStep.devices),
      );
    });

    test('nothing timed means no durations, change time or reminders', () {
      OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
        TreatmentType.injectionsOnly,
      );
      for (final ConsumablePreset preset in draft.selectedCyclicPresets) {
        draft = draft.toggleConsumable(preset.key);
      }

      final List<OnboardingStep> steps = OnboardingSteps.visibleFor(draft);
      expect(steps, isNot(contains(OnboardingStep.durations)));
      expect(steps, isNot(contains(OnboardingStep.changeTime)));
      expect(steps, isNot(contains(OnboardingStep.reminders)));
      expect(
        steps,
        contains(OnboardingStep.consumables),
        reason: 'the user must still be able to change their mind',
      );
    });

    test('a pump user walks the whole flow', () {
      final OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
        TreatmentType.pumpAndCgm,
      );

      expect(OnboardingSteps.visibleFor(draft), OnboardingStep.values);
    });

    test('steps always come back in declaration order', () {
      for (final TreatmentType treatment in TreatmentType.values) {
        final OnboardingDraft draft = const OnboardingDraft().withTreatmentType(
          treatment,
        );
        final List<OnboardingStep> steps = OnboardingSteps.visibleFor(draft);

        expect(
          steps,
          OnboardingStep.values.where(steps.contains),
          reason: '$treatment',
        );
      }
    });

    test('welcome, profile, treatment and summary are always there', () {
      for (final TreatmentType? treatment in <TreatmentType?>[
        null,
        ...TreatmentType.values,
      ]) {
        final OnboardingDraft draft = treatment == null
            ? const OnboardingDraft()
            : const OnboardingDraft().withTreatmentType(treatment);

        expect(
          OnboardingSteps.visibleFor(draft),
          containsAll(<OnboardingStep>[
            OnboardingStep.welcome,
            OnboardingStep.profile,
            OnboardingStep.treatment,
            OnboardingStep.summary,
          ]),
          reason: '$treatment',
        );
      }
    });
  });

  group('skippable', () {
    test('the two questions the app cannot do without are not skippable', () {
      expect(OnboardingStep.profile.isSkippable, isFalse);
      expect(OnboardingStep.treatment.isSkippable, isFalse);
    });

    test('everything optional can be passed', () {
      for (final OnboardingStep step in <OnboardingStep>[
        OnboardingStep.language,
        OnboardingStep.devices,
        OnboardingStep.consumables,
        OnboardingStep.durations,
        OnboardingStep.changeTime,
        OnboardingStep.reminders,
      ]) {
        expect(step.isSkippable, isTrue, reason: '$step');
      }
    });

    test('the first and last steps have their own buttons, not a skip', () {
      expect(OnboardingStep.welcome.isSkippable, isFalse);
      expect(OnboardingStep.summary.isSkippable, isFalse);
    });
  });
}
