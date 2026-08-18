import '../../../l10n/generated/app_localizations.dart';
import '../domain/consumable_preset.dart';

/// Localised names for the consumable presets.
///
/// These strings are what gets *written* to the database as the name of each
/// `ConsumableType` — see `OnboardingService.complete`. From that moment they
/// are the user's own label: editable, and never retranslated underneath the
/// history that refers to them. Switching the app to another language later
/// renames nothing, which is deliberate.
extension ConsumablePresetKeyL10n on ConsumablePresetKey {
  String label(AppLocalizations l10n) => switch (this) {
    ConsumablePresetKey.cgmSensor => l10n.presetCgmSensor,
    ConsumablePresetKey.cgmTransmitter => l10n.presetCgmTransmitter,
    ConsumablePresetKey.infusionSet => l10n.presetInfusionSet,
    ConsumablePresetKey.reservoir => l10n.presetReservoir,
    ConsumablePresetKey.pod => l10n.presetPod,
    ConsumablePresetKey.insulin => l10n.presetInsulin,
    ConsumablePresetKey.penNeedle => l10n.presetPenNeedle,
    ConsumablePresetKey.testStrip => l10n.presetTestStrip,
    ConsumablePresetKey.ketoneStrip => l10n.presetKetoneStrip,
    ConsumablePresetKey.lancet => l10n.presetLancet,
    ConsumablePresetKey.glucagon => l10n.presetGlucagon,
  };
}

/// Localised copy for reminder lead times.
///
/// A [Duration] is too general a type to hang an extension on, so this is a
/// plain namespace. The five offsets the app offers get their own phrasing
/// because "0 days before" is not a sentence anyone says.
abstract final class ReminderOffsetL10n {
  static String label(Duration offset, AppLocalizations l10n) {
    return switch (offset.inMinutes) {
      0 => l10n.reminderOffsetOnTime,
      60 => l10n.reminderOffsetOneHour,
      360 => l10n.reminderOffsetSixHours,
      1440 => l10n.reminderOffsetOneDay,
      2880 => l10n.reminderOffsetTwoDays,
      _ => l10n.durationDays(offset.inDays),
    };
  }
}
