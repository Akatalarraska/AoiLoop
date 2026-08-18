import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../features/body_map/presentation/body_map_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/data/user_profile_repository.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/travel/presentation/travel_screen.dart';
import '../../shared/widgets/main_shell.dart';
import 'app_routes.dart';
import 'route_error_screen.dart';
import 'startup_screen.dart';

/// Root navigator, used by routes that must cover the bottom navigation bar.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// The application router.
///
/// Where a launch lands is decided by one question — does a profile exist? —
/// answered by [primaryProfileProvider] and applied in [startupRedirect]. Until that
/// stream produces something, every location resolves to the startup screen,
/// so nobody sees a flash of the wrong app.
///
/// The four primary destinations live in a [StatefulShellRoute.indexedStack],
/// so each keeps its own navigation stack. The order of [StatefulShellBranch]
/// entries below must match the destination order in `MainShell`.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter re-runs its redirect when this notifies. Riverpod owns the state;
  // this is only the adapter between the two.
  final _RouterRefresh refresh = _RouterRefresh();
  ref.listen<AsyncValue<UserProfile?>>(
    primaryProfileProvider,
    (AsyncValue<UserProfile?>? previous, AsyncValue<UserProfile?> next) =>
        refresh.notify(),
    fireImmediately: true,
  );
  ref.onDispose(refresh.dispose);

  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.startup.path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) => startupRedirect(
      ref.read(primaryProfileProvider),
      state.matchedLocation,
    ),
    errorBuilder: (BuildContext context, GoRouterState state) =>
        RouteErrorScreen(location: state.uri.toString()),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.startup.path,
        name: AppRoute.startup.routeName,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.routeName,
        builder: (_, _) => const OnboardingScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return MainShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.dashboard.path,
                name: AppRoute.dashboard.routeName,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.calendar.path,
                name: AppRoute.calendar.routeName,
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.bodyMap.path,
                name: AppRoute.bodyMap.routeName,
                builder: (_, _) => const BodyMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.history.path,
                name: AppRoute.history.routeName,
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),

      // Secondary sections, pushed over the shell so they get a back button
      // and full height.
      GoRoute(
        path: AppRoute.inventory.path,
        name: AppRoute.inventory.routeName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const InventoryScreen(),
      ),
      GoRoute(
        path: AppRoute.travel.path,
        name: AppRoute.travel.routeName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TravelScreen(),
      ),
      GoRoute(
        path: AppRoute.family.path,
        name: AppRoute.family.routeName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const FamilyScreen(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.routeName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Where [location] should actually resolve to, given what is known about the
/// profile. Null means "stay where you are".
///
/// Pure, and separate from the router, because this is the one piece of
/// navigation logic worth testing directly: the three states it distinguishes
/// — not read yet, no profile, profile — are exactly the three ways a launch
/// can go wrong.
String? startupRedirect(AsyncValue<UserProfile?> profile, String location) {
  final bool atStartup = location == AppRoute.startup.path;
  final bool atOnboarding = location == AppRoute.onboarding.path;

  // Nothing read yet, or the read failed: the startup screen covers both, and
  // offers a retry for the second.
  if (!profile.hasValue) {
    return atStartup ? null : AppRoute.startup.path;
  }

  // No profile means onboarding has not run. Nothing else is reachable until
  // it has — every other screen is about a profile that does not exist.
  if (profile.value == null) {
    return atOnboarding ? null : AppRoute.onboarding.path;
  }

  // Onboarded. The two entry points have done their job and must not be
  // reachable again, or the back button lands on an empty flow.
  return (atStartup || atOnboarding) ? AppRoute.dashboard.path : null;
}

/// Bridges Riverpod's stream to GoRouter's [Listenable] contract.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
