/// Cache invalidation and principal revocation, without a database.
///
/// The other node is played by a fake channel: what this node publishes is
/// recorded, and an invalidation "from another node" is delivered through the
/// callback the invalidator gave the channel — exactly the path a real
/// channel takes. The database channel and a genuine second process are
/// `cache_invalidation_db_test.dart`.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A token for [username] whose `iat` is [issuedAt] (when given) and that
/// expires in an hour.
TomClientJwtToken _token(
  String username, {
  DateTime? issuedAt,
  bool iat = true,
}) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final issued = (issuedAt ?? DateTime.now()).toUtc();
  final payload = {
    'username': username,
    if (iat) 'iat': issued.millisecondsSinceEpoch ~/ 1000,
    'exp': issued.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  };
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  return TomClientJwtToken(
    '$header.${segment(payload)}.not-a-real-signature',
    decrypt: false,
  );
}

TomPrincipal _principal(String username) =>
    TomPrincipal(user: TomUser(username: username), authenticated: true);

/// Records what this node publishes, and plays the other node.
class _FakeChannel implements TomInvalidationChannel {
  final List<TomCacheInvalidation> published = [];
  Future<void> Function(TomCacheInvalidation)? deliver;
  Object? publishFailure;
  bool stopped = false;

  @override
  Duration get stalenessBound => const Duration(seconds: 2);

  @override
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  ) async {
    this.deliver = deliver;
  }

  @override
  Future<void> publish(TomCacheInvalidation invalidation) async {
    if (publishFailure != null) throw publishFailure!;
    published.add(invalidation);
  }

  @override
  Future<void> stop() async => stopped = true;

  /// Delivers [invalidation] as if another node had raised it.
  Future<void> fromAnotherNode(TomCacheInvalidation invalidation) =>
      deliver!(invalidation);
}

Matcher _refusedWith(String key) => throwsA(
  isA<TomAuthorizationCacheException>().having((e) => e.key, 'key', key),
);

