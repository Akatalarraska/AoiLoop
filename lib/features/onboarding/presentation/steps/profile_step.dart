import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/profile_enums_l10n.dart';
import '../../../../shared/models/profile_enums.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

/// Name, optional year of birth, and the glucose unit to phrase copy in.
///
/// The name is the only thing onboarding insists on, because the profile row
/// cannot exist without one. The year of birth is asked as a *year*, never a
/// full date: BlauLoop has no use for the rest of it, so it does not collect it.
class ProfileStep extends ConsumerWidget {
  const ProfileStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return OnboardingStepLayout(
      title: context.l10n.onboardingProfileTitle,
      body: context.l10n.onboardingProfileBody,
      children: <Widget>[
        TextFormField(
          initialValue: draft.displayName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: context.l10n.fieldName,
            border: const OutlineInputBorder(),
            helperText: context.l10n.onboardingNameRequired,
          ),
          onChanged: controller.setDisplayName,
        ),
        const SizedBox(height: AppSpacing.lg),

        TextFormField(
          initialValue: draft.birthYear?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: context.l10n.fieldBirthYear,
            border: const OutlineInputBorder(),
            helperText: context.l10n.fieldBirthYearHelp,
            helperMaxLines: 3,
          ),
          // A half-typed year ("19") is not a year, so it is held as "unset"
          // rather than saved and corrected later.
          onChanged: (String value) => controller.setBirthYear(
            value.length == 4 ? int.tryParse(value) : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text(
          context.l10n.glucoseUnitLabel,
          style: context.textStyles.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<GlucoseUnit>(
          segments: <ButtonSegment<GlucoseUnit>>[
            for (final GlucoseUnit unit in GlucoseUnit.values)
              ButtonSegment<GlucoseUnit>(
                value: unit,
                label: Text(unit.label(context.l10n)),
              ),
          ],
          selected: <GlucoseUnit>{draft.glucoseUnit},
          onSelectionChanged: (Set<GlucoseUnit> selection) =>
              controller.setGlucoseUnit(selection.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.glucoseUnitHelp,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
