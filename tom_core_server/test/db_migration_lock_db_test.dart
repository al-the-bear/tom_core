/// The migration lock and the repair of a failed migration, against a live
/// database.
///
/// Two processes are two data sources on one database, each with its own pool
/// and its own migrator — the shape several replicas starting together have.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const String _schema = 'lock_schema';

/// A MariaDB migrator that counts the scripts it runs.
class _CountingMariadb extends MariadbMigrationAdaptor {
  int applied = 0;

  @override
  Future<void> applyScript(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) {
    applied++;
    return super.applyScript(dsi, schemaName, version, description, sql);
  }
}

/// A PostgreSQL migrator that counts the scripts it runs.
class _CountingPostgres extends PostgresMigrationAdaptor {
  int applied = 0;

  @override
  Future<void> applyScript(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) {
    applied++;
    return super.applyScript(dsi, schemaName, version, description, sql);
  }
}

/// A fresh counting migrator for the engine under test.
TomDbMigrator _migrator() =>
    TestDatabase.isPostgres ? _CountingPostgres() : _CountingMariadb();

int _applied(TomDbMigrator m) => switch (m) {
  _CountingMariadb() => m.applied,
  _CountingPostgres() => m.applied,
  _ => throw StateError('not a counting migrator'),
};

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo first;
  late TomDataSourceInfo second;
  late Directory root;
  late Directory schemaDir;

  Map<String, dynamic> settings() =>
      TestDatabase.datasourceConfig[TestDatabase.datasourceName]
          as Map<String, dynamic>;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    first = await TestDatabase.register();
    await TomDataSourceInfo.initializeDatasourceInfo({
      'migration_lock_second': settings(),
    });
    second = TomDataSourceInfo.getDataSourceInfo('migration_lock_second')!;
    addTearDown(TestDatabase.reset);
  });

  setUp(() async {
    if (!reachable) return;
    root = Directory.systemTemp.createTempSync('migration_lock_');
    schemaDir = Directory('${root.path}/$_schema')..createSync();
    for (final table in [
      '${_schema}_versioning',
      'lock_probe',
      'lock_second',
      'repair_probe',
      'repair_half',
    ]) {
      await first.datasource.executeCommand('DROP TABLE IF EXISTS $table');
    }
  });

  tearDown(() {
    if (reachable) root.deleteSync(recursive: true);
    TomSqlMigrationAdaptor.lockWait = const Duration(minutes: 10);
  });

  void migration(String name, String sql) =>
      File('${schemaDir.path}/$name.sql').writeAsStringSync(sql);

  Future<void> migrate(TomDbMigrator migrator, TomDataSourceInfo dsi) =>
      TomDbMigrations.migrateDataSource(migrator, dsi, root, 'prod');

  Future<List<TomDbVersion>> history() =>
      first.datasource.executeQuery<TomDbVersion>(
        'SELECT installedRank, version, description, checksum, installedBy, '
        'installedOn, executionTimeMs, success, script '
        'FROM ${_schema}_versioning ORDER BY installedRank',
      );

  final sleep = TestDatabase.isPostgres
      ? 'SELECT pg_sleep(1)'
      : 'SELECT SLEEP(1)';

  group('the migration lock', () {
    test('two migrators started together: exactly one applies', () async {
      // Neither script tolerates a second run: CREATE TABLE without IF NOT
      // EXISTS fails on the table the first run made. The sleep keeps the
      // first run inside the lock while the second arrives.
      migration(
        '[0]-create_probe',
        'CREATE TABLE lock_probe (id INT);\n$sleep;',
      );
      migration('[1]-create_second', 'CREATE TABLE lock_second (id INT);');
      final a = _migrator();
      final b = _migrator();

      await Future.wait([migrate(a, first), migrate(b, second)]);

      expect(_applied(a) + _applied(b), 2);
      expect([_applied(a), _applied(b)], contains(0));
      final rows = await history();
      expect(rows.map((r) => r.version), [0, 1]);
      expect(rows.every((r) => r.success == 1), isTrue);
    }, skip: skip);

    test('a run waits for the holder, and gives up after lockWait', () async {
      migration('[0]-create_probe', 'CREATE TABLE lock_probe (id INT);');
      final release = Completer<void>();
      final held = Completer<void>();
      final holder = (first.datasource as TomSqlDatasource).withSessionLock(
        TomSqlMigrationAdaptor.migrationLockName(
          (first.datasource as TomSqlDatasource).databaseName,
        ),
        () async {
          held.complete();
          await release.future;
        },
      );
      await held.future;
      TomSqlMigrationAdaptor.lockWait = const Duration(milliseconds: 500);

      await expectLater(
        migrate(_migrator(), second),
        _throwsKey('error.datasource.session_lock_timeout'),
      );

      release.complete();
      await holder;
      final after = _migrator();
      await migrate(after, second);
      expect(_applied(after), 1);
    }, skip: skip);

    test('a session that ends releases the lock — a dead process holds '
        'nothing', () async {
      migration('[0]-create_probe', 'CREATE TABLE lock_probe (id INT);');
      // A third "process": one connection, which takes the lock and is then
      // closed with its data source, as a dying process's connection is.
      await TomDataSourceInfo.initializeDatasourceInfo({
        'migration_lock_dying': {...settings(), 'poolMaxSize': 1},
      });
      final dying =
          TomDataSourceInfo.getDataSourceInfo(
                'migration_lock_dying',
              )!.datasource
              as TomSqlDatasource;
      final name = TomSqlMigrationAdaptor.migrationLockName(dying.databaseName);
      await dying.executeCommand(
        TestDatabase.isPostgres
            ? 'SELECT pg_advisory_lock(hashtextextended(:name, 0))'
            : 'SELECT GET_LOCK(:name, 0)',
        {'name': name},
      );
      TomSqlMigrationAdaptor.lockWait = const Duration(milliseconds: 500);
      await expectLater(
        migrate(_migrator(), first),
        _throwsKey('error.datasource.session_lock_timeout'),
      );

      await dying.close();

      final after = _migrator();
      await migrate(after, first);
      expect(_applied(after), 1);
    }, skip: skip);

    test('the lock is re-entrant: a run inside withMigrationLock does not wait '
        'for itself', () async {
      migration('[0]-create_probe', 'CREATE TABLE lock_probe (id INT);');
      TomSqlMigrationAdaptor.lockWait = const Duration(milliseconds: 500);
      final migrator = _migrator();
      await TomDbMigrations.withMigrationLock(
        TestDatabase.datasourceName,
        () => migrate(migrator, first),
      );
      expect(_applied(migrator), 1);
    }, skip: skip);
  });

  group('repair', () {
    /// Leaves version 1 recorded as failed, as MariaDB leaves a script that
    /// failed half-way: `repair_half` was created, the statement after it
    /// failed. PostgreSQL rolls a failed script back and records nothing, so
    /// there the record is written as a MariaDB server would have.
    Future<void> failVersionOne() async {
      migration('[0]-create_probe', 'CREATE TABLE repair_probe (id INT);');
      migration(
        '[1]-half_applied',
        'CREATE TABLE repair_half (id INT);\nINSERT INTO no_such_table VALUES (1);',
      );
      await expectLater(migrate(_migrator(), first), throwsA(anything));
      if (TestDatabase.isPostgres) {
        await first.datasource.executeCommand(
          'CREATE TABLE repair_half (id INT)',
        );
        await first.datasource.executeCommand(
          'INSERT INTO ${_schema}_versioning '
          '(version, description, script, checksum, success) '
          'VALUES (1, :d, :s, :c, 0)',
          {
            'd': 'half_applied',
            's': File(
              '${schemaDir.path}/[1]-half_applied.sql',
            ).readAsStringSync(),
            'c': TomSqlMigrationAdaptor.checksumOf(
              File('${schemaDir.path}/[1]-half_applied.sql').readAsStringSync(),
            ),
          },
        );
      }
      final prefix = TestDatabase.isPostgres
          ? 'postgres_migration_adapter'
          : 'mariadb_migration_adapter';
      await expectLater(
        migrate(_migrator(), first),
        _throwsKey('$prefix.initialize.failed_migration_recorded'),
      );
    }

    test('remove: the operator undoes the half, corrects the script, and the '
        'next run applies it', () async {
      await failVersionOne();
      await first.datasource.executeCommand('DROP TABLE repair_half');
      migration('[1]-half_applied', 'CREATE TABLE repair_half (id INT);');

      await TomDbMigrations.repair(
        TestDatabase.datasourceName,
        _schema,
        1,
        TomMigrationRepair.remove,
      );
      final next = _migrator();
      await migrate(next, first);

      expect(_applied(next), 1);
      final rows = await history();
      expect(rows.map((r) => (r.version, r.success)), [(0, 1), (1, 1)]);
    }, skip: skip);

    test('markResolved: the operator finishes by hand, and the next run '
        'proceeds without applying it', () async {
      await failVersionOne();
      // What the script set out to do, finished by hand: the failing INSERT
      // was the operator's to complete, and is accepted as done.
      await TomDbMigrations.repair(
        TestDatabase.datasourceName,
        _schema,
        1,
        TomMigrationRepair.markResolved,
      );
      migration('[2]-after', 'CREATE TABLE lock_second (id INT);');
      final next = _migrator();
      await migrate(next, first);

      expect(_applied(next), 1, reason: 'only [2] runs; [1] is resolved');
      final rows = await history();
      expect(rows.map((r) => (r.version, r.success)), [(0, 1), (1, 1), (2, 1)]);
    }, skip: skip);

    test('a version with no failed record is not repaired', () async {
      migration('[0]-create_probe', 'CREATE TABLE repair_probe (id INT);');
      await migrate(_migrator(), first);
      final prefix = TestDatabase.isPostgres
          ? 'postgres_migration_adapter'
          : 'mariadb_migration_adapter';
      await expectLater(
        TomDbMigrations.repair(
          TestDatabase.datasourceName,
          _schema,
          0,
          TomMigrationRepair.remove,
        ),
        _throwsKey('$prefix.repair.no_failed_record'),
      );
    }, skip: skip);

    test('repairFromArgs runs the repair the command line names', () async {
      await failVersionOne();
      final ran = await TomDbMigrations.repairFromArgs([
        'port=8080',
        '--repair-migration=${TestDatabase.datasourceName}/$_schema/1',
        '--repair-action=resolve',
      ]);
      expect(ran, isTrue);
      expect((await history()).map((r) => r.success), [1, 1]);
    }, skip: skip);
  });

  group('repairFromArgs without a database', () {
    test('no repair option: nothing runs', () async {
      expect(await TomDbMigrations.repairFromArgs(['port=8080']), isFalse);
    });

    test('a malformed request is refused', () async {
      for (final args in [
        ['--repair-migration=ds/schema', '--repair-action=remove'],
        ['--repair-migration=ds/schema/x', '--repair-action=remove'],
        ['--repair-migration=ds/schema/1', '--repair-action=rerun'],
        ['--repair-migration=ds/schema/1'],
      ]) {
        await expectLater(
          TomDbMigrations.repairFromArgs(args),
          _throwsKey('db_migration.repair.invalid_arguments'),
          reason: '$args',
        );
      }
    });
  });
}
