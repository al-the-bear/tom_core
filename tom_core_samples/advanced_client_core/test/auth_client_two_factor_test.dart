/// Socket-free tests for the client half of the two-pass login: the
/// challenge arriving on pass 1, the second factor going back on pass 2, and the
/// retry the server offers when a code is refused.
///
/// The point being proven is that the client keeps **no challenge state of its
/// own**. It never records the mechanism, the attempt count, or the expiry: all
/// of that is read out of the stored interim token through
/// `TomBearerAuthentication.pendingTwoFactorChallenge`, so the client's view
/// cannot drift from the server's. The tests therefore assert against the token
/// the fake transport hands back, not against fields on [AuthClient].
///
/// Same conventions as `auth_client_test.dart`: reflection seeded once, tokens
/// are synthetic unsigned JWTs (`decrypt: false`), and the bearer singleton is
/// reset around every test.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initializeReflection);

  group('AuthClient — two-pass login', () {
    final baseUri = Uri.parse('http://localhost:8081');

    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test('pass 1 reports the pending factor and stores the interim token',
        () async {
      final pending = _pendingResponse(attempt: 0);
      final transport =
          _FakeTransport([HttpJsonResponse(200, jsonEncode(pending))]);
      final client = AuthClient(baseUri, transport: transport);

      final result =
          await client.login(LoginRequest(username: 'dave', password: 'p'));

      expect(result.requires2FA, isTrue);
      expect(result.twoFactorType, equals('totp'));
      // The interim pair is stored like any other: it is what pass 2 presents.
      expect(TomBearerAuthentication.authorizationToken,
          equals(pending['authzToken']));
    });

    test('the challenge detail is read from the token, not from the DTO',
        () async {
      final transport = _FakeTransport(
          [HttpJsonResponse(200, jsonEncode(_pendingResponse(attempt: 0)))]);
      final client = AuthClient(baseUri, transport: transport);

      await client.login(LoginRequest(username: 'dave'));
      final challenge = client.pendingChallenge;

      expect(challenge, isNotNull);
      expect(challenge!.type, equals('totp'));
      expect(challenge.hint, equals('Authenticator app'));
      expect(challenge.attemptsRemaining, equals(3));
      expect(challenge.isExpired(), isFalse);
      // The mechanism describes its own input shape, so the sign-in screen can
      // size the code field without knowing which mechanism it is showing.
      expect(challenge.clientData['digits'], equals(6));
    });

    test('a 2FA-free login leaves no pending challenge', () async {
      final transport = _FakeTransport(
          [HttpJsonResponse(200, jsonEncode(_completedResponse()))]);
      final client = AuthClient(baseUri, transport: transport);

      final result = await client.login(LoginRequest(username: 'alice'));

      expect(result.requires2FA, isFalse);
      expect(client.pendingChallenge, isNull);
    });

    test('pass 2 posts the code with the stored interim token and ends up with '
        'the same shape a pass-1-only login yields', () async {
      final pending = _pendingResponse(attempt: 0);
      final completed = _completedResponse();
      final transport = _FakeTransport([
        HttpJsonResponse(200, jsonEncode(pending)),
        HttpJsonResponse(200, jsonEncode(completed)),
      ]);
      final client = AuthClient(baseUri, transport: transport);

      await client.login(LoginRequest(username: 'dave'));
      final result = await client.submitSecondFactor('123456');

      final call = transport.calls.last;
      expect(call.method, equals('POST'));
      expect(call.uri,
          equals(Uri.parse('http://localhost:8081/auth/second-factor')));
      // The interim token travels in the *body*, not as a bearer: the endpoint
      // is public because the interim principal authenticates nothing.
      expect(call.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(call.body!),
          equals({'code': '123456', 'challengeToken': pending['authzToken']}));

      expect(result.requires2FA, isFalse);
      expect(TomBearerAuthentication.token, equals(completed['authToken']));
      expect(TomBearerAuthentication.authorizationToken,
          equals(completed['authzToken']));
      expect(client.pendingChallenge, isNull);
    });

    test('submitting without a prior login fails before any request is sent',
        () async {
      final transport = _FakeTransport([]);
      final client = AuthClient(baseUri, transport: transport);

      await expectLater(
        client.submitSecondFactor('123456'),
        throwsA(isA<AuthClientException>()
            .having((e) => e.key, 'key', 'auth.no_token')),
      );
      expect(transport.calls, isEmpty);
    });

    test('a refused code stores the re-issued token and reports it is retryable',
        () async {
      final pending = _pendingResponse(attempt: 0);
      final reissued = _pendingResponse(attempt: 1, suffix: '-retry');
      final transport = _FakeTransport([
        HttpJsonResponse(200, jsonEncode(pending)),
        HttpJsonResponse(
            401,
            jsonEncode({
              'error': 'login.error.2fa.invalid-code',
              'challengeToken': reissued['authzToken'],
            })),
      ]);
      final client = AuthClient(baseUri, transport: transport);

      await client.login(LoginRequest(username: 'dave'));
      final failure = await client
          .submitSecondFactor('000000')
          .then<Object?>((r) => r)
          .onError<AuthClientException>((error, _) => error);

      expect(failure, isA<AuthClientException>());
      final error = failure as AuthClientException;
      expect(error.key, equals('login.error.2fa.invalid-code'));
      expect(error.statusCode, equals(401));
      expect(error.canRetrySecondFactor, isTrue);

      // The stored token has *advanced*: the attempt counter lives in it, so a
      // client that kept its old copy would show "3 tries left" forever.
      expect(TomBearerAuthentication.authorizationToken,
          equals(reissued['authzToken']));
      expect(client.pendingChallenge!.attemptsRemaining, equals(2));
    });

    test('retrying after a refusal is just another submitSecondFactor call',
        () async {
      final reissued = _pendingResponse(attempt: 1, suffix: '-retry');
      final completed = _completedResponse();
      final transport = _FakeTransport([
        HttpJsonResponse(200, jsonEncode(_pendingResponse(attempt: 0))),
        HttpJsonResponse(
            401,
            jsonEncode({
              'error': 'login.error.2fa.invalid-code',
              'challengeToken': reissued['authzToken'],
            })),
        HttpJsonResponse(200, jsonEncode(completed)),
      ]);
      final client = AuthClient(baseUri, transport: transport);

      await client.login(LoginRequest(username: 'dave'));
      await client
          .submitSecondFactor('000000')
          .then<Object?>((r) => r)
          .onError<AuthClientException>((error, _) => error);
      final result = await client.submitSecondFactor('123456');

      // The retry presents the token the refusal supplied, without the caller
      // having had to thread it through.
      expect(jsonDecode(transport.calls.last.body!)['challengeToken'],
          equals(reissued['authzToken']));
      expect(result.requires2FA, isFalse);
      expect(TomBearerAuthentication.token, equals(completed['authToken']));
    });

    test('a terminal refusal offers no retry and leaves nothing to answer with',
        () async {
      final transport = _FakeTransport([
        HttpJsonResponse(200, jsonEncode(_pendingResponse(attempt: 0))),
        HttpJsonResponse(
            401, jsonEncode({'error': 'login.error.2fa.attempts-exhausted'})),
      ]);
      final client = AuthClient(baseUri, transport: transport);

      final pending = await client.login(LoginRequest(username: 'dave'));
      final failure = await client
          .submitSecondFactor('000000')
          .then<Object?>((r) => r)
          .onError<AuthClientException>((error, _) => error);

      final error = failure as AuthClientException;
      expect(error.key, equals('login.error.2fa.attempts-exhausted'));
      expect(error.canRetrySecondFactor, isFalse);
      // Nothing was re-stored, so the caller is sent back to pass 1 rather than
      // left retrying a spent challenge.
      expect(TomBearerAuthentication.authorizationToken,
          equals(pending.authzToken));
    });

    test('logout drops a half-finished login', () async {
      final transport = _FakeTransport([
        HttpJsonResponse(200, jsonEncode(_pendingResponse(attempt: 0))),
        HttpJsonResponse(200, '{}'),
      ]);
      final client = AuthClient(baseUri, transport: transport);

      await client.login(LoginRequest(username: 'dave'));
      await client.logout();

      // An abandoned challenge must not be left lying around for the next
      // attempt to pick up.
      expect(TomBearerAuthentication.authorizationToken, isNull);
      expect(client.pendingChallenge, isNull);
    });
  });
}

