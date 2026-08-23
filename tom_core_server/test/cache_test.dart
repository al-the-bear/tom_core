import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A cache configured the way a caller normally configures one: a default entry
/// lifetime, generous enough that nothing expires mid-test.
///
/// The default is not what makes an entry readable — an entry expires only once
/// it carries a deletion time that has passed, and one with no deletion time at
/// all is kept forever (see the "cache forever" test below, which deliberately
/// does *not* use this helper). What a non-null default buys the expiry tests is
/// discrimination: because the cache would have supplied its own instant, a
/// stored entry that expires on the caller's instead proves the caller's was
/// carried through rather than silently replaced.
TomCache _cache(String name, {int? maximumEntries}) => TomCache(
  name,
  deleteEntriesAfterSeconds: 300,
  deletionIntervalSeconds: null, // no background timer needed under test
  maximumEntries: maximumEntries,
);

/// A plain LRU of the same bound, used as the reference the cache is checked
/// against.
///
/// Deliberately naive — a list for the order and a map for the values, with no
/// pointer bookkeeping at all. The cache's chain exists to make eviction O(1);
/// this model gets the same answers by scanning, so the two agree only if the
/// chain is maintained correctly. A shared helper would have hidden exactly the
/// bug being looked for.
class _LruModel {
  _LruModel(this.bound);

  final int bound;

  /// Keys most-recently-used first.
  final List<String> _order = [];
  final Map<String, Object?> _values = {};

  /// Reads [key], promoting it on a hit. A miss changes nothing, matching
  /// `getEntry`.
  Object? get(String key) {
    if (!_values.containsKey(key)) return null;
    _order.remove(key);
    _order.insert(0, key);
    return _values[key];
  }

  /// Stores [value] under [key] at the most-recently-used position, evicting
  /// the least-recently-used entry if that puts the model over its bound.
  void put(String key, Object? value) {
    _order.remove(key);
    _order.insert(0, key);
    _values[key] = value;
    if (_order.length > bound) {
      _values.remove(_order.removeLast());
    }
  }

  void remove(String key) {
    _order.remove(key);
    _values.remove(key);
  }
}

/// Minimal context for a worker spawned by the round-trip group below.
class _CacheWorkerContext extends TomWorkerContext {
  _CacheWorkerContext()
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        'CA',
      );
}

/// Runs inside a WORKER isolate and reports how a forwarded read came back.
///
/// The three returns are the three answers the read can have. Collapsing them
/// to strings is deliberate: what the round trip must show is that the worker
/// can still *tell them apart*, and a creator-side failure that arrives as an
/// ordinary value looks exactly like a miss at this end.
class ProbeCacheReadCommand extends TomCommand {
  final String cacheName;

  ProbeCacheReadCommand(this.cacheName);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      final value = await TomCache.fromNameCache<String>(cacheName, 'k');
      return value == null ? 'miss' : 'hit:$value';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and reports how an *untyped* forwarded read
/// came back.
///
/// The type argument is the whole point. `executeInCreator` never resolves to
/// `null` — a creator result of `null`, which is what a miss is, is substituted
/// with `TomExecutor.noResult` — so a read whose `T` admits any object accepts
/// that sentinel as if it were the cached value. A read for `String` cannot see
/// the defect, because the sentinel fails the type test on its way past.
class ProbeCacheUntypedReadCommand extends TomCommand {
  final String cacheName;

  ProbeCacheUntypedReadCommand(this.cacheName);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      final value = await TomCache.fromNameCache<Object>(cacheName, 'k');
      return value == null ? 'miss' : 'value:${value.runtimeType}';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and reports how a forwarded store came back.
class ProbeCacheStoreCommand extends TomCommand {
  final String cacheName;

  ProbeCacheStoreCommand(this.cacheName);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      return 'stored:${await TomCache.toNameCache(cacheName, 'k', 'from-worker')}';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and stores a value with an explicit expiry.
///
/// The expiry is the whole point of this probe. A `deletionTime` dropped in
/// transit cannot surface as an error — the receiving side simply applies the
/// target cache's `deleteEntriesAfterSeconds` and reports the same success — so
/// the only way to see it is to ask for an instant the cache's default would
/// not have produced, and then look at the entry that landed.
class ProbeCacheStoreWithExpiryCommand extends TomCommand {
  final String cacheName;
  final DateTime deletionTime;

  ProbeCacheStoreWithExpiryCommand(this.cacheName, this.deletionTime);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      final result = await TomCache.toNameCache(
        cacheName,
        'k',
        'from-worker',
        deletionTime,
      );
      return 'stored:$result';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and reports how a forwarded removal came back.
class ProbeCacheRemoveCommand extends TomCommand {
  final String cacheName;

