import 'package:blauloop/features/body_map/presentation/body_map_screen.dart';
import 'package:blauloop/features/calendar/presentation/calendar_screen.dart';
import 'package:blauloop/features/dashboard/presentation/dashboard_screen.dart';
import 'package:blauloop/features/history/presentation/history_screen.dart';
import 'package:blauloop/features/inventory/presentation/inventory_screen.dart';
import 'package:blauloop/features/settings/presentation/settings_screen.dart';
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

    // Every primary destination is built as of Phase 9, so each is checked
    // by the screen it actually shows rather than by a placeholder.
    for (final (String tab, Type screen) in <(String, Type)>[
      ('Calendar', CalendarScreen),
      ('Body', BodyMapScreen),
      ('History', HistoryScreen),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(screen),
        findsOneWidget,
        reason: 'tapping $tab did not show its screen',
      );
    }
  });

  testWidgets('the overflow menu reaches the settings themselves', (
    WidgetTester tester,
  ) async {
    // Built in Phase 10. Every screen that promised "arrives with the settings
    // screen" was pointing at this one.
    await pumpApp(tester);

    await tester.tap(find.byTooltip('More sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('What you track'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the overflow menu reaches the inventory itself', (
    WidgetTester tester,
  ) async {
    // Built in Phase 8, so it is the one secondary section no longer
    // answering with a placeholder.
    await pumpApp(tester);

    await tester.tap(find.byTooltip('More sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();

    // This profile has no consumables at all, so the screen answers with the
    // honest version of empty rather than a count of nothing.
    expect(find.byType(InventoryScreen), findsOneWidget);
    expect(
      find.textContaining('Nothing you set up counts stock'),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the overflow menu reaches the sections still to be built', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final (String section, String availability) in <(String, String)>[
      ('Travel', 'Planned for release 0.3, after the 0.1.0 MVP.'),
      ('Family', 'Planned for release 0.2, after the 0.1.0 MVP.'),
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
      find.text('BlauLoop does not calculate doses or give treatment advice.'),
      findsOneWidget,
    );
  });
}
