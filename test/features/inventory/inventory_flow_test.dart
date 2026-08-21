import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/inventory/presentation/inventory_locations_screen.dart';
import 'package:blauloop/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The inventory through the whole running application.
///
/// The totals and the low-stock rule are unit tested next door. What these add
/// is the part only the wired app can show: that the screen reads the database
/// back, that the sheets write to it, and that Home hears about it.
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
    bool tracksInventory = true,
  }) async {
    final ConsumableType type = await app.harness.seedType(
      name: name,
      tracksInventory: tracksInventory,
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

  Future<void> seedStock(
    AppUnderTest app,
    ConsumableType type, {
    int quantity = 0,
    int minimum = 0,
  }) async {
    await app.harness.inventory.createItem(
      userProfileId: (await app.harness.profiles.findPrimary())!.id,
      consumableTypeId: type.id,
      quantity: quantity,
      minimumQuantity: minimum,
    );
  }

  Future<void> openInventory(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
  }

  Future<int> total(AppUnderTest app, ConsumableType type) async {
    final UserProfile profile = (await app.harness.profiles.findPrimary())!;
    return app.harness.inventory.totalQuantity(profile.id, type.id);
  }

  group('what the screen shows', () {
    testWidgets('says what the app does automatically, and who overrules it', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      expect(
        find.textContaining('BlauLoop subtracts one each time'),
        findsOneWidget,
      );
      expect(
        find.textContaining('you can correct the count whenever it is wrong'),
        findsOneWidget,
      );
    });

    testWidgets('a consumable nobody counted reads as not counted', (
      WidgetTester tester,
    ) async {
      // Not "none left". Zero is a fact and unknown is not.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      expect(find.text('Not counted'), findsWidgets);
      expect(find.text('Nothing counted yet'), findsOneWidget);
    });

    testWidgets('shows the total and the level it will warn at', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 8, minimum: 3);
      await tester.pumpAndSettle();
      await openInventory(tester);

      expect(find.text('8 left'), findsOneWidget);
      expect(find.text('Warn me at 3'), findsOneWidget);
      expect(find.text('In stock'), findsOneWidget);
    });

    testWidgets('marks what is running low', (WidgetTester tester) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 2, minimum: 3);
      await tester.pumpAndSettle();
      await openInventory(tester);

      expect(find.text('Running low'), findsOneWidget);
      expect(find.text('1 thing is running low'), findsOneWidget);
    });

    testWidgets('leaves out consumables the user does not count', (
      WidgetTester tester,
    ) async {
      // A type with counting switched off has no business sitting at a total
      // of zero beside the things they do count.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app, name: 'CGM sensor');
      await seedType(app, name: 'Test strips', tracksInventory: false);
      await tester.pumpAndSettle();
      await openInventory(tester);

      expect(find.text('CGM sensor'), findsOneWidget);
      expect(find.text('Test strips'), findsNothing);
    });
  });

  group('changing the count', () {
    testWidgets('adding stock creates a batch with that many units', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Add stock'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'How many are you adding'),
        '6',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await total(app, sensor), 6);
      expect(find.text('6 left'), findsOneWidget);
    });

    testWidgets('the lot number is folded away, the expiry date is not', (
      WidgetTester tester,
    ) async {
      // Copying a code off a box is no part of why anyone opens a tracker, and
      // the app does nothing with it. The expiry date is the opposite: it is
      // what the going-off reminders are built on.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Add stock'));
      await tester.pumpAndSettle();

      expect(find.text('Expiry date (optional)'), findsOneWidget);
      expect(find.text('Lot number (optional)'), findsNothing);

      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(find.text('Lot number (optional)'), findsOneWidget);
    });

    testWidgets('correcting the count overrules whatever the app thought', (
      WidgetTester tester,
    ) async {
      // Boxes get borrowed and someone else restocks the cupboard. The person
      // holding the supplies is the authority.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 8);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Correct the count'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'How many you actually have'),
        '3',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await total(app, sensor), 3);
    });

    testWidgets('correcting keeps the expiry dates of the other batches', (
      WidgetTester tester,
    ) async {
      // The reason this is not a tidiness point: those dates are what the
      // expiry reminders are built on. Emptying the far batch to balance the
      // total would tell somebody all eight boxes go off next month.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      final UserProfile profile = (await app.harness.profiles.findPrimary())!;
      await app.harness.inventory.createItem(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        quantity: 2,
        expirationDate: now.add(const Duration(days: 30)),
      );
      await app.harness.inventory.createItem(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        quantity: 6,
        expirationDate: now.add(const Duration(days: 400)),
      );
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Correct the count'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'How many you actually have'),
        '7',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final List<InventoryItem> batches = await app.harness.inventory
          .findByType(profile.id, sensor.id);
      expect(await total(app, sensor), 7);
      // One came out of the batch going off soonest. The far one is untouched,
      // and still says what it says.
      expect(batches.first.quantity, 1);
      expect(batches.last.quantity, 6);
      expect(batches.last.expirationDate, isNotNull);
    });

    testWidgets('correcting upwards adds to the batch going off soonest', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      final UserProfile profile = (await app.harness.profiles.findPrimary())!;
      await app.harness.inventory.createItem(
        userProfileId: profile.id,
        consumableTypeId: sensor.id,
        quantity: 2,
        expirationDate: now.add(const Duration(days: 30)),
      );
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Correct the count'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'How many you actually have'),
        '5',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(await total(app, sensor), 5);
    });

    testWidgets('a warning level can be set before any stock exists', (
      WidgetTester tester,
    ) async {
      // Otherwise the app would refuse the answer until the user typed a
      // quantity they may not know yet.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Set warning level'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Warn me when I have this many or fewer',
        ),
        '4',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Warn me at 4'), findsOneWidget);
      expect(await total(app, sensor), 0);
    });

    testWidgets('a non-number is refused rather than guessed at', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.text('Add stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);
      expect(await total(app, sensor), 0);
    });
  });

  group('places', () {
    testWidgets('makes clear that stock does not need one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);

      await tester.tap(find.byTooltip('Places'));
      await tester.pumpAndSettle();

      expect(find.byType(InventoryLocationsScreen), findsOneWidget);
      expect(
        find.text('No places yet. Stock does not need one.'),
        findsOneWidget,
      );
    });

    testWidgets('a place can be added and shows up in the list', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();
      await openInventory(tester);
      await tester.tap(find.byTooltip('Places'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Backpack',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Backpack'), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('says nothing about stock when nothing is low', (
      WidgetTester tester,
    ) async {
      // A warning that is always on screen stops being a warning.
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 9, minimum: 2);
      await tester.pumpAndSettle();

      expect(find.textContaining('running low'), findsNothing);
    });

    testWidgets('warns when a supply drops to its level, and links across', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 2, minimum: 2);
      await tester.pumpAndSettle();

      expect(find.text('1 supply is running low'), findsOneWidget);

      await tester.tap(find.text('Check supplies'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryScreen), findsOneWidget);
    });
  });

  group('registering a change', () {
    testWidgets('takes one off the count without being asked', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 5);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Register change').last,
      );
      await tester.pumpAndSettle();

      expect(await total(app, sensor), 4);
    });

    testWidgets('says so when that was the last one', (
      WidgetTester tester,
    ) async {
      final AppUnderTest app = await pumpTallApp(tester);
      final ConsumableType sensor = await seedType(app);
      await seedStock(app, sensor, quantity: 1);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Register change').last,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('That was your last CGM sensor.'),
        findsOneWidget,
      );
    });

    testWidgets('never tells someone who is not counting that they ran out', (
      WidgetTester tester,
    ) async {
      // It would be an invention. They have not run out; they are simply not
      // counting.
      final AppUnderTest app = await pumpTallApp(tester);
      await seedType(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Register change').last,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('was your last'), findsNothing);
      expect(find.textContaining('left to subtract'), findsNothing);
      expect(find.text('CGM sensor change registered.'), findsOneWidget);
    });
  });
}
