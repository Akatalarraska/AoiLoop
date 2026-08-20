import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Language, preferred change time, reminder offsets, units, appearance.
///
/// Phase 2 collects every one of these during onboarding but offers no way to
/// revisit them afterwards, so editing them is Phase 10 work. Until then this
/// screen says so rather than claiming a phase that has already shipped.
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
        availability: context.l10n.notBuiltYetInPhase(10),
      ),
    );
  }
}
