import 'package:flutter/material.dart';

import '../../shared/models/cycle_status.dart';
import 'app_colors.dart';

/// The visual tokens for a single [CycleStatus].
///
/// Note that an [icon] is part of the token set, not an afterthought. AoiLoop
/// must never encode a status in colour alone (colour vision deficiency,
/// greyscale screenshots, high-contrast modes), so every status carries a
/// distinct **shape** as well as a distinct hue. The third channel — a
/// localised text label — comes from `AppLocalizations`.
@immutable
class StatusVisuals {
  const StatusVisuals({
    required this.color,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  /// Strong accent, for icons, borders and progress indicators.
  final Color color;

  /// Soft fill behind a status chip or card.
  final Color container;

  /// Text/icon colour when placed on [container].
  final Color onContainer;

  /// Shape channel. Chosen to be distinguishable in silhouette.
  final IconData icon;

  StatusVisuals copyWith({
    Color? color,
    Color? container,
    Color? onContainer,
    IconData? icon,
  }) {
    return StatusVisuals(
      color: color ?? this.color,
      container: container ?? this.container,
      onContainer: onContainer ?? this.onContainer,
      icon: icon ?? this.icon,
    );
  }

  static StatusVisuals lerp(StatusVisuals a, StatusVisuals b, double t) {
    return StatusVisuals(
      color: Color.lerp(a.color, b.color, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      // Icons cannot be interpolated; snap at the midpoint.
      icon: t < 0.5 ? a.icon : b.icon,
    );
  }
}

/// Maps every [CycleStatus] to its visual tokens for the current brightness.
///
/// Read it through `context.statusPalette` (see `build_context_x.dart`) rather
/// than reaching into [ThemeData.extensions] directly.
@immutable
class StatusPalette extends ThemeExtension<StatusPalette> {
  const StatusPalette({
    required this.healthy,
    required this.dueSoon,
    required this.dueNow,
    required this.overdue,
    required this.inactive,
  });

  final StatusVisuals healthy;
  final StatusVisuals dueSoon;
  final StatusVisuals dueNow;
  final StatusVisuals overdue;
  final StatusVisuals inactive;

  /// Icons are shared across brightnesses — only the colours change.
  static const IconData _healthyIcon = Icons.check_circle_outline;
  static const IconData _dueSoonIcon = Icons.schedule_outlined;
  static const IconData _dueNowIcon = Icons.notifications_active_outlined;
  static const IconData _overdueIcon = Icons.error_outline;
  static const IconData _inactiveIcon = Icons.remove_circle_outline;

  static const StatusPalette light = StatusPalette(
    healthy: StatusVisuals(
      color: AppColors.healthyLight,
      container: AppColors.healthyContainerLight,
      onContainer: AppColors.onHealthyContainerLight,
      icon: _healthyIcon,
    ),
    dueSoon: StatusVisuals(
      color: AppColors.dueSoonLight,
      container: AppColors.dueSoonContainerLight,
      onContainer: AppColors.onDueSoonContainerLight,
      icon: _dueSoonIcon,
    ),
    dueNow: StatusVisuals(
      color: AppColors.dueNowLight,
      container: AppColors.dueNowContainerLight,
      onContainer: AppColors.onDueNowContainerLight,
      icon: _dueNowIcon,
    ),
    overdue: StatusVisuals(
      color: AppColors.overdueLight,
      container: AppColors.overdueContainerLight,
      onContainer: AppColors.onOverdueContainerLight,
      icon: _overdueIcon,
    ),
    inactive: StatusVisuals(
      color: AppColors.inactiveLight,
      container: AppColors.inactiveContainerLight,
      onContainer: AppColors.onInactiveContainerLight,
      icon: _inactiveIcon,
    ),
  );

  static const StatusPalette dark = StatusPalette(
    healthy: StatusVisuals(
      color: AppColors.healthyDark,
      container: AppColors.healthyContainerDark,
      onContainer: AppColors.onHealthyContainerDark,
      icon: _healthyIcon,
    ),
    dueSoon: StatusVisuals(
      color: AppColors.dueSoonDark,
      container: AppColors.dueSoonContainerDark,
      onContainer: AppColors.onDueSoonContainerDark,
      icon: _dueSoonIcon,
    ),
    dueNow: StatusVisuals(
      color: AppColors.dueNowDark,
      container: AppColors.dueNowContainerDark,
      onContainer: AppColors.onDueNowContainerDark,
      icon: _dueNowIcon,
    ),
    overdue: StatusVisuals(
      color: AppColors.overdueDark,
      container: AppColors.overdueContainerDark,
      onContainer: AppColors.onOverdueContainerDark,
      icon: _overdueIcon,
    ),
    inactive: StatusVisuals(
      color: AppColors.inactiveDark,
      container: AppColors.inactiveContainerDark,
      onContainer: AppColors.onInactiveContainerDark,
      icon: _inactiveIcon,
    ),
  );

  /// Visual tokens for [status].
  StatusVisuals of(CycleStatus status) => switch (status) {
    CycleStatus.healthy => healthy,
    CycleStatus.dueSoon => dueSoon,
    CycleStatus.dueNow => dueNow,
    CycleStatus.overdue => overdue,
    CycleStatus.inactive => inactive,
  };

  @override
  StatusPalette copyWith({
    StatusVisuals? healthy,
    StatusVisuals? dueSoon,
    StatusVisuals? dueNow,
    StatusVisuals? overdue,
    StatusVisuals? inactive,
  }) {
    return StatusPalette(
      healthy: healthy ?? this.healthy,
      dueSoon: dueSoon ?? this.dueSoon,
      dueNow: dueNow ?? this.dueNow,
      overdue: overdue ?? this.overdue,
      inactive: inactive ?? this.inactive,
    );
  }

  @override
  StatusPalette lerp(ThemeExtension<StatusPalette>? other, double t) {
    if (other is! StatusPalette) {
      return this;
    }
    return StatusPalette(
      healthy: StatusVisuals.lerp(healthy, other.healthy, t),
      dueSoon: StatusVisuals.lerp(dueSoon, other.dueSoon, t),
      dueNow: StatusVisuals.lerp(dueNow, other.dueNow, t),
      overdue: StatusVisuals.lerp(overdue, other.overdue, t),
      inactive: StatusVisuals.lerp(inactive, other.inactive, t),
    );
  }
}
