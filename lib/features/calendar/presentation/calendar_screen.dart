import 'package:flutter/material.dart';

import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/not_built_yet_view.dart';

/// Calendar of upcoming and completed changes. Built in Phase 9.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NotBuiltYetView(
      icon: Icons.calendar_month_outlined,
      sectionTitle: context.l10n.navCalendar,
      availability: context.l10n.notBuiltYetInPhase(9),
    );
  }
}
