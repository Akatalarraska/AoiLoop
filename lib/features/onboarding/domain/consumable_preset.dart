import 'package:flutter/foundation.dart';

import '../../../shared/models/consumable_enums.dart';
import '../../../shared/models/profile_enums.dart';

/// The consumables DT1FLOW knows how to suggest during onboarding.
///
/// A key is *not* the same thing as a [ConsumableCategory]: the category says
/// what kind of object it is, the key identifies one concrete suggestion with
/// its own copy and its own default lifetime. Two presets can share a category
/// — a pod and an infusion set are both worn — and the same category can be
/// offered with different defaults later.
///
/// Keys are also the identity used by the onboarding draft's selections, so
/// they are stable: renaming one changes nothing in the database, because what
/// gets persisted is a localised name and a category, never the key itself.
enum ConsumablePresetKey {
  cgmSensor,
  cgmTransmitter,
  infusionSet,
  reservoir,
  pod,
  insulin,
  penNeedle,
  testStrip,
  ketoneStrip,
  lancet,
  glucagon,
}

/// A suggested consumable, with the defaults DT1FLOW proposes for it.
///
/// The numbers here are *starting points a user can change*, not clinical
/// guidance. Ten days for a sensor and 72 hours for a set are the manufacturer
/// wear times most systems ship with; onboarding shows them, and the durations
/// step exists precisely so anyone whose reality differs can say so before
/// their first countdown starts.
@immutable
class ConsumablePreset {
  const ConsumablePreset({
    required this.key,
    required this.category,
    this.defaultDuration,
    this.tracksInventory = true,
  });

  final ConsumablePresetKey key;
  final ConsumableCategory category;

  /// Expected life. Null means this consumable is counted, not timed — a box
  /// of test strips has no wear cycle.
  final Duration? defaultDuration;

  final bool tracksInventory;

  /// Whether this preset gets a countdown and reminders.
  ///
  /// Derived from [defaultDuration] rather than stored separately: a preset
  /// with a lifetime is timed, one without is not, and keeping the two in
  /// separate fields only creates a state where they disagree.
  bool get tracksCycle => defaultDuration != null;
}

/// The catalogue of suggestions, and the rules for which ones to offer.
///
/// Nothing here is written to the database until onboarding is submitted, and
/// what is written is an ordinary `ConsumableType` row the user can edit or
/// deactivate afterwards. These are defaults, not a fixed product catalogue.
abstract final class ConsumablePresets {
  static const ConsumablePreset cgmSensor = ConsumablePreset(
    key: ConsumablePresetKey.cgmSensor,
    category: ConsumableCategory.cgmSensor,
    defaultDuration: Duration(days: 10),
  );

  static const ConsumablePreset cgmTransmitter = ConsumablePreset(
    key: ConsumablePresetKey.cgmTransmitter,
    category: ConsumableCategory.transmitter,
    defaultDuration: Duration(days: 90),
  );

  static const ConsumablePreset infusionSet = ConsumablePreset(
    key: ConsumablePresetKey.infusionSet,
    category: ConsumableCategory.infusionSet,
    defaultDuration: Duration(days: 3),
  );

  static const ConsumablePreset reservoir = ConsumablePreset(
    key: ConsumablePresetKey.reservoir,
    category: ConsumableCategory.reservoir,
    defaultDuration: Duration(days: 3),
  );

  static const ConsumablePreset pod = ConsumablePreset(
    key: ConsumablePresetKey.pod,
    category: ConsumableCategory.pod,
    defaultDuration: Duration(days: 3),
  );

  /// An opened vial or cartridge, which stops being reliable well before it
  /// runs out. Timed for that reason, and unselected by default because plenty
  /// of people would rather not be reminded about it.
  static const ConsumablePreset insulin = ConsumablePreset(
    key: ConsumablePresetKey.insulin,
    category: ConsumableCategory.insulin,
    defaultDuration: Duration(days: 28),
  );

  static const ConsumablePreset penNeedle = ConsumablePreset(
    key: ConsumablePresetKey.penNeedle,
    category: ConsumableCategory.needle,
  );

  static const ConsumablePreset testStrip = ConsumablePreset(
    key: ConsumablePresetKey.testStrip,
    category: ConsumableCategory.testStrip,
  );

  static const ConsumablePreset ketoneStrip = ConsumablePreset(
    key: ConsumablePresetKey.ketoneStrip,
    category: ConsumableCategory.ketoneStrip,
  );

  static const ConsumablePreset lancet = ConsumablePreset(
    key: ConsumablePresetKey.lancet,
    category: ConsumableCategory.lancet,
  );

  static const ConsumablePreset glucagon = ConsumablePreset(
    key: ConsumablePresetKey.glucagon,
    category: ConsumableCategory.glucagon,
  );

  /// Every preset, in the order onboarding lists them: timed items first,
  /// because those are what the app is actually for.
  static const List<ConsumablePreset> all = <ConsumablePreset>[
    cgmSensor,
    cgmTransmitter,
    pod,
    infusionSet,
    reservoir,
    insulin,
    penNeedle,
    testStrip,
    ketoneStrip,
    lancet,
    glucagon,
  ];

  static ConsumablePreset byKey(ConsumablePresetKey key) {
    return all.firstWhere((ConsumablePreset preset) => preset.key == key);
  }

  /// The presets worth showing for a treatment, in list order.
  ///
  /// Someone on injections has no infusion sets to track, and showing them a
  /// reservoir picker is how an onboarding flow starts feeling like paperwork.
  /// [TreatmentType.other] gets everything, because the app cannot guess.
  static List<ConsumablePreset> suggestedFor(TreatmentType treatment) {
    return all
        .where((ConsumablePreset preset) => _applies(preset.key, treatment))
        .toList(growable: false);
  }

  /// What is ticked when the consumables step first appears.
  ///
  /// Only the things the treatment certainly involves. Anything optional —
  /// a transmitter, an insulin countdown, glucagon — is offered unticked, so
  /// the default outcome is a short dashboard rather than a wall of
  /// countdowns nobody asked for.
  static Set<ConsumablePresetKey> defaultSelectionFor(TreatmentType treatment) {
    final bool tubedPump = treatment.usesPumpConsumables && !treatment.usesPod;
    final bool injects =
        !treatment.usesPumpConsumables && treatment != TreatmentType.other;

    return <ConsumablePresetKey>{
      if (treatment.usesCgm) ConsumablePresetKey.cgmSensor,
      if (treatment.usesPod) ConsumablePresetKey.pod,
      if (tubedPump) ConsumablePresetKey.infusionSet,
      if (tubedPump) ConsumablePresetKey.reservoir,
      if (injects) ConsumablePresetKey.penNeedle,
      ConsumablePresetKey.testStrip,
      ConsumablePresetKey.lancet,
    };
  }

  static bool _applies(ConsumablePresetKey key, TreatmentType treatment) {
    if (treatment == TreatmentType.other) {
      return true;
    }
    return switch (key) {
      ConsumablePresetKey.cgmSensor ||
      ConsumablePresetKey.cgmTransmitter => treatment.usesCgm,
      ConsumablePresetKey.pod => treatment.usesPod,
      ConsumablePresetKey.infusionSet || ConsumablePresetKey.reservoir =>
        treatment.usesPumpConsumables && !treatment.usesPod,
      ConsumablePresetKey.penNeedle => !treatment.usesPumpConsumables,
      ConsumablePresetKey.insulin ||
      ConsumablePresetKey.testStrip ||
      ConsumablePresetKey.ketoneStrip ||
      ConsumablePresetKey.lancet ||
      ConsumablePresetKey.glucagon => true,
    };
  }
}