void main() {
  late _FakeChannel channel;

  setUp(() async {
    TomAuthorizationCache.instance.dispose();
    channel = _FakeChannel();
    await TomCacheInvalidator.install(channel);
  });

  tearDown(() async {
    await TomCacheInvalidator.reset();
    TomAuthorizationCache.instance.dispose();
  });

  group('revoking a principal', () {
    test('drops the cached principal and refuses its token', () async {
      final token = _token(
        'alice',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await TomAuthorizationCache.storePrincipal(token, _principal('alice'));
      expect(await TomAuthorizationCache.getPrincipal(token), isNotNull);

      await TomCacheInvalidator.revokePrincipal('alice');

      await expectLater(
        TomAuthorizationCache.getPrincipal(token),
        _refusedWith('authorization.cache.revoked_principal'),
      );
    });

    test('refuses a revoked token even with nothing cached for it', () async {
      // The token's own claims still carry the revoked grants until it
      // expires, so a cache miss must not be the way around the revocation.
      final token = _token(
        'alice',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await TomCacheInvalidator.revokePrincipal('alice');
      expect(TomAuthorizationCache.isRevoked(token), isTrue);
      await expectLater(
        TomAuthorizationCache.getPrincipal(token),
        _refusedWith('authorization.cache.revoked_principal'),
      );
    });

    test('a token issued after the revocation is served', () async {
      await TomCacheInvalidator.revokePrincipal('alice');
      final fresh = _token(
        'alice',
        issuedAt: DateTime.now().add(const Duration(seconds: 2)),
      );
      expect(TomAuthorizationCache.isRevoked(fresh), isFalse);
      await TomAuthorizationCache.storePrincipal(fresh, _principal('alice'));
      expect(
        (await TomAuthorizationCache.getPrincipal(fresh))?.username,
        'alice',
      );
    });

    test(
      'a token issued within the second of the revocation is refused',
      () async {
        // `iat` has whole-second precision, so a token minted in the same second
        // cannot show it came afterwards; refusing it is the safe direction.
        final at = DateTime.now().toUtc();
        TomAuthorizationCache.revokeLocally('alice', at);
        expect(
          TomAuthorizationCache.isRevoked(_token('alice', issuedAt: at)),
          isTrue,
        );
      },
    );

    test(
      'a token that cannot show when it was issued counts as revoked',
      () async {
        await TomCacheInvalidator.revokePrincipal('alice');
        expect(
          TomAuthorizationCache.isRevoked(_token('alice', iat: false)),
          isTrue,
        );
      },
    );

    test('other users are not touched', () async {
      final bob = _token(
        'bob',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await TomAuthorizationCache.storePrincipal(bob, _principal('bob'));
      await TomCacheInvalidator.revokePrincipal('alice');
      expect((await TomAuthorizationCache.getPrincipal(bob))?.username, 'bob');
    });

    test('the later of two revocations is kept', () {
      final later = DateTime.utc(2026, 10, 13, 12);
      TomAuthorizationCache.revokeLocally('alice', later);
      TomAuthorizationCache.revokeLocally('alice', DateTime.utc(2026, 10, 13));
      expect(TomAuthorizationCache.revokedAt('alice'), later);
    });

    test('is published for the other nodes', () async {
      await TomCacheInvalidator.revokePrincipal('alice');
      expect(channel.published, hasLength(1));
      final sent = channel.published.single;
      expect(sent.kind, TomInvalidationKind.principal);
      expect(sent.target, 'alice');
      expect(sent.origin, TomCacheInvalidator.nodeId);
    });

    test('a failed publish still revokes here, and says so', () async {
      channel.publishFailure = StateError('database unreachable');
      final token = _token(
        'alice',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await expectLater(
        TomCacheInvalidator.revokePrincipal('alice'),
        throwsStateError,
      );
      expect(TomAuthorizationCache.isRevoked(token), isTrue);
    });
  });

  group('an invalidation from another node', () {
    test('a revocation raised elsewhere refuses the token here', () async {
      final token = _token(
        'alice',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await TomAuthorizationCache.storePrincipal(token, _principal('alice'));

      await channel.fromAnotherNode(
        TomCacheInvalidation.principal('alice', origin: 'node-b'),
      );

      await expectLater(
        TomAuthorizationCache.getPrincipal(token),
        _refusedWith('authorization.cache.revoked_principal'),
      );
      expect(channel.published, isEmpty, reason: 'not published back');
    });

    test('removes one entry of a named cache', () async {
      final cache = TomCache('invalidation-test-entry');
      TomCacheManager.addCache(cache);
      addTearDown(() => TomCacheManager.removeCache(cache.cacheName));
      await TomCache.toNameCache(cache.cacheName, 'a', 'one');
      await TomCache.toNameCache(cache.cacheName, 'b', 'two');

      await channel.fromAnotherNode(
        TomCacheInvalidation.cacheEntry(cache.cacheName, 'a', origin: 'b'),
      );

      expect(
        await TomCache.fromNameCache<String>(cache.cacheName, 'a'),
        isNull,
      );
      expect(await TomCache.fromNameCache<String>(cache.cacheName, 'b'), 'two');
    });

    test('empties a named cache', () async {
      final cache = TomCache('invalidation-test-all');
      TomCacheManager.addCache(cache);
      addTearDown(() => TomCacheManager.removeCache(cache.cacheName));
      await TomCache.toNameCache(cache.cacheName, 'a', 'one');

      await channel.fromAnotherNode(
        TomCacheInvalidation.cache(cache.cacheName, origin: 'b'),
      );

      expect(
        await TomCache.fromNameCache<String>(cache.cacheName, 'a'),
        isNull,
      );
    });

    test('a cache this node does not have is nothing to invalidate', () async {
      await channel.fromAnotherNode(
        TomCacheInvalidation.cache('never-registered', origin: 'b'),
      );
    });
  });

  group('the invalidator', () {
    test('local invalidations of named caches are published too', () async {
      final cache = TomCache('invalidation-test-local');
      TomCacheManager.addCache(cache);
      addTearDown(() => TomCacheManager.removeCache(cache.cacheName));
      await TomCache.toNameCache(cache.cacheName, 'a', 'one');

      await TomCacheInvalidator.invalidateCacheEntry(cache.cacheName, 'a');
      await TomCacheInvalidator.invalidateCache(cache.cacheName);

      expect(
        await TomCache.fromNameCache<String>(cache.cacheName, 'a'),
        isNull,
      );
      expect(channel.published.map((i) => i.kind), [
        TomInvalidationKind.cacheEntry,
        TomInvalidationKind.cache,
      ]);
    });

    test('installing a channel stops the one it replaces', () async {
      final next = _FakeChannel();
      await TomCacheInvalidator.install(next);
      expect(channel.stopped, isTrue);
      expect(TomCacheInvalidator.channel, same(next));
    });

    test('the default channel reaches no other node, at no delay', () async {
      await TomCacheInvalidator.reset();
      expect(TomCacheInvalidator.channel, isA<TomLocalInvalidationChannel>());
      expect(TomCacheInvalidator.channel.stalenessBound, Duration.zero);
    });

    test(
      'the forwarding command raises the invalidation where it lands',
      () async {
        await TomCacheInvalidateMessage(
          TomCacheInvalidation.principal('carol'),
        ).execute();
        expect(TomAuthorizationCache.revokedAt('carol'), isNotNull);
        expect(channel.published.single.target, 'carol');
      },
    );

    test('a SQL channel over an unregistered data source is refused', () {
      // A configuration error, caught when the channel is built at start-up
      // rather than on the first revocation it fails to carry.
      expect(
        () => TomSqlInvalidationChannel.named('no-such-datasource'),
        throwsA(
          isA<TomCacheException>().having(
            (e) => e.key,
            'key',
            'cache.invalidation.unknown_datasource',
          ),
        ),
      );
    });

    test('an invalidation survives being rebuilt from its stored parts', () {
      final at = DateTime.utc(2026, 10, 13, 8, 30);
      final rebuilt = TomCacheInvalidation.fromParts(
        kind: 'cacheEntry',
        target: 'c',
        key: 'k',
        at: at,
        origin: 'n',
      );
      expect(rebuilt.kind, TomInvalidationKind.cacheEntry);
      expect(rebuilt.key, 'k');
      expect(rebuilt.at, at);
    });
  });

  group('revocations are forgotten after their retention', () {
    test('the sweep drops a revocation older than the retention', () {
      final previous = TomAuthorizationCache.revocationRetention;
      addTearDown(() => TomAuthorizationCache.revocationRetention = previous);
      TomAuthorizationCache.revocationRetention = const Duration(minutes: 1);
      TomAuthorizationCache.revokeLocally(
        'alice',
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      // The sweep runs on its timer; drive it the way the timer does.
      TomAuthorizationCache.startEviction(
        interval: const Duration(milliseconds: 1),
      );
      return Future<void>.delayed(const Duration(milliseconds: 20), () {
        TomAuthorizationCache.stopEviction();
        expect(TomAuthorizationCache.revokedAt('alice'), isNull);
      });
    });
  });
}
