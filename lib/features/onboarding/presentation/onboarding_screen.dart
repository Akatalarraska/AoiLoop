import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../domain/onboarding_step.dart';
import 'onboarding_controller.dart';
import 'onboarding_l10n.dart';
import 'steps/change_time_step.dart';
import 'steps/consumables_step.dart';
import 'steps/devices_step.dart';
import 'steps/durations_step.dart';
import 'steps/language_step.dart';
import 'steps/profile_step.dart';
import 'steps/reminders_step.dart';
import 'steps/summary_step.dart';
import 'steps/treatment_step.dart';
import 'steps/welcome_step.dart';

/// The first-run flow.
///
/// One question per screen, with progress shown, back always available and
/// everything non-essential skippable. The steps themselves are chosen by the
/// answers — see `OnboardingSteps.visibleFor` — so this widget only renders
/// whichever step the controller says is current.
///
/// Nothing navigates away at the end. Submitting writes a profile, the router
/// notices it exists and redirects to the dashboard; that way the same rule
/// decides where the user lands on every launch, including this one.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return PopScope<Object?>(
      // The system back gesture walks the flow backwards rather than leaving
      // it: there is nowhere to leave to until a profile exists.
      canPop: flow.isFirst,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.back();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _ProgressHeader(flow: flow),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.pagePadding,
                  child: _StepBody(step: flow.step),
                ),
              ),
              if (flow.failure != null) const _FailureNotice(),
              _StepControls(flow: flow),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the user is, as a bar and as a sentence.
///
/// The sentence matters: a bar alone tells a screen reader nothing, and
/// "step 3 of 9" is the difference between a flow that feels finite and one
/// that feels endless.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.flow});

  final OnboardingFlow flow;

  @override
  Widget build(BuildContext context) {
    final String counter = context.l10n.onboardingStepCounter(
      flow.index + 1,
      flow.steps.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            label: counter,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: LinearProgressIndicator(value: flow.progress),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  counter,
                  style: context.textStyles.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    // Keyed so that moving between steps rebuilds the subtree instead of
    // reusing the text fields of the step before it.
    return KeyedSubtree(
      key: ValueKey<OnboardingStep>(step),
      child: switch (step) {
        OnboardingStep.welcome => const WelcomeStep(),
        OnboardingStep.language => const LanguageStep(),
        OnboardingStep.profile => const ProfileStep(),
        OnboardingStep.treatment => const TreatmentStep(),
        OnboardingStep.devices => const DevicesStep(),
        OnboardingStep.consumables => const ConsumablesStep(),
        OnboardingStep.durations => const DurationsStep(),
        OnboardingStep.changeTime => const ChangeTimeStep(),
        OnboardingStep.reminders => const RemindersStep(),
        OnboardingStep.summary => const SummaryStep(),
      },
    );
  }
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(Icons.error_outline, color: context.colors.error),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.onboardingFailed,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back, skip and the primary action.
class _StepControls extends ConsumerWidget {
  const _StepControls({required this.flow});

  final OnboardingFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    Future<void> submit() async {
      await controller.submit(
        presetName: (key) => key.label(context.l10n),
        systemLanguageCode: Localizations.localeOf(context).languageCode,
      );
      // Success needs no navigation: writing the profile makes the router
      // redirect. Failure is already on screen above these buttons.
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          if (!flow.isFirst)
            TextButton(
              onPressed: controller.back,
              child: Text(context.l10n.actionBack),
            ),
          const Spacer(),
          if (flow.step.isSkippable)
            TextButton(
              onPressed: controller.next,
              child: Text(context.l10n.actionSkip),
            ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: flow.canAdvance
                ? (flow.isLast ? submit : controller.next)
                : null,
            child: flow.isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_primaryLabel(context, flow)),
          ),
        ],
      ),
    );
  }

  static String _primaryLabel(BuildContext context, OnboardingFlow flow) {
    return switch (flow.step) {
      OnboardingStep.welcome => context.l10n.actionStart,
      OnboardingStep.summary => context.l10n.actionCreateProfile,
      _ => context.l10n.actionContinue,
    };
  }
}
