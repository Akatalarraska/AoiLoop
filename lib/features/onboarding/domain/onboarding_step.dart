import '../../../shared/models/profile_enums.dart';
import 'onboarding_draft.dart';

/// The questions onboarding asks, in order.
///
/// Which of them are actually shown depends on the answers so far — see
/// [OnboardingSteps.visibleFor]. The enum is the full catalogue; the list is
/// what a particular user walks through.
enum OnboardingStep {
  /// What the app is for, and what it deliberately is not.
  welcome,

  language,

  /// Name, and optionally birth year and glucose unit.
  profile,

  /// Pump, pod, injections, CGM or not. Everything after this depends on it.
  treatment,

  /// The pump and CGM hardware, if the user wants to record them.
  devices,

  consumables,

  /// How long each selected consumable lasts.
  durations,

  /// The time of day the user prefers to make changes.
  changeTime,

  /// Reminder lead times.
  reminders,

  /// What is about to be created, and the button that creates it.
  summary;

  /// Whether this step can be passed without answering.
  ///
  /// The two that cannot are [profile] — the database needs a name — and
  /// [treatment], which decides the shape of the rest of the flow. Everything
  /// else has a defensible default, and the fastest way to make someone
  /// abandon a health app is to interrogate them before it has done anything
  /// for them.
  bool get isSkippable => switch (this) {
    OnboardingStep.welcome ||
    OnboardingStep.profile ||
    OnboardingStep.treatment ||
    OnboardingStep.summary => false,
    OnboardingStep.language ||
    OnboardingStep.devices ||
    OnboardingStep.consumables ||
    OnboardingStep.durations ||
    OnboardingStep.changeTime ||
    OnboardingStep.reminders => true,
  };
}

/// Which steps a given draft has to walk through.
abstract final class OnboardingSteps {
  /// The visible steps for [draft], in order.
  ///
  /// Steps disappear when they would have nothing to ask: no devices step for
  /// someone on injections without a CGM, no durations, change time or
  /// reminders step when nothing selected has a countdown. An empty step is
  /// not a step, it is an obstacle.
  static List<OnboardingStep> visibleFor(OnboardingDraft draft) {
    final TreatmentType? treatment = draft.treatmentType;

    // Before the treatment question is answered, assume the full journey.
    // The alternative is a progress bar that grows as the user answers, which
    // reads as the flow getting longer the more you do.
    if (treatment == null) {
      return OnboardingStep.values;
    }

    final bool hasDevices = treatment.usesPumpConsumables || treatment.usesCgm;
    final bool hasCyclic = draft.selectedCyclicPresets.isNotEmpty;

    return <OnboardingStep>[
      for (final OnboardingStep step in OnboardingStep.values)
        if (switch (step) {
          OnboardingStep.devices => hasDevices,
          OnboardingStep.durations ||
          OnboardingStep.reminders ||
          OnboardingStep.changeTime => hasCyclic,
          _ => true,
        })
          step,
    ];
  }
}
