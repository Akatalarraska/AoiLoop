import 'package:dt1flow/app/app.dart';
import 'package:dt1flow/core/database/database_providers.dart';
import 'package:dt1flow/core/database/id_generator.dart';
import 'package:dt1flow/core/utils/clock.dart';
import 'package:dt1flow/core/utils/timezone_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

/// A time zone that does not depend on where the test happens to run.
class FixedTimezoneSource implements TimezoneSource {
  const FixedTimezoneSource([this.zone = 'Europe/Madrid']);

  final String zone;

  @override
  String currentZone() => zone;
}

/// A running application under test: its database and its providers.
class AppUnderTest {
  const AppUnderTest({required this.harness, required this.container});

  final TestHarness harness;

  /// Read providers from here to assert on state the UI does not show.
  final ProviderContainer container;
}

/// Pumps the whole application — router, redirects and all — against an
/// in-memory database.
///
/// Widget tests that build a screen directly cannot see the thing Phase 2
/// actually changed: *where a launch lands*. That is decided by the router
/// reading the profile, so anything that cares has to build the real
/// [DT1FlowApp].
///
/// [onboarded] seeds a profile, which is the whole difference between landing
/// on the dashboard and landing in onboarding.
///
/// The container is created with [ProviderContainer.test] and handed to an
/// `UncontrolledProviderScope` rather than letting a `ProviderScope` widget
/// own it. Disposing a container tears down Drift's query streams, and Drift
/// defers that with a zero-duration timer — harmless in production, but if it
/// happens while a widget test is unmounting, the test framework reports a
/// pending timer and fails a test that did nothing wrong. Disposing in a
/// teardown instead keeps that off the fake clock.
Future<AppUnderTest> pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
  String languageCode = 'en',
  List<Override> overrides = const <Override>[],
}) async {
  final TestHarness harness = TestHarness.create();
  if (onboarded) {
    await harness.seedProfile(languageCode: languageCode);
  }

  final ProviderContainer container = ProviderContainer.test(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(harness.db),
      clockProvider.overrideWithValue(harness.clock),
      idGeneratorProvider.overrideWithValue(harness.ids),
      timezoneSourceProvider.overrideWithValue(const FixedTimezoneSource()),
      ...overrides,
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DT1FlowApp()),
  );
  await tester.pumpAndSettle();

  return AppUnderTest(harness: harness, container: container);
}
