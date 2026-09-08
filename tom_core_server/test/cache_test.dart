import 'dart:async';
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

/// Runs [op] and returns the [TomCacheException] it raises, failing the test if
/// it raises nothing. Used where the assertion is about the *contents* of the
/// exception — its `clientThrow`, its message, its cause — rather than merely
/// that one was thrown, which `throwsA` already covers.
Future<TomCacheException> _raised(Future<Object?> Function() op) async {
  try {
    await op();
  } on TomCacheException catch (e) {
    return e;
  }
  fail('expected a TomCacheException');
}

/// A cache that counts the timer builders its construction reaches.
///
/// Used to observe *whether* the constructor got as far as installing timers.
/// The count is static because the construction under test is the one that
/// throws: no instance ever reaches the caller to be asked. It is counted
/// through an override rather than through a `ZoneSpecification` because both
/// timers are created in [Zone.root] (see "both timers belong to the root
/// zone"), which no forked zone can see — a zone counter would read zero
/// whatever the constructor did.
class _TimerCountingCache extends TomCache {
  _TimerCountingCache(
    super.cacheName, {
    super.maximumEntries,
    super.deletionIntervalSeconds,
    super.clearIntervalSeconds,
  });

  static int built = 0;

  @override
  Timer createDeletionTimer() {
    built++;
    return super.createDeletionTimer();
  }

  @override
  Timer createClearanceTimer() {
    built++;
    return super.createClearanceTimer();
  }
}

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
      await TomCache.toNameCache(cacheName, 'k', 'from-worker');
      // A constant, because the store reports nothing but completion. What is
      // under test is which of the three branches below the crossing took.
      return 'stored';
    } on TomCacheException catch (e) {
      return 'failed:${e.key} client=${e.clientThrow}';
    } catch (e) {
      return 'other:${e.runtimeType}';
    }
  }
}

/// Runs inside a WORKER isolate and tries to forward a store of `null`.
///
/// The refusal has to happen on *this* side, before the crossing. A null that
/// reaches the creator is stored there like any other value, and the worker is
/// told the write succeeded — so the mistake would surface, if at all, at some
/// later read on the other isolate, with nothing left to say where it came
/// from.
///
/// The call is made through a `dynamic` tear-off because the signature refuses
/// `null` at compile time, which is the protection an ordinary call site gets.
/// A caller arriving through reflection or a script has no such protection, and
/// this is the shape it arrives in.
class ProbeCacheStoreNullCommand extends TomCommand {
  final String cacheName;

  ProbeCacheStoreNullCommand(this.cacheName);

