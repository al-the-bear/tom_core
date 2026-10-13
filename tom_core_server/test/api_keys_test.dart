/// Service accounts and API keys: issuing, authenticating, scoped roles,
/// rotation and revocation — against the in-process store.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  setUpAll(initializeReflection);

  var now = DateTime.utc(2026, 1, 1, 12);
  late TomMemoryApiKeyStore store;
  late TomApiKeys keys;

  setUp(() async {
    now = DateTime.utc(2026, 1, 1, 12);
    store = TomMemoryApiKeyStore();
    keys = TomApiKeys(store: store, clock: () => now);
    TomApiKeys.install(keys);
    await keys.saveAccount(
      const TomServiceAccount(
        id: 'importer',
        name: 'Nightly import',
        roles: ['import', 'read'],
        tenant: 'acme',
        organization: 'ops',
      ),
    );
  });

  tearDown(TomApiKeys.reset);

  Matcher refused(String key) =>
      throwsA(isA<TomApiKeyException>().having((e) => e.key, 'key', key));

  group('issuing', () {
    test(
      'answers the key once as tomk.<id>.<secret>; the store keeps a hash',
      () async {
        final issued = await keys.issue('importer', label: 'ci');
        final parts = issued.value.split('.');
        expect(parts, hasLength(3));
        expect(parts[0], 'tomk');
        expect(parts[1], issued.record.id);
        final stored = (await store.findKey(issued.record.id))!;
        expect(stored.secretHash, TomApiKeys.hashSecret(parts[2]));
        expect(stored.secretHash, isNot(contains(parts[2])));
        expect(stored.label, 'ci');
      },
    );

    test('two keys never share an id or a secret', () async {
      final a = await keys.issue('importer');
      final b = await keys.issue('importer');
      expect(a.record.id, isNot(b.record.id));
      expect(a.value, isNot(b.value));
    });

    test('refuses an unknown account', () {
      expect(keys.issue('nobody'), refused('api_key.issue.unknown_account'));
    });

    test('refuses a role the account does not hold', () {
      expect(
        keys.issue('importer', roles: ['admin']),
        refused('api_key.issue.role_not_held'),
      );
    });
  });

  group('authenticating', () {
    test('a key yields its account as an authenticated principal', () async {
      final issued = await keys.issue('importer');
      final (principal, identity) = (await keys.authenticate(issued.value))!;
      expect(principal.authenticated, isTrue);
      expect(principal.username, 'service:importer');
      expect(principal.aci.roles, ['import', 'read']);
      expect(principal.tenant, 'acme');
      expect(principal.organization, 'ops');
      expect(identity.keyId, issued.record.id);
      expect(identity.accountId, 'importer');
    });

    test('a scoped key carries only its own roles', () async {
      final issued = await keys.issue('importer', roles: ['read']);
      final (principal, _) = (await keys.authenticate(issued.value))!;
      expect(principal.aci.roles, ['read']);
    });

    test('narrowing the account narrows its keys at once', () async {
      final issued = await keys.issue('importer', roles: ['import', 'read']);
      await keys.saveAccount(
        const TomServiceAccount(id: 'importer', name: 'n', roles: ['read']),
      );
      final (principal, _) = (await keys.authenticate(issued.value))!;
      expect(principal.aci.roles, ['read']);
    });

    test(
      'a wrong secret, a malformed or an unknown key authenticate nothing',
      () async {
        final issued = await keys.issue('importer');
        final id = issued.record.id;
        expect(await keys.authenticate('tomk.$id.wrong'), isNull);
        expect(await keys.authenticate('not-a-key'), isNull);
        expect(await keys.authenticate('tomk.$id.'), isNull);
        expect(await keys.authenticate('tomk.ffffffffffffffff.secret'), isNull);
      },
    );

    test('a disabled account authenticates nothing, and comes back', () async {
      final issued = await keys.issue('importer');
      final account = (await store.findAccount('importer'))!;
      await keys.saveAccount(account.withDisabled(true));
      expect(await keys.authenticate(issued.value), isNull);
      await keys.saveAccount(account.withDisabled(false));
      expect(await keys.authenticate(issued.value), isNotNull);
    });

    test('an expiring key stops at its expiry', () async {
      final issued = await keys.issue(
        'importer',
        expiresIn: const Duration(days: 30),
      );
      expect(await keys.authenticate(issued.value), isNotNull);
      now = now.add(const Duration(days: 30));
      expect(await keys.authenticate(issued.value), isNull);
    });

    test('the last use is recorded at most once a minute', () async {
      final issued = await keys.issue('importer');
      await keys.authenticate(issued.value);
      final first = (await store.findKey(issued.record.id))!.lastUsedAt;
      expect(first, now);
      now = now.add(const Duration(seconds: 30));
      await keys.authenticate(issued.value);
      expect((await store.findKey(issued.record.id))!.lastUsedAt, first);
      now = now.add(const Duration(seconds: 31));
      await keys.authenticate(issued.value);
      expect((await store.findKey(issued.record.id))!.lastUsedAt, now);
    });
  });

  group('revoking', () {
    test('a revoked key stops at once, even after it was cached', () async {
      final issued = await keys.issue('importer');
      // Authenticated once, so this node holds the key in its lookup cache.
      expect(await keys.authenticate(issued.value), isNotNull);
      await keys.revoke(issued.record.id);
      expect(await keys.authenticate(issued.value), isNull);
      expect((await store.findKey(issued.record.id))!.revokedAt, now);
    });

    test(
      'a node serving a stale cached copy cannot undo a revocation',
      () async {
        final issued = await keys.issue('importer');
        // Cached here, live.
        expect(await keys.authenticate(issued.value), isNotNull);
        // Revoked by another node whose invalidation never reached this one.
        final stored = (await store.findKey(issued.record.id))!;
        await store.saveKey(stored.copyWith(revokedAt: now));
        // This node still serves its cached copy (the bounded staleness) and
        // records the use — which must not write the revocation away.
        now = now.add(const Duration(minutes: 2));
        await keys.authenticate(issued.value);
        final after = (await store.findKey(issued.record.id))!;
        expect(after.revokedAt, isNotNull);
        expect(after.lastUsedAt, now);
      },
    );

    test(
      'a revocation raised inside a tenant still drops the cached key',
      () async {
        final issued = await keys.issue('importer');
        // Looked up outside any tenant, as the authentication middleware does.
        expect(await keys.authenticate(issued.value), isNotNull);
        await TomTenantContext.run('acme', () => keys.revoke(issued.record.id));
        expect(await keys.authenticate(issued.value), isNull);
      },
    );

    test('revoking an unknown key is refused by name', () {
      expect(keys.revoke('nope'), refused('api_key.revoke.unknown_key'));
    });
  });

  group('rotating', () {
    test(
      'by default the successor works and the old key stops at once',
      () async {
        final old = await keys.issue('importer', roles: ['read'], label: 'ci');
        expect(await keys.authenticate(old.value), isNotNull);
        final successor = await keys.rotate(old.record.id);
        expect(await keys.authenticate(old.value), isNull);
        final (principal, _) = (await keys.authenticate(successor.value))!;
        expect(principal.aci.roles, ['read']);
        expect(successor.record.label, 'ci');
        expect(successor.record.accountId, 'importer');
      },
    );

    test('with an overlap both keys work until it passes', () async {
      final old = await keys.issue('importer');
      final successor = await keys.rotate(
        old.record.id,
        overlap: const Duration(hours: 1),
      );
      expect(await keys.authenticate(old.value), isNotNull);
      expect(await keys.authenticate(successor.value), isNotNull);
      now = now.add(const Duration(hours: 1));
      expect(await keys.authenticate(old.value), isNull);
      expect(await keys.authenticate(successor.value), isNotNull);
    });

    test('an overlap never extends a key past its own expiry', () async {
      final old = await keys.issue(
        'importer',
        expiresIn: const Duration(minutes: 5),
      );
      await keys.rotate(old.record.id, overlap: const Duration(days: 1));
      expect(
        (await store.findKey(old.record.id))!.expiresAt,
        now.add(const Duration(minutes: 5)),
      );
    });

    test('the account lists both keys, live and ended', () async {
      final old = await keys.issue('importer');
      await keys.rotate(old.record.id);
      final listed = await keys.keysOf('importer');
      expect(listed, hasLength(2));
      expect(listed.where((k) => k.isLiveAt(now)), hasLength(1));
    });
  });
}
