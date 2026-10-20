/// Resilience of outgoing HTTP calls, each policy driven against a real test
/// server that fails on purpose: the timeout, retries with backoff for calls
/// that may be repeated, the circuit breaker per destination and the bulkhead.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A test server answering every request with [handler], counting requests
/// and the most that were in flight at once.
class _Server {
  _Server._(this._server);

  static Future<_Server> start(
    Future<void> Function(HttpRequest request, int n) handler,
  ) async {
    final server = _Server._(await HttpServer.bind('127.0.0.1', 0));
    server._server.listen((request) async {
      final n = ++server.requests;
      server._inFlight++;
      if (server._inFlight > server.maxInFlight) {
        server.maxInFlight = server._inFlight;
      }
      try {
        await handler(request, n);
      } finally {
        server._inFlight--;
      }
    });
    return server;
  }

  final HttpServer _server;
  int requests = 0;
  int _inFlight = 0;
  int maxInFlight = 0;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  Future<void> close() => _server.close(force: true);
}

Future<void> _answer(
  HttpRequest request,
  int status, [
  String body = '',
]) async {
  request.response.statusCode = status;
  request.response.write(body);
  await request.response.close();
}

Matcher _refused(String key) =>
    throwsA(isA<TomHttpResilienceException>().having((e) => e.key, 'key', key));

/// Fast backoff, so the retry tests do not wait.
const _quickRetry = TomHttpRetryPolicy(
  maxAttempts: 3,
  initialBackoff: Duration(milliseconds: 1),
  maxBackoff: Duration(milliseconds: 5),
);

