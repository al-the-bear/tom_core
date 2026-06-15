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

    test('does not return a value stored without a deletion time', () async {
      // A cache with no default lifetime stores an entry with deletionTime null,
      // which fromNameCache will not return. Documents the TTL requirement.
      TomCacheManager.addCache(TomCache('nottl', deletionIntervalSeconds: null));
      await TomCache.toNameCache('nottl', 'k', 'v');
      expect(await TomCache.fromNameCache<String>('nottl', 'k'), isNull);
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
}
