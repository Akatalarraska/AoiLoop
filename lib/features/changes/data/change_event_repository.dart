import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the record that a change happened.
///
/// The history timeline is built from this table. Rows are append-only in
/// spirit: a mistake is corrected by recording a
/// [ChangeType.manualCorrection], not by editing the past.
class ChangeEventRepository extends Repository {
  const ChangeEventRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// The timeline, most recent first.
  Stream<List<ChangeEvent>> watchTimeline(
    String userProfileId, {
    int limit = 200,
  }) {
    return (db.select(db.changeEvents)
          ..where(
            ($ChangeEventsTable t) => t.userProfileId.equals(userProfileId),
          )
          ..orderBy(<OrderClauseGenerator<$ChangeEventsTable>>[
            ($ChangeEventsTable t) => OrderingTerm.desc(t.changedAt),
          ])
          ..limit(limit))
        .watch();
  }

  /// The timeline filtered to particular reasons — the "incidents only" view.
  Stream<List<ChangeEvent>> watchTimelineOfTypes(
    String userProfileId,
    Set<ChangeType> types, {
    int limit = 200,
  }) {
    if (types.isEmpty) {
      return Stream<List<ChangeEvent>>.value(const <ChangeEvent>[]);
    }
    return (db.select(db.changeEvents)
          ..where(
            ($ChangeEventsTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.type.isInValues(types.toList()),
          )
          ..orderBy(<OrderClauseGenerator<$ChangeEventsTable>>[
            ($ChangeEventsTable t) => OrderingTerm.desc(t.changedAt),
          ])
          ..limit(limit))
        .watch();
  }

  /// Changes within a date range, for the calendar.
  Future<List<ChangeEvent>> findBetween(
    String userProfileId,
    DateTime from,
    DateTime to,
  ) {
    return (db.select(db.changeEvents)
          ..where(
            ($ChangeEventsTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.changedAt.isBiggerOrEqualValue(from.toUtc()) &
                t.changedAt.isSmallerThanValue(to.toUtc()),
          )
          ..orderBy(<OrderClauseGenerator<$ChangeEventsTable>>[
            ($ChangeEventsTable t) => OrderingTerm.asc(t.changedAt),
          ]))
        .get();
  }

  Future<ChangeEvent> create({
    required String userProfileId,
    required String consumableInstanceId,
    required DateTime changedAt,
    required ChangeType type,
    String? previousConsumableInstanceId,
    String? previousBodySiteId,
    String? newBodySiteId,
    String? notes,
  }) {
    return db
        .into(db.changeEvents)
        .insertReturning(
          ChangeEventsCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            consumableInstanceId: consumableInstanceId,
            changedAt: changedAt.toUtc(),
            type: type,
            previousConsumableInstanceId: Value<String?>(
              previousConsumableInstanceId,
            ),
            previousBodySiteId: Value<String?>(previousBodySiteId),
            newBodySiteId: Value<String?>(newBodySiteId),
            notes: Value<String?>(notes),
            // `changedAt` is when it happened; this is when it was written
            // down. A 3 a.m. sensor swap logged at breakfast has both, and the
            // difference is sometimes the interesting part.
            createdAt: now,
          ),
        );
  }

  /// How many changes of each reason occurred since [since].
  ///
  /// Feeds the history summary. Counting is all DT1FLOW does with this — it
  /// does not tell the user whether a number is good or bad.
  Future<Map<ChangeType, int>> countByTypeSince(
    String userProfileId,
    DateTime since,
  ) async {
    final Expression<int> total = db.changeEvents.id.count();
    final List<TypedResult> rows =
        await (db.selectOnly(db.changeEvents)
              ..addColumns(<Expression<Object>>[db.changeEvents.type, total])
              ..where(
                db.changeEvents.userProfileId.equals(userProfileId) &
                    db.changeEvents.changedAt.isBiggerOrEqualValue(
                      since.toUtc(),
                    ),
              )
              ..groupBy(<Expression<Object>>[db.changeEvents.type]))
            .get();

    return <ChangeType, int>{
      for (final TypedResult row in rows)
        // The column stores an enum through a type converter, so it has to be
        // read back through the converter rather than as a raw string.
        row.readWithConverter(db.changeEvents.type)!: row.read(total) ?? 0,
    };
  }
}

final Provider<ChangeEventRepository> changeEventRepositoryProvider =
    Provider<ChangeEventRepository>((Ref ref) {
      return ChangeEventRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
