import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Language, preferred change time, reminder offsets, units, appearance.
/// Built in Phase 2 alongside onboarding, which writes the same profile.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sectionSettings)),
      body: NotBuiltYetView(
        icon: Icons.settings_outlined,
        sectionTitle: context.l10n.sectionSettings,
        availability: context.l10n.notBuiltYetInPhase(2),
      ),
    );
  }
}
