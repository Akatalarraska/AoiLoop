import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/notifications/data/local_notification_gateway.dart';
import '../../core/notifications/data/reminder_copy.dart';
import '../../core/notifications/domain/notification_gateway.dart';
import '../../core/utils/timezone_source.dart';

/// Everything that has to happen against the platform before the first frame.
///
/// Two things, both of which need a plugin channel and neither of which can be
/// done lazily from inside a widget: loading the time zone database, and
/// preparing the notification channel. They are done here, once, and handed to
/// the app as provider overrides — which is also what keeps them out of tests,
/// where the same providers are overridden with fakes instead.
///
/// Nothing here can stop the app starting. Every step is guarded, because the
/// worst outcome of a failure is an app with no reminders and an approximate
/// time zone, and the worst outcome of an unguarded failure is a black screen
/// in front of someone trying to check when their sensor is due.
Future<List<Override>> bootstrapApp() async {
  final List<Override> overrides = <Override>[];

  final String? zone = await _loadTimeZones();
  if (zone != null) {
    overrides.add(
      timezoneSourceProvider.overrideWithValue(
        PlatformTimezoneSource(zone: zone),
      ),
    );
  }

  final NotificationGateway? gateway = await _prepareNotifications();
  if (gateway != null) {
    overrides.add(notificationGatewayProvider.overrideWithValue(gateway));
  }

  return overrides;
}

/// Loads the IANA database and points `tz.local` at the device's zone.
///
/// Returns the zone name, or null if the platform could not be asked. The
/// database has to be loaded before anything converts an instant for
/// scheduling, which is why it happens here rather than on first use.
Future<String?> _loadTimeZones() async {
  try {
    tz_data.initializeTimeZones();
    final String name = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(name));
    return name;
  } on Object catch (error) {
    // `tz.local` stays UTC, which is wrong by up to a day for scheduling but
    // never crashes. The stored zone stays whatever Dart alone could work out.
    debugPrint('Time zone bootstrap failed: $error');
    return null;
  }
}

/// Builds and initialises the real notification gateway.
///
/// The Android channel is named in the **system** language rather than the
/// profile's. It appears in the phone's own settings, beside every other app's
/// channels, and there is no profile to read a language from this early
/// anyway. The reminders themselves are a different matter: those are
/// resolved per reminder, in the language the profile was created in.
Future<NotificationGateway?> _prepareNotifications() async {
  try {
    final ReminderCopy copy = await ReminderCopy.forLanguage(
      PlatformDispatcher.instance.locale.languageCode,
    );
    final LocalNotificationGateway gateway = LocalNotificationGateway(
      channelName: copy.channelName,
      channelDescription: copy.channelDescription,
    );
    await gateway.initialize();
    return gateway;
  } on Object catch (error) {
    // The no-op gateway stays in place and reports itself as disabled, which
    // is what puts the "reminders are off" banner on Home — an honest answer.
    debugPrint('Notification bootstrap failed: $error');
    return null;
  }
}
