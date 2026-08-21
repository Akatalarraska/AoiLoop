import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/notification_enums.dart';

/// The words a notification is delivered with.
///
/// Notifications are rendered by the operating system, often days after the
/// app last ran and with no widget tree anywhere. There is no `BuildContext`
/// to read copy from at delivery time, so the text has to be resolved when the
/// reminder is *scheduled* — in the language the profile was created in, not
/// whatever the phone's system language happens to be.
///
/// The date is formatted rather than a countdown for a related reason: a
/// notification sits in the shade until someone looks at it, and "in 6 hours"
/// is a lie by the time it is read. A date stays true.
class ReminderCopy {
  const ReminderCopy({required this.l10n, required this.languageTag});

  /// Loads the copy for a profile's language.
  ///
  /// Falls back to the delegate's own resolution for an unsupported code
  /// rather than throwing: a reminder in the wrong language is a bad day, a
  /// crash while logging a change is a worse one.
  static Future<ReminderCopy> forLanguage(String languageCode) async {
    final Locale locale = AppLocalizations.supportedLocales.firstWhere(
      (Locale candidate) => candidate.languageCode == languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    final String tag = locale.toLanguageTag();

    // Loaded explicitly rather than relying on the widget tree. Inside the app
    // `GlobalMaterialLocalizations` initialises the symbols for whatever
    // locale is being *displayed*, but reminders are written in the language
    // the profile was created in, and the two are not always the same. Without
    // this, formatting a date for the other one throws.
    await initializeDateFormatting(tag);

    return ReminderCopy(
      l10n: await AppLocalizations.delegate.load(locale),
      languageTag: tag,
    );
  }

  final AppLocalizations l10n;
  final String languageTag;

  String get channelName => l10n.notificationChannelName;

  String get channelDescription => l10n.notificationChannelDescription;

  String title(NotificationKind kind, String consumableName) => switch (kind) {
    NotificationKind.cycleDue => l10n.notificationCycleDueTitle(consumableName),
    NotificationKind.expiringSoon => l10n.notificationExpiringSoonTitle(
      consumableName,
    ),
    NotificationKind.expired => l10n.notificationExpiredTitle(consumableName),
    _ => l10n.notificationCycleReminderTitle(consumableName),
  };

  String body(NotificationKind kind, DateTime dueAt) => switch (kind) {
    NotificationKind.cycleDue => l10n.notificationCycleDueBody,
    // A calendar date rather than a date and a time. Expiry is stated on a box
    // to the day, and printing an hour beside it would invent a precision the
    // packaging does not have.
    NotificationKind.expiringSoon => l10n.notificationExpiringSoonBody(
      formatDay(dueAt),
    ),
    NotificationKind.expired => l10n.notificationExpiredBody(formatDay(dueAt)),
    _ => l10n.notificationCycleReminderBody(formatDayAndTime(dueAt)),
  };

  /// A weekday and a date, with no time.
  String formatDay(DateTime instant) =>
      DateFormat.MMMEd(languageTag).format(instant.toLocal());

  /// A weekday, a date and a time in the profile's language and the device's
  /// zone. Matches what `DateTimeFormatX` shows inside the app, so a reminder
  /// and the card it is about never disagree about when something is due.
  String formatDayAndTime(DateTime instant) =>
      DateFormat.MMMEd(languageTag).add_jm().format(instant.toLocal());
}
