import 'package:blauloop/core/database/app_database.dart';
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
///
/// v3 gives each consumable type its own preferred change time. The upgrade
/// from v1 is retested there for a specific reason: `createAll` builds the
/// current schema, so a v1 upgrade that also ran the v3 step would try to add
/// a column that already exists and abort. Analysis cannot see that; only
/// opening a real v1 database can.
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

    expect(raw.userVersion, 3, reason: 'user_version was not advanced');

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

    expect(raw.userVersion, 3);
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

    expect(raw.userVersion, 3);
    final List<QueryRow> rows = await second
        .customSelect('SELECT name FROM consumable_types')
        .get();
    expect(
      rows.single.read<String>('name'),
      'Sensor',
      reason: 'reopening must not drop or recreate existing data',
    );
  });

  /// The v2 schema, written out by hand.
  ///
  /// Only the two things v3 touches: the table that gains a column, and a row
  /// in it. A full v2 dump would be more faithful and would rot the first time
  /// an unrelated table changed; this asserts what the step actually claims.
  void createV2ConsumableTypes(sqlite.Database raw) {
    raw
      ..execute(
        'CREATE TABLE consumable_types ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'category TEXT NOT NULL, '
        'default_duration_minutes INTEGER NULL, '
        'tracks_cycle INTEGER NOT NULL DEFAULT 1, '
        'tracks_inventory INTEGER NOT NULL DEFAULT 1, '
        "default_reminder_offsets TEXT NOT NULL DEFAULT '', "
        'is_built_in INTEGER NOT NULL DEFAULT 0, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'created_at TEXT NOT NULL, '
        'updated_at TEXT NOT NULL)',
      )
      ..execute(
        'INSERT INTO consumable_types '
        '(id, name, category, default_duration_minutes, tracks_cycle, '
        'tracks_inventory, default_reminder_offsets, is_built_in, active, '
        'created_at, updated_at) '
        "VALUES ('type-0000000000000000000000000001', 'Dexcom G7', "
        "'cgmSensor', 14400, 1, 1, '', 1, 1, "
        "'2026-08-17T09:00:00.000Z', '2026-08-17T09:00:00.000Z')",
      );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final List<QueryRow> rows = await db
        .customSelect('PRAGMA table_info($table)')
        .get();
    return rows.map((QueryRow r) => r.read<String>('name')).toSet();
  }

  group('v2 to v3 — a preferred change time per consumable type', () {
    test('adds the column and keeps every existing row', () async {
      final sqlite.Database raw = sqlite.sqlite3.openInMemory();
      addTearDown(raw.close);
      createV2ConsumableTypes(raw);
      raw.userVersion = 2;

      final AppDatabase db = await openOver(raw);

      expect(raw.userVersion, 3);
      expect(
        await columnsOf(db, 'consumable_types'),
        contains('preferred_change_minute_of_day'),
      );

      final List<QueryRow> rows = await db
          .customSelect(
            'SELECT name, default_duration_minutes, '
            'preferred_change_minute_of_day FROM consumable_types',
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('name'), 'Dexcom G7');
      expect(rows.single.read<int>('default_duration_minutes'), 14400);
    });

    test('leaves existing types inheriting rather than pinned', () async {
      // The upgrade must not stamp the profile's time into every row. A user
      // who installs an update has not asked for their consumables to stop
      // following their preferred time.
      final sqlite.Database raw = sqlite.sqlite3.openInMemory();
      addTearDown(raw.close);
      createV2ConsumableTypes(raw);
      raw.userVersion = 2;

      final AppDatabase db = await openOver(raw);

      final List<QueryRow> rows = await db
          .customSelect(
            'SELECT preferred_change_minute_of_day FROM consumable_types',
          )
          .get();
      expect(
        // Compared against a bare null rather than the `isNull` matcher:
        // drift exports an `isNull` of its own for building SQL expressions,
        // and the two collide in a file that imports both.
        rows.single.read<int?>('preferred_change_minute_of_day'),
        null,
        reason: 'null is what makes a type follow the profile',
      );
    });

    test('a v1 upgrade adds the column exactly once', () async {
      // The regression this file exists for. `createAll` already builds the
      // v3 schema, so a v1 upgrade that fell through to the v3 step would
      // raise "duplicate column name: preferred_change_minute_of_day" and
      // leave the install unopenable.
      final sqlite.Database raw = sqlite.sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.userVersion = 1;

      final AppDatabase db = await openOver(raw);

      expect(raw.userVersion, 3);

      final List<QueryRow> rows = await db
          .customSelect('PRAGMA table_info(consumable_types)')
          .get();
      final List<String> matches = rows
          .map((QueryRow r) => r.read<String>('name'))
          .where((String name) => name == 'preferred_change_minute_of_day')
          .toList();
      expect(matches, hasLength(1));
    });
  });
}
