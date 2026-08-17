import 'package:flutter/material.dart';

import '../../app/theme/status_palette.dart';
import '../../l10n/generated/app_localizations.dart';

/// Short accessors for the things every screen needs.
///
/// Keeps widget code readable and, more importantly, keeps
/// `AppLocalizations.of(context)` as the only way copy reaches the screen.
extension BuildContextX on BuildContext {
  /// Localised copy. Never hardcode user-visible strings in a widget.
  AppLocalizations get l10n => AppLocalizations.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Cycle-status visual tokens for the current brightness.
  ///
  /// Falls back to the light palette rather than throwing, so a theme built
  /// without the extension (an isolated widget test, a preview) still renders.
  StatusPalette get statusPalette =>
      Theme.of(this).extension<StatusPalette>() ?? StatusPalette.light;

  /// True when the user has asked for a noticeably larger font. Layouts should
  /// switch from row to column rather than clip or ellipsise.
  bool get prefersLargeText => MediaQuery.textScalerOf(this).scale(16) > 22;
}
