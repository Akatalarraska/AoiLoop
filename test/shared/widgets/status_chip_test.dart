import 'package:blauloop/app/theme/status_palette.dart';
import 'package:blauloop/shared/models/cycle_status.dart';
import 'package:blauloop/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('renders an icon and a localised label, not colour alone', (
    WidgetTester tester,
  ) async {
    await pumpInApp(tester, const StatusChip(status: CycleStatus.dueSoon));

    expect(find.text('Due soon'), findsOneWidget);
    expect(find.byIcon(StatusPalette.light.dueSoon.icon), findsOneWidget);
  });

  testWidgets('translates its label', (WidgetTester tester) async {
    await pumpInApp(
      tester,
      const StatusChip(status: CycleStatus.overdue),
      locale: const Locale('es'),
    );

    expect(find.text('Cambio vencido'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('keeps the icon but drops the text when showLabel is false', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      const StatusChip(status: CycleStatus.healthy, showLabel: false),
    );

    expect(find.byIcon(StatusPalette.light.healthy.icon), findsOneWidget);
    expect(find.text('On track'), findsNothing);
  });

  testWidgets('announces one combined status to screen readers', (
    WidgetTester tester,
  ) async {
    await pumpInApp(tester, const StatusChip(status: CycleStatus.dueNow));

    // A single node, so TalkBack/VoiceOver say "Status: due now" rather than
    // reading an unlabelled icon and a stray word.
    expect(find.bySemanticsLabel('Status: Due now'), findsOneWidget);
  });

  testWidgets('keeps its semantics label when the text is hidden', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      const StatusChip(status: CycleStatus.inactive, showLabel: false),
    );

    expect(find.bySemanticsLabel('Status: Not set up'), findsOneWidget);
  });

  testWidgets('picks up the dark palette in dark mode', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      const StatusChip(status: CycleStatus.overdue),
      brightness: Brightness.dark,
    );

    final Text label = tester.widget<Text>(find.text('Overdue'));

    expect(label.style?.color, StatusPalette.dark.overdue.onContainer);
  });

  testWidgets('does not overflow at a large text scale', (
    WidgetTester tester,
  ) async {
    // Users with reduced vision run large system fonts. Overflow here would
    // clip the status label, which is one of the three channels carrying it.
    await pumpInApp(
      tester,
      const StatusChip(status: CycleStatus.dueSoon),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Due soon'), findsOneWidget);
  });

  testWidgets('renders every status without error', (
    WidgetTester tester,
  ) async {
    for (final CycleStatus status in CycleStatus.values) {
      await pumpInApp(tester, StatusChip(status: status));
      expect(tester.takeException(), isNull, reason: 'failed for $status');
    }
  });
}
