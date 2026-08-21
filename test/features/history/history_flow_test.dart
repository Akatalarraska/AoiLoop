import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/calendar/presentation/calendar_screen.dart';
import 'package:blauloop/features/dashboard/presentation/widgets/consumable_rail.dart';
import 'package:blauloop/features/history/presentation/history_screen.dart';
import 'package:blauloop/features/incidents/presentation/report_incident_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The calendar and the timeline through the whole running application.
///
/// The merging and the grid arithmetic are pinned next door. What these add is
/// the part only the wired app can show: that both sources reach the screen,
/// that the filters narrow what is on it, and that logging something puts it
/// there without anything being told to refresh.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  Future<AppUnderTest> pumpTallApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(tester);
  }

  Future<ConsumableType> seedType(
    AppUnderTest app, {
    String name = 'CGM sensor',
    bool inUse = true,
    Duration? dueIn = const Duration(days: 2),
  }) async {
    final ConsumableType type = await app.harness.seedType(name: name);
    if (inUse) {
      await app.harness.instances.create(
        userProfileId: (await app.harness.profiles.findPrimary())!.id,
        consumableTypeId: type.id,
        installedAt: now.subtract(const Duration(days: 8)),
        expectedChangeAt: dueIn == null ? null : now.add(dueIn),
      );
    }
    return type;
  }

  /// Writes a change straight to the database, as something logged earlier.
  Future<void> seedChange(
    AppUnderTest app,
    ConsumableType type, {
    required DateTime at,
    ChangeType reason = ChangeType.scheduled,
  }) async {
    final UserProfile profile = (await app.harness.profiles.findPrimary())!;
    final ConsumableInstance instance = await app.harness.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: at,
      status: ConsumableStatus.completed,
    );
    await app.harness.changes.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      changedAt: at,
      type: reason,
    );
  }

  Future<void> seedIncident(
    AppUnderTest app,
    ConsumableType type, {
    required DateTime at,
  }) async {
    final UserProfile profile = (await app.harness.profiles.findPrimary())!;
    final ConsumableInstance instance = await app.harness.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: at,
      status: ConsumableStatus.removedEarly,
    );
    await app.harness.incidents.create(
      userProfileId: profile.id,
      consumableInstanceId: instance.id,
      occurredAt: at,
      type: IncidentType.occlusion,
    );
  }

  /// Taps the consumable's circle on Home, not its summary card. The name is
  /// on both, and the circle is the entry point under test.
  Future<void> tapCircle(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ConsumableRail),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  group('the timeline', () {
    testWidgets('says nothing has been logged, and how to change that', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, inUse: false);
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(
        find.text(
          'Register a change or report a problem and it shows up here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('carries changes and problems in one list', (
      WidgetTester tester,
    ) async {
      // A timeline built on changes alone would be missing entries rather than
      // merely terse.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 3)));
      await seedIncident(
        app,
        sensor,
        at: now.subtract(const Duration(days: 1)),
      );
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      expect(find.text('2 entries'), findsOneWidget);
      expect(find.text('Changed on schedule'), findsOneWidget);
      expect(find.text('Blocked line or cannula'), findsOneWidget);
    });

    testWidgets('says what it does and does not do with the record', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, inUse: false);
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      expect(find.textContaining('it does not judge it'), findsOneWidget);
    });

    testWidgets('heads yesterday as yesterday', (WidgetTester tester) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 1)));
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('a filter narrows the list and says so when nothing matches', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 3)));
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Problems'));
      await tester.pumpAndSettle();

      // Telling somebody their history is empty when it is only hidden would
      // be a small betrayal.
      expect(find.text('Nothing matches what you are filtering by.'), findsOne);
      expect(find.text('Nothing logged yet'), findsNothing);
    });

    testWidgets('changes only leaves the problems out', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 3)));
      await seedIncident(
        app,
        sensor,
        at: now.subtract(const Duration(days: 1)),
      );
      await tester.pumpAndSettle();
      await openTab(tester, 'History');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Changes'));
      await tester.pumpAndSettle();

      expect(find.text('1 entry'), findsOneWidget);
      expect(find.text('Blocked line or cannula'), findsNothing);
    });
  });

  group('the calendar', () {
    testWidgets('shows the month and how much is in it', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 3)));
      await tester.pumpAndSettle();
      await openTab(tester, 'Calendar');

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('1 thing logged this month'), findsOneWidget);
    });

    testWidgets('opening a day shows what was logged on it', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app, inUse: false);
      await seedChange(app, sensor, at: DateTime(2026, 8, 12, 10));
      await tester.pumpAndSettle();
      await openTab(tester, 'Calendar');

      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();

      expect(find.text('Logged'), findsOneWidget);
      expect(find.text('Changed on schedule'), findsOneWidget);
    });

    testWidgets('a deadline ahead is shown as expected, not as logged', (
      WidgetTester tester,
    ) async {
      // A history entry is a record; an expectation is a date the app worked
      // out. Drawing them the same way would let a plan read as a fact.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, dueIn: const Duration(days: 3));
      await tester.pumpAndSettle();
      await openTab(tester, 'Calendar');

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.text('Expected'), findsOneWidget);
      expect(find.text('CGM sensor due'), findsOneWidget);
      expect(find.text('Logged'), findsNothing);
    });

    testWidgets('an empty day says so rather than showing nothing', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, inUse: false);
      await tester.pumpAndSettle();
      await openTab(tester, 'Calendar');

      // The 15th, not the 5th: a six-row grid runs into September, so a
      // single digit appears twice and the finder would be ambiguous.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing on this day.'), findsWidgets);
    });

    testWidgets('stepping back a month changes the heading', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, inUse: false);
      await tester.pumpAndSettle();
      await openTab(tester, 'Calendar');

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('July 2026'), findsOneWidget);
    });
  });

  group('reaching one consumable', () {
    testWidgets('a circle on Home offers its history', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();

      await tapCircle(tester, 'CGM sensor');

      expect(find.text('See its history'), findsOneWidget);
    });

    testWidgets('opening it lands on the timeline, narrowed to that one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      final ConsumableType other = await seedType(
        app,
        name: 'Infusion set',
        inUse: false,
      );
      await seedChange(app, sensor, at: now.subtract(const Duration(days: 3)));
      await seedChange(app, other, at: now.subtract(const Duration(days: 2)));
      await tester.pumpAndSettle();

      await tapCircle(tester, 'CGM sensor');
      await tester.tap(find.text('See its history'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
    });
  });

  testWidgets('a problem logged now appears without a reload', (
    WidgetTester tester,
  ) async {
    // It writes an Incidents row and no change event, so this is also the case
    // a changes-only timeline would have dropped silently.
    final AppUnderTest app = await pumpTallApp(tester);
    await seedType(app);
    await tester.pumpAndSettle();

    await tapCircle(tester, 'CGM sensor');
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'The skin reacted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('It is still on'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ReportIncidentSheet),
        matching: find.widgetWithText(FilledButton, 'Save report'),
      ),
    );
    await tester.pumpAndSettle();

    await openTab(tester, 'History');

    expect(find.text('The skin reacted'), findsOneWidget);
    expect(find.text('1 entry'), findsOneWidget);
  });
}
