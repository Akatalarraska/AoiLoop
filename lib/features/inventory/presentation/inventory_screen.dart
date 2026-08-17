import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Supply counts, minimum stock and storage locations. Built in Phase 8.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sectionInventory)),
      body: NotBuiltYetView(
        icon: Icons.inventory_2_outlined,
        sectionTitle: context.l10n.sectionInventory,
        availability: context.l10n.notBuiltYetInPhase(8),
      ),
    );
  }
}
