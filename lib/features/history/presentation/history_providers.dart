import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../../changes/data/change_event_repository.dart';
import '../../consumables/data/consumable_instance_repository.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../incidents/data/incident_repository.dart';
import '../../settings/data/user_profile_repository.dart';
import '../domain/history_entry.dart';
import '../domain/history_view.dart';

/// Every change and every incident, resolved to the consumable it was about.
///
/// The join is here rather than in the view model because it needs the
/// database: both tables point at a `ConsumableInstance`, and the name the
/// user actually recognises is one hop further on, on the type. A timeline row
/// that could only say "something was changed" would not be a history.
///
/// Entries whose consumable can no longer be resolved are dropped. That is a
/// type deleted out from under its history, which the `RESTRICT` on the
/// foreign key is there to prevent — so this is a belt-and-braces case rather
/// than an expected one, and a row naming nothing is worse than no row.
final FutureProvider<List<HistoryEntry>>
historyEntriesProvider = FutureProvider<List<HistoryEntry>>((Ref ref) async {
  final UserProfile? profile = ref.watch(primaryProfileProvider).value;
  if (profile == null) {
    return const <HistoryEntry>[];
  }

  // Re-read whenever anything is registered. Both writes go through the
  // cycle engine, and both end with the active set changing — except an
  // incident the user rode out, which is why the incident stream is
  // watched as well rather than relying on that one signal.
  ref.watch(activeConsumableInstancesProvider);
  final List<Incident> incidents =
      ref.watch(recentIncidentsProvider).value ?? const <Incident>[];

  final List<ChangeEvent> changes = await ref
      .watch(changeEventRepositoryProvider)
      .findTimeline(profile.id);

  final ConsumableInstanceRepository instances = ref.watch(
    consumableInstanceRepositoryProvider,
  );
  final Map<String, ConsumableType> byTypeId = <String, ConsumableType>{
    for (final ConsumableType type
        in ref.watch(allConsumableTypesProvider).value ??
            const <ConsumableType>[])
      type.id: type,
  };

  // One lookup per instance, memoised: a busy history points many rows at
  // the same handful of instances, and re-reading each of them would turn
  // a screen into a query storm.
  final Map<String, ConsumableType?> typeOfInstance =
      <String, ConsumableType?>{};
  Future<ConsumableType?> resolve(String instanceId) async {
    if (typeOfInstance.containsKey(instanceId)) {
      return typeOfInstance[instanceId];
    }
    final ConsumableInstance? instance = await instances.findById(instanceId);
    final ConsumableType? type = instance == null
        ? null
        : byTypeId[instance.consumableTypeId];
    typeOfInstance[instanceId] = type;
    return type;
  }

  final List<HistoryEntry> entries = <HistoryEntry>[];
  for (final ChangeEvent event in changes) {
    final ConsumableType? type = await resolve(event.consumableInstanceId);
    if (type != null) {
      entries.add(ChangeEntry(event: event, type: type));
    }
  }
  for (final Incident incident in incidents) {
    final ConsumableType? type = await resolve(incident.consumableInstanceId);
    if (type != null) {
      entries.add(IncidentEntry(incident: incident, type: type));
    }
  }
  return entries;
}, isAutoDispose: true);

/// Incidents, most recent first.
final StreamProvider<List<Incident>> recentIncidentsProvider =
    StreamProvider<List<Incident>>((Ref ref) {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return Stream<List<Incident>>.value(const <Incident>[]);
      }
      return ref.watch(incidentRepositoryProvider).watchRecent(profile.id);
    }, isAutoDispose: true);

/// Which kinds of entry the timeline is showing.
final NotifierProvider<HistoryFilterController, HistoryFilter>
historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
      isAutoDispose: true,
    );

class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => HistoryFilter.everything;

  void select(HistoryFilter filter) => state = filter;
}

/// Which consumable the timeline is narrowed to, or null for all of them.
///
/// Kept alive, unlike almost everything else here, because it is set from one
/// screen and read on another: tapping *see its history* on a consumable's
/// circle narrows this and then opens the History tab. Auto-disposed, the
/// value would be thrown away in the gap between the two — nothing is
/// listening at the moment it is written — and the user would land on an
/// unnarrowed list having asked for a narrowed one.
final NotifierProvider<HistoryScopeController, String?> historyScopeProvider =
    NotifierProvider<HistoryScopeController, String?>(
      HistoryScopeController.new,
    );

class HistoryScopeController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? consumableTypeId) => state = consumableTypeId;
}

/// The timeline as the screen renders it.
final Provider<AsyncValue<HistoryView>> historyProvider =
    Provider<AsyncValue<HistoryView>>((Ref ref) {
      final AsyncValue<List<HistoryEntry>> entries = ref.watch(
        historyEntriesProvider,
      );

      if (entries.hasError) {
        return AsyncValue<HistoryView>.error(
          entries.error!,
          entries.stackTrace ?? StackTrace.current,
        );
      }
      if (!entries.hasValue) {
        return const AsyncValue<HistoryView>.loading();
      }

      return AsyncValue<HistoryView>.data(
        HistoryView.from(
          entries: entries.requireValue,
          today: ref.watch(clockProvider).now().toLocal(),
          filter: ref.watch(historyFilterProvider),
          consumableTypeId: ref.watch(historyScopeProvider),
        ),
      );
    }, isAutoDispose: true);