/// A `/auth/login` response for an account that owes a TOTP factor: the interim
/// pair, the `requires2FA` flag, and the challenge claims inside the tokens.
Map<String, Object?> _pendingResponse({
  required int attempt,
  String suffix = '',
}) {
  final claims = {
    'username': 'dave',
    'userId': 5,
    Tom2FAClaims.requires2FA: 'true',
    Tom2FAClaims.type: 'totp',
    Tom2FAClaims.hint: 'Authenticator app',
    Tom2FAClaims.attempt: attempt,
    Tom2FAClaims.attemptsAllowed: 3,
    Tom2FAClaims.expiresAt:
        DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    Tom2FAClaims.clientData: {'digits': 6, 'periodSeconds': 30},
  };
  return {
    'user': _user('dave', 5),
    'authToken': _makeJwt({...claims, 'kind': 'auth$suffix'}),
    'authzToken': _makeJwt({...claims, 'kind': 'authz$suffix'}),
    'expiresAt': '2026-06-28T12:34:56.000Z',
    'requires2FA': true,
    'twoFactorType': 'totp',
  };
}

/// A completed `/auth/login` or `/auth/second-factor` response — no challenge
/// claims, which is exactly what makes it indistinguishable from a single-pass
/// login.
Map<String, Object?> _completedResponse() => {
      'user': _user('dave', 5),
      'authToken': _makeJwt({'username': 'dave', 'userId': 5, 'kind': 'auth-ok'}),
      'authzToken':
          _makeJwt({'username': 'dave', 'userId': 5, 'kind': 'authz-ok'}),
      'expiresAt': '2026-06-28T12:34:56.000Z',
    };

Map<String, Object?> _user(String username, int id) => {
      'id': '$id',
      'username': username,
      'displayName': username,
      'email': '$username@example.com',
      'status': 'active',
    };

/// Builds an unsigned, undecrypted JWT whose middle segment carries [payload].
/// Suitable for `setTokens(..., decrypt: false)`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.sig';
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
    Map<String, String>? headers,
    String? body,
  }) async {
    calls.add(_Call(method, uri, headers ?? const {}, body));
    return _responses[_next++];
  }
}
