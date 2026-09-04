/// Executable example for the cache module of `tom_core_server`.
///
/// Demonstrates the named in-memory cache running in the main isolate: storing
/// and reading a value, per-entry expiry, the entry with no deletion time that
/// never expires, LRU eviction in a bounded cache, removal by type, the
/// [TomCacheException] raised on a type mismatch, a [TomCacheEntry] stored
/// verbatim to carry its own lifetime, stopping a cache's periodic timers, and
/// replacing the current [TomCacheManager].
///
/// Its nine steps run in that order, one per item.
///
/// Run with `dart run example/cache/cache_example.dart`. Every step checks its
/// own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript. `test/cache_test.dart` runs this
/// file under that exact command and requires it to exit 0, which is what keeps
/// the checks honest once nobody runs the example by hand.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

class User {
  final String id;
  User(this.id);
  @override
  String toString() => 'User($id)';
}

Future<void> run() async {
  // 1. A named cache with a default 5-minute entry lifetime: a store that does
  //    not name its own deletion time gets one 300s out. An entry expires only
  //    once it carries a deletion time that has passed, so this one reads back
  //    for the next five minutes.
  TomCacheManager.addCache(
    TomCache('greetings', deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toNameCache('greetings', 'en', 'hello');
  final greeting = await TomCache.fromNameCache<String>('greetings', 'en');
  print('1. stored then read          : $greeting');
  check(greeting == 'hello', 'a stored entry reads back');

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
  check(expired == null, 'an entry past its deletion time reads as a miss');

  // 3. The other half of the same rule: a cache with no default lifetime stores
  //    entries with no deletion time at all, and those never expire on their
  //    own — they are returned by every read until removed, evicted or cleared.
  TomCacheManager.addCache(TomCache('forever'));
  await TomCache.toNameCache('forever', 'pi', '3.14159');
  final kept = await TomCache.fromNameCache<String>('forever', 'pi');
  print('3. entry with no expiry      : $kept');
  check(kept == '3.14159', 'an entry with no deletion time is kept forever');

  // 4. A bounded cache evicts the least-recently-used entry once full.
  TomCacheManager.addCache(
    TomCache('lru', maximumEntries: 2, deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toNameCache('lru', 'a', 1);
  await TomCache.toNameCache('lru', 'b', 2);
  await TomCache.toNameCache('lru', 'c', 3); // evicts 'a' (least recent)
  final a = await TomCache.fromNameCache<int>('lru', 'a');
  final c = await TomCache.fromNameCache<int>('lru', 'c');
  print('4. lru: a -> ${a ?? 'evicted'}, c -> $c');
  check(a == null && c == 3, 'the bound evicts the least-recently-used entry');

  // 5. A type cache is named after the Dart type it holds.
  TomCacheManager.addCache(
    TomCache.forType(User, deleteEntriesAfterSeconds: 300),
  );
  await TomCache.toTypeCache<User>('u-42', User('42'));
  final user = await TomCache.fromTypeCache<User>('u-42');
  print('5. type cache read           : $user');
  check(user?.id == '42', 'a type cache reads back through fromTypeCache');
  await TomCache.removeFromTypeCache<User>('u-42');
  check(
    await TomCache.fromTypeCache<User>('u-42') == null,
    'removeFromTypeCache removes the entry',
  );

  // 6. Reading a value as the wrong type throws TomCacheException.
  await TomCache.toNameCache('greetings', 'num', 123);
  var threw = false;
  try {
    await TomCache.fromNameCache<String>('greetings', 'num');
  } on TomCacheException catch (e) {
    threw = true;
    print('6. type mismatch threw       : ${e.key}');
  }
  check(threw, 'reading a value as the wrong type throws TomCacheException');

  // 7. Passing a TomCacheEntry as the value stores it verbatim, so the entry
  //    keeps its own deletionTime instead of taking the cache's default. The
  //    past instant below is what proves it: 'greetings' has a 300s default
  //    that would have kept this readable, and the read is a miss anyway.
  await TomCache.toNameCache(
    'greetings',
    'flash',
    TomCacheEntry(
      'short-lived',
      DateTime.now().subtract(const Duration(seconds: 1)),
    ),
  );
  final flash = await TomCache.fromNameCache<String>('greetings', 'flash');
  print('7. entry with own lifetime   : ${flash ?? 'null (its own time won)'}');
  check(flash == null, 'a TomCacheEntry keeps its own deletionTime');

  // 8. A cache installs its periodic timers on construction, and a live timer
  //    keeps the isolate alive. A program that outlives its caches must stop
  //    them or exit explicitly — main() below does the latter.
  final ticking = TomCache('ticking', clearIntervalSeconds: 60);
  TomCacheManager.addCache(ticking);
  check(
    ticking.clearanceTimer?.isActive ?? false,
    'a clear interval installs a running clearance timer',
  );
  ticking.stopTimers();
  // A stopped cache clears the field as well as cancelling the timer, so the
  // field is a straight answer to "is this cache still ticking?".
  print('8. timers stopped            : ${ticking.clearanceTimer == null}');
  check(
    ticking.clearanceTimer == null,
    'stopTimers cancels the clearance timer and clears the field',
  );

  // 9. Replacing the current manager discards the registry along with it, which
  //    is what makes it useful between tests. It discards only the *registry*
  //    though: the caches themselves are unreachable now but their timers are
  //    still installed, so stopping them (step 8) has to come first to have
  //    happened at all. Last step here, since it empties the registry.
  check(
    TomCacheManager.getCache('greetings') != null,
    'the cache registered in step 1 is still registered',
  );
  TomCacheManager.setCurrent(TomCacheManager(true));
  print(
    '9. after setCurrent          : ${TomCacheManager.getCache('greetings')}',
  );
  check(
    TomCacheManager.getCache('greetings') == null,
    'setCurrent discards the caches the replaced manager held',
  );
}

Future<void> main() async {
  await run();
  // Each cache installs periodic timers in the main isolate, which keep the
  // process alive; exit explicitly now the demo has finished.
  exit(0);
}
