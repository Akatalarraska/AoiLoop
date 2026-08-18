import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// The shape every onboarding step shares: a heading, a sentence explaining
/// why the question is being asked, then the question itself.
///
/// The explanation is not decoration. Onboarding asks a person with a chronic
/// condition to hand over details about their treatment, and every step that
/// cannot say why it needs something is a step that should not exist.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    required this.title,
    required this.body,
    required this.children,
    super.key,
  });

  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: context.textStyles.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...children,
      ],
    );
  }
}
