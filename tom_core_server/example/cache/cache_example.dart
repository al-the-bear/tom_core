/// Executable example for the cache module of `tom_core_server`.
///
/// Demonstrates the named in-memory cache running in the main isolate: storing
/// and reading a value, per-entry expiry, LRU eviction in a bounded cache,
/// removal by type, and the [TomCacheException] raised on a type mismatch.
///
/// Run with `dart run example/cache/cache_example.dart`.
/// The same behaviour is covered by `test/cache_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

class User {
  final String id;
  User(this.id);
  @override
  String toString() => 'User($id)';
}

Future<void> run() async {
  // 1. A named cache with a default 5-minute entry lifetime. A retrievable
  //    entry must carry a deletion time, so deleteEntriesAfterSeconds supplies
  //    one automatically on store.
  TomCacheManager.addCache(
    TomCache('greetings', deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toNameCache('greetings', 'en', 'hello');
  final greeting = await TomCache.fromNameCache<String>('greetings', 'en');
  print('1. stored then read          : $greeting');
  assert(greeting == 'hello');

  // 2. An explicit past deletion time makes the entry expired: the read returns
  //    null (and drops the stale entry).
  await TomCache.toNameCache(
    'greetings',
    'old',
    'stale',
    DateTime.now().subtract(const Duration(seconds: 1)),
  );
  final expired = await TomCache.fromNameCache<String>('greetings', 'old');
  print('2. expired entry read        : ${expired ?? 'null (expired)'}');
  assert(expired == null);

  // 3. A bounded cache evicts the least-recently-used entry once full.
  TomCacheManager.addCache(
    TomCache('lru', maximumEntries: 2, deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toNameCache('lru', 'a', 1);
  await TomCache.toNameCache('lru', 'b', 2);
  await TomCache.toNameCache('lru', 'c', 3); // evicts 'a' (least recent)
  final a = await TomCache.fromNameCache<int>('lru', 'a');
  final c = await TomCache.fromNameCache<int>('lru', 'c');
  print('3. lru: a -> ${a ?? 'evicted'}, c -> $c');
  assert(a == null && c == 3);

  // 4. A type cache is named after the Dart type it holds.
  TomCacheManager.addCache(
    TomCache.forType(User, deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toTypeCache<User>('u-42', User('42'));
  final user = await TomCache.fromTypeCache<User>('u-42');
  print('4. type cache read           : $user');
  assert(user?.id == '42');
  await TomCache.removeFromTypeCache<User>('u-42');
  assert(await TomCache.fromTypeCache<User>('u-42') == null);

  // 5. Reading a value as the wrong type throws TomCacheException.
  await TomCache.toNameCache('greetings', 'num', 123);
  var threw = false;
  try {
    await TomCache.fromNameCache<String>('greetings', 'num');
  } on TomCacheException catch (e) {
    threw = true;
    print('5. type mismatch threw       : ${e.key}');
  }
  assert(threw);
}

Future<void> main() async {
  await run();
  // Each cache installs periodic timers in the main isolate, which keep the
  // process alive; exit explicitly now the demo has finished.
  exit(0);
}
