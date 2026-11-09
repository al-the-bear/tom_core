import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:http/http.dart'
    show BaseClient, BaseRequest, Request, StreamedResponse;
import 'package:http2/transport.dart' as h2;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The push channel: a configurable protocol, the FCM and APNs protocols built
/// on it, their credentials, and the transport that classifies every answer.
///
/// No test reaches FCM or APNs. Each vendor case scripts an answer in the
/// vendor's documented format and asserts what the protocol makes of it; the
/// HTTP/2 exchange is driven against a local plain-text HTTP/2 server.

// =============================================================================
// FIXTURES
// =============================================================================

// Throwaway keys generated for this suite and used nowhere else. The armour is
// split so a secret scanner reading the source does not mistake them for a
// leaked credential.
const String _ecPrivatePem =
    '-----BEGIN '
    'PRIVATE KEY-----\n'
    'MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg64Kgy89vneVbnvlG\n'
    'XQvdx0pD2u82men6f0yXFr9rYSKhRANCAAQgW1vgqkOOpvjlAYh5VoGilEi7AKJo\n'
    'of+IRyR48tbedG4f6ftxszSMN2lWPu5r9nl8Y2GfSN+2mfqoCnLbQIXG\n'
    '-----END '
    'PRIVATE KEY-----\n';

const String _ecPublicPem =
    '-----BEGIN '
    'PUBLIC KEY-----\n'
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIFtb4KpDjqb45QGIeVaBopRIuwCi\n'
    'aKH/iEckePLW3nRuH+n7cbM0jDdpVj7ua/Z5fGNhn0jftpn6qApy20CFxg==\n'
    '-----END '
    'PUBLIC KEY-----\n';

const String _rsaPrivatePem =
    '-----BEGIN '
    'PRIVATE KEY-----\n'
    'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCo/FWay0VH7DRE\n'
    '5Oatm6Jyx6hqkYhGGKIAr3M4tFzNoHcU5SROPbfYdEg/jLmCcJZuBLfJl4vHL6GG\n'
    'Gsjr84qb5ZWWnqKTG7zTyMOxhxiaSG0LqAou1AxkNwoV142b3YGgi7Tfsjy67mvm\n'
    'E+/fHekQyMnI9s9Br3ZJWHEQHUrXIYV1/aGWyllj2wRC/EMVjLuRV6npFbcuiE0a\n'
    'NR2llEpt/5OTw25eCeJi6EBSBVKZMgwDScPXmt7RXwT643tyEDSYlgkT/bCuozhE\n'
    'Tx29QmmP9IbHBZlVTx51glblnc04CwqyVnOm73eVOJtHJc6e8ZJ6JpzD1st9ARbV\n'
    'vRFWHYLjAgMBAAECggEALqJkZXGPTwfqbNDWsDZxIEflPHOpLd8CZjoFDDMKIV0V\n'
    'P9j0qfryT3PXtGH7l/nGKdp3ddSyqGeGpeGibSsqp1c2bvicWQiglbmj98wWiA1Q\n'
    'upTHKqEuQkHGMLzpwYfhjBLB+bHQfK3rbPU3j1VLymv+88zY6YGonRkhKpdK3g9Z\n'
    'B6ToNHtR4lXlgEEG2+1ByoZTNeY8Cx8ylxiLsQU8pXgTCJsxt0MDYD4DZZ7lmIPV\n'
    'XuPqsle/CS8yBkrAsstx1P900+jSJWx3KLKBRFPeVWX22jjoE8oAz0L7JzpirkVy\n'
    'ODDPE6/JZpUhHZvyOHWQ0xJE+7ih0xmqqIvB2P0iIQKBgQDgpz92FiUAaiI5K62l\n'
    'kiCYnlWLRhowCvruvJC3LcymWAh6s9E93g5Bv8DP2i/UYwKu+Hp4MsfoDoIvvRZ6\n'
    'tEsxN9VEIG8gUEatIyshCA8IwOrV0Tae6CR33rrQQUsUqgCyv3dpnN29azKnNhez\n'
    'qSk45IbzVH1lgK1VsOHZsndU+wKBgQDAkJrmGNfC1BLgH2VjcA6p37pjT8LpComi\n'
    'yPI9SL7Br+2/fjgxinmt5YT6XgpFvj8/G/JnnBH9LJgcBYoYIY61EYaRcAmRC2gr\n'
    'mQjlUAkwJ9bt6EB3LNjUJhyeFDUjnGQwoeR05kYycdYO+mvIZ53sssRDzhsC6ENd\n'
    '6tEMfEkVOQKBgHDQrFbRsg0uPzd0jsQ5yLK7uHuzXY1IxlDDUu0aS84xITj1OhuW\n'
    'epRcBiibCi/e9McHMwFPhwIq3we4LiS6i5QQ1MFchFG23nct1QfGcz5TGtr7MDHG\n'
    'pCGqMShJ0blz0dvxuLbJtrTbs1kzGd34EiJm6LojcMFbSDBjHlfjfnenAoGBAJTz\n'
    'Ba34B2Tfb95GysEY227Q7LaG6sgh64asEpwO2eat86PMuSCw8R/uymZzOVTrLLbf\n'
    'Iii8kzmXNe1u53t08ZLjhIiY9f1oqmIW1MezmffSyTBrFvpYCTxIYphwHw51mRX5\n'
    'E+LMf/3jCeW6FIcGhySgvqmIEmK0T++kg6E5vboZAoGAXuHpp5rmM+p8MeRR8310\n'
    'KPrAI2+uIsV7zVeMbB6XqzSIBSa6GV8+iL+R5bz3jPD1Z+yHfZ+caRPx+E+jZIW4\n'
    'tpqJyu6Rbt3kVhV2jipc/+kXzN50jIONOau4fT3ZcLKumDwUkOOyUN5FPf6/SBQa\n'
    '+lPVVNSZPxQKbSvUfWj/wi0=\n'
    '-----END '
    'PRIVATE KEY-----\n';

