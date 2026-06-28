/// Database- and socket-free tests for [AuthClient] (step 22): the login /
/// refresh / logout sequencing and token storage verify against a fake
/// [JsonTransport], and the "pure JSON parsers" done-bar verifies by feeding a
/// *captured* `/auth/login` response body straight through [LoginResult.fromJson].
///
/// Tokens are synthetic unsigned JWTs (see [_makeJwt]) so [AuthClient] stores
/// them through `TomBearerAuthentication.setTokens(..., decrypt: false)` without
/// any RSA key — matching the client's `decryptTokens: false` default, which
/// treats the authorization token as an opaque bearer.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

void main() {
  group('AuthClient', () {
    final baseUri = Uri.parse('http://localhost:8081');

    // Each test starts from a clean bearer singleton — setTokens/logout mutate
    // global state, so leaking it between tests would mask storage bugs.
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    group('login', () {
      test('TC-22-01: POSTs /auth/login with the request body and parses the result',
          () async {
        final transport = _FakeTransport([
          HttpJsonResponse(200, jsonEncode(_loginResponseFor('alice'))),
        ]);
        final client = AuthClient(baseUri, transport: transport);

        final result = await client.login(
            const LoginRequest(username: 'alice', password: 'alice-pass'));

        // The sequenced HTTP call.
        final call = transport.calls.single;
        expect(call.method, equals('POST'));
        expect(call.uri, equals(Uri.parse('http://localhost:8081/auth/login')));
        expect(jsonDecode(call.body!),
            equals({'username': 'alice', 'password': 'alice-pass', 'app': '', 'org': ''}));

        // The parsed DTO.
        expect(result.user.username, equals('alice'));
        expect(result.authToken, isNotEmpty);
        expect(result.authzToken, isNotEmpty);
      });

      test('TC-22-02: stores the returned token pair so later calls carry the bearer',
          () async {
        final response = _loginResponseFor('alice');
        final transport =
            _FakeTransport([HttpJsonResponse(200, jsonEncode(response))]);
        final client = AuthClient(baseUri, transport: transport);

        expect(TomBearerAuthentication.authorizationToken, isNull);
        await client.login(const LoginRequest(username: 'alice'));

        expect(TomBearerAuthentication.token, equals(response['authToken']));
        expect(TomBearerAuthentication.authorizationToken,
            equals(response['authzToken']));
        expect(TomBearerAuthentication.getPrincipal().username, equals('alice'));
      });

      test('TC-22-03: a 401 throws AuthClientException carrying the server error key',
          () async {
        final transport = _FakeTransport([
          HttpJsonResponse(401, jsonEncode({'error': 'auth.credentials.rejected'})),
        ]);
        final client = AuthClient(baseUri, transport: transport);

        await expectLater(
          client.login(const LoginRequest(username: 'alice', password: 'wrong')),
          throwsA(isA<AuthClientException>()
              .having((e) => e.key, 'key', 'auth.credentials.rejected')
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
        // A rejected login must not store anything.
        expect(TomBearerAuthentication.authorizationToken, isNull);
      });

      test('TC-22-04: a non-success without an error key falls back to auth.login.failed',
          () async {
        final transport = _FakeTransport([HttpJsonResponse(500, '')]);
        final client = AuthClient(baseUri, transport: transport);

        await expectLater(
          client.login(const LoginRequest(username: 'alice')),
          throwsA(isA<AuthClientException>()
              .having((e) => e.key, 'key', 'auth.login.failed')
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });
    });

    group('refresh', () {
      test('TC-22-05: sends the stored authzToken as the bearer and re-stores the new pair',
          () async {
        final first = _loginResponseFor('alice', suffix: '1');
        final second = _loginResponseFor('alice', suffix: '2');
        final transport = _FakeTransport([
          HttpJsonResponse(200, jsonEncode(first)),
          HttpJsonResponse(200, jsonEncode(second)),
        ]);
        final client = AuthClient(baseUri, transport: transport);

        await client.login(const LoginRequest(username: 'alice'));
        await client.refresh();

        final refreshCall = transport.calls[1];
        expect(refreshCall.method, equals('POST'));
        expect(refreshCall.uri,
            equals(Uri.parse('http://localhost:8081/auth/refresh')));
        expect(refreshCall.headers['Authorization'],
            equals('Bearer ${first['authzToken']}'));
        // The fresh pair replaced the old one.
        expect(TomBearerAuthentication.authorizationToken,
            equals(second['authzToken']));
      });

      test('TC-22-06: refresh without a stored token throws auth.no_token', () async {
        final transport = _FakeTransport([]);
        final client = AuthClient(baseUri, transport: transport);

        await expectLater(
          client.refresh(),
          throwsA(isA<AuthClientException>()
              .having((e) => e.key, 'key', 'auth.no_token')
              .having((e) => e.statusCode, 'statusCode', 0)),
        );
        // The bearer-less refresh never reaches the transport.
        expect(transport.calls, isEmpty);
      });
    });

    group('logout', () {
      test('TC-22-07: tells the server then discards the local token pair', () async {
        final transport = _FakeTransport([
          HttpJsonResponse(200, jsonEncode(_loginResponseFor('alice'))),
          HttpJsonResponse(200, ''),
        ]);
        final client = AuthClient(baseUri, transport: transport);

        await client.login(const LoginRequest(username: 'alice'));
        await client.logout();

        expect(transport.calls[1].uri,
            equals(Uri.parse('http://localhost:8081/auth/logout')));
        // Local discard happened — no bearer survives.
        expect(TomBearerAuthentication.token, isNull);
        expect(TomBearerAuthentication.authorizationToken, isNull);
      });

      test('TC-22-08: discards the local token pair even if the server call fails',
          () async {
        final transport = _FailingOnLogout([
          HttpJsonResponse(200, jsonEncode(_loginResponseFor('alice'))),
        ]);
        final client = AuthClient(baseUri, transport: transport);

        await client.login(const LoginRequest(username: 'alice'));
        await expectLater(client.logout(), throwsA(isA<Exception>()));

        expect(TomBearerAuthentication.authorizationToken, isNull);
      });

      test('TC-22-09: logout with no stored session is a no-op that touches no transport',
          () async {
        final transport = _FakeTransport([]);
        final client = AuthClient(baseUri, transport: transport);

        await client.logout();

        expect(transport.calls, isEmpty);
        expect(TomBearerAuthentication.authorizationToken, isNull);
      });
    });
  });

  group('LoginResult parser (captured /auth/login response)', () {
    test('TC-22-10: parses a captured response body into the typed result', () {
      // A real-shaped success body the auth server returns for alice.
      const captured = '''
{
  "user": {
    "id": "2",
    "username": "alice",
    "displayName": "Alice Owner",
    "email": "alice@example.com",
    "status": "active"
  },
  "authToken": "auth-token-abc",
  "authzToken": "authz-token-def",
  "expiresAt": "2026-06-28T12:34:56.000Z"
}''';

      final result = LoginResult.fromJson(
          jsonDecode(captured) as Map<String, Object?>);

      expect(result.user.id, equals('2'));
      expect(result.user.username, equals('alice'));
      expect(result.user.displayName, equals('Alice Owner'));
      expect(result.user.status, equals('active'));
      expect(result.authToken, equals('auth-token-abc'));
      expect(result.authzToken, equals('authz-token-def'));
      expect(result.expiresAt,
          equals(DateTime.utc(2026, 6, 28, 12, 34, 56)));
    });
  });
}

/// A success `/auth/login` body for [username], with synthetic unsigned JWTs so
/// `setTokens(..., decrypt: false)` stores them without RSA. [suffix]
/// distinguishes the token pair across a login→refresh sequence.
Map<String, Object?> _loginResponseFor(String username, {String suffix = ''}) {
  final id = username == 'alice' ? 2 : 4;
  final payload = {'username': username, 'userId': id};
  return {
    'user': {
      'id': '$id',
      'username': username,
      'displayName': username,
      'email': '$username@example.com',
      'status': 'active',
    },
    'authToken': _makeJwt({...payload, 'kind': 'auth$suffix'}),
    'authzToken': _makeJwt({...payload, 'kind': 'authz$suffix'}),
    'expiresAt': '2026-06-28T12:34:56.000Z',
  };
}

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

/// A [JsonTransport] that records each call and replays canned responses in
/// order — no socket, fully deterministic.
class _FakeTransport implements JsonTransport {
  _FakeTransport(this._responses);
  final List<HttpJsonResponse> _responses;
  final List<_Call> calls = [];
  int _next = 0;

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    calls.add(_Call(method, uri, headers, body));
    return _responses[_next++];
  }
}

/// A transport that succeeds for login but throws when the logout call is made,
/// proving the local token discard still runs in the `finally`.
class _FailingOnLogout extends _FakeTransport {
  _FailingOnLogout(super.responses);

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) {
    if (uri.path.endsWith('/auth/logout')) {
      throw const SocketExceptionLike('server unreachable');
    }
    return super.send(method: method, uri: uri, headers: headers, body: body);
  }
}

/// A stand-in network failure (the real client would see a `SocketException`).
class SocketExceptionLike implements Exception {
  const SocketExceptionLike(this.message);
  final String message;
  @override
  String toString() => 'SocketExceptionLike: $message';
}
