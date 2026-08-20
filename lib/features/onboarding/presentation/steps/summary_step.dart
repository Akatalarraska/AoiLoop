import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/date_time_format.dart';
import '../../../../shared/extensions/profile_enums_l10n.dart';
import '../../domain/consumable_preset.dart';
import '../../domain/onboarding_draft.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// The last step: everything about to be written, and a way back to each
/// answer.
///
/// Nothing has touched the database at this point. The whole draft is
/// committed in one transaction when the button below is pressed, so a user
/// who quits here has created nothing at all.
class SummaryStep extends ConsumerWidget {
  const SummaryStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    final OnboardingDraft draft = flow.draft;
    final AppLocalizations l10n = context.l10n;
    final List<OnboardingStep> steps = flow.steps;

    void goTo(OnboardingStep step) =>
        ref.read(onboardingControllerProvider.notifier).goTo(step);

    return OnboardingStepLayout(
      title: l10n.onboardingSummaryTitle,
      body: l10n.onboardingSummaryBody,
      children: <Widget>[
        _SummaryRow(
          label: l10n.fieldName,
          value: draft.displayName.trim(),
          onTap: () => goTo(OnboardingStep.profile),
        ),
        _SummaryRow(
          label: l10n.glucoseUnitLabel,
          value: draft.glucoseUnit.label(l10n),
          onTap: () => goTo(OnboardingStep.profile),
        ),
        _SummaryRow(
          label: l10n.summaryLanguage,
          value: _languageLabel(context, draft.languageCode),
          onTap: () => goTo(OnboardingStep.language),
        ),
        _SummaryRow(
          label: l10n.summaryTreatment,
          value: draft.treatmentType?.label(l10n) ?? l10n.summaryNone,
          onTap: () => goTo(OnboardingStep.treatment),
        ),
        if (steps.contains(OnboardingStep.devices))
          _SummaryRow(
            label: l10n.summaryDevices,
            value: _devicesLabel(draft, l10n),
            onTap: () => goTo(OnboardingStep.devices),
          ),
        _SummaryRow(
          label: l10n.summaryTracking,
          value: _trackingLabel(draft, l10n),
          onTap: () => goTo(OnboardingStep.consumables),
        ),
        if (steps.contains(OnboardingStep.changeTime))
          _SummaryRow(
            label: l10n.summaryChangeTime,
            value: draft.preferredChangeMinuteOfDay == null
                ? l10n.changeTimeNone
                : context.formatMinuteOfDay(draft.preferredChangeMinuteOfDay!),
            onTap: () => goTo(OnboardingStep.changeTime),
          ),
        if (steps.contains(OnboardingStep.reminders))
          _SummaryRow(
            label: l10n.summaryReminders,
            value: draft.reminderOffsets.isEmpty
                ? l10n.onboardingRemindersNone
                : draft.reminderOffsets
                      .map(
                        (Duration offset) =>
                            ReminderOffsetL10n.label(offset, l10n),
                      )
                      .join(', '),
            onTap: () => goTo(OnboardingStep.reminders),
          ),
      ],
    );
  }

  static String _languageLabel(BuildContext context, String? code) {
    final String effective =
        code ?? Localizations.localeOf(context).languageCode;
    return effective == 'es'
        ? context.l10n.languageSpanish
        : context.l10n.languageEnglish;
  }

  static String _devicesLabel(OnboardingDraft draft, AppLocalizations l10n) {
    final List<String> names = <String>[
      for (final DraftDevice device in <DraftDevice>[draft.pump, draft.cgm])
        if (device.isUsable)
          '${device.manufacturer.trim()} ${device.model.trim()}',
    ];
    return names.isEmpty ? l10n.summaryNone : names.join(', ');
  }

  static String _trackingLabel(OnboardingDraft draft, AppLocalizations l10n) {
    if (draft.selectedConsumables.isEmpty) {
      return l10n.summaryNone;
    }
    return draft.selectedPresets
        .map((ConsumablePreset preset) => preset.key.label(l10n))
        .join(', ');
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The row reads as one thing — "Treatment, Pump and CGM" — with the action
    // named in the hint rather than left as an unlabelled pencil icon.
    return Semantics(
      hint: context.l10n.summaryEditSection(label),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: context.textStyles.labelMedium),
        subtitle: Text(value, style: context.textStyles.bodyLarge),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onTap,
      ),
    );
  }
}
