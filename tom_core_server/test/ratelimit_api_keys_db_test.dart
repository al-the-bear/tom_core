/// The shared rate limiter and the shared API-key store against a real
/// MariaDB: two "nodes" — two limiter or key-service instances over one data
/// source — see one count and one revocation.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  late TomDataSource datasource;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    datasource = (await TestDatabase.register()).datasource;
    for (final table in [
      defaultRateLimitTable,
      defaultApiKeyTable,
      defaultServiceAccountTable,
    ]) {
      await datasource.executeCommand('DROP TABLE IF EXISTS $table');
    }
  });

  tearDownAll(() async {
    if (!reachable) return;
    TomApiKeys.reset();
    await TestDatabase.reset();
  });

  group('TomSqlRateLimiter', () {
    final rule = TomRateLimitRule(
      name: 'shared',
      scope: TomRateLimitScope.apiKey,
      limit: 5,
      window: const Duration(minutes: 1),
    );

    setUp(() async => TomSqlRateLimiter(datasource).deleteAll());

    test('two nodes count into one limit', () async {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 10);
      final nodeA = TomSqlRateLimiter(datasource, clock: () => now);
      final nodeB = TomSqlRateLimiter(datasource, clock: () => now);
      for (var i = 0; i < 5; i++) {
        final node = i.isEven ? nodeA : nodeB;
        expect((await node.hit('shared|k1', rule)).allowed, isTrue);
      }
      final refused = await nodeB.hit('shared|k1', rule);
      expect(refused.allowed, isFalse);
      expect(refused.retryAfterSeconds, greaterThan(0));
      // Another key counts apart, on either node.
      expect((await nodeA.hit('shared|k2', rule)).allowed, isTrue);
    });

    test('concurrent requests are each counted once', () async {
      final now = DateTime.utc(2026, 1, 1, 13, 0, 5);
      final nodes = [
        for (var i = 0; i < 4; i++)
          TomSqlRateLimiter(datasource, clock: () => now),
      ];
      final decisions = await Future.wait([
        for (var i = 0; i < 12; i++) nodes[i % 4].hit('shared|burst', rule),
      ]);
      // The atomic upsert gives every request its own count: exactly the
      // limit's worth are admitted, however the twelve interleave.
      expect(decisions.where((d) => d.allowed), hasLength(5));
    });

    test('a new window admits again, weighted by the previous one', () async {
      var now = DateTime.utc(2026, 1, 1, 14, 0, 0);
      final limiter = TomSqlRateLimiter(datasource, clock: () => now);
      for (var i = 0; i < 6; i++) {
        await limiter.hit('shared|k3', rule);
      }
      // 50 s into the next window only a sixth of the previous one counts.
      now = now.add(const Duration(seconds: 110));
      expect((await limiter.hit('shared|k3', rule)).allowed, isTrue);
    });
  }, skip: skipReason);

  group('API keys over TomSqlApiKeyStore', () {
    late TomSqlApiKeyStore store;

    setUp(() async {
      store = TomSqlApiKeyStore(datasource);
      await store.deleteAll();
      TomApiKeys.reset();
    });

    test('accounts and keys round-trip through the tables', () async {
      final keys = TomApiKeys(store: store);
      await keys.saveAccount(
        const TomServiceAccount(
          id: 'exporter',
          name: 'Export job',
          roles: ['export', 'read'],
          tenant: 'acme',
          organization: 'ops',
          disabled: true,
        ),
      );
      final account = (await store.findAccount('exporter'))!;
      expect(account.roles, ['export', 'read']);
      expect(account.tenant, 'acme');
      expect(account.organization, 'ops');
      expect(account.disabled, isTrue);
      await keys.saveAccount(account.withDisabled(false));

      final issued = await keys.issue(
        'exporter',
        roles: ['read'],
        label: 'nightly',
        expiresIn: const Duration(days: 90),
      );
      final stored = (await store.findKey(issued.record.id))!;
      expect(stored.roles, ['read']);
      expect(stored.label, 'nightly');
      expect(stored.expiresAt, issued.record.expiresAt);
      expect(stored.secretHash, issued.record.secretHash);
      expect(await keys.authenticate(issued.value), isNotNull);
      expect((await store.accounts()).single.id, 'exporter');
    });

    test('a key revoked on one node is refused by the other at once', () async {
      final nodeA = TomApiKeys(store: store);
      final nodeB = TomApiKeys(store: TomSqlApiKeyStore(datasource));
      TomApiKeys.install(nodeB);
      await nodeA.saveAccount(
        const TomServiceAccount(id: 'svc', name: 's', roles: ['read']),
      );
      final issued = await nodeA.issue('svc');
      // Node B authenticates it, and caches the key.
      expect(await nodeB.authenticate(issued.value), isNotNull);
      await nodeA.revoke(issued.record.id);
      expect(await nodeB.authenticate(issued.value), isNull);
    });

    test('a rotation on one node moves the other to the successor', () async {
      final nodeA = TomApiKeys(store: store);
      final nodeB = TomApiKeys(store: TomSqlApiKeyStore(datasource));
      TomApiKeys.install(nodeB);
      await nodeA.saveAccount(
        const TomServiceAccount(id: 'svc', name: 's', roles: ['read']),
      );
      final old = await nodeA.issue('svc');
      expect(await nodeB.authenticate(old.value), isNotNull);
      final successor = await nodeA.rotate(old.record.id);
      expect(await nodeB.authenticate(old.value), isNull);
      expect(await nodeB.authenticate(successor.value), isNotNull);
    });
  }, skip: skipReason);
}
