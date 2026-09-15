import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/localized_texts.dart';

/// Text chosen by the recipient's locale rather than the process's.
///
/// Everything here asserts one rule from a different angle: **the locale is an
/// argument, not ambient state**. A server renders for many users in many
/// languages at once, so naming a locale must be unambiguous ([TomTextLocale]),
/// resolving one must degrade per key rather than per bundle so a
/// half-translated language serves what it has, and a key nobody wrote must
/// answer `null` rather than the key — right on a screen, unacceptable in a
/// subject line.

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
      expect(
        TomTextLocale.parse('en-XX').tag,
        'en',
        reason: 'a user-assigned code is not a region, so the scan passes it',
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
        throwsA(isA<TomResourceLocaleException>()),
      );
      expect(
        () => TomTextLocale('zh', 'Hans'),
        throwsA(isA<TomResourceLocaleException>()),
      );
      expect(
        () => TomTextLocale('es', '419'),
        throwsA(isA<TomResourceLocaleException>()),
      );
    });

    test('the codes reserved for meaning "not a country" are refused', () {
      // ISO 3166-1 permanently withholds `AA`, `QM`-`QZ`, `XA`-`XZ` and `ZZ`
      // from assignment so that applications can use them for their own
      // purposes. They are alpha-2, so a shape check passes them, and they are
      // exactly the values a deployment reaches for when it has no country —
      // this stack writes `XX`, CLDR writes `ZZ`.
      //
      // A shape check therefore admits the one class of value guaranteed never
      // to name a bundle. That is the silent miss the country invariant exists
      // to prevent, not an exception to it.
      for (final reserved in ['XX', 'ZZ', 'AA', 'QM', 'QZ', 'XA', 'XZ']) {
        expect(
          () => TomTextLocale('en', reserved),
          throwsA(isA<TomResourceLocaleException>()),
          reason: '$reserved is user-assigned and can never name a country',
        );
      }
      // The neighbours of the reserved ranges are ordinary countries.
      expect(TomTextLocale('en', 'ZW').tag, 'en_ZW');
      expect(TomTextLocale('fr', 'QA').tag, 'fr_QA');
      expect(TomTextLocale('de', 'AT').tag, 'de_AT');
    });

    test('the "no country" sentinel arrives as data and costs the country', () {
      // Not a hypothetical composition. `TomAuthenticationMessage.clientCountry`
      // defaults to `XX` and clients send it verbatim when the device names no
      // region, so it reaches `TomPrincipal.clientCountry` in ordinary
      // traffic — and this is the path a signed-in user with no stored
      // preference actually takes.
      //
      // Admitting it produced the tag `en_XX`: a key no bundle carries, which
      // the chain then resolved through bare `en` while reporting nothing. The
      // text was right and the deployment could not learn that its regional
      // bundles were unreachable.
      final locale = TomTextLocale.fromPrincipal(
        fixturePrincipal(clientLanguage: 'en', clientCountry: 'XX'),
      );
      expect(locale!.tag, 'en');
    });

    test('a principal\'s unusable country costs the country, not the mail', () {
      // `TomPrincipal.country` and the 2FA context's are free-form strings
      // filled from a client request, so the strict constructor must not be
      // reachable with them: a client sending `country: "XYZ"` would otherwise
      // throw inside message delivery. Degrading to the bare language reaches a
      // bundle that exists, which the refused key never could.
      final locale = TomTextLocale.fromPrincipal(
        fixturePrincipal(language: 'de', country: 'AUT'),
      );
      expect(locale!.tag, 'de');
    });

    test('rejects an empty language rather than inventing one', () {
      expect(
        () => TomTextLocale('  '),
        throwsA(isA<TomResourceLocaleException>()),
      );
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
          fixturePrincipal(
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
        fixturePrincipal(clientLanguage: 'fr', clientCountry: 'CH'),
      );
      expect(locale!.tag, 'fr_CH');
    });

    test('a stored language of blanks is nothing stored', () {
      // `TomPrincipal.language` is a free-form column, so "unset" arrives as a
      // null *or* as whitespace -- a form that submitted an untouched field, a
      // migration that defaulted the column to `''`. Only the null case is
      // covered by the test above, and the two branches are separate lines:
      // found by mutation, dropping the blank check left the suite green while
      // making a blank stored language beat a real device one.
      final locale = TomTextLocale.fromPrincipal(
        fixturePrincipal(
          language: '   ',
          clientLanguage: 'fr',
          clientCountry: 'CH',
        ),
      );
      expect(locale!.tag, 'fr_CH');
    });

    test('a principal with no locale at all yields null, not a guess', () {
      expect(TomTextLocale.fromPrincipal(fixturePrincipal()), isNull);
    });
  });

  // ===========================================================================
  // LOCALE EXCEPTION
  // ===========================================================================

  group('TomResourceLocaleException', () {
    test('is never client-visible', () {
      // This is the whole reason the type is declared. It adds no field, no
      // behaviour and no message of its own; it exists to make `clientThrow`
      // false, because the value it is complaining about came from a config
      // file, a file name or a user record, and echoing it to a browser tells
      // an attacker about the deployment while telling the user nothing.
      //
      // So the property has to be an invariant and not a default. `clientThrow`
      // is not a constructor parameter — the signature pins that at compile
      // time, and there being exactly one constructor is what makes the two
      // halves add up: every instance that exists went through it.
      expect(TomResourceLocaleException('k', 'm').clientThrow, isFalse);
      for (final raise in <void Function()>[
        () => TomTextLocale('  '),
        () => TomTextLocale('en', 'AUT'),
      ]) {
        expect(
          raise,
          throwsA(
            isA<TomResourceLocaleException>().having(
              (e) => e.clientThrow,
              'clientThrow',
              isFalse,
            ),
          ),
        );
      }
    });

    test('the key says which of the two rules was broken', () {
      // A handler logs the key, not the prose, and the two failures want
      // different responses: an empty language means whatever derived the tag
      // is broken — a mis-globbed `text_.yaml`, a null database column — while
      // a refused country is routine, since clients send `XX` for "no region"
      // in ordinary traffic. One key for both would flatten a bootstrap fault
      // into background noise.
      expect(
        () => TomTextLocale('  '),
        throwsA(
          isA<TomResourceLocaleException>().having(
            (e) => e.key,
            'key',
            'resources.locale.empty_language',
          ),
        ),
      );
      expect(
        () => TomTextLocale('en', 'AUT'),
        throwsA(
          isA<TomResourceLocaleException>()
              .having((e) => e.key, 'key', 'resources.locale.invalid_country')
              .having((e) => e.parameters, 'parameters', {'country': 'AUT'}),
        ),
      );
    });

    test('is caught by a clause written for the base type', () {
      // The pattern the api summary advertises: one `on TomServerException`
      // clause reaches every exception in the package. Tightening the
      // assertions above to the specific type is not a claim that a caller
      // must name it — only that the tests must, since the base class would
      // hold just as well for anything else the constructor could throw.
      expect(() => TomTextLocale('  '), throwsA(isA<TomServerException>()));
    });
  });

  // ===========================================================================
  // LOCALISED RESOURCES
  // ===========================================================================

  group('TomLocalizedTextResources', () {
    late TomLocalizedTextResources texts;

    setUp(() => texts = fixtureTexts());

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

    test('a bundle key with no language is refused at construction', () {
      // Both constructors normalise their keys through `TomTextLocale.parse`,
      // which reaches the constructor's empty-language check. So a bundle map
      // is not merely data here: constructing the set validates its keys, and
      // the failure is a throw at bootstrap rather than a bundle that quietly
      // never resolves.
      //
      // The realistic source is a *file name*. The documented loading pattern
      // derives keys from `text_<tag>.yaml`, so a stray `text_.yaml` or a
      // mis-globbed `text__AT.yaml` becomes one of these.
      for (final key in ['', '   ', '_AT', '-AT', '_', '-']) {
        expect(
          () => TomLocalizedTextResources(
            defaultLocale: TomTextLocale('en'),
            bundles: {
              key: {'k': 'v'},
            },
          ),
          throwsA(isA<TomResourceLocaleException>()),
          reason: '"$key" names no language, so it cannot key a bundle',
        );
      }
    });

    test(
      'the provider constructor refuses the same keys, not just the map one',
      () {
        // The factory delegates to `ofProviders`, so the check lives there. Worth
        // asserting directly: a deployment loading from a database or an asset
        // archive uses `ofProviders` and never touches the factory, and would
        // otherwise be relying on an untested path.
        expect(
          () => TomLocalizedTextResources.ofProviders(
            defaultLocale: TomTextLocale('en'),
            bundles: {
              '': TomTextResourceProvider.from({'k': 'v'}),
            },
          ),
          throwsA(isA<TomResourceLocaleException>()),
        );
      },
    );

    test('a key that parses is normalised, never refused', () {
      // The complement of the case above, and the more common one. `parse`
      // finds the region by shape and drops any subtag that cannot be one, so
      // almost everything parses — only a missing *language* throws. Nothing
      // here is an error; each is a key spelled differently from its tag.
      final set = TomLocalizedTextResources(
        defaultLocale: TomTextLocale('en'),
        bundles: {
          'DE-at': {'k': 'v'},
          'en_XX': {'k': 'v'},
          'zh-Hans-CN': {'k': 'v'},
          'es-419': {'k': 'v'},
        },
      );
      expect(set.locales, ['de_AT', 'en', 'zh_CN', 'es']);
    });

    test('two keys naming one locale collapse, and the last one wins', () {
      // A consequence of normalising into a map rather than a defect, but an
      // invisible one: `en_XX` is not a locale — `XX` is the reserved code this
      // stack uses for "no country" — so it normalises to `en` and lands on the
      // key `en` already holds. No throw, no warning, and `locales` reports a
      // single `en`, so the set looks exactly like one that was written that
      // way on purpose.
      final set = TomLocalizedTextResources(
        defaultLocale: TomTextLocale('en'),
        bundles: {
          'en': {'k': 'first'},
          'en_XX': {'k': 'second'},
        },
      );
      expect(set.locales, ['en'], reason: 'two keys, one bundle');
      expect(set.textOrNull('k', locale: TomTextLocale('en')), 'second');
    });
  });

  // ===========================================================================
  // THE INSTALLED BUNDLE SET
  // ===========================================================================

  group('the deployment installs one set, and services find it', () {
    // The bean is the module's answer to "where does text come from", and it
    // is the answer precisely because the alternative writes itself: a
    // deployment with nowhere to put the set reaches for a static field of its
    // own, which is a process-wide singleton with none of a bean's
    // substitutability. The sample did exactly that until it had this.
    //
    // The bean context is process-global, so every test here puts it back.
    tearDown(TomBean.resetBeanContext);

    test('resolve answers null when nothing is installed', () {
      // Null rather than an empty set, and the reason is the same one
      // `TomTemplatedMessageService.texts` makes: an empty set renders every
      // message blank, and a blank message that was *sent* cannot be recalled.
      expect(TomLocalizedTextResources.resolve(), isNull);
    });

    test('resolve answers the installed set', () {
      final texts = fixtureTexts();
      TomBean.withType(TomLocalizedTextResources, texts);

      expect(TomLocalizedTextResources.resolve(), same(texts));
    });

    test('resolve answers null when the type is bound to something else', () {
      // It type-tests what it finds rather than casting, so a mis-wired
      // deployment fails as an absence its caller already handles rather than
      // as a cast error raised at whichever consumer asked first.
      TomBean.overrideWithType(TomLocalizedTextResources, 'not a bundle set');

      expect(TomLocalizedTextResources.resolve(), isNull);
    });

    test('a service with no texts argument reads the installed set', () {
      final texts = fixtureTexts();
      TomBean.withType(TomLocalizedTextResources, texts);

      expect(TomEmailService(outbox: _outbox()).texts, same(texts));
    });

    test('a service given a set uses that one, installed or not', () {
      // The argument is an override, so a test with a fixture bundle or a
      // second service rendering from another set is unaffected by what the
      // deployment installed.
      final installed = fixtureTexts();
      final own = fixtureTexts();
      TomBean.withType(TomLocalizedTextResources, installed);

      final service = TomEmailService(outbox: _outbox(), texts: own);

      expect(service.texts, same(own));
      expect(service.texts, isNot(same(installed)));
    });

    test('a service with neither refuses rather than rendering blank', () {
      // The failure a deployment must not be able to reach silently. It is
      // raised on the first render rather than at construction, because the
      // set is resolved per call — which is what lets a bootstrap build its
      // services before it reads its bundles off disk.
      expect(
        () => TomEmailService(outbox: _outbox()).texts,
        throwsA(
          isA<TomMessagingException>().having(
            (error) => error.key,
            'key',
            'messaging.email.texts.not_configured',
          ),
        ),
      );
    });

    test('the refusal names the channel that could not render', () {
      // Two services, two keys: an operator reading `messaging.sms.*` must not
      // be sent to the mail bundle.
      expect(
        () => TomSmsService(outbox: _outbox()).texts,
        throwsA(
          isA<TomMessagingException>().having(
            (error) => error.key,
            'key',
            'messaging.sms.texts.not_configured',
          ),
        ),
      );
    });
  });
}

/// An outbox for a service that never queues anything: every test above reads
/// `texts` and stops there.
TomMessageOutbox _outbox() => TomMessageOutbox(router: TomMessageRouter([]));
