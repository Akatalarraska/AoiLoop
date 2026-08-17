/// The kind of hardware a `Device` row describes.
///
/// A device is durable equipment the user owns — as opposed to a consumable,
/// which is used up and replaced on a cycle.
///
/// Stored by name. See `profile_enums.dart` for why.
enum DeviceType {
  /// Insulin pump with tubing and a reservoir.
  pump,

  /// Continuous glucose monitor reader or receiver.
  cgm,

  /// CGM transmitter, where it is a separate part with its own lifetime.
  transmitter,

  /// Fingerstick blood glucose meter.
  meter,

  /// Patch pump controller (for pod systems).
  podController,

  other,
}
