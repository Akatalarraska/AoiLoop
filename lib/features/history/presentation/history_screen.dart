import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Timeline of changes and incidents, with filters. Built in Phase 9.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NotBuiltYetView(
      icon: Icons.history,
      sectionTitle: context.l10n.navHistory,
      availability: context.l10n.notBuiltYetInPhase(9),
    );
  }
}
