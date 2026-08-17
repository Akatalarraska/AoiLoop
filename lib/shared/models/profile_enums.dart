/// Enumerations describing the person using DT1FLOW.
///
/// All domain enums in DT1FLOW are stored in SQLite **by name**, never by
/// index. Reordering or inserting a value must never silently reinterpret
/// existing rows — in a health log that would rewrite history.
library;

/// The unit the user reads their glucose in.
///
/// DT1FLOW stores no glucose values. This exists so that copy, and any future
/// export, match what the user is used to seeing.
enum GlucoseUnit {
  /// Milligrams per decilitre. Common in the US, Spain, France, Japan.
  mgPerDl,

  /// Millimoles per litre. Common in the UK, Canada, Australia, Nordics.
  mmolPerL,
}

/// How the user delivers insulin and measures glucose.
///
/// Drives which consumables onboarding offers: someone on injections has no
/// infusion sets or reservoirs to track.
enum TreatmentType {
  pumpAndCgm,
  pumpOnly,
  injectionsAndCgm,
  injectionsOnly,

  /// Patch pump (pod) systems, where there is no separate set or tubing.
  podAndCgm,
  podOnly,
  other,
}

extension TreatmentTypeX on TreatmentType {
  /// Whether this treatment involves a pump or pod, and therefore infusion
  /// sets, reservoirs or pods.
  bool get usesPumpConsumables => switch (this) {
    TreatmentType.pumpAndCgm ||
    TreatmentType.pumpOnly ||
    TreatmentType.podAndCgm ||
    TreatmentType.podOnly => true,
    TreatmentType.injectionsAndCgm ||
    TreatmentType.injectionsOnly ||
    TreatmentType.other => false,
  };

  /// Whether this treatment involves a continuous glucose monitor, and
  /// therefore sensors and transmitters.
  bool get usesCgm => switch (this) {
    TreatmentType.pumpAndCgm ||
    TreatmentType.podAndCgm ||
    TreatmentType.injectionsAndCgm => true,
    TreatmentType.pumpOnly ||
    TreatmentType.podOnly ||
    TreatmentType.injectionsOnly ||
    TreatmentType.other => false,
  };

  /// Patch pumps have no separate tubing or infusion set to change.
  bool get usesPod =>
      this == TreatmentType.podAndCgm || this == TreatmentType.podOnly;
}
