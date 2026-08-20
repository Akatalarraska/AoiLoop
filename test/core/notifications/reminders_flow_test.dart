import 'package:aoiloop/core/database/app_database.dart';
import 'package:aoiloop/core/notifications/data/local_notification_gateway.dart';
import 'package:aoiloop/core/notifications/domain/notification_gateway.dart';
import 'package:aoiloop/features/changes/presentation/register_change_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/test_app.dart';

/// Reminders, through the whole running application.
///
/// The scheduler is unit tested next door. What these add is the wiring: that
/// Home says so when reminders cannot be delivered, that granting permission
/// actually schedules something, and that registering a change rebuilds the
/// reminders instead of leaving the old cycle's warnings in place.
void main() {
  /// The instant `TestHarness` pins its clock to.
  final DateTime now = DateTime.utc(2026, 8, 17, 9);

  Future<AppUnderTest> pumpTallApp(
    WidgetTester tester,
    FakeNotificationGateway gateway,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return pumpApp(
      tester,
      overrides: <Override>[
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
  }

  Future<ConsumableType> seedInUse(
    AppUnderTest app, {
    String name = 'CGM sensor',
    Duration dueIn = const Duration(days: 10),
  }) async {
    final ConsumableType type = await app.harness.types.create(
      name: name,
      category: ConsumableCategory.cgmSensor,
      defaultDuration: const Duration(days: 10),
      defaultReminderOffsets: const <Duration>[
        Duration(days: 1),
        Duration.zero,
      ],
    );
    await app.harness.instances.create(
      userProfileId: (await app.harness.profiles.findPrimary())!.id,
      consumableTypeId: type.id,
      installedAt: now,
      expectedChangeAt: now.add(dueIn),
    );
    return type;
  }

  group('when the OS will not deliver', () {
    testWidgets('Home says so rather than looking like it is working', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway(
        enabled: false,
      );
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app);
      await tester.pumpAndSettle();

      expect(find.text('Reminders are off'), findsOneWidget);
      expect(find.text('Allow reminders'), findsOneWidget);
    });

    testWidgets('granting permission schedules what was missing', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway(
        enabled: false,
      );
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app);
      await tester.pumpAndSettle();

      expect(gateway.outstanding, isEmpty);

      await tester.tap(find.text('Allow reminders'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 1);
      expect(gateway.outstanding, hasLength(2));
      expect(find.text('Reminders are off'), findsNothing);
    });

    testWidgets('a refusal is stated once, not retried', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway(
        enabled: false,
        grantsPermission: false,
      );
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allow reminders'));
      await tester.pumpAndSettle();

      expect(find.textContaining('blocked in system settings'), findsOneWidget);
      // The banner stays: the situation has not changed.
      expect(find.text('Reminders are off'), findsOneWidget);
    });
  });

  group('when reminders are working', () {
    testWidgets('Home shows no banner', (WidgetTester tester) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app);
      await tester.pumpAndSettle();

      expect(find.text('Reminders are off'), findsNothing);
    });

    testWidgets('one reminder is held per configured offset', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app);
      await tester.pumpAndSettle();

      expect(gateway.outstanding, hasLength(2));
      expect(
        gateway.outstanding.map((PendingNotification n) => n.at).toList(),
        <DateTime>[
          now.add(const Duration(days: 9)),
          now.add(const Duration(days: 10)),
        ],
      );
    });
  });

  group('registering a change', () {
    testWidgets('replaces the old cycle reminders with the new ones', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final AppUnderTest app = await pumpTallApp(tester, gateway);
      await seedInUse(app, dueIn: const Duration(days: 2));
      await tester.pumpAndSettle();

      // Warnings for the cycle that is about to be replaced.
      expect(
        gateway.outstanding.map((PendingNotification n) => n.at).toList(),
        <DateTime>[
          now.add(const Duration(days: 1)),
          now.add(const Duration(days: 2)),
        ],
      );

      await tester.tap(find.text('Register change').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RegisterChangeSheet),
          matching: find.widgetWithText(FilledButton, 'Register change'),
        ),
      );
      await tester.pumpAndSettle();

      // The old cycle's reminders would now be telling the user to do
      // something they have just done. They are gone, and the new cycle's ten
      // day deadline is what is held instead.
      expect(
        gateway.outstanding.map((PendingNotification n) => n.at).toList(),
        <DateTime>[
          now.add(const Duration(days: 9)),
          now.add(const Duration(days: 10)),
        ],
      );
    });
  });
}
