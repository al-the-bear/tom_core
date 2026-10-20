/// Configures the resilience of outgoing HTTP calls and drives each policy
/// against a loopback server that fails on purpose.
///
/// Every call through a [TomResilientClient] — and so every call through a
/// [TomServerChannel] with the default client factory — is made under the
/// policy of its destination (`scheme://host:port`):
///
/// * a **timeout** per attempt (30 s by default);
/// * **retries** with jittered exponential backoff, only for calls that may be
///   repeated: an idempotent method, or an `Idempotency-Key` header;
/// * a **circuit breaker** per destination, which stops sending after
///   consecutive failures and lets one trial through after its open duration;
/// * a **bulkhead** per destination, limiting concurrent and queued calls.
///
/// The policies are set with [TomHttpResilience.configure] — the same map a
/// configuration file carries — or in code with [TomHttpResiliencePolicy].
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/http_connection/09_http_resilience_example.dart
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// The server
// ============================================================================

/// A loopback server answering every request with [handler], counting the
/// requests it received.
class FlakyServer {
  FlakyServer._(this._server, this._handler);

  /// Binds to a free loopback port and starts serving with [handler].
  static Future<FlakyServer> start(
    Future<void> Function(HttpRequest request, int n) handler,
  ) async {
    final server = FlakyServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      handler,
    );
    server._serve();
    return server;
  }

  final HttpServer _server;
  final Future<void> Function(HttpRequest request, int n) _handler;

  /// Requests received so far.
  int requests = 0;

  /// The URL of [path] on this server.
  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  void _serve() {
    _server.listen((request) => _handler(request, ++requests));
  }

  /// Stops serving, dropping open connections.
  Future<void> stop() => _server.close(force: true);
}

/// Answers [request] with [status] and [body].
Future<void> answer(HttpRequest request, int status, [String body = '']) async {
  request.response.statusCode = status;
  request.response.write(body);
  await request.response.close();
}

/// Retries without waiting long, so the example runs quickly.
const quickRetry = TomHttpRetryPolicy(
  initialBackoff: Duration(milliseconds: 1),
  maxBackoff: Duration(milliseconds: 5),
);

// ============================================================================
// Example class
// ============================================================================

class HttpResilienceExample {
  // Captured results, asserted at the end of [run].
  static late Duration? idpTimeout;
  static late int idpAttempts;
  static late bool idpHasBulkhead;
  static late Duration? defaultTimeout;
  static late String invalidKey;
  static late Duration? unchangedTimeout;
  static late bool defaultClientIsResilient;
  static late int retriedStatus;
  static late int retriedRequests;
  static late double retriesCounted;
  static late int postRequests;
  static late int keyedPostRequests;
  static late String timeoutKey;
  static late List<String> circuitOutcomes;
  static late int circuitRequests;
  static late String bulkheadKey;
  static late int bulkheadStatuses;

  // -------------------------------------------------------------------------
  // Example 1: configuration
  // -------------------------------------------------------------------------
  static void example1Configuration() {
    print('1. Configuration:');

    // The map a configuration file's `httpClient` section carries. The top
    // level replaces parts of the defaults; each destination's map replaces
    // parts of the new defaults.
    TomHttpResilience.configure({
      'timeoutMs': 10000,
      'bulkhead': false,
      'destinations': {
        'https://idp.example.com': {'timeoutMs': 5000, 'retry': false},
      },
    });
    final idp = TomHttpResilience.policyFor(
      Uri.parse('https://idp.example.com/oauth/token'),
    );
    idpTimeout = idp.timeout;
    idpAttempts = idp.retry.maxAttempts;
    idpHasBulkhead = idp.bulkhead != null;
    defaultTimeout = TomHttpResilience.policyFor(
      Uri.parse('https://api.example.com/orders'),
    ).timeout;
    print('   - idp.example.com : timeout $idpTimeout, $idpAttempts attempt');
    print('   - everywhere else : timeout $defaultTimeout');

    // A value of the wrong shape is refused before anything is applied.
    try {
      TomHttpResilience.configure({'timeoutMs': 'soon'});
      invalidKey = 'none';
    } on TomHttpResilienceException catch (e) {
      invalidKey = e.key;
    }
    unchangedTimeout = TomHttpResilience.defaults.timeout;
    print('   - "soon" refused  : $invalidKey');

    // The framework's own client factory wraps the platform client.
    final client = TomDefaultHttpClientFactory().getClient();
    defaultClientIsResilient = client is TomResilientClient;
    client.close();
    print('   - default factory : ${client.runtimeType}');

    TomHttpResilience.reset();
  }

