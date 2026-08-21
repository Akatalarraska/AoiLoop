import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../../settings/data/user_profile_repository.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_view.dart';

/// Every batch this profile has, across every consumable and location.
final StreamProvider<List<InventoryItem>> inventoryItemsProvider =
    StreamProvider<List<InventoryItem>>((Ref ref) {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return Stream<List<InventoryItem>>.value(const <InventoryItem>[]);
      }
      return ref.watch(inventoryRepositoryProvider).watchItems(profile.id);
    }, isAutoDispose: true);

/// The places supplies are kept.
final StreamProvider<List<InventoryLocation>> inventoryLocationsProvider =
    StreamProvider<List<InventoryLocation>>((Ref ref) {
      final UserProfile? profile = ref.watch(primaryProfileProvider).value;
      if (profile == null) {
        return Stream<List<InventoryLocation>>.value(
          const <InventoryLocation>[],
        );
      }
      return ref.watch(inventoryRepositoryProvider).watchLocations(profile.id);
    }, isAutoDispose: true);

/// Everything the inventory screen renders.
///
/// Built from the types that actually count stock. A consumable the user
/// switched counting off for has no business sitting at a total of zero
/// beside the things they do count — the screen would be telling them they
/// are out of something they never asked to be told about.
final Provider<AsyncValue<InventoryView>> inventoryProvider =
    Provider<AsyncValue<InventoryView>>((Ref ref) {
      final AsyncValue<List<ConsumableType>> types = ref.watch(
        allConsumableTypesProvider,
      );
      final AsyncValue<List<InventoryItem>> items = ref.watch(
        inventoryItemsProvider,
      );
      final AsyncValue<List<InventoryLocation>> locations = ref.watch(
        inventoryLocationsProvider,
      );

      for (final AsyncValue<Object> input in <AsyncValue<Object>>[
        types,
        items,
        locations,
      ]) {
        if (input.hasError) {
          return AsyncValue<InventoryView>.error(
            input.error!,
            input.stackTrace ?? StackTrace.current,
          );
        }
        if (!input.hasValue) {
          return const AsyncValue<InventoryView>.loading();
        }
      }

      return AsyncValue<InventoryView>.data(
        InventoryView.from(
          types: types.requireValue
              .where((ConsumableType type) => type.tracksInventory)
              .toList(),
          items: items.requireValue,
          locations: locations.requireValue,
        ),
      );
    }, isAutoDispose: true);

/// How many consumables are at or below the level the user asked about.
///
/// Home watches this rather than the whole view, so a change to one batch's
/// expiry date does not rebuild the dashboard.
final Provider<int> lowStockCountProvider = Provider<int>((Ref ref) {
  return ref.watch(inventoryProvider).value?.lowCount ?? 0;
}, isAutoDispose: true);
