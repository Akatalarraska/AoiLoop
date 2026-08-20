import '../../l10n/generated/app_localizations.dart';
import '../models/cycle_countdown.dart';

/// Localised copy for [CycleCountdown].
///
/// Lives here rather than on the model for the same reason as
/// `cycle_status_l10n.dart`: `cycle_countdown.dart` is pure Dart, and the
/// arithmetic is worth testing without a Flutter binding.
extension CycleCountdownL10n on CycleCountdown {
  /// The countdown as one short phrase — "3 days left", "8 hours late".
  ///
  /// Always rounds **down**, in both directions. A sensor with 23 hours and 50
  /// minutes left reads "23 hours left", not "1 day left": a countdown that
  /// rounds up is a countdown that tells you there is more time than there
  /// is, and this one is read by people deciding whether to pack a spare.
  ///
  /// The unit follows the magnitude — days, then hours, then minutes — because
  /// "4320 minutes left" is not an answer to any question a person asks.
  String label(AppLocalizations l10n) {
    final Duration? left = remaining;
    if (left == null) {
      return l10n.countdownNothingInUse;
    }

    if (left > Duration.zero) {
      if (left.inDays >= 1) {
        return l10n.countdownDaysLeft(left.inDays);
      }
      if (left.inHours >= 1) {
        return l10n.countdownHoursLeft(left.inHours);
      }
      if (left.inMinutes >= 1) {
        return l10n.countdownMinutesLeft(left.inMinutes);
      }
      return l10n.countdownDueAnyMoment;
    }

    final Duration late = -left;
    if (late.inDays >= 1) {
      return l10n.countdownDaysLate(late.inDays);
    }
    if (late.inHours >= 1) {
      return l10n.countdownHoursLate(late.inHours);
    }
    if (late.inMinutes >= 1) {
      return l10n.countdownMinutesLate(late.inMinutes);
    }
    return l10n.countdownDueAnyMoment;
  }
}
