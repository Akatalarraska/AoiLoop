import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/status_palette.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/cycle_countdown_l10n.dart';
import '../../../../shared/extensions/cycle_status_l10n.dart';
import '../../../../shared/extensions/date_time_format.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/dashboard_view.dart';

/// One tracked consumable: what it is, how long it has left, and how far
/// through its life it is.
///
/// The status is carried on four channels — the chip's colour, the chip's
/// icon, the chip's text and the countdown phrase itself — so nothing here
/// depends on being able to tell teal from amber. The progress bar is the one
/// element that is colour-only, which is why it is never the only thing
/// saying a card is in trouble.
///
/// The whole card is a single semantics node. Read element by element it would
/// announce a name, a status and a number as three unrelated fragments; read
/// as one sentence it says "CGM sensor. Due soon. 6 hours left."
class CountdownCard extends StatelessWidget {
  const CountdownCard({required this.card, this.onRegisterChange, super.key});

  final DashboardCard card;

  /// Invoked by the card's own action. Null hides it.
  final VoidCallback? onRegisterChange;

  @override
  Widget build(BuildContext context) {
    final StatusVisuals visuals = context.statusPalette.of(card.status);
    final String countdown = card.countdown.label(context.l10n);

    return Semantics(
      container: true,
      label: context.l10n.cardSemanticLabel(
        card.type.name,
        card.status.label(context.l10n),
        countdown,
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(card: card),
                const SizedBox(height: AppSpacing.md),
                Text(
                  countdown,
                  style: context.textStyles.headlineSmall?.copyWith(
                    color: card.status.needsAttention
                        ? visuals.color
                        : context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (card.countdown.progress
                    case final double progress) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: visuals.color,
                      backgroundColor: visuals.container,
                    ),
                  ),
                ],
                if (_detail(context) case final String detail) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    detail,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (onRegisterChange != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onRegisterChange,
                      icon: const Icon(Icons.autorenew),
                      label: Text(context.l10n.actionRegisterChange),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The supporting line under the countdown: when it is due, or failing
  /// that, when the thing in use went on. Null when neither is known, which
  /// is a consumable that has never been registered — the countdown line
  /// already says so and repeating it would be noise.
  String? _detail(BuildContext context) {
    final DateTime? due = card.instance?.expectedChangeAt;
    if (due != null) {
      return context.l10n.cardDueOn(context.formatDayAndTime(due));
    }
    final DateTime? installed = card.instance?.installedAt;
    if (installed != null) {
      return context.l10n.cardInUseSince(context.formatDayAndTime(installed));
    }
    return null;
  }
}

/// Name and status chip, side by side until the text gets big enough that
/// they stop fitting.
class _Header extends StatelessWidget {
  const _Header({required this.card});

  final DashboardCard card;

  @override
  Widget build(BuildContext context) {
    final Widget name = Text(
      card.type.name,
      style: context.textStyles.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    final Widget chip = StatusChip(status: card.status);

    // At a large text scale a row of "Infusion set" plus "Due soon" runs out
    // of width and would ellipsise the one word that matters. Stacking keeps
    // both readable rather than trading one away.
    if (context.prefersLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          name,
          const SizedBox(height: AppSpacing.sm),
          chip,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: name),
        const SizedBox(width: AppSpacing.sm),
        chip,
      ],
    );
  }
}
