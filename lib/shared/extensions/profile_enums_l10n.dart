import '../../l10n/generated/app_localizations.dart';
import '../models/profile_enums.dart';

/// Localised copy for [TreatmentType].
///
/// Lives here rather than on the enum so `profile_enums.dart` stays pure Dart:
/// the enum is persisted and reasoned about in tests that never build a
/// widget, and it must not drag Flutter in.
extension TreatmentTypeL10n on TreatmentType {
  String label(AppLocalizations l10n) => switch (this) {
    TreatmentType.pumpAndCgm => l10n.treatmentPumpAndCgm,
    TreatmentType.pumpOnly => l10n.treatmentPumpOnly,
    TreatmentType.podAndCgm => l10n.treatmentPodAndCgm,
    TreatmentType.podOnly => l10n.treatmentPodOnly,
    TreatmentType.injectionsAndCgm => l10n.treatmentInjectionsAndCgm,
    TreatmentType.injectionsOnly => l10n.treatmentInjectionsOnly,
    TreatmentType.other => l10n.treatmentOther,
  };
}

/// Localised copy for [GlucoseUnit].
extension GlucoseUnitL10n on GlucoseUnit {
  String label(AppLocalizations l10n) => switch (this) {
    GlucoseUnit.mgPerDl => l10n.glucoseUnitMgdl,
    GlucoseUnit.mmolPerL => l10n.glucoseUnitMmol,
  };
}
