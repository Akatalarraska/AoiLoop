import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dt1flow/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 0 declares no tables yet, so these tests deliberately cover the
/// *wiring* rather than any schema: that the database opens, that the
/// migration strategy runs, and that `PRAGMA foreign_keys` is actually on.
///
/// That last one is the point. SQLite silently ignores foreign keys unless the
/// pragma is set per connection, and the Phase 1 schema depends on them —
/// a ChangeEvent whose ConsumableInstance has been deleted is corrupt data.
/// Without this test the pragma could be dropped in a refactor and nothing
/// would fail until someone's history quietly lost its references.
void main() {
  late AppDatabase database;

  setUpAll(() {
    // The isolation test below opens two databases on purpose. Drift's warning
    // exists for the case where both share one QueryExecutor, which would race;
    // here each gets its own independent in-memory store, so the warning is
    // noise that would otherwise bury real failures in the test output.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('opens and reports the expected schema version', () async {
    // Forces the connection open and the migration strategy to run.
    await database.customSelect('SELECT 1').get();

    expect(database.schemaVersion, 1);
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

  test('two instances do not share in-memory state', () async {
    final AppDatabase other = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(other.close);

    await database.customStatement('CREATE TABLE probe (id INTEGER)');

    // The table must not exist in the second, isolated database.
    final List<QueryRow> tables = await other
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='probe'",
        )
        .get();

    expect(tables, isEmpty);
  });
}
