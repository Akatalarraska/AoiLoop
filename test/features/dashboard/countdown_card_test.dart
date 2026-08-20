import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/dashboard/domain/dashboard_view.dart';
import 'package:blauloop/features/dashboard/presentation/widgets/countdown_card.dart';
import 'package:blauloop/shared/models/cycle_countdown.dart';
import 'package:blauloop/shared/models/cycle_status.dart';
import 'package:blauloop/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';
import '../../support/test_database.dart';

/// A countdown card is the smallest unit of what BlauLoop is for, so these
/// tests hold it to the rules the whole app is judged by: never colour alone,
/// never a number rounded in the user's favour, and one sentence to a screen
/// reader rather than three fragments.
void main() {
  late TestHarness harness;
  late UserProfile profile;
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  setUp(() async {
    harness = TestHarness.create(now: now);
    profile = await harness.seedProfile();
  });

  Future<DashboardCard> cardFor({
    String name = 'CGM sensor',
    DateTime? due,
    DateTime? installedAt,
    bool started = true,
  }) async {
    final ConsumableType type = await harness.seedType(name: name);
    if (!started) {
      return DashboardCard(
        type: type,
        instance: null,
        countdown: CycleCountdown.inactive,
      );
    }

    final DateTime installed =
        installedAt ?? now.subtract(const Duration(days: 8));
    final ConsumableInstance instance = await harness.instances.create(
      userProfileId: profile.id,
      consumableTypeId: type.id,
      installedAt: installed,
      expectedChangeAt: due,
    );
    return DashboardCard(
      type: type,
      instance: instance,
      countdown: CycleCountdown.at(
        installedAt: installed,
        expectedChangeAt: due,
        now: now,
      ),
    );
  }

  group('what it says', () {
    testWidgets('names the consumable and counts down in days', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(days: 2)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('CGM sensor'), findsOneWidget);
      expect(find.text('2 days left'), findsOneWidget);
    });

    testWidgets('rounds down rather than flattering the remaining time', (
      WidgetTester tester,
    ) async {
      // 23 hours and 50 minutes. Rounding up to "1 day left" would tell
      // someone they have longer than they do.
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(hours: 23, minutes: 50)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('23 hours left'), findsOneWidget);
      expect(find.text('1 day left'), findsNothing);
    });

    testWidgets('drops to minutes in the last hour', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(minutes: 20)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('20 minutes left'), findsOneWidget);
    });

    testWidgets('says how late it is once the deadline has passed', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.subtract(const Duration(days: 3)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('3 days late'), findsOneWidget);
    });

    testWidgets('says nothing is in use when nothing has been registered', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(started: false);

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('Nothing in use'), findsOneWidget);
      expect(find.textContaining('Due '), findsNothing);
    });

    testWidgets('shows the due date under the countdown', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(days: 2)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.textContaining('Due '), findsOneWidget);
    });

    testWidgets('falls back to the install date when nothing is due', (
      WidgetTester tester,
    ) async {
      // An item in use with no wear cycle: still worth saying when it started.
      final DashboardCard card = await cardFor(name: 'Open insulin', due: null);

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.textContaining('In use since '), findsOneWidget);
    });
  });

  group('how it says it', () {
    testWidgets('carries the status as a chip, not as colour alone', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(hours: 5)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      final StatusChip chip = tester.widget<StatusChip>(
        find.byType(StatusChip),
      );
      expect(chip.status, CycleStatus.dueSoon);
      expect(find.text('Due soon'), findsOneWidget);
    });

    testWidgets('draws a progress bar for anything counting down', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        installedAt: now.subtract(const Duration(days: 5)),
        due: now.add(const Duration(days: 5)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      final LinearProgressIndicator bar = tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
      expect(bar.value, closeTo(0.5, 0.001));
    });

    testWidgets('draws no progress bar when nothing is counting down', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(started: false);

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('announces one sentence, not three fragments', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.subtract(const Duration(days: 1)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(
        find.bySemanticsLabel('CGM sensor. Overdue. 1 day late.'),
        findsOneWidget,
      );
    });

    testWidgets('translates every part of that sentence', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        name: 'Sensor MCG',
        due: now.add(const Duration(days: 2)),
      );

      await pumpInApp(
        tester,
        CountdownCard(card: card),
        locale: const Locale('es'),
      );

      expect(find.text('Quedan 2 días'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sensor MCG. Todo en orden. Quedan 2 días.'),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow at a large text scale', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        name: 'A rather long consumable name',
        due: now.add(const Duration(hours: 5)),
      );

      await pumpInApp(tester, CountdownCard(card: card), textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode without losing its status', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.subtract(const Duration(days: 2)),
      );

      await pumpInApp(
        tester,
        CountdownCard(card: card),
        brightness: Brightness.dark,
      );

      expect(find.text('Overdue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('its action', () {
    testWidgets('offers to register a change, and reports the tap', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(days: 1)),
      );
      int taps = 0;

      await pumpInApp(
        tester,
        CountdownCard(card: card, onRegisterChange: () => taps++),
      );
      await tester.tap(find.text('Register change'));

      expect(taps, 1);
    });

    testWidgets('hides the action when no handler is given', (
      WidgetTester tester,
    ) async {
      final DashboardCard card = await cardFor(
        due: now.add(const Duration(days: 1)),
      );

      await pumpInApp(tester, CountdownCard(card: card));

      expect(find.text('Register change'), findsNothing);
    });
  });
}
