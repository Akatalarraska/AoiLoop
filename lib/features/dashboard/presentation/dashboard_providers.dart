import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/ticker.dart';
import '../../consumables/data/consumable_instance_repository.dart';
import '../../consumables/data/consumable_type_repository.dart';
import '../../settings/data/user_profile_repository.dart';
import '../domain/dashboard_view.dart';

/// How often the dashboard re-reads the time.
///
/// A minute is the coarsest unit any countdown displays, so anything faster
/// would redraw the screen without changing a character of it. The final
/// minute before a deadline is the only place that shows, and it resolves
/// itself a minute later.
const Duration dashboardTickPeriod = Duration(minutes: 1);

/// The instant the dashboard is currently rendering, refreshed every
/// [dashboardTickPeriod].
///
/// Auto-disposed, so leaving Home cancels the timer rather than redrawing a
/// screen nobody is looking at.
final StreamProvider<DateTime> dashboardTickProvider = StreamProvider<DateTime>(
  (Ref ref) => ref.watch(tickerProvider).ticks(dashboardTickPeriod),
  isAutoDispose: true,
);

/// Active consumable types that have a countdown.
final StreamProvider<List<ConsumableType>> cyclicConsumableTypesProvider =
    StreamProvider<List<ConsumableType>>(
      (Ref ref) => ref.watch(consumableTypeRepositoryProvider).watchCyclic(),
      isAutoDispose: true,
    );

/// Whatever is in use right now, for the profile the app is about.
///
/// Not parameterised by profile id: [primaryProfileProvider] is already the
/// one answer to "who is this app about", and a second way of naming the same
/// person is a second way of naming the wrong one. Release 0.2 introduces
/// profile switching by changing what that provider returns, not by threading
/// an id through every screen.
final StreamProvider<List<ConsumableInstance>>
activeConsumableInstancesProvider = StreamProvider<List<ConsumableInstance>>((
  Ref ref,
) {
  final UserProfile? profile = ref.watch(primaryProfileProvider).value;
  if (profile == null) {
    return Stream<List<ConsumableInstance>>.value(const <ConsumableInstance>[]);
  }
  return ref
      .watch(consumableInstanceRepositoryProvider)
      .watchActive(profile.id);
}, isAutoDispose: true);

/// Everything Home renders.
///
/// Four inputs — the profile, the types, what is in use, and the time —
/// combined here rather than in the widget, so the screen has one thing to
/// watch and one [AsyncValue] to branch on.
///
/// The tick is folded in as a *fallback to the clock* rather than waited on.
/// A stream's first event lands after the first frame, and a dashboard that
/// showed a spinner for a frame every time it was opened would flicker on
/// every tab switch.
final Provider<AsyncValue<DashboardView>> dashboardProvider =
    Provider<AsyncValue<DashboardView>>((Ref ref) {
      final AsyncValue<UserProfile?> profileAsync = ref.watch(
        primaryProfileProvider,
      );

      // The router does not let Home be reached without a profile, so a
      // missing one here means the read has not landed yet or has failed —
      // and the startup screen owns both of those.
      final UserProfile? profile = profileAsync.value;
      if (profile == null) {
        return profileAsync.hasError
            ? AsyncValue<DashboardView>.error(
                profileAsync.error!,
                profileAsync.stackTrace ?? StackTrace.current,
              )
            : const AsyncValue<DashboardView>.loading();
      }

      final AsyncValue<List<ConsumableType>> types = ref.watch(
        cyclicConsumableTypesProvider,
      );
      final AsyncValue<List<ConsumableInstance>> instances = ref.watch(
        activeConsumableInstancesProvider,
      );

      for (final AsyncValue<Object> input in <AsyncValue<Object>>[
        types,
        instances,
      ]) {
        if (input.hasError) {
          return AsyncValue<DashboardView>.error(
            input.error!,
            input.stackTrace ?? StackTrace.current,
          );
        }
      }
      if (!types.hasValue || !instances.hasValue) {
        return const AsyncValue<DashboardView>.loading();
      }

      final DateTime now =
          ref.watch(dashboardTickProvider).value ??
          ref.watch(clockProvider).now();

      return AsyncValue<DashboardView>.data(
        DashboardView.from(
          profile: profile,
          types: types.requireValue,
          instances: instances.requireValue,
          now: now,
        ),
      );
    }, isAutoDispose: true);
