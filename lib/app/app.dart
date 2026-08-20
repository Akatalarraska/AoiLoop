import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'locale/locale_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget.
///
/// Everything configurable is read from Riverpod so tests and the settings
/// screen can override it: the router, the locale chosen during onboarding,
/// and later the theme mode.
class AoiLoopApp extends ConsumerWidget {
  const AoiLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // Resolved per-locale rather than a const string, so the task switcher
      // shows a localised name once the app has one.
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      routerConfig: router,
      // Null follows the OS. Onboarding and the profile override it.
      locale: ref.watch(appLocaleProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follows the OS. A manual override lands with settings in Phase 10.
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
