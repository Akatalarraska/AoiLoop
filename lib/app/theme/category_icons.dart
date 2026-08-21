import 'package:flutter/material.dart';

import '../../shared/models/consumable_enums.dart';

/// The icon that stands for a [ConsumableCategory].
///
/// Lives in the theme rather than on the enum so `consumable_enums.dart` stays
/// pure Dart, and in one place rather than inline in each widget so a sensor
/// looks the same wherever it appears.
///
/// These are recognition aids, never the only thing identifying a consumable.
/// A circle on Home carries this icon *and* the type's own name underneath —
/// the name being the part the user chose, and the only part that is certain
/// to mean something to them. Material has no glyph for an infusion set, so
/// several of these are approximations, and a user who named their own
/// consumable "Sensor Libre" gets the shape they picked the category for and
/// the words they typed.
abstract final class CategoryIcons {
  static IconData of(ConsumableCategory category) => switch (category) {
    ConsumableCategory.cgmSensor => Icons.sensors,
    ConsumableCategory.infusionSet => Icons.settings_input_component,
    ConsumableCategory.cannula => Icons.commit,
    ConsumableCategory.tubing => Icons.cable,
    ConsumableCategory.reservoir => Icons.opacity,
    ConsumableCategory.pod => Icons.album,
    ConsumableCategory.transmitter => Icons.wifi_tethering,
    ConsumableCategory.insulin => Icons.vaccines,
    ConsumableCategory.testStrip => Icons.straighten,
    ConsumableCategory.ketoneStrip => Icons.science,
    ConsumableCategory.lancet => Icons.colorize,
    ConsumableCategory.needle => Icons.vertical_align_bottom,
    ConsumableCategory.glucagon => Icons.medical_services,
    ConsumableCategory.adhesive => Icons.healing,
    ConsumableCategory.battery => Icons.battery_full,
    ConsumableCategory.custom => Icons.category,
  };
}
