import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the *kinds* of consumable a user tracks.
class ConsumableTypeRepository extends Repository {
  const ConsumableTypeRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  Stream<List<ConsumableType>> watchActive() {
    return (db.select(db.consumableTypes)
          ..where(($ConsumableTypesTable t) => t.active.equals(true))
          ..orderBy(<OrderClauseGenerator<$ConsumableTypesTable>>[
            ($ConsumableTypesTable t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  /// Active types that have a countdown — the ones the dashboard cares about.
  Stream<List<ConsumableType>> watchCyclic() {
    return (db.select(db.consumableTypes)
          ..where(
            ($ConsumableTypesTable t) =>
                t.active.equals(true) & t.tracksCycle.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<$ConsumableTypesTable>>[
            ($ConsumableTypesTable t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<ConsumableType?> findById(String id) {
    return (db.select(
      db.consumableTypes,
    )..where(($ConsumableTypesTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<ConsumableType>> findByCategory(ConsumableCategory category) {
    return (db.select(db.consumableTypes)..where(
          ($ConsumableTypesTable t) =>
              t.category.equalsValue(category) & t.active.equals(true),
        ))
        .get();
  }

  Future<ConsumableType> create({
    required String name,
    required ConsumableCategory category,
    Duration? defaultDuration,
    bool tracksCycle = true,
    bool tracksInventory = true,
    List<Duration> defaultReminderOffsets = const <Duration>[],
    bool isBuiltIn = false,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.consumableTypes)
        .insertReturning(
          ConsumableTypesCompanion.insert(
            id: newId,
            name: name,
            category: category,
            defaultDurationMinutes: Value<int?>(defaultDuration?.inMinutes),
            tracksCycle: Value<bool>(tracksCycle),
            tracksInventory: Value<bool>(tracksInventory),
            defaultReminderOffsets: Value<List<Duration>>(
              defaultReminderOffsets,
            ),
            isBuiltIn: Value<bool>(isBuiltIn),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> update(String id, ConsumableTypesCompanion changes) async {
    await (db.update(db.consumableTypes)
          ..where(($ConsumableTypesTable t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value<DateTime>(now)));
  }

  /// Changes how long this kind of consumable is expected to last.
  ///
  /// Deliberately does **not** touch instances already in use. A user who
  /// discovers their sensors only last 7 days should not have yesterday's
  /// deadline silently rewritten underneath them — the new duration applies to
  /// what they put on next.
  Future<void> setDefaultDuration(String id, Duration? duration) {
    return update(
      id,
      ConsumableTypesCompanion(
        defaultDurationMinutes: Value<int?>(duration?.inMinutes),
      ),
    );
  }

  Future<void> setReminderOffsets(String id, List<Duration> offsets) {
    return update(
      id,
      ConsumableTypesCompanion(
        defaultReminderOffsets: Value<List<Duration>>(offsets),
      ),
    );
  }

  /// Hides a type from pickers. Never deletes: instances reference it, and the
  /// foreign key is `RESTRICT` precisely so that history cannot be dropped by
  /// accident.
  Future<void> deactivate(String id) {
    return update(
      id,
      const ConsumableTypesCompanion(active: Value<bool>(false)),
    );
  }

  Future<int> countAll() async {
    final Expression<int> count = db.consumableTypes.id.count();
    final TypedResult row = await (db.selectOnly(
      db.consumableTypes,
    )..addColumns(<Expression<Object>>[count])).getSingle();
    return row.read(count) ?? 0;
  }
}

final Provider<ConsumableTypeRepository> consumableTypeRepositoryProvider =
    Provider<ConsumableTypeRepository>((Ref ref) {
      return ConsumableTypeRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
