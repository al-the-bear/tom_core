/// The blob orphan sweep and removed tenants, against a real MariaDB or
/// PostgreSQL, for a tenant whose rows live in the system schema and for one
/// with a schema of its own.
///
/// Asserted: a removed tenant's file survives a sweep while its data is kept
/// (`TomTenancy.readRemovedTenant` asks its rows), so `restoreTenant` brings
/// back rows whose files are there; once `purgeTenant` drops its data the next
/// sweep deletes the file. A removed tenant stays unserved while it is read.
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
  final name = TestDatabase.datasourceName;
  const prefix = 'fixture/tenant_document';

  group('the orphan sweep and removed tenants', () {
    late TomDataSourceInfo base;
    late TomTenancy tenancy;
    late FixtureTenantDocumentRepository documents;
    late TomDeduplicatingBlobStore store;
    final uploadedAt = DateTime.utc(2026, 11, 1);
    final sweptAt = DateTime.utc(2026, 11, 10);
    final kek = TomAesKeyEncryptionKey('kek-1', List.filled(32, 7));

    TomBlobOrphanSweep sweep() => TomBlobOrphanSweep(
      store: store,
      sources: [
        TomRepositoryBlobReferences<FixtureTenantDocument, int>(documents),
      ],
      prefixes: const [prefix],
    );

    Future<void> upload(String key) =>
        store.put(key: key, bytes: Stream.value('content of $key'.codeUnits));

    /// A document of [tenant] naming its file, uploaded first.
    Future<void> attach(String tenant) async {
      await upload('$prefix/$tenant');
      await tenancy.runFor(
        tenant,
        () => documents.save(
          FixtureTenantDocument()..attachment = '$prefix/$tenant',
        ),
      );
    }

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      // Registered after `register`'s, so it runs first: the tenants' schemas
      // go while the suite database is still there.
      addTearDown(() async {
        TomFieldEncryption.reset();
        await TomTenancy.reset();
        for (final tenant in ['initech', 'hooli']) {
          await TestDatabase.dropSchema(
            base.datasource,
            '${TestDatabase.databaseName}_$tenant',
          );
        }
      });
      await TestDatabase.execute(base.datasource, _documentDdl);
      tenancy = TomTenancy(
        tenants: [
          // Rows in the system schema, beside the others'.
          TomTenant('acme'),
          TomTenant('umbrella'),
          // A schema of their own.
          TomTenant('initech', isolation: TomTenantIsolation.schema),
          TomTenant('hooli', isolation: TomTenantIsolation.schema),
          TomTenant('globex'),
        ],
        datasources: {name},
        createSchemas: true,
      );
      await TomTenancy.install(tenancy);
      for (final tenant in ['initech', 'hooli']) {
        await tenancy.runFor(
          tenant,
          () => TestDatabase.execute(
            TomDataSourceInfo.getDataSourceInfo(name)!.datasource,
            _documentDdl,
          ),
        );
      }
      final keys = TomSqlDataKeyStore(name);
      for (final tenant in tenancy.tenants.keys) {
        await tenancy.runFor(tenant, keys.deleteAll);
      }
      await TomFieldEncryption.install(
        TomFieldKeyring(store: keys, keys: [kek]),
      );
      documents = FixtureTenantDocumentRepository();
      store = TomDeduplicatingBlobStore(
        content: TomMemoryBlobStore(),
        ledger: TomMemoryBlobLedger(),
        clock: () => uploadedAt,
      );
      for (final tenant in ['acme', 'umbrella', 'initech', 'hooli', 'globex']) {
        await attach(tenant);
      }
      await upload('$prefix/nobody');
    });

    tearDownAll(() async {
      if (reachable) await TestDatabase.reset();
    });

    test('OSR-1: a removed tenant\'s files survive a sweep, and restoreTenant '
        'brings back rows whose files are there', () async {
      for (final tenant in ['acme', 'initech']) {
        await tenancy.suspendTenant(tenant);
        await tenancy.removeTenant(tenant);
      }
      expect(await tenancy.removedTenantIds(), ['acme', 'initech']);
      final report = await sweep().sweep(now: sweptAt);
      expect(report.deleted, ['$prefix/nobody']);
      for (final tenant in ['acme', 'initech']) {
        expect(await store.exists('$prefix/$tenant'), isTrue);
        expect(
          tenancy.tenants,
          isNot(contains(tenant)),
          reason: 'reading a removed tenant does not serve it',
        );
        await tenancy.restoreTenant(tenant);
        final restored = await tenancy.runFor(tenant, documents.findAll);
        expect(restored.single.attachment, '$prefix/$tenant');
        expect(await store.exists(restored.single.attachment!), isTrue);
      }
      expect(await tenancy.removedTenantIds(), isEmpty);
    }, skip: skipReason);

    test(
      'OSR-2: once purgeTenant drops a removed tenant\'s data, the next sweep '
      'deletes its files; the other tenants\' stay',
      () async {
        for (final tenant in ['umbrella', 'hooli']) {
          await tenancy.suspendTenant(tenant);
          await tenancy.removeTenant(tenant);
        }
        expect((await sweep().sweep(now: sweptAt)).deleted, isEmpty);
        for (final tenant in ['umbrella', 'hooli']) {
          expect(await store.exists('$prefix/$tenant'), isTrue);
          await tenancy.purgeTenant(tenant, force: true);
        }
        expect(await tenancy.removedTenantIds(), isEmpty);
        final report = await sweep().sweep(now: sweptAt);
        expect(report.deleted.toSet(), {'$prefix/umbrella', '$prefix/hooli'});
        for (final tenant in ['acme', 'initech', 'globex']) {
          expect(await store.exists('$prefix/$tenant'), isTrue);
        }
      },
      skip: skipReason,
    );

    test(
      'OSR-3: readRemovedTenant refuses a tenant that is not removed, and one '
      'the registry does not hold',
      () async {
        Matcher refused(String key) => throwsA(
          isA<TomTenancyException>().having((e) => e.key, 'key', key),
        );
        await expectLater(
          tenancy.readRemovedTenant('globex', () async => 0),
          refused('tenancy.tenant.not_removed'),
        );
        await expectLater(
          tenancy.readRemovedTenant('nobody', () async => 0),
          refused('tenancy.tenant.unknown'),
        );
      },
      skip: skipReason,
    );
  }, skip: skipReason);
}
