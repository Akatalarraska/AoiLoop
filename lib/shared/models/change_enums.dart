/// Enumerations for change events and incidents.
///
/// Stored by name. See `profile_enums.dart` for why.
library;

/// Why a consumable was changed.
///
/// This is the user's own account of what happened, not a judgement. DT1FLOW
/// records it so history is honest and so manufacturer claims have the facts
/// they need — never to score anyone's routine.
enum ChangeType {
  /// Changed at or near the expected date.
  scheduled,

  /// Changed before the expected date, deliberately. A trip, a shower, a
  /// planned swap — no failure involved.
  early,

  /// Changed because something went wrong. Has an associated `Incident`.
  incident,

  /// Not a real change: the user fixed a date or a detail that was recorded
  /// wrongly. Kept distinct so corrections never pollute failure statistics.
  manualCorrection,
}

/// What went wrong with a consumable.
///
/// These are the categories manufacturers ask about when replacing a failed
/// unit, which is why the list is this specific.
enum IncidentType {
  /// Came off the body.
  detached,

  /// Adhesive lifted or stopped holding.
  adhesiveFailure,

  /// Cannula bent on insertion or in use.
  bentCannula,

  /// Blocked line or cannula.
  occlusion,

  /// Insulin not reaching the body, without a detected occlusion.
  noFlow,

  /// Insulin leaking at the site or connection.
  leak,

  /// Painful site.
  pain,

  /// Bleeding at the site.
  bleeding,

  /// Redness, itching or irritation at the site.
  irritation,

  /// Sensor readings clearly not matching fingersticks.
  inaccurateReadings,

  /// Lost connection between sensor/transmitter and reader.
  signalLoss,

  /// Device reported an error.
  deviceError,

  /// Pump hardware failure.
  pumpFailure,

  /// Pod failure or alarm.
  podFailure,

  other,
}

extension IncidentTypeX on IncidentType {
  /// Whether this kind of failure is normally eligible for a manufacturer
  /// replacement claim.
  ///
  /// A hint for the UI, so DT1FLOW can offer to capture the lot and serial
  /// number while the user still has the packaging. It is not a promise —
  /// every manufacturer has its own policy, and DT1FLOW makes no claim about
  /// what they will accept.
  bool get commonlyClaimable => switch (this) {
    IncidentType.adhesiveFailure ||
    IncidentType.bentCannula ||
    IncidentType.occlusion ||
    IncidentType.noFlow ||
    IncidentType.leak ||
    IncidentType.inaccurateReadings ||
    IncidentType.signalLoss ||
    IncidentType.deviceError ||
    IncidentType.pumpFailure ||
    IncidentType.podFailure => true,
    IncidentType.detached ||
    IncidentType.pain ||
    IncidentType.bleeding ||
    IncidentType.irritation ||
    IncidentType.other => false,
  };

  /// Whether this incident is about the body rather than the hardware.
  ///
  /// Used by the body map to show site reactions separately from device
  /// faults. DT1FLOW reports these; it never interprets them medically.
  bool get isSiteReaction => switch (this) {
    IncidentType.pain ||
    IncidentType.bleeding ||
    IncidentType.irritation => true,
    _ => false,
  };
}
