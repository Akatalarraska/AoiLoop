import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved the family provider types out of the main entrypoint, the
// same way it moved `Override`.
import 'package:flutter_riverpod/misc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../consumables/data/consumable_instance_repository.dart';
import '../../consumables/data/consumable_type_repository.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../settings/data/user_profile_repository.dart';
import '../data/body_site_repository.dart';
import '../domain/body_map_view.dart';

/// The profile's body sites, creating the standard set the first time.
///
/// The seeding lives on the read path rather than in onboarding because there
/// are two populations to serve — profiles created from now on, and profiles
/// that finished onboarding before the body map existed — and
/// [BodySiteRepository.ensureDefaults] is idempotent, so one call covers both.
final FutureProvider<List<BodySite>> bodySitesProvider =
    FutureProvider<List<BodySite>>((Ref ref) async {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return const <BodySite>[];
      }

      final BodySiteRepository sites = ref.watch(bodySiteRepositoryProvider);
      await sites.ensureDefaults(profile.id);
      return sites.findActive(profile.id);
    }, isAutoDispose: true);

/// Every consumable type, cyclic or not.
///
/// The dashboard only wants the ones with a countdown; the body map wants to
/// name whatever is actually on a site, and a counted consumable can be worn
/// just as much as a timed one.
final StreamProvider<List<ConsumableType>> allConsumableTypesProvider =
    StreamProvider<List<ConsumableType>>(
      (Ref ref) => ref.watch(consumableTypeRepositoryProvider).watchActive(),
      isAutoDispose: true,
    );

/// Every consumable type, including the ones switched off.
///
/// Only the settings screen wants this. Everywhere else, a type the user
/// turned off should be invisible — that is what turning it off meant.
final StreamProvider<List<ConsumableType>> everyConsumableTypeProvider =
    StreamProvider<List<ConsumableType>>(
      (Ref ref) => ref.watch(consumableTypeRepositoryProvider).watchAll(),
      isAutoDispose: true,
    );

/// When something was last put on each site.
///
/// A query rather than a stream, re-run whenever the set of things in use
/// changes — which is the only event that can alter the answer, and is exactly
/// what registering a change or reporting a failure produces. Watching the
/// instances provider is what wires that up; the read below does not depend on
/// its value.
final FutureProvider<Map<String, DateTime>> lastInstalledBySiteProvider =
    FutureProvider<Map<String, DateTime>>((Ref ref) async {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return const <String, DateTime>{};
      }
      ref.watch(activeConsumableInstancesProvider);
      return ref
          .watch(consumableInstanceRepositoryProvider)
          .lastInstalledByBodySite(profile.id);
    }, isAutoDispose: true);

/// Everything the body map renders.
///
/// Combined here rather than in the widget, so the screen has one thing to
/// watch and one [AsyncValue] to branch on — the same arrangement
/// `dashboardProvider` uses.
final Provider<AsyncValue<BodyMapView>> bodyMapProvider =
    Provider<AsyncValue<BodyMapView>>((Ref ref) {
      final AsyncValue<List<BodySite>> sites = ref.watch(bodySitesProvider);
      final AsyncValue<List<ConsumableInstance>> instances = ref.watch(
        activeConsumableInstancesProvider,
      );
      final AsyncValue<List<ConsumableType>> types = ref.watch(
        allConsumableTypesProvider,
      );
      final AsyncValue<Map<String, DateTime>> lastUsed = ref.watch(
        lastInstalledBySiteProvider,
      );

      for (final AsyncValue<Object> input in <AsyncValue<Object>>[
        sites,
        instances,
        types,
        lastUsed,
      ]) {
        if (input.hasError) {
          return AsyncValue<BodyMapView>.error(
            input.error!,
            input.stackTrace ?? StackTrace.current,
          );
        }
        if (!input.hasValue) {
          return const AsyncValue<BodyMapView>.loading();
        }
      }

      final Map<String, ConsumableType> typesById = <String, ConsumableType>{
        for (final ConsumableType type in types.requireValue) type.id: type,
      };

      // What is on each site right now. An instance with no site simply does
      // not contribute, which is how someone who does not track placement ends
      // up with a body map that is all rest and no occupants.
      final Map<String, ConsumableType> occupants = <String, ConsumableType>{
        for (final ConsumableInstance instance in instances.requireValue)
          if (instance.bodySiteId case final String siteId)
            if (typesById[instance.consumableTypeId]
                case final ConsumableType t)
              siteId: t,
      };

      return AsyncValue<BodyMapView>.data(
        BodyMapView.from(
          sites: sites.requireValue,
          lastUsedBySite: lastUsed.requireValue,
          occupantBySite: occupants,
          now: ref.watch(clockProvider).now(),
        ),
      );
    }, isAutoDispose: true);

/// Everything ever placed on one site, most recent first.
///
/// Re-read whenever the set of things in use changes, so a site's history
/// gains its new entry the moment a change is registered against it.
final FutureProviderFamily<List<ConsumableInstance>, String>
siteHistoryProvider = FutureProvider.family<List<ConsumableInstance>, String>((
  Ref ref,
  String siteId,
) {
  ref.watch(activeConsumableInstancesProvider);
  return ref
      .watch(consumableInstanceRepositoryProvider)
      .findForBodySite(siteId);
}, isAutoDispose: true);
