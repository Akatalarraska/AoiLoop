import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/data/notification_scheduler.dart';
import '../../consumables/data/consumable_type_repository.dart';
import '../data/user_profile_repository.dart';

/// Writes the answers the settings screen collects.
///
/// One place rather than a write scattered through each tile, because several
/// of these have a consequence beyond the row they change: a duration or a set
/// of offsets moves when the operating system will speak, and a reminder set
/// that no longer matches the database is exactly the failure the notification
/// ledger exists to prevent.
///
/// Nothing here throws at the caller. A settings write that fails leaves the
/// stored value alone, and the screen reads back from the database rather than
/// from anything it hoped it had written.
class SettingsController {
  const SettingsController({
    required this.profiles,
    required this.types,
    required this.reminders,
    required this.profileId,
  });

  final UserProfileRepository profiles;
  final ConsumableTypeRepository types;

  /// Rebuilt after anything that changes when a reminder should fire.
  final NotificationScheduler? reminders;

  final String? profileId;

  Future<void> setName(String name) async {
    final String? id = profileId;
    if (id == null) {
      return;
    }
    await profiles.update(
      id,
      UserProfilesCompanion(displayName: Value<String>(name)),
    );
  }

  Future<void> setLanguage(String languageCode) async {
    final String? id = profileId;
    if (id == null) {
      return;
    }
    await profiles.update(
      id,
      UserProfilesCompanion(languageCode: Value<String>(languageCode)),
    );
  }

  Future<void> setUnit(GlucoseUnit unit) async {
    final String? id = profileId;
    if (id == null) {
      return;
    }
    await profiles.update(
      id,
      UserProfilesCompanion(glucoseUnit: Value<GlucoseUnit>(unit)),
    );
  }

  /// Sets the profile-wide preferred change time, or clears it.
  ///
  /// No reminder rebuild: this is an *offer* made when a change is registered,
  /// never a date that moves on its own. Rescheduling here would move
  /// deadlines the user never agreed to move.
  Future<void> setPreferredTime(int? minuteOfDay) async {
    final String? id = profileId;
    if (id == null) {
      return;
    }
    await profiles.setPreferredChangeMinuteOfDay(id, minuteOfDay);
  }

  /// Puts a consumable back on Home, or takes it off.
  ///
  /// Hiding, never deleting. The history keeps its rows and the foreign key
  /// would refuse the delete anyway — which is the point: turning something
  /// off has to be safe enough to tap.
  Future<void> setTracked(String typeId, bool tracked) async {
    tracked ? await types.activate(typeId) : await types.deactivate(typeId);
    await _resync();
  }

  /// Changes how long a consumable is expected to last.
  ///
  /// Rebuilds the reminders, because every deadline derived from this one has
  /// just moved. Instances already in use keep the date they were opened with:
  /// a duration is what the *next* cycle is measured by, and silently
  /// re-dating something already on the body would be the app changing a fact
  /// it did not observe.
  Future<void> setDuration(String typeId, Duration? duration) async {
    await types.setDefaultDuration(typeId, duration);
    await _resync();
  }

  Future<void> setTypeChangeTime(String typeId, int? minuteOfDay) async {
    await types.setPreferredChangeMinuteOfDay(typeId, minuteOfDay);
  }

  Future<void> setReminderOffsets(String typeId, List<Duration> offsets) async {
    await types.setReminderOffsets(typeId, offsets);
    await _resync();
  }

  /// Rebuilds what the operating system is holding.
  ///
  /// Allowed to fail, like every other call into the gateway: the setting is
  /// stored either way, because the log is the product and the reminders are a
  /// courtesy on top of it.
  Future<void> _resync() async {
    final String? id = profileId;
    if (id != null) {
      await reminders?.synchronize(id);
    }
  }
}

final Provider<SettingsController> settingsControllerProvider =
    Provider<SettingsController>((Ref ref) {
      return SettingsController(
        profiles: ref.watch(userProfileRepositoryProvider),
        types: ref.watch(consumableTypeRepositoryProvider),
        reminders: ref.watch(notificationSchedulerProvider),
        profileId: ref.watch(primaryProfileProvider).value?.id,
      );
    });