  @override
  Future<Object?> execute() async {
    if (TomWorker.isMainIsolate) return 'not-a-worker';
    final dynamic store = TomCache.toNameCache;
    try {
      await store(cacheName, 'k', null);
      return 'stored';
    } on TypeError {
      return 'refused';
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
      await TomCache.toNameCache(cacheName, 'k', 'from-worker', deletionTime);
      return 'stored';
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
      await TomCache.removeFromNameCache(cacheName, 'k');
      return 'removed';
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

    test('drops the expired entry rather than merely reporting a miss', () {
      // The read is also the sweep for the key it touches: an unbounded cache
      // has no eviction and a bounded one evicts by recency, so an entry nobody
      // reads again is held until the background timer runs -- and a cache with
      // no `deletionIntervalSeconds` has no timer at all. Without this the
      // expired value stays in the map for the life of the process.
      //
      // Asserted through the cache object rather than through a second read,
      // which would answer `null` either way and so could not tell "dropped"
      // from "still there and still expired". Found by mutation: deleting the
      // `removeEntry` left the whole suite green.
      final cache = _cache('c');
      TomCacheManager.addCache(cache);
      cache.putEntry(
        'k',
        TomCacheEntry('v', DateTime.now().subtract(const Duration(seconds: 1))),
      );
      expect(
        cache.getEntry('k'),
        isNotNull,
        reason: 'the premise: it is there',
      );

      expect(TomCache.fromNameCache<String>('c', 'k'), completion(isNull));

      expect(cache.getEntry('k'), isNull);
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

    test('the mutators report completion and nothing else', () async {
      // The calls below differ in outcome — inserted, replaced, removed a
      // present key, removed an absent one — and the API distinguishes none of
      // them, by design: a store or a removal either happens or throws, so
      // completion is the whole answer and there is nothing to branch on.
      //
      // Removing an absent key earns its line: it is the one case a reader
      // might expect to be an error, and it is not.
      TomCacheManager.addCache(_cache('c'));
      TomCacheManager.addCache(_cache('String'));
      await expectLater(TomCache.toNameCache('c', 'k', 'v'), completes);
      await expectLater(TomCache.toNameCache('c', 'k', 'w'), completes);
      await expectLater(TomCache.removeFromNameCache('c', 'k'), completes);
      await expectLater(TomCache.removeFromNameCache('c', 'k'), completes);
      await expectLater(TomCache.toTypeCache<String>('k', 'v'), completes);
      await expectLater(TomCache.removeFromTypeCache<String>('k'), completes);
    });
  });

  group('A cached null cannot exist', () {
    // `null` is the answer a read gives for a miss and for an expiry, so a
    // *stored* null is a value no read can surface. Admitted, it had two
    // outcomes and neither was the one the caller asked for: the non-nullable
    // read failed its cast and reported "Cached value of type Null is not of
    // type String" — a value the cache had been explicitly asked to hold,
    // reported as a storage fault — while the nullable read returned `null`,
    // which the caller cannot tell from absence. Across an isolate it was a
    // third answer again: a forwarded read translates a creator-side `null`
    // back into a miss, so the same entry read as "not there".
    //
    // The cache refuses it, for the reason the constructor already refuses a
    // non-positive `maximumEntries`: a store that reports success while every
    // read misses is a black hole, and the store is the earliest place that can
    // say so. Refusing also keeps the slot — an admitted null counts against a
    // bounded cache's `maximumEntries` and can evict a live entry to hold
    // something nothing will ever read.
    //
    // The refusal is the parameter type, so an ordinary call site is stopped by
    // the analyzer before the program runs. These tests reach the helpers
    // through `dynamic` because that is the one shape the analyzer cannot stop
    // — a call arriving through reflection or a script — and because a
    // signature widened back to `Object?` has to fail something.

    test('the store refuses a null value', () {
      TomCacheManager.addCache(_cache('c'));
      final dynamic store = TomCache.toNameCache;
      expect(() => store('c', 'k', null), throwsA(isA<TypeError>()));
    });

    test('the type-named store refuses one too', () {
      TomCacheManager.addCache(
        TomCache.forType(int, deleteEntriesAfterSeconds: 300),
      );
      final dynamic store = TomCache.toTypeCache<int>;
      expect(() => store('k', null), throwsA(isA<TypeError>()));
    });

    test('and an entry cannot be built around one', () {
      // The second entrance. `toNameCache` takes a prepared `TomCacheEntry` as
      // a value and stores it as it stands, and `putEntry` is public — so a
      // rule enforced only on the helper's own parameter would have a hole
      // exactly one constructor wide.
      final dynamic entry = TomCacheEntry.new;
      expect(() => entry(null), throwsA(isA<TypeError>()));
    });

    test('the refusal leaves the cache as it was', () async {
      // Refusing after `putEntry` would be no better than admitting: the entry
      // would be in the map, counted against the bound, and — in a cache at its
      // bound — would already have evicted the least-recently-used live value
      // on its way in. So the bound is 1 and the cache is full.
      TomCacheManager.addCache(_cache('bounded', maximumEntries: 1));
      await TomCache.toNameCache('bounded', 'live', 'kept');

      final dynamic store = TomCache.toNameCache;
      expect(() => store('bounded', 'k', null), throwsA(isA<TypeError>()));

      expect(await TomCache.fromNameCache<String>('bounded', 'live'), 'kept');
    });

    test('so a read of the key that was refused is a miss, not a mismatch', () {
      // The outcome the caller sees, and the point of the whole group: asking
      // for a `String` under a key whose store was refused answers `null` —
      // the cache is empty of it — rather than raising a type mismatch that
      // blames the storage for a value the caller supplied.
      TomCacheManager.addCache(_cache('c'));
      final dynamic store = TomCache.toNameCache;
      expect(() => store('c', 'k', null), throwsA(isA<TypeError>()));

      expect(TomCache.fromNameCache<String>('c', 'k'), completion(isNull));
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
          expect((await _raised(op)).clientThrow, isFalse);
        }
      },
    );

    test('a type mismatch is not client-throwable', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 123);
      final e = await _raised(() => TomCache.fromNameCache<String>('c', 'k'));
      expect(e.clientThrow, isFalse);
    });

    test('a type mismatch names the type it found, not the value', () async {
      // The value's contents explain nothing about why the cast failed, and a
      // cache holds whatever a caller put in it — a session token as readily
      // as a greeting. The type is the diagnosis; rendering the payload into a
      // logged message is only a leak.
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'super-secret-token');
      final e = await _raised(() => TomCache.fromNameCache<int>('c', 'k'));
      expect(e.defaultUserMessage, isNot(contains('super-secret-token')));
      expect(e.defaultUserMessage, contains('String'));
      expect(e.defaultUserMessage, contains('int'));
    });
  });

  group('The type mismatch keeps its cause', () {
    // The mismatch is the only failure in this module with a genuine underlying
    // error: the other three raise sites decide by inspection and have nothing
    // to attach. So this is the only place where dropping the cause would cost
    // anything, and the only place worth pinning.

    test('a type mismatch carries the cast error as its cause', () async {
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 123);
      final e = await _raised(() => TomCache.fromNameCache<String>('c', 'k'));

      // The TypeError says something the wrapper's message cannot: it names the
      // target type as the *runtime* resolved it, where `$T` is only ever as
      // specific as the type argument the caller wrote.
      expect(e.rootException, isA<TypeError>());
      expect(
        e.rootException.toString(),
        allOf(contains('int'), contains('String')),
      );
    });

    test('the reported stack is the cast site, not the catch block', () async {
      // The catch passes the trace it was handed rather than letting the
      // exception capture StackTrace.current where it is constructed. Both
      // traces name fromNameCache, so a test that only looked for the method
      // would pass either way; what distinguishes them is the *line*, and the
      // head frame is the cast rather than the throw a few lines below it.
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 123);
      final e = await _raised(() => TomCache.fromNameCache<String>('c', 'k'));

      expect(e.stack, isA<StackTrace>());
      final head = e.stack.toString().split('\n').first;
      expect(head, contains('fromNameCache'));
      expect(head, contains('server_cache.dart'));
    });

    test('the attached cause does not leak the cached value either', () async {
      // Attaching a cause widens the no-leak guarantee that the test above
      // ("names the type it found, not the value") makes of the message alone:
      // TomBaseException.toString() renders rootException, so from here on the
      // cause's own wording appears in every logged form of this exception. A
      // TypeError reports types and never the value that failed to convert —
      // that is a property of the runtime, so it is asserted rather than
      // assumed.
      TomCacheManager.addCache(_cache('c'));
      await TomCache.toNameCache('c', 'k', 'super-secret-token');
      final e = await _raised(() => TomCache.fromNameCache<int>('c', 'k'));

      expect(e.rootException.toString(), isNot(contains('super-secret-token')));
      expect(e.toString(), isNot(contains('super-secret-token')));
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

        expect(answer, 'stored');
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

      expect(answer, 'stored');
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

        expect(answer, 'stored');
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

        expect(answer, 'removed');
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

    test('a forwarded store of null is refused before it crosses', () async {
      // Refusing on the creator side would be too late to be useful: the worker
      // would be told nothing, since a forwarded store reports the creator's
      // success, and the value would already have travelled. Refusing in the
      // worker means the caller learns it at the statement that made the
      // mistake, and the creator's cache never sees the key at all.
      TomCacheManager.addCache(_cache('shared'));

      final answer = await worker
          .executeCommand(ProbeCacheStoreNullCommand('shared'))
          .timeout(const Duration(seconds: 10));

      expect(answer, 'refused');
      expect(await TomCache.fromNameCache<String>('shared', 'k'), isNull);
    });

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

  group('Non-positive configuration is rejected at construction', () {
    // The constructor takes four numbers, and not one of them has a meaning at
    // or below zero. `null` is how each is switched off, and each already
    // works: no bound, no deletion sweep, no clearance sweep, no expiry by age.
    // So a zero is never a caller saying "off" — there is already a way to say
    // that. It is a caller whose arithmetic produced a number the cache cannot
    // honour.
    //
    // What the number then does differs per parameter, which is why all four
    // are pinned rather than one standing in for the rest:
    //
    //   * `maximumEntries` — a cache allowed to hold no entries at all is a
    //     black hole: every store reports success and every read misses.
    //   * `deletionIntervalSeconds` / `clearIntervalSeconds` — a zero
    //     [Duration] does not mean "never" to [Timer.periodic], it means "as
    //     fast as the event loop will run it". Measured: a zero-period timer
    //     ticked ~73,000 times in 50 ms and a negative-period one ~86,000
    //     (a negative period is treated as zero). That is a core burnt sweeping
    //     a map, and nothing reports it.
    //   * `deleteEntriesAfterSeconds` — every entry is stored already expired,
    //     so the cache is a black hole again, by the other mechanism.
    //
    // None of the four announces itself. The constructor is the last point at
    // which the caller that computed the number is still there to be told.

    /// Each configuration number as a construction that passes [value] for that
    /// parameter and leaves the rest switched off, so a failure names one
    /// parameter rather than a combination.
    final parameters = <String, TomCache Function(int)>{
      'maximumEntries': (v) =>
          TomCache('x', deletionIntervalSeconds: null, maximumEntries: v),
      'deletionIntervalSeconds': (v) =>
          TomCache('x', deletionIntervalSeconds: v),
      'clearIntervalSeconds': (v) =>
          TomCache('x', deletionIntervalSeconds: null, clearIntervalSeconds: v),
      'deleteEntriesAfterSeconds': (v) => TomCache(
        'x',
        deletionIntervalSeconds: null,
        deleteEntriesAfterSeconds: v,
      ),
    };

    for (final parameter in parameters.entries) {
      test('${parameter.key} rejects zero and negative values', () {
        // The error is asserted by name and value, not merely by type. An
        // ArgumentError that named the wrong parameter would send the caller
        // to the wrong number in its own configuration, which for four numbers
        // sharing one constructor is the whole difference between a usable
        // message and a puzzle.
        for (final value in [0, -1]) {
          expect(
            () => parameter.value(value),
            throwsA(
              isA<ArgumentError>()
                  .having((e) => e.name, 'name', parameter.key)
                  .having((e) => e.invalidValue, 'invalidValue', value),
            ),
            reason: '$value should be refused for ${parameter.key}',
          );
        }
      });
    }

    test('null still switches each of them off', () {
      // `null` is the documented "off" for all four, and is what makes zero
      // unnecessary as a second way of saying it. Refusing zero must not have
      // been implemented by refusing everything that is not a positive number.
      final cache = TomCache(
        'off',
        deletionIntervalSeconds: null,
        clearIntervalSeconds: null,
        deleteEntriesAfterSeconds: null,
        maximumEntries: null,
      );
      expect(cache.deletionTimer, isNull);
      expect(cache.clearanceTimer, isNull);
      expect(cache.maximumEntries, isNull);
      expect(cache.deleteEntriesAfterSeconds, isNull);
    });

    test('one is accepted for each of them', () {
      // One is the smallest value every one of the four can honour, and it is
      // the edge the rule has to stop at: reject `<= 0`, not `< 2`.
      final cache = TomCache(
        'one',
        deletionIntervalSeconds: 1,
        clearIntervalSeconds: 1,
        deleteEntriesAfterSeconds: 1,
        maximumEntries: 1,
      );
      addTearDown(cache.stopTimers);
      expect(cache.deletionTimer!.isActive, isTrue);
      expect(cache.clearanceTimer!.isActive, isTrue);
      expect(cache.maximumEntries, 1);
      expect(cache.deleteEntriesAfterSeconds, 1);
    });

    test('forType is validated the same way', () {
      // forType delegates to the main constructor, so this pins that the
      // validation sits where both entry points pass through it — for every
      // parameter, since forType restates the whole signature by hand and could
      // have diverged on any one of them.
      expect(
        () => TomCache.forType(
          String,
          deletionIntervalSeconds: null,
          maximumEntries: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TomCache.forType(String, deletionIntervalSeconds: 0),
        throwsArgumentError,
      );
      expect(
        () => TomCache.forType(
          String,
          deletionIntervalSeconds: null,
          clearIntervalSeconds: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TomCache.forType(
          String,
          deletionIntervalSeconds: null,
          deleteEntriesAfterSeconds: 0,
        ),
        throwsArgumentError,
      );
    });

    test('a bound of one is accepted and holds exactly one entry', () {
      // The edge test above reads the bound back off the cache; this one asks
      // the cache to honour it, which is the claim that matters.
      final cache = _cache('one-behaviour', maximumEntries: 1);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      expect(cache.getEntry('a'), isNull);
      expect(cache.getEntry('b')!.value, 2);
    });

    test('an unbounded cache is unaffected', () {
      expect(() => _cache('u2'), returnsNormally);
      expect(_cache('u2').maximumEntries, isNull);
    });

    test('a rejected value leaves no timer running', () {
      // The validation has to precede createTimers(). A throw after the timers
      // were installed would strand a live periodic timer in the isolate with
      // no reference by which to cancel it — the construction failed, so the
      // caller never got the object holding it.
      //
      // A rejected *interval* is the sharp case, and the reason this test is
      // not satisfied by the bound alone: createTimers builds the clearance
      // timer before the deletion one, so a check made inside the builders
      // rather than here would let a good clearance interval install its timer
      // and only then refuse the bad deletion interval beside it — stranding
      // precisely the timer this ordering exists to prevent.
      _TimerCountingCache.built = 0;
      expect(
        () => _TimerCountingCache(
          't',
          deletionIntervalSeconds: 0,
          clearIntervalSeconds: 60,
        ),
        throwsArgumentError,
      );
      expect(_TimerCountingCache.built, 0);

      _TimerCountingCache.built = 0;
      expect(
        () => _TimerCountingCache(
          't2',
          maximumEntries: 0,
          clearIntervalSeconds: 60,
        ),
        throwsArgumentError,
      );
      expect(_TimerCountingCache.built, 0);

      // And the counter would have said so: the same construction with values
      // it can honour reaches both builders. Without this the assertions above
      // would hold just as well for a counter that never counts anything.
      final accepted = _TimerCountingCache(
        't3',
        maximumEntries: 1,
        clearIntervalSeconds: 60,
      );
      addTearDown(accepted.stopTimers);
      expect(_TimerCountingCache.built, 2);
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

    test(
      'both timers belong to the root zone, not to whoever constructed the '
      'cache',
      () async {
        // The scenario this pins: a cache is a process-lifetime object --
        // TomCacheManager holds it in a static map for the life of the isolate
        // -- but nothing says where it is constructed, and `TomCache.forType`
        // is reached lazily from endpoint code. The pipeline runs each request
        // in its own zone to carry the principal, so timers created with
        // Zone.current would be parented to one request's zone: process-lifetime
        // work answering to that request's error handling and teardown long
        // after the request is gone, in a zone chosen by whichever caller
        // happened to arrive first.
        //
        // The caller's zone is instrumented rather than inspected: a timer a
        // zone owns is one it was asked to create (createPeriodicTimer) and
        // whose callback it later runs (runUnary, with the Timer as argument).
        // Both counters staying at zero is what "not this zone's timer" means,
        // and either would rise again the moment Zone.current came back.
        var timersCreatedHere = 0;
        var callbacksRunHere = 0;
        final requestZoneSpec = ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, period, f) {
            timersCreatedHere++;
            return parent.createPeriodicTimer(zone, period, f);
          },
          runUnary: <R, T>(self, parent, zone, f, arg) {
            if (arg is Timer) callbacksRunHere++;
            return parent.runUnary(zone, f, arg);
          },
        );

        // One cache per timer kind, so each callback can be shown to have run
        // its own work. A single cache with both timers at the same interval
        // would leave the clearance sweep able to explain the deletion sweep's
        // result, and neither would be pinned.
        late final TomCache sweeper;
        late final TomCache clearer;
        runZoned(() {
          sweeper = TomCache('zone-pinned-sweeper', deletionIntervalSeconds: 1);
          clearer = TomCache(
            'zone-pinned-clearer',
            deletionIntervalSeconds: null,
            clearIntervalSeconds: 1,
          );
        }, zoneSpecification: requestZoneSpec);
        addTearDown(sweeper.stopTimers);
        addTearDown(clearer.stopTimers);
        expect(timersCreatedHere, 0, reason: 'neither timer is this zone\'s');

        // Outside the zone now -- as a server is once the request has finished.
        sweeper.putEntry(
          'stale',
          TomCacheEntry(
            'gone',
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
        );
        sweeper.putEntry('fresh', TomCacheEntry('kept'));
        clearer.putEntry('anything', TomCacheEntry('also gone'));

        await Future<void>.delayed(const Duration(milliseconds: 1200));

        expect(callbacksRunHere, 0, reason: 'nor does this zone run them');
        // And they are working timers, not merely ones this zone never saw. The
        // deletion sweep is the discriminating case: it took the expired entry
        // and left the live one, which a clear could not have done.
        expect(sweeper.getEntry('stale'), isNull);
        expect(sweeper.getEntry('fresh')!.value, 'kept');
        expect(clearer.getEntry('anything'), isNull);
      },
      // Both timers are periodic at the shortest interval the seconds-based
      // configuration allows, so this test cannot be faster than one tick.
      timeout: const Timeout(Duration(seconds: 15)),
    );
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
    final guidePath = p.join('doc', 'cache.md');

    /// The numbers of the example's numbered steps, in the order they appear.
    ///
    /// A step is a top-level comment in `run()` opening with `// <n>.`, which is
    /// the shape every one of them has and nothing else in the file does — the
    /// continuation lines of a step's comment are indented past it.
    List<int> exampleStepNumbers() => RegExp(r'^  // (\d+)\. ', multiLine: true)
        .allMatches(File(examplePath).readAsStringSync())
        .map((m) => int.parse(m.group(1)!))
        .toList();

    /// The numbers of the `### <n>.` subsections under the guide's
    /// "Walkthrough" heading, in the order they appear.
    List<int> walkthroughStepNumbers() {
      final lines = File(guidePath).readAsLinesSync();
      final heading = lines.indexWhere((l) => l.trim() == '## Walkthrough');
      expect(
        heading,
        greaterThanOrEqualTo(0),
        reason: 'no Walkthrough heading',
      );
      final next = lines.indexWhere((l) => l.startsWith('## '), heading + 1);
      final section = lines.sublist(heading, next < 0 ? lines.length : next);
      return section
          .map((l) => RegExp(r'^### (\d+)\. ').firstMatch(l))
          .whereType<RegExpMatch>()
          .map((m) => int.parse(m.group(1)!))
          .toList();
    }

    test('under exactly the command its header documents', () async {
      // The example is the module's worked demonstration and the source of the
      // guide's walkthrough, so it drifts silently unless something runs it.
      // Run it the way a reader would — plain `dart run`, no extra flags — and
      // require the exit code its own checks produce.
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
      // so pin that every numbered step actually reported. The numbers come
      // from the file rather than from a literal here, so adding a step does
      // not leave this loop checking a prefix of the example.
      final steps = exampleStepNumbers();
      expect(
        steps,
        isNotEmpty,
        reason: 'no numbered steps found in the example',
      );
      for (final step in steps) {
        expect(result.stdout, contains('$step. '));
      }
    });

    test('with its steps matching the guide walkthrough one for one', () {
      // `doc/cache.md` reproduces the example as its "Walkthrough", and both
      // the guide and the example's header say the correspondence is one for
      // one and in order. That claim is the reason the walkthrough is worth
      // reading — it is what makes the snippets code the suite has run — so it
      // has to be checked rather than merely asserted in prose.
      //
      // The check is against the *shipped* guide deliberately: that is the copy
      // a reader of the package can reach, so it is the one whose drift would
      // mislead. A stated correspondence that nothing counts is worth exactly
      // the reader's willingness to believe it.
      expect(walkthroughStepNumbers(), exampleStepNumbers());

      // Numbering that starts at 1 and never skips, so "step 7" means the same
      // thing on both sides. The equality above would be satisfied by two
      // identically-wrong sequences.
      expect(
        exampleStepNumbers(),
        List<int>.generate(exampleStepNumbers().length, (i) => i + 1),
      );
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
      expect(
        source,
        contains("import '../_support/check.dart'"),
        reason: 'the example states its expectations through the shared helper',
      );
    });
  });
}
