import 'package:flutter/foundation.dart';

import '../../../core/catalog/brand_model.dart';
import '../../../shared/models/profile_enums.dart';
import 'consumable_preset.dart';

/// A device the user described during onboarding, before it is written.
///
/// Both fields are free text on purpose. BlauLoop ships no hardware catalogue,
/// and an onboarding flow that cannot cope with a pump it has never heard of
/// is worse than one that simply asks.
@immutable
class DraftDevice {
  const DraftDevice({
    this.manufacturer = '',
    this.model = '',
    this.serialNumber,
    this.brandId,
    this.brandIsCustom = false,
  });

  final String manufacturer;
  final String model;
  final String? serialNumber;

  /// The catalogue brand this came from, or null when it was typed by hand.
  ///
  /// Kept only to drive the picker: what reaches the database is the
  /// manufacturer's name as text, exactly as it would be for a device the
  /// catalogue has never heard of. A row must not become harder to read
  /// because the catalogue happened to know the product.
  final String? brandId;

  /// Whether the user chose "Other" rather than a listed brand.
  final bool brandIsCustom;

  /// Whether there is enough here to write a row.
  ///
  /// The database requires both a manufacturer and a model, so a
  /// half-filled form is treated as "skipped" rather than saved incomplete.
  bool get isUsable =>
      manufacturer.trim().isNotEmpty && model.trim().isNotEmpty;

  bool get isEmpty =>
      manufacturer.trim().isEmpty &&
      model.trim().isEmpty &&
      (serialNumber == null || serialNumber!.trim().isEmpty);

  DraftDevice copyWith({
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? brandId,
    bool? brandIsCustom,
  }) {
    return DraftDevice(
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      brandId: brandId ?? this.brandId,
      brandIsCustom: brandIsCustom ?? this.brandIsCustom,
    );
  }

