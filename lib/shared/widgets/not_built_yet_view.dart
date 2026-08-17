import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../extensions/build_context_x.dart';

/// Placeholder body for a section whose feature has not been built yet.
///
/// Phase 0 delivers navigation, not features. Rather than ship blank screens,
/// each unimplemented destination says plainly what it is and when it is
/// expected — so the app is honest about its own state and the navigation
/// skeleton is genuinely testable.
///
/// Delete each usage as its phase lands.
class NotBuiltYetView extends StatelessWidget {
  const NotBuiltYetView({
    required this.icon,
    required this.sectionTitle,
    required this.availability,
    super.key,
  });

  final IconData icon;

  /// Already-localised section name.
  final String sectionTitle;

  /// Already-localised sentence saying when this section arrives. Build it
  /// with `l10n.notBuiltYetInPhase(n)` for an MVP phase, or
  /// `l10n.notBuiltYetAfterMvp('0.3')` for post-MVP work.
  final String availability;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Decorative: the heading below carries the meaning, so this is
            // hidden from screen readers rather than announced twice.
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 56,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              sectionTitle,
              style: context.textStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.notBuiltYetTitle,
              style: context.textStyles.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              availability,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
