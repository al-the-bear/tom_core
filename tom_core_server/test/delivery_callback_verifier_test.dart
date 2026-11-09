/// The verifiers that gate the delivery-report endpoint: the shared secret,
/// Twilio's `X-Twilio-Signature` and Vonage's `sig`, each checked against the
/// vendor's own published vectors, refusing a tampered request, and accepted
/// end to end by the endpoint.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// Twilio's worked example (twilio.com/docs/usage/security).
const _twilioToken = '12345';
const _twilioUrl = 'https://example.com/myapp.php?foo=1&bar=2';
const _twilioParameters = {
  'CallSid': 'CA1234567890ABCDE',
  'Caller': '+14158675310',
  'Digits': '1234',
  'From': '+14158675310',
  'To': '+18005551212',
};
const _twilioSignature = 'L/OH5YylLD5NRKLltdqwSvS0BnU=';

/// The vectors of Vonage's own client library (vonage-ruby-sdk,
/// test/vonage/signature_test.rb).
const _vonageSecret = 'my_secret_key_for_testing';
const _vonageParameters = {
  'message-timestamp': '2013-11-21 15:27:30',
  'messageId': '020000001B0FE827',
  'msisdn': '14843472194',
  'text': 'Test again',
  'timestamp': '1385047698',
  'to': '13239877404',
  'type': 'text',
};
const _vonageSignatures = {
  TomVonageSignatureMethod.md5hash: 'd2e7b1dc968737c5998ad624e02f90b7',
  TomVonageSignatureMethod.md5: 'DDEBD46008C2D4E93CCE578A332A52D5',
  TomVonageSignatureMethod.sha1: '27D0D05C2876C7CB1720DBCDBA4D492E1E55C09A',
  TomVonageSignatureMethod.sha256:
      'DDB8397C2B90AAC7F3882D306475C9A5058C92322EEF43C92B298B6E0FC0D330',
  TomVonageSignatureMethod.sha512:
      'E0D3C650F8C9D1A5C174D10DDDBFB003E561F59B265616208B0487C5D819481CD3C311D59CF6165ECD1139622D5BA3A256C0D763AC4A9AD9144B5A426B94FE82',
};
final _vonageSignedAt = DateTime.fromMillisecondsSinceEpoch(
  1385047698 * 1000,
  isUtc: true,
);

TomDeliveryCallbackRequest _form(
  String url,
  Map<String, String> fields, {
  Map<String, String> headers = const {},
}) => TomDeliveryCallbackRequest(
  method: 'POST',
  url: Uri.parse(url),
  headers: {'content-type': 'application/x-www-form-urlencoded', ...headers},
  body: Uri(queryParameters: fields).query,
  parameters: {...Uri.parse(url).queryParameters, ...fields},
);

TomDeliveryCallbackRequest _query(Map<String, String> parameters) =>
    TomDeliveryCallbackRequest(
      method: 'GET',
      url: Uri.parse(
        'https://example.com/messaging/delivery-report',
      ).replace(queryParameters: parameters),
      parameters: parameters,
    );

