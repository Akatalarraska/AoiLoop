import 'package:dt1flow/core/database/app_database.dart';
import 'package:dt1flow/features/dashboard/presentation/widgets/countdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Home, running inside the whole application.
///
/// These go through [pumpApp] rather than building the screen directly,
/// because half of what Phase 3 delivers only exists once the real providers
/// are wired: the database streams that make a card appear the moment
/// something is registered, and the tick that keeps its number honest
/// afterwards.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  /// Pumps the app on a viewport tall enough to build the whole page.
  ///
  /// Home is a `ListView`, so on the default 800pt test surface everything
  /// below the fold is never built and `find` cannot see it. Scrolling to each
  /// assertion would test the scroll physics; these tests are about what the
  /// screen says.
  Future<AppUnderTest> pumpTallApp(
    WidgetTester tester, {
    String languageCode = 'en',
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(tester, languageCode: languageCode);
  }

  /// Sends the app to the background and brings it back.
  ///
  /// The intermediate `hidden` states are not decoration: `AppLifecycleListener`
  /// asserts on transitions, and a phone never jumps straight from inactive to
  /// paused.
  void backgroundAndResume(
    WidgetTester tester, {
    required VoidCallback while_,
  }) {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }

    while_();

    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// A tracked type, optionally with something already in use.
  ///
  /// Seeded *after* the app is pumped, which is the interesting order: the
  /// dashboard is watching, so this is the same path a real change takes.
  Future<ConsumableType> seedType(
    AppUnderTest app, {
    required String name,
    Duration? dueIn,
    Duration installedAgo = const Duration(days: 1),
    bool inUse = true,
  }) async {
    final ConsumableType type = await app.harness.seedType(name: name);
    if (inUse) {
      await app.harness.instances.create(
        userProfileId: (await app.harness.profiles.findPrimary())!.id,
        consumableTypeId: type.id,
        installedAt: now.subtract(installedAgo),
        expectedChangeAt: dueIn == null ? null : now.add(dueIn),
      );
    }
    return type;
  }

  group('a dashboard with nothing registered yet', () {
    testWidgets('greets by name and says nothing is counting down', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await tester.pumpAndSettle();

      expect(find.text('Hello, Test'), findsOneWidget);
      expect(find.text('Nothing is counting down yet'), findsOneWidget);
      expect(
        find.text(
          'Register a change and DT1FLOW starts the countdown from there.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('still shows a card for everything set up', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await seedType(app, name: 'Infusion set', inUse: false);
      await tester.pumpAndSettle();

      expect(find.byType(CountdownCard), findsNWidgets(2));
      expect(find.text('Nothing in use'), findsNWidgets(2));
    });
  });

  group('a dashboard with something in use', () {
    testWidgets('leads with the next change and counts it down', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 3));
      await tester.pumpAndSettle();

      expect(find.text('Next change'), findsOneWidget);
      // Once on the summary card, once on the countdown card below it.
      expect(find.text('3 days left'), findsNWidgets(2));
      expect(find.text('Nothing needs changing right now.'), findsOneWidget);
    });

    testWidgets('leads with the most urgent, not the nearest', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(
        app,
        name: 'Infusion set',
        dueIn: const Duration(hours: 2),
      );
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: -2));
      await tester.pumpAndSettle();

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Next change'), findsNothing);
      expect(find.text('2 days late'), findsNWidgets(2));
      expect(find.text('2 items need changing'), findsOneWidget);
    });

    testWidgets('orders the cards with the most urgent at the top', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'Reservoir', dueIn: const Duration(days: 5));
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: -1));
      await seedType(
        app,
        name: 'Infusion set',
        dueIn: const Duration(hours: 4),
      );
      await tester.pumpAndSettle();

      final List<String> order = tester
          .widgetList<CountdownCard>(find.byType(CountdownCard))
          .map((CountdownCard card) => card.card.type.name)
          .toList();

      expect(order, <String>['CGM sensor', 'Infusion set', 'Reservoir']);
    });
  });

  group('countdowns stay correct without a restart', () {
    testWidgets('the number follows the clock when the ticker fires', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(hours: 3));
      await tester.pumpAndSettle();

      expect(find.text('3 hours left'), findsNWidgets(2));

      app.harness.clock.advance(const Duration(hours: 2));
      app.ticker.tick();
      await tester.pumpAndSettle();

      expect(find.text('1 hour left'), findsNWidgets(2));
      expect(find.text('3 hours left'), findsNothing);
    });

    testWidgets('the status changes although nothing was written', (
      WidgetTester tester,
    ) async {
      // Twenty-five hours out is comfortably on track; two hours later the
      // same untouched row is due soon. Nothing in the database moved.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(hours: 25));
      await tester.pumpAndSettle();

      expect(find.text('On track'), findsOneWidget);

      app.harness.clock.advance(const Duration(hours: 2));
      app.ticker.tick();
      await tester.pumpAndSettle();

      expect(find.text('Due soon'), findsOneWidget);
      expect(find.text('On track'), findsNothing);
    });

    testWidgets('coming back from the background catches up immediately', (
      WidgetTester tester,
    ) async {
      // The phone that spent the night in a drawer: the OS froze the timer,
      // so nothing ticked. Resuming has to re-read the clock rather than wait
      // out a minute showing last night's number.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      expect(find.text('2 days left'), findsNWidgets(2));

      backgroundAndResume(
        tester,
        while_: () => app.harness.clock.advance(const Duration(days: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 day left'), findsNWidgets(2));
    });

    testWidgets('a change registered elsewhere appears without a reload', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await tester.pumpAndSettle();

      expect(find.text('Nothing is counting down yet'), findsOneWidget);

      await app.harness.instances.create(
        userProfileId: (await app.harness.profiles.findPrimary())!.id,
        consumableTypeId: (await app.harness.allConsumableTypes()).single.id,
        installedAt: now,
        expectedChangeAt: now.add(const Duration(days: 10)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next change'), findsOneWidget);
      expect(find.text('10 days left'), findsNWidgets(2));
    });
  });

  group('nothing to track', () {
    testWidgets('says so rather than showing a blank tab', (
      WidgetTester tester,
    ) async {
      await pumpTallApp(tester);

      expect(find.text('Nothing to track'), findsOneWidget);
      expect(find.byType(CountdownCard), findsNothing);
      expect(find.text('Register change'), findsNothing);
    });

    testWidgets('is honest that changing it is not built yet', (
      WidgetTester tester,
    ) async {
      await pumpTallApp(tester);

      expect(
        find.textContaining('Choosing what to track arrives with the settings'),
        findsOneWidget,
      );
    });
  });

  group('the register change call to action', () {
    testWidgets('says what does not work yet instead of doing nothing', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Registering a change arrives in phase 4'),
        findsOneWidget,
      );
    });

    testWidgets('is offered on every card as well as on the summary', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await seedType(app, name: 'Infusion set', dueIn: const Duration(days: 1));
      await tester.pumpAndSettle();

      // One on the summary card, one per countdown card.
      expect(find.text('Register change'), findsNWidgets(3));
    });
  });

  testWidgets('keeps the medical boundary notice visible', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpTallApp(tester);
    await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('DT1FLOW does not calculate doses or give treatment advice.'),
      findsOneWidget,
    );
  });

  testWidgets('runs in Spanish for a Spanish profile', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpTallApp(tester, languageCode: 'es');
    await seedType(app, name: 'Sensor MCG', dueIn: const Duration(days: 2));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Test'), findsOneWidget);
    expect(find.text('Próximo cambio'), findsOneWidget);
    expect(find.text('Quedan 2 días'), findsNWidgets(2));
  });
}
