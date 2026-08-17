import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/body_map/presentation/body_map_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/travel/presentation/travel_screen.dart';
import '../../shared/widgets/main_shell.dart';
import 'app_routes.dart';
import 'route_error_screen.dart';

/// Root navigator, used by routes that must cover the bottom navigation bar.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// The application router.
///
/// Exposed through Riverpod so that Phase 2 can add redirect logic driven by
/// app state — sending a first-time user to onboarding, for example — without
/// restructuring anything here.
///
/// The four primary destinations live in a [StatefulShellRoute.indexedStack],
/// so each keeps its own navigation stack. The order of [StatefulShellBranch]
/// entries below must match the destination order in `MainShell`.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.dashboard.path,
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (BuildContext context, GoRouterState state) =>
        RouteErrorScreen(location: state.uri.toString()),
    routes: <RouteBase>[
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
