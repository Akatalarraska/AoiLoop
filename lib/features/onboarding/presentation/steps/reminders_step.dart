import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// Reminder lead times, stored as the default for every tracked consumable.
///
/// Phase 5 is what actually schedules them, and the step says so rather than
/// implying the app will start buzzing tonight. Promising a diabetes reminder
/// that does not arrive is worse than promising nothing.
class RemindersStep extends ConsumerWidget {
  const RemindersStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return OnboardingStepLayout(
      title: context.l10n.onboardingRemindersTitle,
      body: context.l10n.onboardingRemindersBody,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final Duration offset
                in OnboardingDraft.availableReminderOffsets)
              FilterChip(
                label: Text(ReminderOffsetL10n.label(offset, context.l10n)),
                selected: draft.reminderOffsets.contains(offset),
                onSelected: (_) => controller.toggleReminderOffset(offset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (draft.reminderOffsets.isEmpty)
          Text(
            context.l10n.onboardingRemindersNone,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.onboardingRemindersLater,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
