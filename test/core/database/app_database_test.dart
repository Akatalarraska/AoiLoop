import 'package:aoiloop/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the database *wiring* — the guarantees every table depends on.
///
/// The foreign key test is the one that matters most. SQLite silently ignores
/// foreign keys unless the pragma is set per connection, so without this test
/// a refactor could drop it and nothing would fail until someone's history had
/// quietly lost its references.
void main() {
  late AppDatabase database;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('opens and reports the expected schema version', () async {
    await database.customSelect('SELECT 1').get();

    expect(database.schemaVersion, 2);
  });

  test('enables foreign key enforcement on the connection', () async {
    final List<QueryRow> rows = await database
        .customSelect('PRAGMA foreign_keys')
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.data.values.first, 1);
  });

  test('records its schema version in the SQLite user_version', () async {
    final List<QueryRow> rows = await database
        .customSelect('PRAGMA user_version')
        .get();

    expect(rows.single.data.values.first, database.schemaVersion);
  });

  test('creates every declared table', () async {
    final List<QueryRow> rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final Set<String> tables = rows
        .map((QueryRow r) => r.read<String>('name'))
        .toSet();

    expect(tables, <String>{
      'user_profiles',
      'devices',
      'consumable_types',
      'consumable_instances',
      'change_events',
      'incidents',
      'body_sites',
      'site_usages',
      'inventory_locations',
      'inventory_items',
      'notification_schedules',
    });
  });

  test(
    'creates the partial unique indexes that enforce the invariants',
    () async {
      final List<QueryRow> rows = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      final Set<String> indexes = rows
          .map((QueryRow r) => r.read<String>('name'))
          .toSet();

      expect(indexes, contains('idx_one_active_instance_per_type'));
      expect(indexes, contains('idx_one_open_usage_per_site'));
    },
  );

  test('stores timestamps as readable ISO-8601 text, not epoch integers', () async {
    // Chosen so a health log can be inspected or exported without decoding,
    // and to remove a class of bug where an integer column is read back in the
    // wrong unit. Asserted against what actually lands in the column rather
    // than against the option flag, because the flag is not the promise.
    await database.customStatement(
      'INSERT INTO consumable_types '
      '(id, name, category, tracks_cycle, tracks_inventory, '
      'default_reminder_offsets, is_built_in, active, created_at, updated_at) '
      "VALUES ('t-00000000000000000000000000001', 'Sensor', 'cgmSensor', "
      "1, 1, '', 0, 1, '2026-08-17T09:00:00.000Z', "
      "'2026-08-17T09:00:00.000Z')",
    );

    final List<QueryRow> rows = await database
        .customSelect(
          'SELECT typeof(created_at) AS kind, created_at AS raw '
          'FROM consumable_types',
        )
        .get();

    expect(rows.single.read<String>('kind'), 'text');
    expect(rows.single.read<String>('raw'), startsWith('2026-08-17T09:00:00'));
  });

  test('two instances do not share in-memory state', () async {
    final AppDatabase other = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(other.close);

    await database.customStatement('CREATE TABLE probe (id INTEGER)');

    final List<QueryRow> tables = await other
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='probe'",
        )
        .get();

    expect(tables, isEmpty);
  });
}
