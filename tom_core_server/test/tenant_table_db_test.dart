/// Tenant tables and system tables against a live database, under every place
/// a tenant's rows can live — the system schema (a shared tenant of the type
/// `default`), its type's shared schema, a schema of its own, a database of its
/// own:
///
/// - a tenant table's rows land where the tenant's data lives, a system
///   table's in the system schema, also when written inside a tenant;
/// - the tenant predicate holds in every model;
/// - one transaction holding a tenant table and a system table is one branch
///   where they share a data source or the tenant's connection reaches the
///   system schema (the system table qualified on it), is refused where it does
///   not and one of them commits in one phase, and commits in two phases where
///   both are `*_xa`;
/// - sync keeps a tenant table's change log beside the tenant's rows;
/// - retention, run with no tenant, is applied in every tenant.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; run it with tool/run_db_tests.sh (MariaDB) or
/// tool/run_db_tests_postgres.sh (PostgreSQL).
@Tags(['db'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const String _tenantNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_note (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32)  NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _systemNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_system_note (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  text VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _softNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_soft_note (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  version    BIGINT       NOT NULL DEFAULT 0,
  text       VARCHAR(255) NULL,
  deleted_at DATETIME(6)  NULL,
  PRIMARY KEY (id)
)''';

const String _softNoteHistoryDdl = '''
CREATE TABLE IF NOT EXISTS fixture_soft_note_history (
  history_id     BIGINT       NOT NULL AUTO_INCREMENT,
  history_action VARCHAR(16)  NOT NULL,
  history_at     DATETIME(6)  NOT NULL,
  history_by     VARCHAR(255) NULL,
  id             BIGINT       NOT NULL,
  version        BIGINT       NOT NULL,
  text           VARCHAR(255) NULL,
  deleted_at     DATETIME(6)  NULL,
  PRIMARY KEY (history_id)
)''';

const String _tenantSyncNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_sync_note (
  id        VARCHAR(64)  NOT NULL,
  tenant_id VARCHAR(32)  NULL,
  version   BIGINT       NOT NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _tenantVisitDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_visit (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  tenant_id  VARCHAR(32) NULL,
  visitor_id BIGINT      NULL,
  at         DATETIME(6) NULL,
  PRIMARY KEY (id)
)''';

/// Where the tenants of one group keep their tenant tables.
enum _Placement {
  /// Shared isolation, type `default`: the system schema.
  systemSchema,

  /// Shared isolation, type `standard`: the type's shared schema.
  typeSchema,

  /// A schema of each tenant's own.
  ownSchema,

  /// A database of each tenant's own.
  ownDatabase,
}

Future<int> _count(
  TomDataSourceInfo info,
  String table, [
  String where = '',
]) async {
  final rows = await info.datasource.executeQuery<TomCountResult>(
    'SELECT COUNT(*) AS count FROM $table $where',
  );
  return rows.single.count;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';
  final name = TestDatabase.datasourceName;

  group('tenant tables and system tables', () {
    late TomDataSourceInfo base;
    late Directory trees;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      for (final ddl in [
        _tenantNoteDdl,
        _systemNoteDdl,
        _softNoteDdl,
        _softNoteHistoryDdl,
        _tenantSyncNoteDdl,
        _tenantVisitDdl,
      ]) {
        await TestDatabase.execute(base.datasource, ddl);
      }
      trees = Directory.systemTemp.createTempSync('tom_tenant_tables_');
      for (final type in ['default', 'standard']) {
        Directory(
          TomTenantType.treeUnder(trees.path, type),
        ).createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      trees.deleteSync(recursive: true);
      await TestDatabase.reset();
    });

    for (final placement in _Placement.values) {
      group('placed in ${placement.name}', () {
        late TomTenancy tenancy;
        final schemas = <String>[];
        final databases = <String>[];

        TomDataSourceInfo routed() =>
            TomDataSourceInfo.getDataSourceInfo(name)!;

        setUpAll(() async {
          TomTenant tenant(String id) => switch (placement) {
            _Placement.systemSchema => TomTenant(id),
            _Placement.typeSchema => TomTenant(id, type: 'standard'),
            _Placement.ownSchema => TomTenant(
              id,
              isolation: TomTenantIsolation.schema,
            ),
            _Placement.ownDatabase => TomTenant(
              id,
              isolation: TomTenantIsolation.database,
              datasources: {
                name: {
                  ...(TestDatabase.datasourceConfig[name] as Map)
                      .cast<String, Object>(),
                  'databaseName': '${TestDatabase.databaseName}_tt$id',
                },
              },
            ),
          };
          switch (placement) {
            case _Placement.typeSchema:
              schemas.add('${TestDatabase.databaseName}_standard');
            case _Placement.ownSchema:
              schemas.addAll([
                for (final id in ['acme', 'globex'])
                  '${TestDatabase.databaseName}_$id',
              ]);
            case _Placement.ownDatabase:
              for (final id in ['acme', 'globex']) {
                final database = '${TestDatabase.databaseName}_tt$id';
                databases.add(database);
                await TestDatabase.createDatabase(base.datasource, database);
              }
            case _Placement.systemSchema:
              break;
          }
          tenancy = TomTenancy(
            tenants: [tenant('acme'), tenant('globex')],
            types: [
              for (final type in ['default', 'standard'])
                TomTenantType(
                  type,
                  migrations: TomTenantType.treeUnder(trees.path, type),
                ),
            ],
            datasources: {name},
            createSchemas: true,
          );
          await TomTenancy.install(tenancy);
          // The tenant tables, where each tenant's data lives.
          await tenancy.forEachTenant((_) async {
            for (final ddl in [
              _tenantNoteDdl,
              _tenantSyncNoteDdl,
              _tenantVisitDdl,
              // A decoy of the system table where the tenant lives: a system
              // statement left unqualified on the tenant's connection would
              // land here instead of failing.
              _systemNoteDdl,
            ]) {
              await TestDatabase.execute(routed().datasource, ddl);
            }
          });
        });

        tearDownAll(() async {
          TomSync.reset();
          TomPrivacy.reset();
          await TomTenancy.reset();
          for (final schema in schemas) {
            await TestDatabase.dropSchema(base.datasource, schema);
          }
          for (final database in databases) {
            await TestDatabase.dropDatabase(base.datasource, database);
          }
        });

        setUp(() async {
          for (final table in [
            'fixture_tenant_note',
            'fixture_system_note',
            'fixture_soft_note',
            'fixture_soft_note_history',
            'fixture_tenant_visit',
          ]) {
            await base.datasource.executeCommand('DELETE FROM $table');
          }
          await tenancy.forEachTenant((_) async {
            for (final table in [
              'fixture_tenant_note',
              'fixture_tenant_visit',
              'fixture_system_note',
            ]) {
              await routed().datasource.executeCommand('DELETE FROM $table');
            }
          });
        });

        test('TTB-1: tenant rows land where the tenant lives, system rows in '
            'the system schema; the predicate holds in every model', () async {
          final tenantNotes = FixtureTenantNoteRepository();
          final systemNotes = FixtureSystemNoteRepository();
          for (final id in ['acme', 'globex']) {
            await tenancy.runFor(id, () async {
              await tenantNotes.save(FixtureTenantNote()..text = '$id note');
              await systemNotes.save(FixtureSystemNote()..text = '$id entry');
            });
          }
          // A system table is the deployment's, in the system schema: both
          // tenants' entries, seen from either.
          expect(await _count(base, 'fixture_system_note'), 2);
          for (final id in ['acme', 'globex']) {
            expect(
              (await tenancy.runFor(id, systemNotes.findAll)).length,
              2,
              reason: 'a system table is not filtered by tenant',
            );
          }
          // A tenant table is the tenant's, where its data lives.
          final acmeRoute = await tenancy.runFor('acme', routed);
          switch (placement) {
            case _Placement.systemSchema:
              expect(acmeRoute, same(base));
              expect(await _count(base, 'fixture_tenant_note'), 2);
            case _Placement.typeSchema:
              expect(acmeRoute.name, '$name@type.standard');
              expect(await tenancy.runFor('globex', routed), same(acmeRoute));
              expect(await _count(acmeRoute, 'fixture_tenant_note'), 2);
              expect(await _count(base, 'fixture_tenant_note'), 0);
            case _Placement.ownSchema || _Placement.ownDatabase:
              expect(acmeRoute.name, '$name@acme');
              expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);
              expect(await _count(base, 'fixture_tenant_note'), 0);
          }
          // A row of another tenant where acme's data lives stays invisible.
          await acmeRoute.datasource.executeCommand(
            "INSERT INTO fixture_tenant_note (tenant_id, text) "
            "VALUES ('umbrella', 'stray')",
          );
          expect(
            (await tenancy.runFor(
              'acme',
              tenantNotes.findAll,
            )).map((n) => n.text),
            ['acme note'],
          );
        });

        /// Whether the tenant's connection reaches the system schema: a type's
        /// shared schema and a schema of its own do; a database of its own on
        /// the same server does on MariaDB, whose databases are its schemas,
        /// and not on PostgreSQL, where another database cannot be named.
        bool reachesSystem() => switch (placement) {
          _Placement.systemSchema => false,
          _Placement.typeSchema || _Placement.ownSchema => true,
          _Placement.ownDatabase => !TestDatabase.isPostgres,
        };

        Matcher refusedAs(String key) => throwsA(
          isA<TomRepositoryException>().having((e) => e.key, 'key', key),
        );

        test('TTB-2: one transaction over a tenant table and a system table is '
            "one branch on a shared data source or on the tenant's connection, "
            'and refused on two one-phase data sources', () async {
          final tenantNotes = FixtureTenantNoteRepository();
          final systemNotes = FixtureSystemNoteRepository();
          Future<void> both() => tenancy.runFor(
            'acme',
            () => TomTransactionManager.runInTransaction((_) async {
              await tenantNotes.save(FixtureTenantNote()..text = 'in tx');
              await systemNotes.save(FixtureSystemNote()..text = 'in tx');
            }),
          );
          final acmeRoute = await tenancy.runFor('acme', routed);
          if (placement == _Placement.systemSchema || reachesSystem()) {
            await both();
            expect(await _count(base, 'fixture_system_note'), 1);
            expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);
            if (reachesSystem()) {
              expect(
                await _count(acmeRoute, 'fixture_system_note'),
                0,
                reason:
                    "the system row is qualified on the tenant's "
                    "connection, not written to the tenant's schema",
              );
            }
            return;
          }
          await expectLater(
            both(),
            refusedAs(TomSqlDatasourceRepository.tenantSystemTransactionKey),
          );
          expect(
            await _count(acmeRoute, 'fixture_tenant_note'),
            0,
            reason: 'the tenant write was rolled back with the transaction',
          );
          expect(await _count(base, 'fixture_system_note'), 0);
        });

        test(
          "TTB-5: on the tenant's connection the system table comes first or "
          'second, its writes roll back with the tenant\'s, and it reads its '
          'own uncommitted rows',
          () async {
            if (!reachesSystem()) return;
            final tenantNotes = FixtureTenantNoteRepository();
            final systemNotes = FixtureSystemNoteRepository();
            final acmeRoute = await tenancy.runFor('acme', routed);
            // System first, then the tenant table: one branch all the same.
            await tenancy.runFor(
              'acme',
              () => TomTransactionManager.runInTransaction((_) async {
                final entry = await systemNotes.save(
                  FixtureSystemNote()..text = 'first',
                );
                await tenantNotes.save(FixtureTenantNote()..text = 'second');
                // Reads inside the transaction see its own system row.
                expect((await systemNotes.findById(entry.id!))!.text, 'first');
                expect((await systemNotes.count()).get(), 1);
                expect(
                  (await systemNotes.findByQuerySentence('find by text = :t', {
                    't': 'first',
                  })).single.id,
                  entry.id,
                );
              }),
            );
            expect(await _count(base, 'fixture_system_note'), 1);
            expect(await _count(acmeRoute, 'fixture_system_note'), 0);
            expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);

            // A failure after both writes undoes both: they were one commit.
            await expectLater(
              tenancy.runFor(
                'acme',
                () => TomTransactionManager.runInTransaction((_) async {
                  await tenantNotes.save(FixtureTenantNote()..text = 'undone');
                  await systemNotes.save(FixtureSystemNote()..text = 'undone');
                  throw StateError('after both writes');
                }),
              ),
              throwsStateError,
            );
            expect(await _count(base, 'fixture_system_note'), 1);
            expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);
          },
        );

        test(
          "TTB-6: on the tenant's connection a system table's updates, deletes, "
          'soft deletes, restores and history are all qualified',
          () async {
            if (!reachesSystem()) return;
            final tenantNotes = FixtureTenantNoteRepository();
            final softNotes = FixtureSoftNoteRepository();
            final entry = await tenancy.runFor(
              'acme',
              () => TomTransactionManager.runInTransaction((_) async {
                await tenantNotes.save(FixtureTenantNote()..text = 'beside');
                final note = await softNotes.save(
                  FixtureSoftNote()..text = 'v1',
                );
                final updated = await softNotes.save(note..text = 'v2');
                expect(await softNotes.deleteById(updated.id!), 1);
                expect(await softNotes.findAll(), isEmpty);
                expect(await softNotes.restoreById(updated.id!), 1);
                expect((await softNotes.historyOf(updated.id!)).length, 3);
                return updated;
              }),
            );
            expect(await _count(base, 'fixture_soft_note'), 1);
            expect(await _count(base, 'fixture_soft_note_history'), 3);
            final stored = await softNotes.findById(entry.id!);
            expect(stored!.text, 'v2');
            expect(stored.deletedAt, isNull);
            // Deleted for good inside a tenant transaction as well.
            await tenancy.runFor(
              'acme',
              () => TomTransactionManager.runInTransaction((_) async {
                await tenantNotes.save(FixtureTenantNote()..text = 'again');
                await softNotes.purgeById(entry.id!);
              }),
            );
            expect(await _count(base, 'fixture_soft_note'), 0);
          },
        );

        test("TTB-7: a raw statement for a system table runs on its own data "
            "source until the transaction runs the table on the tenant's "
            'connection, and is refused after', () async {
          final systemNotes = FixtureSystemNoteRepository();
          final raw = 'SELECT * FROM fixture_system_note WHERE text = :t';
          // Raw first: the table stays on its own data source.
          await tenancy.runFor(
            'acme',
            () => TomTransactionManager.runInTransaction((_) async {
              await systemNotes.executeQueryString(raw, {'t': 'x'});
              await systemNotes.save(FixtureSystemNote()..text = 'x');
            }),
          );
          expect(await _count(base, 'fixture_system_note'), 1);
          if (!reachesSystem()) return;
          await expectLater(
            tenancy.runFor(
              'acme',
              () => TomTransactionManager.runInTransaction((_) async {
                await systemNotes.save(FixtureSystemNote()..text = 'y');
                await systemNotes.executeQueryString(raw, {'t': 'y'});
              }),
            ),
            refusedAs(TomSqlDatasourceRepository.literalOnTenantConnectionKey),
          );
          expect(await _count(base, 'fixture_system_note'), 1);
        });

        test("TTB-3: sync keeps a tenant table's change log beside the "
            "tenant's rows: each tenant pulls its own changes", () async {
          TomSync.reset();
          await TomSync.expose('tnotes', FixtureTenantSyncNoteRepository());
          final notes = FixtureTenantSyncNoteRepository();
          await tenancy.runFor(
            'acme',
            () => notes.insert(
              FixtureTenantSyncNote()
                ..id = 'n-${placement.name}'
                ..text = 'acme',
            ),
          );
          final acme = await tenancy.runFor(
            'acme',
            () => TomSync.pull('tnotes', 0),
          );
          expect(acme.changes.map((c) => c.id), ['n-${placement.name}']);
          final globex = await tenancy.runFor(
            'globex',
            () => TomSync.pull('tnotes', 0),
          );
          expect(globex.changes, isEmpty);
        });

        test(
          'TTB-4: retention applies the policies of its place, and the '
          'retention job, planned per tenant, reaches every tenant',
          () async {
            TomPrivacy.reset();
            TomPrivacy.register(FixtureTenantVisitRepository());
            final visits = FixtureTenantVisitRepository();
            final now = DateTime.utc(2026, 11, 10, 12);
            for (final id in ['acme', 'globex']) {
              await tenancy.runFor(id, () async {
                await visits.save(
                  FixtureTenantVisit()
                    ..visitorId = 1
                    ..at = now.subtract(const Duration(days: 30)),
                );
                await visits.save(
                  FixtureTenantVisit()
                    ..visitorId = 2
                    ..at = now.subtract(const Duration(days: 1)),
                );
              });
            }
            Future<List<int>> left(String id) async => [
              for (final v in await tenancy.runFor(id, visits.findAll))
                v.visitorId!,
            ]..sort();
            expect(
              await TomPrivacy.applyRetention(now: now),
              isEmpty,
              reason: 'outside any tenant only system tables are retained',
            );
            final inAcme = await tenancy.runFor(
              'acme',
              () => TomPrivacy.applyRetention(now: now),
            );
            expect(inAcme.single.affected, 1);
            expect(await left('acme'), [2]);
            expect(await left('globex'), [1, 2]);

            // The job: planned for acme, globex and the system, each run in
            // its place.
            var clock = now;
            final scheduler = TomScheduler(
              store: TomMemoryJobStore(),
              dispatcher: const TomInlineJobDispatcher(),
              clock: () => clock,
            );
            addTearDown(scheduler.close);
            scheduler.register(
              TomPrivacy.retentionJob(
                schedule: TomIntervalSchedule(const Duration(hours: 1)),
              ),
            );
            await scheduler.tick();
            final planned = await scheduler.store.all();
            expect(planned.map((r) => r.tenant).toSet(), {
              null,
              'acme',
              'globex',
            });
            clock = clock.add(const Duration(hours: 1));
            await scheduler.tick();
            await scheduler.drain();
            final runs = await scheduler.store.all();
            expect(
              runs.where((r) => r.state == TomJobRunState.succeeded).length,
              3,
            );
            expect(await left('globex'), [2]);
          },
        );
      });
    }
  }, skip: skipReason);

  group('two-phase data sources', () {
    late TomDataSourceInfo base;

    setUpAll(() async {
      initializeReflection();
      await TestDatabase.provision();
      await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
        name: <String, dynamic>{
          ...(TestDatabase.datasourceConfig[name] as Map)
              .cast<String, Object>(),
          'type': TestDatabase.isPostgres ? 'postgresql_xa' : 'mariadb_xa',
        },
      });
      base = TomDataSourceInfo.getBaseDataSourceInfo(name)!;
      await TestDatabase.execute(base.datasource, _tenantNoteDdl);
      await TestDatabase.execute(base.datasource, _systemNoteDdl);
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    test("TTB-8: on two-phase data sources a schema tenant's system write "
        "joins the tenant's branch; a tenant whose connection cannot reach "
        'the system schema commits in two phases', () async {
      final tenancy = TomTenancy(
        tenants: [
          TomTenant('acme', isolation: TomTenantIsolation.schema),
          if (TestDatabase.isPostgres)
            TomTenant(
              'globex',
              isolation: TomTenantIsolation.database,
              datasources: {
                name: {
                  ...(TestDatabase.datasourceConfig[name] as Map)
                      .cast<String, Object>(),
                  'type': 'postgresql_xa',
                  'databaseName': '${TestDatabase.databaseName}_ttxglobex',
                },
              },
            ),
        ],
        datasources: {name},
        createSchemas: true,
      );
      if (TestDatabase.isPostgres) {
        await TestDatabase.createDatabase(
          base.datasource,
          '${TestDatabase.databaseName}_ttxglobex',
        );
      }
      await TomTenancy.install(tenancy);
      Future<int> branchesOf(String tenant) async {
        final route = await tenancy.runFor(
          tenant,
          () => TomDataSourceInfo.getDataSourceInfo(name)!,
        );
        expect(route.datasource, isA<TomSqlTwoPhaseRecovery>());
        await TestDatabase.execute(route.datasource, _tenantNoteDdl);
        var participants = 0;
        await tenancy.runFor(
          tenant,
          () => TomTransactionManager.runInTransaction((transaction) async {
            await FixtureTenantNoteRepository().save(
              FixtureTenantNote()..text = 'two-phase',
            );
            await FixtureSystemNoteRepository().save(
              FixtureSystemNote()..text = 'two-phase',
            );
            participants = transaction.participantIds.length;
          }),
        );
        expect(await _count(route, 'fixture_tenant_note'), 1);
        return participants;
      }

      expect(await branchesOf('acme'), 1);
      expect(await _count(base, 'fixture_system_note'), 1);
      if (TestDatabase.isPostgres) {
        expect(await branchesOf('globex'), 2);
        expect(await _count(base, 'fixture_system_note'), 2);
      }
      // Dropped here, while the suite's database still exists.
      await TomTenancy.reset();
      await TestDatabase.dropSchema(
        base.datasource,
        '${TestDatabase.databaseName}_acme',
      );
      if (TestDatabase.isPostgres) {
        await TestDatabase.dropDatabase(
          base.datasource,
          '${TestDatabase.databaseName}_ttxglobex',
        );
      }
    });
  }, skip: skipReason ?? await TestDatabase.twoPhaseSkipReason());
}
