import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/date_time_format.dart';
import '../../domain/consumable_preset.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// The hour of day the user prefers to make changes.
///
/// Optional, and worth asking because of one specific situation: a sensor
/// fails at 03:17, a new one goes on, and every future change inherits 03:17.
/// BlauLoop offers to move it back to a civilised hour — offers, in Phase 4,
/// and never shifts a date on its own.
///
/// One hour does not fit every product, so under the general time there is a
/// line per timed consumable. Each starts out showing the general time, which
/// is what a user expects to see; only the ones they actually touch are stored
/// against the type. Everything else keeps inheriting, so moving the general
/// time later moves them too.
///
/// This step comes after `durations`, which is what makes the per-consumable
/// list possible: by now the draft knows which consumables were selected.
class ChangeTimeStep extends ConsumerWidget {
  const ChangeTimeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final int? minuteOfDay = draft.preferredChangeMinuteOfDay;
    final List<ConsumablePreset> presets = draft.selectedCyclicPresets;

    return OnboardingStepLayout(
      title: context.l10n.onboardingChangeTimeTitle,
      body: context.l10n.onboardingChangeTimeBody,
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
              minuteOfDay == null
                  ? context.l10n.changeTimeNone
                  : context.formatMinuteOfDay(minuteOfDay),
              style: context.textStyles.titleMedium,
            ),
            subtitle: Text(context.l10n.changeTimeChoose),
            trailing: minuteOfDay == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: context.l10n.changeTimeClear,
                    onPressed: () =>
                        controller.setPreferredChangeMinuteOfDay(null),
                  ),
            onTap: () async {
              final int? picked = await _pickMinuteOfDay(
                context,
                initial: minuteOfDay ?? _defaultMinuteOfDay,
              );
              if (picked != null) {
                controller.setPreferredChangeMinuteOfDay(picked);
              }
            },
          ),
        ),

        // Nothing to fine-tune when nothing counts down. A user who unticked
        // every timed consumable gets the general question and no list.
        if (presets.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              context.l10n.changeTimePerConsumableTitle,
              style: context.textStyles.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.changeTimePerConsumableBody,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final ConsumablePreset preset in presets)
            _ConsumableChangeTimeRow(
              key: Key('${preset.key.name}-change-time'),
              preset: preset,
              effectiveMinuteOfDay: draft.effectiveChangeTimeFor(preset.key),
              isOverridden: draft.changeTimeOverrideFor(preset.key) != null,
              onPick: (int minute) =>
                  controller.setChangeTimeOverride(preset.key, minute),
              onReset: () => controller.setChangeTimeOverride(preset.key, null),
            ),
        ],

        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// Where the time picker opens when there is nothing to open at.
  ///
  /// Evening, because that is when most people change a set — and an initial
  /// value is not a stored answer, so nothing is written unless they confirm.
  static const int _defaultMinuteOfDay = 20 * TimeOfDay.minutesPerHour;
}

/// One consumable's change time: what it will be, and whether that is its own
/// or the general one.
///
/// The state is carried in words as well as in the presence of a button —
/// "follows the general time" versus "its own time" — because a row that
/// differed only by whether a small icon was there would be unreadable to
/// anyone not comparing rows side by side.
class _ConsumableChangeTimeRow extends StatelessWidget {
  const _ConsumableChangeTimeRow({
    required this.preset,
    required this.effectiveMinuteOfDay,
    required this.isOverridden,
    required this.onPick,
    required this.onReset,
    super.key,
  });

  final ConsumablePreset preset;

  /// The time this consumable will actually be changed at: its own where it
  /// has one, the general one otherwise, null when neither is set.
  final int? effectiveMinuteOfDay;

  /// Whether that time is this consumable's own rather than inherited.
  final bool isOverridden;

  final ValueChanged<int> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final String name = preset.key.label(context.l10n);
    final String time = effectiveMinuteOfDay == null
        ? context.l10n.changeTimeNone
        : context.formatMinuteOfDay(effectiveMinuteOfDay!);
    final String state = isOverridden
        ? context.l10n.changeTimeOwnTime
        : context.l10n.changeTimeFollowsGeneral;

    return Semantics(
      container: true,
      button: true,
      label: '$name, $time, $state',
      child: ExcludeSemantics(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name),
          subtitle: Text(state),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(time, style: context.textStyles.titleMedium),
              if (isOverridden)
                IconButton(
                  icon: const Icon(Icons.settings_backup_restore),
                  tooltip: context.l10n.changeTimeResetToGeneral,
                  onPressed: onReset,
                )
              else
                // Keeps every row the same width whether or not it has the
                // reset button, so the times stay in a column instead of
                // jumping sideways as rows are overridden.
                const SizedBox(width: 48),
            ],
          ),
          onTap: () async {
            final int? picked = await _pickMinuteOfDay(
              context,
              initial:
                  effectiveMinuteOfDay ?? ChangeTimeStep._defaultMinuteOfDay,
            );
            if (picked != null) {
              onPick(picked);
            }
          },
        ),
      ),
    );
  }
}

/// Asks for a time of day and returns it as minutes since local midnight.
///
/// Minutes in, minutes out: [TimeOfDay] exists only inside this function, so
/// no caller has to remember which of the two representations it is holding.
Future<int?> _pickMinuteOfDay(
  BuildContext context, {
  required int initial,
}) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: initial ~/ TimeOfDay.minutesPerHour,
      minute: initial % TimeOfDay.minutesPerHour,
    ),
  );
  return picked == null
      ? null
      : picked.hour * TimeOfDay.minutesPerHour + picked.minute;
}
