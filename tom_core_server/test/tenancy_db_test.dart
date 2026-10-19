/// Two tenants against a real MariaDB, under each of the three isolation
/// models: no data crosses from one tenant to the other through the
/// repositories, the caches, the revocations, the jobs or the outbox.
///
/// The same assertions run under every model — that is the point of one seam.
/// What differs is where the rows land, and the suite checks that too: in the
/// shared table under `shared`, in each tenant's schema under `schema`, and in
/// each tenant's database under `database`.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTenantNote, FixtureTenantNoteRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _noteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_note (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32)  NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

/// A count row.
Future<int> _count(TomDataSourceInfo info, String where) async {
  final rows = await info.datasource.executeQuery<TomCountResult>(
    'SELECT COUNT(*) AS count FROM fixture_tenant_note $where',
  );
  return rows.single.count;
}

/// Saves a note in the tenant the command runs in — a job body.
class _SaveNote extends TomCommand {
  _SaveNote(this.repository, this.text);

  final FixtureTenantNoteRepository repository;
  final String text;

  @override
  Future<Object?> execute() async {
    await repository.save(FixtureTenantNote()..text = text);
    return null;
  }
}

/// Records the tenant each message was delivered in.
class _RecordingTransport extends TomMessageTransport {
  final Map<String, String?> deliveredIn = {};

  @override
  TomMessageChannel get channel => TomMessageChannel.email;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    deliveredIn[message.id] = TomTenantContext.currentId;
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: 'remote-${message.id}',
    );
  }
}

