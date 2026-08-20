import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

/// The hour of day the user prefers to make changes.
///
/// Optional, and worth asking because of one specific situation: a sensor
/// fails at 03:17, a new one goes on, and every future change inherits 03:17.
/// AoiLoop offers to move it back to a civilised hour — offers, in Phase 4,
/// and never shifts a date on its own.
class ChangeTimeStep extends ConsumerWidget {
  const ChangeTimeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? minuteOfDay = ref
        .watch(onboardingControllerProvider)
        .draft
        .preferredChangeMinuteOfDay;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final TimeOfDay? time = minuteOfDay == null
        ? null
        : TimeOfDay(
            hour: minuteOfDay ~/ TimeOfDay.minutesPerHour,
            minute: minuteOfDay % TimeOfDay.minutesPerHour,
          );

    return OnboardingStepLayout(
      title: context.l10n.onboardingChangeTimeTitle,
      body: context.l10n.onboardingChangeTimeBody,
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
              time == null
                  ? context.l10n.changeTimeNone
                  : MaterialLocalizations.of(context).formatTimeOfDay(time),
              style: context.textStyles.titleMedium,
            ),
            subtitle: Text(context.l10n.changeTimeChoose),
            trailing: time == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: context.l10n.changeTimeClear,
                    onPressed: () =>
                        controller.setPreferredChangeMinuteOfDay(null),
                  ),
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: time ?? const TimeOfDay(hour: 20, minute: 0),
              );
              if (picked != null) {
                controller.setPreferredChangeMinuteOfDay(
                  picked.hour * TimeOfDay.minutesPerHour + picked.minute,
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
