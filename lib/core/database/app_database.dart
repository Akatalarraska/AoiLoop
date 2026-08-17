import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../constants/app_info.dart';

part 'app_database.g.dart';

/// The single local SQLite database behind DT1FLOW.
///
/// DT1FLOW is offline-first: this database is the source of truth, not a cache.
/// Every feature reads and writes through a repository that wraps this class;
/// no widget touches Drift directly.
///
/// **Phase 0 intentionally declares no tables.** The wiring — connection,
/// background isolate, foreign keys, migration strategy, disposal — is what
/// this phase delivers and what `test/core/database/app_database_test.dart`
/// exercises. The domain tables (UserProfile, Device, ConsumableType,
/// ConsumableInstance, ChangeEvent, Incident, BodySite, SiteUsage,
/// InventoryItem, NotificationSchedule) arrive in Phase 1, each with an
/// explicit migration step.
///
/// Rules for future schema changes, so migrations stay safe:
///
/// 1. Bump [schemaVersion] by exactly one per released change.
/// 2. Add a matching `from(n)To(n+1)` step in [migration].
/// 3. Never edit a shipped migration step — add a new one.
/// 4. Store timestamps in UTC. Presentation converts to local time.
@DriftDatabase(tables: <Type>[])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database, in a background isolate so large queries
  /// never stutter the UI.
  ///
  /// Pass [executor] to supply a different backing store — tests use
  /// `NativeDatabase.memory()`. A single constructor with an injectable
  /// executor keeps the test seam explicit without a second entry point that
  /// could drift out of sync.
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (OpeningDetails details) async {
        // SQLite disables foreign keys per connection by default. The Phase 1
        // schema leans on them heavily (a ChangeEvent without its
        // ConsumableInstance is corrupt data), so enable them on every open.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: AppInfo.databaseName);
  }
}
