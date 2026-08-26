import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The templating layer above the message transport.
///
/// Everything here asserts the same underlying rule from a different angle:
/// **an application email is a template key plus parameters**. That means no
/// user-facing string reaches Dart, the same key renders differently per
/// recipient locale, a key nobody wrote fails at send rather than mailing a
/// blank, and the rendered message goes to the *outbox* — where retry and
/// permanence classification already live — rather than to a transport.

// =============================================================================
// FIXTURES
// =============================================================================

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;
}

/// The two-locale bundle set every email test renders against.
///
/// Deliberately *partially* translated: `de` carries the password-reset
/// template but not the welcome one, which is what a real deployment mid-way
/// through a translation looks like and is the only way to assert that a
/// missing key falls through to the default locale rather than rendering empty.
TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'email': {
        'password_reset': {
          'subject': 'Reset your password, {firstname}',
          'text': 'Open {link} to choose a new password.',
          'html': '<p>Open <a href="{link}">this link</a>.</p>',
        },
        'welcome': {'subject': 'Welcome', 'text': 'Glad to have you.'},
        'no_text': {'subject': 'Has a subject but no body'},
        'no_subject': {'text': 'Has a body but no subject'},
      },
    },
    'de': {
      'email': {
        'password_reset': {
          'subject': 'Passwort zurücksetzen, {firstname}',
          'text': 'Öffnen Sie {link}, um ein neues Passwort zu wählen.',
          'html': '<p>Öffnen Sie <a href="{link}">diesen Link</a>.</p>',
        },
      },
    },
    'de_AT': {
      'email': {
        'password_reset': {'subject': 'Kennwort zurücksetzen, {firstname}'},
      },
    },
  },
);

