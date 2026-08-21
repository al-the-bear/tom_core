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
/// version-ordering and anchored-name validation are
/// unit-testable.
void main() {
  // C-16 production-safety default: with no environment initialized on
  // TomRuntime, resolveActiveEnvironment falls back to the default environment
  // — under which only untagged migrations apply. Declared first so it observes
  // the pristine (uninitialized) TomRuntime before any later group sets it.
  group('C-16 uninitialized-environment fallback', () {
    test('falls back to the default environment when none is set', () {
      expect(
        TomDbMigrations.resolveActiveEnvironment(),
        defaultTomEnvironment.env,
      );
      final ordered = TomDbMigrations.orderMigrationNames([
        '[0]-schema',
        '[1]-demo_seed@dev',
      ]);
      // Under the default fallback, the @dev seed is skipped — production-safe.
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0],
      );
    });
  });

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

  // The validation pattern must be anchored to the whole basename, so
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

    test('rejects a name with surrounding text', () {
      // An unanchored regex would accept this as version 5 / "temp".
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

    test('rejects a description containing a digit', () {
      // A description group that stops at the first digit would silently
      // truncate this to "add_orders_" instead of rejecting it.
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

  // Ordering must be by the numeric version, not lexicographic, so a
  // schema with more than nine versions still runs in numeric order.
  group('TomDbMigrations.orderMigrationNames', () {
    test('orders by numeric version, so [2] precedes [10]', () {
      // Lexicographically '[10]-...' sorts before '[2]-...'; numerically it must
      // come after.
      final ordered = TomDbMigrations.orderMigrationNames([
        '[10]-c',
        '[2]-b',
        '[1]-a',
      ]);
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

  // A multi-statement migration script must be split into individual
  // statements before it is sent. The underlying mysql_client only half-reads a
  // multi-statement command — it consumes the first result set and leaves the
  // rest, desyncing the single shared connection so every later read returns
  // stale data (a first-boot seed sees an empty users table even though the
  // migration committed its rows). These tests pin that splitter.
  group('MariadbMigrationAdaptor.splitSqlStatements', () {
    test('splits a multi-statement script into its statements', () {
      const sql =
          'CREATE TABLE a (id INT);\n'
          'CREATE TABLE b (id INT);\n'
          'INSERT INTO a VALUES (1);';
      expect(MariadbMigrationAdaptor.splitSqlStatements(sql), [
        'CREATE TABLE a (id INT)',
        'CREATE TABLE b (id INT)',
        'INSERT INTO a VALUES (1)',
      ]);
    });

    test('returns the single statement for a single-statement script', () {
      expect(MariadbMigrationAdaptor.splitSqlStatements('SELECT 1;'), [
        'SELECT 1',
      ]);
    });

    test('drops the empty tail after a trailing semicolon', () {
      expect(MariadbMigrationAdaptor.splitSqlStatements('SELECT 1;\n\n'), [
        'SELECT 1',
      ]);
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

  // C-16: an optional `@<env>[,<env>…]` tag on the description selects the
  // environment(s) a migration belongs to; untagged migrations apply
  // everywhere. These pin the tag parse, the per-environment predicate, and the
  // pure selection that the engine drives from TomRuntime.
  group('C-16 environment tag parsing', () {
    test('an untagged name parses to an empty (all-environments) tag', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[0]-app_core');
      expect(parsed.version, 0);
      expect(parsed.description, 'app_core');
      expect(parsed.environments, isEmpty);
    });

    test('a single @env tag parses to a one-element list', () {
      final parsed = TomDbMigrations.parseMigrationFileName(
        '[3]-demo_seed@dev',
      );
      expect(parsed.version, 3);
      expect(parsed.description, 'demo_seed');
      expect(parsed.environments, ['dev']);
    });

    test('a comma list parses to each environment in file order', () {
      final parsed = TomDbMigrations.parseMigrationFileName(
        '[4]-perf_probe@dev,test',
      );
      expect(parsed.description, 'perf_probe');
      expect(parsed.environments, ['dev', 'test']);
    });

    test('rejects a trailing comma in the tag', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@dev,'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects a digit inside an environment name', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@dev,env2'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects an empty tag (bare @)', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });

  group('TomMigrationFileName.appliesInEnvironment', () {
    test('an untagged migration applies in every environment', () {
      const untagged = TomMigrationFileName(0, 'schema');
      expect(untagged.appliesInEnvironment('prod'), isTrue);
      expect(untagged.appliesInEnvironment('dev'), isTrue);
      expect(untagged.appliesInEnvironment('anything'), isTrue);
    });

    test('a tagged migration applies only for a listed environment', () {
      const tagged = TomMigrationFileName(3, 'demo_seed', ['dev', 'test']);
      expect(tagged.appliesInEnvironment('dev'), isTrue);
      expect(tagged.appliesInEnvironment('test'), isTrue);
      expect(tagged.appliesInEnvironment('prod'), isFalse);
    });
  });

  // The C-16 done-bar: the same demo-seed migration applies under `dev` and is
  // skipped under `prod`, while every untagged (schema) migration applies in
  // both. Proven here at the pure-selection level (the actual applyMigration DB
  // write is the live-DB follow-up) so it is verified "at two environment
  // values" without a connection.
  group('TomDbMigrations.selectForEnvironment (C-16 done-bar)', () {
    final ordered = TomDbMigrations.orderMigrationNames([
      '[0]-app_core_schema',
      '[1]-authz_grants',
      '[2]-admin_seed@prod,dev,test',
      '[3]-demo_seed@dev,test',
      '[4]-perf_probe@dev',
    ]);

    test('under dev the demo seed and probe are included', () {
      final selected = TomDbMigrations.selectForEnvironment(ordered, 'dev');
      expect(selected.map((e) => e.parsed.version), [0, 1, 2, 3, 4]);
    });

    test('under prod the @dev/@test-only migrations are skipped', () {
      final selected = TomDbMigrations.selectForEnvironment(ordered, 'prod');
      // Untagged schema (0,1) and the @prod-tagged admin seed (2) survive; the
      // demo seed (3, @dev,test) and probe (4, @dev) are dropped — no rows.
      expect(selected.map((e) => e.parsed.version), [0, 1, 2]);
      expect(
        selected.every((e) => e.parsed.appliesInEnvironment('prod')),
        isTrue,
      );
    });
  });

  // The engine resolves the active environment via TomRuntime (never a raw
  // Platform read, G-ENV-1). TomRuntime is global static state; dart test runs
  // this file in its own isolate, so setting the environment here does not leak
  // to other files.
  group('TomDbMigrations.resolveActiveEnvironment', () {
    test('reads the environment set on TomRuntime and drives selection', () {
      final ordered = TomDbMigrations.orderMigrationNames([
        '[0]-schema',
        '[1]-demo_seed@dev',
      ]);

      TomRuntime.addEnvironment(
        const TomEnvironment('dev', isDevelopment: true),
      );
      TomRuntime.addEnvironment(const TomEnvironment('prod'));

      TomRuntime.setCurrentEnvironment('dev');
      expect(TomDbMigrations.resolveActiveEnvironment(), 'dev');
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0, 1],
      );

      TomRuntime.setCurrentEnvironment('prod');
      expect(TomDbMigrations.resolveActiveEnvironment(), 'prod');
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0],
      );
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
