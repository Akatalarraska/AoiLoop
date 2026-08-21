import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../history/domain/history_entry.dart';
import '../../history/presentation/history_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../domain/calendar_month.dart';

/// The month the calendar is showing, as local midnight on its first day.
final NotifierProvider<CalendarMonthController, DateTime> visibleMonthProvider =
    NotifierProvider<CalendarMonthController, DateTime>(
      CalendarMonthController.new,
      isAutoDispose: true,
    );

class CalendarMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = ref.watch(clockProvider).now().toLocal();
    return DateTime(now.year, now.month);
  }

  void show(DateTime month) => state = DateTime(month.year, month.month);
}

/// The dates the app is expecting something on.
///
/// Deadlines from whatever is in use, and dates from stock that still has
/// units in it. Both are things the user would rather see coming than be
/// surprised by, which is the whole reason the calendar exists.
final Provider<List<CalendarExpectation>>
calendarExpectationsProvider = Provider<List<CalendarExpectation>>((Ref ref) {
  final Map<String, ConsumableType> byTypeId = <String, ConsumableType>{
    for (final ConsumableType type
        in ref.watch(allConsumableTypesProvider).value ??
            const <ConsumableType>[])
      type.id: type,
  };

  final List<CalendarExpectation> expectations = <CalendarExpectation>[];

  for (final ConsumableInstance instance
      in ref.watch(activeConsumableInstancesProvider).value ??
          const <ConsumableInstance>[]) {
    final ConsumableType? type = byTypeId[instance.consumableTypeId];
    if (type != null && instance.expectedChangeAt != null) {
      expectations.add(ChangeDue(instance: instance, type: type));
    }
  }

  for (final InventoryItem batch
      in ref.watch(inventoryItemsProvider).value ?? const <InventoryItem>[]) {
    final ConsumableType? type = byTypeId[batch.consumableTypeId];
    // An empty batch records a box that is gone. Marking the day it would
    // have gone off is marking nothing.
    if (type != null && batch.expirationDate != null && batch.quantity > 0) {
      expectations.add(StockExpires(batch: batch, type: type));
    }
  }

  return List<CalendarExpectation>.unmodifiable(expectations);
}, isAutoDispose: true);

/// The grid the calendar renders.
final Provider<AsyncValue<CalendarMonth>> calendarProvider =
    Provider<AsyncValue<CalendarMonth>>((Ref ref) {
      final AsyncValue<List<HistoryEntry>> entries = ref.watch(
        historyEntriesProvider,
      );

      if (entries.hasError) {
        return AsyncValue<CalendarMonth>.error(
          entries.error!,
          entries.stackTrace ?? StackTrace.current,
        );
      }
      if (!entries.hasValue) {
        return const AsyncValue<CalendarMonth>.loading();
      }

      return AsyncValue<CalendarMonth>.data(
        CalendarMonth.from(
          month: ref.watch(visibleMonthProvider),
          entries: entries.requireValue,
          expectations: ref.watch(calendarExpectationsProvider),
          today: ref.watch(clockProvider).now().toLocal(),
          firstWeekday: ref.watch(firstWeekdayProvider),
        ),
      );
    }, isAutoDispose: true);

/// The locale's first day of the week.
///
/// Hardcoded to Monday for now, which is right for both languages BlauLoop
/// ships in. It is a provider rather than a constant so the settings screen in
/// Phase 10, or a third locale, can change it in one place instead of in the
/// grid arithmetic.
final Provider<int> firstWeekdayProvider = Provider<int>(
  (Ref ref) => DateTime.monday,
);

/// The day the user has opened, or null while none is.
final NotifierProvider<SelectedDayController, DateTime?> selectedDayProvider =
    NotifierProvider<SelectedDayController, DateTime?>(
      SelectedDayController.new,
      isAutoDispose: true,
    );

class SelectedDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime? day) =>
      state = day == null ? null : DateTime(day.year, day.month, day.day);
}
