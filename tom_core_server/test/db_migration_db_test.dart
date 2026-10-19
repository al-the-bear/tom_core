/// DB-backed tests for the migration orchestrator + MariaDB adaptor.
///
/// The connection-free surface (filename parsing, ascending-version ordering,
/// environment selection, statement splitting) is covered by
/// `db_migration_test.dart`. This file exercises what only a real server can:
/// [TomDbMigrations.migrateDatabases] walking the committed migration tree and
/// [MariadbMigrationAdaptor] creating the `<schema>_versioning` table, running
/// the script, recording the applied version — and skipping it (idempotently)
/// on a second run.
///
/// The migration tree lives under `test/fixtures/migrations/` (committed, not a
/// temp dir), keyed by the registered data-source name so the orchestrator
/// resolves its migrator by the data source's `type`.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The committed migration tree root. `migrateDatabases` walks
/// `<root>/<datasourceName>/<schemaName>/[<version>]-<desc>.sql`; the
/// `tom_core_server_test` sub-directory matches the registered data source.
const String _migrationsDir = 'test/fixtures/migrations';

/// The schema directory under the data source; the adaptor maintains a
/// `<schema>_versioning` table for it.
const String _schemaName = 'fixture_schema';

/// A **second** schema under the same data source.
///
/// The fixture tree deliberately carries two, because one schema cannot
/// distinguish a migrator whose applied-version state is per `(data source,
/// schema)` pair from one whose state is per data source — and the second kind
/// aborts the run outright on the second schema, or (with the abort removed)
/// judges the second schema's migrations against the first schema's history.
/// Both fixture schemas are at version 0, which is exactly what a
/// cross-contaminated version list would misread as "already applied".
const String _secondSchemaName = 'fixture_schema_two';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('TomDbMigrations.migrateDatabases (DB-backed)', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      // Reflection first: the migrator is discovered by @TomDbMigrationAdaptor
      // metadata and TomDbVersion rows are mapped by mirror.
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() async {
      // Start each test from a clean slate: drop the versioning table and the
      // table the fixture migration creates, so a re-run genuinely re-applies.
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS ${_schemaName}_versioning',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS ${_secondSchemaName}_versioning',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS fixture_widget',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS fixture_gadget',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS fixture_quoted',
      );
      await dsi.datasource.executeCommand('DROP TABLE IF EXISTS fixture_dupe');
    });

    tearDownAll(TestDatabase.reset);

    /// Reads the applied-migration rows the adaptor records for [schema].
    Future<List<TomDbVersion>> appliedVersionsOf(String schema) =>
        dsi.datasource.executeQuery<TomDbVersion>(
          'SELECT installedRank, version, description, checksum, installedBy, '
          'installedOn, executionTimeMs, success, script '
          'FROM ${schema}_versioning ORDER BY installedRank',
        );

    /// Reads the applied-migration rows for the first fixture schema.
    Future<List<TomDbVersion>> appliedVersions() =>
        appliedVersionsOf(_schemaName);

    /// Whether [table] exists in the test database.
    Future<bool> tableExists(String table) async {
      final rows = await dsi.datasource.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM information_schema.tables '
        'WHERE table_schema = ${dsi.datasource.sqlDialect.currentSchema} '
        'AND table_name = :table',
        {'table': table},
      );
      return rows.single.count == 1;
    }

    test('applies the pending migration and records it as succeeded', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
      expect(versions.single.description, 'create_fixture_widget');
      expect(versions.single.success, 1);

      // The migration's own DDL ran: the table it creates now exists.
      expect(await tableExists('fixture_widget'), isTrue);
    });

    test('a second run is idempotent — no duplicate version rows', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      // The already-applied version is verified and skipped, not re-inserted.
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
    });

    // How long each script took is the one piece of operational data this
    // module goes out of its way to measure, and it is only useful if it
    // survives the whole round trip: measured by `applyMigration`, stored in
    // the `executionTimeMs` column, selected back by `initializeMigration`, and
    // *mapped onto the row type*. The last step is the one that was missing —
    // `TomDbVersion` had no field for the column, so the value was written,
    // selected, and then silently dropped by the mapper.
    group('the recorded execution time', () {
      test('a stored duration is readable through the row type', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        // A distinctive value, deliberately not the column's `DEFAULT 0`: a
        // row type with no `executionTimeMs` field leaves the property at its
        // Dart initialiser, which is also 0. Only a value the mapper has to
        // carry across can tell a working mapping from an absent one.
        await dsi.datasource.executeCommand(
          'UPDATE ${_schemaName}_versioning SET executionTimeMs = 4242',
        );

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        // Read through the adaptor's own loaded history, not just the test's
        // helper query — that is the list every caller sees.
        expect(adaptor.versions.single.executionTimeMs, 4242);
      });

      test('the adaptor records the duration it actually measured', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        final recorded = (await appliedVersions()).single;
        // The fixture migration is a `CREATE TABLE` sent over a socket to a
        // real server, so the elapsed time is a small positive number of
        // milliseconds. Both bounds are oracles: zero would mean the column
        // default survived (nothing was measured or nothing was written), and
        // a value this large would mean the unit is not milliseconds — the
        // stopwatch exposes microseconds on an identically-shaped getter.
        expect(recorded.executionTimeMs, greaterThan(0));
        expect(recorded.executionTimeMs, lessThan(60000));
      });

      test(
        'a failed script records the time spent before it failed',
        () async {
          await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
          final adaptor = TestDatabase.migrationAdaptor();
          await adaptor.initializeMigration(dsi, _schemaName);

          // Two statements: one that takes a known, non-trivial amount of time,
          // then one the server rejects. A migration that spent time and *then*
          // failed is the case where "how long did it take" matters most, and the
          // one a stopwatch read inside the `try`, after the loop, records
          // nothing for: the catch path never reaches it and the duration stays
          // at its initial 0. The sleep makes that falsifiable without depending
          // on how fast the server rejects bad syntax.
          await expectLater(
            adaptor.applyMigration(
              dsi,
              _schemaName,
              99,
              'deliberately_broken',
              'SELECT SLEEP(0.2); THIS IS NOT VALID SQL;',
            ),
            throwsA(isA<TomSqlMigrationException>()),
          );

          final recorded = (await appliedVersions()).firstWhere(
            (v) => v.version == 99,
          );
          // Recorded as failed — the row exists precisely so the failure is
          // visible in the table and not only in a log.
          expect(recorded.success, 0);
          expect(recorded.executionTimeMs, greaterThanOrEqualTo(200));
          // The known sleep is what makes the *unit* checkable: the true elapsed
          // time is a fifth of a second, so a stopwatch read in microseconds
          // would land around 200000 and fail here. Without a duration we
          // control, any upper bound loose enough to be safe is also loose
          // enough to accept the wrong unit.
          expect(recorded.executionTimeMs, lessThan(60000));
        },
        skip: TestDatabase.onlyOnMariaDb(
          'MariaDB records a failed script; PostgreSQL rolls it back',
        ),
      );

      test(
        'on PostgreSQL a failed script is rolled back and not recorded',
        () async {
          // PostgreSQL runs DDL in the transaction, and the adaptor runs a
          // script and its version row in one: a script that fails part-way
          // leaves neither its first statement's table nor a history row behind,
          // so the next run applies it again from the start.
          await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
          final adaptor = TestDatabase.migrationAdaptor();
          await adaptor.initializeMigration(dsi, _schemaName);
          await expectLater(
            adaptor.applyMigration(
              dsi,
              _schemaName,
              99,
              'deliberately_broken',
              'CREATE TABLE fixture_half (id BIGINT); THIS IS NOT VALID SQL;',
            ),
            throwsA(
              isA<TomSqlMigrationException>().having(
                (e) => e.key,
                'key',
                TestDatabase.migrationKey('apply_migration.failed'),
              ),
            ),
          );
          expect(
            (await appliedVersions()).where((v) => v.version == 99),
            isEmpty,
          );
          expect(await tableExists('fixture_half'), isFalse);
          // Nothing recorded as failed, so nothing refuses the next run.
          await TestDatabase.migrationAdaptor().initializeMigration(
            dsi,
            _schemaName,
          );
        },
        skip: TestDatabase.isPostgres ? null : 'PostgreSQL only',
      );
    });

    // The stability guard, end to end. `checksumOf` itself is pinned to a
    // constant in `db_migration_test.dart`; what only a server can show is that
    // the value the adaptor *writes* is that same digest, and that reading it
    // back decides correctly whether the script was edited.
    // A `success = 0` row says a script ran and did not finish, and MariaDB
    // does not roll DDL back — so what it left behind is a schema in a state
    // nobody wrote down. The column was written by this module and read by
    // nobody in it, which is how a failed migration came to be skipped from
    // then on: the version is present, and the description and the checksum
    // agree because both were written from the same script.
    group('a migration recorded as failed', () {
      /// Applies the fixture chain, then fails a script so the schema's history
      /// holds one `success = 0` row — through the real path, so the row is
      /// exactly the one a failure leaves.
      Future<void> leaveAFailedRow() async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        if (TestDatabase.isPostgres) {
          // PostgreSQL's adaptor never records a failure — it rolls the
          // script back — so the row is the one a history carried over from
          // elsewhere, or repaired by hand, would hold. The refusal is the
          // shared adaptor's rule, and holds for it all the same.
          await dsi.datasource.executeCommand(
            'INSERT INTO ${_schemaName}_versioning '
            '(version, description, script, checksum, executionTimeMs, success) '
            'VALUES (99, :description, :script, :checksum, 0, 0)',
            {
              'description': 'deliberately_broken',
              'script': 'THIS IS NOT VALID SQL;',
              'checksum': TomSqlMigrationAdaptor.checksumOf(
                'THIS IS NOT VALID SQL;',
              ),
            },
          );
          return;
        }
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        await expectLater(
          adaptor.applyMigration(
            dsi,
            _schemaName,
            99,
            'deliberately_broken',
            'THIS IS NOT VALID SQL;',
          ),
          throwsA(isA<TomSqlMigrationException>()),
        );
        expect(
          (await appliedVersions()).firstWhere((v) => v.version == 99).success,
          0,
        );
      }

      Matcher refusesTheHistory(List<int> versions) =>
          isA<TomSqlMigrationException>()
              .having(
                (e) => e.key,
                'key',
                TestDatabase.migrationKey(
                  'initialize.failed_migration_recorded',
                ),
              )
              .having((e) => e.parameters?['versions'], 'versions', versions)
              .having((e) => e.parameters?['schema'], 'schema', _schemaName);

      test('is not treated as applied on the next run', () async {
        await leaveAFailedRow();
        await expectLater(
          TestDatabase.migrationAdaptor().initializeMigration(dsi, _schemaName),
          throwsA(refusesTheHistory([99])),
        );
      });

      test('stops the whole run, not just its own version', () async {
        // The consequence the decision turns on: a schema whose middle is
        // unknown is not one later statements can be reasoned about, so the
        // orchestrator stops rather than continuing over it.
        await leaveAFailedRow();
        await expectLater(
          TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir)),
          throwsA(isA<TomSqlMigrationException>()),
        );
      });

      test('names the version and the description in its message', () async {
        // An operator holding only "a migration failed" has to go looking for
        // which one, in a table they may not know the name of.
        await leaveAFailedRow();
        try {
          await TestDatabase.migrationAdaptor().initializeMigration(
            dsi,
            _schemaName,
          );
          fail('the history holds a failed row and was accepted');
        } on TomSqlMigrationException catch (e) {
          expect(e.defaultUserMessage, contains('99'));
          expect(e.defaultUserMessage, contains('deliberately_broken'));
          expect(e.defaultUserMessage, contains('${_schemaName}_versioning'));
        }
      });

      test('leaves the adaptor unbound, so nothing runs against it', () async {
        // The refusal happens before `versions` is assigned and before the
        // binding is set, so a caller that swallowed the exception cannot go on
        // to apply migrations judged against a history that never loaded.
        await leaveAFailedRow();
        final adaptor = TestDatabase.migrationAdaptor();
        await expectLater(
          adaptor.initializeMigration(dsi, _schemaName),
          throwsA(refusesTheHistory([99])),
        );
        expect(adaptor.versions, isEmpty);
        await expectLater(
          adaptor.applyMigration(dsi, _schemaName, 1, 'anything', 'SELECT 1;'),
          throwsA(
            isA<TomSqlMigrationException>().having(
              (e) => e.key,
              'key',
              TestDatabase.migrationKey(
                'apply_migration.not_initialized_for_schema',
              ),
            ),
          ),
        );
      });

      test('repairing the row is what lets the run continue', () async {
        // The documented repair, asserted rather than described: the message
        // tells an operator to set `success = 1` once they have finished or
        // undone what the script left, and doing so unblocks the schema.
        await leaveAFailedRow();
        await dsi.datasource.executeCommand(
          'UPDATE ${_schemaName}_versioning SET success = 1 WHERE version = 99',
        );
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        expect(adaptor.versions.map((v) => v.version), contains(99));
      });

      test('deleting the row has it applied again', () async {
        // The other repair the message offers, and the one that matters when
        // the script left nothing behind: the version goes back to pending.
        await leaveAFailedRow();
        await dsi.datasource.executeCommand(
          'DELETE FROM ${_schemaName}_versioning WHERE version = 99',
        );
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        expect(adaptor.versions.map((v) => v.version), isNot(contains(99)));
      });
    });

    group('the recorded checksum', () {
      test('is the digest of the script it was recorded with', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        final recorded = (await appliedVersions()).single;
        // Paired against the row's own `script` column, so this holds whatever
        // the fixture file happens to contain — and would fail if the write
        // and the read ever disagreed about what is hashed.
        expect(
          recorded.checksum,
          TomSqlMigrationAdaptor.checksumOf(recorded.script),
        );
        // Asserted as a digest, not merely as "some string": the defect being
        // fixed wrote a decimal `String.hashCode`, which is also a non-empty
        // string and would pass a shape-blind assertion.
        expect(recorded.checksum, matches(RegExp(r'^[0-9a-f]{64}$')));
      });

      test('accepts the unchanged script on a later run', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        final recorded = (await appliedVersions()).single;

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        // The row was written by a previous `MariadbMigrationAdaptor`; this is
        // a fresh one reading it back. Re-presenting the same script must be
        // recognised as already applied and returned from quietly.
        await adaptor.applyMigration(
          dsi,
          _schemaName,
          recorded.version,
          recorded.description,
          recorded.script,
        );
        // Verified and skipped, not re-applied: still one row.
        expect(await appliedVersions(), hasLength(1));
      });

      test('rejects an edited script with checksum_mismatch', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        final recorded = (await appliedVersions()).single;

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        await expectLater(
          adaptor.applyMigration(
            dsi,
            _schemaName,
            recorded.version,
            // Same description, so the description guard cannot be what fires.
            recorded.description,
            '${recorded.script}\n-- edited after the fact',
          ),
          throwsA(
            isA<TomSqlMigrationException>().having(
              (e) => e.key,
              'key',
              TestDatabase.migrationKey('apply_migration.checksum_mismatch'),
            ),
          ),
        );
      });
    });

    // A stored checksum this adaptor could not have written is not evidence
    // that a migration was edited — it is evidence that the row came from
    // somewhere else: a hand-written repair, an older schema, a partially
    // applied insert, or the `NOT NULL DEFAULT ''` the column itself supplies.
    // Reporting it as a mismatch would send the operator hunting for an edit
    // that never happened, so it has its own key and its own message.
    group('an unreadable stored checksum', () {
      /// Applies the fixture migration, then overwrites the recorded checksum
      /// with [checksum] and re-presents the *unchanged* script to a freshly
      /// bound adaptor — so the only thing that can fail is readability.
      Future<void> expectRejectedWithKey(String checksum, String key) async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        await dsi.datasource.executeCommand(
          'UPDATE ${_schemaName}_versioning SET checksum = :checksum',
          {'checksum': checksum},
        );
        final recorded = (await appliedVersions()).single;
        // The row really does hold what the test intends — a silently rejected
        // UPDATE would make every assertion below vacuous.
        expect(recorded.checksum, checksum);

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        await expectLater(
          adaptor.applyMigration(
            dsi,
            _schemaName,
            recorded.version,
            recorded.description,
            recorded.script,
          ),
          throwsA(
            isA<TomSqlMigrationException>().having((e) => e.key, 'key', key),
          ),
        );
      }

      test('the empty string the column defaults to is refused', () async {
        // The DDL declares `checksum VARCHAR(200) NOT NULL DEFAULT ''`, so this
        // is what any row not written by applyMigration carries. It used to
        // reach `int.parse('')` and escape as a bare FormatException naming
        // neither the schema nor the migration.
        await expectRejectedWithKey(
          '',
          TestDatabase.migrationKey('apply_migration.checksum_unreadable'),
        );
      });

      test('a non-numeric value is refused', () async {
        await expectRejectedWithKey(
          'not-a-digest',
          TestDatabase.migrationKey('apply_migration.checksum_unreadable'),
        );
      });

      test('a decimal hash code — the format this module used to store — is '
          'refused as unreadable, not as a mismatch', () async {
        // A database written before the checksum became a content digest. The
        // distinction is the whole point of the separate key: these rows are
        // stale, not tampered with.
        await expectRejectedWithKey(
          '-1234567890',
          TestDatabase.migrationKey('apply_migration.checksum_unreadable'),
        );
      });

      test('the message names the schema and the version', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        await dsi.datasource.executeCommand(
          'UPDATE ${_schemaName}_versioning SET checksum = :checksum',
          {'checksum': ''},
        );
        final recorded = (await appliedVersions()).single;

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        try {
          await adaptor.applyMigration(
            dsi,
            _schemaName,
            recorded.version,
            recorded.description,
            recorded.script,
          );
          fail('an unreadable checksum must not be accepted');
        } on TomSqlMigrationException catch (e) {
          // Pinned to the key as well as the text: the mismatch message names
          // the schema and version too, so without this the assertions below
          // would still hold if the readability guard were removed entirely.
          expect(
            e.key,
            TestDatabase.migrationKey('apply_migration.checksum_unreadable'),
          );
          // One migrator instance walks every schema of every data source, so a
          // message naming only the version cannot be acted on: "version 0 is
          // unreadable" is true of a different table in each schema.
          expect(e.defaultUserMessage, contains(_schemaName));
          expect(e.defaultUserMessage, contains('${recorded.version}'));
        }
      });
    });

    // A data source with more than one schema is the shape both this module's
    // guide and TomSchemaConvergenceCheck.checkAll assume works, and it did
    // not: the orchestrator reset the migrator once per data source but
    // initialised it once per schema, so the second schema aborted the whole
    // run with `initialize.initialized_twice`. Removing only that guard would
    // have left the quieter half — the adaptor appended each schema's history
    // to the previous one's, so the second schema's version 0 read as already
    // applied.
    group('a data source with two schemas', () {
      test('applies both schemas in one run', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        // Each schema got its own versioning table and its own single row —
        // and each row is the migration belonging to *that* schema, which is
        // what a shared version list would get wrong.
        final first = await appliedVersions();
        expect(first, hasLength(1));
        expect(first.single.version, 0);
        expect(first.single.description, 'create_fixture_widget');
        expect(first.single.success, 1);

        final second = await appliedVersionsOf(_secondSchemaName);
        expect(second, hasLength(1));
        expect(second.single.version, 0);
        expect(second.single.description, 'create_fixture_gadget');
        expect(second.single.success, 1);

        // Both migrations genuinely ran. The second schema is the one at risk:
        // under the cross-contaminated reading its version 0 is "already
        // applied", so its table is never created while the run reports
        // success.
        expect(await tableExists('fixture_widget'), isTrue);
        expect(await tableExists('fixture_gadget'), isTrue);
      });

      test('re-running leaves each schema at its own single version', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        expect(await appliedVersions(), hasLength(1));
        expect(await appliedVersionsOf(_secondSchemaName), hasLength(1));
      });

      test('initializeMigration rebinds and replaces the loaded '
          'history', () async {
        // Give both schemas a recorded version 0, so a list that accumulated
        // would hold two rows after the second initialisation rather than one.
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        expect(adaptor.versions.map((v) => v.description), [
          'create_fixture_widget',
        ]);

        // The second initialisation used to abort with
        // `initialize.initialized_twice`. It now rebinds — and *replaces* the
        // loaded history rather than adding to it, so what is in hand describes
        // the second schema and nothing else.
        await adaptor.initializeMigration(dsi, _secondSchemaName);
        expect(adaptor.versions.map((v) => v.description), [
          'create_fixture_gadget',
        ]);
      });

      test('refuses to apply a migration against another schema\'s '
          'history', () async {
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        // Bound to the first schema, asked about the second: the version list
        // in hand cannot answer, and answering from it anyway is the silent
        // half of this defect.
        await expectLater(
          adaptor.applyMigration(
            dsi,
            _secondSchemaName,
            0,
            'create_fixture_gadget',
            'SELECT 1',
          ),
          throwsA(
            isA<TomSqlMigrationException>().having(
              (e) => e.key,
              'key',
              TestDatabase.migrationKey(
                'apply_migration.not_initialized_for_schema',
              ),
            ),
          ),
        );
      });
    });

    // What `initializeMigration` produces is the loaded history, and the order
    // it is in is the only part of that not already asserted above. It matters
    // because the SELECT carries no ORDER BY: without the adaptor's own sort
    // the order is whatever the server felt like, and nothing else in the suite
    // would notice.
    group('the loaded history', () {
      /// Creates the versioning table — the adaptor's own DDL — and records
      /// [versions] in that order, letting the `installedRank` identity assign
      /// install order.
      ///
      /// Written directly rather than driven through `migrateDatabases`,
      /// because the orchestrator applies files in ascending version order by
      /// construction — the very case that cannot distinguish install order
      /// from version order is the only one it can produce.
      Future<void> recordInstallOrder(List<int> versions) async {
        await dsi.datasource.executeCommand(
          TestDatabase.migrationAdaptor().versioningTableDdl(_schemaName),
        );
        for (final version in versions) {
          await dsi.datasource.executeCommand(
            'INSERT INTO ${_schemaName}_versioning (version, description, '
            'success) VALUES (:version, :description, 1)',
            {'version': version, 'description': 'migration_$version'},
          );
        }
      }

      test('comes back in installation order, not version order', () async {
        // Install order 3, 1, 2 — the ordinary shape once migrations carry
        // environment tags (C-16): an untagged [3] applies everywhere, and
        // [1]@dev / [2]@dev only reach this box later, after it is switched to
        // `dev`. Deliberately not ascending, so a list that came back in
        // version order — or in whatever order the server chose — fails here.
        await recordInstallOrder([3, 1, 2]);

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        expect(adaptor.versions.map((v) => v.version), [3, 1, 2]);
        // The ranks are ascending, which is what "installation order" means;
        // asserted separately so a sort that happened to reproduce the version
        // sequence by luck cannot pass as an install-order sort.
        expect(
          adaptor.versions.map((v) => v.installedRank),
          orderedEquals([1, 2, 3]),
        );
      });

      test('is empty, not absent, for a schema with no history', () async {
        await recordInstallOrder([]);

        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        // An empty history binds like any other: the next `applyMigration`
        // must be accepted, not refused for want of a binding.
        expect(adaptor.versions, isEmpty);
        await adaptor.applyMigration(
          dsi,
          _schemaName,
          0,
          'create_fixture_widget',
          'SELECT 1',
        );
        expect((await appliedVersions()).single.version, 0);
      });
    });

    // The outcome row is written with bound parameters. Rebuilding that
    // `INSERT` by interpolation fails seventeen tests in this file already —
    // the fixture migration's header comment contains the apostrophe in
    // "migrator's", which is enough to break an interpolated statement. So the
    // property is covered; what it is not is *named*. Nothing says the coverage
    // is the point, and rewording one comment in one fixture would retire it
    // without a word.
    //
    // This group says it, with content chosen to be hostile rather than
    // incidentally awkward, and adds the one claim nothing else makes: the
    // stored script equals the literal it was given. The existing checksum test
    // pairs the row's checksum against the row's *own* script, which is the
    // right question for detecting an edit and the wrong one for detecting that
    // both were mangled on the way in.
    //
    // What makes the failure mode worth naming is when it lands: the migration
    // has already run and changed the schema by the time the adaptor tries to
    // record it. A recording failure there is not a migration that did not
    // happen — it is one that happened and left no trace, which is the state
    // the versioning table exists to make impossible.
    group('recording a migration whose script is full of quote characters', () {
      // Single quotes, double quotes, a backslash, an apostrophe in a comment,
      // and — inside a quoted run — a semicolon, which is also the statement
      // separator. Interpolating this text produces a syntax error; splitting
      // it with anything less than a lexer cuts it in half mid-literal.
      // PostgreSQL reads a double-quoted run as an identifier, not a string,
      // so its variant quotes the apostrophe by doubling it; both keep every
      // hazard the recording has to survive.
      final script = TestDatabase.isPostgres
          ? '''
-- The operator's seed row, with a JSON payload.
CREATE TABLE IF NOT EXISTS fixture_quoted (
  id      BIGINT       NOT NULL,
  payload VARCHAR(255) NOT NULL DEFAULT '["a;b","c\\\\d"]',
  label   VARCHAR(255) NOT NULL DEFAULT 'it''s fine',
  PRIMARY KEY (id)
);'''
          : '''
-- The operator's seed row, with a JSON payload.
CREATE TABLE IF NOT EXISTS fixture_quoted (
  id      BIGINT       NOT NULL AUTO_INCREMENT,
  payload VARCHAR(255) NOT NULL DEFAULT '["a;b","c\\\\d"]',
  label   VARCHAR(255) NOT NULL DEFAULT "it's fine",
  PRIMARY KEY (id)
);''';

      test('runs and records instead of failing on the recording', () async {
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        await adaptor.applyMigration(
          dsi,
          _schemaName,
          11,
          'quoted_payload',
          script,
        );

        final recorded = (await appliedVersions()).single;
        expect(recorded.version, 11);
        // Recorded as a *success*: the distinction that matters is between a
        // script that failed and one whose recording failed, and only the
        // former may leave `success = 0`.
        expect(recorded.success, 1);
        // The script ran, so the table it declares exists.
        expect(await tableExists('fixture_quoted'), isTrue);
      });

      test('stores the script byte-for-byte, with no escaping applied', () async {
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        await adaptor.applyMigration(
          dsi,
          _schemaName,
          11,
          'quoted_payload',
          script,
        );

        // Round-tripping the text is the stronger claim, and the one the
        // checksum depends on: a value that survived an escaping round trip
        // with a doubled quote or a stripped backslash would still *store*,
        // and would then fail its own stability check on the next startup —
        // accusing an operator of editing a migration nobody touched.
        final recorded = (await appliedVersions()).single;
        expect(recorded.script, script);
        expect(
          recorded.checksum,
          TomSqlMigrationAdaptor.checksumOf(script),
          reason:
              'the stored script must still hash to what the adaptor recorded, '
              'or the next run reads this migration as edited',
        );
      });
    });

    // `versions` is documented as a snapshot taken by `initializeMigration` and
    // deliberately *not* extended as `applyMigration` runs — an applied
    // migration is written to the table, not added to the list. That is a real
    // constraint, not a footnote: the skip-if-applied check reads `versions`,
    // so within a single run the adaptor cannot see what it has just applied.
    //
    // These tests pin the contract and then follow it to its end, because the
    // consequence is what justifies guarding the *tree* rather than patching
    // the list. Appending here would mean inventing an `installedRank`,
    // `installedBy` and `installedOn` the database assigns, putting rows that
    // were never read from the versioning table into a list whose whole
    // definition is that it was — a subtler untruth than the one it fixes.
    // `orderMigrationNames` refuses the collision instead, before any script
    // runs.
    group('the applied-version list within a single run', () {
      const createSql = 'CREATE TABLE IF NOT EXISTS fixture_dupe (id BIGINT);';

      test(
        'applyMigration does not extend the snapshot it decides from',
        () async {
          final adaptor = TestDatabase.migrationAdaptor();
          await adaptor.initializeMigration(dsi, _schemaName);
          expect(adaptor.versions, isEmpty);

          await adaptor.applyMigration(
            dsi,
            _schemaName,
            1,
            'schema',
            createSql,
          );

          // The row exists; the list does not know it.
          expect(await appliedVersions(), hasLength(1));
          expect(
            adaptor.versions,
            isEmpty,
            reason:
                'the property documents itself as an initialisation snapshot; a '
                'list that grew here would have to carry a fabricated '
                'installedRank',
          );
        },
      );

      test('so one version offered twice in a run is applied twice', () async {
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        await adaptor.applyMigration(dsi, _schemaName, 1, 'schema', createSql);
        await adaptor.applyMigration(
          dsi,
          _schemaName,
          1,
          'seed',
          'INSERT INTO fixture_dupe VALUES (1);',
        );

        // Not a blessing of this outcome — a measurement of it. The skip check
        // reads `versions`, which is still empty, so nothing stops the second
        // call. This is why the collision is refused while it is still a pair
        // of filenames.
        final recorded = await appliedVersions();
        expect(recorded.map((v) => v.version), [1, 1]);
        expect(recorded.map((v) => v.description), ['schema', 'seed']);
      });

      test('and the run after that cannot tell the two rows apart', () async {
        final adaptor = TestDatabase.migrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        await adaptor.applyMigration(dsi, _schemaName, 1, 'schema', createSql);
        await adaptor.applyMigration(
          dsi,
          _schemaName,
          1,
          'seed',
          'INSERT INTO fixture_dupe VALUES (1);',
        );

        // A fresh run over the same tree: the history now holds two rows for
        // version 1, and the skip check stops at the first one whatever it is
        // offered.
        final next = TestDatabase.migrationAdaptor();
        await next.initializeMigration(dsi, _schemaName);
        expect(next.versions, hasLength(2));

        // This is the damage that outlives the run. The database is not merely
        // holding a duplicate — it is unmigratable, and it says so in the
        // language of an edited migration, sending the operator to look for a
        // change to a file nobody touched.
        await expectLater(
          next.applyMigration(
            dsi,
            _schemaName,
            1,
            'seed',
            'INSERT INTO fixture_dupe VALUES (1);',
          ),
          throwsA(
            isA<TomSqlMigrationException>().having(
              (e) => e.key,
              'key',
              TestDatabase.migrationKey('apply_migration.description_mismatch'),
            ),
          ),
        );
      });
    });
  }, skip: skipReason);
}
