/// Executable example for the authorization module of `tom_core_server`.
///
/// Demonstrates the per-token principal cache ([TomAuthorizationCache]) running
/// in the main isolate: storing a resolved [TomPrincipal] under a JWT token,
/// reading it back, getting `null` for an unknown token (a cache miss), and the
/// [TomAuthorizationCacheException] raised when a cached entry has expired. It
/// also shows the cross-isolate command objects and the executor that services
/// them.
///
/// Run with `dart run example/authorization/authorization_example.dart`.
/// The same behaviour is covered by `test/authorization_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// Builds a client JWT token whose `validUntil` claim is [validFor] from now.
/// Pass a negative duration to obtain an already-expired token.
TomClientJwtToken _token(String userId, {Duration validFor = const Duration(hours: 2)}) =>
    TomClientJwtToken(
      TomServerJwtToken({'userId': userId}, expiresIn: validFor).getJWT('tom'),
    );

/// A principal for [username], marked authenticated.
TomPrincipal _principal(String username) =>
    TomPrincipal(user: TomUser(username: username), authenticated: true);

Future<void> run() async {
  // 1. Store a resolved principal under its token, then read it back. This is
  //    the hot path: the authorization lookup runs once and is reused.
  final aliceToken = _token('alice');
  await TomAuthorizationCache.storePrincipal(aliceToken, _principal('alice'));

  final cached = await TomAuthorizationCache.getPrincipal(aliceToken);
  print('1. cached principal username : ${cached?.username}');
  assert(cached != null && cached.username == 'alice');

  // 2. An unknown token is a cache miss and returns null (not an error).
  final strangerToken = _token('stranger');
  final miss = await TomAuthorizationCache.getPrincipal(strangerToken);
  print('2. unknown token -> miss     : ${miss == null ? 'null (miss)' : miss.username}');
  assert(miss == null);

  // 3. A token whose validUntil is already in the past yields an expired entry.
  //    Reading it throws TomAuthorizationCacheException so the caller can
  //    distinguish "expired, please re-authorize" from a plain cache miss.
  final expiredToken = _token('bob', validFor: const Duration(hours: -1));
  await TomAuthorizationCache.storePrincipal(expiredToken, _principal('bob'));
  var threw = false;
  try {
    await TomAuthorizationCache.getPrincipal(expiredToken);
  } on TomAuthorizationCacheException catch (e) {
    threw = true;
    print('3. expired entry threw       : ${e.key}');
  }
  assert(threw);

  // 4. The cross-isolate command objects simply carry their payload; in a
  //    worker isolate getPrincipal/storePrincipal forward one of these to the
  //    main isolate, where TomAuthorizationCacheExecutor turns it back into a
  //    cache call.
  final store = TomAuthorizationCacheStoreMessage(aliceToken, _principal('alice'));
  final retrieve = TomAuthorizationCacheRetrieveMessage(aliceToken);
  final executor = TomAuthorizationCacheExecutor();
  print('4. executor store -> ${executor.execute(store)}, '
      'unknown command -> noResult: ${identical(executor.execute('nope'), TomExecutor.noResult)}');
  assert(executor.execute(store) == true);
  assert(identical(executor.execute('nope'), TomExecutor.noResult));
  // The retrieve command resolves (asynchronously) to the stored principal.
  final retrieved =
      await (executor.execute(retrieve) as Future<TomPrincipal?>);
  assert(retrieved?.username == 'alice');
}

Future<void> main() async {
  await run();
  // The cache installs a periodic eviction timer in the main isolate, which
  // keeps the process alive; exit explicitly now the demo has finished.
  exit(0);
}
