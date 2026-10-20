/// Idempotency keys: a retried `POST` runs once and gets the first response;
/// a key reused for another request, or still claimed, is refused; and only an
/// endpoint that opts in with `@TomIdempotent` takes part.
///
/// The SQL store is tested against a database in `idempotency_db_test.dart`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

TomPrincipal _user(String id) => TomPrincipal(
  user: TomUser(id: id, username: id),
  authenticated: true,
);

Request _post(String path, String body, {String? key}) => Request(
  'POST',
  Uri.parse('http://localhost$path'),
  body: body,
  headers: {'idempotency-key': ?key},
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

/// Runs [body] as [principal], the way the authentication middleware does.
Future<T> _as<T>(TomPrincipal? principal, Future<T> Function() body) =>
    runZoned(body, zoneValues: {TomPrincipal: principal});

void main() {
  setUpAll(initializeReflection);
  setUp(TomIdempotency.reset);
  tearDown(TomIdempotency.reset);

  group('TomIdempotency.handle', () {
    late int runs;

    Future<Response> handler(Request request) async {
      runs++;
      final body = await request.readAsString();
      return Response(
        201,
        body: jsonEncode({'run': runs, 'echo': body}),
        headers: {'content-type': 'application/json', 'set-cookie': 's=1'},
      );
    }

    Future<Response> send(
      String body, {
      String? key = 'k-1',
      TomPrincipal? principal,
      String operation = 'POST /orders',
    }) => _as(
      principal ?? _user('alice'),
      () => TomIdempotency.handle(
        _post('/orders', body, key: key),
        operation,
        const TomIdempotent(),
        handler,
      ),
    );

    setUp(() => runs = 0);

    test('a retry runs once and gets the first response', () async {
      final first = await send('{"item":1}');
      final second = await send('{"item":1}');
      expect(runs, 1);
      expect(first.statusCode, 201);
      expect(second.statusCode, 201);
      final firstBody = await first.readAsString();
      expect(await second.readAsString(), firstBody);
      expect(second.headers[TomIdempotency.replayedHeader], 'true');
      expect(first.headers[TomIdempotency.replayedHeader], isNull);
      expect(second.headers['content-type'], 'application/json');
      expect(
        second.headers['set-cookie'],
        isNull,
        reason: 'a cookie is the first caller\'s, not a replay\'s',
      );
      // The handler saw the body although the store read it first.
      expect(jsonDecode(firstBody)['echo'], '{"item":1}');
    });

    test('a key reused for a different request is refused with 422', () async {
      await send('{"item":1}');
      final reused = await send('{"item":2}');
      expect(reused.statusCode, 422);
      expect(
        jsonDecode(await reused.readAsString())['error'],
        'endpoint.idempotency.key_reused',
      );
      expect(runs, 1);
    });

    test('a key still claimed answers 409 with Retry-After', () async {
      final release = Completer<void>();
      final slow = _as(
        _user('alice'),
        () => TomIdempotency.handle(
          _post('/orders', 'x', key: 'k-slow'),
          'POST /orders',
          const TomIdempotent(),
          (request) async {
            await release.future;
            return Response.ok('done');
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final concurrent = await send('x', key: 'k-slow');
      expect(concurrent.statusCode, 409);
      expect(concurrent.headers['retry-after'], '1');
      expect(
        jsonDecode(await concurrent.readAsString())['error'],
        'endpoint.idempotency.in_progress',
      );
      release.complete();
      expect((await slow).statusCode, 200);
    });

    test('a failed request releases the key, so the retry runs', () async {
      var fail = true;
      Future<Response> flaky(Request _) async {
        runs++;
        if (fail) return Response.internalServerError(body: 'down');
        return Response(201, body: 'made');
      }

      Future<Response> call() => _as(
        _user('alice'),
        () => TomIdempotency.handle(
          _post('/orders', 'x', key: 'k-1'),
          'POST /orders',
          const TomIdempotent(),
          flaky,
        ),
      );
      expect((await call()).statusCode, 500);
      fail = false;
      expect((await call()).statusCode, 201);
      expect((await call()).statusCode, 201);
      expect(runs, 2, reason: 'the 500 was not stored; the 201 was');
    });

    test('a thrown handler releases the key and rethrows', () async {
      await expectLater(
        _as(
          _user('alice'),
          () => TomIdempotency.handle(
            _post('/orders', 'x', key: 'k-1'),
            'POST /orders',
            const TomIdempotent(),
            (_) => throw StateError('boom'),
          ),
        ),
        throwsStateError,
      );
      expect((await send('x')).statusCode, 201);
    });

    test('refusals that say the request did not run are not stored', () async {
      var status = 429;
      Future<Response> limited(Request _) async {
        runs++;
        return Response(status);
      }

      Future<Response> call() => _as(
        _user('alice'),
        () => TomIdempotency.handle(
          _post('/orders', 'x', key: 'k-1'),
          'POST /orders',
          const TomIdempotent(),
          limited,
        ),
      );
      expect((await call()).statusCode, 429);
      status = 200;
      expect((await call()).statusCode, 200);
      expect(runs, 2);
    });

    test('keys are the caller\'s and the operation\'s', () async {
      await send('x', principal: _user('alice'));
      await send('x', principal: _user('bob'));
      await send('x', operation: 'POST /refunds');
      expect(runs, 3);
    });

    test(
      'a request without a key, or without a principal, simply runs',
      () async {
        await send('x', key: null);
        await send('x', key: null);
        await _as(
          TomPrincipal(),
          () => TomIdempotency.handle(
            _post('/orders', 'x', key: 'k-anon'),
            'POST /orders',
            const TomIdempotent(),
            handler,
          ),
        );
        await _as(
          TomPrincipal(),
          () => TomIdempotency.handle(
            _post('/orders', 'x', key: 'k-anon'),
            'POST /orders',
            const TomIdempotent(),
            handler,
          ),
        );
        expect(runs, 4);
      },
    );

    test('an over-long key is refused with 400', () async {
      final response = await send('x', key: 'k' * 192);
      expect(response.statusCode, 400);
      expect(
        jsonDecode(await response.readAsString())['error'],
        'endpoint.idempotency.key_invalid',
      );
      expect(runs, 0);
    });

    test('a record past its retention runs again', () async {
      var now = DateTime.utc(2026, 10, 20, 12);
      TomIdempotency.clock = () => now;
      await send('x');
      now = now.add(const Duration(hours: 25));
      await send('x');
      expect(runs, 2);
    });

    test(
      'a claim whose request died is taken over after the timeout',
      () async {
        var now = DateTime.utc(2026, 10, 20, 12);
        TomIdempotency.clock = () => now;
        // The first request never finishes: its process died mid-request.
        unawaited(
          _as(
            _user('alice'),
            () => TomIdempotency.handle(
              _post('/orders', 'x', key: 'k-1'),
              'POST /orders',
              const TomIdempotent(),
              (_) => Completer<Response>().future,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect((await send('x')).statusCode, 409);
        now = now.add(const Duration(minutes: 6));
        expect((await send('x')).statusCode, 201);
        expect(runs, 1);
      },
    );
  });

  group('configuration', () {
    test('the idempotency map installs a SQL store and the retention', () {
      TomServer.configureIdempotency(
        TomServerConfigResourceProvider.from({
          'idempotency': {
            'datasource': 'app',
            'retentionMinutes': 60,
            'inProgressTimeoutSeconds': 30,
          },
        }),
      );
      expect(TomIdempotency.store, isA<TomSqlIdempotencyStore>());
      expect(
        (TomIdempotency.store as TomSqlIdempotencyStore).datasourceName,
        'app',
      );
      expect(TomIdempotency.defaultRetention, const Duration(hours: 1));
      expect(TomIdempotency.inProgressTimeout, const Duration(seconds: 30));
    });

    test('a SQL store whose data source is not registered refuses', () {
      final now = DateTime.utc(2026, 10, 20, 12);
      expect(
        () => TomSqlIdempotencyStore('no-such-datasource').claim(
          const TomIdempotencyScope(
            tenant: '',
            principal: 'alice',
            operation: 'POST /orders',
            key: 'k-1',
          ),
          'hash',
          now: now,
          expiresAt: now.add(const Duration(hours: 1)),
          staleBefore: now.subtract(const Duration(minutes: 5)),
        ),
        throwsA(
          isA<TomIdempotencyException>().having(
            (e) => e.key,
            'key',
            'endpoint.idempotency.no_datasource',
          ),
        ),
      );
    });

    test('a value of the wrong shape is refused', () {
      for (final bad in <Object>[
        'fast',
        {'retentionMinutes': 'soon'},
        {'inProgressTimeoutSeconds': 0},
      ]) {
        expect(
          () => TomIdempotency.configure(bad),
          throwsA(
            isA<TomIdempotencyException>().having(
              (e) => e.key,
              'key',
              'endpoint.idempotency.config.invalid',
            ),
          ),
        );
      }
    });
  });

  group('an endpoint opts in with @TomIdempotent', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<TomHealthServer>(TomHealthServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      registerFixtureAccessApi();
      router = TomEndpointRouting().initializeRouter();
      FixtureApiServer.ordersPlaced = 0;
    });
    tearDown(TomBean.resetBeanContext);

    test('a retried POST runs once and returns the same response', () async {
      Future<Response> place() => _as(
        _user('alice'),
        () => router.call(_post('/fixture/orders', '{}', key: 'order-77')),
      );
      final first = await place();
      final retry = await place();
      expect(FixtureApiServer.ordersPlaced, 1);
      expect(first.statusCode, 200);
      expect(retry.statusCode, 200);
      final body = await first.readAsString();
      expect(jsonDecode(body)['order'], 1);
      expect(await retry.readAsString(), body);
      expect(retry.headers[TomIdempotency.replayedHeader], 'true');
    });

    test('without a key the endpoint runs on every request', () async {
      for (var i = 0; i < 2; i++) {
        await _as(
          _user('alice'),
          () => router.call(_post('/fixture/orders', '{}')),
        );
      }
      expect(FixtureApiServer.ordersPlaced, 2);
    });
  });
}
