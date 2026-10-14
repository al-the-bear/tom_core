import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The templating layer above the SMS transport.
///
/// The same rule the email service enforces — **a message is a template key
/// plus parameters** — applied to a second channel, which is the only way to
/// find out whether the rule was general or merely email-shaped. The one thing
/// that is genuinely different lives here too: an SMS has a *length*, and the
/// moment to hear about a twelve-segment message is at send, not on the
/// invoice.

// =============================================================================
// FIXTURES
// =============================================================================

class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;
}

/// A two-locale bundle set, deliberately partially translated.
TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'sms': {
        'two_factor': {
          'text': 'Your code is {code}. It expires in {minutes}m.',
        },
        'welcome': {'text': 'Welcome aboard, {firstname}.'},
        'long': {'text': 'x' * 400},
        'overdue': {'text': 'You have {count} overdue tasks.'},
      },
    },
    'de': {
      'sms': {
        'two_factor': {'text': 'Ihr Code lautet {code}. Gültig {minutes}m.'},
      },
    },
  },
);

TomPrincipal _principal({
  String? mobile = '+41791234567',
  String? phone,
  String? language,
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(
    id: '7',
    username: 'erin',
    firstname: 'Erin',
    lastname: 'Muster',
    mobile: mobile,
    phone: phone,
  ),
  language: language,
);

void main() {
  late TomMemoryMessageTransport transport;
  late TomMessageOutbox outbox;
  late TomSmsService service;

  setUp(() {
    final clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
    transport = TomMemoryMessageTransport(channel: TomMessageChannel.sms);
    outbox = TomMessageOutbox(
      router: TomMessageRouter([transport]),
      clock: clock.call,
    );
    addTearDown(outbox.close);
    service = TomSmsService(outbox: outbox, texts: _texts());
  });

  TomSmsRequest code({
    TomTextLocale? locale,
    String templateKey = 'sms.two_factor',
    String? messageId,
  }) => TomSmsRequest(
    templateKey: templateKey,
    to: [TomRecipient('+41791234567')],
    locale: locale,
    parameters: {'code': '123456', 'minutes': 5},
    messageId: messageId,
  );

  // ===========================================================================
  // RENDERING
  // ===========================================================================

  group('TomSmsService.render', () {
    test('builds the text from a resource key, on the sms channel', () {
      final message = service.render(code());
      expect(message.channel, TomMessageChannel.sms);
      expect(
        message.textBody!.content,
        'Your code is 123456. It expires in 5m.',
      );
      expect(message.subject, isNull, reason: 'an SMS has no subject');
      expect(message.bodies, hasLength(1), reason: 'and no HTML alternative');
    });

    test('renders the same key in a second locale', () {
      final german = service.render(code(locale: TomTextLocale('de')));
      expect(german.textBody!.content, 'Ihr Code lautet 123456. Gültig 5m.');
    });

    test('falls back to the default locale for an untranslated key', () {
      final message = service.render(
        code(templateKey: 'sms.welcome', locale: TomTextLocale('de')),
      );
      expect(message.textBody!.content, startsWith('Welcome aboard'));
    });

    test('a template nobody wrote fails at render, naming the key', () {
      expect(
        () => service.render(code(templateKey: 'sms.nonexistent')),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.parameters?['resourceKey'],
            'resourceKey',
            'sms.nonexistent.text',
          ),
        ),
      );
    });

    test('the sender id travels in metadata, where the transport reads it', () {
      final message = service.render(
        TomSmsRequest(
          templateKey: 'sms.two_factor',
          to: [TomRecipient('+41791234567')],
          from: 'PERTENANT',
          parameters: const {'code': '1', 'minutes': 1},
        ),
      );
      expect(
        message.metadata[TomSmsTransport.senderIdMetadataKey],
        'PERTENANT',
      );
    });

    test('there is no way to spell a literal message through this API', () {
      // The type has no `text` field. This asserts the shape rather than a
      // behaviour, which is the point: the rule is enforced by the compiler.
      expect(
        TomSmsRequest(
          templateKey: 'sms.welcome',
          to: [TomRecipient('+41791234567')],
        ).templateKey,
        'sms.welcome',
      );
    });

    test('an empty template key is refused at construction', () {
      expect(
        () => TomSmsRequest(
          templateKey: '  ',
          to: [TomRecipient('+41791234567')],
        ),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('a request with no recipient is refused at construction', () {
      expect(
        () => TomSmsRequest(templateKey: 'sms.welcome', to: const []),
        throwsA(isA<TomMessagingException>()),
      );
    });
  });

  // ===========================================================================
  // SEGMENTATION — THE CONCERN SMS HAS AND EMAIL DOES NOT
  // ===========================================================================

  group('segment budget', () {
    test('a rendered message reports its segmentation', () {
      expect(service.segmentationOf(code()).segments, 1);
      expect(service.segmentationOf(code(templateKey: 'sms.long')).segments, 3);
    });

    test('over the cap fails at render, before anything is queued', () async {
      final capped = TomSmsService(
        outbox: outbox,
        texts: _texts(),
        maxSegments: 2,
      );
      expect(
        () => capped.render(code(templateKey: 'sms.long')),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.parameters?['segments'],
            'segments',
            3,
          ),
        ),
      );
      expect(await outbox.store.all(), isEmpty);
    });

    test('exactly at the cap is allowed', () {
      final capped = TomSmsService(
        outbox: outbox,
        texts: _texts(),
        maxSegments: 3,
      );
      expect(capped.render(code(templateKey: 'sms.long')).textBody, isNotNull);
    });

    test('no cap by default: the transport still holds the deployment one', () {
      expect(service.maxSegments, isNull);
      expect(service.render(code(templateKey: 'sms.long')).textBody, isNotNull);
    });
  });

  // ===========================================================================
  // ADDRESSING A PRINCIPAL
  // ===========================================================================

  group('TomSmsRequest.toPrincipal', () {
    test('prefers the mobile number', () {
      final request = TomSmsRequest.toPrincipal(
        templateKey: 'sms.welcome',
        principal: _principal(mobile: '+41791111111', phone: '+41442222222'),
      );
      expect(request.to.single.address, '+41791111111');
    });

    test('falls back to the phone number when there is no mobile', () {
      final request = TomSmsRequest.toPrincipal(
        templateKey: 'sms.welcome',
        principal: _principal(mobile: null, phone: '+41442222222'),
      );
      expect(request.to.single.address, '+41442222222');
    });

    test('takes the locale from the principal', () {
      final request = TomSmsRequest.toPrincipal(
        templateKey: 'sms.two_factor',
        principal: _principal(language: 'de'),
      );
      expect(request.locale!.language, 'de');
    });

    test('a principal reachable by neither raises at composition', () {
      // Here, where the caller still knows *which user* it was reaching. A
      // transport discovering it later can only say a number was empty.
      expect(
        () => TomSmsRequest.toPrincipal(
          templateKey: 'sms.welcome',
          principal: _principal(mobile: null),
        ),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.parameters?['username'],
            'username',
            'erin',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // THE QUEUE
  // ===========================================================================

  group('sending', () {
    test('send queues rather than delivering inline', () async {
      await service.send(code());
      expect(transport.count, 0);
      await outbox.tick();
      expect(transport.count, 1);
      expect(
        transport.sent.single.textBody!.content,
        startsWith('Your code is 123456'),
      );
    });

    test('sendNow delivers without waiting for a tick', () async {
      await service.sendNow(code());
      expect(transport.count, 1);
    });

    test('the message id is the idempotence key', () async {
      await service.send(code(messageId: 'reset-42'));
      await service.send(code(messageId: 'reset-42'));
      expect(await outbox.store.all(), hasLength(1));
    });

    test(
      'a template fault arrives as a failed future, not a sync throw',
      () async {
        await expectLater(
          service.send(code(templateKey: 'sms.nonexistent')),
          throwsA(isA<TomMessagingException>()),
        );
      },
    );
  });

  // ===========================================================================
  // THE SHARED BASE
  // ===========================================================================

  group('the templated-message base', () {
    test('resolves a conditional fragment through requiredText', () {
      // The same escape hatch the email service exposes, inherited rather than
      // reimplemented: a sentence a message includes only sometimes is its own
      // resource key, resolved fully before insertion.
      expect(
        service.requiredText(
          'sms.overdue',
          TomSmsService.textSubKey,
          parameters: const {'count': 3},
        ),
        'You have 3 overdue tasks.',
      );
    });

    test('a missing fragment fails the same way a missing template does', () {
      expect(
        () => service.requiredText('sms.nope', TomSmsService.textSubKey),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('both services are the same kind of thing', () {
      final email = TomEmailService(outbox: outbox, texts: _texts());
      expect(service, isA<TomTemplatedMessageService<TomSmsRequest>>());
      expect(email, isA<TomTemplatedMessageService<TomEmailRequest>>());
      expect(service.channelName, 'sms');
      expect(email.channelName, 'email');
    });

    test('resolve returns null when no service was installed', () {
      expect(TomSmsService.resolve(), isNull);
    });
  });
}