  ProbeCacheRemoveCommand(this.cacheName);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    try {
      return 'removed:${await TomCache.removeFromNameCache(cacheName, 'k')}';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

void main() {
  // Start every test from a clean registry. We run in the main isolate, so the
  // manager serves caches locally (useInThisIsolate == true).
  setUp(() => TomCacheManager.setCurrent(TomCacheManager()));

  group('TomCacheEntry', () {
    test('defaults deletionTime to null', () {
      expect(TomCacheEntry('v').deletionTime, isNull);
    });

    test('carries value and explicit deletion time', () {
      final when = DateTime(2030);
      final entry = TomCacheEntry('v', when);
      expect(entry.value, 'v');
      expect(entry.deletionTime, when);
    });
  });

  group('TomCacheException', () {
    test('is a TomServerException carrying its key', () {
      final e = TomCacheException('a.key', 'a message');
      expect(e, isA<TomServerException>());
      expect(e.key, 'a.key');
    });

    test('is internal by default, unlike TomServerException', () {
      // The base defaults to `true`, so an unforwarded `clientThrow` is not a
      // neutral omission — it silently makes every cache failure
      // client-throwable. Pinning both sides is what makes this test say
      // "chosen" rather than "inherited".
      expect(TomServerException('a.key', 'a message').clientThrow, isTrue);
      expect(TomCacheException('a.key', 'a message').clientThrow, isFalse);
    });

    test('lets a raise site opt into client visibility', () {
      expect(
        TomCacheException('a.key', 'a message', clientThrow: true).clientThrow,
        isTrue,
      );
    });
  });

  group('TomCacheManager', () {
    test('registers and looks caches up by name', () {
      final c = _cache('users');
      TomCacheManager.addCache(c);
      expect(TomCacheManager.getCache('users'), same(c));
    });

    test('returns null for an unknown cache name', () {
      expect(TomCacheManager.getCache('nope'), isNull);
    });

    test('uses this isolate in the main isolate', () {
      expect(TomCacheManager().useInThisIsolate, isTrue);
    });

    test('setCurrent swaps the active manager', () {
      final replacement = TomCacheManager();
      expect(TomCacheManager.setCurrent(replacement), same(replacement));
    });

    test('setCurrent discards the caches the replaced manager held', () {
      // The registry is an instance field, so installing a new manager drops
      // every registration with the old one. This is the whole reason the
      // swap is useful between tests, and it was the half not covered.
      TomCacheManager.addCache(_cache('doomed'));
      expect(TomCacheManager.getCache('doomed'), isNotNull);
      TomCacheManager.setCurrent(TomCacheManager());
      expect(TomCacheManager.getCache('doomed'), isNull);
    });
  });

  group('TomCache store/read/remove (main isolate)', () {
    test('stores a value and reads it back', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'v');
      expect(await TomCache.fromNameCache<String>('c', 'k'), 'v');
    });

    test('returns null for a missing key', () async {
      TomCacheManager.addCache(_cache('c'));
      expect(await TomCache.fromNameCache<String>('c', 'absent'), isNull);
    });

    test('treats an entry with a past deletion time as expired', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache(
        'c',
        'k',
        'v',
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(await TomCache.fromNameCache<String>('c', 'k'), isNull);
    });

    test(
      'returns a value stored without a deletion time (cache forever)',
      () async {
        // A cache with no default lifetime stores an entry with deletionTime null.
        // Such an entry never expires on its own and must be returned by a read
        // (the "cache forever" contract).
        TomCacheManager.addCache(
          TomCache('nottl', deletionIntervalSeconds: null),
        );
        await TomCache.toNameCache('nottl', 'k', 'v');
        expect(await TomCache.fromNameCache<String>('nottl', 'k'), 'v');
      },
    );

    test('throws TomCacheException on a type mismatch', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 123);
      expect(
        () => TomCache.fromNameCache<String>('c', 'k'),
        throwsA(isA<TomCacheException>()),
      );
    });

    test('removes an entry', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'v');
      await TomCache.removeFromNameCache('c', 'k');
      expect(await TomCache.fromNameCache<String>('c', 'k'), isNull);
    });

    test('type helpers use the type name as the cache name', () async {
      TomCacheManager.addCache(
        TomCache.forType(int, deleteEntriesAfterSeconds: 300),
      );
      await TomCache.toTypeCache<int>('k', 7);
      expect(await TomCache.fromTypeCache<int>('k'), 7);
      await TomCache.removeFromTypeCache<int>('k');
      expect(await TomCache.fromTypeCache<int>('k'), isNull);
    });
  });

  group('Missing cache in the main isolate throws (no forwarding)', () {
    // useInThisIsolate is true in the main isolate, so all three helpers must
    // throw rather than try to forward. removeFromNameCache previously had an
    // inverted condition and would attempt to forward here; this pins the fix.
    test('toNameCache throws TomCacheException', () {
      expect(
        () => TomCache.toNameCache('ghost', 'k', 'v'),
        throwsA(isA<TomCacheException>()),
      );
    });

    test('fromNameCache throws TomCacheException', () {
      expect(
        () => TomCache.fromNameCache<String>('ghost', 'k'),
        throwsA(isA<TomCacheException>()),
      );
    });

    test('removeFromNameCache throws TomCacheException (regression)', () {
      expect(
        () => TomCache.removeFromNameCache('ghost', 'k'),
        throwsA(isA<TomCacheException>()),
      );
    });
  });

  group('Cache failures are internal', () {
    // The constructor default only matters if the raise sites take it, and a
    // raise site can override it silently. Each of the four is pinned here.

    Future<TomCacheException> raised(Future<Object?> Function() op) async {
      try {
        await op();
      } on TomCacheException catch (e) {
        return e;
      }
      fail('expected a TomCacheException');
    }

    test(
      'a missing cache is not client-throwable, on any of the three helpers',
      () async {
        // "No cache named X" names an entry in a server-side registry. The
        // caller never addressed the cache — it asked for a resource — so the
        // message discloses an implementation choice and offers nothing to act
        // on.
        for (final op in <Future<Object?> Function()>[
          () => TomCache.fromNameCache<String>('ghost', 'k'),
          () => TomCache.toNameCache('ghost', 'k', 'v'),
          () => TomCache.removeFromNameCache('ghost', 'k'),
        ]) {
          expect((await raised(op)).clientThrow, isFalse);
        }
      },
    );

    test('a type mismatch is not client-throwable', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 123);
      final e = await raised(() => TomCache.fromNameCache<String>('c', 'k'));
      expect(e.clientThrow, isFalse);
    });