  /// Replaces the brand and model together.
  ///
  /// A single method rather than two `copyWith` calls, because the two are one
  /// decision: a model picked under one brand means nothing under another, and
  /// changing them separately is how a form ends up claiming a Dexcom t:slim.
  DraftDevice withBrandModel({
    required String? brandId,
    required bool brandIsCustom,
    required String manufacturer,
    required String model,
  }) {
    return DraftDevice(
      manufacturer: manufacturer,
      model: model,
      serialNumber: serialNumber,
      brandId: brandId,
      brandIsCustom: brandIsCustom,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DraftDevice &&
        other.manufacturer == manufacturer &&
        other.model == model &&
        other.serialNumber == serialNumber &&
        other.brandId == brandId &&
        other.brandIsCustom == brandIsCustom;
  }

  @override
  int get hashCode =>
      Object.hash(manufacturer, model, serialNumber, brandId, brandIsCustom);
}

/// Everything onboarding collects, held in memory until it is submitted.
///
/// Nothing is written to the database step by step. A user who abandons
/// onboarding halfway through has not created a profile, half a set of
/// consumable types and an orphaned device — they have created nothing, and
/// the next launch starts them cleanly. The whole draft is committed in one
/// transaction at the end.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.displayName = '',
    this.birthYear,
    this.languageCode,
    this.glucoseUnit = GlucoseUnit.mgPerDl,
    this.treatmentType,
    this.pump = const DraftDevice(),
    this.cgm = const DraftDevice(),
    this.selectedConsumables = const <ConsumablePresetKey>{},
    this.durationOverrides = const <ConsumablePresetKey, Duration>{},
    this.productChoices = const <ConsumablePresetKey, BrandModel>{},
    this.changeTimeOverrides = const <ConsumablePresetKey, int>{},
    this.preferredChangeMinuteOfDay,
    this.reminderOffsets = defaultReminderOffsets,
  });

  /// The lead times offered in the reminders step.
  ///
  /// `Duration.zero` means "when it is due". Phase 5 schedules these; here
  /// they are only recorded as the default for the types being created.
  static const List<Duration> availableReminderOffsets = <Duration>[
    Duration(days: 2),
    Duration(days: 1),
    Duration(hours: 6),
    Duration(hours: 1),
    Duration.zero,
  ];

  /// Ticked by default: one useful warning the day before, and one when the
  /// change is actually due. Enough to be helpful, few enough to stay
  /// credible — a reminder people learn to dismiss is worse than none.
  static const List<Duration> defaultReminderOffsets = <Duration>[
    Duration(days: 1),
    Duration.zero,
  ];

  final String displayName;

  /// Optional, and only a year. See `UserProfiles.birthYear`.
  final int? birthYear;

  /// Null until the user picks one, which means "follow the system".
  final String? languageCode;

  final GlucoseUnit glucoseUnit;

  /// Null until the treatment step is answered. This is the one question the
  /// rest of the flow depends on, and the only reason the draft is not usable
  /// straight away.
  final TreatmentType? treatmentType;

  final DraftDevice pump;
  final DraftDevice cgm;

  final Set<ConsumablePresetKey> selectedConsumables;

  /// Durations the user changed. Anything absent keeps the preset default, so
  /// a skipped durations step is indistinguishable from an accepted one.
  final Map<ConsumablePresetKey, Duration> durationOverrides;

  /// The actual product chosen for each consumable, where one was.
  ///
  /// Optional throughout. Someone who does not know their infusion set by name
  /// — which is most people, most of the time — leaves it blank and gets the
  /// generic label and the generic duration, exactly as before the catalogue
  /// existed.
  final Map<ConsumablePresetKey, BrandModel> productChoices;

  /// Per-consumable change times, as minutes since local midnight.
  ///
  /// Only the ones the user singled out. Anything absent inherits
  /// [preferredChangeMinuteOfDay], and is written to the database as null so
  /// it goes on inheriting it — the same arrangement as [durationOverrides],
  /// where absent means "whatever the default is now", not "no answer".
  final Map<ConsumablePresetKey, int> changeTimeOverrides;

  /// Minutes since local midnight, or null for no preference. The default
  /// every consumable follows unless [changeTimeOverrides] says otherwise.
  final int? preferredChangeMinuteOfDay;

  final List<Duration> reminderOffsets;

  /// Whether the draft can be written.
  ///
  /// A name and a treatment type: everything else in the flow is skippable,
  /// and these two are what the profile row cannot be built without.
  bool get isSubmittable =>
      displayName.trim().isNotEmpty && treatmentType != null;

  /// The selected presets, in catalogue order.
  List<ConsumablePreset> get selectedPresets {
    return ConsumablePresets.all
        .where(
          (ConsumablePreset preset) => selectedConsumables.contains(preset.key),
        )
        .toList(growable: false);
  }

  /// The selected presets that have a countdown — the ones the durations and
  /// reminders steps are about.
  List<ConsumablePreset> get selectedCyclicPresets {
    return selectedPresets
        .where((ConsumablePreset preset) => preset.tracksCycle)
        .toList(growable: false);
  }

  /// The lifetime to persist for [key]: the user's override if they set one,
  /// otherwise the preset default.
  Duration? durationFor(ConsumablePresetKey key) {
    return durationOverrides[key] ??
        ConsumablePresets.byKey(key).defaultDuration;
  }

  /// The change time to **persist** for [key]: the override if the user set
  /// one, otherwise null so the type inherits the profile's.
  ///
  /// Deliberately not the same as [effectiveChangeTimeFor]. This one answers
  /// "what goes in the column", and null is a meaningful value there.
  int? changeTimeOverrideFor(ConsumablePresetKey key) =>
      changeTimeOverrides[key];

  /// The change time to **show** for [key]: the override if there is one,
  /// otherwise the profile-wide preference, otherwise null.
  ///
  /// This is what the onboarding step puts on each line, which is why a user
  /// sees the general time already filled in against every consumable even
  /// though nothing has been written against them.
  int? effectiveChangeTimeFor(ConsumablePresetKey key) =>
      changeTimeOverrides[key] ?? preferredChangeMinuteOfDay;

  /// The product chosen for [key], or an empty selection.
  BrandModel productFor(ConsumablePresetKey key) =>
      productChoices[key] ?? const BrandModel();

  /// The name to store for [key]'s consumable type.
  ///
  /// A named product wins over the generic label, because "Dexcom G7" on a
  /// dashboard card says more than "Glucose sensor (CGM)" — it is what is
  /// printed on the box the user is holding. [fallback] is the localised
  /// preset name, passed in because this class has no `BuildContext`.
  String nameFor(ConsumablePresetKey key, String fallback) {
    final BrandModel product = productFor(key);
    return product.isUsable
        ? '${product.brand.trim()} ${product.model.trim()}'
        : fallback;
  }

  /// Records the product chosen for [key].
  ///
  /// [catalogDuration] is what the manufacturer states, when the catalogue
  /// knows it. It is written as an override so the durations row updates in
  /// front of the user — and stays editable, because the number on the box is
  /// a starting point and not a rule. A null duration leaves whatever was
  /// there: the catalogue not knowing is no reason to discard the user's own
  /// figure.
  OnboardingDraft withProduct(
    ConsumablePresetKey key,
    BrandModel product, {
    Duration? catalogDuration,
  }) {
    final Map<ConsumablePresetKey, BrandModel> products =
        <ConsumablePresetKey, BrandModel>{...productChoices, key: product};

    if (catalogDuration == null) {
      return copyWith(productChoices: products);
    }
    return copyWith(
      productChoices: products,
      durationOverrides: <ConsumablePresetKey, Duration>{
        ...durationOverrides,
        key: catalogDuration,
      },
    );
  }

  /// Adopts a treatment type and, when it actually changed, the default
  /// consumable selection that goes with it.
  ///
  /// Re-selecting the same answer must not wipe choices the user already made
  /// further down the flow, which is why the guard is here rather than in the
  /// widget.
  OnboardingDraft withTreatmentType(TreatmentType type) {
    if (treatmentType == type) {
      return this;
    }
    return copyWith(
      treatmentType: type,
      selectedConsumables: ConsumablePresets.defaultSelectionFor(type),
      durationOverrides: const <ConsumablePresetKey, Duration>{},
    );
  }

  /// Adds or removes one consumable from the selection.
  OnboardingDraft toggleConsumable(ConsumablePresetKey key) {
    final Set<ConsumablePresetKey> next = <ConsumablePresetKey>{
      ...selectedConsumables,
    };
    if (!next.remove(key)) {
      next.add(key);
    }
    return copyWith(selectedConsumables: next);
  }

  OnboardingDraft withDuration(ConsumablePresetKey key, Duration duration) {
    return copyWith(
      durationOverrides: <ConsumablePresetKey, Duration>{
        ...durationOverrides,
        key: duration,
      },
    );
  }

  OnboardingDraft copyWith({
    String? displayName,
    int? birthYear,
    bool clearBirthYear = false,
    String? languageCode,
    GlucoseUnit? glucoseUnit,
    TreatmentType? treatmentType,
    DraftDevice? pump,
    DraftDevice? cgm,
    Set<ConsumablePresetKey>? selectedConsumables,
    Map<ConsumablePresetKey, Duration>? durationOverrides,
    Map<ConsumablePresetKey, BrandModel>? productChoices,
    Map<ConsumablePresetKey, int>? changeTimeOverrides,
    int? preferredChangeMinuteOfDay,
    bool clearPreferredChangeTime = false,
    List<Duration>? reminderOffsets,
  }) {
    return OnboardingDraft(
      displayName: displayName ?? this.displayName,
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      languageCode: languageCode ?? this.languageCode,
      glucoseUnit: glucoseUnit ?? this.glucoseUnit,
      treatmentType: treatmentType ?? this.treatmentType,
      pump: pump ?? this.pump,
      cgm: cgm ?? this.cgm,
      selectedConsumables: selectedConsumables ?? this.selectedConsumables,
      durationOverrides: durationOverrides ?? this.durationOverrides,
      productChoices: productChoices ?? this.productChoices,
      changeTimeOverrides: changeTimeOverrides ?? this.changeTimeOverrides,
      preferredChangeMinuteOfDay: clearPreferredChangeTime
          ? null
          : (preferredChangeMinuteOfDay ?? this.preferredChangeMinuteOfDay),
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OnboardingDraft &&
        other.displayName == displayName &&
        other.birthYear == birthYear &&
        other.languageCode == languageCode &&
        other.glucoseUnit == glucoseUnit &&
        other.treatmentType == treatmentType &&
        other.pump == pump &&
        other.cgm == cgm &&
        setEquals(other.selectedConsumables, selectedConsumables) &&
        mapEquals(other.durationOverrides, durationOverrides) &&
        mapEquals(other.productChoices, productChoices) &&
        mapEquals(other.changeTimeOverrides, changeTimeOverrides) &&
        other.preferredChangeMinuteOfDay == preferredChangeMinuteOfDay &&
        listEquals(other.reminderOffsets, reminderOffsets);
  }

  @override
  int get hashCode => Object.hash(
    displayName,
    birthYear,
    languageCode,
    glucoseUnit,
    treatmentType,
    pump,
    cgm,
    Object.hashAllUnordered(selectedConsumables),
    Object.hashAllUnordered(
      durationOverrides.entries.map(
        (MapEntry<ConsumablePresetKey, Duration> e) =>
            Object.hash(e.key, e.value),
      ),
    ),
    Object.hashAllUnordered(
      productChoices.entries.map(
        (MapEntry<ConsumablePresetKey, BrandModel> e) =>
            Object.hash(e.key, e.value),
      ),
    ),
    Object.hashAllUnordered(
      changeTimeOverrides.entries.map(
        (MapEntry<ConsumablePresetKey, int> e) => Object.hash(e.key, e.value),
      ),
    ),
    preferredChangeMinuteOfDay,
    Object.hashAll(reminderOffsets),
  );
}