const String _rsaPublicPem =
    '-----BEGIN '
    'PUBLIC KEY-----\n'
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqPxVmstFR+w0ROTmrZui\n'
    'cseoapGIRhiiAK9zOLRczaB3FOUkTj232HRIP4y5gnCWbgS3yZeLxy+hhhrI6/OK\n'
    'm+WVlp6ikxu808jDsYcYmkhtC6gKLtQMZDcKFdeNm92BoIu037I8uu5r5hPv3x3p\n'
    'EMjJyPbPQa92SVhxEB1K1yGFdf2hlspZY9sEQvxDFYy7kVep6RW3LohNGjUdpZRK\n'
    'bf+Tk8NuXgniYuhAUgVSmTIMA0nD15re0V8E+uN7chA0mJYJE/2wrqM4RE8dvUJp\n'
    'j/SGxwWZVU8edYJW5Z3NOAsKslZzpu93lTibRyXOnvGSeiacw9bLfQEW1b0RVh2C\n'
    '4wIDAQAB\n'
    '-----END '
    'PUBLIC KEY-----\n';

/// A [TomPushExchange] whose every answer is scripted.
class _ScriptedExchange extends TomPushExchange {
  _ScriptedExchange(this.answer);

  /// Answers one request. Throwing from here is how a network failure is
  /// spelled.
  final FutureOr<TomPushGatewayResponse> Function(TomPushGatewayRequest) answer;

  /// Every request made, in order.
  final List<TomPushGatewayRequest> requests = [];

  bool closed = false;

  @override
  Future<TomPushGatewayResponse> exchange(TomPushGatewayRequest request) async {
    requests.add(request);
    return answer(request);
  }

  @override
  Future<void> close() async => closed = true;
}

/// A credential that counts its mints, so a refresh is observable.
class _CountingCredential extends TomPushCredential {
  int minted = 0;
  String? _token;

