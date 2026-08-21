import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/dashboard/presentation/widgets/consumable_rail.dart';
import 'package:blauloop/features/incidents/presentation/report_incident_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Reporting a failure, through the whole running application.
///
/// The engine is unit tested next door against a pinned clock. What these add
/// is the part only the wired app can show: that a circle on Home reaches the
/// sheet, that the sheet reaches the engine, and that the two answers with no
/// default really do hold the save button.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  Future<AppUnderTest> pumpTallApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(tester);
  }

  Future<ConsumableType> seedType(
    AppUnderTest app, {
    String name = 'CGM sensor',
    ConsumableCategory category = ConsumableCategory.cgmSensor,
    Duration? dueIn = const Duration(days: 2),
    bool inUse = true,
  }) async {
    final ConsumableType type = await app.harness.seedType(
      name: name,
      category: category,
    );
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

  /// Taps the consumable's circle on Home, not its card. The name is on both,
  /// and the rail is the entry point under test.
  Future<void> tapCircle(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ConsumableRail),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReportSheet(WidgetTester tester, String name) async {
    await tapCircle(tester, name);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
  }

  /// The sheet's own save button.
  final Finder save = find.descendant(
    of: find.byType(ReportIncidentSheet),
    matching: find.widgetWithText(FilledButton, 'Save report'),
  );

  bool isEnabled(WidgetTester tester, Finder button) =>
      tester.widget<FilledButton>(button).onPressed != null;

  Future<List<Incident>> incidents(AppUnderTest app) =>
      app.harness.db.select(app.harness.db.incidents).get();
  Future<List<ConsumableInstance>> instances(AppUnderTest app) =>
      app.harness.db.select(app.harness.db.consumableInstances).get();

  group('getting there', () {
    testWidgets('a circle on Home opens the actions for that consumable', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();

      await tapCircle(tester, 'CGM sensor');

      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Register change'), findsOneWidget);
    });

    testWidgets('reporting is unavailable with nothing in use', (
      WidgetTester tester,
    ) async {
      // Nothing has ever been registered, so there is no instance for an
      // incident to point at. The row says why rather than being a dead tap.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, inUse: false);
      await tester.pumpAndSettle();

      await tapCircle(tester, 'CGM sensor');

      expect(find.text('Nothing is in use for this one yet'), findsOneWidget);
      final ListTile row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Report a problem'),
      );
      expect(row.enabled, isFalse);
    });
  });

  group('the sheet', () {
    testWidgets('will not save until both answers are given', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');

      // Neither the reason nor the outcome has a default, because a
      // pre-ticked one would write an account of someone's day that they
      // never gave.
      expect(isEnabled(tester, save), isFalse);

      await tester.tap(find.widgetWithText(ChoiceChip, 'It lost signal'));
      await tester.pumpAndSettle();
      expect(isEnabled(tester, save), isFalse);

      await tester.tap(find.text('I put a new one on'));
      await tester.pumpAndSettle();
      expect(isEnabled(tester, save), isTrue);
    });

    testWidgets('says what it does and does not do with the report', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');

      expect(
        find.textContaining(
          'It does not tell you what caused it or what to do about it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('leads a sensor with the failures sensors have', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');

      // Ordered, not filtered: the bent cannula is further down the list, but
      // it is still there for the user whose product surprised them.
      expect(find.widgetWithText(ChoiceChip, 'Readings were off'), findsOne);
      expect(find.widgetWithText(ChoiceChip, 'Bent cannula'), findsOne);
    });

    testWidgets('previews the next deadline only once one is being opened', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');
      await tester.tap(find.widgetWithText(ChoiceChip, 'It lost signal'));
      await tester.pumpAndSettle();

      // Scoped to the sheet: Home's own summary card carries the same words
      // and is still in the tree behind the modal.
      final Finder preview = find.descendant(
        of: find.byType(ReportIncidentSheet),
        matching: find.text('Next change'),
      );
      expect(preview, findsNothing);

      await tester.tap(find.text('I put a new one on'));
      await tester.pumpAndSettle();
      expect(preview, findsOneWidget);
    });
  });

  group('what gets written', () {
    testWidgets('a replacement closes one cycle and opens the next', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');

      await tester.tap(find.widgetWithText(ChoiceChip, 'It lost signal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I put a new one on'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final List<Incident> logged = await incidents(app);
      expect(logged, hasLength(1));
      expect(logged.single.type, IncidentType.signalLoss);

      final List<ConsumableInstance> all = await instances(app);
      expect(all, hasLength(2));
      expect(
        all.where((ConsumableInstance i) => i.status.isOpen),
        hasLength(1),
      );

      // The change is a Drift stream away from Home, so nothing had to tell
      // the screen to redraw.
      expect(find.text('CGM sensor problem recorded.'), findsNothing);
      expect(
        find.textContaining('The new one is counting down.'),
        findsOneWidget,
      );
    });

    testWidgets('keeping it on records the failure and nothing else', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      final List<ConsumableInstance> before = await instances(app);
      await openReportSheet(tester, 'CGM sensor');

      await tester.tap(find.widgetWithText(ChoiceChip, 'The skin reacted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('It is still on'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(await incidents(app), hasLength(1));
      expect(await instances(app), before);
      expect(find.text('CGM sensor problem recorded.'), findsOneWidget);
    });

    testWidgets('the note the user typed is kept', (WidgetTester tester) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openReportSheet(tester, 'CGM sensor');

      await tester.tap(find.widgetWithText(ChoiceChip, 'It came off'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'caught it on a door handle',
      );
      await tester.tap(find.text('I took it off, nothing on yet'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final List<Incident> logged = await incidents(app);
      expect(logged.single.notes, 'caught it on a door handle');

      // Nothing was put on, so nothing is counting down.
      final List<ConsumableInstance> all = await instances(app);
      expect(all, hasLength(1));
      expect(all.single.status, ConsumableStatus.removedEarly);
    });
  });
}
