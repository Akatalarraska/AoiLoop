import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Interactive body map showing which sites are in use and when each was last
/// used. Built in Phase 7.
///
/// It reports usage; it never prescribes a site.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class BodyMapScreen extends StatelessWidget {
  const BodyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NotBuiltYetView(
      icon: Icons.accessibility_new,
      sectionTitle: context.l10n.navBody,
      availability: context.l10n.notBuiltYetInPhase(7),
    );
  }
}
