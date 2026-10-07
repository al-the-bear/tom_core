/// Pins the `db_migration` error keys that no other suite names: the adaptor
/// scan's refusals, the orchestrator's lookups, and the MariaDB adaptor's
/// failures while initialising a schema and applying a script.
///
/// A key is the contract a caller, a log search or a translation table is
/// written against. One that no test names is a failure mode nobody checks:
/// its raise site can be deleted, reworded into a different key, or swallowed
/// by a broader catch, and every suite stays green. A migration run is the
/// worst place for that to happen unnoticed — it runs at startup, against a
/// production schema, and its error is often the only record of how far a
/// script got. Each test reaches its raise site through the smallest real
/// input and asserts the exact key.
///
/// No database is involved. The adaptor reaches its data source only through
/// `executeCommand` and `executeQuery`, which [ScriptedDataSource] answers; the
/// orchestrator's lookups fail before any data source is touched. The adaptor
/// scan reads `tomReflector.annotatedClasses`, so this file installs its own
/// reflection data (see `fixtures/scripted_reflection.dart`) rather than the
/// shared fixture's: a second adaptor for an existing type, placed in the
/// shared fixture, would break the scan for every suite that migrates.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/scripted_datasource.dart';
import 'fixtures/scripted_reflection.dart';

/// Completes with a [TomServerException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A migrator that does nothing, for the scan to register.
class _IdleMigrator implements TomDbMigrator {
  @override
  Future<void> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {}

  @override
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {}

  @override
  void reset() {}
}

/// A scripted data source whose commands fail when they start with [failing].
///
/// [ScriptedDataSource] accepts every command; a migration's failures are all
/// failures of a command, and which one fails is what separates the keys.
class _FailingCommands extends ScriptedDataSource {
  _FailingCommands(this.failing);

  final String failing;

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    if (command.trimLeft().startsWith(failing)) {
      throw StateError('scripted failure for: $command');
    }
    return BigInt.one;
  }
}

/// A registry entry over [source] that can describe itself.
///
/// The adaptor logs the entry it is given, and the registry's own description
/// reads the fields only `initialize` sets — which a scripted entry never runs.
class _ScriptedInfo extends ScriptedDataSourceInfo {
  _ScriptedInfo(super.scripted);

  @override
  String toString() => 'TomDataSourceInfo $name (scripted)';
}

void main() {
  late Directory root;

  setUp(() {
    // No adaptor at all: the orchestrator's own lookups are what is under test,
    // and an empty scan registers nothing for them to find.
    installReflectedClasses(const []);
    TomDataSourceInfo.datasources.clear();
    root = Directory.systemTemp.createTempSync('db_migration_error_keys_');
  });

  tearDown(() {
    TomDataSourceInfo.datasources.clear();
    root.deleteSync(recursive: true);
  });

  group('the adaptor scan', () {
    test('two adaptors for one data-source type are refused', () async {
      ScriptedClassMirror adaptor(String name) => ScriptedClassMirror(
        name,
        metadata: const [TomDbMigrationAdaptor('duplicated')],
        construct: _IdleMigrator.new,
      );
      installReflectedClasses([adaptor('FirstAdaptor'), adaptor('Second')]);

      await expectLater(
        TomDbMigrations.migrateDatabases(root.path),
        _throwsKey(
          'db_migration.initialization.found_more_than_one_migration_adapter',
        ),
      );
    });

    test('a class that is not a migrator is refused', () {
      expect(
        () => TomDbMigrations.instantiateMigrator('NotAMigrator', Object.new),
        _throwsKey(
          'db_migration.initialization.migrator_does_not_implement_tom_db_migrator',
        ),
      );
    });
  });

  group('TomDbMigrations.migrateDatabases', () {
    test('a directory naming no registered data source', () async {
      Directory(p.join(root.path, 'unregistered')).createSync();

      await expectLater(
        TomDbMigrations.migrateDatabases(root.path),
        _throwsKey('db_migration.migration.no_datasource_info_found'),
      );
    });

    test('a data source whose type has no migrator', () async {
      TomDataSourceInfo.datasources['orphan'] = TomDataSourceInfo(
        'orphan',
        const {},
      )..type = 'no_adaptor_for_this_type';
      Directory(p.join(root.path, 'orphan')).createSync();

      await expectLater(
        TomDbMigrations.migrateDatabases(root.path),
        _throwsKey(
          'db_migration.migration.no_migrator_found_for_datasource_type',
        ),
      );
    });
  });

  group('MariadbMigrationAdaptor.initializeMigration', () {
    test('the versioning table cannot be created', () {
      final info = _ScriptedInfo(_FailingCommands('CREATE TABLE'));
      expect(
        MariadbMigrationAdaptor().initializeMigration(info, 'app'),
        _throwsKey(
          'mariadb_migration_adapter.initialize.schema_creation_failed',
        ),
      );
    });

    test('the applied versions cannot be read', () {
      final scripted = ScriptedDataSource()
        ..answers.add(Exception('the versioning table is unreadable'));
      expect(
        MariadbMigrationAdaptor().initializeMigration(
          _ScriptedInfo(scripted),
          'app',
        ),
        _throwsKey('mariadb_migration_adapter.initialize.version_query_failed'),
      );
    });
  });

  group('MariadbMigrationAdaptor.applyMigration', () {
    Future<void> apply(String failing, String sql) async {
      final info = _ScriptedInfo(_FailingCommands(failing));
      final adaptor = MariadbMigrationAdaptor();
      await adaptor.initializeMigration(info, 'app');
      await adaptor.applyMigration(info, 'app', 1, 'create_things', sql);
    }

    test('a script statement fails', () {
      expect(
        apply('CREATE TABLE things', 'CREATE TABLE things (id INT);'),
        _throwsKey('mariadb_migration.apply_migration.failed'),
      );
    });

    test('the outcome cannot be recorded', () {
      expect(
        apply('INSERT INTO app_versioning', 'CREATE TABLE things (id INT);'),
        _throwsKey(
          'mariadb_migration.apply_migration.update_version_table_failed',
        ),
      );
    });
  });
}