  // -------------------------------------------------------------------------
  // Example 2: retries
  // -------------------------------------------------------------------------
  static Future<void> example2Retries() async {
    print('\n2. Retries:');

    // Two 503s, then a success: a GET is retried through them.
    final flaky = await FlakyServer.start(
      (request, n) => answer(request, n < 3 ? 503 : 200, 'ok'),
    );
    final client = TomResilientClient(
      null,
      const TomHttpResiliencePolicy(retry: quickRetry),
    );
    try {
      final response = await client.get(flaky.url('/report'));
      retriedStatus = response.statusCode;
      retriedRequests = flaky.requests;
      retriesCounted = TomMetrics.registry
          .counter('tom_http_client_retries', help: '')
          .valueOf({
            'destination': TomHttpResilience.destinationOf(flaky.url('/')),
          });
      print(
        '   - GET          : $retriedStatus after $retriedRequests requests',
      );
    } finally {
      await flaky.stop();
    }

    // A POST is sent once; with an Idempotency-Key it may be repeated.
    final down = await FlakyServer.start((request, n) => answer(request, 503));
    try {
      await client.post(down.url('/orders'), body: '{}');
      postRequests = down.requests;
      await client.post(
        down.url('/orders'),
        body: '{}',
        headers: {'Idempotency-Key': 'order-4711'},
      );
      keyedPostRequests = down.requests - postRequests;
      print('   - POST         : $postRequests request');
      print('   - POST + key   : $keyedPostRequests requests');
    } finally {
      client.close();
      await down.stop();
      TomHttpResilience.reset();
    }
  }

