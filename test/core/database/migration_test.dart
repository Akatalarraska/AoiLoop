import 'package:aoiloop/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Migration tests.
///
/// Phase 0 shipped schema v1: a working connection with no tables. Phase 1
/// brings the whole domain schema as v2. Nobody outside the project ran v1, but
/// the upgrade path is tested anyway — the first migration is the one that
/// establishes whether migrations are taken seriously at all, and every later
/// one will be copied from it.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  /// Opens a database over [raw] and forces the migration to run.
  Future<AppDatabase> openOver(sqlite.Database raw) async {
    final AppDatabase db = AppDatabase(executor: NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('upgrades a v1 database to v2 and creates the whole schema', () async {
    final sqlite.Database raw = sqlite.sqlite3.openInMemory();
    addTearDown(raw.close);

    // A Phase 0 database: version stamped, no tables.
    raw.userVersion = 1;

    final AppDatabase db = await openOver(raw);

    expect(raw.userVersion, 2, reason: 'user_version was not advanced');

    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final Set<String> tables = rows
        .map((QueryRow r) => r.read<String>('name'))
        .toSet();

    expect(tables, contains('user_profiles'));
    expect(tables, contains('consumable_instances'));
    expect(tables, contains('notification_schedules'));
    expect(tables, hasLength(11));
  });

  test('a v1 upgrade also creates the partial unique indexes', () async {
    final sqlite.Database raw = sqlite.sqlite3.openInMemory();
    addTearDown(raw.close);
    raw.userVersion = 1;

    final AppDatabase db = await openOver(raw);

    final List<QueryRow> rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final Set<String> indexes = rows
        .map((QueryRow r) => r.read<String>('name'))
        .toSet();

    // These carry the app's core invariants. An upgrade that created the
    // tables but not these would leave an older install quietly able to record
    // two sensors on at once.
    expect(indexes, contains('idx_one_active_instance_per_type'));
    expect(indexes, contains('idx_one_open_usage_per_site'));
  });

  test('a fresh database lands directly on the current version', () async {
    final sqlite.Database raw = sqlite.sqlite3.openInMemory();
    addTearDown(raw.close);

    expect(raw.userVersion, 0, reason: 'expected an empty database');

    await openOver(raw);

    expect(raw.userVersion, 2);
  });

  test('reopening an up-to-date database changes nothing', () async {
    final sqlite.Database raw = sqlite.sqlite3.openInMemory();
    addTearDown(raw.close);

    final AppDatabase first = AppDatabase(
      executor: NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await first.customSelect('SELECT 1').get();
    await first.customStatement(
      "INSERT INTO consumable_types "
      '(id, name, category, tracks_cycle, tracks_inventory, '
      'default_reminder_offsets, is_built_in, active, created_at, updated_at) '
      "VALUES ('type-0000000000000000000000000001', 'Sensor', 'cgmSensor', "
      "1, 1, '', 0, 1, '2026-08-17T09:00:00.000Z', "
      "'2026-08-17T09:00:00.000Z')",
    );
    await first.close();

    final AppDatabase second = await openOver(raw);

    expect(raw.userVersion, 2);
    final List<QueryRow> rows = await second
        .customSelect('SELECT name FROM consumable_types')
        .get();
    expect(
      rows.single.read<String>('name'),
      'Sensor',
      reason: 'reopening must not drop or recreate existing data',
    );
  });
}
