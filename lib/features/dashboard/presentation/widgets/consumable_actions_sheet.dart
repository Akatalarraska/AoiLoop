import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/cycle_countdown_l10n.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../changes/presentation/register_change_sheet.dart';
import '../../../incidents/presentation/report_incident_sheet.dart';
import '../../domain/dashboard_view.dart';

/// What you can do about one consumable, opened by tapping its circle on Home.
///
/// Two actions, which is the whole list. *I changed it* and *it broke* are the
/// things people open this app to record; anything else is a screen of its
/// own, and a menu padded out with entries that lead nowhere teaches users to
/// stop opening it.
class ConsumableActionsSheet extends StatelessWidget {
  const ConsumableActionsSheet({
    required this.card,
    required this.profile,
    super.key,
  });

  /// Opens the sheet for [card], then whichever action was chosen.
  ///
  /// The action sheet closes before the next one opens, so *back* from the
  /// register-change sheet returns to Home rather than to a menu the user has
  /// already finished with.
  static Future<void> show(
    BuildContext context, {
    required DashboardCard card,
    required UserProfile profile,
  }) async {
    final _ConsumableAction? action =
        await showModalBottomSheet<_ConsumableAction>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext context) =>
              ConsumableActionsSheet(card: card, profile: profile),
        );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _ConsumableAction.registerChange:
        await RegisterChangeSheet.show(context, card: card, profile: profile);
      case _ConsumableAction.reportIncident:
        await ReportIncidentSheet.show(context, card: card, profile: profile);
    }
  }

  final DashboardCard card;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.consumableActionsTitle(card.type.name),
                  style: context.textStyles.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Status and countdown together, so a sheet opened from a
                // circle repeats what the circle said. A menu that dropped the
                // context would leave the user deciding without it.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    StatusChip(status: card.status),
                    Text(
                      card.countdown.label(context.l10n),
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(context.l10n.actionRegisterChange),
            onTap: () =>
                Navigator.of(context).pop(_ConsumableAction.registerChange),
          ),

          // Only where there is something to report a failure against. A type
          // that has never been registered has no instance for an incident to
          // point at, and the subtitle says why rather than leaving a dead
          // row to be tapped at.
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: Text(context.l10n.actionReportIncident),
            subtitle: card.hasStarted
                ? null
                : Text(context.l10n.consumableActionsNothingInUse),
            enabled: card.hasStarted,
            onTap: () =>
                Navigator.of(context).pop(_ConsumableAction.reportIncident),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Which row was tapped. Returned through the navigator rather than acted on
/// in place, so the sheet is closed before the next one opens.
enum _ConsumableAction { registerChange, reportIncident }
