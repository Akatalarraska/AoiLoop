import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/settings/data/user_profile_repository.dart';

/// A language picked in the app, for as long as this launch lasts.
///
/// Onboarding writes here so the flow switches language the moment the user
/// taps it, before there is any profile to store the choice on. Once the
/// profile exists it carries the language, and this override stops mattering.
class LocaleOverrideController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void set(Locale? locale) => state = locale;

  /// Goes back to following the profile, or the system if there is none.
  void clear() => state = null;
}

final NotifierProvider<LocaleOverrideController, Locale?>
localeOverrideProvider = NotifierProvider<LocaleOverrideController, Locale?>(
  LocaleOverrideController.new,
);

/// The locale the app runs in, or null to follow the operating system.
///
/// Precedence is deliberate: an explicit in-app choice wins over the profile,
/// and the profile wins over the OS. Someone who told DT1FLOW "Spanish" during
/// onboarding on an English phone meant it, and having the app quietly revert
/// on the next launch would read as a bug.
final Provider<Locale?> appLocaleProvider = Provider<Locale?>((Ref ref) {
  final Locale? chosen = ref.watch(localeOverrideProvider);
  if (chosen != null) {
    return chosen;
  }

  final UserProfile? profile = ref.watch(primaryProfileProvider).value;
  if (profile == null) {
    return null;
  }
  return Locale(profile.languageCode);
});
