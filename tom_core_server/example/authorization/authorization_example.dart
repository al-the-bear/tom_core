/// Executable example for the authorization module of `tom_core_server`.
///
/// Demonstrates the per-token principal cache ([TomAuthorizationCache]) running
/// in the main isolate: storing a resolved [TomPrincipal] under a JWT token,
/// reading it back, getting `null` for an unknown token (a cache miss), and the
/// [TomAuthorizationCacheException] raised when a cached entry has expired --
/// together with the removal that read performs, which turns the next read of
/// the same dead token back into an ordinary miss. It
/// also shows the cross-isolate command objects and the executor that services
/// them, the refusal to cache a token whose `validUntil` claim is unreadable,
/// and the eviction sweep that bounds the map -- started with the first stored
/// principal and stopped again at the end, which is what lets this program
/// terminate on its own.
///
/// Run with `dart run example/authorization/authorization_example.dart`.
/// The same behaviour is covered by `test/authorization_test.dart`.
library;

import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';

/// Builds a client JWT token whose `validUntil` claim is [validFor] from now.
/// Pass a negative duration to obtain an already-expired token.
TomClientJwtToken _token(
  String userId, {
  Duration validFor = const Duration(hours: 2),
}) => TomClientJwtToken(
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
  print(
    '2. unknown token -> miss     : ${miss == null ? 'null (miss)' : miss.username}',
  );
  assert(miss == null);

  // 3. A token whose validUntil is already in the past yields an expired entry.
  //    Reading it throws TomAuthorizationCacheException so the caller can
  //    distinguish "expired, please re-authorize" from a plain cache miss.
  //    That read also drops the entry it rejected -- it holds the map and has
  //    just established the entry is dead -- so the expiry is reported once and
  //    asking again for the same dead token is an ordinary miss rather than a
  //    second throw.
  final bobToken = _token('bob', validFor: const Duration(hours: -1));
  await TomAuthorizationCache.storePrincipal(bobToken, _principal('bob'));
  var threw = false;
  try {
    await TomAuthorizationCache.getPrincipal(bobToken);
  } on TomAuthorizationCacheException catch (e) {
    threw = true;
    print('3. expired entry threw       : ${e.key}');
  }
  assert(threw);
  final afterExpiry = await TomAuthorizationCache.getPrincipal(bobToken);
  print(
    '   the same token again      : '
    '${afterExpiry == null ? 'null (miss - the entry is gone)' : afterExpiry.username}',
  );
  assert(afterExpiry == null);

  // 4. The cross-isolate command objects simply carry their payload; in a
  //    worker isolate getPrincipal/storePrincipal forward one of these to the
  //    main isolate, where TomAuthorizationCacheExecutor turns it back into a
  //    cache call.
  final store = TomAuthorizationCacheStoreMessage(
    aliceToken,
    _principal('alice'),
  );
  final retrieve = TomAuthorizationCacheRetrieveMessage(aliceToken);
  final executor = TomAuthorizationCacheExecutor();
  // Both handled commands hand back the cache call's future rather than
  // awaiting it, so a creator-side refusal travels to the asking worker as a
  // throw. Await it here as the transport would.
  final stored = await (executor.execute(store) as Future<int>);
  print(
    '4. executor store -> $stored, '
    'unknown command -> noResult: ${identical(executor.execute('nope'), TomExecutor.noResult)}',
  );
  assert(stored == 0);
  assert(identical(executor.execute('nope'), TomExecutor.noResult));
  // The retrieve command resolves (asynchronously) to the stored principal.
  final retrieved = await (executor.execute(retrieve) as Future<TomPrincipal?>);
  assert(retrieved?.username == 'alice');

  // 5. A token whose validUntil claim is unreadable is refused rather than
  //    cached under an invented expiry: the entry's lifetime IS the token's,
  //    so a default here would outlive the token authorizing it. The refusal
  //    names the claim and the token, so the log says what was wrong.
  final malformed = TomClientJwtToken(
    '${base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '')}'
    '.${base64Url.encode(utf8.encode('{"userId":"mallory"}')).replaceAll('=', '')}'
    '.unverified',
    decrypt: false,
  );
  try {
    await TomAuthorizationCache.storePrincipal(
      malformed,
      _principal('mallory'),
    );
    assert(false, 'a malformed validUntil must not be cached');
  } on TomAuthorizationCacheException catch (e) {
    print(
      '5. malformed validUntil     : ${e.key} (claim ${e.parameters?['claim']})',
    );
  }
  assert(await TomAuthorizationCache.getPrincipal(malformed) == null);

  // 6. Storing the first principal also started the eviction sweep, which
  //    bounds the map by dropping entries past their expiry. Its interval is
  //    an hour by default; ask for a short one so the demo can watch it work.
  //    The sweep's timer is created in Zone.root either way, so on a server the
  //    request that stores first does not end up owning it.
  //
  //    Step 3's entry is long gone -- the read that rejected it took it with
  //    it -- so the sweep needs a dead entry nobody has asked about. That is
  //    exactly the half of the map the sweep is for: reads shed the dead tokens
  //    somebody presents, the sweep sheds the ones nobody ever comes back for.
  final abandonedToken = _token('carol', validFor: const Duration(hours: -1));
  await TomAuthorizationCache.storePrincipal(
    abandonedToken,
    _principal('carol'),
  );
  print('6. sweep running            : ${TomAuthorizationCache.isEvicting}');
  TomAuthorizationCache.startEviction(
    interval: const Duration(milliseconds: 20),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
  final swept = await TomAuthorizationCache.getPrincipal(abandonedToken);
  final survivor = await TomAuthorizationCache.getPrincipal(aliceToken);
  print(
    '   after the sweep           : abandoned -> '
    '${swept == null ? 'evicted' : swept.username}, '
    'live -> ${survivor?.username}',
  );
  // A miss rather than a rejection: the sweep removed the row, so nothing is
  // left for the read to recognise as expired.
  assert(swept == null);
  assert(survivor?.username == 'alice');
}

Future<void> main() async {
  await run();
  // The sweep is a periodic timer, so it holds the isolate open until it is
  // stopped -- which is why the cache offers a way to stop it instead of
  // leaving callers to call exit(). A server registers the cache with
  // tomShutdownCleanup (`addDisposable(TomAuthorizationCache.instance)`) and
  // gets the same thing on shutdown, plus the cached principals dropped.
  TomAuthorizationCache.stopEviction();
}
