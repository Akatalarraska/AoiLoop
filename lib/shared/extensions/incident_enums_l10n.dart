import '../../features/incidents/domain/incident_report.dart';
import '../../l10n/generated/app_localizations.dart';
import '../models/change_enums.dart';

/// Localised copy for [IncidentType].
///
/// Lives here rather than on the enum for the same reason every other enum's
/// copy does: `change_enums.dart` is persisted and reasoned about in tests
/// that never build a widget, and it must not drag Flutter in.
///
/// The labels are written in the first person and in the past tense — "it came
/// off", not "detachment" — because this is the user's own account of their
/// day, not a clinical classification of it.
extension IncidentTypeL10n on IncidentType {
  String label(AppLocalizations l10n) => switch (this) {
    IncidentType.detached => l10n.incidentTypeDetached,
    IncidentType.adhesiveFailure => l10n.incidentTypeAdhesiveFailure,
    IncidentType.bentCannula => l10n.incidentTypeBentCannula,
    IncidentType.occlusion => l10n.incidentTypeOcclusion,
    IncidentType.noFlow => l10n.incidentTypeNoFlow,
    IncidentType.leak => l10n.incidentTypeLeak,
    IncidentType.pain => l10n.incidentTypePain,
    IncidentType.bleeding => l10n.incidentTypeBleeding,
    IncidentType.irritation => l10n.incidentTypeIrritation,
    IncidentType.inaccurateReadings => l10n.incidentTypeInaccurateReadings,
    IncidentType.signalLoss => l10n.incidentTypeSignalLoss,
    IncidentType.deviceError => l10n.incidentTypeDeviceError,
    IncidentType.pumpFailure => l10n.incidentTypePumpFailure,
    IncidentType.podFailure => l10n.incidentTypePodFailure,
    IncidentType.other => l10n.incidentTypeOther,
  };
}

/// Localised copy for [IncidentOutcome].
extension IncidentOutcomeL10n on IncidentOutcome {
  String label(AppLocalizations l10n) => switch (this) {
    IncidentOutcome.replaced => l10n.incidentOutcomeReplaced,
    IncidentOutcome.removed => l10n.incidentOutcomeRemoved,
    IncidentOutcome.keptInUse => l10n.incidentOutcomeKeptInUse,
  };
}
