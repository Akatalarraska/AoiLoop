import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/category_icons.dart';
import '../../../../app/theme/status_palette.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/cycle_countdown_l10n.dart';
import '../../../../shared/extensions/cycle_status_l10n.dart';
import '../../domain/dashboard_view.dart';

/// The row of circles at the top of Home: one per tracked consumable, each a
/// way into what you can do about it.
///
/// It exists to put the two common jobs — *I changed it*, *it broke* — one tap
/// from the first screen. The cards below say more, but they say it after a
/// scroll, and the moment someone opens this app is usually the moment
/// something has just happened.
///
/// A circle carries the status on three channels, the same as everywhere else:
/// the ring's colour, the status glyph on its corner, and the countdown in
/// words underneath. The colour is the fastest of the three and the least
/// reliable, which is why it is never the only one.
///
/// It scrolls horizontally and the tiles grow with the text scale rather than
/// clipping, so a 200% setting reflows into a longer row instead of a row of
/// truncated words.
class ConsumableRail extends StatelessWidget {
  const ConsumableRail({required this.cards, required this.onTap, super.key});

  final List<DashboardCard> cards;

  final ValueChanged<DashboardCard> onTap;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // The gutter is applied here rather than by the page, so the row can
          // scroll edge to edge instead of stopping short of it.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            // Tiles keep their own height and the row takes the tallest, so a
            // two-line name next to a one-line name does not stretch either.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final DashboardCard card in cards)
                _ConsumableCircle(
                  key: ValueKey<String>(card.id),
                  card: card,
                  onTap: () => onTap(card),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.dashboardRailHint,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConsumableCircle extends StatelessWidget {
  const _ConsumableCircle({required this.card, required this.onTap, super.key});

  /// The unscaled tile width. Chosen so five fit across a small phone without
  /// scrolling, which is the number of consumables a typical setup tracks.
  static const double _baseWidth = 96;

  /// The ring's diameter. Fixed, because it is a graphic rather than text and
  /// growing it with the font would push the words off the bottom of a row
  /// that has to stay a row.
  static const double _ringSize = 56;

  final DashboardCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StatusVisuals visuals = context.statusPalette.of(card.status);
    final String countdown = card.countdown.label(context.l10n);

    // Widened in step with the text, so the name and the countdown wrap onto
    // more lines rather than being cut off. Capped: past a point a wider tile
    // just means fewer of them are visible, and scrolling to find the sensor
    // is worse than reading it over three lines.
    final double width = MediaQuery.textScalerOf(context)
        .scale(_baseWidth)
        .clamp(_baseWidth, _baseWidth * 2);

    return Semantics(
      button: true,
      container: true,
      label: context.l10n.cardSemanticLabel(
        card.type.name,
        card.status.label(context.l10n),
        countdown,
      ),
      child: SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.cardBorderRadius,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Ring(card: card, visuals: visuals, size: _ringSize),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    card.type.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    countdown,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: card.status.needsAttention
                          ? visuals.color
                          : context.colors.onSurfaceVariant,
                      fontWeight: card.status.needsAttention
                          ? FontWeight.w600
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The category's icon inside a ring in the status colour, with the status
/// glyph on its corner.
///
/// Two icons rather than one because they answer different questions. The
/// middle one says *what this is* and the corner one says *how it is doing*,
/// and collapsing them into a single glyph would lose whichever question the
/// user was asking.
class _Ring extends StatelessWidget {
  const _Ring({required this.card, required this.visuals, required this.size});

  final DashboardCard card;
  final StatusVisuals visuals;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: visuals.container,
              border: Border.all(color: visuals.color, width: 3),
            ),
            child: Center(
              child: Icon(
                CategoryIcons.of(card.type.category),
                size: size * 0.45,
                color: visuals.onContainer,
              ),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The page colour, so the glyph reads as sitting on top of the
                // ring rather than inside it.
                color: context.colors.surface,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Icon(visuals.icon, size: 16, color: visuals.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
