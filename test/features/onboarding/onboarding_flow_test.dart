import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The flow as a user meets it: a first launch with an empty database, one
/// question at a time, ending on a dashboard that belongs to them.
///
/// These tests drive the real app — router, redirect, database — because the
/// interesting failures in a first-run flow are the seams between those, not
/// any single widget.
void main() {
  setUp(() {
    // Tall enough that a step's options are all on screen; the flow itself is
    // scrollable, and scrolling in every test would say nothing about it.
    _useTallScreen();
  });

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a first launch opens onboarding, not the dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    expect(find.text('Welcome to DT1FLOW'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('says what it is for, and what it is not', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    expect(
      find.text('DT1FLOW does not calculate doses or give treatment advice.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Everything stays on this device. No account, no cloud, nothing sent '
        'anywhere.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('walks a pump user from welcome to their own dashboard', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpApp(tester, onboarded: false);

    // Welcome.
    expect(find.text('Step 1 of 10'), findsOneWidget);
    await tapText(tester, 'Get started');

    // Language: leave it as it is.
    expect(find.text('Choose your language'), findsOneWidget);
    await tapText(tester, 'Continue');

    // Profile.
    await tester.enterText(find.byType(TextFormField).first, 'Robert');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');

    // Treatment.
    await tapText(tester, 'Pump and CGM');
    await tapText(tester, 'Continue');

    // Devices.
    expect(find.text('Pump'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Manufacturer').first,
      'Tandem',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Model').first,
      't:slim X2',
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');

    // Consumables: pre-ticked from the treatment answer.
    expect(find.text('Infusion set'), findsOneWidget);
    expect(find.text('Pod'), findsNothing);
    await tapText(tester, 'Continue');

    // Durations.
    expect(find.text('10 days'), findsOneWidget);
    await tapText(tester, 'Continue');

    // Preferred change time, then reminders.
    await tapText(tester, 'Skip');
    await tapText(tester, 'Continue');

    // Summary.
    expect(find.text('Ready to go'), findsOneWidget);
    expect(find.text('Robert'), findsOneWidget);
    expect(find.text('Pump and CGM'), findsOneWidget);
    expect(find.text('Tandem t:slim X2'), findsOneWidget);

    await tapText(tester, 'Create my profile');

    // The router notices the profile and moves the user on. Home greets them
    // by the name they just typed, and says plainly that nothing is counting
    // down yet — they have set up what they use, but registered no change.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Hello, Robert'), findsOneWidget);
    expect(find.text('Nothing is counting down yet'), findsOneWidget);

    final UserProfile? profile = await app.harness.profiles.findPrimary();
    expect(profile, isNotNull);
    expect(profile!.displayName, 'Robert');
    expect(profile.treatmentType, TreatmentType.pumpAndCgm);
    expect(profile.timezone, 'Europe/Madrid');

    final List<ConsumableType> types = await app.harness.allConsumableTypes();
    expect(
      types.map((ConsumableType type) => type.name),
      containsAll(<String>[
        'CGM sensor',
        'Infusion set',
        'Reservoir',
        'Test strips',
        'Lancets',
      ]),
    );

    final List<Device> devices = await app.harness.allDevices();
    expect(devices.single.manufacturer, 'Tandem');
  });

  testWidgets('a pod user is never asked about infusion sets', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Continue');
    await tester.enterText(find.byType(TextFormField).first, 'Robert');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Patch pump and CGM');
    await tapText(tester, 'Continue');

    expect(find.text('Pod controller'), findsOneWidget);
    await tapText(tester, 'Skip');

    expect(find.text('Pod'), findsOneWidget);
    expect(find.text('Infusion set'), findsNothing);
    expect(find.text('Reservoir'), findsNothing);
  });

  testWidgets('someone on injections skips the hardware step entirely', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Continue');
    await tester.enterText(find.byType(TextFormField).first, 'Robert');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Injections, no CGM');

    // Six steps rather than ten: no hardware to record, and nothing selected
    // has a countdown, so there is nothing to time or be reminded about.
    expect(find.text('Step 4 of 6'), findsOneWidget);

    await tapText(tester, 'Continue');
    expect(find.text('What should DT1FLOW track?'), findsOneWidget);
  });

  testWidgets('the name is required before the flow will move on', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Continue');

    expect(find.text('Who is this for?'), findsOneWidget);
    final Finder continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).first, 'Robert');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });

  testWidgets('back returns to the previous question with its answer intact', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Continue');
    await tester.enterText(find.byType(TextFormField).first, 'Robert');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');

    expect(find.text('How do you manage your diabetes?'), findsOneWidget);
    await tapText(tester, 'Back');

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(find.text('Robert'), findsOneWidget);
  });

  testWidgets('choosing Spanish translates the flow immediately', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Español');

    expect(find.text('Elige tu idioma'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('the language chosen during onboarding is the one stored', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpApp(tester, onboarded: false);

    await tapText(tester, 'Get started');
    await tapText(tester, 'Español');
    await tapText(tester, 'Continuar');
    await tester.enterText(find.byType(TextFormField).first, 'Roberto');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continuar');
    await tapText(tester, 'Inyecciones, sin MCG');

    while (find.text('Crear mi perfil').evaluate().isEmpty) {
      await tapText(tester, 'Continuar');
    }
    await tapText(tester, 'Crear mi perfil');

    final UserProfile? profile = await app.harness.profiles.findPrimary();
    expect(profile!.languageCode, 'es');
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Inicio'),
      ),
      findsOneWidget,
      reason: 'the app should stay in Spanish after onboarding',
    );

    final List<ConsumableType> types = await app.harness.allConsumableTypes();
    expect(
      types.map((ConsumableType type) => type.name),
      contains('Agujas de pluma'),
      reason: 'types are named in the language the user chose',
    );
  });

  testWidgets('the summary returns to any answer it shows', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);

    await _fillToSummary(tester);

    await tapText(tester, 'Treatment');
    expect(find.text('How do you manage your diabetes?'), findsOneWidget);
  });

  testWidgets('a change made from the summary is kept', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpApp(tester, onboarded: false);

    await _fillToSummary(tester);
    await tapText(tester, 'Glucose unit');
    await tapText(tester, 'mmol/L');

    // Walk forward to the end again.
    while (find.text('Create my profile').evaluate().isEmpty) {
      await tapText(tester, 'Continue');
    }
    await tapText(tester, 'Create my profile');

    final UserProfile? profile = await app.harness.profiles.findPrimary();
    expect(profile!.glucoseUnit, GlucoseUnit.mmolPerL);
  });

  testWidgets('onboarding is unreachable once a profile exists', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Welcome to DT1FLOW'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

/// Fills in the two required answers and walks to the summary.
Future<void> _fillToSummary(WidgetTester tester) async {
  Future<void> tapText(String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  await tapText('Get started');
  await tapText('Continue');
  await tester.enterText(find.byType(TextFormField).first, 'Robert');
  await tester.pumpAndSettle();
  await tapText('Continue');
  await tapText('Pump and CGM');

  while (find.text('Ready to go').evaluate().isEmpty) {
    await tapText('Continue');
  }
}

void _useTallScreen() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
  binding.platformDispatcher.views.first
    ..physicalSize = const Size(1000, 2400)
    ..devicePixelRatio = 1;
  addTearDown(binding.platformDispatcher.views.first.reset);
}
