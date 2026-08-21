import 'package:blauloop/app/theme/category_icons.dart';
import 'package:blauloop/app/theme/status_palette.dart';
import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/features/dashboard/domain/dashboard_view.dart';
import 'package:blauloop/features/dashboard/presentation/widgets/consumable_rail.dart';
import 'package:blauloop/shared/models/cycle_countdown.dart';
import 'package:blauloop/shared/models/cycle_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';
import '../../support/test_database.dart';

/// The row of circles at the top of Home.
///
/// Two things it is not allowed to get wrong, both load-bearing elsewhere in
/// the app: a status is never carried by colour alone, and a horizontal row
/// has to survive a 200% text scale.
void main() {
  late TestHarness harness;
  late UserProfile profile;
  final DateTime now = DateTime.utc(2026, 8, 21, 9);

  setUp(() async {
    harness = TestHarness.create(now: now);
    profile = await harness.seedProfile();
  });

  /// A card for a consumable with [remaining] left on it. Null means nothing
  /// is in use, which is every type on the day after onboarding.
  Future<DashboardCard> card({
    String name = 'CGM sensor',
    ConsumableCategory category = ConsumableCategory.cgmSensor,
    Duration? remaining = const Duration(days: 3),
  }) async {
    final ConsumableType type = await harness.seedType(
      name: name,
      category: category,
    );
    if (remaining == null) {
      return DashboardCard(
        type: type,
        instance: null,
        countdown: CycleCountdown.inactive,
      );
    }

    final DateTime due = now.add(remaining);
    final DateTime installed = due.subtract(const Duration(days: 10));
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

  /// Five consumables, which is what a typical setup tracks.
  Future<List<DashboardCard>> fiveCards() async {
    return <DashboardCard>[
      await card(name: 'CGM sensor'),
      await card(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      ),
      await card(name: 'Reservoir', category: ConsumableCategory.reservoir),
      await card(name: 'Pod', category: ConsumableCategory.pod),
      await card(name: 'Transmitter', category: ConsumableCategory.transmitter),
    ];
  }

  Future<void> pumpRail(
    WidgetTester tester,
    List<DashboardCard> cards, {
    double textScale = 1,
    ValueChanged<DashboardCard>? onTap,
  }) {
    return pumpInApp(
      tester,
      ConsumableRail(cards: cards, onTap: onTap ?? (DashboardCard _) {}),
      textScale: textScale,
    );
  }

  testWidgets('draws one circle per tracked consumable', (
    WidgetTester tester,
  ) async {
    await pumpRail(tester, <DashboardCard>[
      await card(name: 'CGM sensor'),
      await card(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      ),
    ]);

    expect(find.text('CGM sensor'), findsOneWidget);
    expect(find.text('Infusion set'), findsOneWidget);
    expect(
      find.byIcon(CategoryIcons.of(ConsumableCategory.cgmSensor)),
      findsOneWidget,
    );
    expect(
      find.byIcon(CategoryIcons.of(ConsumableCategory.infusionSet)),
      findsOneWidget,
    );
  });

  testWidgets('says nothing at all when nothing is tracked', (
    WidgetTester tester,
  ) async {
    await pumpRail(tester, const <DashboardCard>[]);

    // Not an empty state — Home already has one, and a caption floating above
    // a row with no circles under it would be a label for nothing.
    expect(find.text('Tap one to log a change or a problem.'), findsNothing);
  });

  testWidgets('carries the countdown in words, not just in colour', (
    WidgetTester tester,
  ) async {
    await pumpRail(tester, <DashboardCard>[
      await card(remaining: const Duration(hours: 6)),
    ]);

    expect(find.text('6 hours left'), findsOneWidget);
  });

  testWidgets('carries the status on three channels', (
    WidgetTester tester,
  ) async {
    // Colour, shape and text together — the rule every status surface in
    // BlauLoop obeys, because a ring nobody can tell from teal is not a
    // status.
    await pumpRail(tester, <DashboardCard>[
      await card(remaining: -const Duration(days: 2)),
    ]);

    final StatusVisuals overdue = StatusPalette.light.of(CycleStatus.overdue);
    expect(find.byIcon(overdue.icon), findsOneWidget);
    expect(find.text('2 days late'), findsOneWidget);

    final Text countdown = tester.widget<Text>(find.text('2 days late'));
    expect(countdown.style?.color, overdue.color);
  });

  testWidgets('an untracked consumable still gets a circle', (
    WidgetTester tester,
  ) async {
    // Built from types, not instances. Someone who has just finished
    // onboarding has five types and no instances, and a rail that waited for
    // the first change would be empty at the moment it is most needed.
    await pumpRail(tester, <DashboardCard>[await card(remaining: null)]);

    expect(find.text('CGM sensor'), findsOneWidget);
    expect(find.text('Nothing in use'), findsOneWidget);
  });

  testWidgets('a tap hands back the card that was tapped', (
    WidgetTester tester,
  ) async {
    DashboardCard? tapped;
    await pumpRail(tester, <DashboardCard>[
      await card(name: 'CGM sensor'),
      await card(
        name: 'Infusion set',
        category: ConsumableCategory.infusionSet,
      ),
    ], onTap: (DashboardCard card) => tapped = card);

    await tester.tap(find.text('Infusion set'));
    await tester.pumpAndSettle();

    expect(tapped?.type.name, 'Infusion set');
  });

  testWidgets('reads as one sentence to a screen reader', (
    WidgetTester tester,
  ) async {
    // Element by element it would announce a name, a ring and a number as
    // three unrelated fragments.
    await pumpRail(tester, <DashboardCard>[
      await card(remaining: const Duration(hours: 6)),
    ]);

    expect(
      find.bySemanticsLabel('CGM sensor. Due soon. 6 hours left.'),
      findsOneWidget,
    );
  });

  for (final double scale in <double>[1, 1.5, 2]) {
    testWidgets('survives a ${(scale * 100).round()}% text scale', (
      WidgetTester tester,
    ) async {
      await pumpRail(tester, await fiveCards(), textScale: scale);

      // An overflow paints an error banner and records an exception, so a
      // clean take is the assertion. The names surviving is the other half: a
      // row that stays inside its bounds by truncating every word has not
      // survived, it has given up.
      expect(tester.takeException(), isNull);
      expect(find.text('CGM sensor'), findsOneWidget);
      expect(find.text('Transmitter'), findsOneWidget);
    });
  }

  testWidgets('tiles grow with the text rather than clipping it', (
    WidgetTester tester,
  ) async {
    final DashboardCard only = await card();

    await pumpRail(tester, <DashboardCard>[only]);
    final double atNormalScale = tester
        .getSize(find.byType(InkWell).first)
        .width;

    await pumpRail(tester, <DashboardCard>[only], textScale: 2);
    final double atDoubleScale = tester
        .getSize(find.byType(InkWell).first)
        .width;

    expect(atDoubleScale, greaterThan(atNormalScale));
  });
}
