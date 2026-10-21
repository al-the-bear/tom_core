/// Down migrations and the rollback against a live database: a migration set
/// is applied, undone to a version, applied again; refusals leave the schema
/// untouched; the two-phase data-source types migrate through the same
/// adaptors.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const String _schema = 'rb_schema';
const String _xa = 'rollback_xa';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';
  final xaSkip = skip ?? await TestDatabase.twoPhaseSkipReason();

  late TomDataSource ds;
  late Directory root;
  final prefix = TestDatabase.isPostgres
      ? 'postgres_migration'
      : 'mariadb_migration';

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    ds = (await TestDatabase.register()).datasource;
    await TomDataSourceInfo.initializeDatasourceInfo({
      _xa: {
        ...TestDatabase.datasourceConfig[TestDatabase.datasourceName]
            as Map<String, dynamic>,
        'type': TestDatabase.isPostgres ? 'postgresql_xa' : 'mariadb_xa',
      },
    });
    addTearDown(TestDatabase.reset);
  });

  setUp(() async {
    if (!reachable) return;
    TomDbMigrations.resetLastRun();
    root = Directory.systemTemp.createTempSync('migration_rollback_');
    for (final table in ['${_schema}_versioning', 'rb_two', 'rb_one']) {
      await ds.executeCommand('DROP TABLE IF EXISTS $table');
    }
  });

  tearDown(() {
    if (reachable) root.deleteSync(recursive: true);
  });

  /// Writes the set under [datasource]: three migrations, each with its down
  /// script unless [without] names its version.
  void writeSet(String datasource, {int? without}) {
    final dir = Directory('${root.path}/$datasource/$_schema')
      ..createSync(recursive: true);
    void file(String name, String sql) =>
        File('${dir.path}/$name').writeAsStringSync(sql);
    file('[0]-create_one.sql', 'CREATE TABLE rb_one (id INT);');
    file('[1]-add_note.sql', 'ALTER TABLE rb_one ADD COLUMN note VARCHAR(20);');
    file('[2]-create_two.sql', 'CREATE TABLE rb_two (id INT);');
    final downs = {
      0: ('[0]-create_one.down.sql', 'DROP TABLE rb_one;'),
      1: ('[1]-add_note.down.sql', 'ALTER TABLE rb_one DROP COLUMN note;'),
      2: ('[2]-create_two.down.sql', 'DROP TABLE rb_two;'),
    };
    for (final MapEntry(:key, :value) in downs.entries) {
      if (key != without) file(value.$1, value.$2);
    }
  }

  Future<List<int>> history() async => [
    for (final v in await ds.executeQuery<TomDbVersion>(
      'SELECT installedRank, version, description, checksum, installedBy, '
      'installedOn, executionTimeMs, success, script '
      'FROM ${_schema}_versioning ORDER BY installedRank',
    ))
      v.version,
  ];

  Future<bool> exists(String table) async =>
      (await ds.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM information_schema.tables '
        'WHERE table_schema = ${ds.sqlDialect.currentSchema} '
        'AND table_name = :t',
        {'t': table},
      )).single.count ==
      1;

  Future<bool> hasNote() async =>
      (await ds.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM information_schema.columns '
        'WHERE table_schema = ${ds.sqlDialect.currentSchema} '
        "AND table_name = 'rb_one' AND column_name = 'note'",
      )).single.count ==
      1;

  final name = TestDatabase.datasourceName;

  test(
    'a set is applied, rolled back to a version, and applied again',
    () async {
      writeSet(name);
      await TomDbMigrations.migrateDatabases(root.path);
      expect(await history(), [0, 1, 2]);

      final undone = await TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: 0,
      );
      expect(undone, [2, 1], reason: 'newest first');
      expect(await history(), [0]);
      expect(await exists('rb_two'), isFalse);
      expect(await hasNote(), isFalse);
      expect(await exists('rb_one'), isTrue);

      await TomDbMigrations.migrateDatabases(root.path);
      expect(await history(), [0, 1, 2]);
      expect(await hasNote(), isTrue);
    },
    skip: skip,
  );

  test('-1 rolls back everything; nothing left to undo is no error', () async {
    writeSet(name);
    await TomDbMigrations.migrateDatabases(root.path);
    expect(
      await TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: -1,
      ),
      [2, 1, 0],
    );
    expect(await history(), isEmpty);
    expect(await exists('rb_one'), isFalse);
    expect(
      await TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: -1,
      ),
      isEmpty,
    );
  }, skip: skip);

  test('a migration without a down script refuses the rollback before '
      'anything is undone', () async {
    writeSet(name, without: 1);
    await TomDbMigrations.migrateDatabases(root.path);
    await expectLater(
      TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: 0,
      ),
      _throwsKey('$prefix.rollback_migration.no_down_script'),
    );
    expect(await history(), [0, 1, 2]);
    expect(await exists('rb_two'), isTrue, reason: '[2] was not undone');
  }, skip: skip);

  test(
    'an up script changed since it was applied refuses the rollback',
    () async {
      writeSet(name);
      await TomDbMigrations.migrateDatabases(root.path);
      File(
        '${root.path}/$name/$_schema/[2]-create_two.sql',
      ).writeAsStringSync('CREATE TABLE rb_two (id BIGINT);');
      await expectLater(
        TomDbMigrations.rollback(
          root.path,
          datasource: name,
          schema: _schema,
          toVersion: 0,
        ),
        _throwsKey('$prefix.rollback_migration.script_changed'),
      );
      expect(await history(), [0, 1, 2]);
    },
    skip: skip,
  );

  test('a down script that fails leaves the migration recorded', () async {
    writeSet(name);
    await TomDbMigrations.migrateDatabases(root.path);
    File(
      '${root.path}/$name/$_schema/[2]-create_two.down.sql',
    ).writeAsStringSync('DROP TABLE rb_no_such_table;');
    await expectLater(
      TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: 1,
      ),
      _throwsKey('$prefix.rollback_migration.failed'),
    );
    expect(await history(), [0, 1, 2]);
  }, skip: skip);

  test('rollbackFromArgs runs the rollback the command line names', () async {
    writeSet(name);
    await TomDbMigrations.migrateDatabases(root.path);
    expect(
      await TomDbMigrations.rollbackFromArgs(['port=1'], root.path),
      isFalse,
    );
    expect(
      await TomDbMigrations.rollbackFromArgs([
        '--rollback-migrations=$name/$_schema/1',
      ], root.path),
      isTrue,
    );
    expect(await history(), [0, 1]);
    for (final bad in ['$name/$_schema', '$name/$_schema/x', '/$_schema/1']) {
      await expectLater(
        TomDbMigrations.rollbackFromArgs([
          '--rollback-migrations=$bad',
        ], root.path),
        _throwsKey('db_migration.rollback.invalid_arguments'),
        reason: bad,
      );
    }
    await expectLater(
      TomDbMigrations.rollback(
        root.path,
        datasource: name,
        schema: _schema,
        toVersion: -2,
      ),
      _throwsKey('db_migration.rollback.invalid_target'),
    );
  }, skip: skip);

  test('a two-phase data source migrates and rolls back through the '
      'adaptor of its database', () async {
    writeSet(_xa);
    await TomDbMigrations.migrateDatabases(root.path);
    expect(await history(), [0, 1, 2]);
    expect(
      await TomDbMigrations.rollback(
        root.path,
        datasource: _xa,
        schema: _schema,
        toVersion: 0,
      ),
      [2, 1],
    );
    expect(await history(), [0]);
  }, skip: xaSkip);
}
