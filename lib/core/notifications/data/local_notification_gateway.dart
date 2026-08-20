import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/models/notification_enums.dart';
import '../domain/notification_gateway.dart';

/// The real [NotificationGateway], backed by `flutter_local_notifications`.
///
/// Everything platform-shaped is confined here: channel setup, permission
/// dialogs, the plugin's own types, and the conversion from an absolute
/// instant to the zoned value the plugin insists on. Nothing above this file
/// imports the plugin.
///
/// Nothing here throws. Every method catches and reports failure as a value,
/// because the callers are all in the middle of doing something the user
/// actually asked for — logging a change, opening the app — and a plugin that
/// is unavailable, unpermitted or out of budget must not interrupt that.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    required this.channelName,
    required this.channelDescription,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Android requires every notification to belong to a channel, and shows
  /// this name in system settings as the thing the user can switch off. It is
  /// localised copy, which is why it is injected rather than hardcoded.
  final String channelName;
  final String channelDescription;

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  /// Which platform-specific implementation to talk to.
  ///
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform`, which does
  /// not exist on the web and would stop the whole app compiling there. The
  /// `kIsWeb` guard comes first because on the web that getter reports the
  /// *simulated* platform — Android on an Android browser — and there is no
  /// plugin behind it to resolve.
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The channel every reminder goes to.
  ///
  /// One channel, not one per kind. Android surfaces channels to the user as
  /// individual switches, and offering to turn off "due soon" separately from
  /// "due now" invites someone to disable half a reminder and then wonder why
  /// it never arrived.
  static const String channelId = 'blauloop_cycle_reminders';

  @override
  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }
    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      // Permission is requested later, deliberately: iOS shows its dialog the
      // first time it is asked, and asking during startup — before the user
      // has seen what the app does — is how permission gets denied forever.
      const DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final bool? ready = await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );

      _initialized = ready ?? false;
      return _initialized;
    } on Object catch (error, stackTrace) {
      _report('initialize', error, stackTrace);
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (_isAndroid) {
        final bool? granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        // Null means the platform had no opinion, which on Android below 13
        // is the same as granted: there was no runtime permission to ask for.
        return granted ?? true;
      }
      if (_isIOS) {
        final bool? granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      return false;
    } on Object catch (error, stackTrace) {
      _report('requestPermission', error, stackTrace);
      return false;
    }
  }

  @override
  Future<bool> areEnabled() async {
    try {
      if (_isAndroid) {
        final bool? enabled = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
        return enabled ?? false;
      }
      if (_isIOS) {
        final NotificationsEnabledOptions? options = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        // Alerts specifically, not just "enabled": an app allowed to update a
        // badge and nothing else will never tell anyone their sensor is due.
        return options?.isAlertEnabled ?? false;
      }
      return false;
    } on Object catch (error, stackTrace) {
      _report('areEnabled', error, stackTrace);
      return false;
    }
  }

  @override
  Future<bool> schedule(PendingNotification notification) async {
    try {
      await _plugin.zonedSchedule(
        id: notification.platformId,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        scheduledDate: tz.TZDateTime.from(notification.at.toUtc(), tz.local),
        notificationDetails: _detailsFor(notification.kind),
        // Inexact on purpose. Exact alarms cost either a permission prompt
        // the user has to make sense of (SCHEDULE_EXACT_ALARM) or an app
        // store audit as an alarm-clock app (USE_EXACT_ALARM), and BlauLoop's
        // shortest lead time is an hour. `allowWhileIdle` is the part that
        // matters: without it a phone in Doze overnight delivers nothing.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } on Object catch (error, stackTrace) {
      _report('schedule', error, stackTrace);
      return false;
    }
  }

  @override
  Future<void> cancel(int platformId) async {
    try {
      await _plugin.cancel(id: platformId);
    } on Object catch (error, stackTrace) {
      _report('cancel', error, stackTrace);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } on Object catch (error, stackTrace) {
      _report('cancelAll', error, stackTrace);
    }
  }

  NotificationDetails _detailsFor(NotificationKind kind) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        // The reminder is the whole message; there is nothing to expand.
        styleInformation: const DefaultStyleInformation(false, false),
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  void _report(String operation, Object error, StackTrace stackTrace) {
    // Logged, not thrown, and not shown. What the user needs to know is
    // whether reminders are working at all, which `areEnabled` answers far
    // better than the text of a plugin exception.
    debugPrint('LocalNotificationGateway.$operation failed: $error');
    assert(() {
      debugPrintStack(stackTrace: stackTrace, maxFrames: 6);
      return true;
    }());
  }
}

/// The application-wide gateway.
///
/// Defaults to the no-op implementation. `BlauLoopApp` overrides it with the
/// real one during startup, once the localised channel copy is available —
/// the channel name is what the user sees in system settings, so it cannot be
/// built before a locale is known. Widget tests get the no-op by default,
/// which is what stops a test suite from asking a plugin channel that is not
/// there.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((Ref ref) => const NoopNotificationGateway());
