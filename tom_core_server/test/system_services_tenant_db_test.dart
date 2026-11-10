/// The system services over SQL tables, per tenant, against a real MariaDB or
/// PostgreSQL: two shared tenants, `acme` and `globex`, in the system schema.
///
/// Asserted: a blob reference source over a tenant table, asked outside any
/// tenant — the orphan sweep's own job — answers every tenant's references,
/// and in a tenant that tenant's; field re-encryption passes over the rows of
/// its place, and its job, planned per tenant and for the system, reaches
/// every tenant; the SQL audit-question store deletes a purged tenant's
/// questions by their owner, a tenant id holding `_` included.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; `tool/run_db_tests.sh` and `tool/run_db_tests_postgres.sh` start
/// one.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTenantDocument, FixtureTenantDocumentRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const String _documentDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_document (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id  VARCHAR(32)  NULL,
  attachment VARCHAR(255) NULL,
  secret     TEXT         NULL,
  PRIMARY KEY (id)
)''';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('system services per tenant', () {
    late TomDataSourceInfo base;
    late TomTenancy tenancy;
    late FixtureTenantDocumentRepository documents;
    final kek = TomAesKeyEncryptionKey('kek-1', List.filled(32, 7));

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      await TestDatabase.execute(base.datasource, _documentDdl);
      tenancy = TomTenancy(
        tenants: [TomTenant('acme'), TomTenant('globex')],
        datasources: {TestDatabase.datasourceName},
      );
      await TomTenancy.install(tenancy);
      final keys = TomSqlDataKeyStore(TestDatabase.datasourceName);
      for (final tenant in ['acme', 'globex']) {
        await tenancy.runFor(tenant, keys.deleteAll);
      }
      await TomFieldEncryption.install(
        TomFieldKeyring(store: keys, keys: [kek]),
      );
      documents = FixtureTenantDocumentRepository();
      for (final tenant in ['acme', 'globex']) {
        await tenancy.runFor(
          tenant,
          () => documents.save(
            FixtureTenantDocument()
              ..attachment = 'fixture/tenant_document/$tenant'
              ..secret = 'secret of $tenant',
          ),
        );
      }
    });

    tearDownAll(() async {
      if (!reachable) return;
      TomFieldEncryption.reset();
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    test(
      'SSD-1: a reference source over a tenant table answers every '
      'tenant\'s references outside a tenant, and a tenant\'s in it',
      () async {
        final source = TomRepositoryBlobReferences<FixtureTenantDocument, int>(
          documents,
        );
        final keys = [
          'fixture/tenant_document/acme',
          'fixture/tenant_document/globex',
          'fixture/tenant_document/nobody',
        ];
        expect(await source.referenced(keys), {
          'fixture/tenant_document/acme',
          'fixture/tenant_document/globex',
        });
        expect(await tenancy.runFor('acme', () => source.referenced(keys)), {
          'fixture/tenant_document/acme',
        });
      },
      skip: skipReason,
    );

    test(
      'SSD-2: re-encryption passes over the rows of its place; its job, '
      'planned per tenant and for the system, reaches every tenant',
      () async {
        final pass = TomFieldReencryption(entities: [FixtureTenantDocument]);
        expect(
          (await pass.run()).examined,
          0,
          reason: 'outside any tenant only system tables are passed over',
        );
        expect((await tenancy.runFor('acme', pass.run)).examined, 1);

        var clock = DateTime.utc(2026, 11, 10, 10, 30);
        final store = TomMemoryJobStore();
        final scheduler = TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          clock: () => clock,
        );
        addTearDown(scheduler.close);
        scheduler.register(
          pass.job(schedule: TomIntervalSchedule(const Duration(hours: 1))),
        );
        await scheduler.tick();
        expect((await store.all()).map((r) => r.tenant).toSet(), {
          null,
          'acme',
          'globex',
        });
        clock = clock.add(const Duration(hours: 1));
        await scheduler.tick();
        await scheduler.drain();
        final results = {
          for (final run in await store.all())
            if (run.state == TomJobRunState.succeeded) run.tenant: run,
        };
        expect(results.keys.toSet(), {null, 'acme', 'globex'});
      },
      skip: skipReason,
    );

    test('SSD-3: the SQL question store deletes a purged tenant\'s '
        'questions by their owner\'s tenant only', () async {
      final questions = TomSqlAuditQuestionStore(base.datasource);
      TomAuditQuestion question(String id, String owner) => TomAuditQuestion(
        id: id,
        name: id,
        owner: owner,
        filter: TomAuditQuestionFilter(),
        recipients: const ['auditor@example.com'],
      );
      await questions.save(question('q1', 'tenant:a_b/u1'));
      await questions.save(question('q2', 'tenant:axb/u1'));
      await questions.save(question('q3', 'u1'));
      expect(await questions.purgeTenant('a_b'), 1);
      expect(await questions.find('q1'), isNull);
      expect(
        await questions.find('q2'),
        isNotNull,
        reason: '`_` is not a wildcard here',
      );
      expect(await questions.find('q3'), isNotNull);
      for (final id in ['q2', 'q3']) {
        await questions.remove(id);
      }
    }, skip: skipReason);
  }, skip: skipReason);
}
