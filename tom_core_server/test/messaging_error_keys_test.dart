/// Pins every error key the messaging layer raises.
///
/// An error key is a contract: callers branch on it, translations are looked
/// up by it, and operators grep logs for it. A key that no test names is a
/// failure mode nobody checks — it can be renamed, misspelled or made
/// unreachable and every suite stays green. Each case here drives the smallest
/// real input that reaches one raise site and asserts the thrown exception
/// carries that exact key literal; asserting the exception type alone would
/// let the key drift unnoticed.
///
/// Nothing here needs a database or the network: the raise sites are
/// constructor guards, a closed in-memory outbox, and the SMS render-time
/// segment cap, all of which fail before any transport is touched.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Matches a [TomMessagingException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomMessagingException>().having((e) => e.key, 'key', key));

TomPrincipal _principal({String? email, String? mobile, String? phone}) =>
    TomPrincipal(
      authenticated: true,
      user: TomUser(
        id: '7',
        username: 'erin',
        firstname: 'Erin',
        lastname: 'Muster',
        email: email,
        mobile: mobile,
        phone: phone,
      ),
    );

/// One synchronous raise site: the key and the input that reaches it.
class _Case {
  final String key;
  final String reach;
  final void Function() trigger;

  const _Case(this.key, this.reach, this.trigger);
}

final List<_Case> _constructorCases = [
  _Case(
    'messaging.recipient.empty',
    'a recipient with a blank address',
    () => TomRecipient('   '),
  ),
  _Case(
    'messaging.attachment.unnamed',
    'an attachment with a blank file name',
    () => TomAttachment(fileName: ' ', bytes: Uint8List.fromList([1, 2, 3])),
  ),
  _Case(
    'messaging.message.unaddressed',
    'a message with no recipients',
    () => TomMessage(recipients: const []),
  ),
  _Case(
    'messaging.email.template.empty',
    'an email request with a blank template key',
    () => TomEmailRequest(templateKey: ' ', to: [TomRecipient('a@b.example')]),
  ),
  _Case(
    'messaging.email.recipients.empty',
    'an email request with no recipients',
    () => TomEmailRequest(templateKey: 'mail.welcome', to: const []),
  ),
  _Case(
    'messaging.email.principal.no_address',
    'an email addressed to a principal without an email address',
    () => TomEmailRequest.toPrincipal(
      templateKey: 'mail.welcome',
      principal: _principal(email: '  '),
    ),
  ),
  _Case(
    'messaging.sms.template.empty',
    'an SMS request with a blank template key',
    () => TomSmsRequest(templateKey: '', to: [TomRecipient('+41791234567')]),
  ),
  _Case(
    'messaging.sms.recipients.empty',
    'an SMS request with no recipients',
    () => TomSmsRequest(templateKey: 'sms.two_factor', to: const []),
  ),
  _Case(
    'messaging.sms.principal.no_number',
    'an SMS addressed to a principal with neither mobile nor phone',
    () => TomSmsRequest.toPrincipal(
      templateKey: 'sms.two_factor',
      principal: _principal(mobile: ' ', phone: null),
    ),
  ),
  _Case(
    'messaging.sms.bad_endpoint',
    'gateway settings with a non-http endpoint',
    () => TomSmsGatewaySettings(endpoint: Uri.parse('ftp://sms.example/send')),
  ),
  _Case(
    'messaging.sms.incomplete_credential',
    'basic auth with an API key but no secret',
    () => TomSmsGatewaySettings(
      endpoint: Uri.parse('https://sms.example/send'),
      authScheme: TomSmsAuthScheme.basic,
      apiKey: 'key',
    ),
  ),
  _Case(
    'messaging.smtp.no_host',
    'SMTP settings with a blank host',
    () => TomSmtpSettings(host: ' '),
  ),
  _Case(
    'messaging.smtp.no_password',
    'SMTP settings with a username but an empty password',
    () =>
        TomSmtpSettings(host: 'mail.example', username: 'mailer', password: ''),
  ),
  _Case(
    'messaging.webhook.bad_detail_cap',
    'webhook settings with a negative detail cap',
    () => TomWebhookSettings(maxDetailChars: -1),
  ),
];

void main() {
  group('messaging error keys — construction guards', () {
    for (final c in _constructorCases) {
      test('${c.key}: ${c.reach}', () {
        expect(c.trigger, _throwsKey(c.key));
      });
    }
  });

  group('messaging error keys — runtime', () {
    late TomMessageOutbox outbox;

    setUp(() {
      outbox = TomMessageOutbox(
        router: TomMessageRouter([
          TomMemoryMessageTransport(channel: TomMessageChannel.sms),
        ]),
      );
      addTearDown(outbox.close);
    });

    test('messaging.outbox.closed: sending on a closed outbox', () async {
      await outbox.close();
      await expectLater(
        outbox.send(
          TomMessage.sms(to: [TomRecipient('+41791234567')], text: 'hi'),
        ),
        _throwsKey('messaging.outbox.closed'),
      );
    });

    test('messaging.sms.too_long: a render over the service segment cap', () {
      final service = TomSmsService(
        outbox: outbox,
        texts: TomLocalizedTextResources(
          defaultLocale: TomTextLocale('en'),
          bundles: {
            'en': {
              'sms': {
                'long': {'text': 'x' * 400},
              },
            },
          },
        ),
        maxSegments: 1,
      );
      expect(
        () => service.render(
          TomSmsRequest(
            templateKey: 'sms.long',
            to: [TomRecipient('+41791234567')],
          ),
        ),
        _throwsKey('messaging.sms.too_long'),
      );
    });
  });
}