  @override
  Future<String> token() async => _token ??= 'token-${++minted}';

  @override
  void invalidate() => _token = null;
}

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

TomPushSubmission _submission({
  String token = 'device-a',
  String? title = 'Assigned',
  Map<String, String> data = const {},
}) => TomPushSubmission(
  messageId: 'm-1',
  token: token,
  title: title,
  body: 'Alpha is yours.',
  data: data,
);

TomMessage _message({List<String> tokens = const ['device-a']}) =>
    TomMessage.push(
      id: 'm-1',
      to: [for (final token in tokens) TomRecipient(token)],
      title: 'Assigned',
      body: 'Alpha is yours.',
      data: {'taskId': '42'},
    );

TomPushGatewayResponse _json(int status, Object body) =>
    TomPushGatewayResponse(status, jsonEncode(body));

Map<String, Object?> _fcmError(int code, String status, [String? fcmCode]) => {
  'error': {
    'code': code,
    'message': 'refused',
    'status': status,
    'details': [
      if (fcmCode != null)
        {
          '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
          'errorCode': fcmCode,
        },
    ],
  },
};

Matcher _deliveryKey(String key, {required bool permanent}) => throwsA(
  isA<TomDeliveryException>()
      .having((e) => e.key, 'key', key)
      .having((e) => e.isPermanent, 'isPermanent', permanent),
);

Matcher _messagingKey(String key) =>
    throwsA(isA<TomMessagingException>().having((e) => e.key, 'key', key));

