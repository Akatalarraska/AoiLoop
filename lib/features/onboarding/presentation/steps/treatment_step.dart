import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/profile_enums_l10n.dart';
import '../../../../shared/models/profile_enums.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

/// The one question the rest of the flow depends on.
///
/// Answering it decides which consumables are offered, whether a devices step
/// appears at all, and what the dashboard will count down. Changing the answer
/// later resets the consumable selection, which is why this step is not
/// skippable and the summary keeps it one tap away.
class TreatmentStep extends ConsumerWidget {
  const TreatmentStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TreatmentType? selected = ref
        .watch(onboardingControllerProvider)
        .draft
        .treatmentType;

    return OnboardingStepLayout(
      title: context.l10n.onboardingTreatmentTitle,
      body: context.l10n.onboardingTreatmentBody,
      children: <Widget>[
        RadioGroup<TreatmentType>(
          groupValue: selected,
          onChanged: (TreatmentType? value) {
            if (value != null) {
              ref
                  .read(onboardingControllerProvider.notifier)
                  .setTreatmentType(value);
            }
          },
          child: Column(
            children: <Widget>[
              for (final TreatmentType type in TreatmentType.values)
                RadioListTile<TreatmentType>(
                  value: type,
                  title: Text(type.label(context.l10n)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
