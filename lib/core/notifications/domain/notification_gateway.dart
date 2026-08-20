import 'package:flutter/foundation.dart';

import '../../../shared/models/notification_enums.dart';

/// One notification, ready to hand to the operating system.
///
/// Carries its text already localised. Notifications are rendered by the OS
/// long after the app that asked for them has been closed, so there is no
/// `BuildContext` to resolve copy against at delivery time — it has to be
/// resolved when the reminder is scheduled, in the language the profile was
/// created in.
@immutable
class PendingNotification {
  const PendingNotification({
    required this.platformId,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  /// The integer handle the platform understands, and the only way to cancel
  /// this later.
  final int platformId;

  final NotificationKind kind;

  /// When it should fire. UTC.
  final DateTime at;

  final String title;
  final String body;

  /// Opaque data returned when the user taps it. Carries the consumable
  /// instance id, so opening a reminder can land on the right thing once
  /// deep links exist.
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is PendingNotification &&
      other.platformId == platformId &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(platformId, kind, at, title, body, payload);

  @override
  String toString() => 'PendingNotification($platformId, $kind at $at)';
}

/// Everything BlauLoop asks of the operating system's notification service.
///
/// This is the seam. Behind it sits a plugin that cannot run in a test and
/// cannot be verified on a machine without a device; in front of it sits all
/// the logic worth testing. Nothing above this interface knows which plugin is
/// in use, and nothing below it knows what a consumable is.
///
/// Every method is best-effort by contract. A denied permission, a revoked
/// one, a platform budget already spent — all of them are ordinary states
/// here, not exceptions. A reminder that cannot be scheduled must never take
/// down the change the user was logging.
abstract interface class NotificationGateway {
  /// Prepares the platform channel. Safe to call more than once.
  ///
  /// Returns false when the platform is not available at all, which is the
  /// normal answer in tests and on unsupported targets.
  Future<bool> initialize();

  /// Asks the user for permission to post notifications.
  ///
  /// Returns whether it was granted. On a platform that grants it implicitly
  /// this returns true without showing anything.
  Future<bool> requestPermission();

  /// Whether the OS will currently deliver anything at all.
  ///
  /// Distinct from [requestPermission]: this asks without prompting, and is
  /// how the app can tell a user their reminders stopped because permission
  /// was revoked in system settings.
  Future<bool> areEnabled();

  /// Registers one notification for future delivery.
  ///
  /// Returns whether the platform accepted it, so the ledger can record a
  /// refusal rather than claiming a reminder exists.
  Future<bool> schedule(PendingNotification notification);

  Future<void> cancel(int platformId);

  Future<void> cancelAll();
}

/// A gateway that accepts everything and delivers nothing.
///
/// Used where notifications are not available — tests that do not care about
/// them, and any platform without an implementation. It reports itself as
/// disabled rather than pretending, so code that checks before scheduling
/// behaves the same way it would against a revoked permission.
class NoopNotificationGateway implements NotificationGateway {
  const NoopNotificationGateway();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> areEnabled() async => false;

  @override
  Future<bool> schedule(PendingNotification notification) async => false;

  @override
  Future<void> cancel(int platformId) async {}

  @override
  Future<void> cancelAll() async {}
}
