/// Enumerations for consumables — the things that get used up and replaced.
///
/// Stored by name. See `profile_enums.dart` for why.
library;

/// What kind of thing a consumable type is.
///
/// The category drives defaults and grouping, not behaviour: whether something
/// has a wear cycle or is counted in inventory is decided per type by
/// `tracksCycle` and `tracksInventory`, because the same category behaves
/// differently between products.
enum ConsumableCategory {
  /// CGM sensor.
  cgmSensor,

  /// Infusion set — the whole assembly.
  infusionSet,

  /// Cannula, where it is changed independently of the tubing.
  cannula,

  /// Tubing, where it is changed independently of the cannula.
  tubing,

  /// Pump reservoir or cartridge.
  reservoir,

  /// Patch pump.
  pod,

  /// CGM transmitter, treated as a consumable when it has a fixed lifetime.
  transmitter,

  /// Insulin vial, cartridge or pen.
  insulin,

  /// Blood glucose test strip.
  testStrip,

  /// Ketone test strip.
  ketoneStrip,

  /// Lancet for fingersticks.
  lancet,

  /// Pen needle or syringe.
  needle,

  /// Emergency glucagon.
  glucagon,

  /// Overpatch, tape or adhesive spray.
  adhesive,

  /// Battery for a pump, meter or transmitter.
  battery,

  /// Anything the user defines themselves.
  custom,
}

/// Where a specific installed consumable is in its life.
enum ConsumableStatus {
  /// Currently in use. At most one active instance exists per consumable type
  /// per profile.
  active,

  /// Ran its full expected life and was replaced on schedule.
  completed,

  /// Taken off before its expected change date, for any reason. The reason,
  /// if there was one worth recording, lives in the linked `Incident`.
  removedEarly,

  /// Never used: dropped, expired on the shelf, failed on insertion.
  discarded,
}

extension ConsumableStatusX on ConsumableStatus {
  /// Whether this instance is still on the body / in the pump.
  bool get isOpen => this == ConsumableStatus.active;

  /// Whether this instance consumed a unit from inventory. A discarded item
  /// still left the cupboard, so it counts.
  bool get consumedStock => true;
}
