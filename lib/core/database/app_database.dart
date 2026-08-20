import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The generated part file is compiled as part of *this* library, so every type
// it names has to be imported here. Importing them only in the table files is
// not enough, and the analyzer will not catch the omission because generated
// sources are excluded from analysis — only a build or a test run fails.
import '../../shared/models/body_enums.dart';
import '../../shared/models/change_enums.dart';
import '../../shared/models/consumable_enums.dart';
import '../../shared/models/device_enums.dart';
import '../../shared/models/notification_enums.dart';
import '../../shared/models/profile_enums.dart';
import '../constants/app_info.dart';
import 'converters/reminder_offsets_converter.dart';
import 'tables/body_sites.dart';
import 'tables/change_events.dart';
import 'tables/consumable_instances.dart';
import 'tables/consumable_types.dart';
import 'tables/devices.dart';
import 'tables/incidents.dart';
import 'tables/inventory.dart';
import 'tables/notification_schedules.dart';
import 'tables/site_usages.dart';
import 'tables/user_profiles.dart';

// The row classes generated here expose these enums in their public API, so
// anything that can read a row can name its fields without a second import.
export '../../shared/models/body_enums.dart';
export '../../shared/models/change_enums.dart';
export '../../shared/models/consumable_enums.dart';
export '../../shared/models/device_enums.dart';
export '../../shared/models/notification_enums.dart';
export '../../shared/models/profile_enums.dart';
export 'tables/body_sites.dart';
export 'tables/change_events.dart';
export 'tables/consumable_instances.dart';
export 'tables/consumable_types.dart';
export 'tables/devices.dart';
export 'tables/incidents.dart';
export 'tables/inventory.dart';
export 'tables/notification_schedules.dart';
export 'tables/site_usages.dart';
export 'tables/user_profiles.dart';

part 'app_database.g.dart';

/// The single local SQLite database behind BlauLoop.
///
/// BlauLoop is offline-first: this database is the source of truth, not a
/// cache. Every feature reads and writes through a repository that wraps this
/// class; no widget touches Drift directly.
///
/// Rules for schema changes, so migrations stay safe:
///
/// 1. Bump [schemaVersion] by exactly one per released change.
/// 2. Add a matching `from(n)To(n+1)` step in [migration].
/// 3. Never edit a shipped migration step — add a new one.
/// 4. Store timestamps in UTC. Presentation converts to local time.
@DriftDatabase(
  tables: <Type>[
    UserProfiles,
    Devices,
    ConsumableTypes,
    ConsumableInstances,
    ChangeEvents,
    Incidents,
    BodySites,
    SiteUsages,
    InventoryLocations,
    InventoryItems,
    NotificationSchedules,
  ],
)
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
  int get schemaVersion => 3;

  /// Timestamps are stored as ISO-8601 text rather than Unix seconds.
  ///
  /// A health log is something people occasionally need to inspect, export or
  /// hand to support. `2026-08-17T11:00:00.000Z` is readable and unambiguous
  /// about its offset; `1786662000` is neither. It also removes a whole class
  /// of silent bug where an integer column is read back in the wrong unit.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v1 shipped the connection and no tables at all (Phase 0). The domain
        // schema arrives whole in v2, so the step is a plain create.
        //
        // The early return matters. `createAll` builds the schema as it stands
        // *today*, which already contains every column added since v2 — so
        // falling through to the incremental steps below would try to add a
        // column that createAll just created, and SQLite aborts the upgrade
        // with "duplicate column name". Analysis cannot catch that; only a
        // v1 database can, which is what the migration test opens.
        if (from < 2) {
          await m.createAll();
          return;
        }

        // v3 gives each consumable type its own preferred change time.
        // Nullable, and left null on upgrade: every existing type keeps
        // inheriting the profile's time, so nobody's deadlines move because
        // they installed an update.
        if (from < 3) {
          await m.addColumn(
            consumableTypes,
            consumableTypes.preferredChangeMinuteOfDay,
          );
        }
      },
      beforeOpen: (OpeningDetails details) async {
        // SQLite disables foreign keys per connection by default. The schema
        // leans on them heavily (a ChangeEvent without its ConsumableInstance
        // is corrupt data), so enable them on every open.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: AppInfo.databaseName,
      // Ignored on Android and iOS, and mandatory on the web — `driftDatabase`
      // throws outright without it. Both files are served from `web/` and must
      // match the pinned `drift` and `sqlite3` versions; a mismatch fails at
      // runtime, not at build time.
      //
      // The web target exists to look at the app during development. The
      // shipping platforms are the two mobile ones, where this parameter does
      // nothing at all.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
