import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Managing another person's profile — typically a child — and the caregivers
/// around them. Built after the MVP, in release 0.2.
///
/// Only the domain shape is prepared during the MVP; nothing here syncs to a
/// server yet.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sectionFamily)),
      body: NotBuiltYetView(
        icon: Icons.people_outline,
        sectionTitle: context.l10n.sectionFamily,
        availability: context.l10n.notBuiltYetAfterMvp('0.2'),
      ),
    );
  }
}
