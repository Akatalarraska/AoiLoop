import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the individual consumables that were actually used.
///
/// This is the table the dashboard and the history timeline are both built on.
/// The cycle engine (Phase 4) drives it; nothing here decides *when* a change
/// is due, only what is recorded.
class ConsumableInstanceRepository extends Repository {
  const ConsumableInstanceRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// Everything currently in use, soonest deadline first.
  ///
  /// Instances with no deadline sort last rather than first: SQLite orders
  /// NULL before everything, which would put untimed items at the top of a
  /// dashboard that is meant to lead with what is most urgent.
  Stream<List<ConsumableInstance>> watchActive(String userProfileId) {
    return (db.select(db.consumableInstances)
          ..where(
            ($ConsumableInstancesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.status.equalsValue(ConsumableStatus.active),
          )
          ..orderBy(<OrderClauseGenerator<$ConsumableInstancesTable>>[
            ($ConsumableInstancesTable t) =>
                OrderingTerm.asc(t.expectedChangeAt, nulls: NullsOrder.last),
          ]))
        .watch();
  }

  /// Everything currently in use, as a plain future.
  ///
  /// The same question [watchActive] answers, for callers that ask once and
  /// act rather than rendering. The notification scheduler is the reason it
  /// exists: it runs on startup and after a change, does its work and stops,
  /// and subscribing to a stream to read a single value would leave it
  /// listening for the life of the app.
  Future<List<ConsumableInstance>> findActive(String userProfileId) {
    return (db.select(db.consumableInstances)
          ..where(
            ($ConsumableInstancesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.status.equalsValue(ConsumableStatus.active),
          )
          ..orderBy(<OrderClauseGenerator<$ConsumableInstancesTable>>[
            ($ConsumableInstancesTable t) =>
                OrderingTerm.asc(t.expectedChangeAt, nulls: NullsOrder.last),
          ]))
        .get();
  }

  /// The instance currently in use for one consumable type, if any.
  ///
  /// At most one can exist — enforced by a partial unique index, not by this
  /// query.
  Future<ConsumableInstance?> findActiveForType(
    String userProfileId,
    String consumableTypeId,
  ) {
    return (db.select(db.consumableInstances)..where(
          ($ConsumableInstancesTable t) =>
              t.userProfileId.equals(userProfileId) &
              t.consumableTypeId.equals(consumableTypeId) &
              t.status.equalsValue(ConsumableStatus.active),
        ))
        .getSingleOrNull();
  }

  Future<ConsumableInstance?> findById(String id) {
    return (db.select(db.consumableInstances)
          ..where(($ConsumableInstancesTable t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Closed instances, most recently removed first.
  Stream<List<ConsumableInstance>> watchHistory(
    String userProfileId, {
    int limit = 100,
  }) {
    return (db.select(db.consumableInstances)
          ..where(
            ($ConsumableInstancesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.status.equalsValue(ConsumableStatus.active).not(),
          )
          ..orderBy(<OrderClauseGenerator<$ConsumableInstancesTable>>[
            ($ConsumableInstancesTable t) =>
                OrderingTerm.desc(t.removedAt, nulls: NullsOrder.last),
          ])
          ..limit(limit))
        .watch();
  }

  /// Active instances whose deadline has passed, or falls before [cutoff].
  Future<List<ConsumableInstance>> findDueBefore(
    String userProfileId,
    DateTime cutoff,
  ) {
    return (db.select(db.consumableInstances)
          ..where(
            ($ConsumableInstancesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.status.equalsValue(ConsumableStatus.active) &
                t.expectedChangeAt.isNotNull() &
                t.expectedChangeAt.isSmallerOrEqualValue(cutoff.toUtc()),
          )
          ..orderBy(<OrderClauseGenerator<$ConsumableInstancesTable>>[
            ($ConsumableInstancesTable t) =>
                OrderingTerm.asc(t.expectedChangeAt),
          ]))
        .get();
  }

  Future<ConsumableInstance> create({
    required String userProfileId,
    required String consumableTypeId,
    required DateTime installedAt,
    DateTime? expectedChangeAt,
    String? deviceId,
    String? bodySiteId,
    String? lotNumber,
    String? serialNumber,
    DateTime? expirationDate,
    String? notes,
    ConsumableStatus status = ConsumableStatus.active,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.consumableInstances)
        .insertReturning(
          ConsumableInstancesCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            consumableTypeId: consumableTypeId,
            installedAt: installedAt.toUtc(),
            status: status,
            expectedChangeAt: Value<DateTime?>(expectedChangeAt?.toUtc()),
            deviceId: Value<String?>(deviceId),
            bodySiteId: Value<String?>(bodySiteId),
            lotNumber: Value<String?>(lotNumber),
            serialNumber: Value<String?>(serialNumber),
            expirationDate: Value<DateTime?>(expirationDate?.toUtc()),
            notes: Value<String?>(notes),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  /// Ends an instance's life.
  ///
  /// [status] says how it ended — completed, removed early, or discarded
  /// unused — and is what separates an ordinary change from a failure in
  /// every later count.
  Future<void> close(
    String id, {
    required DateTime removedAt,
    required ConsumableStatus status,
  }) async {
    assert(
      status != ConsumableStatus.active,
      'close() must move the instance out of the active state',
    );
    await (db.update(
      db.consumableInstances,
    )..where(($ConsumableInstancesTable t) => t.id.equals(id))).write(
      ConsumableInstancesCompanion(
        removedAt: Value<DateTime>(removedAt.toUtc()),
        status: Value<ConsumableStatus>(status),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  Future<void> update(String id, ConsumableInstancesCompanion changes) async {
    await (db.update(db.consumableInstances)
          ..where(($ConsumableInstancesTable t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value<DateTime>(now)));
  }

  /// Moves the expected change date.
  ///
  /// Used when the user accepts a shift to their preferred change time. The
  /// engine proposes it and the user agrees — this method never runs on its
  /// own initiative.
  Future<void> setExpectedChangeAt(String id, DateTime? expectedChangeAt) {
    return update(
      id,
      ConsumableInstancesCompanion(
        expectedChangeAt: Value<DateTime?>(expectedChangeAt?.toUtc()),
      ),
    );
  }
}

final Provider<ConsumableInstanceRepository>
consumableInstanceRepositoryProvider = Provider<ConsumableInstanceRepository>((
  Ref ref,
) {
  return ConsumableInstanceRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});
