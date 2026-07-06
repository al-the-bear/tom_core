/// Socket-free tests for [AuthorizedHttp] (step 23): bearer injection and the
/// refresh-once-on-401 recovery, verified against a path-routing fake
/// [JsonTransport] shared by the wrapper and its [AuthClient].
///
/// The fake routes by `uri.path`, so the interleaved app-endpoint call and the
/// `/auth/refresh` call the wrapper makes on a 401 are each driven by their own
/// canned queue — letting the tests assert *exactly* how many times each path
/// was hit (the "retries exactly once" bar) and which bearer each attempt
/// carried (the "picks up the refreshed token" property).
///
/// Stored tokens are synthetic unsigned JWTs (see [_makeJwt]) so
/// `setTokens(..., decrypt: false)` accepts them without RSA. The refresh path
/// deserializes a [LoginResult] through reflection, so the combined
/// domain+contracts seed is installed once (`initializeReflection`).
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initializeReflection);

  group('AuthorizedHttp', () {
    final authBaseUri = Uri.parse('http://localhost:8081');
    final appUri = Uri.parse('http://localhost:8080/items');
    const appPath = '/items';
    const refreshPath = '/auth/refresh';

    // Fresh bearer singleton per test — setTokens/refresh mutate global state.
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    AuthorizedHttp wrapperOver(_RoutingTransport transport) =>
        AuthorizedHttp(transport, AuthClient(authBaseUri, transport: transport));

    test('TC-23-01: injects the stored bearer and returns a 2xx unchanged',
        () async {
      final authz = _makeJwt({'username': 'alice', 'userId': 2});
      TomBearerAuthentication.setTokens(authz, authz, false);

      final transport = _RoutingTransport({
        appPath: [HttpJsonResponse(200, '{"ok":true}')],
      });
      final http = wrapperOver(transport);

      final response = await http.send(method: 'GET', uri: appUri);

      expect(response.statusCode, equals(200));
      final call = transport.callsTo(appPath).single;
      expect(call.headers['Authorization'], equals('Bearer $authz'));
      // No 401, so no refresh.
      expect(transport.callsTo(refreshPath), isEmpty);
    });

    test('TC-23-02: merges the bearer with caller-supplied headers', () async {
      final authz = _makeJwt({'username': 'alice', 'userId': 2});
      TomBearerAuthentication.setTokens(authz, authz, false);

      final transport = _RoutingTransport({
        appPath: [HttpJsonResponse(201, '')],
      });
      final http = wrapperOver(transport);

      await http.send(
        method: 'POST',
        uri: appUri,
        headers: {'Content-Type': 'application/json'},
        body: '{"title":"x"}',
      );

      final call = transport.callsTo(appPath).single;
      expect(call.headers['Content-Type'], equals('application/json'));
      expect(call.headers['Authorization'], equals('Bearer $authz'));
      expect(call.body, equals('{"title":"x"}'));
    });

    test('TC-23-03: on a 401 refreshes once and retries with the new bearer',
        () async {
      final authz0 = _makeJwt({'username': 'alice', 'userId': 2, 'v': 0});
      TomBearerAuthentication.setTokens(authz0, authz0, false);
      final authz1 = _makeJwt({'username': 'alice', 'userId': 2, 'v': 1});

      final transport = _RoutingTransport({
        // First app call is rejected; the retry succeeds.
        appPath: [
          HttpJsonResponse(401, '{"error":"auth.token.expired"}'),
          HttpJsonResponse(200, '{"items":[]}'),
        ],
        refreshPath: [HttpJsonResponse(200, jsonEncode(_loginBody(authz1)))],
      });
      final http = wrapperOver(transport);

      final response = await http.send(method: 'GET', uri: appUri);

      expect(response.statusCode, equals(200));
      // Exactly one refresh and exactly one retry — no looping.
      expect(transport.callsTo(refreshPath), hasLength(1));
      final appCalls = transport.callsTo(appPath);
      expect(appCalls, hasLength(2));
      // First attempt carried the stale token; the retry carries the fresh one.
      expect(appCalls[0].headers['Authorization'], equals('Bearer $authz0'));
      expect(appCalls[1].headers['Authorization'], equals('Bearer $authz1'));
      // The refresh sent the (old) authorization token as its bearer.
      expect(transport.callsTo(refreshPath).single.headers['Authorization'],
          equals('Bearer $authz0'));
    });

    test('TC-23-04: a 401 that persists after refresh throws TomAuthExpiredException',
        () async {
      final authz0 = _makeJwt({'username': 'alice', 'userId': 2});
      TomBearerAuthentication.setTokens(authz0, authz0, false);
      final authz1 = _makeJwt({'username': 'alice', 'userId': 2, 'v': 1});

      final transport = _RoutingTransport({
        appPath: [
          HttpJsonResponse(401, '{"error":"auth.token.expired"}'),
          HttpJsonResponse(401, '{"error":"auth.token.invalid"}'),
        ],
        refreshPath: [HttpJsonResponse(200, jsonEncode(_loginBody(authz1)))],
      });
      final http = wrapperOver(transport);

      await expectLater(
        http.send(method: 'GET', uri: appUri),
        throwsA(isA<TomAuthExpiredException>()
            .having((e) => e.key, 'key', 'auth.token.invalid')
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
      // Refresh + retry happened exactly once each — then it surfaced, no loop.
      expect(transport.callsTo(refreshPath), hasLength(1));
      expect(transport.callsTo(appPath), hasLength(2));
    });

    test('TC-23-05: a non-401 error status is returned as-is, with no refresh',
        () async {
      final authz = _makeJwt({'username': 'alice', 'userId': 2});
      TomBearerAuthentication.setTokens(authz, authz, false);

      final transport = _RoutingTransport({
        appPath: [HttpJsonResponse(403, '{"error":"app.access.forbidden"}')],
      });
      final http = wrapperOver(transport);

      final response = await http.send(method: 'GET', uri: appUri);

      // The API client interprets 403/404 itself — the wrapper does not refresh.
      expect(response.statusCode, equals(403));
      expect(transport.callsTo(appPath), hasLength(1));
      expect(transport.callsTo(refreshPath), isEmpty);
    });

    test('TC-23-06: with no stored session the call goes out unauthenticated and a 401 surfaces the refresh failure',
        () async {
      // No setTokens — there is no session to inject or to refresh.
      final transport = _RoutingTransport({
        appPath: [HttpJsonResponse(401, '')],
      });
      final http = wrapperOver(transport);

      await expectLater(
        http.send(method: 'GET', uri: appUri),
        throwsA(isA<AuthClientException>()
            .having((e) => e.key, 'key', 'auth.no_token')),
      );
      // The first attempt carried no Authorization header; refresh aborted
      // before any /auth/refresh round-trip.
      final firstCall = transport.callsTo(appPath).single;
      expect(firstCall.headers.containsKey('Authorization'), isFalse);
      expect(transport.callsTo(refreshPath), isEmpty);
    });
  });
}

/// A success `/auth/refresh` body carrying [authzToken] as the new authorization
/// token (and a synthetic auth token), so the wrapper's refresh stores a fresh
/// pair the retry can pick up.
Map<String, Object?> _loginBody(String authzToken) => {
      'user': {
        'id': '2',
        'username': 'alice',
        'displayName': 'alice',
        'email': 'alice@example.com',
        'status': 'active',
      },
      'authToken': _makeJwt({'username': 'alice', 'userId': 2, 'kind': 'auth'}),
      'authzToken': authzToken,
      'expiresAt': '2026-06-28T12:34:56.000Z',
    };

/// Builds an unsigned, undecrypted JWT whose middle segment carries [payload].
/// Suitable for `setTokens(..., decrypt: false)`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  return '${seg(header)}.${seg(payload)}.sig';
}

/// One captured transport call, so a test can assert what the client sent.
class _Call {
  _Call(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

/// A [JsonTransport] that records every call and replays canned responses from a
/// per-`uri.path` queue — so an interleaved app call and `/auth/refresh` are
/// each driven independently and assertable by path.
class _RoutingTransport implements JsonTransport {
  _RoutingTransport(this._queues);
  final Map<String, List<HttpJsonResponse>> _queues;
  final List<_Call> calls = [];
  final Map<String, int> _idx = {};

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    calls.add(_Call(method, uri, headers, body));
    final queue = _queues[uri.path];
    if (queue == null) {
      throw StateError('no canned response queued for ${uri.path}');
    }
    final i = _idx[uri.path] ?? 0;
    _idx[uri.path] = i + 1;
    return queue[i];
  }

  /// The recorded calls whose path equals [path], in order.
  List<_Call> callsTo(String path) =>
      calls.where((c) => c.uri.path == path).toList();
}
