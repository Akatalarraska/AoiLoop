import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the person being tracked.
///
/// The MVP has exactly one profile, which is why [watchPrimary] exists. The
/// table already supports several, so release 0.2 adds a selector rather than
/// a migration.
class UserProfileRepository extends Repository {
  const UserProfileRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// The profile the app is currently about.
  ///
  /// Emits null before onboarding has run, which is how the router decides
  /// whether to send the user there.
  Stream<UserProfile?> watchPrimary() {
    return (db.select(db.userProfiles)
          ..orderBy(<OrderClauseGenerator<$UserProfilesTable>>[
            ($UserProfilesTable t) => OrderingTerm.asc(t.createdAt),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<UserProfile?> findPrimary() {
    return (db.select(db.userProfiles)
          ..orderBy(<OrderClauseGenerator<$UserProfilesTable>>[
            ($UserProfilesTable t) => OrderingTerm.asc(t.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<UserProfile?> findById(String id) {
    return (db.select(
      db.userProfiles,
    )..where(($UserProfilesTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<List<UserProfile>> watchAll() {
    return (db.select(db.userProfiles)
          ..orderBy(<OrderClauseGenerator<$UserProfilesTable>>[
            ($UserProfilesTable t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Future<UserProfile> create({
    required String displayName,
    required String timezone,
    required String languageCode,
    required GlucoseUnit glucoseUnit,
    required TreatmentType treatmentType,
    int? birthYear,
    int? preferredChangeMinuteOfDay,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.userProfiles)
        .insertReturning(
          UserProfilesCompanion.insert(
            id: newId,
            displayName: displayName,
            timezone: timezone,
            languageCode: languageCode,
            glucoseUnit: glucoseUnit,
            treatmentType: treatmentType,
            birthYear: Value<int?>(birthYear),
            preferredChangeMinuteOfDay: Value<int?>(preferredChangeMinuteOfDay),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  /// Applies a partial update and refreshes `updatedAt`.
  ///
  /// Takes a companion rather than a long list of nullable named parameters,
  /// because half these fields are themselves nullable and "not supplied"
  /// would be indistinguishable from "set to null".
  Future<void> update(String id, UserProfilesCompanion changes) async {
    await (db.update(db.userProfiles)
          ..where(($UserProfilesTable t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value<DateTime>(now)));
  }

  /// Sets the preferred time of day for changes, as minutes since local
  /// midnight. Null clears the preference.
  ///
  /// Changing this does **not** move any existing deadline. The cycle engine
  /// asks the user before shifting a date; nothing here does it silently.
  Future<void> setPreferredChangeMinuteOfDay(String id, int? minuteOfDay) {
    assert(
      minuteOfDay == null || (minuteOfDay >= 0 && minuteOfDay < 24 * 60),
      'minuteOfDay must be within a single day, got $minuteOfDay',
    );
    return update(
      id,
      UserProfilesCompanion(
        preferredChangeMinuteOfDay: Value<int?>(minuteOfDay),
      ),
    );
  }

  /// Removes a profile and, by cascade, everything belonging to it.
  Future<void> delete(String id) async {
    await (db.delete(
      db.userProfiles,
    )..where(($UserProfilesTable t) => t.id.equals(id))).go();
  }
}

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((Ref ref) {
      return UserProfileRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
