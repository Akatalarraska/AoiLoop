import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../changes/presentation/register_change_sheet.dart';
import '../domain/dashboard_view.dart';
import 'dashboard_providers.dart';
import 'widgets/countdown_card.dart';
import 'widgets/next_change_card.dart';

/// Home — the centre of the application.
///
/// One question, answered above the fold: *is there anything I need to deal
/// with?* The summary card answers it, the countdown cards below give the
/// detail, and the *Register change* button is the only thing here that is
/// not read-only.
///
/// Countdowns stay correct without the app being restarted. Two mechanisms
/// cover the two ways they go stale: a minute ticker while Home is on screen,
/// and a refresh when the app comes back from the background — where the OS
/// suspends timers, so a phone that spent the night in a drawer would
/// otherwise wake up showing last night's numbers.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Rebuilding the tick stream re-reads the clock immediately, rather
      // than waiting up to a minute for a timer that was frozen anyway.
      onResume: () => ref.invalidate(dashboardTickProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DashboardView> dashboard = ref.watch(dashboardProvider);

    return SafeArea(
      child: dashboard.when(
        loading: () => Center(
          child: Semantics(
            label: context.l10n.loading,
            child: const CircularProgressIndicator.adaptive(),
          ),
        ),
        error: (Object error, StackTrace stackTrace) => _DashboardError(
          onRetry: () => ref.invalidate(cyclicConsumableTypesProvider),
        ),
        data: (DashboardView view) => _DashboardBody(view: view),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.view});

  final DashboardView view;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pagePadding,
      children: <Widget>[
        Text(
          context.l10n.dashboardGreeting(view.profile.displayName),
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (view.isEmpty)
          const _NothingTracked()
        else ...<Widget>[
          NextChangeCard(
            view: view,
            onRegisterChange: () =>
                RegisterChangeSheet.showForView(context, view: view),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AttentionSummary(view: view),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.l10n.dashboardTracking,
            style: context.textStyles.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final DashboardCard card in view.cards)
            CountdownCard(
              key: ValueKey<String>(card.id),
              card: card,
              onRegisterChange: () => RegisterChangeSheet.show(
                context,
                card: card,
                profile: view.profile,
              ),
            ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(
          context.l10n.medicalDisclaimerShort,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One line under the summary: how many things are asking for something.
class _AttentionSummary extends StatelessWidget {
  const _AttentionSummary({required this.view});

  final DashboardView view;

  @override
  Widget build(BuildContext context) {
    final int count = view.needsAttentionCount;

    return Text(
      count == 0
          ? context.l10n.dashboardAllOnTrack
          : context.l10n.dashboardAttentionCount(count),
      style: context.textStyles.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

/// Shown when nothing with a countdown was set up.
///
/// Reachable by anyone who unticked every timed consumable during onboarding.
/// It is honest that the way out — editing what is tracked — is not built
/// yet, rather than offering a button that goes nowhere.
class _NothingTracked extends StatelessWidget {
  const _NothingTracked();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.event_available_outlined,
              size: 56,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.dashboardEmptyTitle,
            style: context.textStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.dashboardEmptyBody,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The read failed. Home is the launch destination, so it offers a way out
/// rather than leaving the user on a blank tab.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 56,
                color: context.colors.onSurfaceVariant,
              ),
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
        ),
      ),
    );
  }
}
