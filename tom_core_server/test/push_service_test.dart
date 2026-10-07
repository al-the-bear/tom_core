import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The templating layer above the push transport — the email and SMS rule on a
/// third channel, with its own `title` and `body` sub-keys.

class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;
}

TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'push': {
        'task_assigned': {'title': 'New task', 'body': '{task} is yours.'},
        'untitled': {'body': 'No title here.'},
      },
    },
    'de': {
      'push': {
        'task_assigned': {
          'title': 'Neue Aufgabe',
          'body': '{task} gehört Ihnen.',
        },
      },
    },
  },
);

void main() {
  late TomMemoryMessageTransport transport;
  late TomMessageOutbox outbox;
  late TomPushService service;

  setUp(() {
    transport = TomMemoryMessageTransport(channel: TomMessageChannel.push);
    outbox = TomMessageOutbox(
      router: TomMessageRouter([transport]),
      clock: _FakeClock(DateTime.utc(2026, 10, 7, 10)).call,
    );
    addTearDown(outbox.close);
    service = TomPushService(outbox: outbox, texts: _texts());
  });

  TomPushRequest assigned({
    String templateKey = 'push.task_assigned',
    TomTextLocale? locale,
  }) => TomPushRequest(
    templateKey: templateKey,
    to: [TomRecipient('device-a'), TomRecipient('device-b')],
    locale: locale,
    parameters: {'task': 'Alpha'},
    data: {'taskId': '42'},
    messageId: 'push-42',
  );

  group('TomPushService.render', () {
    test('renders title and body from resource keys, on the push channel', () {
      final message = service.render(assigned());
      expect(message.id, 'push-42');
      expect(message.channel, TomMessageChannel.push);
      expect(message.subject, 'New task');
      expect(message.textBody!.content, 'Alpha is yours.');
      expect(message.recipients.map((r) => r.address), [
        'device-a',
        'device-b',
      ]);
      expect(message.metadata[TomPushTransport.dataMetadataKey], {
        'taskId': '42',
      });
    });

    test('renders in the requested locale', () {
      final message = service.render(assigned(locale: TomTextLocale('de')));
      expect(message.subject, 'Neue Aufgabe');
      expect(message.textBody!.content, 'Alpha gehört Ihnen.');
    });

    test('a missing title fails at render, naming the key', () {
      expect(
        () => service.render(assigned(templateKey: 'push.untitled')),
        throwsA(
          isA<TomMessagingException>()
              .having((e) => e.key, 'key', 'messaging.push.template.missing')
              .having(
                (e) => e.parameters?['resourceKey'],
                'resourceKey',
                'push.untitled.title',
              ),
        ),
      );
    });
  });

  group('TomPushService.send', () {
    test(
      'queues the rendered notification and the outbox delivers it',
      () async {
        await service.sendNow(assigned());
        expect(transport.last!.subject, 'New task');
      },
    );
  });

  group('TomPushRequest', () {
    test('refuses a blank template key', () {
      expect(
        () => TomPushRequest(templateKey: ' ', to: [TomRecipient('d')]),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.key,
            'key',
            'messaging.push.template.empty',
          ),
        ),
      );
    });

    test('refuses an empty token list', () {
      expect(
        () => TomPushRequest(templateKey: 'push.x', to: const []),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.key,
            'key',
            'messaging.push.recipients.empty',
          ),
        ),
      );
    });
  });

  group('TomPushService', () {
    test('is its own subclass of the shared base, named push', () {
      expect(service, isA<TomTemplatedMessageService<TomPushRequest>>());
      expect(service, isNot(isA<TomEmailService>()));
      expect(service, isNot(isA<TomSmsService>()));
      expect(service.channelName, 'push');
    });

    test('resolve returns null when no service was installed', () {
      expect(TomPushService.resolve(), isNull);
    });
  });
}
