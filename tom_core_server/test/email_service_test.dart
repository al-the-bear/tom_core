import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/localized_texts.dart';

/// The templating layer above the message transport.
///
/// Everything here asserts the same underlying rule from a different angle:
/// **an application email is a template key plus parameters**. That means no
/// user-facing string reaches Dart, the same key renders differently per
/// recipient locale, a key nobody wrote fails at send rather than mailing a
/// blank, and the rendered message goes to the *outbox* — where retry and
/// permanence classification already live — rather than to a transport.
///
/// The bundle set and the principal are the ones `resources_test.dart` renders
/// against, from `fixtures/localized_texts.dart`. What this file asserts about
/// them is only what the *service* does with a locale; that resolving one
/// degrades key by key is the resources module's rule and is pinned there.

// =============================================================================
// FIXTURES
// =============================================================================

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;
}

void main() {
  // ===========================================================================
  // EMAIL SERVICE
  // ===========================================================================

  group('TomEmailService', () {
    late TomMemoryMessageTransport transport;
    late TomMessageOutbox outbox;
    late TomEmailService service;

    setUp(() {
      final clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      transport = TomMemoryMessageTransport();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      service = TomEmailService(outbox: outbox, texts: fixtureTexts());
    });

    TomEmailRequest reset({
      TomTextLocale? locale,
      String templateKey = 'email.password_reset',
    }) => TomEmailRequest(
      templateKey: templateKey,
      to: [TomRecipient('erin@example.com')],
      locale: locale,
      parameters: {'firstname': 'Erin', 'link': 'https://example.com/r/1'},
    );

    test('renders subject and both bodies from resource keys', () {
      final message = service.render(reset());
      expect(message.subject, 'Reset your password, Erin');
      expect(message.textBody!.content, contains('https://example.com/r/1'));
      expect(
        message.htmlBody!.content,
        contains('href="https://example.com/r/1"'),
      );
      expect(message.channel, TomMessageChannel.email);
    });

    test('the HTML alternative is offered last, as MIME expects', () {
      final message = service.render(reset());
      expect(message.bodies.map((b) => b.mediaType), [
        'text/plain',
        'text/html',
      ]);
      expect(message.preferredBody!.mediaType, 'text/html');
    });

    test('renders the same template in a second locale', () {
      final german = service.render(reset(locale: TomTextLocale('de')));
      expect(german.subject, 'Passwort zurücksetzen, Erin');
      expect(german.textBody!.content, startsWith('Öffnen Sie'));

      final english = service.render(reset(locale: TomTextLocale('en')));
      expect(english.subject, 'Reset your password, Erin');
      expect(english.textBody!.content, startsWith('Open'));
    });

    test('an absent HTML key leaves a single plain-text body', () {
      final message = service.render(reset(templateKey: 'email.welcome'));
      expect(message.bodies, hasLength(1));
      expect(message.textBody!.content, 'Glad to have you.');
      expect(message.htmlBody, isNull);
    });

    test('a template with no subject fails loudly', () {
      expect(
        () => service.render(reset(templateKey: 'email.no_subject')),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.key,
            'key',
            contains('template'),
          ),
        ),
      );
    });

    test('a template with no plain-text body fails loudly', () {
      // Mail with only an HTML part — or none at all — is a deliverability
      // problem, so the text part is required rather than merely preferred.
      expect(
        () => service.render(reset(templateKey: 'email.no_text')),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('requiredText resolves a fragment for a conditional body', () {
      // A sentence a body includes only sometimes cannot live in the body's own
      // template, so it is resolved on its own and passed in as a parameter.
      expect(
        service.requiredText(
          'email.password_reset',
          'subject',
          parameters: {'firstname': 'Ada'},
        ),
        'Reset your password, Ada',
      );
    });

    test('requiredList joins with the separators the bundle gives', () {
      // The other half of "a template has no control flow". A conditional
      // sentence is a fragment resolved separately; a list is this, and neither
      // the comma nor the conjunction is written in Dart.
      expect(
        service.requiredList(['Alpha', 'Beta', 'Gamma']),
        'Alpha, Beta and Gamma',
      );
      expect(service.requiredList(['Alpha', 'Beta']), 'Alpha and Beta');
    });

    test('requiredList joins in the recipient\'s language', () {
      // The assertion a single-locale fixture cannot make: the conjunction is
      // resolved, not hard-coded. German says "und".
      expect(
        service.requiredList(['Alpha', 'Beta'], locale: TomTextLocale('de')),
        'Alpha und Beta',
      );
    });

    test('one item consults no separator at all', () {
      // So a deployment that never joins more than one never has to supply the
      // keys — asserted against a bundle set that does not have them, which is
      // the only way to show the resolution did not happen.
      final bare = TomEmailService(
        outbox: outbox,
        texts: TomLocalizedTextResources(
          defaultLocale: TomTextLocale('en'),
          bundles: const {'en': <String, Object?>{}},
        ),
      );
      expect(bare.requiredList(['Alpha']), 'Alpha');
    });

    test('an empty list is the empty string, not a failure', () {
      // A caller that needs "you have nothing outstanding" is in the
      // conditional case rather than the list case, and renders that sentence
      // as its own key.
      final bare = TomEmailService(
        outbox: outbox,
        texts: TomLocalizedTextResources(
          defaultLocale: TomTextLocale('en'),
          bundles: const {'en': <String, Object?>{}},
        ),
      );
      expect(bare.requiredList(const []), '');
    });

    test('a bundle with no separators fails the send, naming the key', () {
      // The separators have no Dart default: ", " and " and " are English, and
      // a framework that routes every user-facing string through a bundle
      // cannot make these the two it writes in code.
      final bare = TomEmailService(
        outbox: outbox,
        texts: TomLocalizedTextResources(
          defaultLocale: TomTextLocale('en'),
          bundles: const {'en': <String, Object?>{}},
        ),
      );
      expect(
        () => bare.requiredList(['Alpha', 'Beta']),
        throwsA(
          isA<TomMessagingException>()
              .having((e) => e.key, 'key', 'messaging.email.template.missing')
              .having(
                (e) => e.parameters?['resourceKey'],
                'resourceKey',
                'messaging.list.last',
              ),
        ),
      );
    });

    test('requiredList substitutes nothing, so items arrive as written', () {
      // It joins strings. An item that still carries a placeholder keeps it —
      // the same rule fragments have, and the reason both say "resolve fully
      // before passing in".
      expect(
        service.requiredList(['{firstname}', 'Beta']),
        '{firstname} and Beta',
      );
    });

    test('requiredText fails the same way a missing subject does', () {
      // One failure mode for one class of fault: a fragment nobody wrote must
      // not be the one part of a mail that silently renders empty.
      expect(
        () => service.requiredText('email.password_reset', 'footer'),
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.parameters?['resourceKey'],
            'resourceKey',
            'email.password_reset.footer',
          ),
        ),
      );
    });

    test('an entirely unknown template key fails loudly at send', () async {
      await expectLater(
        service.send(reset(templateKey: 'email.does_not_exist')),
        throwsA(isA<TomMessagingException>()),
      );
      expect(await outbox.store.all(), isEmpty);
      expect(transport.count, 0);
    });

    test('send reaches the outbox and not the transport', () async {
      await service.send(reset());
      expect(transport.count, 0);
      expect(await outbox.store.all(), hasLength(1));

      await outbox.tick();
      expect(transport.count, 1);
      expect(transport.last!.subject, 'Reset your password, Erin');
    });

    test('sendNow delivers without waiting for a tick', () async {
      await service.sendNow(reset());
      expect(transport.count, 1);
    });

    test('a principal supplies the address, display name and locale', () {
      final message = service.render(
        TomEmailRequest.toPrincipal(
          templateKey: 'email.password_reset',
          principal: fixturePrincipal(language: 'de', country: 'AT'),
          parameters: {'firstname': 'Erin', 'link': 'https://example.com/r/1'},
        ),
      );
      expect(message.recipients.single.address, 'erin@example.com');
      expect(message.recipients.single.displayName, 'Erin Muster');
      expect(message.subject, 'Kennwort zurücksetzen, Erin');
    });

    test('a principal with no address fails rather than mailing nowhere', () {
      expect(
        () => TomEmailRequest.toPrincipal(
          templateKey: 'email.welcome',
          principal: fixturePrincipal(email: null),
        ),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('the sender is left to the transport unless the caller names one', () {
      expect(service.render(reset()).from, isNull);

      final signed = service.render(
        TomEmailRequest(
          templateKey: 'email.welcome',
          to: [TomRecipient('erin@example.com')],
          from: TomRecipient('noreply@example.com', displayName: 'Example'),
        ),
      );
      expect(signed.from!.address, 'noreply@example.com');
    });

    test('an explicit message id makes a resend idempotent', () async {
      final request = TomEmailRequest(
        templateKey: 'email.welcome',
        to: [TomRecipient('erin@example.com')],
        messageId: 'welcome-7',
      );
      await service.send(request);
      await service.send(request);
      expect(await outbox.store.all(), hasLength(1));
    });

    test('without an explicit id two sends are two messages', () async {
      await service.send(reset());
      await service.send(reset());
      expect(await outbox.store.all(), hasLength(2));
    });

    test('resolve answers the installed bean', () {
      expect(TomEmailService.resolve(), isNull);
      addTearDown(TomBean.resetBeanContext);
      TomBean.withType(TomEmailService, service);
      expect(TomEmailService.resolve(), same(service));
    });
  });
}