/// A token for [username] in [tenant], issued a minute ago.
TomClientJwtToken _token(String username, String tenant) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final issued = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
  return TomClientJwtToken(
    '${segment({'alg': 'HS256'})}.${segment({'username': username, 'tenant': tenant, 'iat': issued.millisecondsSinceEpoch ~/ 1000})}.sig',
    decrypt: false,
  );
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('two tenants', () {
    late TomDataSourceInfo base;
    final name = TestDatabase.datasourceName;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      await TestDatabase.execute(base.datasource, _noteDdl);
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    for (final isolation in TomTenantIsolation.values) {
      group('isolated by ${isolation.name}', () {
        late TomTenancy tenancy;
        late FixtureTenantNoteRepository notes;
        final extraDatabases = <String>[];

        setUpAll(() async {
          Map<String, Object> ownDatabase(String tenant) {
            final database = '${TestDatabase.databaseName}_db$tenant';
            extraDatabases.add(database);
            return {
              name: {
                ...(TestDatabase.datasourceConfig[name] as Map)
                    .cast<String, Object>(),
                'databaseName': database,
              },
            };
          }

          TomTenant tenant(String id) => TomTenant(
            id,
            isolation: isolation,
            datasources: isolation == TomTenantIsolation.database
                ? ownDatabase(id)
                : const {},
          );
          final tenants = [tenant('acme'), tenant('globex')];
          if (isolation == TomTenantIsolation.schema) {
            for (final id in ['acme', 'globex']) {
              extraDatabases.add('${TestDatabase.databaseName}_$id');
            }
          }
          for (final database in extraDatabases) {
            if (isolation == TomTenantIsolation.database) {
              await TestDatabase.createDatabase(base.datasource, database);
            }
          }
          tenancy = TomTenancy(
            tenants: tenants,
            datasources: {name},
            createSchemas: true,
          );
          await TomTenancy.install(tenancy);
          // Routed: under schema and database isolation this creates the table
          // in each tenant's own place.
          await tenancy.forEachTenant(
            (_) => TestDatabase.execute(
              TomDataSourceInfo.getDataSourceInfo(name)!.datasource,
              _noteDdl,
            ),
          );
          notes = FixtureTenantNoteRepository();
        });

        tearDownAll(() async {
          await TomTenancy.reset();
          for (final database in extraDatabases) {
            if (isolation == TomTenantIsolation.database) {
              await TestDatabase.dropDatabase(base.datasource, database);
            } else {
              await TestDatabase.dropSchema(base.datasource, database);
            }
          }
        });

        setUp(() async {
          await base.datasource.executeCommand(
            'DELETE FROM fixture_tenant_note',
          );
          await tenancy.forEachTenant(
            (_) => TomDataSourceInfo.getDataSourceInfo(
              name,
            )!.datasource.executeCommand('DELETE FROM fixture_tenant_note'),
          );
        });

        Future<T> inTenant<T>(String tenant, FutureOr<T> Function() body) =>
            tenancy.runFor(tenant, body);

        test(
          'repositories: each tenant reads and writes only its own rows',
          () async {
            await inTenant('acme', () async {
              await notes.save(FixtureTenantNote()..text = 'acme 1');
              await notes.save(FixtureTenantNote()..text = 'acme 2');
            });
            final globexNote = await inTenant(
              'globex',
              () => notes.save(FixtureTenantNote()..text = 'globex 1'),
            );
            expect(globexNote.tenantId, 'globex', reason: 'filled on insert');

            final acmeSees = await inTenant('acme', notes.findAll);
            expect(
              acmeSees.map((n) => n.text),
              unorderedEquals(['acme 1', 'acme 2']),
            );
            expect(acmeSees.every((n) => n.tenantId == 'acme'), isTrue);
            expect(
              (await inTenant('globex', notes.findAll)).map((n) => n.text),
              ['globex 1'],
            );
            expect((await inTenant('acme', notes.count)).get(), 2);

            // Asked for by id, globex's note is not acme's to read: under the
            // stronger models the same id may name an acme row instead.
            final byId = await inTenant(
              'acme',
              () => notes.findById(globexNote.id!),
            );
            expect(byId?.text, isNot('globex 1'));

            // Nor to write: naming another tenant, or updating its row.
            await expectLater(
              inTenant(
                'acme',
                () => notes.save(
                  FixtureTenantNote()
                    ..tenantId = 'globex'
                    ..text = 'smuggled',
                ),
              ),
              throwsA(
                isA<TomDataScopeAuthorizationException>().having(
                  (e) => e.key,
                  'key',
                  'data_scope.write.foreign_tenant',
                ),
              ),
            );
            await expectLater(
              inTenant(
                'acme',
                () => notes.save(
                  FixtureTenantNote()
                    ..id = globexNote.id
                    ..tenantId = 'globex'
                    ..text = 'overwritten',
                ),
              ),
              throwsA(isA<TomDataScopeAuthorizationException>()),
            );
            expect(
              (await inTenant('globex', notes.findAll)).single.text,
              'globex 1',
            );

            // With no tenant in context, tenant data is closed.
            expect(await TomTenantContext.run(null, notes.findAll), isEmpty);
            await expectLater(
              TomTenantContext.run(
                null,
                () => notes.save(FixtureTenantNote()..text = 'nobody'),
              ),
              throwsA(
                isA<TomDataScopeAuthorizationException>().having(
                  (e) => e.key,
                  'key',
                  'data_scope.write.no_tenant',
                ),
              ),
            );

            // Where the rows physically are.
            if (isolation == TomTenantIsolation.shared) {
              expect(await _count(base, ''), 3);
              expect(await _count(base, "WHERE tenant_id = 'acme'"), 2);
            } else {
              expect(
                await _count(base, ''),
                0,
                reason: 'nothing in the shared table',
              );
              final acmeInfo = await inTenant(
                'acme',
                () => TomDataSourceInfo.getDataSourceInfo(name)!,
              );
              expect(acmeInfo, isNot(same(base)));
              expect(await _count(acmeInfo, ''), 2);
            }
          },
        );

        test('caches: two tenants caching one key hold two entries', () async {
          final cache = TomCache('tenant-notes-${isolation.name}');
          TomCacheManager.addCache(cache);
          addTearDown(() {
            TomCacheManager.removeCache(cache.cacheName);
            cache.stopTimers();
          });

          await inTenant(
            'acme',
            () => TomCache.toNameCache(cache.cacheName, 'k', 'acme value'),
          );
          expect(
            await inTenant(
              'globex',
              () => TomCache.fromNameCache<String>(cache.cacheName, 'k'),
            ),
            isNull,
          );
          await inTenant(
            'globex',
            () => TomCache.toNameCache(cache.cacheName, 'k', 'globex value'),
          );
          expect(
            await inTenant(
              'acme',
              () => TomCache.fromNameCache<String>(cache.cacheName, 'k'),
            ),
            'acme value',
          );

          // Invalidating globex's entry leaves acme's alone.
          await inTenant(
            'globex',
            () =>
                TomCacheInvalidator.invalidateCacheEntry(cache.cacheName, 'k'),
          );
          expect(
            await inTenant(
              'globex',
              () => TomCache.fromNameCache<String>(cache.cacheName, 'k'),
            ),
            isNull,
          );
          expect(
            await inTenant(
              'acme',
              () => TomCache.fromNameCache<String>(cache.cacheName, 'k'),
            ),
            'acme value',
          );
        });

        test(
          'revocation: revoking alice in one tenant leaves the other alice',
          () async {
            addTearDown(TomAuthorizationCache.instance.dispose);
            await inTenant(
              'acme',
              () => TomCacheInvalidator.revokePrincipal('alice'),
            );
            expect(
              TomAuthorizationCache.isRevoked(_token('alice', 'acme')),
              isTrue,
            );
            expect(
              TomAuthorizationCache.isRevoked(_token('alice', 'globex')),
              isFalse,
            );
          },
        );

        test(
          'jobs: a run carries its tenant, and its body writes there',
          () async {
            final store = TomSqlJobStore(
              base.datasource,
              table: 'tenancy_job_run_${isolation.name}',
            );
            final events = StreamController<Object?>.broadcast();
            final scheduler = TomScheduler(
              store: store,
              dispatcher: const TomInlineJobDispatcher(),
            );
            addTearDown(() async {
              await scheduler.close();
              await events.close();
              await base.datasource.executeCommand(
                'DROP TABLE IF EXISTS tenancy_job_run_${isolation.name}',
              );
            });
            scheduler.register(
              TomJobDefinition(
                name: 'note-from-job',
                schedule: TomEventSchedule(events.stream),
                body: (run) => _SaveNote(notes, 'job for ${run.tenant}'),
              ),
            );
            events
              ..add(TomTenantEvent('acme', null))
              ..add(TomTenantEvent('globex', null));
            // The enqueue is the scheduler's, unawaited and over real I/O.
            for (var i = 0; i < 100 && (await store.all()).length < 2; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
            expect(
              {for (final run in await store.all()) run.tenant},
              {'acme', 'globex'},
            );
            await scheduler.tick();
            await scheduler.drain();

            expect((await inTenant('acme', notes.findAll)).map((n) => n.text), [
              'job for acme',
            ]);
            expect(
              (await inTenant('globex', notes.findAll)).map((n) => n.text),
              ['job for globex'],
            );
          },
        );

        test(
          'outbox: a message is delivered inside the tenant that sent it',
          () async {
            final transport = _RecordingTransport();
            final reports = TomMemoryDeliveryReportStore();
            final outbox = TomMessageOutbox(
              router: TomMessageRouter([transport]),
              store: TomSqlJobStore(
                base.datasource,
                table: 'tenancy_outbox_${isolation.name}',
              ),
              reportStore: reports,
            );
            final receipts = <TomDeliveryReceipt>[];
            final subscription = outbox.receipts.listen(receipts.add);
            addTearDown(() async {
              await subscription.cancel();
              await outbox.close();
              await base.datasource.executeCommand(
                'DROP TABLE IF EXISTS tenancy_outbox_${isolation.name}',
              );
            });

            TomMessage mail(String id) => TomMessage.email(
              id: id,
              to: [TomRecipient('someone@example.test')],
              subject: id,
              text: id,
            );
            await inTenant('acme', () => outbox.send(mail('m-acme')));
            await inTenant('globex', () => outbox.send(mail('m-globex')));
            await outbox.tick();
            await pumpEventQueue();

            expect(transport.deliveredIn, {
              'm-acme': 'acme',
              'm-globex': 'globex',
            });
            expect(
              {for (final r in receipts) r.messageId: r.tenant},
              {'m-acme': 'acme', 'm-globex': 'globex'},
            );
            expect(
              {for (final c in reports.correlations) c.messageId: c.tenant},
              {'m-acme': 'acme', 'm-globex': 'globex'},
            );
          },
        );

        // Last in the group: it removes acme for good.
        test(
          'removing a tenant closes what was opened for it and nothing else',
          () async {
            final routed = '$name@acme';
            final opened = TomDataSourceInfo.datasources[routed];
            if (isolation != TomTenantIsolation.shared) {
              expect(opened, isNotNull, reason: 'a pool of its own');
            }

            await tenancy.removeTenant('acme');

            expect(TomDataSourceInfo.datasources.containsKey(routed), isFalse);
            if (opened != null) {
              await expectLater(
                opened.datasource.executeQuery<TomCountResult>(
                  'SELECT COUNT(*) AS count FROM fixture_tenant_note',
                ),
                throwsA(anything),
                reason: 'its pool is closed',
              );
            }
            await expectLater(
              inTenant('acme', () => null),
              throwsA(isA<TomTenancyException>()),
            );
            // The shared base and the other tenant keep working.
            expect(await _count(base, 'WHERE 1 = 1'), greaterThanOrEqualTo(0));
            await inTenant(
              'globex',
              () => notes.save(FixtureTenantNote()..text = 'after removal'),
            );
            expect(
              (await inTenant('globex', notes.findAll)).map((n) => n.text),
              contains('after removal'),
            );
          },
        );
      });
    }
  }, skip: skipReason);
}