    test('a type mismatch names the type it found, not the value', () async {
      // The value's contents explain nothing about why the cast failed, and a
      // cache holds whatever a caller put in it — a session token as readily
      // as a greeting. The type is the diagnosis; rendering the payload into a
      // logged message is only a leak.
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'super-secret-token');
      final e = await raised(() => TomCache.fromNameCache<int>('c', 'k'));
      expect(e.defaultUserMessage, isNot(contains('super-secret-token')));
      expect(e.defaultUserMessage, contains('String'));
      expect(e.defaultUserMessage, contains('int'));
    });
  });

  group('LRU eviction (bounded cache)', () {
    test('evicts the least-recently-used entry when full', () async {
      TomCacheManager.addCache(_cache('lru', maximumEntries: 2));
      await TomCache.toNameCache('lru', 'a', 1);
      await TomCache.toNameCache('lru', 'b', 2);
      await TomCache.toNameCache('lru', 'c', 3); // evicts 'a'
      expect(await TomCache.fromNameCache<int>('lru', 'a'), isNull);
      expect(await TomCache.fromNameCache<int>('lru', 'b'), 2);
      expect(await TomCache.fromNameCache<int>('lru', 'c'), 3);
    });

    test(
      'reading an entry promotes it so it survives the next eviction',
      () async {
        TomCacheManager.addCache(_cache('lru', maximumEntries: 2));
        await TomCache.toNameCache('lru', 'a', 1);
        await TomCache.toNameCache('lru', 'b', 2);
        await TomCache.fromNameCache<int>('lru', 'a'); // promote 'a'
        await TomCache.toNameCache('lru', 'c', 3); // evicts 'b', not 'a'
        expect(await TomCache.fromNameCache<int>('lru', 'a'), 1);
        expect(await TomCache.fromNameCache<int>('lru', 'b'), isNull);
        expect(await TomCache.fromNameCache<int>('lru', 'c'), 3);
      },
    );

    test('updating an existing key keeps the cache within its bound', () async {
      TomCacheManager.addCache(_cache('lru', maximumEntries: 2));
      await TomCache.toNameCache('lru', 'a', 1);
      await TomCache.toNameCache('lru', 'b', 2);
      await TomCache.toNameCache('lru', 'a', 11); // update, no growth
      expect(await TomCache.fromNameCache<int>('lru', 'a'), 11);
      expect(await TomCache.fromNameCache<int>('lru', 'b'), 2);
    });

    test('storing a TomCacheEntry verbatim keeps LRU/eviction correct', () async {
      // A TomCacheEntry passed as the value must be routed through putEntry and
      // linked into the MRU chain, not written to the backing map
      // directly — otherwise the next read corrupts/throws and no eviction runs.
      TomCacheManager.addCache(_cache('be', maximumEntries: 2));
      await TomCache.toNameCache('be', 'a', TomCacheEntry(1, DateTime(2999)));
      await TomCache.toNameCache('be', 'b', TomCacheEntry(2, DateTime(2999)));
      await TomCache.toNameCache(
        'be',
        'c',
        TomCacheEntry(3, DateTime(2999)),
      ); // evicts 'a'
      expect(await TomCache.fromNameCache<int>('be', 'a'), isNull);
      expect(await TomCache.fromNameCache<int>('be', 'b'), 2);
      expect(await TomCache.fromNameCache<int>('be', 'c'), 3);
    });

    test('a TomCacheEntry value keeps its own deletionTime over the '
        'cache default', () async {
      // The test above dates every entry to 2999, so it pins the routing
      // (through putEntry, into the MRU chain) but not whose deletion time
      // survives — a far-future entry reads back under either rule. The
      // helper's 300s default would keep an ordinary store readable, so an
      // entry carrying an instant already past reading as a miss is the only
      // observation that separates the two.
      TomCacheManager.addCache(_cache('own'));
      await TomCache.toNameCache(
        'own',
        'k',
        TomCacheEntry('v', DateTime.now().subtract(const Duration(seconds: 1))),
      );
      expect(await TomCache.fromNameCache<String>('own', 'k'), isNull);
    });
  });

  group('Background timers on a bounded cache (chain integrity)', () {
    test(
      'deletion sweep evicts expired entries without breaking the MRU chain',
      () async {
        // Bounded cache + a 1s deletion timer. The sweep has to evict through
        // removeEntry rather than mutating the backing map directly: the map and
        // the MRU chain are two views of the same entries, so a direct mutation
        // leaves the chain pointing at evicted nodes and every later
        // put/eviction walks a dangling list.
        final cache = TomCache(
          'sweep',
          deletionIntervalSeconds: 1,
          maximumEntries: 3,
        );
        TomCacheManager.addCache(cache);
        try {
          await TomCache.toNameCache(
            'sweep',
            'old',
            0,
            DateTime.now().add(const Duration(milliseconds: 200)),
          );
          await TomCache.toNameCache('sweep', 'a', 1, DateTime(2999));
          await TomCache.toNameCache('sweep', 'b', 2, DateTime(2999));
          // Let the deletion timer fire and sweep 'old'.
          await Future<void>.delayed(const Duration(milliseconds: 1300));
          expect(await TomCache.fromNameCache<int>('sweep', 'old'), isNull);
          // The chain must still be coherent: fill past the bound and evict the LRU.
          await TomCache.toNameCache('sweep', 'c', 3, DateTime(2999));
          await TomCache.toNameCache(
            'sweep',
            'd',
            4,
            DateTime(2999),
          ); // over bound
          expect(
            await TomCache.fromNameCache<int>('sweep', 'a'),
            isNull,
          ); // LRU evicted
          expect(await TomCache.fromNameCache<int>('sweep', 'b'), 2);
          expect(await TomCache.fromNameCache<int>('sweep', 'c'), 3);
          expect(await TomCache.fromNameCache<int>('sweep', 'd'), 4);
        } finally {
          cache.stopTimers();
        }
      },
    );

    test('clearance sweep empties the cache and leaves it reusable', () async {
      // Bounded cache + a 1s clearance timer. The clear must reset the MRU chain
      // so the cache is immediately reusable and still bounded.
      final cache = TomCache(
        'clear',
        deletionIntervalSeconds: null,
        clearIntervalSeconds: 1,
        maximumEntries: 3,
      );
      TomCacheManager.addCache(cache);
      try {
        await TomCache.toNameCache('clear', 'a', 1, DateTime(2999));
        await TomCache.toNameCache('clear', 'b', 2, DateTime(2999));
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        expect(await TomCache.fromNameCache<int>('clear', 'a'), isNull);
        expect(await TomCache.fromNameCache<int>('clear', 'b'), isNull);
        // Reusable and bounded after the clear.
        await TomCache.toNameCache('clear', 'x', 10, DateTime(2999));
        await TomCache.toNameCache('clear', 'y', 20, DateTime(2999));
        await TomCache.toNameCache('clear', 'z', 30, DateTime(2999));
        await TomCache.toNameCache(
          'clear',
          'w',
          40,
          DateTime(2999),
        ); // over bound
        expect(
          await TomCache.fromNameCache<int>('clear', 'x'),
          isNull,
        ); // LRU evicted
        expect(await TomCache.fromNameCache<int>('clear', 'w'), 40);
      } finally {
        cache.stopTimers();
      }
    });
  });

  group('Worker-isolate forwarding decision', () {
    // Simulate a worker isolate that does not hold the named cache:
    // useInThisIsolate is false, so the helpers must *forward* the operation to
    // the creator (TomWorker.executeInCreator) rather than throw "not found".
    // There is no back channel in the test process, so the forwarding attempt
    // surfaces as a TomWorkerException — proof the forwarding branch was taken.
    setUp(() {
      TomWorker.simulateWorkerIsolate();
      TomCacheManager.setCurrent(
        TomCacheManager(),
      ); // useInThisIsolate stays false
    });
    tearDown(() {
      TomWorker.resetIsMainIsolate();
      TomCacheManager.setCurrent(TomCacheManager());
    });

    test('fromNameCache forwards a missing-cache read', () {
      expect(
        () => TomCache.fromNameCache<String>('absent', 'k'),
        throwsA(isA<TomWorkerException>()),
      );
    });

    test('toNameCache forwards a missing-cache store', () {
      expect(
        () => TomCache.toNameCache('absent', 'k', 'v'),
        throwsA(isA<TomWorkerException>()),
      );
    });

    test('removeFromNameCache forwards a missing-cache removal', () {
      expect(
        () => TomCache.removeFromNameCache('absent', 'k'),
        throwsA(isA<TomWorkerException>()),
      );
    });
  });

  // The group above proves only which branch was taken. This one runs the
  // forwarding for real, because the interesting failures live in the transport:
  // a creator-side "no such cache" used to come back as an ordinary value, so a
  // forwarded read reported a miss and — worse — a forwarded store reported
  // success, for a cache that exists nowhere.
  //
  // Executing a command object directly in the main isolate is not a substitute.
  // That is the *local* path with an extra object around it: it never exercises
  // the crossing, so it cannot see an argument that fails to make it. The
  // `deletionTime` is exactly such an argument — dropping it substitutes the
  // target cache's default and still reports success — which is why the two
  // expiry tests below go through a real worker rather than through
  // `TomCacheStoreMessage.execute()`.
  group('Worker-isolate forwarding round trip', () {
    late TomWorker worker;

    setUp(() async {
      worker = await TomWorker.spawn(
        TomWorker.startRemoteIsolate,
        _CacheWorkerContext(),
      );
    });

    tearDown(() => worker.close());

    test(
      'a forwarded read of a cache the creator holds returns the value',
      () async {
        TomCacheManager.addCache(_cache('shared'));
        await TomCache.toNameCache('shared', 'k', 'v');

        final answer = await worker
            .executeCommand(ProbeCacheReadCommand('shared'))
            .timeout(const Duration(seconds: 10));

        expect(answer, 'hit:v');
      },
    );

    test('a forwarded read of a key the creator lacks is a miss', () async {
      // The companion to the failure case: without it, a fix that turned every
      // answer into a failure would still look correct.
      TomCacheManager.addCache(_cache('shared'));

      final answer = await worker
          .executeCommand(ProbeCacheReadCommand('shared'))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'miss');
    });

    test('a creator-side failure reaches the worker as a failure', () async {
      // No cache of this name anywhere, so the creator throws. That must not
      // arrive looking like an empty cache.
      final answer = await worker
          .executeCommand(ProbeCacheReadCommand('nowhere'))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'failed:error.cache_retrieve.not_found client=false');
    });

    test(
      'a forwarded store into a missing cache fails rather than lying',
      () async {
        final answer = await worker
            .executeCommand(ProbeCacheStoreCommand('nowhere'))
            .timeout(const Duration(seconds: 10));

        expect(answer, 'failed:error.cache_store.not_found client=false');
      },
    );

    test(
      'a forwarded store into a cache the creator holds lands there',
      () async {
        TomCacheManager.addCache(_cache('shared'));

        final answer = await worker
            .executeCommand(ProbeCacheStoreCommand('shared'))
            .timeout(const Duration(seconds: 10));

        expect(answer, 'stored:0');
        expect(
          await TomCache.fromNameCache<String>('shared', 'k'),
          'from-worker',
        );
      },
    );

    test('a forwarded store carries the expiry the worker asked for', () async {
      // The store above passes no `deletionTime`, so it exercises the
      // forwarding path with `null` and can say nothing about the one argument
      // whose loss is invisible: the receiving side would fill it in from the
      // cache's `deleteEntriesAfterSeconds` and report the very same success,
      // and the entry would then outlive its intended lifetime until some
      // later read. The cache below would have supplied now+300s of its own
      // accord, so an entry that lands with the worker's instant proves the
      // argument crossed rather than being silently substituted.
      final cache = _cache('shared'); // deleteEntriesAfterSeconds: 300
      TomCacheManager.addCache(cache);
      final asked = DateTime.now().add(const Duration(days: 30));

      final answer = await worker
          .executeCommand(ProbeCacheStoreWithExpiryCommand('shared', asked))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'stored:0');
      expect(cache.getEntry('k')!.deletionTime, asked);
    });

    test(
      'a forwarded store of an already-expired entry reads back as a miss',
      () async {
        // The same fact stated through the public API rather than the entry, so
        // it holds even for a caller that never reaches past `fromNameCache`:
        // had the instant been dropped, the cache's default would have made this
        // value live for five minutes and the read below would hit.
        TomCacheManager.addCache(_cache('shared'));
        final past = DateTime.now().subtract(const Duration(minutes: 1));

        final answer = await worker
            .executeCommand(ProbeCacheStoreWithExpiryCommand('shared', past))
            .timeout(const Duration(seconds: 10));

        expect(answer, 'stored:0');
        expect(await TomCache.fromNameCache<String>('shared', 'k'), isNull);
      },
    );

    test(
      'a forwarded removal from a missing cache fails rather than lying',
      () async {
        // The third helper. A removal that reports success for a cache that
        // exists nowhere is the same lie the store used to tell, and the one
        // helper of the three with no round-trip evidence behind it.
        final answer = await worker
            .executeCommand(ProbeCacheRemoveCommand('nowhere'))
            .timeout(const Duration(seconds: 10));

        expect(
          answer,
          'failed:error.cache_remove.cache_not_found client=false',
        );
      },
    );

    test(
      'a forwarded removal from a cache the creator holds takes effect',
      () async {
        // The companion that keeps the case above honest: a removal must be able
        // to succeed, and succeed by actually removing something.
        TomCacheManager.addCache(_cache('shared'));
        await TomCache.toNameCache('shared', 'k', 'v');

        final answer = await worker
            .executeCommand(ProbeCacheRemoveCommand('shared'))
            .timeout(const Duration(seconds: 10));

        expect(answer, 'removed:0');
        expect(await TomCache.fromNameCache<String>('shared', 'k'), isNull);
      },
    );

    test(
      'a forwarded read of a wrongly typed value fails, not misses',
      () async {
        // The local path throws types_dont_match here. Across the boundary the
        // value came back fine and it is the *conversion* that fails, so no
        // exception marker in the transport can help: the call site has to make
        // the check itself, or a caller asking for the wrong type is told the
        // cache is empty and goes off to recompute a value that is right there.
        TomCacheManager.addCache(_cache('shared'));
        await TomCache.toNameCache('shared', 'k', 42);

        final answer = await worker
            .executeCommand(ProbeCacheReadCommand('shared'))
            .timeout(const Duration(seconds: 10));

        expect(
          answer,
          'failed:error.cache_retrieve.types_dont_match client=false',
        );
      },
    );

    test('a forwarded miss answers null even when T admits Object', () async {
      // A miss arrives as the noResult sentinel rather than as null, so a read
      // whose T accepts any object hands that sentinel back as if it were the
      // cached value — an object no caller has a type for, in place of the
      // `null` the same call returns locally.
      TomCacheManager.addCache(_cache('shared'));

      final answer = await worker
          .executeCommand(ProbeCacheUntypedReadCommand('shared'))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'miss');
    });
  });

  group('Cross-isolate command objects (executed locally)', () {
    test('store message stores into the named cache', () async {
      TomCacheManager.addCache(_cache('c'));
      final ok = await TomCacheStoreMessage('c', 'k', 'v', null).execute();
      expect(ok, isTrue);
      expect(await TomCache.fromNameCache<String>('c', 'k'), 'v');
    });

    test('store message honours a deletion time already past', () async {
      // The message is how a worker isolate asks the main isolate to store, so
      // dropping its deletionTime on arrival is invisible at the call site: the
      // worker's write reports success and the entry outlives the lifetime it
      // asked for. The cache's own 300s default is what it silently fell back
      // to, which is why an already-past instant is the assertion — under the
      // default the value is still readable, so the two outcomes cannot be
      // confused.
      TomCacheManager.addCache(_cache('c'));
      final ok = await TomCacheStoreMessage(
        'c',
        'k',
        'v',
        DateTime.now().subtract(const Duration(hours: 1)),
      ).execute();
      expect(ok, isTrue);
      expect(await TomCache.fromNameCache<String>('c', 'k'), isNull);
    });

    test('store message forwards its deletion time verbatim', () async {
      // The expired case above proves *an* expiry was applied; this proves it
      // is the one the worker asked for, and not the cache default that
      // happened to be shorter.
      TomCacheManager.addCache(_cache('c'));
      final deletionTime = DateTime(2999, 1, 2, 3, 4, 5);
      await TomCacheStoreMessage('c', 'k', 'v', deletionTime).execute();
      expect(
        TomCacheManager.getCache('c')!.getEntry('k')!.deletionTime,
        deletionTime,
      );
    });

    test('retrieve message returns the stored value', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'v');
      final result = await TomCacheRetrieveMessage('c', 'k').execute();
      expect(result, 'v');
    });

    test('remove message deletes the entry', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'v');
      final ok = await TomCacheRemoveMessage('c', 'k').execute();
      expect(ok, isTrue);
      expect(await TomCache.fromNameCache<String>('c', 'k'), isNull);
    });
  });

  group('Construction and properties', () {
    test('exposes its configured name and bounds', () {
      final cache = TomCache(
        'users',
        deleteEntriesAfterSeconds: 30,
        deletionIntervalSeconds: null,
        maximumEntries: 5,
        clearIntervalSeconds: 120,
      );
      addTearDown(cache.stopTimers);
      expect(cache.cacheName, 'users');
      expect(cache.deleteEntriesAfterSeconds, 30);
      expect(cache.deletionIntervalSeconds, isNull);
      expect(cache.maximumEntries, 5);
      expect(cache.clearIntervalSeconds, 120);
    });

    test('forType names the cache after the type', () {
      final cache = TomCache.forType(String, deletionIntervalSeconds: null);
      expect(cache.cacheName, 'String');
    });

    test('an unbounded cache has no maximumEntries', () {
      expect(_cache('u').maximumEntries, isNull);
    });
  });

  group('A non-positive bound is rejected at construction', () {
    // `maximumEntries` is the module's only capacity guarantee, and every
    // document states it as an upper bound. A zero or negative value cannot be
    // honoured under that reading — a cache that may hold no entries at all is
    // a black hole, storing successfully and missing on every read — so it is
    // refused where the caller can still see it, rather than degrading into a
    // one-entry cache that silently contradicts the number it was given.
    test('rejects a bound of zero', () {
      expect(() => TomCache('z', maximumEntries: 0), throwsArgumentError);
    });

    test('rejects a negative bound', () {
      expect(() => TomCache('n', maximumEntries: -1), throwsArgumentError);
    });

    test('forType rejects it too', () {
      // forType delegates to the main constructor, so this pins that the
      // validation sits where both entry points pass through it.
      expect(
        () => TomCache.forType(String, maximumEntries: 0),
        throwsArgumentError,
      );
    });

    test('a bound of one is accepted and holds exactly one entry', () {
      // One is the smallest bound that *can* be honoured, and it is the edge
      // the rule has to stop at: reject `<= 0`, not `< 2`.
      final cache = _cache('one', maximumEntries: 1);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      expect(cache.getEntry('a'), isNull);
      expect(cache.getEntry('b')!.value, 2);
    });

    test('an unbounded cache is unaffected', () {
      expect(() => _cache('u2'), returnsNormally);
      expect(_cache('u2').maximumEntries, isNull);
    });

    test('a rejected bound leaves no timer running', () {
      // The validation has to precede createTimers(). A throw after the timers
      // were installed would leave a live periodic timer in the isolate with
      // no reference by which to cancel it — the construction failed, so the
      // caller never got the object holding it. Counting timer creations in a
      // zone is what makes the ordering observable at all.
      var created = 0;
      final spec = ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, period, f) {
          created++;
          return parent.createPeriodicTimer(zone, period, f);
        },
      );
      runZoned(() {
        expect(
          () => TomCache('t', maximumEntries: 0, clearIntervalSeconds: 60),
          throwsArgumentError,
        );
      }, zoneSpecification: spec);
      expect(created, 0);
    });
  });

  group('getEntry (direct)', () {
    test('returns the stored entry object in an unbounded cache', () {
      final cache = _cache('g');
      final entry = TomCacheEntry('v', DateTime(2999));
      cache.putEntry('k', entry);
      expect(cache.getEntry('k'), same(entry));
    });

    test('returns null for an absent key', () {
      expect(_cache('g').getEntry('absent'), isNull);
    });

    test('does not check expiry — an already-expired entry is still returned', () {
      // getEntry is a raw structural read; the "is it expired?" decision belongs
      // to fromNameCache, not here. An entry whose deletionTime is in the past
      // must still be handed back verbatim.
      final cache = _cache('g');
      cache.putEntry('k', TomCacheEntry('v', DateTime(2000)));
      final entry = cache.getEntry('k');
      expect(entry, isNotNull);
      expect(entry!.value, 'v');
    });

    test(
      'promotes the read entry to most-recently-used in a bounded cache',
      () {
        final cache = _cache('g', maximumEntries: 2);
        cache.putEntry('a', TomCacheEntry(1));
        cache.putEntry('b', TomCacheEntry(2));
        cache.getEntry('a'); // promote 'a' over 'b'
        cache.putEntry('c', TomCacheEntry(3)); // evicts LRU 'b', not 'a'
        expect(cache.getEntry('b'), isNull);
        expect(cache.getEntry('a')!.value, 1);
        expect(cache.getEntry('c')!.value, 3);
      },
    );
  });

  group('putEntry (direct)', () {
    test('stores and overwrites in an unbounded cache', () {
      final cache = _cache('p');
      cache.putEntry('k', TomCacheEntry(1));
      cache.putEntry('k', TomCacheEntry(2));
      expect(cache.getEntry('k')!.value, 2);
    });

    test('evicts the least-recently-used entry past the bound', () {
      final cache = _cache('p', maximumEntries: 2);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      cache.putEntry('c', TomCacheEntry(3)); // evicts 'a'
      expect(cache.getEntry('a'), isNull);
      expect(cache.getEntry('b')!.value, 2);
      expect(cache.getEntry('c')!.value, 3);
    });

    test('replacing the sole entry of a bounded cache updates it in place', () {
      // The single-entry update path clears the backing map and re-inserts, so
      // the cache must end up holding exactly the new value and stay usable.
      final cache = _cache('p', maximumEntries: 2);
      cache.putEntry('k', TomCacheEntry(1));
      cache.putEntry('k', TomCacheEntry(2));
      expect(cache.getEntry('k')!.value, 2);
      cache.putEntry('a', TomCacheEntry(3));
      expect(cache.getEntry('a')!.value, 3);
      expect(cache.getEntry('k')!.value, 2);
    });

    test('replacing a key in a bounded cache leaves no stale entry behind', () {
      // The other replacement tests take the unbounded path and the
      // single-entry path; this one takes the third — a bounded cache holding
      // more than one entry, where the replacement routes through removeEntry.
      //
      // The failure this guards against is invisible at the moment it happens.
      // A replacement that skips the unlink still answers every read
      // correctly — the map holds one value per key either way — and the
      // superseded entry merely sits in the MRU chain unreachable. It surfaces
      // two stores later, when the chain's tail is that ghost and the eviction
      // follows its key: the cache then drops the *live* replacement and keeps
      // the entry it should have dropped. So the assertions have to come after
      // the bound has been crossed twice, and nothing may read the cache in
      // between, since a read promotes and would rewrite the very order under
      // test.
      final cache = _cache('p', maximumEntries: 3);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      cache.putEntry('c', TomCacheEntry(3));
      cache.putEntry('b', TomCacheEntry(20)); // replace: 'b' becomes newest
      cache.putEntry('d', TomCacheEntry(4)); // over bound -> evict LRU 'a'
      cache.putEntry('e', TomCacheEntry(5)); // over bound -> evict LRU 'c'

      expect(cache.getEntry('a'), isNull, reason: 'evicted first, as the LRU');
      expect(cache.getEntry('c'), isNull, reason: 'evicted second, as the LRU');
      expect(
        cache.getEntry('b')!.value,
        20,
        reason:
            'the replacement is the newest entry of the three survivors and '
            'must not be evicted on account of the entry it replaced',
      );
      expect(cache.getEntry('d')!.value, 4);
      expect(cache.getEntry('e')!.value, 5);
    });
  });

  group('removeEntry (direct)', () {
    test('is a no-op for an absent key', () {
      expect(() => _cache('r').removeEntry('ghost'), returnsNormally);
    });

    test('unlinks a middle entry and keeps the bounded chain coherent', () {
      final cache = _cache('r', maximumEntries: 3);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      cache.putEntry('c', TomCacheEntry(3));
      cache.removeEntry('b'); // unlink from the middle of the MRU chain
      expect(cache.getEntry('b'), isNull);
      // The chain is still coherent: filling past the bound evicts the true LRU.
      cache.putEntry('d', TomCacheEntry(4));
      cache.putEntry('e', TomCacheEntry(5)); // over bound -> evict LRU 'a'
      expect(cache.getEntry('a'), isNull);
      expect(cache.getEntry('c')!.value, 3);
      expect(cache.getEntry('e')!.value, 5);
    });
  });

  group('The MRU chain stays coherent across evictions', () {
    // The map and the chain are two views of the same entries, and only the
    // map is observable from outside. A chain that drifts out of step with it
    // is therefore invisible until it produces a wrong *answer* — the wrong
    // entry evicted, or no eviction at all and a cache over its bound. These
    // tests reach the chain the only way a caller can: through the answers.
    test('draining to a single entry and refilling still evicts the LRU', () {
      // The drain is the interesting part. Removing entries until one is left
      // leaves that entry as both head and tail, which is the shape in which a
      // tail repair that only runs when the tail has a predecessor would be
      // skipped. Refilling past the bound then asks the cache to evict it.
      final cache = _cache('drain', maximumEntries: 3);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      cache.putEntry('c', TomCacheEntry(3));
      cache.removeEntry('a');
      cache.removeEntry('b'); // 'c' is now head and tail at once

      cache.putEntry('d', TomCacheEntry(4));
      cache.putEntry('e', TomCacheEntry(5));
      cache.putEntry('f', TomCacheEntry(6)); // over bound -> evict LRU 'c'

      expect(cache.getEntry('c'), isNull);
      expect(cache.getEntry('d')!.value, 4);
      expect(cache.getEntry('e')!.value, 5);
      expect(cache.getEntry('f')!.value, 6);
    });

    test(
      'draining the cache empty and refilling starts from a clean chain',
      () {
        // Removing the last entry has to leave head and tail both unset, or the
        // next put links a fresh entry onto a chain of entries that are gone.
        final cache = _cache('empty', maximumEntries: 2);
        cache.putEntry('a', TomCacheEntry(1));
        cache.putEntry('b', TomCacheEntry(2));
        cache.removeEntry('a');
        cache.removeEntry('b');

        cache.putEntry('x', TomCacheEntry(10));
        cache.putEntry('y', TomCacheEntry(20));
        cache.putEntry('z', TomCacheEntry(30)); // over bound -> evict LRU 'x'

        expect(cache.getEntry('x'), isNull);
        expect(cache.getEntry('y')!.value, 20);
        expect(cache.getEntry('z')!.value, 30);
      },
    );

    test('agrees with a reference LRU over a long random operation mix', () {
      // The hand-written cases above each pin one shape. This one pins the
      // invariant behind all of them: whatever sequence of puts, reads and
      // removes it is driven through, the cache holds exactly the entries an
      // ordinary LRU of the same bound would hold. Any chain that drifts out
      // of step with the map eventually evicts the wrong entry — or fails to
      // evict and grows past the bound — and either shows up here.
      //
      // The verification pass is itself a run of reads, so it promotes; it is
      // applied to the model in the same order and therefore keeps the two in
      // lockstep rather than perturbing one of them. That is what allows it to
      // run every round and name the round that first diverged, instead of
      // once at the end where the diagnosis would be a single failed key.
      const bound = 3;
      final keys = List.generate(8, (i) => 'k$i');
      final random = Random(20260823); // fixed seed: a failure is reproducible
      final cache = _cache('model', maximumEntries: bound);
      final model = _LruModel(bound);

      for (var round = 1; round <= 40; round++) {
        for (var i = 0; i < 15; i++) {
          final key = keys[random.nextInt(keys.length)];
          final roll = random.nextInt(100);
          if (roll < 50) {
            final value = random.nextInt(1000);
            cache.putEntry(key, TomCacheEntry(value));
            model.put(key, value);
          } else if (roll < 85) {
            expect(
              cache.getEntry(key)?.value,
              model.get(key),
              reason: 'round $round: read of $key',
            );
          } else {
            cache.removeEntry(key);
            model.remove(key);
          }
        }
        for (final key in keys) {
          expect(
            cache.getEntry(key)?.value,
            model.get(key),
            reason: 'round $round: contents differ at $key',
          );
        }
      }
    });
  });

  group('Timer lifecycle', () {
    test('the default deletion interval is one hour and installs a timer', () {
      final cache = TomCache('t');
      addTearDown(cache.stopTimers);
      expect(cache.deletionIntervalSeconds, 3600);
      expect(cache.deletionTimer, isNotNull);
      expect(cache.deletionTimer!.isActive, isTrue);
      expect(cache.clearanceTimer, isNull); // no clear interval by default
    });

    test('no timers are installed when both intervals are null', () {
      final cache = TomCache('t', deletionIntervalSeconds: null);
      expect(cache.deletionTimer, isNull);
      expect(cache.clearanceTimer, isNull);
    });

    test('a clear interval installs a clearance timer', () {
      final cache = TomCache(
        't',
        deletionIntervalSeconds: null,
        clearIntervalSeconds: 3600,
      );
      addTearDown(cache.stopTimers);
      expect(cache.clearanceTimer, isNotNull);
      expect(cache.clearanceTimer!.isActive, isTrue);
    });

    test('stopTimers cancels both timers and clears both fields', () {
      // The fields are the documented answer to "is this cache sweeping?", so a
      // stopped cache must not leave a cancelled timer behind for a
      // `deletionTimer != null` check to find. Holding the two timers in locals
      // is what lets both halves be asserted: that they were really cancelled
      // rather than merely dropped, and that the fields no longer name them.
      final cache = TomCache('t', clearIntervalSeconds: 3600);
      final deletion = cache.deletionTimer!;
      final clearance = cache.clearanceTimer!;

      cache.stopTimers();

      expect(deletion.isActive, isFalse);
      expect(clearance.isActive, isFalse);
      expect(cache.deletionTimer, isNull);
      expect(cache.clearanceTimer, isNull);
    });

    test('createTimers restarts a stopped cache', () {
      // Clearing the fields must not make stopping terminal: the pair is a
      // stop/start, not a teardown. Without this, nulling could just as well
      // have been implemented by dropping the intervals.
      final cache = TomCache('t');
      addTearDown(cache.stopTimers);
      cache.stopTimers();
      expect(cache.deletionTimer, isNull);

      cache.createTimers();

      expect(cache.deletionTimer, isNotNull);
      expect(cache.deletionTimer!.isActive, isTrue);
    });

    test('createTimers is idempotent, replacing a running timer', () {
      final cache = TomCache('t');
      addTearDown(cache.stopTimers);
      final first = cache.deletionTimer;
      cache.createTimers(); // cancels `first`, installs a fresh timer
      expect(first!.isActive, isFalse);
      expect(cache.deletionTimer, isNot(same(first)));
      expect(cache.deletionTimer!.isActive, isTrue);
    });
  });

  group('The limits the documentation records', () {
    // `doc/cache.md`'s "Not Yet Implemented" section states these as the
    // module's behaviour today. Prose cannot go red on its own, so closing one
    // of these limits turns the matching test red, which is the signal that the
    // section has a line to lose. The section's remaining two items are covered
    // elsewhere: `getEntry` skipping expiry is pinned by the "getEntry
    // (direct)" group above, and unbatched forwarding is a cost rather than an
    // outcome — pinning it would mean asserting a shape, not a behaviour.

    test('an unbounded cache keeps every entry it is given', () async {
      // Nothing caps the backing map when `maximumEntries` is null, and a value
      // stored into a cache without `deleteEntriesAfterSeconds` carries no
      // `deletionTime` — so the sweep has nothing to find either. Both eviction
      // mechanisms decline and the map grows for the life of the process.
      // Giving `maximumEntries` a default would turn this red.
      final cache = TomCache('unbounded', deletionIntervalSeconds: null);
      TomCacheManager.addCache(cache);
      for (var i = 0; i < 5000; i++) {
        await TomCache.toNameCache('unbounded', 'k$i', i);
      }
      expect(cache.maximumEntries, isNull);
      // The first key survives 4999 later writes: nothing evicted it.
      expect(await TomCache.fromNameCache<int>('unbounded', 'k0'), 0);
      expect(await TomCache.fromNameCache<int>('unbounded', 'k4999'), 4999);
      // And it is not merely unswept-yet — it carries no expiry to sweep.
      expect(cache.getEntry('k0')!.deletionTime, isNull);
    });

    test('the mutators answer 0 whatever they did', () async {
      // Each pair below differs in outcome and agrees in result, which is the
      // whole of the claim: the `int` is a uniform shape, not a count. Making
      // it meaningful — or narrowing it to `void`/`bool` — fails here.
      TomCacheManager.addCache(_cache('c'));
      TomCacheManager.addCache(_cache('String'));
      expect(await TomCache.toNameCache('c', 'k', 'v'), 0); // inserted
      expect(await TomCache.toNameCache('c', 'k', 'w'), 0); // replaced
      expect(await TomCache.removeFromNameCache('c', 'k'), 0); // removed one
      expect(await TomCache.removeFromNameCache('c', 'k'), 0); // removed none
      expect(await TomCache.toTypeCache<String>('k', 'v'), 0);
      expect(await TomCache.removeFromTypeCache<String>('k'), 0);
    });

    test('setCurrent leaves the discarded caches sweeping', () {
      // The registry is swapped, but the caches that went with it keep their
      // timers: they carry on firing against maps no lookup can reach, and each
      // one keeps the isolate alive. The tear-down below is the workaround the
      // absence of a deregistration API forces, and is itself the evidence.
      final orphan = TomCache('orphan', deletionIntervalSeconds: 1);
      addTearDown(orphan.stopTimers);
      TomCacheManager.addCache(orphan);
      TomCacheManager.setCurrent(TomCacheManager());
      expect(TomCacheManager.getCache('orphan'), isNull);
      expect(orphan.deletionTimer!.isActive, isTrue);
    });
  });

  group('The example runs green', () {
    final examplePath = p.join('example', 'cache', 'cache_example.dart');

    test('under exactly the command its header documents', () async {
      // The example is the module's worked demonstration and the source of the
      // completion document's snippets, so it drifts silently unless something
      // runs it. Run it the way a reader would — plain `dart run`, no extra
      // flags — and require the exit code its own checks produce.
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // A crash before the last step would also exit 0 if it were swallowed,
      // so pin that every numbered step actually reported.
      for (var step = 1; step <= 9; step++) {
        expect(result.stdout, contains('$step. '));
      }
    });

    test('with its expectations checked rather than asserted', () async {
      // The test above cannot see the difference on its own: an example that
      // checks nothing exits 0 too. `dart run` leaves assertions disabled —
      // that is what `--enable-asserts` is for — so an `assert` in the example
      // is compiled out under the very command the test above uses, and the
      // run stays green with every expectation violated. The example therefore
      // states its expectations through a throwing helper, and this guards the
      // regression of quietly reverting them to `assert`.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        isNot(contains('assert(')),
        reason: 'an assert in the example does not run under `dart run`',
      );
      expect(source, contains('void check(bool ok, String expectation)'));
    });
  });

  group("The readme's quick start runs green", () {
    // The example is pinned by the group above because it drifts unless
    // something runs it. The readme's quick start is a complete `main()` too,
    // and nothing ran it — so it drifted in the one way this module makes easy:
    // it created a cache, printed its result, and then hung forever on the
    // deletion timer the constructor installs. It was the first thing a reader
    // of the module saw, and the only artefact of the five that got the
    // isolate-lifetime rule wrong. Extracting and running it closes that gap.
    final readmePath = p.join('lib', 'src', 'tomserver', 'cache', 'readme.md');

    /// Returns the `dart` fenced block under the readme's "Quick start"
    /// heading — the program this module tells a reader to start from.
    String quickStartSource() {
      final lines = File(readmePath).readAsLinesSync();
      final heading = lines.indexWhere((l) => l.trim() == '## Quick start');
      expect(
        heading,
        greaterThanOrEqualTo(0),
        reason: 'no Quick start heading',
      );
      final open = lines.indexWhere((l) => l.trim() == '```dart', heading);
      expect(open, greaterThan(heading), reason: 'no dart block after it');
      final close = lines.indexWhere((l) => l.trim() == '```', open + 1);
      expect(close, greaterThan(open), reason: 'unterminated dart block');
      return lines.sublist(open + 1, close).join('\n');
    }

    test(
      'terminates on its own, exactly as written',
      () async {
        // Written to `.dart_tool/` for two reasons: it is gitignored, so the
        // scratch file cannot be committed by accident, and it is inside the
        // package, so the snippet's `package:tom_core_server` import resolves
        // against the real package_config.json rather than a synthesised one.
        final script = File(
          p.join('.dart_tool', 'cache_readme_quick_start.dart'),
        );
        script.writeAsStringSync(quickStartSource());
        addTearDown(() {
          if (script.existsSync()) script.deleteSync();
        });

        final process = await Process.start(Platform.resolvedExecutable, [
          'run',
          script.path,
        ]);
        final out = StringBuffer();
        final err = StringBuffer();
        final drained = Future.wait([
          process.stdout.transform(utf8.decoder).forEach(out.write),
          process.stderr.transform(utf8.decoder).forEach(err.write),
        ]);

        // The watchdog is the whole point of the test. A regression here is a
        // program that never exits, and without a deadline that is a suite that
        // never finishes — a hang reported as a hang says far less than a hang
        // reported as this failure. It has to fire before the framework's own
        // 30s default, hence the explicit Timeout on the test below.
        int exitCode;
        try {
          exitCode = await process.exitCode.timeout(
            const Duration(seconds: 20),
          );
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
          fail(
            'the readme quick start did not terminate within 20s. A cache '
            'installs periodic timers on construction and a live timer keeps '
            'the isolate alive, so the snippet must stop its timers (or exit '
            'explicitly) for the program it shows a reader to return.',
          );
        }
        await drained;

        expect(exitCode, 0, reason: 'quick start failed: $out$err');
        // Exit 0 alone would also be satisfied by a snippet that printed nothing,
        // so pin the output the readme's own `// hello` comment promises.
        expect(out.toString(), contains('hello'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
