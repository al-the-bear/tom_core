import 'dart:convert';

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

/// Builds a client token carrying [payload] verbatim.
///
/// [TomServerJwtToken] always writes a well-formed `validUntil`, so it cannot
/// produce the tokens the guard exists for. A client can: `TomClientJwtToken`
/// decodes without verifying, which is what makes the payload untrusted input
/// in the first place, so a hand-assembled token is the honest fixture here —
/// the signature is never inspected on this path and a real forgery would be
/// rejected earlier, by bearer authentication.
TomClientJwtToken _tokenWithPayload(Map<String, Object?> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  return TomClientJwtToken(
    '$header.${segment(payload)}.not-a-real-signature',
    decrypt: false,
  );
}

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
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      return 'stored:'
          '${await TomAuthorizationCache.storePrincipal(token, principal)}';
    } on TomAuthorizationCacheException catch (e) {
      return 'rejected:${e.key}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
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

  // The token is client-supplied, so `validUntil` is untrusted input and every
  // shape of it has to land somewhere deliberate. The entry's lifetime *is* the
  // token's, so there is no safe default to fall back on: a lifetime invented
  // here would keep a principal cached after the token authorizing it expired.
  group('TomAuthorizationCache.storePrincipal (malformed validUntil)', () {
    test('rejects a token that carries no validUntil claim', () async {
      final token = _tokenWithPayload({'userId': 'ivan'});

      await expectLater(
        () => TomAuthorizationCache.storePrincipal(token, _principal('ivan')),
        throwsA(
          isA<TomAuthorizationCacheException>().having(
            (e) => e.key,
            'key',
            'tomclient.authorization_cache.missing_valid_until',
          ),
        ),
      );
    });

    test('rejects a validUntil that is not a string', () async {
      // A JSON payload can carry any type, so the claim being present says
      // nothing about it being readable.
      final token = _tokenWithPayload({'userId': 'ivy', 'validUntil': 1787});

      await expectLater(
        () => TomAuthorizationCache.storePrincipal(token, _principal('ivy')),
        throwsA(
          isA<TomAuthorizationCacheException>().having(
            (e) => e.key,
            'key',
            'tomclient.authorization_cache.missing_valid_until',
          ),
        ),
      );
    });

    test('rejects a validUntil that is not a date', () async {
      final token = _tokenWithPayload({
        'userId': 'igor',
        'validUntil': 'tomorrow-ish',
      });

      await expectLater(
        () => TomAuthorizationCache.storePrincipal(token, _principal('igor')),
        throwsA(
          isA<TomAuthorizationCacheException>().having(
            (e) => e.key,
            'key',
            'tomclient.authorization_cache.invalid_valid_until',
          ),
        ),
      );
    });

    test('names the claim and the token in the failure', () async {
      // The complaint this guard answers was diagnosability: the old TypeError
      // named neither, so the message is part of the contract, not decoration.
      final token = _tokenWithPayload({
        'userId': 'irene',
        'validUntil': 'tomorrow-ish',
      });

      Object? caught;
      try {
        await TomAuthorizationCache.storePrincipal(token, _principal('irene'));
      } catch (e) {
        caught = e;
      }

      final message = (caught as TomAuthorizationCacheException).parameters;
      expect(message?['claim'], 'validUntil');
      expect(message?['value'], 'tomorrow-ish');
      expect(message?['token'], startsWith(token.tokenString.substring(0, 20)));
    });

    test('stores nothing when the claim is rejected', () async {
      // The guard has to run before the map is touched: a half-completed write
      // would leave an entry with a lifetime nobody chose, which is the outcome
      // refusing the write exists to avoid.
      final token = _tokenWithPayload({'userId': 'ida'});

      await expectLater(
        () => TomAuthorizationCache.storePrincipal(token, _principal('ida')),
        throwsA(isA<TomAuthorizationCacheException>()),
      );

      expect(await TomAuthorizationCache.getPrincipal(token), isNull);
    });

    test('accepts a well-formed validUntil supplied by a client', () async {
      // The companion case: the guard must not reject the tokens this server
      // actually issues, and the parsed instant must be the one in the claim.
      final expiry = DateTime.now().add(const Duration(hours: 3));
      final token = _tokenWithPayload({
        'userId': 'iris',
        'validUntil': expiry.toIso8601String(),
      });

      expect(
        await TomAuthorizationCache.storePrincipal(token, _principal('iris')),
        0,
      );
      final cached = await TomAuthorizationCache.getPrincipal(token);
      expect(cached!.username, 'iris');
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
  //
  // That is all this group establishes, and it is worth saying so: which branch
  // ran says nothing about what the branch returns. The round-trip group below
  // is what covers the answers.
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

    test('a miss becomes a hit once the creator stores the token', () async {
      // Asserting the miss on its own would be worthless: an unknown token
      // reads as a miss whether the creator answered or nothing did. Verified
      // by deleting the addExecutor above — the bare assertion stays green,
      // because an unserviced command comes back as TomExecutor.noResult and
      // `is TomPrincipal` rejects that exactly as it rejects a real miss.
      //
      // So the two probes share one token and one worker, and only the
      // creator's map changes between them. A transition from miss to hit can
      // only be that map being read, which pins the miss as an answer rather
      // than as silence.
      final token = _token('henry');

      final beforeStore = await worker
          .executeCommand(ProbeCacheCommand(token))
          .timeout(const Duration(seconds: 10));
      expect(beforeStore, 'miss');

      await TomAuthorizationCache.storePrincipal(token, _principal('henry'));

      final afterStore = await worker
          .executeCommand(ProbeCacheCommand(token))
          .timeout(const Duration(seconds: 10));
      expect(afterStore, 'hit:henry');
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

    test(
      'a worker-stored entry expires for the worker that stored it',
      () async {
        // The whole loop in one test, with the main isolate touching neither
        // end: the worker writes, the creator keeps the entry, the worker reads
        // it back. Each test above crosses the boundary once and has the main
        // isolate supply the other half, so this is the only one that would
        // notice the two halves agreeing with the main isolate but not with each
        // other — and it lands on the expiry, the answer that used to be lost.
        final token = _token('helen', validFor: const Duration(hours: -1));

        final stored = await worker
            .executeCommand(
              StoreThroughWorkerCommand(token, _principal('helen')),
            )
            .timeout(const Duration(seconds: 10));
        expect(stored, 'stored:0');

        final answer = await worker
            .executeCommand(ProbeCacheCommand(token))
            .timeout(const Duration(seconds: 10));

        expect(
          answer,
          'expired:tomclient.authorization_cache.expired_principal',
        );
      },
    );

    test('a worker-side store of a malformed token is refused', () async {
      // The guard lives on the creator side, so a worker only learns that its
      // store was refused if the refusal travels back. Nothing else in this
      // group would notice it not travelling: storePrincipal answers `0` on
      // the way out regardless, so the worker reads a store that never
      // happened as a store that did — the same failure shape as the expiry
      // that used to be lost, one method along.
      final token = _tokenWithPayload({'userId': 'ivan'});

      final answer = await worker
          .executeCommand(StoreThroughWorkerCommand(token, _principal('ivan')))
          .timeout(const Duration(seconds: 10));

      expect(
        answer,
        'rejected:tomclient.authorization_cache.missing_valid_until',
      );
      expect(await TomAuthorizationCache.getPrincipal(token), isNull);
    });
  });

  group('TomAuthorizationCacheExecutor', () {
    final executor = TomAuthorizationCacheExecutor();

    test('handles a store message, returning the store to be awaited', () async {
      // The future is returned rather than discarded so that a refusal reaches
      // the worker that asked for the store; the value it settles to is
      // storePrincipal's `0`, which matters only in that it is not null and so
      // is not read as an unclaimed command.
      final token = _token('carol');
      final result = executor.execute(
        TomAuthorizationCacheStoreMessage(token, _principal('carol')),
      );
      expect(await (result as Future<int>), 0);
      expect(
        (await TomAuthorizationCache.getPrincipal(token))!.username,
        'carol',
      );
    });

    test('surfaces a refused store as a throw the caller can await', () async {
      final result = executor.execute(
        TomAuthorizationCacheStoreMessage(
          _tokenWithPayload({'userId': 'jane'}),
          _principal('jane'),
        ),
      );
      await expectLater(
        result as Future<Object?>,
        throwsA(
          isA<TomAuthorizationCacheException>().having(
            (e) => e.key,
            'key',
            'tomclient.authorization_cache.missing_valid_until',
          ),
        ),
      );
    });

    test(
      'handles a retrieve message, resolving to the stored principal',
      () async {
        final token = _token('dave');
        await (executor.execute(
              TomAuthorizationCacheStoreMessage(token, _principal('dave')),
            )
            as Future<int>);
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
