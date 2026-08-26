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
        fixturePrincipal(language: 'de', country: 'AUT'),
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

    test('a principal with no locale at all yields null, not a guess', () {
      expect(TomTextLocale.fromPrincipal(fixturePrincipal()), isNull);
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
  });
}
