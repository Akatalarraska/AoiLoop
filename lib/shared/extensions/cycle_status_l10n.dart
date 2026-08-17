import '../../l10n/generated/app_localizations.dart';
import '../models/cycle_status.dart';

/// Localised copy for [CycleStatus].
///
/// Lives here rather than on the enum itself so `cycle_status.dart` stays pure
/// Dart and unit-testable without a Flutter binding.
extension CycleStatusL10n on CycleStatus {
  String label(AppLocalizations l10n) => switch (this) {
    CycleStatus.healthy => l10n.statusHealthy,
    CycleStatus.dueSoon => l10n.statusDueSoon,
    CycleStatus.dueNow => l10n.statusDueNow,
    CycleStatus.overdue => l10n.statusOverdue,
    CycleStatus.inactive => l10n.statusInactive,
  };

  /// What a screen reader should announce. Prefixed so the status is not
  /// mistaken for the name of the consumable.
  String semanticLabel(AppLocalizations l10n) =>
      l10n.statusSemanticLabel(label(l10n));
}
