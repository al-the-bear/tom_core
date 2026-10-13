/// Request rate limiting: the sliding-window arithmetic, the in-process
/// limiter, and the middleware — per principal, per API key and per address,
/// answered with 429 and Retry-After.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// A connection seen from [address], as shelf's adapter records it.
class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 40000;

  @override
  int get localPort => 8080;
}

Request _request(
  String address, {
  String path = '/api/items',
  String method = 'GET',
  Map<String, String> headers = const {},
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: headers,
  context: {TomClientAddress.connectionInfoKey: _Connection(address)},
);

void main() {
  setUpAll(initializeReflection);

  group('the sliding-window arithmetic', () {
    TomRateLimitDecision decide({
      required int current,
      int previous = 0,
      int elapsedSeconds = 0,
      int limit = 10,
    }) => TomRateLimitDecision.slidingWindow(
      limit: limit,
      window: const Duration(seconds: 60),
      elapsed: Duration(seconds: elapsedSeconds),
      current: current,
      previous: previous,
    );

    test('within the limit: allowed, with what remains', () {
      final d = decide(current: 4, elapsedSeconds: 15);
      expect(d.allowed, isTrue);
      expect(d.remaining, 6);
      expect(d.reset, const Duration(seconds: 45));
    });

    test('the previous window counts by how much of it still overlaps', () {
      // Half-way through: half of the previous window's 10 still counts.
      expect(
        decide(current: 5, previous: 10, elapsedSeconds: 30).allowed,
        isTrue,
      );
      expect(
        decide(current: 6, previous: 10, elapsedSeconds: 30).allowed,
        isFalse,
      );
    });

    test('over the limit in this window: wait into the next one', () {
      final d = decide(current: 11, elapsedSeconds: 50);
      expect(d.allowed, isFalse);
      // 10 s to the window's end, then until the 11 weigh no more than 9.
      expect(d.retryAfter.inSeconds, greaterThanOrEqualTo(10));
      expect(d.retryAfterSeconds, greaterThanOrEqualTo(10));
    });

    test('held back by the previous window: wait until its weight drops', () {
      final d = decide(current: 6, previous: 10, elapsedSeconds: 30);
      expect(d.allowed, isFalse);
      expect(d.retryAfter > Duration.zero, isTrue);
      expect(d.retryAfter < const Duration(seconds: 30), isTrue);
    });

    test('Retry-After is at least one second', () {
      final d = TomRateLimitDecision(
        allowed: false,
        limit: 1,
        remaining: 0,
        reset: Duration.zero,
        retryAfter: const Duration(milliseconds: 1),
      );
      expect(d.retryAfterSeconds, 1);
    });
  });

  group('TomMemoryRateLimiter', () {
    test('admits the limit, refuses the next, admits again in time', () async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final limiter = TomMemoryRateLimiter(clock: () => now);
      final rule = TomRateLimitRule(
        name: 'r',
        scope: TomRateLimitScope.address,
        limit: 3,
        window: const Duration(seconds: 10),
      );
      for (var i = 0; i < 3; i++) {
        expect((await limiter.hit('k', rule)).allowed, isTrue);
      }
      final refused = await limiter.hit('k', rule);
      expect(refused.allowed, isFalse);
      // Another key is counted apart.
      expect((await limiter.hit('other', rule)).allowed, isTrue);
      // Two whole windows later nothing still counts.
      now = now.add(const Duration(seconds: 20));
      expect((await limiter.hit('k', rule)).allowed, isTrue);
    });
  });

  group('rules', () {
    test('need a positive limit and window', () {
      expect(
        () => TomRateLimitRule(
          name: 'bad',
          scope: TomRateLimitScope.principal,
          limit: 0,
          window: const Duration(seconds: 1),
        ),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.invalid_rule',
          ),
        ),
      );
    });

    test('a configuration that is not a map is refused by name', () {
      expect(
        () => TomRateLimits.fromConfiguration(
          TomServerConfigResourceProvider.from({'rateLimits': 'fast'}),
        ),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.not_a_map',
          ),
        ),
      );
    });

    test('the sql limiter without a registered data source is refused', () {
      expect(
        () => TomRateLimits.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'rateLimits': {
              'limiter': 'sql',
              'datasource': 'no_such_datasource',
              'rules': [],
            },
          }),
        ),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.missing_datasource',
          ),
        ),
      );
    });

    test('must be uniquely named', () {
      TomRateLimitRule rule() => TomRateLimitRule(
        name: 'same',
        scope: TomRateLimitScope.address,
        limit: 1,
        window: const Duration(seconds: 1),
      );
      expect(
        () => TomRateLimits(rules: [rule(), rule()]),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.duplicate_rule',
          ),
        ),
      );
    });

    test('are read from the rateLimits configuration key', () {
      final limits = TomRateLimits.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'rateLimits': {
            'trustedProxies': ['10.0.0.2'],
            'rules': [
              {
                'name': 'users',
                'per': 'principal',
                'limit': 100,
                'windowSeconds': 60,
              },
              {
                'name': 'keys',
                'per': 'api-key',
                'limit': '600',
                'windowSeconds': 60,
                'paths': ['/api'],
              },
              {
                'name': 'anonymous',
                'per': 'address',
                'limit': 60,
                'windowSeconds': 60,
                'anonymousOnly': false,
              },
            ],
          },
        }),
      )!;
      expect(limits.rules.map((r) => r.scope), [
        TomRateLimitScope.principal,
        TomRateLimitScope.apiKey,
        TomRateLimitScope.address,
      ]);
      expect(limits.rules[1].limit, 600);
      expect(limits.rules[1].pathPrefixes, ['/api']);
      expect(limits.rules[2].anonymousOnly, isFalse);
      expect(limits.trustedProxies, {'10.0.0.2'});
      expect(limits.limiter, isA<TomMemoryRateLimiter>());
    });

    test('are absent without the key: nothing is limited by default', () {
      expect(
        TomRateLimits.fromConfiguration(
          TomServerConfigResourceProvider.from({}),
        ),
        isNull,
      );
    });

    test('an unknown scope or limiter is refused by name', () {
      expect(
        () => TomRateLimits.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'rateLimits': {
              'rules': [
                {'per': 'planet', 'limit': 1, 'windowSeconds': 1},
              ],
            },
          }),
        ),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.unknown_scope',
          ),
        ),
      );
      expect(
        () => TomRateLimits.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'rateLimits': {'limiter': 'redis', 'rules': []},
          }),
        ),
        throwsA(
          isA<TomRateLimitException>().having(
            (e) => e.key,
            'key',
            'rate_limit.config.unknown_limiter',
          ),
        ),
      );
    });
  });

  group('TomClientAddress', () {
    test('is the socket peer', () {
      expect(TomClientAddress.of(_request('203.0.113.7')), '203.0.113.7');
    });

    test('ignores X-Forwarded-For from a peer that is not a trusted proxy', () {
      expect(
        TomClientAddress.of(
          _request('203.0.113.7', headers: {'x-forwarded-for': '1.2.3.4'}),
        ),
        '203.0.113.7',
      );
    });

    test('reads X-Forwarded-For from the right behind trusted proxies', () {
      expect(
        TomClientAddress.of(
          _request(
            '10.0.0.2',
            headers: {'x-forwarded-for': '6.6.6.6, 198.51.100.9, 10.0.0.3'},
          ),
          trustedProxies: {'10.0.0.2', '10.0.0.3'},
        ),
        // 6.6.6.6 is whatever the client claimed; 198.51.100.9 is the first
        // address a trusted proxy recorded.
        '198.51.100.9',
      );
    });
  });

  group('the middleware', () {
    late Handler handler;

    setUp(() async {
      final keys = TomApiKeys(store: TomMemoryApiKeyStore());
      TomApiKeys.install(keys);
      await keys.saveAccount(
        const TomServiceAccount(id: 'svc', name: 's', roles: ['read']),
      );
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
              pathPrefixes: ['/api'],
            ),
          ],
        ),
      );
      handler = const Pipeline()
          .addMiddleware(tomDefaultAuthenticationMiddleware('auth'))
          .addMiddleware(tomRateLimitMiddleware())
          .addHandler((request) {
            final principal = getFromCurrentZone<TomPrincipal>();
            return Response.ok(principal?.username ?? 'anonymous');
          });
    });

    tearDown(() {
      TomRateLimits.reset();
      TomApiKeys.reset();
    });

    Future<Response> send(Request request) async => await handler(request);

    test('limits per address, and answers 429 with Retry-After', () async {
      final first = await send(_request('203.0.113.7'));
      expect(first.statusCode, 200);
      expect(first.headers['ratelimit-limit'], '2');
      expect(first.headers['ratelimit-remaining'], '1');
      expect((await send(_request('203.0.113.7'))).statusCode, 200);
      final refused = await send(_request('203.0.113.7'));
      expect(refused.statusCode, 429);
      expect(int.parse(refused.headers['retry-after']!), greaterThan(0));
      expect(refused.headers['ratelimit-remaining'], '0');
      final body = jsonDecode(await refused.readAsString()) as Map;
      expect(body['errorKey'], 'rate_limit.exceeded');
      // Another address has its own count.
      expect((await send(_request('198.51.100.1'))).statusCode, 200);
    });

    test('a path the rule does not cover is not counted', () async {
      for (var i = 0; i < 5; i++) {
        expect(
          (await send(_request('203.0.113.8', path: '/health'))).statusCode,
          200,
        );
      }
    });

    test('a preflight is not counted', () async {
      for (var i = 0; i < 5; i++) {
        expect(
          (await send(_request('203.0.113.9', method: 'OPTIONS'))).statusCode,
          200,
        );
      }
    });

    test('limits per API key, apart from the address rule', () async {
      final keys = TomApiKeys.current!;
      final a = await keys.issue('svc');
      final b = await keys.issue('svc');
      Request keyed(String key) =>
          _request('203.0.113.10', headers: {'x-api-key': key});
      for (var i = 0; i < 3; i++) {
        final ok = await send(keyed(a.value));
        expect(ok.statusCode, 200);
        expect(await ok.readAsString(), 'service:svc');
      }
      expect((await send(keyed(a.value))).statusCode, 429);
      // The other key of the same account has its own count, and the address
      // rule — anonymous only — counted none of these.
      expect((await send(keyed(b.value))).statusCode, 200);
    });

    test('a refused key proceeds anonymous, counted by its address', () async {
      final response = await send(
        _request('203.0.113.11', headers: {'x-api-key': 'tomk.nope.nope'}),
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'anonymous');
      expect(response.headers['ratelimit-limit'], '2');
    });

    test('with no limits installed nothing is limited or annotated', () async {
      TomRateLimits.reset();
      for (var i = 0; i < 5; i++) {
        final response = await send(_request('203.0.113.12'));
        expect(response.statusCode, 200);
        expect(response.headers['ratelimit-limit'], isNull);
      }
    });
  });

  test('a principal rule keys signed-in users by tenant and name', () async {
    final limits = TomRateLimits(
      rules: [
        TomRateLimitRule(
          name: 'users',
          scope: TomRateLimitScope.principal,
          limit: 100,
          window: const Duration(minutes: 1),
        ),
      ],
    );
    final rule = limits.rules.single;
    String? bucketAs(TomPrincipal? principal, [TomApiKeyIdentity? key]) =>
        runZoned(
          () => limits.bucketOf(rule, _request('203.0.113.1')),
          zoneValues: TomZoneValues({
            TomPrincipal: principal,
            TomApiKeyIdentity: key,
          }).zoneValues,
        );
    expect(
      bucketAs(
        TomPrincipal(
          user: TomUser(username: 'alice'),
          authenticated: true,
          tenant: 'acme',
        ),
      ),
      'users|acme/alice',
    );
    expect(bucketAs(null), isNull);
    expect(bucketAs(TomPrincipal(user: TomUser(username: 'guest'))), isNull);
    // A service account is counted by its key, never as a user.
    expect(
      bucketAs(
        TomPrincipal(
          user: TomUser(username: 'service:svc'),
          authenticated: true,
        ),
        const TomApiKeyIdentity('k', 'svc'),
      ),
      isNull,
    );
  });
}
