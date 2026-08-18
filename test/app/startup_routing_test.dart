import 'package:dt1flow/app/router/app_router.dart';
import 'package:dt1flow/app/router/app_routes.dart';
import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Where a launch lands is one decision, taken in one place. These tests cover
/// it twice: the rule on its own, and the app actually obeying it.
void main() {
  group('the rule', () {
    const AsyncValue<UserProfile?> loading = AsyncLoading<UserProfile?>();
    const AsyncValue<UserProfile?> none = AsyncData<UserProfile?>(null);

    test('while the profile is unknown, everything waits on startup', () {
      expect(startupRedirect(loading, AppRoute.dashboard.path), '/startup');
      expect(startupRedirect(loading, AppRoute.onboarding.path), '/startup');
      expect(
        startupRedirect(loading, AppRoute.startup.path),
        isNull,
        reason: 'already there',
      );
    });

    test('a failed read waits on startup too, where the retry is', () {
      final AsyncValue<UserProfile?> failed = AsyncError<UserProfile?>(
        Exception('disk'),
        StackTrace.empty,
      );

      expect(startupRedirect(failed, AppRoute.dashboard.path), '/startup');
    });

    test('no profile means onboarding, and nothing else', () {
      expect(startupRedirect(none, AppRoute.dashboard.path), '/onboarding');
      expect(startupRedirect(none, AppRoute.settings.path), '/onboarding');
      expect(startupRedirect(none, AppRoute.startup.path), '/onboarding');
      expect(startupRedirect(none, AppRoute.onboarding.path), isNull);
    });

    test('with a profile, the entry points hand over to the dashboard', () {
      final AsyncValue<UserProfile?> onboarded = AsyncData<UserProfile?>(
        _profile,
      );

      expect(startupRedirect(onboarded, AppRoute.startup.path), '/');
      expect(startupRedirect(onboarded, AppRoute.onboarding.path), '/');
      expect(
        startupRedirect(onboarded, AppRoute.calendar.path),
        isNull,
        reason: 'an onboarded user navigates freely',
      );
    });
  });

  group('the app', () {
    testWidgets('a first launch lands in onboarding', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, onboarded: false);

      expect(find.text('Welcome to DT1FLOW'), findsOneWidget);
    });

    testWidgets('a returning launch lands on the dashboard', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Welcome to DT1FLOW'), findsNothing);
    });

    testWidgets('a profile appearing moves the user on by itself', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpApp(tester, onboarded: false);
      expect(find.text('Welcome to DT1FLOW'), findsOneWidget);

      // What submitting onboarding does, without the ten taps.
      await app.harness.seedProfile();
      await tester.pumpAndSettle();

      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'writing a profile is what ends onboarding',
      );
    });
  });
}

final UserProfile _profile = UserProfile(
  id: 'test-0001',
  displayName: 'Robert',
  timezone: 'Europe/Madrid',
  languageCode: 'en',
  glucoseUnit: GlucoseUnit.mgPerDl,
  treatmentType: TreatmentType.pumpAndCgm,
  createdAt: DateTime.utc(2026, 8, 17),
  updatedAt: DateTime.utc(2026, 8, 17),
);