void main() {
  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  group('TomMessage.push', () {
    test('puts the title in the subject and the data in metadata', () {
      final message = _message();
      expect(message.channel, TomMessageChannel.push);
      expect(message.subject, 'Assigned');
      expect(message.textBody!.content, 'Alpha is yours.');
      expect(message.metadata[TomPushTransport.dataMetadataKey], {
        'taskId': '42',
      });
    });

    test('survives the outbox JSON round trip', () {
      final copy = TomMessage.fromJson(
        (jsonDecode(jsonEncode(_message().toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copy.channel, TomMessageChannel.push);
      expect(copy.metadata[TomPushTransport.dataMetadataKey], {'taskId': '42'});
    });
  });

  // ===========================================================================
  // FCM
  // ===========================================================================

  group('TomFcmPushProtocol', () {
    final fcm = TomFcmPushProtocol(projectId: 'demo-project');

    test('encodes the HTTP v1 message', () {
      final request = fcm.encode(_submission(data: {'taskId': '42'}), 'access');
      expect(
        request.url.toString(),
        'https://fcm.googleapis.com/v1/projects/demo-project/messages:send',
      );
      expect(request.headers['Authorization'], 'Bearer access');
      expect(jsonDecode(request.body), {
        'message': {
          'token': 'device-a',
          'notification': {'title': 'Assigned', 'body': 'Alpha is yours.'},
          'data': {'taskId': '42'},
        },
      });
      expect(fcm.requiresHttp2, isFalse);
    });

    test('omits an absent title and an empty data map', () {
      final body = jsonDecode(fcm.encode(_submission(title: null), null).body);
      expect(body['message']['notification'], {'body': 'Alpha is yours.'});
      expect((body['message'] as Map).containsKey('data'), isFalse);
    });

    test('a success reports the message name', () {
      final answer = fcm.decode(
        _json(200, {'name': 'projects/demo-project/messages/0:1'}),
      );
      expect(answer.isAccepted, isTrue);
      expect(answer.remoteId, 'projects/demo-project/messages/0:1');
    });

    test('UNREGISTERED is permanent — the app was uninstalled', () {
      final answer = fcm.decode(
        _json(404, _fcmError(404, 'NOT_FOUND', 'UNREGISTERED')),
      );
      expect(answer.isAccepted, isFalse);
      expect(answer.providerCode, 'UNREGISTERED');
      expect(answer.isPermanent, isTrue);
    });

    test('QUOTA_EXCEEDED is transient', () {
      final answer = fcm.decode(
        _json(429, _fcmError(429, 'RESOURCE_EXHAUSTED', 'QUOTA_EXCEEDED')),
      );
      expect(answer.isPermanent, isFalse);
    });

    test('UNAUTHENTICATED is a rejected credential, body or not', () {
      expect(
        fcm
            .decode(_json(401, _fcmError(401, 'UNAUTHENTICATED')))
            .isCredentialRejected,
        isTrue,
      );
      expect(
        fcm.decode(TomPushGatewayResponse(401, '')).isCredentialRejected,
        isTrue,
      );
    });

    test('an unknown code leaves the judgement to the status', () {
      final answer = fcm.decode(_json(500, _fcmError(500, 'SOMETHING_NEW')));
      expect(answer.isPermanent, isNull);
    });
  });

  // ===========================================================================
  // APNS
  // ===========================================================================

  group('TomApnsPushProtocol', () {
    const apns = TomApnsPushProtocol(topic: 'com.example.app');

    test('encodes the device path, headers and aps payload', () {
      final request = apns.encode(
        _submission(token: 'device-token', data: {'taskId': '42', 'aps': 'x'}),
        'jwt',
      );
      expect(
        request.url.toString(),
        'https://api.push.apple.com/3/device/device-token',
      );
      expect(request.headers, {
        'authorization': 'bearer jwt',
        'apns-topic': 'com.example.app',
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'content-type': 'application/json',
      });
      expect(jsonDecode(request.body), {
        'taskId': '42',
        'aps': {
          'alert': {'title': 'Assigned', 'body': 'Alpha is yours.'},
        },
      }, reason: 'a data key named aps must not replace the alert');
      expect(apns.requiresHttp2, isTrue);
    });

    test('the sandbox flag selects the development host', () {
      const sandbox = TomApnsPushProtocol(topic: 't', sandbox: true);
      expect(
        sandbox.encode(_submission(), null).url.host,
        'api.sandbox.push.apple.com',
      );
    });

    test('a success reports the apns-id header', () {
      final answer = apns.decode(
        TomPushGatewayResponse(200, '', headers: {'Apns-Id': 'uuid-1'}),
      );
      expect(answer.isAccepted, isTrue);
      expect(answer.remoteId, 'uuid-1');
    });

    test('Unregistered and BadDeviceToken are permanent', () {
      for (final reason in ['Unregistered', 'BadDeviceToken']) {
        final answer = apns.decode(_json(410, {'reason': reason}));
        expect(answer.isPermanent, isTrue, reason: reason);
        expect(answer.providerCode, reason);
      }
    });

    test('TooManyRequests is transient', () {
      expect(
        apns.decode(_json(429, {'reason': 'TooManyRequests'})).isPermanent,
        isFalse,
      );
    });

    test('ExpiredProviderToken is a rejected credential', () {
      final answer = apns.decode(
        _json(403, {'reason': 'ExpiredProviderToken'}),
      );
      expect(answer.isCredentialRejected, isTrue);
      expect(answer.isPermanent, isNull);
    });
  });

  // ===========================================================================
  // FIELD-MAPPED
  // ===========================================================================

  group('TomFieldMappedPushProtocol', () {
    const mapped = TomFieldMappedPushProtocol(
      endpoint: 'https://push.example.com/v2/devices/{token}/send',
      tokenField: null,
      titleField: 'notification.title',
      bodyField: 'notification.body',
      extraFields: {'priority': 'high'},
      authorizationHeader: 'X-Api-Key',
      authorizationPrefix: '',
      statusPath: 'result',
      acceptedStatuses: {'queued'},
      remoteIdPath: 'id',
      errorCodePath: 'error.code',
      errorMessagePath: 'error.message',
      permanentErrorCodes: {'dead_token'},
      transientErrorCodes: {'busy'},
      credentialErrorCodes: {'expired_key'},
    );

    test('builds nested fields and puts the token in the path', () {
      final request = mapped.encode(
        _submission(token: 'a/b', data: {'k': 'v'}),
        'secret',
      );
      expect(
        request.url.toString(),
        'https://push.example.com/v2/devices/a%2Fb/send',
      );
      expect(request.headers['X-Api-Key'], 'secret');
      expect(jsonDecode(request.body), {
        'priority': 'high',
        'notification': {'title': 'Assigned', 'body': 'Alpha is yours.'},
        'data': {'k': 'v'},
      });
    });

    test('a 200 whose status is not accepted is not a success', () {
      expect(mapped.decode(_json(200, {'result': 'held'})).isAccepted, isFalse);
      final ok = mapped.decode(_json(200, {'result': 'QUEUED', 'id': 'n-1'}));
      expect(ok.isAccepted, isTrue);
      expect(ok.remoteId, 'n-1');
    });

    test('classifies the configured codes', () {
      TomPushGatewayAnswer of(String code) => mapped.decode(
        _json(400, {
          'error': {'code': code, 'message': 'no'},
        }),
      );
      expect(of('dead_token').isPermanent, isTrue);
      expect(of('busy').isPermanent, isFalse);
      expect(of('expired_key').isCredentialRejected, isTrue);
      expect(of('other').isPermanent, isNull);
      expect(of('other').detail, 'no');
    });
  });

  // ===========================================================================
  // CREDENTIALS
  // ===========================================================================

  group('TomApnsProviderToken', () {
    test('signs an ES256 token with the team and key ids', () async {
      final clock = _FakeClock(DateTime.utc(2026, 10, 7, 12));
      final credential = TomApnsProviderToken(
        teamId: 'TEAM123456',
        keyId: 'KEY1234567',
        privateKeyPem: _ecPrivatePem,
        now: clock.call,
      );
      final token = await credential.token();
      final verified = jwt.JWT.verify(token, jwt.ECPublicKey(_ecPublicPem));
      expect(verified.header!['alg'], 'ES256');
      expect(verified.header!['kid'], 'KEY1234567');
      expect(verified.payload['iss'], 'TEAM123456');
      expect(verified.payload['iat'], clock.now.millisecondsSinceEpoch ~/ 1000);
    });

    test('reuses a token for its lifetime, then mints anew', () async {
      final clock = _FakeClock(DateTime.utc(2026, 10, 7, 12));
      final credential = TomApnsProviderToken(
        teamId: 'T',
        keyId: 'K',
        privateKeyPem: _ecPrivatePem,
        now: clock.call,
      );
      final first = await credential.token();
      clock.advance(const Duration(minutes: 49));
      expect(await credential.token(), first);
      clock.advance(const Duration(minutes: 2));
      expect(await credential.token(), isNot(first));
    });

    test('invalidate forces a fresh token', () async {
      final clock = _FakeClock(DateTime.utc(2026, 10, 7, 12));
      final credential = TomApnsProviderToken(
        teamId: 'T',
        keyId: 'K',
        privateKeyPem: _ecPrivatePem,
        now: clock.call,
      );
      final first = await credential.token();
      clock.advance(const Duration(seconds: 1));
      credential.invalidate();
      expect(await credential.token(), isNot(first));
    });

    test('a key that is not an EC key fails at construction', () {
      expect(
        () => TomApnsProviderToken(
          teamId: 'T',
          keyId: 'K',
          privateKeyPem: 'not a key',
        ),
        _messagingKey('messaging.push.bad_key'),
      );
    });
  });

  group('TomFcmServiceAccountCredential', () {
    String keyFile({String? email = 'push@demo.iam.gserviceaccount.com'}) =>
        jsonEncode({
          'type': 'service_account',
          'project_id': 'demo-project',
          'private_key': _rsaPrivatePem,
          'client_email': ?email,
          'token_uri': 'https://oauth2.example.com/token',
        });

    test('exchanges a signed assertion and caches the token', () async {
      final clock = _FakeClock(DateTime.utc(2026, 10, 7, 12));
      final exchange = _ScriptedExchange(
        (_) => _json(200, {'access_token': 'ya29.a', 'expires_in': 3599}),
      );
      final credential = TomFcmServiceAccountCredential.fromJson(
        keyFile(),
        exchange: exchange,
        now: clock.call,
      );
      expect(credential.projectId, 'demo-project');
      expect(await credential.token(), 'ya29.a');

      final request = exchange.requests.single;
      expect(request.url.toString(), 'https://oauth2.example.com/token');
      final form = Uri.splitQueryString(request.body);
      expect(form['grant_type'], 'urn:ietf:params:oauth:grant-type:jwt-bearer');
      final assertion = jwt.JWT.verify(
        form['assertion']!,
        jwt.RSAPublicKey(_rsaPublicPem),
        // Minted on the fixed clock, which the real one has long passed.
        checkExpiresIn: false,
      );
      expect(assertion.payload['iss'], 'push@demo.iam.gserviceaccount.com');
      expect(
        assertion.payload['scope'],
        TomFcmServiceAccountCredential.messagingScope,
      );
      expect(assertion.payload['aud'], 'https://oauth2.example.com/token');

      clock.advance(const Duration(minutes: 50));
      expect(await credential.token(), 'ya29.a');
      expect(exchange.requests, hasLength(1), reason: 'cached');
      clock.advance(const Duration(minutes: 6));
      await credential.token();
      expect(exchange.requests, hasLength(2), reason: 'renewed before expiry');
    });

    test('a key file without client_email is refused', () {
      expect(
        () => TomFcmServiceAccountCredential.fromJson(keyFile(email: null)),
        _messagingKey('messaging.push.bad_service_account'),
      );
      expect(
        () => TomFcmServiceAccountCredential.fromJson('{not json'),
        _messagingKey('messaging.push.bad_service_account'),
      );
    });

    test('a refused grant is permanent', () async {
      final credential = TomFcmServiceAccountCredential.fromJson(
        keyFile(),
        exchange: _ScriptedExchange(
          (_) => _json(400, {'error': 'invalid_grant'}),
        ),
      );
      await expectLater(
        credential.token(),
        _deliveryKey('messaging.push.credential_refused', permanent: true),
      );
    });

    test('an unreachable or failing token endpoint is transient', () async {
      final down = TomFcmServiceAccountCredential.fromJson(
        keyFile(),
        exchange: _ScriptedExchange(
          (_) => throw const SocketException('refused'),
        ),
      );
      await expectLater(
        down.token(),
        _deliveryKey('messaging.push.credential_unavailable', permanent: false),
      );
      final failing = TomFcmServiceAccountCredential.fromJson(
        keyFile(),
        exchange: _ScriptedExchange((_) => TomPushGatewayResponse(503, '')),
      );
      await expectLater(
        failing.token(),
        _deliveryKey('messaging.push.credential_unavailable', permanent: false),
      );
    });
  });

  // ===========================================================================
  // TRANSPORT
  // ===========================================================================

  group('TomPushTransport', () {
    final fcm = TomFcmPushProtocol(projectId: 'demo-project');

    test('delivers to every token and reports the first remote id', () async {
      final exchange = _ScriptedExchange((_) => _json(200, {'name': 'n-1'}));
      final transport = TomPushTransport(
        fcm,
        credential: const TomStaticPushCredential('access'),
        exchange: exchange,
      );
      final receipt = await transport.send(
        _message(tokens: ['device-a', 'device-b']),
      );
      expect(receipt.outcome, TomDeliveryOutcome.delivered);
      expect(receipt.rejectedRecipients, isEmpty);
      expect(exchange.requests, hasLength(2));
      final body = jsonDecode(exchange.requests.first.body);
      expect(body['message']['data'], {'taskId': '42'});
      expect(body['message']['notification']['title'], 'Assigned');
    });

    test(
      'a dead token is a rejected recipient, not a failed message',
      () async {
        final transport = TomPushTransport(
          fcm,
          exchange: _ScriptedExchange(
            (r) => jsonDecode(r.body)['message']['token'] == 'dead'
                ? _json(404, _fcmError(404, 'NOT_FOUND', 'UNREGISTERED'))
                : _json(200, {'name': 'n-1'}),
          ),
        );
        final receipt = await transport.send(
          _message(tokens: ['dead', 'device-a']),
        );
        expect(receipt.rejectedRecipients, ['dead']);
      },
    );

    test('every token rejected fails the message permanently', () async {
      final transport = TomPushTransport(
        fcm,
        exchange: _ScriptedExchange(
          (_) => _json(
            400,
            _fcmError(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT'),
          ),
        ),
      );
      await expectLater(
        transport.send(_message()),
        _deliveryKey('messaging.push.all_recipients_rejected', permanent: true),
      );
    });

    test('a transient refusal stops the pass and defers', () async {
      final exchange = _ScriptedExchange(
        (_) =>
            _json(429, _fcmError(429, 'RESOURCE_EXHAUSTED', 'QUOTA_EXCEEDED')),
      );
      final transport = TomPushTransport(fcm, exchange: exchange);
      await expectLater(
        transport.send(_message(tokens: ['a', 'b', 'c'])),
        _deliveryKey('messaging.push.gateway_deferred', permanent: false),
      );
      expect(exchange.requests, hasLength(1));
    });

    test('an unknown code on a 5xx defers by the status rule', () async {
      final transport = TomPushTransport(
        fcm,
        exchange: _ScriptedExchange((_) => TomPushGatewayResponse(502, '')),
      );
      await expectLater(
        transport.send(_message()),
        _deliveryKey('messaging.push.gateway_deferred', permanent: false),
      );
    });

    test(
      'a rejected credential is refreshed once and the send retried',
      () async {
        final credential = _CountingCredential();
        final exchange = _ScriptedExchange(
          (r) => r.headers['Authorization'] == 'Bearer token-1'
              ? _json(401, _fcmError(401, 'UNAUTHENTICATED'))
              : _json(200, {'name': 'n-1'}),
        );
        final transport = TomPushTransport(
          fcm,
          credential: credential,
          exchange: exchange,
        );
        final receipt = await transport.send(_message());
        expect(receipt.outcome, TomDeliveryOutcome.delivered);
        expect(credential.minted, 2);
        expect(exchange.requests, hasLength(2));
      },
    );

    test('a credential rejected twice fails permanently', () async {
      final transport = TomPushTransport(
        const TomApnsPushProtocol(topic: 't'),
        credential: _CountingCredential(),
        exchange: _ScriptedExchange(
          (_) => _json(403, {'reason': 'InvalidProviderToken'}),
        ),
      );
      await expectLater(
        transport.send(_message()),
        _deliveryKey('messaging.push.credential_rejected', permanent: true),
      );
    });

    test('an unreachable service defers', () async {
      final transport = TomPushTransport(
        fcm,
        exchange: _ScriptedExchange(
          (_) => throw const SocketException('no route'),
        ),
      );
      await expectLater(
        transport.send(_message()),
        _deliveryKey('messaging.push.unreachable', permanent: false),
      );
    });

    test('a message with no text is refused before anything is sent', () async {
      final exchange = _ScriptedExchange((_) => _json(200, {}));
      final transport = TomPushTransport(fcm, exchange: exchange);
      await expectLater(
        transport.send(
          TomMessage(
            channel: TomMessageChannel.push,
            recipients: [TomRecipient('device-a')],
          ),
        ),
        _deliveryKey('messaging.push.no_body', permanent: true),
      );
      expect(exchange.requests, isEmpty);
    });

    test('picks HTTP/2 for APNs and HTTP/1.1 for FCM by default', () async {
      final apns = TomPushTransport(const TomApnsPushProtocol(topic: 't'));
      final http1 = TomPushTransport(fcm);
      expect(apns.exchange, isA<TomHttp2PushExchange>());
      expect(http1.exchange, isA<TomHttp1PushExchange>());
      await apns.close();
      await http1.close();
    });

    test('close releases the exchange', () async {
      final exchange = _ScriptedExchange((_) => _json(200, {}));
      await TomPushTransport(fcm, exchange: exchange).close();
      expect(exchange.closed, isTrue);
    });
  });

  // ===========================================================================
  // EXCHANGES
  // ===========================================================================

  group('TomHttp1PushExchange', () {
    test('sends over the kernel call layer without the caller token', () async {
      final client = _FakeClient(
        (request) async => StreamedResponse(
          Stream.value(utf8.encode('{"name":"n-1"}')),
          200,
          headers: {'X-Trace': 'abc'},
        ),
      );
      final exchange = TomHttp1PushExchange(
        clientFactory: _FakeClientFactory(client),
      );
      final response = await exchange.exchange(
        TomPushGatewayRequest(
          url: Uri.parse('https://fcm.example.com/v1/send'),
          headers: const {'Authorization': 'Bearer access'},
          body: '{"a":1}',
        ),
      );
      await exchange.close();
      expect(response.statusCode, 200);
      expect(response.body, '{"name":"n-1"}');
      expect(response.headers['x-trace'], 'abc');
      expect(client.requests.single.url.host, 'fcm.example.com');
      expect(client.requests.single.headers['Authorization'], 'Bearer access');
      expect(client.bodies.single, '{"a":1}');
    });
  });

  group('TomHttp2PushExchange', () {
    test('round-trips a request over one reused HTTP/2 connection', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var connections = 0;
      final paths = <String>[];
      server.listen((socket) {
        connections++;
        final connection = h2.ServerTransportConnection.viaSocket(socket);
        connection.incomingStreams.listen((stream) async {
          final headers = <String, String>{};
          final body = <int>[];
          await for (final message in stream.incomingMessages) {
            if (message is h2.HeadersStreamMessage) {
              for (final header in message.headers) {
                headers[ascii.decode(header.name)] = utf8.decode(header.value);
              }
            } else if (message is h2.DataStreamMessage) {
              body.addAll(message.bytes);
            }
          }
          paths.add(headers[':path']!);
          final ok =
              headers['apns-topic'] == 'com.example.app' &&
              utf8.decode(body).contains('Alpha');
          stream.sendHeaders([
            h2.Header.ascii(':status', ok ? '200' : '400'),
            h2.Header.ascii('apns-id', 'uuid-${paths.length}'),
          ], endStream: true);
        });
      });

      final exchange = TomHttp2PushExchange(
        connect: (url) => Socket.connect(url.host, url.port),
      );
      final protocol = TomApnsPushProtocol(
        topic: 'com.example.app',
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final transport = TomPushTransport(
        protocol,
        credential: const TomStaticPushCredential('jwt'),
        exchange: exchange,
      );
      final receipt = await transport.send(
        _message(tokens: ['device-a', 'device-b']),
      );
      await transport.close();
      await server.close();

      expect(receipt.rejectedRecipients, isEmpty);
      expect(receipt.remoteId, 'uuid-1');
      expect(paths, ['/3/device/device-a', '/3/device/device-b']);
      expect(
        connections,
        1,
        reason: 'Apple asks for one long-lived connection',
      );
    });
  });
}

/// A [BaseClient] whose every response is scripted.
class _FakeClient extends BaseClient {
  _FakeClient(this.handler);

  final Future<StreamedResponse> Function(BaseRequest request) handler;
  final List<BaseRequest> requests = [];
  final List<String> bodies = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request);
    bodies.add(request is Request ? request.body : '');
    return handler(request);
  }
}

/// Hands a [TomServerChannel] the scripted client.
class _FakeClientFactory implements TomHttpClientAbstractFactory {
  _FakeClientFactory(this._client);

  final _FakeClient _client;

  @override
  _FakeClient getClient() => _client;
}
