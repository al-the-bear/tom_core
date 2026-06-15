import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the db_migration module.
///
/// The orchestrator ([TomDbMigrations]) and the MariaDB adaptor need a live
/// data source and reflection codegen, so they are exercised through
/// `doc/db_migration.md` and integration tests, not here. This suite pins the
/// types a caller touches without a database: the [TomDbMigrationAdaptor] type
/// binding, the [TomDbVersion] row type, and the two exception types.
void main() {
  group('TomDbMigrationAdaptor', () {
    test('binds a migrator to a data-source type', () {
      const adaptor = TomDbMigrationAdaptor('mariadb');
      expect(adaptor.type, 'mariadb');
    });
  });

  group('TomDbVersion', () {
    test('has zero/empty defaults before any migration is recorded', () {
      final version = TomDbVersion();
      expect(version.installedRank, 0);
      expect(version.version, 0);
      expect(version.description, '');
      expect(version.script, '');
      expect(version.checksum, '');
      expect(version.installedBy, '');
      expect(version.success, 0);
    });

    test('records the fields of a single applied migration', () {
      final version = TomDbVersion()
        ..installedRank = 1
        ..version = 2
        ..description = 'add_orders'
        ..script = 'CREATE TABLE orders (id INT PRIMARY KEY);'
        ..checksum = '12345'
        ..success = 1;
      expect(version.installedRank, 1);
      expect(version.version, 2);
      expect(version.description, 'add_orders');
      expect(version.script, 'CREATE TABLE orders (id INT PRIMARY KEY);');
      expect(version.checksum, '12345');
      expect(version.success, 1);
    });
  });

  group('exception types', () {
    test('TomDbMigrationException is a TomServerException', () {
      final exception = TomDbMigrationException('key', 'message');
      expect(exception, isA<TomServerException>());
      expect(exception.key, 'key');
    });

    test('MariadbMigrationException is a TomServerException', () {
      final exception = MariadbMigrationException('key', 'message');
      expect(exception, isA<TomServerException>());
      expect(exception.key, 'key');
    });
  });
}
