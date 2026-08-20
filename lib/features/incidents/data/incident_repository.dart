import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes records of things going wrong.
///
/// BlauLoop stores incidents so the user can see their own history and so they
/// have the facts a manufacturer asks for. It draws no conclusions from them.
class IncidentRepository extends Repository {
  const IncidentRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  Stream<List<Incident>> watchRecent(String userProfileId, {int limit = 100}) {
    return (db.select(db.incidents)
          ..where(($IncidentsTable t) => t.userProfileId.equals(userProfileId))
          ..orderBy(<OrderClauseGenerator<$IncidentsTable>>[
            ($IncidentsTable t) => OrderingTerm.desc(t.occurredAt),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<Incident>> findForInstance(String consumableInstanceId) {
    return (db.select(db.incidents)
          ..where(
            ($IncidentsTable t) =>
                t.consumableInstanceId.equals(consumableInstanceId),
          )
          ..orderBy(<OrderClauseGenerator<$IncidentsTable>>[
            ($IncidentsTable t) => OrderingTerm.asc(t.occurredAt),
          ]))
        .get();
  }

  Future<Incident?> findById(String id) {
    return (db.select(
      db.incidents,
    )..where(($IncidentsTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Incident> create({
    required String userProfileId,
    required String consumableInstanceId,
    required DateTime occurredAt,
    required IncidentType type,
    String? notes,
    String? photoPath,
  }) {
    return db
        .into(db.incidents)
        .insertReturning(
          IncidentsCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            consumableInstanceId: consumableInstanceId,
            occurredAt: occurredAt.toUtc(),
            type: type,
            notes: Value<String?>(notes),
            photoPath: Value<String?>(photoPath),
            createdAt: now,
          ),
        );
  }

  Future<void> update(String id, IncidentsCompanion changes) async {
    await (db.update(
      db.incidents,
    )..where(($IncidentsTable t) => t.id.equals(id))).write(changes);
  }

  Future<void> delete(String id) async {
    await (db.delete(
      db.incidents,
    )..where(($IncidentsTable t) => t.id.equals(id))).go();
  }

  /// How often each kind of failure happened since [since].
  ///
  /// The user's own data, counted. BlauLoop presents the numbers and says
  /// nothing about what they mean.
  Future<Map<IncidentType, int>> countByTypeSince(
    String userProfileId,
    DateTime since,
  ) async {
    final Expression<int> total = db.incidents.id.count();
    final List<TypedResult> rows =
        await (db.selectOnly(db.incidents)
              ..addColumns(<Expression<Object>>[db.incidents.type, total])
              ..where(
                db.incidents.userProfileId.equals(userProfileId) &
                    db.incidents.occurredAt.isBiggerOrEqualValue(since.toUtc()),
              )
              ..groupBy(<Expression<Object>>[db.incidents.type]))
            .get();

    return <IncidentType, int>{
      for (final TypedResult row in rows)
        // Enum column behind a type converter, so read it through one.
        row.readWithConverter(db.incidents.type)!: row.read(total) ?? 0,
    };
  }
}

final Provider<IncidentRepository> incidentRepositoryProvider =
    Provider<IncidentRepository>((Ref ref) {
      return IncidentRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
