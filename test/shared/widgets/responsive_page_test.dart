import 'package:blauloop/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// The page column that stops growing once the screen gets wide.
///
/// `AppSpacing.pagePadding` promised these helpers from Phase 0 and there were
/// none until Phase 10. These pin what the promise now means.
void main() {
  Future<double> widthOf(WidgetTester tester, double screenWidth) async {
    tester.view.physicalSize = Size(screenWidth, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpInApp(
      tester,
      const ResponsivePage(children: <Widget>[Text('anything')]),
    );
    return tester.getSize(find.byType(ListView)).width;
  }

  testWidgets('uses the whole width of a phone', (WidgetTester tester) async {
    expect(await widthOf(tester, 400), 400);
  });

  testWidgets('stops growing on a tablet', (WidgetTester tester) async {
    // Past a point the extra room becomes margin. A line of text stops being
    // readable somewhere around 70 characters however much space is going
    // spare, and a card stretched across a tablet reads as a bug.
    expect(await widthOf(tester, 1400), ResponsivePage.maxContentWidth);
  });

  testWidgets('sits at the top rather than floating in the middle', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpInApp(
      tester,
      const ResponsivePage(children: <Widget>[Text('a short page')]),
    );

    // A short page on a tall screen keeps its heading where a heading belongs.
    expect(tester.getTopLeft(find.text('a short page')).dy, lessThan(100));
  });

  testWidgets('still scrolls when the content is taller than the screen', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      ResponsivePage(
        children: <Widget>[
          for (int i = 0; i < 60; i++) SizedBox(height: 40, child: Text('$i')),
        ],
      ),
    );

    expect(find.text('0'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
  });
}
