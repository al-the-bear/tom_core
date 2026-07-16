import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A cache with a generous default lifetime so stored entries are retrievable
/// (a readable entry must carry a future deletion time).
TomCache _cache(String name, {int? maximumEntries}) => TomCache(
      name,
      deleteEntriesAfterSeconds: 300,
      deletionIntervalSeconds: null, // no background timer needed under test
      maximumEntries: maximumEntries,
    );

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

    test('returns a value stored without a deletion time (cache forever)', () async {
      // A cache with no default lifetime stores an entry with deletionTime null.
      // Such an entry never expires on its own and must be returned by a read
      // (the "cache forever" contract — see bug §59).
      TomCacheManager.addCache(TomCache('nottl', deletionIntervalSeconds: null));
      await TomCache.toNameCache('nottl', 'k', 'v');
      expect(await TomCache.fromNameCache<String>('nottl', 'k'), 'v');
    });

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
      TomCacheManager.addCache(TomCache.forType(int, deleteEntriesAfterSeconds: 300));
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

    test('reading an entry promotes it so it survives the next eviction', () async {
      TomCacheManager.addCache(_cache('lru', maximumEntries: 2));
      await TomCache.toNameCache('lru', 'a', 1);
      await TomCache.toNameCache('lru', 'b', 2);
      await TomCache.fromNameCache<int>('lru', 'a'); // promote 'a'
      await TomCache.toNameCache('lru', 'c', 3); // evicts 'b', not 'a'
      expect(await TomCache.fromNameCache<int>('lru', 'a'), 1);
      expect(await TomCache.fromNameCache<int>('lru', 'b'), isNull);
      expect(await TomCache.fromNameCache<int>('lru', 'c'), 3);
    });

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
      // linked into the MRU chain (bug §60), not written to the backing map
      // directly — otherwise the next read corrupts/throws and no eviction runs.
      TomCacheManager.addCache(_cache('be', maximumEntries: 2));
      await TomCache.toNameCache('be', 'a', TomCacheEntry(1, DateTime(2999)));
      await TomCache.toNameCache('be', 'b', TomCacheEntry(2, DateTime(2999)));
      await TomCache.toNameCache('be', 'c', TomCacheEntry(3, DateTime(2999))); // evicts 'a'
      expect(await TomCache.fromNameCache<int>('be', 'a'), isNull);
      expect(await TomCache.fromNameCache<int>('be', 'b'), 2);
      expect(await TomCache.fromNameCache<int>('be', 'c'), 3);
    });
  });

  group('Background timers on a bounded cache (chain integrity)', () {
    test('deletion sweep evicts expired entries without breaking the MRU chain',
        () async {
      // Bounded cache + a 1s deletion timer. Before bug §61 was fixed the timer
      // mutated the backing map directly, leaving the MRU chain dangling; after
      // it, the sweep evicts via removeEntry so subsequent put/eviction stay sane.
      final cache = TomCache('sweep', deletionIntervalSeconds: 1, maximumEntries: 3);
      TomCacheManager.addCache(cache);
      try {
        await TomCache.toNameCache(
            'sweep', 'old', 0, DateTime.now().add(const Duration(milliseconds: 200)));
        await TomCache.toNameCache('sweep', 'a', 1, DateTime(2999));
        await TomCache.toNameCache('sweep', 'b', 2, DateTime(2999));
        // Let the deletion timer fire and sweep 'old'.
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        expect(await TomCache.fromNameCache<int>('sweep', 'old'), isNull);
        // The chain must still be coherent: fill past the bound and evict the LRU.
        await TomCache.toNameCache('sweep', 'c', 3, DateTime(2999));
        await TomCache.toNameCache('sweep', 'd', 4, DateTime(2999)); // over bound
        expect(await TomCache.fromNameCache<int>('sweep', 'a'), isNull); // LRU evicted
        expect(await TomCache.fromNameCache<int>('sweep', 'b'), 2);
        expect(await TomCache.fromNameCache<int>('sweep', 'c'), 3);
        expect(await TomCache.fromNameCache<int>('sweep', 'd'), 4);
      } finally {
        cache.stopTimers();
      }
    });

    test('clearance sweep empties the cache and leaves it reusable', () async {
      // Bounded cache + a 1s clearance timer. The clear must reset the MRU chain
      // (bug §61) so the cache is immediately reusable and still bounded.
      final cache = TomCache('clear',
          deletionIntervalSeconds: null, clearIntervalSeconds: 1, maximumEntries: 3);
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
        await TomCache.toNameCache('clear', 'w', 40, DateTime(2999)); // over bound
        expect(await TomCache.fromNameCache<int>('clear', 'x'), isNull); // LRU evicted
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
      TomWorker.isMainIsolate = false;
      TomCacheManager.setCurrent(TomCacheManager()); // useInThisIsolate stays false
    });
    tearDown(() {
      TomWorker.isMainIsolate = true;
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

  group('Cross-isolate command objects (executed locally)', () {
    test('store message stores into the named cache', () async {
      TomCacheManager.addCache(_cache('c'));
      final ok = await TomCacheStoreMessage('c', 'k', 'v', null).execute();
      expect(ok, isTrue);
      expect(await TomCache.fromNameCache<String>('c', 'k'), 'v');
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

    test('promotes the read entry to most-recently-used in a bounded cache', () {
      final cache = _cache('g', maximumEntries: 2);
      cache.putEntry('a', TomCacheEntry(1));
      cache.putEntry('b', TomCacheEntry(2));
      cache.getEntry('a'); // promote 'a' over 'b'
      cache.putEntry('c', TomCacheEntry(3)); // evicts LRU 'b', not 'a'
      expect(cache.getEntry('b'), isNull);
      expect(cache.getEntry('a')!.value, 1);
      expect(cache.getEntry('c')!.value, 3);
    });
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

    test('stopTimers cancels a running deletion timer', () {
      final cache = TomCache('t');
      cache.stopTimers();
      expect(cache.deletionTimer!.isActive, isFalse);
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
}
