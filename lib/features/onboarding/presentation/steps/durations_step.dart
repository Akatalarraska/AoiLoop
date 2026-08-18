import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/consumable_preset.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// How long each tracked consumable lasts.
///
/// Adjusted in whole days, between one and [_maxDays]. Real wear times are not
/// always whole days — a pod is 72 hours plus a grace period — but a first-run
/// screen is the wrong place to ask anyone to think in hours. The schema
/// stores minutes, so a finer editor can arrive later without a migration.
class DurationsStep extends ConsumerWidget {
  const DurationsStep({super.key});

  static const int _minDays = 1;
  static const int _maxDays = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return OnboardingStepLayout(
      title: context.l10n.onboardingDurationsTitle,
      body: context.l10n.onboardingDurationsBody,
      children: <Widget>[
        for (final ConsumablePreset preset in draft.selectedCyclicPresets)
          _DurationRow(
            label: preset.key.label(context.l10n),
            days: draft.durationFor(preset.key)!.inDays,
            onChanged: (int days) => controller.setDuration(
              preset.key,
              Duration(days: days.clamp(_minDays, _maxDays)),
            ),
            canDecrease: draft.durationFor(preset.key)!.inDays > _minDays,
            canIncrease: draft.durationFor(preset.key)!.inDays < _maxDays,
          ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.days,
    required this.onChanged,
    required this.canDecrease,
    required this.canIncrease,
  });

  final String label;
  final int days;
  final ValueChanged<int> onChanged;
  final bool canDecrease;
  final bool canIncrease;

  @override
  Widget build(BuildContext context) {
    final String value = context.l10n.durationDays(days);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.textStyles.bodyLarge)),
          IconButton(
            onPressed: canDecrease ? () => onChanged(days - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: context.l10n.durationShorter,
          ),
          // One live region per consumable: the value is announced when it
          // changes, without repeating the label each time.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: Semantics(
              liveRegion: true,
              label: '$label, $value',
              excludeSemantics: true,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyLarge,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? () => onChanged(days + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: context.l10n.durationLonger,
          ),
        ],
      ),
    );
  }
}
