import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the db_migration module.
///
/// The MariaDB adaptor's SQL needs a live data source, so that is exercised by
/// `db_migration_db_test.dart`. This suite pins the types a caller touches
/// without a database — the [TomDbMigrationAdaptor] type binding, the
/// [TomDbVersion] row type, and the two exception types — plus the filename
/// parsing / ordering logic ([TomDbMigrations.parseMigrationFileName] and
/// [TomDbMigrations.orderMigrationNames]) extracted from the walk so the
/// version-ordering and anchored-name validation are unit-testable.
///
/// It also pins the **schema lifecycle**: [TomDbMigrations.migrateDataSource]
/// takes the migrator as an argument, so the walk over a data source's schemas
/// can be driven with a recording fake and no server at all. That matters
/// because the lifecycle was wrong and nothing here could see it — the
/// orchestrator reset the migrator once per *data source* while initialising it
/// once per *schema*, which aborted the run on the second schema and, with that
/// abort removed, would have judged the second schema's migrations against the
/// first schema's applied-version history.
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

  // The statement splitter the applier drives lives in `TomSqlLexer` and is
  // pinned by `sql_lexer_test.dart` — it is shared with the DDL reader, so it
  // is tested where it lives rather than from either consumer.

  // The recorded checksum is what decides, on every later startup, whether an
  // already-applied migration has been edited. It therefore has to mean the
  // same thing in the process that *writes* it and in every process that reads
  // it back — including one on a different SDK, platform or isolate. These pin
  // the digest to a constant, so a change of algorithm is a red suite here
  // rather than a fleet-wide `checksum_mismatch` on the next deployment.
  group('MariadbMigrationAdaptor.checksumOf', () {
    test('a known script produces a known constant digest', () {
      // The constant is the whole point: it is the contract between a row
      // written last year and the code reading it today. `String.hashCode`
      // could not be written down like this — that is what made it wrong.
      expect(
        MariadbMigrationAdaptor.checksumOf(
          'CREATE TABLE orders (id INT PRIMARY KEY);',
        ),
        '9ad9167cb37c929c8f439bcc29682d4f4b6a963310c983d1bdd35ebc21634483',
      );
    });

    test('the empty script produces the empty SHA-256', () {
      // Pins the encoding as much as the algorithm: this is the digest of zero
      // bytes, so an implementation that hashed a quoted or padded form of the
      // script would not land here.
      expect(
        MariadbMigrationAdaptor.checksumOf(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('the digest is 64 lowercase hex characters', () {
      expect(
        MariadbMigrationAdaptor.checksumOf('SELECT 1'),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });

    test('a one-character edit changes the digest', () {
      // The guard exists to catch edits, so an edit must move the value.
      expect(
        MariadbMigrationAdaptor.checksumOf('SELECT 1'),
        isNot(MariadbMigrationAdaptor.checksumOf('SELECT 2')),
      );
    });

    test('non-ASCII script text hashes by its UTF-8 bytes', () {
      // A seed migration carrying accented data is ordinary; the digest must
      // not depend on how the string happens to be represented in memory.
      expect(
        MariadbMigrationAdaptor.checksumOf("INSERT INTO t VALUES ('é');"),
        MariadbMigrationAdaptor.checksumOf("INSERT INTO t VALUES ('é');"),
      );
    });

    test('the digest fits the checksum column', () {
      // The column is VARCHAR(200); a digest longer than that would be
      // truncated on write and mismatch on every later read.
      expect(
        MariadbMigrationAdaptor.checksumOf('SELECT 1').length,
        lessThanOrEqualTo(200),
      );
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

  // A migrator's applied-version state belongs to one (data source, schema)
  // pair, so the walk has to rebind it per schema. These drive the real
  // committed fixture tree — which carries two schemas under one data source
  // precisely so this is observable — through a recording fake, and assert the
  // call sequence rather than its effect on a database.
  group('TomDbMigrations.migrateDataSource schema lifecycle', () {
    /// The committed fixture tree's data-source directory.
    final dataSourceDirectory = Directory(
      'test/fixtures/migrations/tom_core_server_test',
    );

    /// A data source the fake migrator only reads a name from — no connection
    /// is opened, and it is deliberately not registered, so this leaves no
    /// global state behind.
    TomDataSourceInfo dsi() =>
        TomDataSourceInfo('tom_core_server_test', <String, dynamic>{})
          ..type = 'mariadb';

    Future<List<String>> eventsOf(_RecordingMigrator migrator) async {
      await TomDbMigrations.migrateDataSource(
        migrator,
        dsi(),
        dataSourceDirectory,
        defaultTomEnvironment.env,
      );
      return migrator.events;
    }

    // Without two schemas in the tree the assertions below are vacuous: one
    // schema cannot distinguish per-schema from per-data-source state. So the
    // fixture's shape is asserted, not assumed.
    test('the fixture data source really has more than one schema', () {
      final schemas =
          dataSourceDirectory
              .listSync()
              .whereType<Directory>()
              .map((d) => d.path.split(Platform.pathSeparator).last)
              .toList()
            ..sort();
      expect(schemas, ['fixture_schema', 'fixture_schema_two']);
    });

    test('resets and initialises once per schema, not once per run', () async {
      final events = await eventsOf(_RecordingMigrator());

      // Two schemas, so two of each. The defect was exactly one reset for the
      // whole data source against two initialisations.
      expect(events.where((e) => e == 'reset'), hasLength(2));
      expect(events.where((e) => e.startsWith('init:')), hasLength(2));
      expect(
        events
            .where((e) => e.startsWith('init:'))
            .map((e) => e.substring(5))
            .toList()
          ..sort(),
        ['fixture_schema', 'fixture_schema_two'],
      );
    });

    test('every initialisation is preceded by its own reset', () async {
      final events = await eventsOf(_RecordingMigrator());

      for (var i = 0; i < events.length; i++) {
        if (!events[i].startsWith('init:')) continue;
        expect(
          i > 0 && events[i - 1] == 'reset',
          isTrue,
          reason:
              'Initialising without first dropping the previous schema\'s '
              'state is what let one schema\'s applied-version history stand '
              'for the next one\'s. Events: $events',
        );
      }
    });

    test('no migration is applied to a schema other than the last '
        'initialised one', () async {
      final events = await eventsOf(_RecordingMigrator());

      String? current;
      var applied = 0;
      for (final event in events) {
        if (event.startsWith('init:')) {
          current = event.substring(5);
          continue;
        }
        if (!event.startsWith('apply:')) continue;
        applied++;
        expect(
          event.split(':')[1],
          current,
          reason:
              'a migration judged against another schema\'s version list is '
              'the silent half of this defect',
        );
      }
      // Both fixture migrations reached the migrator — an assertion that
      // passes because nothing was applied would prove nothing.
      expect(applied, 2);
    });

    test('both schemas are at version 0, which is what makes the fixture '
        'discriminating', () async {
      final events = await eventsOf(_RecordingMigrator());
      final applies = events.where((e) => e.startsWith('apply:')).toList();

      // Same version, different schemas: a shared version list would read the
      // second one as already applied.
      expect(applies.map((e) => e.split(':')[2]).toSet(), {'0'});
      expect(applies.map((e) => e.split(':')[1]).toSet(), {
        'fixture_schema',
        'fixture_schema_two',
      });
    });
  });

  // The adaptor half of the same invariant. Whether a migration counts as
  // already applied is read from `versions`, which describes one schema, so
  // applying against a schema the instance is not bound to is refused rather
  // than answered from the wrong history. The mismatched-pair case needs a
  // successful initialisation and therefore a server (see
  // `db_migration_db_test.dart`); the unbound case is reachable here because
  // the guard runs before any statement is issued.
  group('MariadbMigrationAdaptor schema binding', () {
    final dsi = TomDataSourceInfo('some_ds', <String, dynamic>{});

    test('refuses to apply before initializeMigration has bound it', () async {
      await expectLater(
        MariadbMigrationAdaptor().applyMigration(
          dsi,
          'schema_a',
          0,
          'create_thing',
          'SELECT 1',
        ),
        throwsA(
          isA<MariadbMigrationException>().having(
            (e) => e.key,
            'key',
            'mariadb_migration.apply_migration.not_initialized_for_schema',
          ),
        ),
      );
    });

    test('reset leaves no applied-version state behind', () {
      final adaptor = MariadbMigrationAdaptor()
        ..versions.add(TomDbVersion()..version = 7);
      adaptor.reset();
      expect(adaptor.versions, isEmpty);
    });

    test('reset unbinds, so a later apply is refused again', () async {
      final adaptor = MariadbMigrationAdaptor()..reset();
      await expectLater(
        adaptor.applyMigration(dsi, 'schema_a', 0, 'create_thing', 'SELECT 1'),
        // The key is asserted, not merely the type: without the binding check
        // this call still throws a MariadbMigrationException — the one wrapping
        // the datasource failure it runs into next — so a type-only assertion
        // would pass whether or not the migration was refused.
        throwsA(
          isA<MariadbMigrationException>().having(
            (e) => e.key,
            'key',
            'mariadb_migration.apply_migration.not_initialized_for_schema',
          ),
        ),
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

/// A [TomDbMigrator] that records the calls it receives and does nothing else.
///
/// The subject of the lifecycle group is the *sequence* the orchestrator drives
/// a migrator through — how often it resets, when it initialises, and which
/// schema each migration is applied against. That sequence is what was wrong,
/// and it is entirely observable without a database, so this fake stands in for
/// [MariadbMigrationAdaptor] and the walk runs over the committed fixture tree
/// exactly as it would in production.
class _RecordingMigrator implements TomDbMigrator {
  /// Every call, in order: `reset`, `init:<schema>`,
  /// `apply:<schema>:<version>:<description>`.
  final List<String> events = [];

  @override
  void reset() => events.add('reset');

  @override
  Future<int> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    events.add('init:$schemaName');
    return -1;
  }

  @override
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {
    events.add('apply:$schemaName:$version:$description');
  }
}