void main() {
  setUp(() {
    TomHttpResilience.reset();
    TomMetrics.registry.reset();
  });
  tearDown(TomHttpResilience.reset);

  group('timeout', () {
    test(
      'an attempt that gets no answer fails with http.client.timeout',
      () async {
        final server = await _Server.start((request, _) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          await _answer(request, 200);
        });
        addTearDown(server.close);
        final client = TomResilientClient(
          null,
          const TomHttpResiliencePolicy(
            timeout: Duration(milliseconds: 200),
            retry: TomHttpRetryPolicy.none,
          ),
        );
        addTearDown(client.close);
        final watch = Stopwatch()..start();
        await expectLater(
          client.get(server.url('/slow')),
          _refused('http.client.timeout'),
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );

    test('the framework default is a timeout, not none', () {
      expect(TomHttpResilience.defaults.timeout, const Duration(seconds: 30));
      final previous = TomPlatformUtils.current;
      addTearDown(() => TomPlatformUtils.setCurrentPlatform(previous));
      TomPlatformUtils.setCurrentPlatform(_PlatformWithClient());
      final client = TomDefaultHttpClientFactory().getClient();
      expect(client, isA<TomResilientClient>());
      client.close();
    });
    test('an upload is not cut off by the response timeout', () async {
      final server = await _Server.start((request, _) async {
        // A server answers an upload once the body has arrived; this one
        // takes longer than the response timeout to do so.
        await request.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _answer(request, 201);
      });
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          timeout: Duration(milliseconds: 100),
          retry: TomHttpRetryPolicy.none,
        ),
      );
      addTearDown(client.close);
      final upload = http.StreamedRequest('POST', server.url('/upload'));
      final sent = client.send(upload);
      upload.sink.add(List.filled(1024, 7));
      await upload.sink.close();
      expect((await sent).statusCode, 201);
    });
  });

  group('retries', () {
    test('a GET is retried through 503s and succeeds', () async {
      final server = await _Server.start(
        (request, n) => _answer(request, n < 3 ? 503 : 200, 'ok $n'),
      );
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(retry: _quickRetry),
      );
      addTearDown(client.close);
      final response = await client.get(server.url('/flaky'));
      expect(response.statusCode, 200);
      expect(response.body, 'ok 3');
      expect(server.requests, 3);
      expect(
        TomMetrics.registry
            .counter('tom_http_client_retries', help: '')
            .valueOf({
              'destination': TomHttpResilience.destinationOf(server.url('/')),
            }),
        2,
      );
    });

    test(
      'the last retryable status is answered once attempts run out',
      () async {
        final server = await _Server.start(
          (request, _) => _answer(request, 503),
        );
        addTearDown(server.close);
        final client = TomResilientClient(
          null,
          const TomHttpResiliencePolicy(
            retry: _quickRetry,
            circuitBreaker: null,
          ),
        );
        addTearDown(client.close);
        final response = await client.get(server.url('/down'));
        expect(response.statusCode, 503);
        expect(server.requests, 3);
      },
    );

    test(
      'a POST is not repeated, unless it carries an Idempotency-Key',
      () async {
        final server = await _Server.start(
          (request, n) => _answer(request, 503),
        );
        addTearDown(server.close);
        final client = TomResilientClient(
          null,
          const TomHttpResiliencePolicy(
            retry: _quickRetry,
            circuitBreaker: null,
          ),
        );
        addTearDown(client.close);
        expect(
          (await client.post(server.url('/p'), body: 'x')).statusCode,
          503,
        );
        expect(server.requests, 1);
        await client.post(
          server.url('/p'),
          body: 'x',
          headers: {'Idempotency-Key': 'k-1'},
        );
        expect(server.requests, 4);
      },
    );

    test('a refused connection is retried, then reported', () async {
      final closed = await HttpServer.bind('127.0.0.1', 0);
      final port = closed.port;
      await closed.close(force: true);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(retry: _quickRetry, circuitBreaker: null),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse('http://127.0.0.1:$port/')),
        throwsA(isA<http.ClientException>()),
      );
      expect(
        TomMetrics.registry
            .counter('tom_http_client_attempts', help: '')
            .valueOf({
              'destination': 'http://127.0.0.1:$port',
              'outcome': 'error',
            }),
        3,
      );
    });

    test('a body is resent whole on every attempt', () async {
      final bodies = <String>[];
      final server = await _Server.start((request, n) async {
        bodies.add(
          await request
              .cast<List<int>>()
              .transform(const SystemEncoding().decoder)
              .join(),
        );
        await _answer(request, n < 2 ? 502 : 200);
      });
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(retry: _quickRetry),
      );
      addTearDown(client.close);
      await client.put(server.url('/doc'), body: 'payload');
      expect(bodies, ['payload', 'payload']);
    });

    test('Retry-After within maxBackoff is honoured', () {
      const policy = TomHttpRetryPolicy(maxBackoff: Duration(seconds: 10));
      expect(
        policy.backoffBefore(
          2,
          Random0(),
          retryAfter: const Duration(seconds: 3),
        ),
        const Duration(seconds: 3),
      );
      // Beyond the ceiling the server's wish is not honoured.
      expect(
        policy.backoffBefore(
          2,
          Random0(),
          retryAfter: const Duration(minutes: 5),
        ),
        lessThanOrEqualTo(const Duration(seconds: 10)),
      );
    });

    test('backoff grows exponentially up to maxBackoff', () {
      const policy = TomHttpRetryPolicy(
        initialBackoff: Duration(milliseconds: 100),
        maxBackoff: Duration(seconds: 1),
      );
      final r = Random0();
      expect(
        policy.backoffBefore(2, r).inMilliseconds,
        inInclusiveRange(50, 100),
      );
      expect(
        policy.backoffBefore(4, r).inMilliseconds,
        inInclusiveRange(200, 400),
      );
      expect(
        policy.backoffBefore(20, r),
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    });
  });

  group('circuit breaker', () {
    test(
      'opens after the threshold, fails fast, then half-opens and closes',
      () async {
        var now = DateTime.utc(2026, 10, 20, 9);
        TomHttpResilience.clock = () => now;
        var healthy = false;
        final server = await _Server.start(
          (request, _) => _answer(request, healthy ? 200 : 500),
        );
        addTearDown(server.close);
        final client = TomResilientClient(
          null,
          const TomHttpResiliencePolicy(
            retry: TomHttpRetryPolicy.none,
            circuitBreaker: TomCircuitBreakerPolicy(
              failureThreshold: 3,
              openDuration: Duration(seconds: 30),
            ),
          ),
        );
        addTearDown(client.close);
        for (var i = 0; i < 3; i++) {
          expect((await client.get(server.url('/x'))).statusCode, 500);
        }
        await expectLater(
          client.get(server.url('/x')),
          _refused('http.client.circuit_open'),
        );
        expect(server.requests, 3, reason: 'an open circuit sends nothing');

        now = now.add(const Duration(seconds: 31));
        healthy = true;
        expect((await client.get(server.url('/x'))).statusCode, 200);
        expect(server.requests, 4);
        expect((await client.get(server.url('/x'))).statusCode, 200);
      },
    );

    test('a failed trial reopens the circuit', () async {
      var now = DateTime.utc(2026, 10, 20, 9);
      TomHttpResilience.clock = () => now;
      final server = await _Server.start((request, _) => _answer(request, 500));
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          retry: TomHttpRetryPolicy.none,
          circuitBreaker: TomCircuitBreakerPolicy(
            failureThreshold: 1,
            openDuration: Duration(seconds: 10),
          ),
        ),
      );
      addTearDown(client.close);
      await client.get(server.url('/x'));
      now = now.add(const Duration(seconds: 11));
      await client.get(server.url('/x'));
      await expectLater(
        client.get(server.url('/x')),
        _refused('http.client.circuit_open'),
      );
      expect(server.requests, 2);
    });

    test('circuits are per destination', () async {
      final failing = await _Server.start(
        (request, _) => _answer(request, 500),
      );
      final fine = await _Server.start((request, _) => _answer(request, 200));
      addTearDown(failing.close);
      addTearDown(fine.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          retry: TomHttpRetryPolicy.none,
          circuitBreaker: TomCircuitBreakerPolicy(failureThreshold: 1),
        ),
      );
      addTearDown(client.close);
      await client.get(failing.url('/'));
      await expectLater(
        client.get(failing.url('/')),
        _refused('http.client.circuit_open'),
      );
      expect((await client.get(fine.url('/'))).statusCode, 200);
    });

    test('4xx answers are not failures of the destination', () async {
      final server = await _Server.start((request, _) => _answer(request, 404));
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          retry: TomHttpRetryPolicy.none,
          circuitBreaker: TomCircuitBreakerPolicy(failureThreshold: 1),
        ),
      );
      addTearDown(client.close);
      for (var i = 0; i < 3; i++) {
        expect((await client.get(server.url('/'))).statusCode, 404);
      }
    });
  });

  group('bulkhead', () {
    test('limits concurrent calls, queues some, refuses the rest', () async {
      final release = Completer<void>();
      final server = await _Server.start((request, _) async {
        await release.future;
        await _answer(request, 200);
      });
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          retry: TomHttpRetryPolicy.none,
          bulkhead: TomBulkheadPolicy(maxConcurrent: 2, maxQueued: 1),
        ),
      );
      addTearDown(client.close);
      final calls = [for (var i = 0; i < 3; i++) client.get(server.url('/$i'))];
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await expectLater(
        client.get(server.url('/4')),
        _refused('http.client.bulkhead_full'),
      );
      expect(server.requests, 2, reason: 'the third call waits in the queue');
      release.complete();
      final responses = await Future.wait(calls);
      expect(responses.map((r) => r.statusCode), [200, 200, 200]);
      expect(server.maxInFlight, 2);
    });

    test('a permit is held until the body has been read', () async {
      final server = await _Server.start(
        (request, _) => _answer(request, 200, 'body'),
      );
      addTearDown(server.close);
      final client = TomResilientClient(
        null,
        const TomHttpResiliencePolicy(
          bulkhead: TomBulkheadPolicy(maxConcurrent: 1, maxQueued: 0),
        ),
      );
      addTearDown(client.close);
      final streamed = await client.send(http.Request('GET', server.url('/')));
      final bulkhead = TomHttpResilience.bulkheadFor(
        TomHttpResilience.destinationOf(server.url('/')),
        client.policy!,
      )!;
      expect(bulkhead.active, 1);
      await streamed.stream.drain<void>();
      expect(bulkhead.active, 0);
    });
  });

  group('configuration', () {
    test('a map replaces defaults and gives destinations their own policy', () {
      TomHttpResilience.configure({
        'timeoutMs': 10000,
        'retry': {
          'maxAttempts': 2,
          'retryStatuses': [503],
        },
        'bulkhead': false,
        'destinations': {
          'https://idp.example.com': {'timeoutMs': 5000, 'retry': false},
        },
      });
      final defaults = TomHttpResilience.defaults;
      expect(defaults.timeout, const Duration(seconds: 10));
      expect(defaults.retry.maxAttempts, 2);
      expect(defaults.retry.retryStatuses, {503});
      expect(defaults.bulkhead, isNull);
      expect(defaults.circuitBreaker, isNotNull);
      final idp = TomHttpResilience.policyFor(
        Uri.parse('https://idp.example.com/token'),
      );
      expect(idp.timeout, const Duration(seconds: 5));
      expect(idp.retry.maxAttempts, 1);
      expect(idp.bulkhead, isNull, reason: 'inherits the new defaults');
      expect(
        TomHttpResilience.policyFor(Uri.parse('https://other.example.com/')),
        same(defaults),
      );
    });

    test('retry: true after retry: false restores a retry policy', () {
      TomHttpResilience.configure({'retry': false});
      expect(TomHttpResilience.defaults.retry.maxAttempts, 1);
      TomHttpResilience.configure({'retry': true});
      expect(TomHttpResilience.defaults.retry.maxAttempts, 3);
    });

    test('a retry map keeps the idempotent methods', () {
      TomHttpResilience.configure({
        'retry': {'maxAttempts': 5},
      });
      expect(
        TomHttpResilience.defaults.retry.idempotentMethods,
        const TomHttpRetryPolicy().idempotentMethods,
      );
    });

    test('streamed bodies have their own timeout, off by default', () {
      expect(TomHttpResilience.defaults.streamedTimeout, isNull);
      TomHttpResilience.configure({'streamedTimeoutMs': 600000});
      expect(
        TomHttpResilience.defaults.streamedTimeout,
        const Duration(minutes: 10),
      );
    });

    test('timeoutMs 0 means no timeout', () {
      TomHttpResilience.configure({'timeoutMs': 0});
      expect(TomHttpResilience.defaults.timeout, isNull);
    });

    test('a value of the wrong shape is refused and nothing is applied', () {
      expect(
        () => TomHttpResilience.configure({'timeoutMs': 'soon'}),
        throwsA(
          isA<TomHttpResilienceException>().having(
            (e) => e.key,
            'key',
            'http.client.config.invalid',
          ),
        ),
      );
      expect(TomHttpResilience.defaults.timeout, const Duration(seconds: 30));
    });

    test('settings that are not a map are refused', () {
      expect(
        () => TomHttpResilience.configure('fast'),
        throwsA(
          isA<TomHttpResilienceException>().having(
            (e) => e.key,
            'key',
            'http.client.config.invalid',
          ),
        ),
      );
    });

    test('destinations are scheme, host and port', () {
      expect(
        TomHttpResilience.destinationOf(Uri.parse('https://a.example.com/x?y')),
        'https://a.example.com:443',
      );
      expect(
        TomHttpResilience.destinationOf(Uri.parse('http://a.example.com:8080')),
        'http://a.example.com:8080',
      );
    });
  });
}

/// A [Random] that always answers the largest value it may, so a backoff is
/// at its ceiling.
class Random0 implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => max - 1;
}

/// A platform whose HTTP client is `package:http`'s default, for the test
/// that reads what the framework's client factory produces.
class _PlatformWithClient extends TomFallbackPlatformUtils {
  @override
  http.Client httpClient() => http.Client();
}
