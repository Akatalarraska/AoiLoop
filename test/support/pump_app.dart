import 'package:aoiloop/app/theme/app_theme.dart';
import 'package:aoiloop/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside the real theme and the real localizations.
///
/// Widget tests that build their own bare `MaterialApp` end up testing a
/// different app than the one users get: no [AppTheme] extensions, no
/// `AppLocalizations`. Every widget test goes through this helper instead.
Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
