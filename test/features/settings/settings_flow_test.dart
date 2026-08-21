import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/settings/presentation/consumable_settings_screen.dart';
import 'package:blauloop/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The settings screen through the whole running application.
///
/// Two things it must never do, and both are checked here: lose a record, and
/// move a date the user did not agree to move.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  Future<AppUnderTest> pumpTallApp(
    WidgetTester tester, {
    String languageCode = 'en',
  }) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(tester, languageCode: languageCode);
  }

  Future<ConsumableType> seedType(
    AppUnderTest app, {
    String name = 'CGM sensor',
    Duration? duration = const Duration(days: 10),
    bool inUse = true,
  }) async {
    final ConsumableType type = await app.harness.seedType(
      name: name,
      defaultDuration: duration,
    );
    if (inUse) {
      await app.harness.instances.create(
        userProfileId: (await app.harness.profiles.findPrimary())!.id,
        consumableTypeId: type.id,
        installedAt: now.subtract(const Duration(days: 8)),
        expectedChangeAt: now.add(const Duration(days: 2)),
      );
    }
    return type;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
  }

  Future<UserProfile> profileOf(AppUnderTest app) async =>
      (await app.harness.profiles.findPrimary())!;

  Future<ConsumableType> reload(AppUnderTest app, ConsumableType type) async =>
      (await app.harness.types.findById(type.id))!;

  group('the profile', () {
    testWidgets('the name can be changed and Home greets by the new one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Robert');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await profileOf(app)).displayName, 'Robert');
    });

    testWidgets('an emptied name is refused rather than stored', (
      WidgetTester tester,
    ) async {
      // The column requires one, and it is what Home greets the user by.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('A name is needed'), findsOneWidget);
      expect((await profileOf(app)).displayName, 'Test');
    });

    testWidgets('switching language changes the app there and then', (
      WidgetTester tester,
    ) async {
      // A language that only took effect on the next launch would read as the
      // setting not having worked.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect(find.text('Lo que llevas'), findsOneWidget);
      expect((await profileOf(app)).languageCode, 'es');
    });

    testWidgets('it is honest that scheduled reminders keep their language', (
      WidgetTester tester,
    ) async {
      // Notification text is resolved when a reminder is scheduled, so
      // changing language cannot rewrite what the OS is already holding.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(
        find.textContaining('keep the language they were written in'),
        findsOneWidget,
      );
    });

    testWidgets('the units setting says the app does not read glucose', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(
        find.textContaining('does not read or interpret glucose'),
        findsOneWidget,
      );
    });
  });

  group('the preferred change time', () {
    testWidgets('says it is offered rather than applied', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(find.textContaining('never applied on its own'), findsOneWidget);
    });

    testWidgets('clearing it moves no deadline that is already set', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await app.harness.profiles.setPreferredChangeMinuteOfDay(
        (await profileOf(app)).id,
        9 * 60,
      );
      await tester.pumpAndSettle();
      final ConsumableInstance before = (await app.harness.instances
          .findActiveForType((await profileOf(app)).id, sensor.id))!;

      await openSettings(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect((await profileOf(app)).preferredChangeMinuteOfDay, isNull);
      final ConsumableInstance after = (await app.harness.instances.findById(
        before.id,
      ))!;
      expect(after.expectedChangeAt, before.expectedChangeAt);
    });
  });

  group('what you track', () {
    testWidgets('lists the consumables with how long each lasts', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(find.text('CGM sensor'), findsOneWidget);
      expect(find.text('10 days'), findsOneWidget);
    });

    testWidgets('turning one off keeps everything it recorded', (
      WidgetTester tester,
    ) async {
      // Hiding, never deleting. The first mistap must not cost a history.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);

      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // ignore: avoid_print
      print(
        'IN DETAIL: ${find.descendant(of: find.byType(ConsumableSettingsScreen), matching: find.byType(CircularProgressIndicator)).evaluate().length}',
      );
      // ignore: avoid_print
      print(
        'IN SETTINGS: ${find.descendant(of: find.byType(SettingsScreen), matching: find.byType(CircularProgressIndicator)).evaluate().length}',
      );
      // ignore: avoid_print
      print('SWITCH: ${find.byType(SwitchListTile).evaluate().length}');
      expect((await reload(app, sensor)).active, isFalse);
      // The instance that was in use is untouched.
      expect(
        await app.harness.db.select(app.harness.db.consumableInstances).get(),
        hasLength(1),
      );
    });

    testWidgets('and it can be turned back on', (WidgetTester tester) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await app.harness.types.deactivate(sensor.id);
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(find.text('Not tracked'), findsOneWidget);

      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect((await reload(app, sensor)).active, isTrue);
    });
  });

  group('one consumable', () {
    testWidgets('says the app does not know how long the product lasts', (
      WidgetTester tester,
    ) async {
      // The catalogue's wear times have never been checked against a
      // manufacturer, and a wrong duration is a reminder on the wrong day.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsumableSettingsScreen), findsOneWidget);
      expect(
        find.textContaining('BlauLoop does not know how long your product'),
        findsWidgets,
      );
    });

    testWidgets('changing the duration does not re-date what is worn', (
      WidgetTester tester,
    ) async {
      // A duration describes the next cycle. Silently moving a deadline for
      // something already on the body would be the app changing a fact it
      // never observed.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      final ConsumableInstance before = (await app.harness.instances
          .findActiveForType((await profileOf(app)).id, sensor.id))!;
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10 days'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await reload(app, sensor)).defaultDurationMinutes, 7 * 24 * 60);
      final ConsumableInstance after = (await app.harness.instances.findById(
        before.id,
      ))!;
      expect(after.expectedChangeAt, before.expectedChangeAt);
    });

    testWidgets('a duration of zero makes it counted rather than timed', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10 days'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await reload(app, sensor)).defaultDurationMinutes, isNull);
      expect(find.text('Counted, not timed'), findsWidgets);
    });

    testWidgets('a reminder offset can be ticked on', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();

      expect(find.text('No reminders'), findsOneWidget);

      // Twenty-four hours reads as a day: the same fact, more readably, and
      // exactly so — the formatter only collapses a duration when nothing is
      // lost by it.
      await tester.tap(find.text('1 day before'));
      await tester.pumpAndSettle();

      expect(
        (await reload(app, sensor)).defaultReminderOffsets,
        contains(const Duration(hours: 24)),
      );
    });

    testWidgets('its own change time falls back to the general one', (
      WidgetTester tester,
    ) async {
      // Null on the type means inherit, not "no preference" — the whole point
      // of the column being nullable.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('CGM sensor'));
      await tester.pumpAndSettle();

      expect(find.text('Follows your general preference'), findsOneWidget);
    });
  });
}
