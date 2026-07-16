import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds a client JWT token whose `validUntil` claim is [validFor] from now.
/// Pass a negative duration to obtain an already-expired token.
TomClientJwtToken _token(
  String userId, {
  Duration validFor = const Duration(hours: 2),
}) =>
    TomClientJwtToken(
      TomServerJwtToken({'userId': userId}, expiresIn: validFor).getJWT('tom'),
    );

TomPrincipal _principal(String username) =>
    TomPrincipal(user: TomUser(username: username), authenticated: true);

void main() {
  // The cache runs in the main isolate by default; keep it that way for the
  // synchronous, single-isolate behaviour under test.
  setUp(() => TomWorker.isMainIsolate = true);

  group('TomAuthorizationCacheEntry', () {
    test('defaults the deletion time to roughly one day out', () {
      final before = DateTime.now().add(const Duration(days: 1));
      final entry = TomAuthorizationCacheEntry(_principal('alice'));
      final after = DateTime.now().add(const Duration(days: 1));
      expect(entry.deletionTime.isBefore(before.subtract(const Duration(minutes: 1))), isFalse);
      expect(entry.deletionTime.isAfter(after.add(const Duration(minutes: 1))), isFalse);
    });

    test('honours an explicit deletion time', () {
      final when = DateTime(2030, 1, 1);
      final entry = TomAuthorizationCacheEntry(_principal('alice'), when);
      expect(entry.deletionTime, when);
    });

    test('carries the authorized principal', () {
      final entry = TomAuthorizationCacheEntry(_principal('bob'));
      expect(entry.authorizedPrincipal.username, 'bob');
    });
  });

  group('TomAuthorizationCacheException', () {
    test('is a TomException carrying its key and message', () {
      final e = TomAuthorizationCacheException('a.key', 'a message');
      expect(e, isA<TomException>());
      expect(e.key, 'a.key');
    });
  });

  group('TomAuthorizationCache (main isolate)', () {
    test('stores a principal and reads it back by token', () async {
      final token = _token('alice');
      final result =
          await TomAuthorizationCache.storePrincipal(token, _principal('alice'));
      expect(result, 0);

      final cached = await TomAuthorizationCache.getPrincipal(token);
      expect(cached, isNotNull);
      expect(cached!.username, 'alice');
    });

    test('returns null for an unknown token (cache miss)', () async {
      final cached = await TomAuthorizationCache.getPrincipal(_token('nobody'));
      expect(cached, isNull);
    });

    test('throws TomAuthorizationCacheException for an expired entry', () async {
      final token = _token('bob', validFor: const Duration(hours: -1));
      await TomAuthorizationCache.storePrincipal(token, _principal('bob'));
      expect(
        () => TomAuthorizationCache.getPrincipal(token),
        throwsA(isA<TomAuthorizationCacheException>()),
      );
    });
  });

  group('Cross-isolate command objects', () {
    test('store message carries token and principal', () {
      final token = _token('alice');
      final principal = _principal('alice');
      final msg = TomAuthorizationCacheStoreMessage(token, principal);
      expect(msg.authenticationToken, same(token));
      expect(msg.authorizedPrincipal, same(principal));
    });

    test('retrieve message carries the token', () {
      final token = _token('alice');
      final msg = TomAuthorizationCacheRetrieveMessage(token);
      expect(msg.authenticationToken, same(token));
    });
  });

  // Worker-isolate forwarding decision (mirrors cache_test's forwarding group).
  // Off the main isolate, getPrincipal/storePrincipal forward to the creator
  // isolate via TomWorker.executeInCreator. In this single-isolate test process
  // there is no back channel, so the forwarding attempt throws
  // TomWorkerException — proof the off-isolate branch was taken rather than the
  // local map being touched.
  group('TomAuthorizationCache (worker isolate forwarding)', () {
    setUp(() => TomWorker.isMainIsolate = false);
    tearDown(() => TomWorker.isMainIsolate = true);

    test('getPrincipal forwards the lookup to the creator isolate', () {
      expect(
        () => TomAuthorizationCache.getPrincipal(_token('alice')),
        throwsA(isA<TomWorkerException>()),
      );
    });

    test('storePrincipal forwards the write to the creator isolate', () {
      expect(
        () => TomAuthorizationCache.storePrincipal(
          _token('alice'),
          _principal('alice'),
        ),
        throwsA(isA<TomWorkerException>()),
      );
    });
  });

  group('TomAuthorizationCacheExecutor', () {
    final executor = TomAuthorizationCacheExecutor();

    test('handles a store message and returns true', () {
      final result = executor.execute(
        TomAuthorizationCacheStoreMessage(_token('carol'), _principal('carol')),
      );
      expect(result, isTrue);
    });

    test('handles a retrieve message, resolving to the stored principal', () async {
      final token = _token('dave');
      executor.execute(
        TomAuthorizationCacheStoreMessage(token, _principal('dave')),
      );
      final result = executor.execute(
        TomAuthorizationCacheRetrieveMessage(token),
      );
      final principal = await (result as Future<TomPrincipal?>);
      expect(principal!.username, 'dave');
    });

    test('returns TomExecutor.noResult for an unrelated command', () {
      expect(
        identical(executor.execute('not a cache command'), TomExecutor.noResult),
        isTrue,
      );
    });
  });
}
