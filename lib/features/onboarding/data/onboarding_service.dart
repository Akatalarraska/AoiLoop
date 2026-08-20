import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../consumables/data/consumable_type_repository.dart';
import '../../devices/data/device_repository.dart';
import '../../settings/data/user_profile_repository.dart';
import '../domain/consumable_preset.dart';
import '../domain/onboarding_draft.dart';

/// Turns a finished onboarding draft into rows.
///
/// This is the only place onboarding writes anything. It writes in a single
/// transaction, so a failure halfway through leaves no profile at all rather
/// than a profile with two of its five consumable types — which would look
/// like a completed onboarding on the next launch and quietly skip the rest.
class OnboardingService {
  const OnboardingService({
    required this.db,
    required this.profiles,
    required this.devices,
    required this.types,
  });

  final AppDatabase db;
  final UserProfileRepository profiles;
  final DeviceRepository devices;
  final ConsumableTypeRepository types;

  /// Creates the profile, the devices that were filled in, and one
  /// [ConsumableType] per selected preset.
  ///
  /// [presetName] resolves a preset to its localised name. Names are stored as
  /// plain text because they are the user's own labels from that point on —
  /// editable, and never retranslated underneath the history that references
  /// them.
  ///
  /// [timezone] and [languageCode] come from the caller rather than being read
  /// here: the draft may carry an explicit language choice, and the zone comes
  /// from a source Phase 5 will replace.
  ///
  /// Throws [StateError] if the draft is not submittable, which is a
  /// programming error — the summary step's button is disabled until it is.
  Future<UserProfile> complete({
    required OnboardingDraft draft,
    required String Function(ConsumablePresetKey key) presetName,
    required String timezone,
    required String languageCode,
  }) {
    if (!draft.isSubmittable) {
      throw StateError(
        'Onboarding submitted without a name or a treatment type.',
      );
    }

    return db.transaction(() async {
      final UserProfile profile = await profiles.create(
        displayName: draft.displayName.trim(),
        timezone: timezone,
        languageCode: draft.languageCode ?? languageCode,
        glucoseUnit: draft.glucoseUnit,
        treatmentType: draft.treatmentType!,
        birthYear: draft.birthYear,
        preferredChangeMinuteOfDay: draft.preferredChangeMinuteOfDay,
      );

      if (draft.pump.isUsable) {
        await devices.create(
          userProfileId: profile.id,
          // A pod system has no tubed pump: what the user carries is the
          // controller, and calling it a pump would make the device list lie.
          type: draft.treatmentType!.usesPod
              ? DeviceType.podController
              : DeviceType.pump,
          manufacturer: draft.pump.manufacturer.trim(),
          model: draft.pump.model.trim(),
          serialNumber: _trimToNull(draft.pump.serialNumber),
        );
      }

      if (draft.cgm.isUsable) {
        await devices.create(
          userProfileId: profile.id,
          type: DeviceType.cgm,
          manufacturer: draft.cgm.manufacturer.trim(),
          model: draft.cgm.model.trim(),
          serialNumber: _trimToNull(draft.cgm.serialNumber),
        );
      }

      for (final ConsumablePreset preset in draft.selectedPresets) {
        await types.create(
          // The product the user named, when they named one. "Dexcom G7" on a
          // dashboard card says more than "Glucose sensor (CGM)" — it is what
          // is printed on the box in their hand. The generic label is the
          // fallback, not the preference.
          name: draft.nameFor(preset.key, presetName(preset.key)),
          category: preset.category,
          defaultDuration: preset.tracksCycle
              ? draft.durationFor(preset.key)
              : null,
          tracksCycle: preset.tracksCycle,
          tracksInventory: preset.tracksInventory,
          // Reminder offsets on something with no countdown would never fire.
          defaultReminderOffsets: preset.tracksCycle
              ? draft.reminderOffsets
              : const <Duration>[],
          isBuiltIn: true,
          // The override only, never the profile's own time. Absent here means
          // the type follows the profile, so a user who later moves their
          // general change time moves everything they did not single out.
          preferredChangeMinuteOfDay: preset.tracksCycle
              ? draft.changeTimeOverrideFor(preset.key)
              : null,
        );
      }

      return profile;
    });
  }

  static String? _trimToNull(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final Provider<OnboardingService> onboardingServiceProvider =
    Provider<OnboardingService>((Ref ref) {
      return OnboardingService(
        db: ref.watch(appDatabaseProvider),
        profiles: ref.watch(userProfileRepositoryProvider),
        devices: ref.watch(deviceRepositoryProvider),
        types: ref.watch(consumableTypeRepositoryProvider),
      );
    });