  // -------------------------------------------------------------------------
  // Example 3: timeout
  // -------------------------------------------------------------------------
  static Future<void> example3Timeout() async {
    print('\n3. Timeout:');

    final slow = await FlakyServer.start((request, _) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      await answer(request, 200);
    });
    final client = TomResilientClient(
      null,
      const TomHttpResiliencePolicy(
        timeout: Duration(milliseconds: 100),
        retry: TomHttpRetryPolicy.none,
      ),
    );
    try {
      await client.get(slow.url('/slow'));
      timeoutKey = 'none';
    } on TomHttpResilienceException catch (e) {
      timeoutKey = e.key;
    } finally {
      client.close();
      await slow.stop();
      TomHttpResilience.reset();
    }
    print('   - unanswered   : $timeoutKey');
  }

  // -------------------------------------------------------------------------
  // Example 4: circuit breaker
  // -------------------------------------------------------------------------
  static Future<void> example4CircuitBreaker() async {
    print('\n4. Circuit breaker:');

    var now = DateTime.utc(2026, 10, 20, 9);
    TomHttpResilience.clock = () => now;
    var healthy = false;
    final server = await FlakyServer.start(
      (request, _) => answer(request, healthy ? 200 : 500),
    );
    final client = TomResilientClient(
      null,
      const TomHttpResiliencePolicy(
        retry: TomHttpRetryPolicy.none,
        circuitBreaker: TomCircuitBreakerPolicy(
          failureThreshold: 2,
          openDuration: Duration(seconds: 30),
        ),
      ),
    );
    Future<String> call() async {
      try {
        return '${(await client.get(server.url('/'))).statusCode}';
      } on TomHttpResilienceException catch (e) {
        return e.key;
      }
    }

    try {
      circuitOutcomes = [await call(), await call(), await call()];
      // After the open duration one trial goes through; it succeeds.
      now = now.add(const Duration(seconds: 31));
      healthy = true;
      circuitOutcomes.add(await call());
      circuitRequests = server.requests;
    } finally {
      client.close();
      await server.stop();
      TomHttpResilience.reset();
    }
    print('   - outcomes     : $circuitOutcomes');
    print('   - sent         : $circuitRequests');
  }

  // -------------------------------------------------------------------------
  // Example 5: bulkhead
  // -------------------------------------------------------------------------
  static Future<void> example5Bulkhead() async {
    print('\n5. Bulkhead:');

    final release = Completer<void>();
    final server = await FlakyServer.start((request, _) async {
      await release.future;
      await answer(request, 200);
    });
    final client = TomResilientClient(
      null,
      const TomHttpResiliencePolicy(
        retry: TomHttpRetryPolicy.none,
        bulkhead: TomBulkheadPolicy(maxConcurrent: 1, maxQueued: 1),
      ),
    );
    try {
      // One call in flight, one queued: a third is refused at once.
      final admitted = [
        client.get(server.url('/a')),
        client.get(server.url('/b')),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        await client.get(server.url('/c'));
        bulkheadKey = 'none';
      } on TomHttpResilienceException catch (e) {
        bulkheadKey = e.key;
      }
      release.complete();
      bulkheadStatuses = (await Future.wait(
        admitted,
      )).where((r) => r.statusCode == 200).length;
    } finally {
      client.close();
      await server.stop();
      TomHttpResilience.reset();
    }
    print('   - third call   : $bulkheadKey');
    print('   - admitted     : $bulkheadStatuses answered');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static Future<void> run() async {
    print('=== 09: HTTP Resilience Example ===\n');

    TomHttpResilience.reset();
    try {
      example1Configuration();
      await example2Retries();
      await example3Timeout();
      await example4CircuitBreaker();
      await example5Bulkhead();
    } finally {
      // Leave the isolate as it was found: later samples get the defaults.
      TomHttpResilience.reset();
    }

    assert(
      idpTimeout == const Duration(seconds: 5),
      'A destination has its own timeout',
    );
    assert(idpAttempts == 1, '"retry: false" leaves one attempt');
    assert(!idpHasBulkhead, 'A destination inherits the new defaults');
    assert(
      defaultTimeout == const Duration(seconds: 10),
      'Every other destination gets the configured defaults',
    );
    assert(
      invalidKey == 'http.client.config.invalid',
      'A value of the wrong shape is refused',
    );
    assert(
      unchangedTimeout == const Duration(seconds: 10),
      'A refused configuration changes nothing',
    );
    assert(
      defaultClientIsResilient,
      'The default factory wraps the platform client',
    );
    assert(retriedStatus == 200, 'The GET succeeds on its third attempt');
    assert(retriedRequests == 3, 'Two retries were sent');
    assert(retriesCounted == 2, 'tom_http_client_retries counts them');
    assert(postRequests == 1, 'A POST is not repeated');
    assert(
      keyedPostRequests == 3,
      'A POST with an Idempotency-Key gets every attempt',
    );
    assert(
      timeoutKey == 'http.client.timeout',
      'An unanswered attempt times out',
    );
    assert(
      circuitOutcomes.join(',') == '500,500,http.client.circuit_open,200',
      'The circuit opens after two failures and closes after a good trial',
    );
    assert(circuitRequests == 3, 'An open circuit sends nothing');
    assert(
      bulkheadKey == 'http.client.bulkhead_full',
      'A call beyond the bulkhead and its queue is refused',
    );
    assert(bulkheadStatuses == 2, 'The admitted calls are answered');

    print('\n=== HTTP Resilience Example Complete ===\n');
  }
}

/// Runs this example.
Future<void> run() => HttpResilienceExample.run();

Future<void> main() async {
  prepareSampleProcess();
  await run();
}
