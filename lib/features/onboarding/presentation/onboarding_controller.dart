import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/locale/locale_providers.dart';
import '../../../core/catalog/brand_model.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/timezone_source.dart';
import '../data/onboarding_service.dart';
import '../domain/consumable_preset.dart';
import '../domain/onboarding_draft.dart';
import '../domain/onboarding_step.dart';

/// Where the user is in onboarding, and what they have answered so far.
@immutable
class OnboardingFlow {
  const OnboardingFlow({
    this.draft = const OnboardingDraft(),
    this.step = OnboardingStep.welcome,
    this.isSubmitting = false,
    this.failure,
  });

  final OnboardingDraft draft;
  final OnboardingStep step;

  /// True while the draft is being written. The finish button waits on it, so
  /// a double tap cannot create two profiles.
  final bool isSubmitting;

  /// Set when the last submit failed. Cleared when another one starts.
  final AppFailure? failure;

  /// The steps this draft has to walk through, which depends on its answers.
  List<OnboardingStep> get steps => OnboardingSteps.visibleFor(draft);

  /// Position of the current step, clamped: a step can stop being visible
  /// after an answer changes, and the flow must not fall off the end.
  int get index {
    final int position = steps.indexOf(step);
    return position < 0 ? 0 : position;
  }

  bool get isFirst => index == 0;
  bool get isLast => index == steps.length - 1;

  /// For the progress bar. Between 0 and 1, never 0 — the first step is
  /// already progress.
  double get progress => (index + 1) / steps.length;

  /// Whether the current step has been answered well enough to move on.
  ///
  /// Only the two unskippable questions can block: a profile needs a name, and
  /// the rest of the flow needs a treatment type.
  bool get canAdvance => switch (step) {
    OnboardingStep.profile => draft.displayName.trim().isNotEmpty,
    OnboardingStep.treatment => draft.treatmentType != null,
    OnboardingStep.summary => draft.isSubmittable && !isSubmitting,
    _ => true,
  };

  OnboardingFlow copyWith({
    OnboardingDraft? draft,
    OnboardingStep? step,
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return OnboardingFlow(
      draft: draft ?? this.draft,
      step: step ?? this.step,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Drives onboarding: holds the draft, moves between steps, and submits.
///
/// Every answer lands here rather than in widget state, for two reasons. The
/// visible steps depend on the answers, so the flow cannot be a fixed
/// `PageView`; and a health app that loses a half-filled form to a rotation is
/// one people do not come back to.
class OnboardingController extends Notifier<OnboardingFlow> {
  @override
  OnboardingFlow build() => const OnboardingFlow();

  void next() {
    final List<OnboardingStep> steps = state.steps;
    if (state.index + 1 < steps.length) {
      state = state.copyWith(step: steps[state.index + 1]);
    }
  }

  void back() {
    if (state.index > 0) {
      state = state.copyWith(step: state.steps[state.index - 1]);
    }
  }

  /// Jumps to a step. Used by the summary, where every line is editable.
  void goTo(OnboardingStep step) {
    if (state.steps.contains(step)) {
      state = state.copyWith(step: step);
    }
  }

  /// Picks the app language, and applies it immediately.
  ///
  /// The change has to be visible in the same frame the user taps it — a
  /// language picker that only takes effect later is indistinguishable from
  /// one that did not work.
  void setLanguage(String languageCode) {
    ref.read(localeOverrideProvider.notifier).set(Locale(languageCode));
    _updateDraft(state.draft.copyWith(languageCode: languageCode));
  }

  void setDisplayName(String value) {
    _updateDraft(state.draft.copyWith(displayName: value));
  }

  void setBirthYear(int? year) {
    _updateDraft(
      state.draft.copyWith(birthYear: year, clearBirthYear: year == null),
    );
  }

  void setGlucoseUnit(GlucoseUnit unit) {
    _updateDraft(state.draft.copyWith(glucoseUnit: unit));
  }

  void setTreatmentType(TreatmentType type) {
    _updateDraft(state.draft.withTreatmentType(type));
  }

  void setPump(DraftDevice device) {
    _updateDraft(state.draft.copyWith(pump: device));
  }

  void setCgm(DraftDevice device) {
    _updateDraft(state.draft.copyWith(cgm: device));
  }

  void toggleConsumable(ConsumablePresetKey key) {
    _updateDraft(state.draft.toggleConsumable(key));
  }

  void setDuration(ConsumablePresetKey key, Duration duration) {
    _updateDraft(state.draft.withDuration(key, duration));
  }

  /// Records which product this consumable actually is.
  ///
  /// [catalogDuration] is the manufacturer's stated wear time when the
  /// catalogue knows it, and null otherwise. The draft writes it as an
  /// ordinary override, so the number moves in front of the user and stays
  /// theirs to change.
  void setProduct(
    ConsumablePresetKey key,
    BrandModel product, {
    Duration? catalogDuration,
  }) {
    _updateDraft(
      state.draft.withProduct(key, product, catalogDuration: catalogDuration),
    );
  }

  /// Minutes since local midnight, or null for no preference.
  void setPreferredChangeMinuteOfDay(int? minuteOfDay) {
    _updateDraft(
      state.draft.copyWith(
        preferredChangeMinuteOfDay: minuteOfDay,
        clearPreferredChangeTime: minuteOfDay == null,
      ),
    );
  }

  void toggleReminderOffset(Duration offset) {
    final List<Duration> next = <Duration>[...state.draft.reminderOffsets];
    if (!next.remove(offset)) {
      next.add(offset);
    }
    _updateDraft(state.draft.copyWith(reminderOffsets: next));
  }

  /// Writes the draft. Returns the new profile, or null if it failed.
  ///
  /// [presetName] comes from the caller because names are localised and this
  /// class has no `BuildContext`. [systemLanguageCode] is the fallback for a
  /// user who skipped the language step.
  Future<UserProfile?> submit({
    required String Function(ConsumablePresetKey key) presetName,
    required String systemLanguageCode,
  }) async {
    if (state.isSubmitting || !state.draft.isSubmittable) {
      return null;
    }
    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      final UserProfile profile = await ref
          .read(onboardingServiceProvider)
          .complete(
            draft: state.draft,
            presetName: presetName,
            timezone: ref.read(timezoneSourceProvider).currentZone(),
            languageCode: systemLanguageCode,
          );
      state = state.copyWith(isSubmitting: false);
      return profile;
    } on Object catch (error, stackTrace) {
      // Nothing was written — the service commits in one transaction — so the
      // draft is still intact and the user can simply try again.
      state = state.copyWith(
        isSubmitting: false,
        failure: StorageFailure(cause: error, stackTrace: stackTrace),
      );
      return null;
    }
  }

  void _updateDraft(OnboardingDraft draft) {
    state = state.copyWith(draft: draft, clearFailure: true);
  }
}

final NotifierProvider<OnboardingController, OnboardingFlow>
onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingFlow>(
      OnboardingController.new,
    );
