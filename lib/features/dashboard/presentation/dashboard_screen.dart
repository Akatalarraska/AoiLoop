import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/models/cycle_status.dart';
import '../../../shared/widgets/status_chip.dart';

/// Home — the centre of the application.
///
/// **Phase 0 placeholder.** Phase 3 replaces the body below with the real
/// dashboard: one countdown card per active consumable, a "next change"
/// summary and the *Register change* call to action.
///
/// What it does carry today is the design contract the real cards will use:
/// the status vocabulary rendered through [StatusChip], so the tri-channel
/// (colour + shape + text) rule is visible and testable from day one.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: <Widget>[
          Text(
            context.l10n.appTagline,
            style: context.textStyles.titleMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Scaffolding, not product copy: a live reference of the status
          // vocabulary. Remove in Phase 3 once real cards exist.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.devStatusVocabulary,
                    style: context.textStyles.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final CycleStatus status in CycleStatus.values)
                        StatusChip(status: status),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(
            context.l10n.medicalDisclaimerShort,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
