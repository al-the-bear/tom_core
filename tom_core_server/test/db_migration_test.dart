import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the db_migration module.
///
/// The orchestrator's directory walk and the MariaDB adaptor need a live data
/// source and reflection codegen, so those are exercised through
/// `doc/db_migration.md` and integration tests, not here. This suite pins the
/// types a caller touches without a database — the [TomDbMigrationAdaptor] type
/// binding, the [TomDbVersion] row type, and the two exception types — plus the
/// filename parsing / ordering logic ([TomDbMigrations.parseMigrationFileName]
/// and [TomDbMigrations.orderMigrationNames]) extracted from the walk so the
/// version-ordering (bug §21) and anchored-name validation (bug §22) are
/// unit-testable.
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

  // Bug §22: the validation pattern must be anchored to the whole basename, so
  // a name that merely *contains* the pattern, or whose description holds a
  // digit, is rejected rather than silently misparsed.
  group('TomDbMigrations.parseMigrationFileName', () {
    test('parses a well-formed name into version and description', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[2]-add_orders');
      expect(parsed.version, 2);
      expect(parsed.description, 'add_orders');
    });

    test('parses a multi-digit version', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[10]-add_index');
      expect(parsed.version, 10);
      expect(parsed.description, 'add_index');
    });

    test('rejects a name with surrounding text (§22a)', () {
      // Before §22 the unanchored regex accepted this as version 5 / "temp".
      expect(
        () => TomDbMigrations.parseMigrationFileName('notes_[5]-temp'),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.key,
            'key',
            'db_migration.migration.illegal_filename_in_migrations_directory',
          ),
        ),
      );
    });

    test('rejects a description containing a digit (§22b)', () {
      // Before §22 the description group stopped at the first digit, silently
      // truncating to "add_orders_" instead of rejecting.
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-add_orders_2024'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects a name with no version bracket', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('add_orders'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });

  // Bug §21: ordering must be by the numeric version, not lexicographic, so a
  // schema with more than nine versions still runs in numeric order.
  group('TomDbMigrations.orderMigrationNames', () {
    test('orders by numeric version, so [2] precedes [10]', () {
      // Lexicographically '[10]-...' sorts before '[2]-...'; numerically it must
      // come after.
      final ordered = TomDbMigrations.orderMigrationNames(
        ['[10]-c', '[2]-b', '[1]-a'],
      );
      expect(ordered.map((e) => e.parsed.version), [1, 2, 10]);
      expect(ordered.map((e) => e.basename), ['[1]-a', '[2]-b', '[10]-c']);
    });

    test('throws on any malformed name in the set', () {
      expect(
        () => TomDbMigrations.orderMigrationNames(['[1]-ok', 'bad-name']),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });

  // Bug §69: a multi-statement migration script was sent as ONE command, which
  // the underlying mysql_client only half-reads — it consumes the first result
  // set and leaves the rest, desyncing the single shared connection so every
  // later read returns stale data (the first-boot seed saw an empty users
  // table even though the migration had committed the rows). The fix splits the
  // script into individual statements; these tests pin that splitter.
  group('MariadbMigrationAdaptor.splitSqlStatements (bug §69)', () {
    test('splits a multi-statement script into its statements', () {
      const sql = 'CREATE TABLE a (id INT);\n'
          'CREATE TABLE b (id INT);\n'
          'INSERT INTO a VALUES (1);';
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        'CREATE TABLE a (id INT)',
        'CREATE TABLE b (id INT)',
        'INSERT INTO a VALUES (1)',
      ]);
    });

    test('returns the single statement for a single-statement script', () {
      expect(
        MariadbMigrationAdaptor.splitSqlStatements('SELECT 1;'),
        ['SELECT 1'],
      );
    });

    test('drops the empty tail after a trailing semicolon', () {
      expect(
        MariadbMigrationAdaptor.splitSqlStatements('SELECT 1;\n\n'),
        ['SELECT 1'],
      );
    });

    test('keeps a semicolon inside a string literal in one statement', () {
      const sql = "INSERT INTO t (s) VALUES ('a;b');\nSELECT 1;";
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        "INSERT INTO t (s) VALUES ('a;b')",
        'SELECT 1',
      ]);
    });

    test('treats a doubled quote inside a literal as an escaped quote', () {
      const sql = "INSERT INTO t (s) VALUES ('it''s; ok');\nSELECT 2;";
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        "INSERT INTO t (s) VALUES ('it''s; ok')",
        'SELECT 2',
      ]);
    });

    test('ignores a semicolon inside a line comment', () {
      const sql = 'SELECT 1; -- a comment with ; inside\nSELECT 2;';
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        'SELECT 1',
        '-- a comment with ; inside\nSELECT 2',
      ]);
    });

    test('ignores a semicolon inside a block comment', () {
      const sql = 'SELECT 1 /* ; not a split */ ;\nSELECT 2;';
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        'SELECT 1 /* ; not a split */',
        'SELECT 2',
      ]);
    });

    test('keeps a semicolon inside a quoted identifier', () {
      const sql = 'CREATE TABLE `weird;name` (id INT);\nSELECT 3;';
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        'CREATE TABLE `weird;name` (id INT)',
        'SELECT 3',
      ]);
    });

    test('returns an empty list for a whitespace-only script', () {
      expect(MariadbMigrationAdaptor.splitSqlStatements('  \n\t '), isEmpty);
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
