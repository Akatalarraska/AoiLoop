import '../../core/database/app_database.dart';
import '../../features/history/domain/history_entry.dart';
import '../../features/history/domain/history_view.dart';
import '../../l10n/generated/app_localizations.dart';
import 'incident_enums_l10n.dart';

/// Localised copy for a timeline entry.
///
/// Lives here rather than on the model for the reason every extension in this
/// folder does: the history domain is plain Dart, and its merging and ordering
/// are worth testing without a Flutter binding.
extension HistoryEntryL10n on HistoryEntry {
  /// What happened, in one phrase.
  ///
  /// A change reads as a statement and never as a mark against the user.
  /// *Changed early* is a fact about a date; people change things early for
  /// good reasons, and an app that editorialises is one they stop telling the
  /// truth to.
  String headline(AppLocalizations l10n) => switch (this) {
    ChangeEntry(:final ChangeType reason) => switch (reason) {
      ChangeType.scheduled => l10n.historyChangeScheduled,
      ChangeType.early => l10n.historyChangeEarly,
      ChangeType.incident => l10n.historyChangeIncident,
      ChangeType.manualCorrection => l10n.historyChangeCorrection,
    },
    IncidentEntry(:final IncidentType reason) => reason.label(l10n),
  };
}

/// Localised copy for [HistoryFilter].
extension HistoryFilterL10n on HistoryFilter {
  String label(AppLocalizations l10n) => switch (this) {
    HistoryFilter.everything => l10n.historyFilterEverything,
    HistoryFilter.changes => l10n.historyFilterChanges,
    HistoryFilter.problems => l10n.historyFilterProblems,
  };
}
