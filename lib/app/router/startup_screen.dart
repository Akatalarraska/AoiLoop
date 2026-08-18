import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/settings/data/user_profile_repository.dart';
import '../../shared/extensions/build_context_x.dart';
import '../theme/app_spacing.dart';

/// What the app shows while it works out where the user belongs.
///
/// Opening the database and reading the profile takes a frame or two. Without
/// this the first launch flashes the dashboard before redirecting to
/// onboarding, and a returning user gets a flash of onboarding — both of which
/// read as the app losing their data.
///
/// It doubles as the error state for that read, because a failure here is the
/// one failure the rest of the app cannot route around.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile?> profile = ref.watch(primaryProfileProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: profile.hasError
              ? _StartupError(
                  onRetry: () => ref.invalidate(primaryProfileProvider),
                )
              : Semantics(
                  label: context.l10n.loading,
                  child: const CircularProgressIndicator.adaptive(),
                ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.error_outline,
          size: 56,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.genericErrorTitle,
          style: context.textStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.genericErrorBody,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.retry),
        ),
      ],
    );
  }
}
