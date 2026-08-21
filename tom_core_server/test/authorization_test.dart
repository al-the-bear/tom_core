import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds a client JWT token whose `validUntil` claim is [validFor] from now.
/// Pass a negative duration to obtain an already-expired token.
TomClientJwtToken _token(
  String userId, {
  Duration validFor = const Duration(hours: 2),
}) => TomClientJwtToken(
  TomServerJwtToken({'userId': userId}, expiresIn: validFor).getJWT('tom'),
);

TomPrincipal _principal(String username) =>
    TomPrincipal(user: TomUser(username: username), authenticated: true);

/// Minimal context for a worker spawned by the round-trip group below.
class _CacheWorkerContext extends TomWorkerContext {
  _CacheWorkerContext()
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        'AC',
      );
}

/// Runs inside a WORKER isolate and reports which of the cache's three answers
/// it received.
///
/// The outcomes are collapsed to a string on purpose. What the round trip has
/// to prove is that the worker can still *tell them apart* — an expiry that
/// arrives as a `null` is the defect this exists to catch, and returning the
/// principal itself would make the two look alike again at the far end.
class ProbeCacheCommand extends TomCommand {
  final TomClientJwtToken token;

  ProbeCacheCommand(this.token);

  @override
  Future<Object?> execute() async {
    // A worker that answered from a local map would prove nothing about the
    // forwarding path, so record that this really is the off-isolate branch.
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      final principal = await TomAuthorizationCache.getPrincipal(token);
      return principal == null ? 'miss' : 'hit:${principal.username}';
    } on TomAuthorizationCacheException catch (e) {
      return 'expired:${e.key}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and forwards a store to the creator.
class StoreThroughWorkerCommand extends TomCommand {
  final TomClientJwtToken token;
  final TomPrincipal principal;

  StoreThroughWorkerCommand(this.token, this.principal);

  @override
  Future<Object?> execute() async =>
      'stored:${await TomAuthorizationCache.storePrincipal(token, principal)}';
}

void main() {
  // The cache runs in the main isolate by default; keep it that way for the
  // synchronous, single-isolate behaviour under test.
  setUp(() => TomWorker.resetIsMainIsolate());

  group('TomAuthorizationCacheEntry', () {
    test('defaults the deletion time to roughly one day out', () {
      final before = DateTime.now().add(const Duration(days: 1));
      final entry = TomAuthorizationCacheEntry(_principal('alice'));
      final after = DateTime.now().add(const Duration(days: 1));
      expect(
        entry.deletionTime.isBefore(
          before.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      expect(
        entry.deletionTime.isAfter(after.add(const Duration(minutes: 1))),
        isFalse,
      );
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
      final result = await TomAuthorizationCache.storePrincipal(
        token,
        _principal('alice'),
      );
      expect(result, 0);

      final cached = await TomAuthorizationCache.getPrincipal(token);
      expect(cached, isNotNull);
      expect(cached!.username, 'alice');
    });

    test('returns null for an unknown token (cache miss)', () async {
      final cached = await TomAuthorizationCache.getPrincipal(_token('nobody'));
      expect(cached, isNull);
    });

    test(
      'throws TomAuthorizationCacheException for an expired entry',
      () async {
        final token = _token('bob', validFor: const Duration(hours: -1));
        await TomAuthorizationCache.storePrincipal(token, _principal('bob'));
        expect(
          () => TomAuthorizationCache.getPrincipal(token),
          throwsA(isA<TomAuthorizationCacheException>()),
        );
      },
    );
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
    setUp(() => TomWorker.simulateWorkerIsolate());
    tearDown(() => TomWorker.resetIsMainIsolate());

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

  // The branch-selection group above proves only which branch was taken. This
  // one runs the forwarding for real, in a spawned isolate with the creator-side
  // executor registered, because the defect it guards against lives in the
  // transport rather than in either branch: an expiry raised on the creator used
  // to arrive in the worker as an ordinary value, fail the `is TomPrincipal`
  // test, and leave `getPrincipal` returning `null`. Both signals then looked
  // like a miss exactly where the request pipeline runs.
  group('TomAuthorizationCache (worker isolate round trip)', () {
    final executor = TomAuthorizationCacheExecutor();
    late TomWorker worker;

    setUp(() async {
      TomWorker.addExecutor(executor);
      worker = await TomWorker.spawn(
        TomWorker.startRemoteIsolate,
        _CacheWorkerContext(),
      );
    });

    tearDown(() {
      worker.close();
      // The registry is process-global, so withdraw exactly this registration;
      // clearExecutors would discard whatever else the process had installed.
      TomWorker.removeExecutor(executor);
    });

    test('an expired entry reaches the worker as an expiry', () async {
      final token = _token('erin', validFor: const Duration(hours: -1));
      await TomAuthorizationCache.storePrincipal(token, _principal('erin'));

      final answer = await worker
          .executeCommand(ProbeCacheCommand(token))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'expired:tomclient.authorization_cache.expired_principal');
    });

    test('an unknown token still reaches the worker as a miss', () async {
      // The companion to the case above: if every answer became an expiry the
      // first assertion would pass for the wrong reason.
      final answer = await worker
          .executeCommand(ProbeCacheCommand(_token('nobody-at-all')))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'miss');
    });

    test('a live entry reaches the worker as the principal', () async {
      final token = _token('frank');
      await TomAuthorizationCache.storePrincipal(token, _principal('frank'));

      final answer = await worker
          .executeCommand(ProbeCacheCommand(token))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'hit:frank');
    });

    test('a worker-side store lands in the creator cache', () async {
      // Closes the loop: the write forwards too, so the read above is not the
      // only half of the pair that crosses the boundary.
      final token = _token('grace');
      final stored = await worker
          .executeCommand(StoreThroughWorkerCommand(token, _principal('grace')))
          .timeout(const Duration(seconds: 10));
      expect(stored, 'stored:0');

      final cached = await TomAuthorizationCache.getPrincipal(token);
      expect(cached!.username, 'grace');
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

    test(
      'handles a retrieve message, resolving to the stored principal',
      () async {
        final token = _token('dave');
        executor.execute(
          TomAuthorizationCacheStoreMessage(token, _principal('dave')),
        );
        final result = executor.execute(
          TomAuthorizationCacheRetrieveMessage(token),
        );
        final principal = await (result as Future<TomPrincipal?>);
        expect(principal!.username, 'dave');
      },
    );

    test('returns TomExecutor.noResult for an unrelated command', () {
      expect(
        identical(
          executor.execute('not a cache command'),
          TomExecutor.noResult,
        ),
        isTrue,
      );
    });
  });
}
