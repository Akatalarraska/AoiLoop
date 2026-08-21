import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/body_map/presentation/body_map_screen.dart';
import 'package:blauloop/features/body_map/presentation/body_site_picker.dart';
import 'package:blauloop/features/changes/presentation/register_change_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The body map through the whole running application.
///
/// The view model is unit tested next door at a fixed instant. What these add
/// is the part only the wired app can show: that the sites get created on
/// first visit, that choosing one reaches the engine, and that the map reads
/// back what the change flow wrote.
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
    Duration? dueIn = const Duration(days: 2),
    bool inUse = true,
    String? bodySiteId,
  }) async {
    final ConsumableType type = await app.harness.seedType(name: name);
    if (inUse) {
      await app.harness.instances.create(
        userProfileId: (await app.harness.profiles.findPrimary())!.id,
        consumableTypeId: type.id,
        installedAt: now.subtract(const Duration(days: 8)),
        expectedChangeAt: dueIn == null ? null : now.add(dueIn),
        bodySiteId: bodySiteId,
      );
    }
    return type;
  }

  Future<void> openBodyTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Body'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<ConsumableInstance>> instances(AppUnderTest app) =>
      app.harness.db.select(app.harness.db.consumableInstances).get();

  group('first visit', () {
    testWidgets('creates the standard sites for a profile that has none', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      expect(
        await app.harness.bodySites.findAll(
          (await app.harness.profiles.findPrimary())!.id,
        ),
        isEmpty,
      );

      await openBodyTab(tester);

      // Seeded on the read path, which is what serves the profiles that
      // finished onboarding before the body map existed.
      expect(find.text('Left arm'), findsOneWidget);
      expect(find.text('Right buttock'), findsOneWidget);
    });

    testWidgets('groups the sites under the part of the body they are on', (
      WidgetTester tester,
    ) async {
      await pumpTallApp(tester);
      await openBodyTab(tester);

      for (final String heading in <String>[
        'Arms',
        'Abdomen',
        'Thighs',
        'Buttocks',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
    });

    testWidgets('says nothing is on you, and says why it is not advising', (
      WidgetTester tester,
    ) async {
      await pumpTallApp(tester);
      await openBodyTab(tester);

      expect(find.text('Nothing on you right now'), findsOneWidget);
      expect(
        find.textContaining('it does not tell you where to put the next one'),
        findsOneWidget,
      );
    });

    testWidgets('every site reads as never used, not as a long rest', (
      WidgetTester tester,
    ) async {
      // A duration would be a different claim, and a false one.
      await pumpTallApp(tester);
      await openBodyTab(tester);

      expect(find.text('Never used'), findsNWidgets(10));
      expect(find.textContaining('Free for'), findsNothing);
    });
  });

  group('what the map reports', () {
    testWidgets('names what is currently on a site', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await openBodyTab(tester);

      final BodySite arm = (await app.harness.bodySites.findAll(
        (await app.harness.profiles.findPrimary())!.id,
      )).firstWhere((BodySite s) => s.bodyRegion == BodyRegion.leftArm);
      await seedType(app, bodySiteId: arm.id);
      await tester.pumpAndSettle();

      expect(find.text('In use now: CGM sensor'), findsOneWidget);
      expect(find.text('1 site in use'), findsOneWidget);
    });

    testWidgets('marks the site that has gone longest without use', (
      WidgetTester tester,
    ) async {
      await pumpTallApp(tester);
      await openBodyTab(tester);

      // A statement of fact about the user's own history. The copy is checked
      // here precisely because the line closest to advice is the one that must
      // never become it — "longest without use" is arithmetic, "try this one"
      // would not be.
      expect(find.text('Longest without use'), findsOneWidget);
      expect(find.textContaining('try'), findsNothing);
    });
  });

  group('choosing where it went', () {
    testWidgets('the register-change sheet offers a site', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(find.text('Where'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
    });

    testWidgets('the chosen site is what gets stored', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BodySitePicker),
          matching: find.text('Left thigh'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Left thigh'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(RegisterChangeSheet),
          matching: find.widgetWithText(FilledButton, 'Register change'),
        ),
      );
      await tester.pumpAndSettle();

      final ConsumableInstance opened = (await instances(app))
          .firstWhere((ConsumableInstance i) => i.status.isOpen);
      final BodySite thigh = (await app.harness.bodySites.findAll(
        (await app.harness.profiles.findPrimary())!.id,
      )).firstWhere((BodySite s) => s.bodyRegion == BodyRegion.leftThigh);

      expect(opened.bodySiteId, thigh.id);
    });

    testWidgets('a routine change stays where the last one was', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await openBodyTab(tester);
      final BodySite arm = (await app.harness.bodySites.findAll(
        (await app.harness.profiles.findPrimary())!.id,
      )).firstWhere((BodySite s) => s.bodyRegion == BodyRegion.leftArm);

      await seedType(app, bodySiteId: arm.id);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      // The site only moves when the user says it did, and the sheet says so
      // rather than leaving them guessing whether it carried over.
      expect(find.text('Left arm'), findsOneWidget);
      expect(find.text('Same place as before'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(RegisterChangeSheet),
          matching: find.widgetWithText(FilledButton, 'Register change'),
        ),
      );
      await tester.pumpAndSettle();

      final ConsumableInstance opened = (await instances(app))
          .firstWhere((ConsumableInstance i) => i.status.isOpen);
      expect(opened.bodySiteId, arm.id);
    });

    testWidgets('placement can be declined outright', (
      WidgetTester tester,
    ) async {
      // Tracking a site is a courtesy the app offers, not a toll it charges
      // for logging a change.
      final AppUnderTest app = await pumpTallApp(tester);
      await openBodyTab(tester);
      final BodySite arm = (await app.harness.bodySites.findAll(
        (await app.harness.profiles.findPrimary())!.id,
      )).firstWhere((BodySite s) => s.bodyRegion == BodyRegion.leftArm);

      await seedType(app, bodySiteId: arm.id);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave it unrecorded'));
      await tester.pumpAndSettle();

      expect(find.text('Not recorded'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(RegisterChangeSheet),
          matching: find.widgetWithText(FilledButton, 'Register change'),
        ),
      );
      await tester.pumpAndSettle();

      final ConsumableInstance opened = (await instances(app))
          .firstWhere((ConsumableInstance i) => i.status.isOpen);
      expect(opened.bodySiteId, isNull);
    });
  });

  testWidgets('the map reads back what the change flow wrote', (
    WidgetTester tester,
  ) async {
    final AppUnderTest app = await pumpTallApp(tester);
    await seedType(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register change').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BodySitePicker),
        matching: find.text('Right thigh'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(RegisterChangeSheet),
        matching: find.widgetWithText(FilledButton, 'Register change'),
      ),
    );
    await tester.pumpAndSettle();

    await openBodyTab(tester);

    expect(find.byType(BodyMapScreen), findsOneWidget);
    expect(find.text('In use now: CGM sensor'), findsOneWidget);
    expect(find.text('1 site in use'), findsOneWidget);
  });
}
