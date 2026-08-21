import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Locale-aware date formatting for instants read out of the database.
///
/// Every timestamp BlauLoop stores is UTC. Every timestamp it *shows* is local,
/// because a deadline is a moment in the user's day, not in Greenwich — so
/// each helper here converts before formatting rather than trusting the caller
/// to have remembered.
///
/// The locale comes from [Localizations] rather than the system, so a profile
/// created in Spanish keeps Spanish dates on an English phone. The symbol data
/// is loaded by `GlobalMaterialLocalizations`, which every entry point
/// installs through `AppLocalizations.localizationsDelegates`.
extension DateTimeFormatX on BuildContext {
  String get _locale => Localizations.localeOf(this).toLanguageTag();

  /// Read directly rather than through `BuildContextX.l10n`: two extensions
  /// declaring the same member on `BuildContext` makes every call site
  /// ambiguous, and this one is only needed inside this file.
  AppLocalizations get _l10n => AppLocalizations.of(this);

  /// A weekday, a date and a time — "Tue, 25 Aug, 08:00".
  ///
  /// The weekday is included on purpose: "Tuesday" is how someone decides
  /// whether a change lands on a work day, and the bare date is not.
  String formatDayAndTime(DateTime instant) =>
      DateFormat.MMMEd(_locale).add_jm().format(instant.toLocal());

  /// A weekday and a date, with no time of day.
  String formatDay(DateTime instant) =>
      DateFormat.MMMEd(_locale).format(instant.toLocal());

  /// The time of day an instant fell at — "08:15", "8:15 PM".
  ///
  /// Through [MaterialLocalizations] rather than [DateFormat], for the reason
  /// [formatMinuteOfDay] gives: whether to show a 24-hour clock is a device
  /// setting the user chose, not a property of their language.
  String formatTimeOfDay(DateTime instant) {
    return MaterialLocalizations.of(this)
        .formatTimeOfDay(TimeOfDay.fromDateTime(instant.toLocal()));
  }

  /// A wear time in the coarsest unit that stays exact — "10 days", "72
  /// hours" — or the phrase for a consumable that has none.
  ///
  /// Coarsest-but-exact rather than rounded: "3 days" for a 72 hour set is the
  /// same fact more readably, but "3 days" for a 76 hour one is a different
  /// fact, and a wear time the user has to trust is not the place to round.
  String formatDuration(Duration? duration) {
    if (duration == null) {
      return _l10n.settingsDurationNone;
    }
    if (duration.inHours % 24 == 0) {
      return _l10n.settingsDurationDays(duration.inDays);
    }
    return _l10n.settingsDurationHours(duration.inHours);
  }

  /// One reminder lead time, as the settings screen lists it.
  String formatReminderOffset(Duration offset) {
    if (offset == Duration.zero) {
      return _l10n.settingsReminderOnTheDay;
    }
    if (offset.inHours % 24 == 0) {
      return _l10n.settingsReminderOffsetDays(offset.inDays);
    }
    return _l10n.settingsReminderOffsetHours(offset.inHours);
  }

  /// A time of day held as minutes since local midnight — "08:00", "8:00 PM".
  ///
  /// Minutes since midnight rather than an instant because this is a
  /// wall-clock preference, not a moment: 20:00 stays 20:00 on the night the
  /// clocks go back.
  ///
  /// Formatted through [MaterialLocalizations] rather than [DateFormat],
  /// because whether to show a 24-hour clock is a device setting the user
  /// chose, not a property of their language.
  String formatMinuteOfDay(int minuteOfDay) {
    return MaterialLocalizations.of(this).formatTimeOfDay(
      TimeOfDay(
        hour: minuteOfDay ~/ TimeOfDay.minutesPerHour,
        minute: minuteOfDay % TimeOfDay.minutesPerHour,
      ),
    );
  }
}
