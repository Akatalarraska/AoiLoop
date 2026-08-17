import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Trip planning: how much to pack, and what is missing from inventory.
/// Built after the MVP, in release 0.3.
///
/// Its output is a logistics forecast from the user's own settings, never a
/// clinical recommendation.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class TravelScreen extends StatelessWidget {
  const TravelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sectionTravel)),
      body: NotBuiltYetView(
        icon: Icons.luggage_outlined,
        sectionTitle: context.l10n.sectionTravel,
        availability: context.l10n.notBuiltYetAfterMvp('0.3'),
      ),
    );
  }
}
