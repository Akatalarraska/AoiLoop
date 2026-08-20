import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

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

  /// A weekday, a date and a time — "Tue, 25 Aug, 08:00".
  ///
  /// The weekday is included on purpose: "Tuesday" is how someone decides
  /// whether a change lands on a work day, and the bare date is not.
  String formatDayAndTime(DateTime instant) =>
      DateFormat.MMMEd(_locale).add_jm().format(instant.toLocal());

  /// A weekday and a date, with no time of day.
  String formatDay(DateTime instant) =>
      DateFormat.MMMEd(_locale).format(instant.toLocal());
}
