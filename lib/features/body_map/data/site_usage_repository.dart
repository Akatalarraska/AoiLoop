import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes how long each body site has been occupied.
///
/// This is what lets the body map answer "how long has this spot been
/// resting". DT1FLOW reports that number. It never turns it into a
/// recommendation — the most it will say is which site was used least
/// recently, which is arithmetic, not advice.
class SiteUsageRepository extends Repository {
  const SiteUsageRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// Marks a site as occupied.
  ///
  /// Fails if the site already has an open usage — a partial unique index
  /// enforces one occupant at a time.
  Future<SiteUsage> open({
    required String bodySiteId,
    required String consumableInstanceId,
    required DateTime startedAt,
  }) {
    return db
        .into(db.siteUsages)
        .insertReturning(
          SiteUsagesCompanion.insert(
            id: newId,
            bodySiteId: bodySiteId,
            consumableInstanceId: consumableInstanceId,
            startedAt: startedAt.toUtc(),
          ),
        );
  }

  /// Frees whichever site the given instance was occupying.
  ///
  /// Keyed on the instance rather than the site because that is what the
  /// change flow has in hand, and because an instance can only be in one
  /// place.
  Future<void> closeForInstance(
    String consumableInstanceId, {
    required DateTime endedAt,
  }) async {
    await (db.update(db.siteUsages)..where(
          ($SiteUsagesTable t) =>
              t.consumableInstanceId.equals(consumableInstanceId) &
              t.endedAt.isNull(),
        ))
        .write(SiteUsagesCompanion(endedAt: Value<DateTime>(endedAt.toUtc())));
  }

  Future<SiteUsage?> findOpenForSite(String bodySiteId) {
    return (db.select(db.siteUsages)..where(
          ($SiteUsagesTable t) =>
              t.bodySiteId.equals(bodySiteId) & t.endedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<List<SiteUsage>> findForSite(String bodySiteId, {int limit = 50}) {
    return (db.select(db.siteUsages)
          ..where(($SiteUsagesTable t) => t.bodySiteId.equals(bodySiteId))
          ..orderBy(<OrderClauseGenerator<$SiteUsagesTable>>[
            ($SiteUsagesTable t) => OrderingTerm.desc(t.startedAt),
          ])
          ..limit(limit))
        .get();
  }

  /// The most recent start time for each of a profile's active sites.
  ///
  /// Sites that have never been used appear with a null value, so the body map
  /// can distinguish "rested for a long time" from "never used" — they look
  /// identical if you only report a duration, and they mean different things.
  Future<Map<String, DateTime?>> lastUsedBySite(String userProfileId) async {
    final Expression<DateTime> lastStarted = db.siteUsages.startedAt.max();

    final List<TypedResult> rows =
        await (db.selectOnly(db.bodySites)
              ..addColumns(<Expression<Object>>[db.bodySites.id, lastStarted])
              ..join(<Join<HasResultSet, dynamic>>[
                leftOuterJoin(
                  db.siteUsages,
                  db.siteUsages.bodySiteId.equalsExp(db.bodySites.id),
                ),
              ])
              ..where(
                db.bodySites.userProfileId.equals(userProfileId) &
                    db.bodySites.active.equals(true),
              )
              ..groupBy(<Expression<Object>>[db.bodySites.id]))
            .get();

    return <String, DateTime?>{
      for (final TypedResult row in rows)
        row.read<String>(db.bodySites.id)!: row.read<DateTime>(lastStarted),
    };
  }

  /// Sites ordered by how long they have been resting, longest first.
  ///
  /// Never-used sites come first. This is the only ranking DT1FLOW performs on
  /// body sites, and it is presented as a fact about the user's own history,
  /// not as a suggestion about where to place anything.
  Future<List<String>> siteIdsByRestDescending(String userProfileId) async {
    final Map<String, DateTime?> lastUsed = await lastUsedBySite(userProfileId);
    final List<MapEntry<String, DateTime?>> entries = lastUsed.entries.toList()
      ..sort((MapEntry<String, DateTime?> a, MapEntry<String, DateTime?> b) {
        if (a.value == null && b.value == null) {
          return a.key.compareTo(b.key);
        }
        if (a.value == null) {
          return -1;
        }
        if (b.value == null) {
          return 1;
        }
        return a.value!.compareTo(b.value!);
      });
    return entries.map((MapEntry<String, DateTime?> e) => e.key).toList();
  }
}

final Provider<SiteUsageRepository> siteUsageRepositoryProvider =
    Provider<SiteUsageRepository>((Ref ref) {
      return SiteUsageRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
