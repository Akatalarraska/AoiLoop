import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/data/user_profile_repository.dart';
import '../../database/app_database.dart';
import '../data/notification_scheduler.dart';

/// Brings the operating system's reminders in line with the database, and
/// reports what happened.
///
/// Runs when the app reaches a screen that watches it, which in practice means
/// once per launch. That is the moment worth rebuilding at: notifications are
/// lost on reinstall, dropped when permission is revoked, and rescheduled by
/// the OS after a reboot in ways the app cannot see.
///
/// Registering a change reschedules too, from inside `CycleEngine`, so this
/// is not the only path. Both are idempotent — a synchronisation withdraws
/// what it previously asked for before asking again — so running twice costs a
/// few platform calls and changes nothing.
final FutureProvider<ReminderSync> reminderSyncProvider =
    FutureProvider<ReminderSync>((Ref ref) async {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return ReminderSync.disabled;
      }
      return ref.watch(notificationSchedulerProvider).synchronize(profile.id);
    });
