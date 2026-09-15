import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart'
    show BaseClient, BaseRequest, Request, StreamedResponse;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The second implementation of [TomMessageTransport], and therefore the first
/// test of whether that contract is an abstraction at all.
///
/// Everything here asserts one of three things:
///
/// - **segmentation** — the concern SMS has and email does not, measured in
///   billable units rather than characters;
/// - **classification** — the single judgement a transport is allowed to make,
///   split across an HTTP status rule the framework owns and a provider payload
///   rule the deployment configures;
/// - **the seam** — that a queued SMS rides the same outbox, the same retry
///   budget and the same permanence marker an email does.

// =============================================================================
// FIXTURES
// =============================================================================

/// A [BaseClient] whose every response is scripted, so no socket is opened and
/// every branch of the classification is reachable.
class _FakeGateway extends BaseClient {
  _FakeGateway(this.handler);

  /// Answers one request. Throwing from here is how a network failure is
  /// spelled.
  final Future<StreamedResponse> Function(BaseRequest request) handler;

  /// Every request the transport made, in order.
  final List<BaseRequest> requests = [];

  /// The bodies of those requests, in the same order.
  final List<String> bodies = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request);
    bodies.add(request is Request ? request.body : '');
    return handler(request);
  }
}

/// Hands a [TomServerChannel] the scripted client instead of a real one.
class _FakeGatewayFactory implements TomHttpClientAbstractFactory {
  _FakeGatewayFactory(this._client);

  final _FakeGateway _client;

  @override
  _FakeGateway getClient() => _client;
}

StreamedResponse _answer(String body, {int status = 200}) {
  final bytes = utf8.encode(body);
  return StreamedResponse(
    Stream<List<int>>.value(bytes),
    status,
    contentLength: bytes.length,
  );
}

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

TomSmsGatewaySettings _settings({
  String? senderId = 'TOMTEST',
  int maxSegments = 3,
  TomSmsAuthScheme authScheme = TomSmsAuthScheme.bearer,
}) => TomSmsGatewaySettings(
  endpoint: Uri.parse('https://gateway.example.com/v1/messages'),
  apiKey: 'key-123',
  apiSecret: 'secret-456',
  senderId: senderId,
  authScheme: authScheme,
  maxSegments: maxSegments,
);

/// A field mapping in the shape the common gateways use: a form post, a
/// `status` string in the answer, and numeric provider codes for the failures
/// the HTTP status does not distinguish.
TomFieldMappedSmsProtocol _protocol() => TomFieldMappedSmsProtocol(
  toField: 'to',
  fromField: 'from',
  textField: 'body',
  statusPath: 'status',
  acceptedStatuses: const {'queued', 'sent'},
  remoteIdPath: 'sid',
  errorCodePath: 'code',
  errorMessagePath: 'message',
  permanentErrorCodes: const {'21211', '21610'},
  transientErrorCodes: const {'20429'},
);

TomMessage _sms({
  String id = 's1',
  List<String> to = const ['+41791234567'],
  String text = 'Your code is 123456.',
  Map<String, Object?>? metadata,
}) => TomMessage(
  id: id,
  channel: TomMessageChannel.sms,
  recipients: to.map(TomRecipient.new).toList(),
  bodies: [TomMessageBody.text(text)],
  metadata: metadata,
);

/// Builds a transport over a scripted gateway, returning both so a test can
/// assert on what was sent as well as what came back.
({TomSmsTransport transport, _FakeGateway gateway}) _transport(
  Future<StreamedResponse> Function(BaseRequest request) handler, {
  TomSmsGatewaySettings? settings,
  TomSmsGatewayProtocol? protocol,
}) {
  final gateway = _FakeGateway(handler);
  final resolved = settings ?? _settings();
  return (
    transport: TomSmsTransport(
      resolved,
      protocol ?? _protocol(),
      openChannel: (s) => TomServerChannel(
        s.endpoint.host,
        s.endpoint.port,
        clientFactory: _FakeGatewayFactory(gateway),
      ),
    ),
    gateway: gateway,
  );
}

