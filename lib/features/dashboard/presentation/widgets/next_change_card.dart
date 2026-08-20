import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/status_palette.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/cycle_countdown_l10n.dart';
import '../../../../shared/extensions/date_time_format.dart';
import '../../../../shared/models/cycle_status.dart';
import '../../domain/dashboard_view.dart';

/// The one thing to do next, above everything else on Home.
///
/// Home answers a single question — *is there anything I need to deal with?* —
/// and this card is the answer. It leads with the most urgent consumable
/// rather than the chronologically nearest one, because someone with a sensor
/// two days overdue and a set due tomorrow should be looking at the sensor.
///
/// When nothing is counting down it says so plainly instead of hiding. An
/// empty space where a summary should be reads as an app that has lost track,
/// which is the opposite of what this one is for.
class NextChangeCard extends StatelessWidget {
  const NextChangeCard({
    required this.view,
    required this.onRegisterChange,
    super.key,
  });

  final DashboardView view;
  final VoidCallback onRegisterChange;

  @override
  Widget build(BuildContext context) {
    final DashboardCard? next = view.nextChange;
    final CycleStatus status = next?.status ?? CycleStatus.inactive;
    final StatusVisuals visuals = context.statusPalette.of(status);
    final bool urgent = status.needsAttention;

    return Card(
      // Filled rather than outlined, and tinted by the status, so the answer
      // is legible from arm's length before a single word is read.
      color: urgent ? visuals.container : context.colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _heading(context, next: next, urgent: urgent, visuals: visuals),
            const SizedBox(height: AppSpacing.sm),
            if (next == null)
              Text(
                context.l10n.dashboardNothingScheduledBody,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              )
            else
              _Next(card: next, urgent: urgent, visuals: visuals),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRegisterChange,
                icon: const Icon(Icons.add_task),
                label: Text(context.l10n.actionRegisterChange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(
    BuildContext context, {
    required DashboardCard? next,
    required bool urgent,
    required StatusVisuals visuals,
  }) {
    final String text = switch ((next, urgent)) {
      (null, _) => context.l10n.dashboardNothingScheduled,
      (_, true) => context.l10n.dashboardNeedsAttention,
      (_, false) => context.l10n.dashboardNextChange,
    };

    return Row(
      children: <Widget>[
        // Decorative: the heading text beside it already carries the meaning.
        ExcludeSemantics(
          child: Icon(
            urgent ? visuals.icon : Icons.event_outlined,
            size: 20,
            color: urgent ? visuals.onContainer : context.colors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.labelLarge?.copyWith(
              color: urgent
                  ? visuals.onContainer
                  : context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// The name, the countdown and the date of the most urgent change.
class _Next extends StatelessWidget {
  const _Next({
    required this.card,
    required this.urgent,
    required this.visuals,
  });

  final DashboardCard card;
  final bool urgent;
  final StatusVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final Color onCard = urgent
        ? visuals.onContainer
        : context.colors.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          card.type.name,
          style: context.textStyles.titleLarge?.copyWith(color: onCard),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          card.countdown.label(context.l10n),
          style: context.textStyles.headlineMedium?.copyWith(
            color: onCard,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (card.instance?.expectedChangeAt
            case final DateTime due) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.cardDueOn(context.formatDayAndTime(due)),
            style: context.textStyles.bodyMedium?.copyWith(
              color: urgent ? onCard : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
