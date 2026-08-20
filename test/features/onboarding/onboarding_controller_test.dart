import 'package:blauloop/app/locale/locale_providers.dart';
import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/database/database_providers.dart';
import 'package:blauloop/core/database/id_generator.dart';
import 'package:blauloop/core/errors/app_failure.dart';
import 'package:blauloop/core/utils/clock.dart';
import 'package:blauloop/core/utils/timezone_source.dart';
import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/features/onboarding/domain/onboarding_step.dart';
import 'package:blauloop/features/onboarding/presentation/onboarding_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';
import '../../support/test_database.dart';

/// The controller is the flow: which step is current, what may be skipped, and
/// when a draft becomes rows. Tested without widgets so the rules are pinned
/// independently of how any screen happens to render them.
void main() {
  late TestHarness harness;
  late ProviderContainer container;

  setUp(() {
    harness = TestHarness.create();
    container = ProviderContainer.test(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(harness.db),
        clockProvider.overrideWithValue(harness.clock),
        idGeneratorProvider.overrideWithValue(harness.ids),
        timezoneSourceProvider.overrideWithValue(
          const FixedTimezoneSource('Europe/Madrid'),
        ),
      ],
    );
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);
  OnboardingFlow flow() => container.read(onboardingControllerProvider);

  String presetName(ConsumablePresetKey key) => key.name;

  /// Answers the two questions onboarding cannot do without.
  void fillRequired({TreatmentType treatment = TreatmentType.pumpAndCgm}) {
    controller()
      ..setDisplayName('Robert')
      ..setTreatmentType(treatment);
  }

  group('navigation', () {
    test('starts on the welcome step', () {
      expect(flow().step, OnboardingStep.welcome);
      expect(flow().isFirst, isTrue);
      expect(flow().isLast, isFalse);
    });

    test('walks forward and back through the visible steps', () {
      fillRequired(treatment: TreatmentType.injectionsOnly);

      final List<OnboardingStep> steps = flow().steps;
      expect(steps, isNot(contains(OnboardingStep.devices)));

      for (int i = 1; i < steps.length; i++) {
        controller().next();
        expect(flow().step, steps[i]);
      }

      expect(flow().isLast, isTrue);
      controller().next();
      expect(flow().step, steps.last, reason: 'the flow has no step ten');

      controller().back();
      expect(flow().step, steps[steps.length - 2]);
    });

    test('cannot go back past the beginning', () {
      controller().back();
      expect(flow().step, OnboardingStep.welcome);
    });

    test('the summary can jump to any step it shows', () {
      fillRequired();
      controller().goTo(OnboardingStep.consumables);

      expect(flow().step, OnboardingStep.consumables);
    });

    test('jumping to a step this user does not have is refused', () {
      fillRequired(treatment: TreatmentType.injectionsOnly);
      controller().goTo(OnboardingStep.devices);

      expect(flow().step, OnboardingStep.welcome);
    });

    test('progress grows and ends at one', () {
      fillRequired();
      expect(flow().progress, greaterThan(0));

      while (!flow().isLast) {
        controller().next();
      }
      expect(flow().progress, 1);
    });
  });

  group('advancing', () {
    test('the profile step waits for a name', () {
      controller().goTo(OnboardingStep.profile);
      expect(flow().canAdvance, isFalse);

      controller().setDisplayName('Robert');
      expect(flow().canAdvance, isTrue);
    });

    test('the treatment step waits for an answer', () {
      controller().setDisplayName('Robert');
      controller().goTo(OnboardingStep.treatment);
      expect(flow().canAdvance, isFalse);

      controller().setTreatmentType(TreatmentType.pumpOnly);
      expect(flow().canAdvance, isTrue);
    });

    test('every other step can be passed as it is', () {
      fillRequired();
      for (final OnboardingStep step in flow().steps) {
        if (step == OnboardingStep.profile ||
            step == OnboardingStep.treatment) {
          continue;
        }
        controller().goTo(step);
        expect(flow().canAdvance, isTrue, reason: '$step blocked the user');
      }
    });
  });

  group('answers', () {
    test('choosing a language applies it to the running app', () {
      controller().setLanguage('es');

      expect(container.read(localeOverrideProvider), const Locale('es'));
      expect(container.read(appLocaleProvider), const Locale('es'));
      expect(flow().draft.languageCode, 'es');
    });

    test('a treatment answer pre-ticks the consumables that go with it', () {
      controller().setTreatmentType(TreatmentType.podAndCgm);

      expect(
        flow().draft.selectedConsumables,
        contains(ConsumablePresetKey.pod),
      );
    });

    test('reminder offsets toggle off and on', () {
      controller().toggleReminderOffset(Duration.zero);
      expect(flow().draft.reminderOffsets, isNot(contains(Duration.zero)));

      controller().toggleReminderOffset(Duration.zero);
      expect(flow().draft.reminderOffsets, contains(Duration.zero));
    });

    test('a partial year of birth is held rather than stored wrong', () {
      controller().setBirthYear(null);
      expect(flow().draft.birthYear, isNull);

      controller().setBirthYear(1992);
      expect(flow().draft.birthYear, 1992);

      controller().setBirthYear(null);
      expect(flow().draft.birthYear, isNull);
    });

    test('the preferred change time can be set and cleared', () {
      controller().setPreferredChangeMinuteOfDay(21 * 60);
      expect(flow().draft.preferredChangeMinuteOfDay, 1260);

      controller().setPreferredChangeMinuteOfDay(null);
      expect(flow().draft.preferredChangeMinuteOfDay, isNull);
    });
  });

  group('submitting', () {
    test('writes the profile and reports it', () async {
      fillRequired();

      final UserProfile? profile = await controller().submit(
        presetName: presetName,
        systemLanguageCode: 'en',
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Robert');
      expect(profile.timezone, 'Europe/Madrid');
      expect((await harness.profiles.findPrimary())?.id, profile.id);
      expect(flow().isSubmitting, isFalse);
      expect(flow().failure, isNull);
    });

    test(
      'an unfinished draft is refused without touching the database',
      () async {
        final UserProfile? profile = await controller().submit(
          presetName: presetName,
          systemLanguageCode: 'en',
        );

        expect(profile, isNull);
        expect(await harness.profiles.findPrimary(), isNull);
      },
    );

    test('a failed write is reported, and leaves the draft to retry', () async {
      fillRequired();

      final UserProfile? profile = await controller().submit(
        // Longer than the name column allows.
        presetName: (ConsumablePresetKey key) => 'x' * 200,
        systemLanguageCode: 'en',
      );

      expect(profile, isNull);
      expect(flow().failure, isA<StorageFailure>());
      expect(flow().isSubmitting, isFalse);
      expect(flow().draft.displayName, 'Robert');
      expect(await harness.profiles.findPrimary(), isNull);
    });

    test('touching an answer clears the previous failure', () async {
      fillRequired();
      await controller().submit(
        presetName: (ConsumablePresetKey key) => 'x' * 200,
        systemLanguageCode: 'en',
      );
      expect(flow().failure, isNotNull);

      controller().setDisplayName('Robert M');
      expect(flow().failure, isNull);
    });

    test('falls back to the system language when none was chosen', () async {
      fillRequired();

      final UserProfile? profile = await controller().submit(
        presetName: presetName,
        systemLanguageCode: 'es',
      );

      expect(profile!.languageCode, 'es');
    });
  });
}
