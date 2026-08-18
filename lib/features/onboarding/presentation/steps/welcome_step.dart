import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../widgets/onboarding_step_layout.dart';

/// First step: what the app does, and what it deliberately does not do.
///
/// The medical boundary is stated here rather than buried in an about screen.
/// Someone installing a diabetes app has a right to know within ten seconds
/// whether it is going to tell them what to inject. This one never will.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      title: context.l10n.onboardingWelcomeTitle,
      body: context.l10n.onboardingWelcomeBody,
      children: <Widget>[
        _Note(
          icon: Icons.lock_outline,
          text: context.l10n.onboardingWelcomePrivacy,
        ),
        const SizedBox(height: AppSpacing.md),
        _Note(
          icon: Icons.medical_information_outlined,
          text: context.l10n.medicalDisclaimerShort,
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The sentence beside it carries the meaning, so the icon is not
        // announced separately.
        ExcludeSemantics(
          child: Icon(icon, color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
