import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/extensions/build_context_x.dart';
import '../theme/app_spacing.dart';
import 'app_routes.dart';

/// Shown when a location cannot be resolved.
///
/// Reachable in practice from a stale deep link or a notification tap after a
/// route rename, so it offers a way out rather than a dead end.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({required this.location, super.key});

  /// The unresolved location. Shown only in debug builds — a URI can carry
  /// record identifiers, and DT1FLOW does not put health data on screen for
  /// no reason.
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.genericErrorTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.genericErrorBody,
                style: context.textStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  location,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.goNamed(AppRoute.dashboard.routeName),
                icon: const Icon(Icons.home_outlined),
                label: Text(context.l10n.navHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
