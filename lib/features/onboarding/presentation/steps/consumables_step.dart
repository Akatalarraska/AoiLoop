import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/consumable_preset.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// Which consumables to track, pre-ticked from the treatment answer.
///
/// Only what the treatment certainly involves starts ticked. Everything
/// optional is offered unticked, so the default result is a short dashboard
/// rather than eleven countdowns nobody asked for.
class ConsumablesStep extends ConsumerWidget {
  const ConsumablesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final List<ConsumablePreset> presets = ConsumablePresets.suggestedFor(
      // The step is unreachable before the treatment question is answered.
      draft.treatmentType!,
    );

    return OnboardingStepLayout(
      title: context.l10n.onboardingConsumablesTitle,
      body: context.l10n.onboardingConsumablesBody,
      children: <Widget>[
        for (final ConsumablePreset preset in presets)
          CheckboxListTile(
            value: draft.selectedConsumables.contains(preset.key),
            onChanged: (_) => controller.toggleConsumable(preset.key),
            isThreeLine: preset.key.help(context.l10n) != null,
            title: Text(preset.key.label(context.l10n)),
            subtitle: _Subtitle(preset: preset),
          ),
        if (draft.selectedConsumables.isEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.onboardingConsumablesEmpty,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// What this consumable is, and how long it lasts.
///
/// The explanation comes first and the duration second. Someone reading this
/// screen is deciding *whether they use this thing at all*; the number only
/// matters once they have decided they do.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.preset});

  final ConsumablePreset preset;

  @override
  Widget build(BuildContext context) {
    final String? help = preset.key.help(context.l10n);
    final String duration = preset.tracksCycle
        ? context.l10n.durationDays(preset.defaultDuration!.inDays)
        : context.l10n.presetCountedOnly;

    if (help == null) {
      return Text(duration);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(help),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          duration,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
