import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/changes/presentation/register_change_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Registering a change, through the whole running application.
///
/// The engine is unit tested next door against a pinned clock. What these add
/// is the part only the wired app can show: that the sheet reaches the engine,
/// that the write lands, and that Home redraws itself off the Drift stream
/// without anything telling it to.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  Future<AppUnderTest> pumpTallApp(
    WidgetTester tester, {
    int? preferredChangeMinuteOfDay,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(
      tester,
      preferredChangeMinuteOfDay: preferredChangeMinuteOfDay,
    );
  }

  Future<ConsumableType> seedType(
    AppUnderTest app, {
    required String name,
    Duration? dueIn,
    Duration installedAgo = const Duration(days: 1),
    bool inUse = true,
    int? preferredChangeMinuteOfDay,
  }) async {
    final ConsumableType type = await app.harness.seedType(
      name: name,
      preferredChangeMinuteOfDay: preferredChangeMinuteOfDay,
    );
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

  /// The sheet's own confirm button.
  ///
  /// Scoped to the sheet on purpose: Home's summary button carries the same
  /// label and is still in the tree behind the modal, so an unscoped finder
  /// matches two widgets and taps neither.
  final Finder confirmChange = find.descendant(
    of: find.byType(RegisterChangeSheet),
    matching: find.widgetWithText(FilledButton, 'Register change'),
  );

  Future<List<ConsumableInstance>> instances(AppUnderTest app) =>
      app.harness.db.select(app.harness.db.consumableInstances).get();

  group('registering a change', () {
    testWidgets('closes the old cycle and opens a new one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final List<ConsumableInstance> all = await instances(app);
      expect(all, hasLength(2));

      final ConsumableInstance closed = all.firstWhere(
        (ConsumableInstance i) => i.status != ConsumableStatus.active,
      );
      final ConsumableInstance opened = all.firstWhere(
        (ConsumableInstance i) => i.status == ConsumableStatus.active,
      );

      // Replaced two days before it was due, which is early and is recorded
      // as such rather than quietly counted as a completed cycle.
      expect(closed.status, ConsumableStatus.removedEarly);
      expect(closed.removedAt, now);
      expect(opened.installedAt, now);
      expect(opened.expectedChangeAt, now.add(const Duration(days: 10)));
    });

    testWidgets('writes the event that links the two instances', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final List<ChangeEvent> events = await app.harness.db
          .select(app.harness.db.changeEvents)
          .get();
      expect(events, hasLength(1));
      expect(events.single.previousConsumableInstanceId, isNotNull);
      expect(events.single.type, ChangeType.early);
    });

    testWidgets('restarts the countdown on Home without being told to', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      expect(find.text('2 days left'), findsWidgets);

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      // No invalidate, no refresh call: `watchActive` is a Drift stream and
      // the write is what redraws the screen.
      expect(find.text('2 days left'), findsNothing);
      expect(find.text('10 days left'), findsWidgets);
    });

    testWidgets('confirms in words that it was recorded', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      expect(find.text('CGM sensor change registered.'), findsOneWidget);
    });

    testWidgets('cancelling writes nothing at all', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await instances(app), hasLength(1));
      expect(
        await app.harness.db.select(app.harness.db.changeEvents).get(),
        isEmpty,
      );
    });
  });

  group('the first change after onboarding', () {
    testWidgets('asks which consumable it was, rather than guessing', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await seedType(app, name: 'Infusion set', inUse: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(find.text('What did you change?'), findsOneWidget);

      await tester.tap(find.text('Infusion set').last);
      await tester.pumpAndSettle();

      expect(find.text('Change Infusion set'), findsOneWidget);
    });

    testWidgets('starts the first cycle with nothing to close', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await tester.pumpAndSettle();

      // A single tracked type is not ambiguous, so no chooser appears.
      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      expect(find.text('Change CGM sensor'), findsOneWidget);

      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final List<ConsumableInstance> all = await instances(app);
      expect(all, hasLength(1));
      expect(all.single.status, ConsumableStatus.active);
      expect(all.single.expectedChangeAt, now.add(const Duration(days: 10)));
    });
  });

  group('the preferred change time', () {
    testWidgets('is not mentioned when the user never chose one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('is offered, and left off until the user says otherwise', (
      WidgetTester tester,
    ) async {
      // 09:00 local. The clock is pinned to 09:00 UTC, so unless the machine
      // running this sits in UTC the deadline lands somewhere other than
      // 09:00 local and there is a genuine shift to offer.
      final AppUnderTest app = await pumpTallApp(
        tester,
        preferredChangeMinuteOfDay: 9 * 60,
      );
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      final Finder offer = find.byType(CheckboxListTile);
      if (offer.evaluate().isEmpty) {
        // Running in UTC: the natural deadline already falls at 09:00, so
        // there is nothing to move and withholding the offer is correct.
        return;
      }

      expect(tester.widget<CheckboxListTile>(offer).value, isFalse);

      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      // Declined by default: the stored deadline is the full ten days.
      final ConsumableInstance opened = (await instances(app)).firstWhere(
        (ConsumableInstance i) => i.status == ConsumableStatus.active,
      );
      expect(opened.expectedChangeAt, now.add(const Duration(days: 10)));
    });

    testWidgets('shortens the cycle when accepted', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(
        tester,
        preferredChangeMinuteOfDay: 9 * 60,
      );
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      final Finder offer = find.byType(CheckboxListTile);
      if (offer.evaluate().isEmpty) {
        return; // See above: nothing to offer when the test runs in UTC.
      }

      await tester.tap(offer);
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final ConsumableInstance opened = (await instances(app)).firstWhere(
        (ConsumableInstance i) => i.status == ConsumableStatus.active,
      );
      final DateTime due = opened.expectedChangeAt!;

      // Earlier than the full cycle, never later, and landing on 09:00 local.
      expect(due.isBefore(now.add(const Duration(days: 10))), isTrue);
      expect(due.toLocal().hour, 9);
      expect(due.toLocal().minute, 0);
    });
  });

  group("a consumable with a change time of its own", () {
    testWidgets("the offer names the type's hour, not the profile's", (
      WidgetTester tester,
    ) async {
      // 20:00 on the profile, 08:00 on the type. Formatted for the en locale
      // in a widget test that is 8:00 PM versus 8:00 AM, so a sheet reading
      // the wrong one is unmistakable rather than off by a rounding.
      final AppUnderTest app = await pumpTallApp(
        tester,
        preferredChangeMinuteOfDay: 20 * 60,
      );
      await seedType(
        app,
        name: 'CGM sensor',
        dueIn: const Duration(days: 2),
        preferredChangeMinuteOfDay: 8 * 60,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      final Finder offer = find.byType(CheckboxListTile);
      expect(
        offer,
        findsOneWidget,
        reason: '08:00 is always a shift away from a 09:00 UTC deadline',
      );

      final String label = tester
          .widget<Text>(
            find.descendant(of: offer, matching: find.byType(Text)).first,
          )
          .data!;
      expect(label, contains('8:00 AM'));
      expect(
        label,
        isNot(contains('PM')),
        reason: 'the profile 20:00 must not reach this label',
      );
    });

    testWidgets('and the stored deadline uses that hour', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(
        tester,
        preferredChangeMinuteOfDay: 20 * 60,
      );
      await seedType(
        app,
        name: 'CGM sensor',
        dueIn: const Duration(days: 2),
        preferredChangeMinuteOfDay: 8 * 60,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final ConsumableInstance opened = (await instances(app)).firstWhere(
        (ConsumableInstance i) => i.status == ConsumableStatus.active,
      );
      expect(opened.expectedChangeAt!.toLocal().hour, 8);
      expect(opened.expectedChangeAt!.toLocal().minute, 0);
    });
  });

  group('an early change', () {
    testWidgets('says what will be recorded and offers to say why', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      // Phrased as a record rather than a reproach. Changing something early
      // is a thing people do for good reasons, and an app that tuts at them
      // is one they stop telling the truth to.
      expect(
        find.textContaining('goes into your history as an early change'),
        findsOneWidget,
      );
      expect(find.text('Why, if you want to say'), findsOneWidget);
    });

    testWidgets('keeps the reason on the change, not on the new one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(days: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Why, if you want to say'),
        'going swimming',
      );
      await tester.tap(confirmChange);
      await tester.pumpAndSettle();

      final List<ChangeEvent> events = await app.harness.db
          .select(app.harness.db.changeEvents)
          .get();
      expect(events.single.type, ChangeType.early);
      expect(events.single.notes, 'going swimming');

      // "Going swimming" is a fact about the swap. Hung on the new sensor it
      // would read as a remark about something that has not done anything yet.
      final ConsumableInstance opened = (await instances(app))
          .firstWhere((ConsumableInstance i) => i.status.isOpen);
      expect(opened.notes, isNull);
    });

    testWidgets('does not ask an on-time change to explain itself', (
      WidgetTester tester,
    ) async {
      // Shares the dashboard's own 24 hour threshold, so a swap the evening
      // before the deadline is following the app's prompt, not failing at
      // anything.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', dueIn: const Duration(hours: 6));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(find.text('Why, if you want to say'), findsNothing);
    });

    testWidgets('a first ever change has no date to have missed', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor', inUse: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();

      expect(find.text('Why, if you want to say'), findsNothing);
    });
  });
}
