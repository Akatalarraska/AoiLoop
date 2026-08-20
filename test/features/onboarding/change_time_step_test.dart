import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/features/onboarding/presentation/onboarding_controller.dart';
import 'package:blauloop/features/onboarding/presentation/steps/change_time_step.dart';
import 'package:blauloop/l10n/generated/app_localizations.dart';
import 'package:blauloop/shared/models/profile_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The per-consumable half of the change time step.
///
/// The design it implements is easy to state and easy to get wrong: the
/// general time appears against every consumable straight away, so a user sees
/// it already filled in — but nothing is *stored* against a consumable until
/// they change it. These tests pin both halves, because a screen that showed
/// the right thing while storing the wrong one would look correct right up
/// until someone edited their general time months later.
void main() {
  /// Pumps the step alone with a container the test can drive.
  Future<ProviderContainer> pumpStep(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer.test();

    // A treatment type is what selects the consumable presets, and without
    // one the draft tracks nothing at all — there would be no rows to test.
    container
        .read(onboardingControllerProvider.notifier)
        .setTreatmentType(TreatmentType.pumpAndCgm);

    // Tall, so every consumable row is laid out rather than clipped off the
    // bottom where a finder cannot reach it.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChangeTimeStep()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  OnboardingController controllerOf(ProviderContainer c) =>
      c.read(onboardingControllerProvider.notifier);

  testWidgets('the general time shows against every consumable', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpStep(tester);
    controllerOf(container).setPreferredChangeMinuteOfDay(20 * 60);
    await tester.pumpAndSettle();

    final int rows = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .length;
    expect(rows, greaterThan(1), reason: 'the default draft tracks several');

    // One for the general card, one per consumable line. The whole point of
    // the design: a user sees their answer already applied everywhere.
    expect(find.text('8:00 PM'), findsNWidgets(rows + 1));
    expect(find.text('Follows the general time'), findsNWidgets(rows));
  });

  testWidgets('overriding one consumable leaves the rest inheriting', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpStep(tester);
    final OnboardingController controller = controllerOf(container);
    controller.setPreferredChangeMinuteOfDay(20 * 60);

    final ConsumablePresetKey pinned = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .first
        .key;
    controller.setChangeTimeOverride(pinned, 8 * 60);
    await tester.pumpAndSettle();

    final int rows = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .length;

    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Its own time'), findsOneWidget);
    expect(find.text('Follows the general time'), findsNWidgets(rows - 1));
  });

  testWidgets('moving the general time moves everything not pinned', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpStep(tester);
    final OnboardingController controller = controllerOf(container);
    controller.setPreferredChangeMinuteOfDay(20 * 60);

    final ConsumablePresetKey pinned = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .first
        .key;
    controller.setChangeTimeOverride(pinned, 8 * 60);

    // The behaviour the nullable column exists for. Nothing was copied, so
    // moving the general answer moves every consumable that never disagreed.
    controller.setPreferredChangeMinuteOfDay(7 * 60);
    await tester.pumpAndSettle();

    final int rows = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .length;

    expect(find.text('7:00 AM'), findsNWidgets(rows));
    expect(
      find.text('8:00 AM'),
      findsOneWidget,
      reason: 'the pinned one keeps its own time',
    );
    expect(find.text('8:00 PM'), findsNothing);
  });

  testWidgets('handing a consumable back restores the general time', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpStep(tester);
    final OnboardingController controller = controllerOf(container);
    controller.setPreferredChangeMinuteOfDay(20 * 60);

    final ConsumablePresetKey pinned = container
        .read(onboardingControllerProvider)
        .draft
        .selectedCyclicPresets
        .first
        .key;
    controller.setChangeTimeOverride(pinned, 8 * 60);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_backup_restore));
    await tester.pumpAndSettle();

    expect(find.text('Its own time'), findsNothing);
    expect(
      container.read(onboardingControllerProvider).draft.changeTimeOverrides,
      isEmpty,
    );
  });

  testWidgets(
    'with no general time the rows say so rather than inventing one',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpStep(tester);

      final int rows = container
          .read(onboardingControllerProvider)
          .draft
          .selectedCyclicPresets
          .length;
      expect(rows, greaterThan(0));

      // A guessed hour here would be a wrong date later, which is the one
      // failure this app cannot afford.
      expect(find.text('No preferred time'), findsNWidgets(rows + 1));
    },
  );
}
