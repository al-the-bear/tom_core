/// API keys for service accounts, and request rate limits, step by step,
/// without a database.
///
/// Run with `dart run example/ratelimit/rate_limit_example.dart`. Every step
/// checks its own result, and the run fails when one does not hold.
///
/// The requests go through the same two middlewares a `TomServer` stacks —
/// authentication, then rate limiting — with a handler that answers who it
/// served. The shared implementations (`TomSqlApiKeyStore`,
/// `TomSqlRateLimiter`) need a database and are shown by
/// `test/ratelimit_api_keys_db_test.dart`.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';

/// A connection from [address], as shelf's adapter records it.
class _From implements HttpConnectionInfo {
  _From(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 40000;

  @override
  int get localPort => 8080;
}

Request _get(String from, {String? apiKey}) => Request(
  'GET',
  Uri.parse('http://localhost/api/report'),
  headers: {'x-api-key': ?apiKey},
  context: {TomClientAddress.connectionInfoKey: _From(from)},
);

Future<void> main() async {
  initializeReflection();
  final handler = const Pipeline()
      .addMiddleware(tomDefaultAuthenticationMiddleware('auth'))
      .addMiddleware(tomRateLimitMiddleware())
      .addHandler((request) {
        final principal = getFromCurrentZone<TomPrincipal>();
        return Response.ok(
          principal == null
              ? 'anonymous'
              : '${principal.username} ${principal.aci.roles}',
        );
      });

  // 1. A service account, and a key scoped to one of its two roles.
  final keys = TomApiKeys(store: TomMemoryApiKeyStore());
  TomApiKeys.install(keys);
  await keys.saveAccount(
    const TomServiceAccount(
      id: 'reporter',
      name: 'Report export',
      roles: ['report', 'read'],
    ),
  );
  final issued = await keys.issue('reporter', roles: ['report']);
  print(
    '1. issued                   : ${issued.value.split('.').first}.'
    '${issued.record.id}.<secret>',
  );
  check(issued.value.startsWith('tomk.'), 'a key is recognisable as one');

  // 2. The key authenticates the request as the account, with its scope.
  final served = await handler(_get('198.51.100.4', apiKey: issued.value));
  final who = await served.readAsString();
  print('2. served                   : $who');
  check(who == 'service:reporter [report]', 'the key carries its scope');

  // 3. Rate limits: three requests a minute per key, two per anonymous
  //    address.
  TomRateLimits.install(
    TomRateLimits(
      rules: [
        TomRateLimitRule(
          name: 'keys',
          scope: TomRateLimitScope.apiKey,
          limit: 3,
          window: const Duration(minutes: 1),
        ),
        TomRateLimitRule(
          name: 'anonymous',
          scope: TomRateLimitScope.address,
          limit: 2,
          window: const Duration(minutes: 1),
        ),
      ],
    ),
  );
  final statuses = [
    for (var i = 0; i < 4; i++)
      (await handler(_get('198.51.100.4', apiKey: issued.value))).statusCode,
  ];
  print('3. four requests by the key : $statuses');
  check(
    statuses.join(',') == '200,200,200,429',
    'the fourth request in the minute is refused',
  );

  // 4. The refusal says when to come back.
  final refused = await handler(_get('198.51.100.4', apiKey: issued.value));
  print('4. Retry-After              : ${refused.headers['retry-after']} s');
  check(
    refused.statusCode == 429 && int.parse(refused.headers['retry-after']!) > 0,
    'a 429 always carries Retry-After',
  );

  // 5. Anonymous callers are counted by address, apart from the key.
  final anonymous = [
    for (var i = 0; i < 3; i++) (await handler(_get('203.0.113.9'))).statusCode,
  ];
  print('5. anonymous from one address: $anonymous');
  check(anonymous.join(',') == '200,200,429', 'two per address, then 429');

  // 6. Rotation: the successor works, the old key stops at once.
  TomRateLimits.reset();
  final successor = await keys.rotate(issued.record.id);
  final old = await (await handler(
    _get('198.51.100.4', apiKey: issued.value),
  )).readAsString();
  final fresh = await (await handler(
    _get('198.51.100.4', apiKey: successor.value),
  )).readAsString();
  print('6. old / successor          : $old / $fresh');
  check(
    old == 'anonymous' && fresh.startsWith('service:reporter'),
    'rotation retires the old key',
  );

  // 7. Revocation ends a key at once.
  await keys.revoke(successor.record.id);
  final revoked = await (await handler(
    _get('198.51.100.4', apiKey: successor.value),
  )).readAsString();
  print('7. after revoke             : $revoked');
  check(revoked == 'anonymous', 'a revoked key authenticates nothing');

  TomApiKeys.reset();
}