void main() {
  // ===========================================================================
  // SEGMENTATION
  // ===========================================================================

  group('TomSmsSegmentation', () {
    test('plain text is GSM-7 and fits one segment', () {
      final s = TomSmsSegmentation.of('Your code is 123456.');
      expect(s.encoding, TomSmsEncoding.gsm7);
      expect(s.units, 20);
      expect(s.segments, 1);
      expect(s.isMultipart, isFalse);
    });

    test('160 GSM-7 units is one segment and 161 is two', () {
      expect(TomSmsSegmentation.of('a' * 160).segments, 1);
      // The 161st character does not add a segment, it adds *two*: a
      // concatenated message spends seven bits per part on the header, so the
      // capacity of every part drops to 153.
      final over = TomSmsSegmentation.of('a' * 161);
      expect(over.segments, 2);
      expect(over.isMultipart, isTrue);
    });

    test('a concatenated GSM-7 part holds 153, not 160', () {
      expect(TomSmsSegmentation.of('a' * 306).segments, 2);
      expect(TomSmsSegmentation.of('a' * 307).segments, 3);
    });

    test('a character outside the GSM alphabet forces UCS-2', () {
      final s = TomSmsSegmentation.of('Grüße 😀');
      expect(s.encoding, TomSmsEncoding.ucs2);
    });

    test('70 UCS-2 units is one segment and 71 is two', () {
      // 'ł' is not in the GSM alphabet, so the whole message is UCS-2.
      expect(TomSmsSegmentation.of('ł' * 70).segments, 1);
      expect(TomSmsSegmentation.of('ł' * 71).segments, 2);
      expect(TomSmsSegmentation.of('ł' * 134).segments, 2);
      expect(TomSmsSegmentation.of('ł' * 135).segments, 3);
    });

    test('a non-BMP character costs two UCS-2 units', () {
      // The surrogate pair is what goes on the wire, and what is billed.
      final s = TomSmsSegmentation.of('😀');
      expect(s.encoding, TomSmsEncoding.ucs2);
      expect(s.units, 2);
    });

    test('a GSM extension character costs two units, not one', () {
      // The escape-table characters are the most commonly missed billing
      // detail: a message of 80 euro signs is 160 units, not 80.
      final euros = TomSmsSegmentation.of('€' * 80);
      expect(euros.encoding, TomSmsEncoding.gsm7);
      expect(euros.units, 160);
      expect(euros.segments, 1);
      expect(TomSmsSegmentation.of('€' * 81).segments, 2);

      for (final char in ['^', '{', '}', r'\', '[', '~', ']', '|']) {
        expect(
          TomSmsSegmentation.of(char).units,
          2,
          reason: '$char is an escape-table character',
        );
      }
    });

    test('accented GSM characters stay single-unit', () {
      // These are in the *basic* table, so a German message does not silently
      // halve its capacity.
      final s = TomSmsSegmentation.of('Grüße Ähnlich Öl §');
      expect(s.encoding, TomSmsEncoding.gsm7);
      expect(s.units, 18);
    });

    test('an empty message is one segment, not zero', () {
      expect(TomSmsSegmentation.of('').segments, 1);
      expect(TomSmsSegmentation.of('').units, 0);
    });
  });

  // ===========================================================================
  // PROTOCOL
  // ===========================================================================

  group('TomFieldMappedSmsProtocol', () {
    final submission = TomSmsSubmission(
      messageId: 's1',
      to: '+41791234567',
      from: 'TOMTEST',
      text: 'hello',
      segmentation: TomSmsSegmentation.of('hello'),
    );

    test('encodes a form body under the configured field names', () {
      final request = _protocol().encode(submission, _settings());
      expect(request.fields, {
        'to': '+41791234567',
        'from': 'TOMTEST',
        'body': 'hello',
      });
      expect(request.body, isNull);
      expect(request.url, _settings().endpoint);
      expect(request.method, 'POST');
    });

    test('encodes a JSON body when the gateway wants one', () {
      final protocol = TomFieldMappedSmsProtocol(
        format: TomSmsBodyFormat.json,
        toField: 'recipient',
        textField: 'message',
        extraFields: const {'route': 'transactional'},
      );
      final request = protocol.encode(submission, _settings());
      expect(request.fields, isNull);
      expect(jsonDecode(request.body!), {
        'route': 'transactional',
        'recipient': '+41791234567',
        'from': 'TOMTEST',
        'message': 'hello',
      });
      expect(request.headers['Content-Type'], startsWith('application/json'));
    });

    test('places the credential in the payload when so configured', () {
      // Some gateways take the key as a field rather than a header. That must
      // not require a second protocol class.
      final protocol = TomFieldMappedSmsProtocol(apiKeyField: 'api_key');
      final request = protocol.encode(
        submission,
        _settings(authScheme: TomSmsAuthScheme.none),
      );
      expect(request.fields!['api_key'], 'key-123');
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('a bearer credential becomes an Authorization header', () {
      final request = _protocol().encode(submission, _settings());
      expect(request.headers['Authorization'], 'Bearer key-123');
    });

    test('a basic credential is the key and secret, base64 encoded', () {
      final request = _protocol().encode(
        submission,
        _settings(authScheme: TomSmsAuthScheme.basic),
      );
      expect(
        request.headers['Authorization'],
        'Basic ${base64.encode(utf8.encode('key-123:secret-456'))}',
      );
    });

    test('lifts the remote id out of an accepted answer', () {
      final answer = _protocol().decode(
        201,
        '{"sid":"SM123","status":"queued"}',
      );
      expect(answer.isAccepted, isTrue);
      expect(answer.remoteId, 'SM123');
    });

    test('a 200 carrying a known permanent code is permanent', () {
      // The case the HTTP status cannot express: the gateway accepted the
      // request and refused the message.
      final answer = _protocol().decode(
        200,
        '{"status":"failed","code":21211,"message":"Invalid To number"}',
      );
      expect(answer.isAccepted, isFalse);
      expect(answer.isPermanent, isTrue);
      expect(answer.providerCode, '21211');
      expect(answer.detail, contains('Invalid To number'));
    });

    test('a known transient code is transient', () {
      final answer = _protocol().decode(
        200,
        '{"status":"failed","code":20429,"message":"Too many requests"}',
      );
      expect(answer.isPermanent, isFalse);
    });

    test('an unknown code defers to the HTTP status rather than guessing', () {
      final answer = _protocol().decode(
        200,
        '{"status":"failed","code":99999,"message":"Who knows"}',
      );
      expect(answer.isAccepted, isFalse);
      expect(answer.isPermanent, isNull);
    });

    test('an unparseable body is not accepted', () {
      final answer = _protocol().decode(200, '<html>maintenance</html>');
      expect(answer.isAccepted, isFalse);
      expect(answer.isPermanent, isNull);
    });

    test('reads a nested path', () {
      final protocol = TomFieldMappedSmsProtocol(
        statusPath: 'result.state',
        acceptedStatuses: const {'ok'},
        remoteIdPath: 'result.id',
      );
      final answer = protocol.decode(
        200,
        '{"result":{"state":"ok","id":"abc"}}',
      );
      expect(answer.isAccepted, isTrue);
      expect(answer.remoteId, 'abc');
    });

    test('with no status path configured, the HTTP status decides', () {
      final protocol = TomFieldMappedSmsProtocol(remoteIdPath: 'id');
      expect(protocol.decode(200, '{"id":"x"}').isAccepted, isTrue);
      expect(protocol.decode(400, '{"id":"x"}').isAccepted, isFalse);
    });
  });

  // ===========================================================================
  // TRANSPORT
  // ===========================================================================

  group('TomSmsTransport', () {
    test('serves the sms channel and neither copies nor attachments', () {
      final t = _transport((_) async => _answer('{"status":"queued"}'));
      expect(t.transport.channel, TomMessageChannel.sms);
      // Not overridden, and that is the assertion: the base defaults are
      // already the right answer for SMS.
      expect(t.transport.supportsCopies, isFalse);
      expect(t.transport.supportsAttachments, isFalse);
    });

    test('sends the text part even when its media type is capitalised', () async {
      // `send` picks `textBody ?? preferredBody`, and bodies are ordered
      // least-preferred first — so when the plain-text part is not recognised,
      // the fallback is the *HTML* one and the subscriber receives markup in a
      // text message. That made the case-sensitive plain-text match a delivery
      // defect rather than a null getter: nothing throws, nothing logs, and the
      // SMS goes out wrong.
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      final message = TomMessage(
        id: 's1',
        channel: TomMessageChannel.sms,
        recipients: [TomRecipient('+41791234567')],
        bodies: const [
          TomMessageBody('Text/Plain', 'Your code is 123456.'),
          TomMessageBody('Text/HTML', '<p>Your code is <b>123456</b>.</p>'),
        ],
      );

      await t.transport.send(message);

      final sent = t.gateway.bodies.single;
      expect(sent, contains(Uri.encodeQueryComponent('Your code is 123456.')));
      expect(sent, isNot(contains('%3Cp%3E')));
    });

    test('a copied recipient is refused permanently', () async {
      final t = _transport((_) async => _answer('{"status":"queued"}'));
      final message = TomMessage(
        channel: TomMessageChannel.sms,
        recipients: [
          TomRecipient('+41791234567'),
          TomRecipient('+41799999999', kind: TomRecipientKind.cc),
        ],
        bodies: const [TomMessageBody.text('hi')],
      );
      await expectLater(
        t.transport.send(message),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test('an accepted answer becomes a delivered receipt', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM99","status":"queued"}'),
      );
      final receipt = await t.transport.send(_sms());

      expect(receipt.outcome, TomDeliveryOutcome.delivered);
      expect(receipt.isDelivered, isTrue);
      expect(receipt.remoteId, 'SM99');
      expect(receipt.messageId, 's1');
      expect(receipt.rejectedRecipients, isEmpty);
      expect(t.gateway.requests, hasLength(1));
      expect(t.gateway.bodies.single, contains('%2B41791234567'));
      expect(t.gateway.bodies.single, contains('TOMTEST'));
    });

    test('never presents the caller bearer token to the gateway', () async {
      // The kernel call layer injects the *caller's* token by default. A
      // gateway has no idea what that is, and sending it leaks a user
      // credential to a third party.
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      await t.transport.send(_sms());
      expect(
        t.gateway.requests.single.headers['Authorization'],
        'Bearer key-123',
      );
    });

    test('one request per recipient', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      await t.transport.send(
        _sms(to: ['+41791111111', '+41792222222', '+41793333333']),
      );
      expect(t.gateway.requests, hasLength(3));
    });

    test('the message may name its own sender id in metadata', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      await t.transport.send(
        _sms(metadata: {TomSmsTransport.senderIdMetadataKey: 'PERTENANT'}),
      );
      expect(t.gateway.bodies.single, contains('PERTENANT'));
    });

    test('a 429 is transient: the gateway is asking for later', () async {
      final t = _transport((_) async => _answer('{}', status: 429));
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('a 503 is transient', () async {
      final t = _transport((_) async => _answer('{}', status: 503));
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('a 408 is transient, not a client mistake', () async {
      final t = _transport((_) async => _answer('{}', status: 408));
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('a 401 is permanent: no retry produces a credential', () async {
      final t = _transport((_) async => _answer('{}', status: 401));
      await expectLater(
        t.transport.send(_sms()),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test('a provider failure code on a 200 is permanent', () async {
      final t = _transport(
        (_) async => _answer('{"status":"failed","code":21211}'),
      );
      await expectLater(
        t.transport.send(_sms()),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test('a provider transient code on a 200 is transient', () async {
      final t = _transport(
        (_) async => _answer('{"status":"failed","code":20429}'),
      );
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('an unreachable gateway is transient', () async {
      final t = _transport((_) async => throw const SocketFailure());
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('one dead number is reported, not thrown', () async {
      // The same rule SMTP applies to a rejected `RCPT TO`: one bad address in
      // a list must not cost the others their message.
      var call = 0;
      final t = _transport((_) async {
        call++;
        return call == 2
            ? _answer('{"status":"failed","code":21211}')
            : _answer('{"sid":"SM$call","status":"queued"}');
      });

      final receipt = await t.transport.send(
        _sms(to: ['+41791111111', '+41792222222', '+41793333333']),
      );
      expect(receipt.isDelivered, isTrue);
      expect(receipt.isPartial, isTrue);
      expect(receipt.rejectedRecipients, ['+41792222222']);
    });

    test('every number rejected is a permanent failure', () async {
      final t = _transport(
        (_) async => _answer('{"status":"failed","code":21211}'),
      );
      await expectLater(
        t.transport.send(_sms(to: ['+41791111111', '+41792222222'])),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test(
      'a transient answer stops the pass rather than partially sending',
      () async {
        // A rate limit applies to the account, not the number: continuing down
        // the list would burn the rest of the recipients on the same refusal,
        // and the retry would then send the first ones twice.
        var call = 0;
        final t = _transport((_) async {
          call++;
          return call == 2
              ? _answer('{}', status: 429)
              : _answer('{"sid":"SM$call","status":"queued"}');
        });
        await expectLater(
          t.transport.send(_sms(to: ['+4179111', '+4179222', '+4179333'])),
          throwsA(isA<TomDeliveryException>()),
        );
        expect(t.gateway.requests, hasLength(2));
      },
    );

    test('a message over the segment cap never reaches the gateway', () async {
      // Permanent by construction: the text is not going to get shorter on a
      // retry, and a 12-segment SMS is a billing incident.
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
        settings: _settings(maxSegments: 2),
      );
      await expectLater(
        t.transport.send(_sms(text: 'a' * 400)),
        throwsA(isA<TomPermanentFailure>()),
      );
      expect(t.gateway.requests, isEmpty);
    });

    test('a zero cap means no cap', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
        settings: _settings(maxSegments: 0),
      );
      final receipt = await t.transport.send(_sms(text: 'a' * 1000));
      expect(receipt.isDelivered, isTrue);
    });

    test('a message with no text is permanent, not an empty SMS', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      final message = TomMessage(
        channel: TomMessageChannel.sms,
        recipients: [TomRecipient('+41791234567')],
      );
      await expectLater(
        t.transport.send(message),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test('no sender id anywhere is permanent, not a doomed retry', () async {
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
        settings: _settings(senderId: null),
        protocol: TomFieldMappedSmsProtocol(
          fromField: 'from',
          requiresSender: true,
        ),
      );
      await expectLater(
        t.transport.send(_sms()),
        throwsA(isA<TomPermanentFailure>()),
      );
    });

    test('a gateway that never answers is transient', () async {
      final t = _transport(
        (_) => Completer<StreamedResponse>().future,
        settings: TomSmsGatewaySettings(
          endpoint: Uri.parse('https://gateway.example.com/v1/messages'),
          apiKey: 'key-123',
          senderId: 'TOMTEST',
          timeout: const Duration(milliseconds: 20),
        ),
      );
      await expectLater(
        t.transport.send(_sms()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // SETTINGS
  // ===========================================================================

  group('TomSmsGatewaySettings', () {
    test('never prints the credential', () {
      final text = _settings().toString();
      expect(text, contains('gateway.example.com'));
      expect(text, isNot(contains('key-123')));
      expect(text, isNot(contains('secret-456')));
    });

    test('an unset endpoint is how a deployment says "no SMS"', () {
      final configuration = _Configuration();
      expect(TomSmsGatewaySettings.fromConfiguration(configuration), isNull);
    });

    test('reads the sms fields off the configuration', () {
      final configuration = _Configuration()
        ..smsEndpoint = 'https://gateway.example.com/send'
        ..smsApiKey = 'k'
        ..smsApiSecret = 's'
        ..smsSenderId = 'TOM'
        ..smsAuthScheme = 'basic'
        ..smsMaxSegments = 5;
      final settings = TomSmsGatewaySettings.fromConfiguration(configuration)!;
      expect(settings.endpoint.host, 'gateway.example.com');
      expect(settings.apiKey, 'k');
      expect(settings.senderId, 'TOM');
      expect(settings.authScheme, TomSmsAuthScheme.basic);
      expect(settings.maxSegments, 5);
    });

    test('an unrecognised auth scheme falls back to bearer', () {
      final configuration = _Configuration()
        ..smsEndpoint = 'https://gateway.example.com/send'
        ..smsAuthScheme = 'sorcery';
      expect(
        TomSmsGatewaySettings.fromConfiguration(configuration)!.authScheme,
        TomSmsAuthScheme.bearer,
      );
    });

    test('an unparseable endpoint fails at startup, naming the setting', () {
      final configuration = _Configuration()..smsEndpoint = ':::not a url';
      expect(
        () => TomSmsGatewaySettings.fromConfiguration(configuration),
        throwsA(isA<TomMessagingException>()),
      );
    });
  });

  // ===========================================================================
  // THE SEAM: ONE OUTBOX, ONE RETRY BUDGET, TWO CHANNELS
  // ===========================================================================

  group('the path a vendor mapping is written in', () {
    // The reader both vendor mappings share. It grew a numeric segment because
    // almost every gateway wraps its answer in a list — Vonage, MessageBird,
    // Infobip, Plivo, ClickSend all answer per recipient — and a map-only
    // reader could not express any of them. Twilio is the outlier, and Twilio
    // is the shape this suite's own fixture was written against, which is why
    // the limitation survived as long as it did.

    test('a map key reads a map', () {
      expect(tomVendorValueAt({'status': 'queued'}, 'status'), 'queued');
      expect(
        tomVendorValueAt({
          'a': {'b': 'c'},
        }, 'a.b'),
        'c',
      );
    });

    test('a numeric segment indexes a list', () {
      // Vonage's shape, which has no path to `status` that does not pass
      // through a list.
      final answer = {
        'messages': [
          {'message-id': 'ID1', 'status': '0'},
        ],
      };
      expect(tomVendorValueAt(answer, 'messages.0.status'), '0');
      expect(tomVendorValueAt(answer, 'messages.0.message-id'), 'ID1');
    });

    test('an index past the end is null, not a crash', () {
      // A path is configuration describing someone else's payload. A gateway
      // that answered with fewer entries than the mapping expects must produce
      // an unclassifiable answer rather than an exception from inside a decode.
      expect(tomVendorValueAt({'m': <Object?>[]}, 'm.0.status'), isNull);
      expect(
        tomVendorValueAt({
          'm': [1],
        }, 'm.3'),
        isNull,
      );
    });

    test('a segment applied to the wrong shape is null', () {
      expect(tomVendorValueAt({'a': 'text'}, 'a.b'), isNull);
      expect(tomVendorValueAt([1, 2], 'key'), isNull);
      expect(tomVendorValueAt(null, 'a'), isNull);
      expect(tomVendorValueAt({'a': 1}, null), isNull);
    });

    test('a negative index is read as a key, not as an offset', () {
      // `-1` meaning "the last entry" would be a second rule to remember for
      // no gateway that needs it, and it would make a map key of `-1`
      // unreachable. It stays a key lookup, which finds nothing in a list.
      expect(
        tomVendorValueAt({
          'm': [1, 2],
        }, 'm.-1'),
        isNull,
      );
    });

    test('the value is stringified, whatever the vendor sent', () {
      // Codes arrive as numbers from some gateways and as strings from others,
      // and the classification sets are sets of strings.
      expect(tomVendorValueAt({'code': 21211}, 'code'), '21211');
      expect(tomVendorValueAt({'ok': true}, 'ok'), 'true');
    });
  });

  group('a mapping over a list-shaped answer', () {
    // The end of the same argument, through the protocol rather than the
    // reader: a gateway that answers per recipient is now expressible.

    const vonage = TomFieldMappedSmsProtocol(
      statusPath: 'messages.0.status',
      acceptedStatuses: {'0'},
      remoteIdPath: 'messages.0.message-id',
      errorCodePath: 'messages.0.status',
      permanentErrorCodes: {'6'},
      transientErrorCodes: {'1'},
    );

    test('reads the accepted answer out of the list', () {
      final answer = vonage.decode(
        200,
        '{"messages":[{"message-id":"ID1","status":"0"}]}',
      );
      expect(answer.isAccepted, isTrue);
      expect(answer.remoteId, 'ID1');
    });

    test('classifies a refusal by the code in the same place', () {
      // Vonage reports success and failure in one field, so the status path and
      // the error-code path are the same path. The mapping expresses that
      // directly rather than needing a special case.
      final answer = vonage.decode(200, '{"messages":[{"status":"1"}]}');
      expect(answer.isAccepted, isFalse);
      expect(answer.isPermanent, isFalse);
      expect(answer.providerCode, '1');
    });

    test('an answer with no entries is a refusal, not a success', () {
      expect(vonage.decode(200, '{"messages":[]}').isAccepted, isFalse);
    });
  });

  group('an SMS on the outbox', () {
    late _FakeClock clock;
    late TomMessageOutbox outbox;

    TomMessageOutbox outboxOver(TomMessageTransport transport) {
      clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      return TomMessageOutbox(
        router: TomMessageRouter([transport]),
        clock: clock.call,
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 3,
          initialBackoff: Duration(minutes: 1),
          jitter: 0,
        ),
      );
    }

    test('a transient gateway answer is retried and then succeeds', () async {
      var call = 0;
      final t = _transport((_) async {
        call++;
        return call == 1
            ? _answer('{}', status: 429)
            : _answer('{"sid":"SM1","status":"queued"}');
      });
      outbox = outboxOver(t.transport);
      addTearDown(outbox.close);

      await outbox.sendNow(_sms());
      expect(call, 1);

      clock.advance(const Duration(minutes: 2));
      await outbox.tick();

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.succeeded);
      expect(run.attempt, 2);
    });

    test('a permanent gateway answer burns no retry', () async {
      var call = 0;
      final t = _transport((_) async {
        call++;
        return _answer('{"status":"failed","code":21211}');
      });
      outbox = outboxOver(t.transport);
      addTearDown(outbox.close);

      await outbox.sendNow(_sms());

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.failed);
      expect(run.attempt, 1);
      expect(call, 1);
    });

    test('an SMS and an email share one router and one queue', () async {
      // The point of the whole exercise: two channels, one delivery mechanism.
      final t = _transport(
        (_) async => _answer('{"sid":"SM1","status":"queued"}'),
      );
      final mail = TomMemoryMessageTransport();
      clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      final shared = TomMessageOutbox(
        router: TomMessageRouter([mail, t.transport]),
        clock: clock.call,
      );
      addTearDown(shared.close);

      await shared.sendNow(
        TomMessage.email(
          to: [TomRecipient('erin@example.com')],
          subject: 'hi',
          text: 'hi',
        ),
      );
      await shared.sendNow(_sms());

      expect(mail.count, 1);
      expect(t.gateway.requests, hasLength(1));
      final runs = await shared.store.all();
      expect(runs, hasLength(2));
      expect(runs.every((r) => r.state == TomJobRunState.succeeded), isTrue);
    });
  });
}

/// Stands in for a socket-level failure without needing a socket.
class SocketFailure implements Exception {
  const SocketFailure();

  @override
  String toString() => 'connection refused';
}

/// A minimal concrete configuration.
///
/// [TomBaseServerConfiguration] is abstract and normally filled by generated
/// reflection; these tests only need the `sms*` field values, so the base
/// constructor's source-merging is bypassed entirely.
class _Configuration extends TomBaseServerConfiguration {
  _Configuration() : super(const []);

  @override
  void setValues(Map<String, Object?> values) {}
}
