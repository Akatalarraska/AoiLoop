/// Enumerations for scheduled local notifications.
///
/// Stored by name. See `profile_enums.dart` for why.
library;

/// What a scheduled notification is about.
enum NotificationKind {
  /// Advance warning before a change is due, at a configured offset.
  cycleReminder,

  /// The expected change date has been reached.
  cycleDue,

  /// The expected change date has passed and nothing was logged.
  cycleOverdue,

  /// An inventory item reached its minimum quantity.
  lowStock,

  /// Stock is approaching its expiry date.
  expiringSoon,
}

/// Where a scheduled notification is in its life.
///
/// AoiLoop tracks this itself rather than trusting the OS, because the two
/// disagree in practice: notifications are dropped when permissions change,
/// silently coalesced, or lost across a reinstall.
enum NotificationStatus {
  /// Handed to the OS and expected to fire.
  pending,

  /// Fired, as far as the app can tell.
  delivered,

  /// Withdrawn before firing — usually because the user logged the change
  /// early, so the reminder is no longer true.
  cancelled,

  /// The OS refused it. Most often the permission was denied or revoked, or
  /// the platform's pending-notification limit was hit.
  failed,
}

extension NotificationStatusX on NotificationStatus {
  /// Whether this row still corresponds to something the OS is holding.
  bool get isScheduled => this == NotificationStatus.pending;
}
