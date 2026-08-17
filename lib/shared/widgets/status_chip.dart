import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_palette.dart';
import '../extensions/build_context_x.dart';
import '../extensions/cycle_status_l10n.dart';
import '../models/cycle_status.dart';

/// The canonical way to render a [CycleStatus].
///
/// Encodes the status on three independent channels so no single perceptual
/// difference is load-bearing:
///
/// 1. **Colour** — from [StatusPalette].
/// 2. **Shape** — a distinct icon silhouette.
/// 3. **Text** — a localised label.
///
/// The whole chip is a single semantics node with an explicit label, so
/// TalkBack and VoiceOver announce "Status: due soon" rather than reading an
/// icon and a word as two unrelated fragments.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, this.showLabel = true, super.key});

  final CycleStatus status;

  /// When false, only the icon is drawn — for dense rows where the label is
  /// already present nearby. The semantics label is kept either way.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final StatusVisuals visuals = context.statusPalette.of(status);
    final String label = status.label(context.l10n);

    return Semantics(
      label: status.semanticLabel(context.l10n),
      excludeSemantics: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.container,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          // A border keeps the chip legible in forced high-contrast modes,
          // where background fills are sometimes dropped.
          border: Border.all(color: visuals.color, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? AppSpacing.sm : AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(visuals.icon, size: 16, color: visuals.onContainer),
              if (showLabel) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: context.textStyles.labelMedium?.copyWith(
                    color: visuals.onContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
