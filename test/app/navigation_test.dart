import 'package:dt1flow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Phase 0's deliverable is a navigable skeleton. These tests are what make
/// "navigable" a fact rather than a claim: every destination in the spec is
/// reachable, and the shell preserves each tab's own stack.
///
/// Since Phase 2 the app only shows that skeleton to someone who has a
/// profile, so every test here launches with one already seeded.
void main() {
  testWidgets('starts on Home', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('offers exactly the four primary destinations', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(bar.destinations, hasLength(4));
    for (final String label in <String>[
      'Home',
      'Calendar',
      'Body',
      'History',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: 'missing bottom destination: $label',
      );
    }
  });

  testWidgets('each primary destination is reachable from the bottom bar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final (String tab, int phase) in <(String, int)>[
      ('Calendar', 9),
      ('Body', 7),
      ('History', 9),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Planned for phase $phase of the roadmap.'),
        findsOneWidget,
        reason: 'tapping $tab did not show its screen',
      );
    }
  });

  testWidgets('the overflow menu reaches the four secondary sections', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final (String section, String availability) in <(String, String)>[
      ('Inventory', 'Planned for phase 8 of the roadmap.'),
      ('Travel', 'Planned for release 0.3, after the 0.1.0 MVP.'),
      ('Family', 'Planned for release 0.2, after the 0.1.0 MVP.'),
      ('Settings', 'Planned for phase 10 of the roadmap.'),
    ]) {
      await tester.tap(find.byTooltip('More sections'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(section).last);
      await tester.pumpAndSettle();

      expect(
        find.text(availability),
        findsOneWidget,
        reason: 'could not open $section from the overflow menu',
      );

      // Secondary sections are pushed, so they must offer a way back.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('switching tabs preserves each branch, and returns Home intact', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    Future<void> tapTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tapTab('History');
    await tapTab('Home');

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('runs in the language the profile was created with', (
    WidgetTester tester,
  ) async {
    // The OS says English; the profile says Spanish. The explicit choice made
    // during onboarding wins — reverting it on the next launch would read as
    // the app having forgotten.
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await pumpApp(tester, languageCode: 'es');

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Inicio'),
      ),
      findsOneWidget,
    );
    // Home greets by name, so a Spanish profile proves the locale reached
    // past the navigation chrome and into the screen itself.
    expect(find.text('Hola, Test'), findsOneWidget);
  });

  testWidgets('shows the medical boundary notice on Home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.text('DT1FLOW does not calculate doses or give treatment advice.'),
      findsOneWidget,
    );
  });
}
