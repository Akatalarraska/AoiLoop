import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 relative luminance and contrast ratio.
///
/// AoiLoop asserts contrast in tests rather than eyeballing it, because the
/// status palette is the one place where a well-meaning colour tweak can push
/// text below legibility for a user with reduced vision — and nothing else in
/// the build would notice.
double relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between two opaque colours, from 1.0 to 21.0.
double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA minimum for body text.
const double wcagAaNormalText = 4.5;

/// WCAG AA minimum for large text and for graphical objects such as icons
/// and borders.
const double wcagAaLargeText = 3.0;
