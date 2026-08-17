import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../extensions/build_context_x.dart';

/// Chrome around the four primary destinations: Home, Calendar, Body, History.
///
/// Uses GoRouter's [StatefulNavigationShell] so each tab keeps its own
/// navigation stack and scroll position — switching to Calendar and back must
/// not lose where the user was in History.
///
/// The secondary sections (Inventory, Travel, Family, Settings) are reachable
/// from the overflow menu in the app bar rather than the bottom bar. Five or
/// more bottom destinations stop being scannable, and these four are visited
/// occasionally rather than daily.
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on returns to that tab's root,
      // matching platform convention.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_Destination> destinations = _destinationsFor(context);
    final int index = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[index].label),
        actions: <Widget>[
          PopupMenuButton<AppRoute>(
            icon: const Icon(Icons.more_horiz),
            tooltip: context.l10n.moreSectionsTooltip,
            onSelected: (AppRoute route) => context.pushNamed(route.routeName),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<AppRoute>>[
              _menuItem(
                context,
                AppRoute.inventory,
                Icons.inventory_2_outlined,
                context.l10n.sectionInventory,
              ),
              _menuItem(
                context,
                AppRoute.travel,
                Icons.luggage_outlined,
                context.l10n.sectionTravel,
              ),
              _menuItem(
                context,
                AppRoute.family,
                Icons.people_outline,
                context.l10n.sectionFamily,
              ),
              const PopupMenuDivider(),
              _menuItem(
                context,
                AppRoute.settings,
                Icons.settings_outlined,
                context.l10n.sectionSettings,
              ),
            ],
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onDestinationSelected,
        destinations: <Widget>[
          for (final _Destination destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
      ),
    );
  }

  PopupMenuItem<AppRoute> _menuItem(
    BuildContext context,
    AppRoute route,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<AppRoute>(
      value: route,
      child: Row(
        children: <Widget>[
          Icon(icon, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  /// Order must match the branch order in `app_router.dart`.
  List<_Destination> _destinationsFor(BuildContext context) {
    return <_Destination>[
      _Destination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: context.l10n.navHome,
      ),
      _Destination(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: context.l10n.navCalendar,
      ),
      _Destination(
        icon: Icons.accessibility_new,
        selectedIcon: Icons.accessibility_new,
        label: context.l10n.navBody,
      ),
      _Destination(
        icon: Icons.history,
        selectedIcon: Icons.history,
        label: context.l10n.navHistory,
      ),
    ];
  }
}

@immutable
class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