void main() {
  group('the shared secret', () {
    test('DV-1: the header holding the secret passes; any other value, a '
        'prefix, or no header does not', () {
      final verifier = TomSharedSecretCallbackVerifier('shared-secret');
      TomDeliveryCallbackRequest withSecret(String? secret) =>
          TomDeliveryCallbackRequest(
            method: 'POST',
            url: Uri.parse('https://example.com/'),
            headers: {
              if (secret != null)
                TomSharedSecretCallbackVerifier.defaultHeader: secret,
            },
          );
      expect(verifier.verify(withSecret('shared-secret')), isTrue);
      expect(verifier.verify(withSecret('shared')), isFalse);
      expect(verifier.verify(withSecret('shared-secret-')), isFalse);
      expect(verifier.verify(withSecret(null)), isFalse);
    });
  });

  group('Twilio', () {
    test("DV-2: the signature of Twilio's worked example", () {
      expect(
        TomTwilioCallbackVerifier.signature(
          _twilioToken,
          _twilioUrl,
          _twilioParameters,
        ),
        _twilioSignature,
      );
    });

    test('DV-3: a signed form callback passes; a tampered parameter, another '
        'token or no signature does not', () {
      final verifier = TomTwilioCallbackVerifier(_twilioToken);
      final signed = {'x-twilio-signature': _twilioSignature};
      expect(
        verifier.verify(_form(_twilioUrl, _twilioParameters, headers: signed)),
        isTrue,
      );
      expect(
        verifier.verify(
          _form(_twilioUrl, {
            ..._twilioParameters,
            'Digits': '9999',
          }, headers: signed),
        ),
        isFalse,
      );
      expect(
        TomTwilioCallbackVerifier(
          '54321',
        ).verify(_form(_twilioUrl, _twilioParameters, headers: signed)),
        isFalse,
      );
      expect(verifier.verify(_form(_twilioUrl, _twilioParameters)), isFalse);
    });

    test('DV-4: behind a proxy the public URL is the one signed, and a URL is '
        'accepted signed with or without its port', () {
      final signed = {'x-twilio-signature': _twilioSignature};
      final behindProxy = _form(
        'http://app:8080/myapp.php?foo=1&bar=2',
        _twilioParameters,
        headers: signed,
      );
      expect(
        TomTwilioCallbackVerifier(_twilioToken).verify(behindProxy),
        isFalse,
      );
      expect(
        TomTwilioCallbackVerifier(
          _twilioToken,
          publicUrl: Uri.parse('https://example.com'),
        ).verify(behindProxy),
        isTrue,
      );
      final withPort = TomTwilioCallbackVerifier.signature(
        _twilioToken,
        'https://example.com:443/myapp.php?foo=1&bar=2',
        _twilioParameters,
      );
      expect(
        TomTwilioCallbackVerifier(_twilioToken).verify(
          _form(
            _twilioUrl,
            _twilioParameters,
            headers: {'x-twilio-signature': withPort},
          ),
        ),
        isTrue,
      );
    });

    test('DV-5: a JSON callback is signed over its URL, whose bodySHA256 must '
        'match the body', () {
      const body = '{"MessageSid":"SM1","MessageStatus":"delivered"}';
      final hash = sha256.convert(utf8.encode(body)).toString();
      final url = 'https://example.com/report?bodySHA256=$hash';
      final signature = TomTwilioCallbackVerifier.signature(
        _twilioToken,
        url,
        const {},
      );
      TomDeliveryCallbackRequest json(String body) =>
          TomDeliveryCallbackRequest(
            method: 'POST',
            url: Uri.parse(url),
            headers: {
              'content-type': 'application/json',
              'x-twilio-signature': signature,
            },
            body: body,
          );
      final verifier = TomTwilioCallbackVerifier(_twilioToken);
      expect(verifier.verify(json(body)), isTrue);
      expect(
        verifier.verify(json(body.replaceAll('delivered', 'failed'))),
        isFalse,
      );
    });
  });

  group('Vonage', () {
    test("DV-6: the signatures of Vonage's own vectors, for every method", () {
      for (final MapEntry(key: method, value: expected)
          in _vonageSignatures.entries) {
        expect(
          TomVonageCallbackVerifier.signature(
            _vonageSecret,
            _vonageParameters,
            method: method,
          ),
          expected,
          reason: method.name,
        );
      }
    });

    test('DV-7: a signed receipt passes within the age limit; a tampered '
        'value, a stale timestamp or no signature does not', () {
      for (final MapEntry(key: method, value: sig)
          in _vonageSignatures.entries) {
        TomVonageCallbackVerifier at(DateTime now) => TomVonageCallbackVerifier(
          _vonageSecret,
          method: method,
          clock: () => now,
        );
        final fresh = at(_vonageSignedAt.add(const Duration(minutes: 1)));
        expect(
          fresh.verify(_query({..._vonageParameters, 'sig': sig})),
          isTrue,
          reason: method.name,
        );
        expect(
          fresh.verify(
            _query({..._vonageParameters, 'text': 'Test', 'sig': sig}),
          ),
          isFalse,
          reason: method.name,
        );
        expect(
          at(
            _vonageSignedAt.add(const Duration(minutes: 6)),
          ).verify(_query({..._vonageParameters, 'sig': sig})),
          isFalse,
          reason: '${method.name}: replayed six minutes later',
        );
        expect(fresh.verify(_query(_vonageParameters)), isFalse);
      }
    });

    test('DV-8: a receipt posted as JSON is verified from its fields', () {
      final verifier = TomVonageCallbackVerifier(
        _vonageSecret,
        clock: () => _vonageSignedAt,
      );
      final body = jsonEncode({
        ..._vonageParameters,
        'sig': _vonageSignatures[TomVonageSignatureMethod.md5hash],
      });
      expect(
        verifier.verify(
          TomDeliveryCallbackRequest(
            method: 'POST',
            url: Uri.parse('https://example.com/messaging/delivery-report'),
            headers: {'content-type': 'application/json'},
            body: body,
          ),
        ),
        isTrue,
      );
    });

    test('DV-9: an empty secret is refused '
        '(messaging.delivery_report.empty_secret)', () {
      Matcher refused() => throwsA(
        isA<TomMessagingException>().having(
          (e) => e.key,
          'key',
          'messaging.delivery_report.empty_secret',
        ),
      );
      expect(() => TomVonageCallbackVerifier(''), refused());
      expect(() => TomTwilioCallbackVerifier(''), refused());
    });
  });

  group('the endpoint, end to end', () {
    tearDown(TomDeliveryReportEndpoint.reset);

    Future<TomMemoryDeliveryReportStore> store(String remoteId) async {
      final store = TomMemoryDeliveryReportStore();
      await store.remember(
        TomDeliveryCorrelation(
          remoteId: remoteId,
          messageId: 'm1',
          channel: TomMessageChannel.sms,
          sentAt: DateTime.utc(2026, 11, 6),
        ),
      );
      return store;
    }

    test('DV-10: a signed Twilio status callback, posted as a form, is '
        'recorded; a tampered one is refused', () async {
      const url = 'https://api.example.com/messaging/delivery-report';
      final fields = {
        'MessageSid': 'SM1',
        'MessageStatus': 'delivered',
        'AccountSid': 'AC1',
      };
      final reports = await store('SM1');
      TomDeliveryReportEndpoint.install(
        store: reports,
        protocol: const TomFieldMappedDeliveryReportProtocol(
          remoteIdPath: 'MessageSid',
          statusPath: 'MessageStatus',
        ),
        verifier: TomTwilioCallbackVerifier('auth-token'),
      );
      Request post(Map<String, String> fields) => Request(
        'POST',
        Uri.parse(url),
        body: Uri(queryParameters: fields).query,
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          'x-twilio-signature': TomTwilioCallbackVerifier.signature(
            'auth-token',
            url,
            {
              'MessageSid': 'SM1',
              'MessageStatus': 'delivered',
              'AccountSid': 'AC1',
            },
          ),
        },
      );
      final refused = await TomDeliveryReportEndpoint.handle(
        post({...fields, 'MessageStatus': 'failed'}),
      );
      expect(refused.statusCode, 401);
      final recorded = await TomDeliveryReportEndpoint.handle(post(fields));
      expect(recorded.statusCode, 200);
      expect(
        (await reports.messageOf('SM1'))!.state,
        TomDeliveryState.delivered,
      );
    });

    test('DV-11: a signed Vonage receipt, sent as a GET, is recorded; a '
        'replayed one is refused', () async {
      final now = DateTime.utc(2026, 11, 6, 12);
      final parameters = {
        'messageId': '0A0000000123ABCD1',
        'status': 'delivered',
        'msisdn': '447700900000',
        'timestamp': '${now.millisecondsSinceEpoch ~/ 1000}',
      };
      final sig = TomVonageCallbackVerifier.signature(
        'signature-secret',
        parameters,
        method: TomVonageSignatureMethod.sha256,
      );
      final reports = await store('0A0000000123ABCD1');
      var clock = now.add(const Duration(seconds: 20));
      TomDeliveryReportEndpoint.install(
        store: reports,
        protocol: const TomFieldMappedDeliveryReportProtocol(
          remoteIdPath: 'messageId',
          statusPath: 'status',
        ),
        verifier: TomVonageCallbackVerifier(
          'signature-secret',
          method: TomVonageSignatureMethod.sha256,
          clock: () => clock,
        ),
      );
      Request get() => Request(
        'GET',
        Uri.parse(
          'https://api.example.com/messaging/delivery-report',
        ).replace(queryParameters: {...parameters, 'sig': sig}),
      );
      final recorded = await TomDeliveryReportEndpoint.handle(get());
      expect(recorded.statusCode, 200);
      expect(
        (await reports.messageOf('0A0000000123ABCD1'))!.state,
        TomDeliveryState.delivered,
      );
      clock = now.add(const Duration(hours: 1));
      expect((await TomDeliveryReportEndpoint.handle(get())).statusCode, 401);
    });
  });

  group('through the endpoint pipeline', () {
    late Handler router;

    setUpAll(initializeReflection);
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<TomDeliveryReportServer>(TomDeliveryReportServer());
      // The router mounts every endpoint the fixture seed reflects, the
      // fixture's own API included.
      registerFixtureAccessApi();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      // The request context every endpoint reads, as the server installs it.
      router = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('delivery report', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addHandler(TomEndpointRouting().initializeRouter().call);
    });
    tearDown(() {
      TomBean.resetBeanContext();
      TomDeliveryReportEndpoint.reset();
    });

    test('DV-12: the route takes a signed Twilio form POST and a signed '
        'Vonage GET, the pipeline leaving the body to the handler', () async {
      final reports = TomMemoryDeliveryReportStore();
      for (final id in ['SM1', 'V1']) {
        await reports.remember(
          TomDeliveryCorrelation(
            remoteId: id,
            messageId: 'm-$id',
            channel: TomMessageChannel.sms,
            sentAt: DateTime.utc(2026, 11, 6),
          ),
        );
      }
      const url = 'http://localhost/messaging/delivery-report';
      const fields = {'MessageSid': 'SM1', 'MessageStatus': 'delivered'};
      TomDeliveryReportEndpoint.install(
        store: reports,
        protocol: const TomFieldMappedDeliveryReportProtocol(
          remoteIdPath: 'MessageSid',
          statusPath: 'MessageStatus',
        ),
        verifier: TomTwilioCallbackVerifier('auth-token'),
      );
      final twilio = await router(
        Request(
          'POST',
          Uri.parse(url),
          body: Uri(queryParameters: fields).query,
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            'x-twilio-signature': TomTwilioCallbackVerifier.signature(
              'auth-token',
              url,
              fields,
            ),
          },
        ),
      );
      expect(twilio.statusCode, 200, reason: await twilio.readAsString());
      expect(
        (await reports.messageOf('SM1'))!.state,
        TomDeliveryState.delivered,
      );

      final now = DateTime.now().toUtc();
      final parameters = {
        'messageId': 'V1',
        'status': 'delivered',
        'timestamp': '${now.millisecondsSinceEpoch ~/ 1000}',
      };
      TomDeliveryReportEndpoint.install(
        store: reports,
        protocol: const TomFieldMappedDeliveryReportProtocol(
          remoteIdPath: 'messageId',
          statusPath: 'status',
        ),
        verifier: TomVonageCallbackVerifier('signature-secret'),
      );
      final vonage = await router(
        Request(
          'GET',
          Uri.parse(url).replace(
            queryParameters: {
              ...parameters,
              'sig': TomVonageCallbackVerifier.signature(
                'signature-secret',
                parameters,
              ),
            },
          ),
        ),
      );
      expect(vonage.statusCode, 200, reason: await vonage.readAsString());
      expect(
        (await reports.messageOf('V1'))!.state,
        TomDeliveryState.delivered,
      );
    });
  });
}
