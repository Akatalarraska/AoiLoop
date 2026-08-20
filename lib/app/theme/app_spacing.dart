import 'package:flutter/material.dart';

/// A 4pt spacing scale, plus a few layout constants that accessibility
/// depends on.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Minimum tappable edge. 48dp satisfies both the Material and the
  /// iOS (44pt) guidance, so AoiLoop uses the stricter of the two.
  static const double minTapTarget = 48;

  /// Corner radius for cards and sheets. Soft, not playful.
  static const Radius cardRadius = Radius.circular(16);
  static const BorderRadius cardBorderRadius = BorderRadius.all(cardRadius);

  /// Page gutter. Widened on tablets by the responsive helpers.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
}