TomPrincipal _principal({
  String? email = 'erin@example.com',
  String? language,
  String? country,
  String? clientLanguage,
  String? clientCountry,
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(
    id: 7,
    username: 'erin',
    firstname: 'Erin',
    lastname: 'Muster',
    email: email,
  ),
  language: language,
  country: country,
  clientLanguage: clientLanguage,
  clientCountry: clientCountry,
);

void main() {
  // ===========================================================================
  // LOCALE
  // ===========================================================================

  group('TomTextLocale', () {
    test('normalises case so a bundle key is unambiguous', () {
      final locale = TomTextLocale('DE', 'at');
      expect(locale.language, 'de');
      expect(locale.country, 'AT');
      expect(locale.tag, 'de_AT');
    });

    test('parses both separator conventions', () {
      expect(TomTextLocale.parse('de_AT').tag, 'de_AT');
      expect(TomTextLocale.parse('de-at').tag, 'de_AT');
      expect(TomTextLocale.parse('de').tag, 'de');
    });

    test('a script subtag is not a country', () {
      // BCP 47 puts the script before the region for the languages that have
      // more than one, so the second segment is not reliably a country.
      // Reading it as one produced `zh_HANS` — a key naming no locale, which
      // no deployment's `zh_CN` bundle could ever match. The chain still
      // reached bare `zh`, so the deployment saw Chinese and never learnt its
      // regional bundle was unreachable.
      expect(TomTextLocale.parse('zh-Hans-CN').tag, 'zh_CN');
      expect(TomTextLocale.parse('zh-Hans').tag, 'zh');
      expect(TomTextLocale.parse('zh-Hans-CN').country, 'CN');
    });

    test('the region is found by shape, not by position', () {
      // Whatever sits between the language and the region — script, extlang,
      // variant — is skipped rather than counted.
      expect(TomTextLocale.parse('sr-Latn-RS').tag, 'sr_RS');
      expect(TomTextLocale.parse('de-DE-1996').tag, 'de_DE');
      expect(
        TomTextLocale.parse('en-US-x-private').tag,
        'en_US',
        reason: 'a singleton opens private use; the region precedes it',
      );
      expect(
        TomTextLocale.parse('es-419').tag,
        'es',
        reason: 'a UN M.49 region is not alpha-2, so it is not a country here',
      );
    });

    test('an empty country is the same as no country', () {
      expect(TomTextLocale('de', '  ').tag, 'de');
    });

    test('refuses a country that cannot be a country', () {
      // The field is documented as ISO 3166-1 alpha-2. It was documented and
      // not enforced, which is how a four-letter script reached it.
      expect(
        () => TomTextLocale('de', 'AUT'),
        throwsA(isA<TomServerException>()),
      );
      expect(
        () => TomTextLocale('zh', 'Hans'),
        throwsA(isA<TomServerException>()),
      );
      expect(
        () => TomTextLocale('es', '419'),
        throwsA(isA<TomServerException>()),
      );
    });

    test('a principal\'s unusable country costs the country, not the mail', () {
      // `TomPrincipal.country` and the 2FA context's are free-form strings
      // filled from a client request, so the strict constructor must not be
      // reachable with them: a client sending `country: "XYZ"` would otherwise
      // throw inside message delivery. Degrading to the bare language reaches a
      // bundle that exists, which the refused key never could.
      final locale = TomTextLocale.fromPrincipal(
        _principal(language: 'de', country: 'AUT'),
      );
      expect(locale!.tag, 'de');
    });

    test('rejects an empty language rather than inventing one', () {
      expect(() => TomTextLocale('  '), throwsA(isA<TomServerException>()));
    });

    test('falls back from the country variant to the bare language', () {
      expect(TomTextLocale('de', 'AT').fallbackTags, ['de_AT', 'de']);
      expect(TomTextLocale('de').fallbackTags, ['de']);
    });

    test('equality is by tag, so it can key a bundle map', () {
      expect(TomTextLocale('de', 'AT'), TomTextLocale('DE', 'at'));
      expect(TomTextLocale('de'), isNot(TomTextLocale('de', 'AT')));
    });

    test(
      'a principal\'s stored language wins over the device it signed in on',
      () {
        final locale = TomTextLocale.fromPrincipal(
          _principal(
            language: 'de',
            country: 'AT',
            clientLanguage: 'en',
            clientCountry: 'GB',
          ),
        );
        expect(locale!.tag, 'de_AT');
      },
    );

    test('the device locale serves when nothing is stored', () {
      final locale = TomTextLocale.fromPrincipal(
        _principal(clientLanguage: 'fr', clientCountry: 'CH'),
      );
      expect(locale!.tag, 'fr_CH');
    });

    test('a principal with no locale at all yields null, not a guess', () {
      expect(TomTextLocale.fromPrincipal(_principal()), isNull);
    });
  });

  // ===========================================================================
  // LOCALISED RESOURCES
  // ===========================================================================

  group('TomLocalizedTextResources', () {
    late TomLocalizedTextResources texts;

    setUp(() => texts = _texts());

    test('resolves from the requested locale', () {
      expect(
        texts.textOrNull(
          'email.password_reset.text',
          locale: TomTextLocale('de'),
        ),
        startsWith('Öffnen Sie'),
      );
    });

    test('a country variant wins over the bare language', () {
      expect(
        texts.textOrNull(
          'email.password_reset.subject',
          locale: TomTextLocale('de', 'AT'),
        ),
        startsWith('Kennwort'),
      );
    });

    test('a partially translated variant falls through to its language', () {
      // de_AT translates only the subject; the body must still be German
      // rather than English or empty.
      expect(
        texts.textOrNull(
          'email.password_reset.text',
          locale: TomTextLocale('de', 'AT'),
        ),
        startsWith('Öffnen Sie'),
      );
    });

    test('an untranslated key falls through to the default locale', () {
      expect(
        texts.textOrNull('email.welcome.subject', locale: TomTextLocale('de')),
        'Welcome',
      );
    });

    test('an unknown locale is served by the default one', () {
      expect(
        texts.textOrNull('email.welcome.subject', locale: TomTextLocale('ja')),
        'Welcome',
      );
    });

    test('the default the chain ends at is the configured one, not English', () {
      // Every other test in this group runs against a fixture whose default is
      // `en`, so all of them assert English strings — and would go on passing
      // against an implementation that had English built into it. That is the
      // whole point of the module: the locale stopped being ambient, and a
      // privileged language would put it straight back.
      //
      // A second set with a French default, and no English bundle at all, is
      // the only arrangement in which "the configured default" and "English"
      // give different answers.
      final french = TomLocalizedTextResources(
        defaultLocale: TomTextLocale('fr'),
        bundles: {
          'fr': {
            'email': {
              'welcome': {'subject': 'Bienvenue'},
            },
          },
          'de': {
            'email': {
              'password_reset': {'subject': 'Passwort zurücksetzen'},
            },
          },
        },
      );

      expect(
        french.textOrNull('email.welcome.subject', locale: TomTextLocale('de')),
        'Bienvenue',
        reason:
            'an untranslated key falls through to the deployment\'s default',
      );
      expect(
        french.resolveLocale(TomTextLocale('ja'))?.tag,
        'fr',
        reason: 'and so does a locale the set carries nothing for',
      );
    });

    test('a missing key answers null rather than echoing the key', () {
      // The client-side provider answers a miss with the key itself, which is
      // right on a screen and catastrophic in a subject line.
      expect(texts.textOrNull('email.nothing.here'), isNull);
    });

    test('substitutes named parameters', () {
      expect(
        texts.textOrNull(
          'email.password_reset.subject',
          parameters: {'firstname': 'Erin'},
        ),
        'Reset your password, Erin',
      );
    });

    test('an unreferenced parameter is not an error', () {
      expect(
        texts.textOrNull(
          'email.welcome.subject',
          parameters: {'firstname': 'Erin'},
        ),
        'Welcome',
      );
    });

    test(
      'a null parameter leaves the placeholder rather than writing null',
      () {
        // `parameters` is `Map<String, Object?>` and callers fill it from
        // nullable model fields — `TomUser.firstname` among them — so a null
        // value arrives through the front door. Interpolating it produced
        // `Reset your password, null`, which reads as finished text and so
        // defeats the very argument the unmatched-placeholder rule rests on: a
        // visible `{firstname}` is caught by whoever proof-reads the mail.
        expect(
          texts.textOrNull(
            'email.password_reset.subject',
            parameters: {'firstname': null},
          ),
          'Reset your password, {firstname}',
        );
      },
    );

    test('a null parameter is indistinguishable from an absent one', () {
      // The behaviours are equal by construction, not by coincidence: the
      // point of the rule is that a caller need not decide which of "I have no
      // value" and "I am not passing this key" it means.
      expect(
        TomLocalizedTextResources.substitute('Hi {n}!', {'n': null}),
        TomLocalizedTextResources.substitute('Hi {n}!', const {}),
      );
      expect(
        TomLocalizedTextResources.substitute('{a} and {b}', {
          'a': 'one',
          'b': null,
        }),
        'one and {b}',
        reason: 'a null value does not disturb its neighbours',
      );
    });

    test('reports which locales it carries', () {
      expect(texts.locales, containsAll(['en', 'de', 'de_AT']));
    });

    test('resolveLocale names the bundle the chain lands on first', () {
      expect(texts.resolveLocale(TomTextLocale('de', 'AT'))?.tag, 'de_AT');
      expect(
        texts.resolveLocale(TomTextLocale('de', 'CH'))?.tag,
        'de',
        reason: 'a country variant nobody wrote resolves to its bare language',
      );
      expect(
        texts.resolveLocale(null)?.tag,
        'en',
        reason: 'asking for no locale in particular reaches the default',
      );
    });

    test('resolveLocale answers null for a chain miss, not an empty set', () {
      // The distinction is the whole point. This set plainly carries
      // something; what it carries nothing for is the chain for `de`, which is
      // [de, en]. And because every chain ends with the default locale's own
      // tags, that is the general rule: null means the *default* bundle is
      // absent, which is a wiring fault rather than a routine miss.
      //
      // Worth pinning because the documented use is
      // `resolveLocale(requested) ?? defaultLocale` for a Content-Language
      // header. Read as "null means the set is empty", that `??` looks
      // unreachable in a configured deployment — and it is exactly the branch
      // that declares a language no bundle exists for.
      final sparse = TomLocalizedTextResources(
        defaultLocale: TomTextLocale('en'),
        bundles: {
          'fr': {
            'email': {
              'welcome': {'subject': 'Bienvenue'},
            },
          },
        },
      );

      expect(sparse.locales, ['fr'], reason: 'the set is not empty');
      expect(sparse.resolveLocale(TomTextLocale('de')), isNull);
      expect(
        sparse.resolveLocale(null),
        isNull,
        reason: 'the default locale is not carried either',
      );
      expect(
        sparse.resolveLocale(TomTextLocale('fr'))?.tag,
        'fr',
        reason: 'the one bundle it does carry still resolves',
      );
    });

    test('isTranslated reports the bundle someone wrote, not the chain', () {
      final austrian = TomTextLocale('de', 'AT');
      // `de_AT` carries only the subject. A render is right to fall through for
      // the body — that is what a translation in progress looks like — but a
      // completeness check must not call the gap a translation.
      expect(
        texts.isTranslated('email.password_reset.subject', austrian),
        isTrue,
      );
      expect(
        texts.isTranslated('email.password_reset.text', austrian),
        isFalse,
      );
      // ...whereas `exists` follows the chain and answers yes for both, which
      // is exactly why the two methods are separate.
      expect(
        texts.exists('email.password_reset.text', locale: austrian),
        isTrue,
      );
    });

    test('isTranslated answers false for a locale nobody wrote', () {
      expect(
        texts.isTranslated('email.welcome.subject', TomTextLocale('fr')),
        isFalse,
      );
    });
  });

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
      service = TomEmailService(outbox: outbox, texts: _texts());
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
          principal: _principal(language: 'de', country: 'AT'),
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
          principal: _principal(email: null),
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
