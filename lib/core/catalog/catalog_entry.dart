import 'package:flutter/foundation.dart';

import '../../shared/models/consumable_enums.dart';
import '../../shared/models/device_enums.dart';

/// A company whose products BlauLoop knows about.
///
/// Identified by a stable slug rather than by its display name, so a brand
/// that renames itself does not orphan every product filed under it.
@immutable
class CatalogBrand {
  const CatalogBrand({required this.id, required this.name});

  /// Stable slug, e.g. `dexcom`. Never shown.
  final String id;

  /// What the user sees, e.g. `Dexcom`. Not translated: a brand name is the
  /// same word in every language, and translating it would make it
  /// unrecognisable on the box.
  final String name;

  @override
  bool operator ==(Object other) => other is CatalogBrand && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CatalogBrand($id)';
}

/// A device model — a pump, a reader, a pod controller.
///
/// Devices carry no lifetime. A pump is replaced when it breaks or when a
/// warranty runs out, and neither is something BlauLoop can count down to.
@immutable
class CatalogDevice {
  const CatalogDevice({
    required this.brandId,
    required this.name,
    required this.type,
    this.source,
  });

  final String brandId;

  /// Model name as printed, e.g. `t:slim X2`.
  final String name;

  final DeviceType type;

  /// Where the details came from. Present so an entry can be checked rather
  /// than trusted, and absent only where nothing was verified.
  final String? source;
}

/// A consumable product, with the wear time its manufacturer states.
///
/// **The duration is a starting value, never a rule.** It is what the box
/// says; what the user actually gets is their own business, and the durations
/// step exists so they can say so before a single countdown starts. Nothing
/// in BlauLoop treats a catalogue duration as more authoritative than a number
/// the user typed.
///
/// A null [duration] means BlauLoop does not know, not that the product has no
/// wear time. Guessing here would produce a wrong reminder, which is worse
/// than asking — so unknown durations stay unknown and the user fills them in.
@immutable
class CatalogConsumable {
  const CatalogConsumable({
    required this.brandId,
    required this.name,
    required this.category,
    this.duration,
    this.source,
    this.note,
  });

  final String brandId;

  /// Product name as printed, e.g. `FreeStyle Libre 3`.
  final String name;

  final ConsumableCategory category;

  /// Manufacturer-stated wear time, or null when BlauLoop does not know it.
  final Duration? duration;

  /// Where the duration came from, so it can be re-checked.
  final String? source;

  /// Anything unusual worth knowing — a grace period, a warm-up, a part with
  /// a separate lifetime. Shown to the user when present.
  final String? note;

  /// Whether this entry can prefill a duration.
  bool get hasDuration => duration != null;
}
