import 'package:flutter/material.dart';

/// Raw colour constants for DT1FLOW.
///
/// This file answers "which colours exist". It deliberately says nothing about
/// what they mean — that mapping lives in `status_palette.dart`.
///
/// Design intent: calm, modern, non-clinical. Red is reserved strictly for
/// "overdue / problem" and is desaturated so the app never feels alarmist.
/// Every pair below was chosen to clear WCAG AA (4.5:1) for body text against
/// its intended surface.
abstract final class AppColors {
  /// Brand seed. A muted teal — trustworthy without reading as "hospital".
  static const Color seed = Color(0xFF1F7A8C);

  // --- Light scheme status colours ----------------------------------------
  static const Color healthyLight = Color(0xFF1B6B47);
  static const Color healthyContainerLight = Color(0xFFE3F1EA);
  static const Color onHealthyContainerLight = Color(0xFF0F4A30);

  static const Color dueSoonLight = Color(0xFF8A5300);
  static const Color dueSoonContainerLight = Color(0xFFFDF0DC);
  static const Color onDueSoonContainerLight = Color(0xFF5C3800);

  static const Color dueNowLight = Color(0xFFA03E00);
  static const Color dueNowContainerLight = Color(0xFFFDE8DC);
  static const Color onDueNowContainerLight = Color(0xFF6B2A00);

  static const Color overdueLight = Color(0xFFA3231C);
  static const Color overdueContainerLight = Color(0xFFFBE4E2);
  static const Color onOverdueContainerLight = Color(0xFF6E1712);

  static const Color inactiveLight = Color(0xFF5A6470);
  static const Color inactiveContainerLight = Color(0xFFEDEFF2);
  static const Color onInactiveContainerLight = Color(0xFF3C444D);

  // --- Dark scheme status colours -----------------------------------------
  static const Color healthyDark = Color(0xFF6FD3A2);
  static const Color healthyContainerDark = Color(0xFF133427);
  static const Color onHealthyContainerDark = Color(0xFFA8E9C8);

  static const Color dueSoonDark = Color(0xFFE8B563);
  static const Color dueSoonContainerDark = Color(0xFF3A2A0E);
  static const Color onDueSoonContainerDark = Color(0xFFF5D6A0);

  static const Color dueNowDark = Color(0xFFF09C6B);
  static const Color dueNowContainerDark = Color(0xFF3D200F);
  static const Color onDueNowContainerDark = Color(0xFFF8C6A6);

  static const Color overdueDark = Color(0xFFF08279);
  static const Color overdueContainerDark = Color(0xFF3D1714);
  static const Color onOverdueContainerDark = Color(0xFFF8B4AE);

  static const Color inactiveDark = Color(0xFF9AA5B1);
  static const Color inactiveContainerDark = Color(0xFF22282E);
  static const Color onInactiveContainerDark = Color(0xFFC3CBD3);
}
