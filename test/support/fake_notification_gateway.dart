import 'package:blauloop/core/notifications/domain/notification_gateway.dart';

/// A [NotificationGateway] that records instead of delivering.
///
/// The real one cannot run in a test — there is no platform channel — and it
/// is the half of notifications with nothing worth asserting anyway. What
/// matters is *which* reminders the app decides to ask for, and this is what
/// makes that visible.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({
    this.enabled = true,
    this.grantsPermission = true,
    this.refuseFrom,
  });

  /// What [areEnabled] reports. Set false to test a revoked permission.
  bool enabled;

  /// What [requestPermission] returns, and what it sets [enabled] to.
  bool grantsPermission;

  /// Refuse every schedule from this many accepted onwards, standing in for a
  /// platform that has run out of room. Null accepts everything.
  final int? refuseFrom;

  /// Every notification the platform accepted, in the order it was asked.
  ///
  /// A history, not a state: ids are reused between runs, so a reminder can
  /// appear here more than once.
  final List<PendingNotification> scheduled = <PendingNotification>[];

  /// Platform ids passed to [cancel], in order.
  final List<int> cancelled = <int>[];

  int cancelAllCount = 0;
  int permissionRequests = 0;

  /// What the OS is actually holding right now, keyed by platform id.
  ///
  /// Modelled the way the real thing behaves rather than as a filter over the
  /// history: scheduling an id the platform already holds *replaces* it, and
  /// cancelling removes it. BlauLoop reuses ids from 1 on every run, so a
  /// filter would report a freshly scheduled reminder as cancelled.
  final Map<int, PendingNotification> _live = <int, PendingNotification>{};

  /// Everything currently outstanding, soonest first.
  List<PendingNotification> get outstanding =>
      _live.values.toList(growable: false)..sort(
        (PendingNotification a, PendingNotification b) => a.at.compareTo(b.at),
      );

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = grantsPermission;
    return grantsPermission;
  }

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> schedule(PendingNotification notification) async {
    if (refuseFrom != null && scheduled.length >= refuseFrom!) {
      return false;
    }
    scheduled.add(notification);
    _live[notification.platformId] = notification;
    return true;
  }

  @override
  Future<void> cancel(int platformId) async {
    cancelled.add(platformId);
    _live.remove(platformId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    _live.clear();
  }
}
