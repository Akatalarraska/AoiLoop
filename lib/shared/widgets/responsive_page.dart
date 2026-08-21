import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// A scrolling page that stops growing once the screen gets wide.
///
/// `AppSpacing.pagePadding` has promised "widened on tablets by the responsive
/// helpers" since Phase 0 and there were no such helpers. This is them, and
/// the promise is now true.
///
/// Width is capped rather than padded proportionally. A line of text stops
/// being readable somewhere around 70 characters however much room is going
/// spare, and a countdown card stretched across a tablet reads as a bug rather
/// than as a use of the space.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({required this.children, this.padding, super.key});

  /// The widest a column of content is allowed to get, in logical pixels.
  ///
  /// Roughly 70 characters at the app's body size. Beyond it the extra room
  /// becomes margin, which is what a reader's eye wants rather than a longer
  /// line to track back along.
  static const double maxContentWidth = 560;

  final List<Widget> children;

  /// Overrides the page gutter. Rarely needed: the default is the one every
  /// other screen uses.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top, so a short page on a tall screen does not float in the middle
      // with its heading somewhere near the user's chin.
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: ListView(
          padding: padding ?? AppSpacing.pagePadding,
          children: children,
        ),
      ),
    );
  }
}
