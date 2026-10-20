/// The resilience of the server's outgoing HTTP calls: the `httpClient`
/// configuration, and the framework's own call paths — a channel's call, the
/// OAuth provider transport — against a test server that fails on purpose.
///
/// The policies themselves are the kernel's and are tested there
/// (`tom_core_kernel/test/http_resilience_test.dart`).
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// A test server answering request `n` with `statuses[n - 1]` (the last one
/// for every later request), counting what it received.
class _FlakyServer {
  _FlakyServer._(this._server, this.statuses);

  static Future<_FlakyServer> start(List<int> statuses) async {
    final s = _FlakyServer._(await HttpServer.bind('127.0.0.1', 0), statuses);
    s._server.listen((request) async {
      s.methods.add(request.method);
      final status =
          statuses[(s.methods.length - 1).clamp(0, statuses.length - 1)];
      request.response.statusCode = status;
      request.response.write('{"answer": ${s.methods.length}}');
      await request.response.close();
    });
    return s;
  }

  final HttpServer _server;
  final List<int> statuses;
  final List<String> methods = [];

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  Future<void> close() => _server.close(force: true);
}

const TomHttpResiliencePolicy _quick = TomHttpResiliencePolicy(
  retry: TomHttpRetryPolicy(
    initialBackoff: Duration(milliseconds: 1),
    maxBackoff: Duration(milliseconds: 5),
  ),
);

void main() {
  setUpAll(initializeReflection);
  setUp(TomHttpResilience.reset);
  tearDown(TomHttpResilience.reset);

  group('configuration', () {
    test('the httpClient map sets the defaults and destination policies', () {
      TomServer.configureHttpClients(
        TomServerConfigResourceProvider.from({
          'httpClient': {
            'timeoutMs': 8000,
            'destinations': {
              'https://breached.example.com': {
                'timeoutMs': 2000,
                'circuitBreaker': {'failureThreshold': 2},
              },
            },
          },
        }),
      );
      expect(TomHttpResilience.defaults.timeout, const Duration(seconds: 8));
      final policy = TomHttpResilience.policyFor(
        Uri.parse('https://breached.example.com/range/ABCDE'),
      );
      expect(policy.timeout, const Duration(seconds: 2));
      expect(policy.circuitBreaker!.failureThreshold, 2);
    });

    test('without the key the framework defaults stand', () {
      TomServer.configureHttpClients(TomServerConfigResourceProvider.from({}));
      expect(TomHttpResilience.defaults.timeout, const Duration(seconds: 30));
    });

    test('a value that is not a map stops the start', () {
      expect(
        () => TomServer.configureHttpClients(
          TomServerConfigResourceProvider.from({'httpClient': 'fast'}),
        ),
        throwsA(
          isA<TomHttpResilienceException>().having(
            (e) => e.key,
            'key',
            'http.client.config.invalid',
          ),
        ),
      );
    });
  });

  group('framework call paths', () {
    test('a channel call is retried through a 503', () async {
      final server = await _FlakyServer.start([503, 200]);
      addTearDown(server.close);
      TomHttpResilience.setDestinationPolicy(
        server.url('/').toString(),
        _quick,
      );
      final channel = TomServerChannel.forUri(
        server.url('/'),
        clientFactory: _Factory(),
      );
      addTearDown(channel.close);
      expect(channel.getClient(), isA<TomResilientClient>());
      final body = await channel
          .prepareCall(
            TomServerCallSpecs(
              'GET',
              server.url('/status'),
              includeBearerAuthentication: false,
            ),
          )
          .send(TomServerCallLoad())
          .readAsString(const SystemEncoding());
      expect(body, '{"answer": 2}');
      expect(server.methods, ['GET', 'GET']);
    });

    test('the OAuth user-info GET is retried, the token POST is not', () async {
      final server = await _FlakyServer.start([502, 200]);
      addTearDown(server.close);
      TomHttpResilience.setDestinationPolicy(
        server.url('/').toString(),
        _quick,
      );
      const transport = TomHttpOAuthTokenTransport();
      expect(
        await transport.getJson(server.url('/userinfo'), const {}),
        contains('2'),
      );

      final failing = await _FlakyServer.start([503]);
      addTearDown(failing.close);
      TomHttpResilience.setDestinationPolicy(
        failing.url('/').toString(),
        _quick,
      );
      await expectLater(
        transport.postForm(failing.url('/token'), {'code': 'c'}, const {}),
        throwsA(isA<TomOAuthException>()),
      );
      expect(failing.methods, ['POST'], reason: 'a code is single-use');
    });
  });
}

/// Produces what the framework's default factory produces, over `dart:io`.
class _Factory implements TomHttpClientAbstractFactory {
  @override
  TomResilientClient getClient() => TomResilientClient();
}
