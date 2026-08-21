import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the places on the body a user puts things.
class BodySiteRepository extends Repository {
  const BodySiteRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  Stream<List<BodySite>> watchActive(String userProfileId) {
    return (db.select(db.bodySites)
          ..where(
            ($BodySitesTable t) =>
                t.userProfileId.equals(userProfileId) & t.active.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<$BodySitesTable>>[
            ($BodySitesTable t) => OrderingTerm.asc(t.bodyRegion),
          ]))
        .watch();
  }

  /// The sites a user currently wants offered, as a plain future.
  ///
  /// The same question [watchActive] answers, for callers that read once and
  /// build rather than subscribing. Sites change when a user edits them, which
  /// is a settings screen away and not something the body map needs to react
  /// to mid-frame.
  Future<List<BodySite>> findActive(String userProfileId) {
    return (db.select(db.bodySites)
          ..where(
            ($BodySitesTable t) =>
                t.userProfileId.equals(userProfileId) & t.active.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<$BodySitesTable>>[
            ($BodySitesTable t) => OrderingTerm.asc(t.bodyRegion),
          ]))
        .get();
  }

  Future<List<BodySite>> findAll(String userProfileId) {
    return (db.select(db.bodySites)
          ..where(($BodySitesTable t) => t.userProfileId.equals(userProfileId)))
        .get();
  }

  Future<BodySite?> findById(String id) {
    return (db.select(
      db.bodySites,
    )..where(($BodySitesTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<BodySite> create({
    required String userProfileId,
    required BodyRegion bodyRegion,
    BodySide? side,
    String? customName,
    double? normalizedX,
    double? normalizedY,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.bodySites)
        .insertReturning(
          BodySitesCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            bodyRegion: bodyRegion,
            // Most regions already say which side they are on; only a custom
            // site needs to be told.
            side: side ?? bodyRegion.side,
            customName: Value<String?>(customName),
            normalizedX: Value<double?>(normalizedX),
            normalizedY: Value<double?>(normalizedY),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  /// Creates the standard set of sites for a new profile.
  ///
  /// Runs in a single transaction so onboarding cannot leave a profile with
  /// half a body map if it is interrupted.
  Future<List<BodySite>> createDefaults(String userProfileId) {
    return db.transaction(() async {
      final List<BodySite> created = <BodySite>[];
      for (final BodyRegion region in BodyRegionX.defaults) {
        created.add(
          await create(userProfileId: userProfileId, bodyRegion: region),
        );
      }
      return created;
    });
  }

  /// Creates the standard set of sites, but only for a profile that has none.
  ///
  /// The body map cannot work without somewhere to put things, and there are
  /// two populations to serve: profiles created from now on, and profiles that
  /// finished onboarding before this existed. One idempotent call on the read
  /// path covers both, rather than a seed in onboarding plus a migration for
  /// everyone else.
  ///
  /// It counts **all** sites, not the active ones. Someone who deliberately
  /// deactivated every site is telling the app something, and an app that
  /// silently put them all back would be arguing with them.
  Future<List<BodySite>> ensureDefaults(String userProfileId) async {
    final List<BodySite> existing = await findAll(userProfileId);
    if (existing.isNotEmpty) {
      return existing;
    }
    return createDefaults(userProfileId);
  }

  Future<void> update(String id, BodySitesCompanion changes) async {
    await (db.update(db.bodySites)
          ..where(($BodySitesTable t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value<DateTime>(now)));
  }

  /// Hides a site without deleting it, so past usage keeps its location.
  Future<void> deactivate(String id) {
    return update(id, const BodySitesCompanion(active: Value<bool>(false)));
  }
}

final Provider<BodySiteRepository> bodySiteRepositoryProvider =
    Provider<BodySiteRepository>((Ref ref) {
      return BodySiteRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
