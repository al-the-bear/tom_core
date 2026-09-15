/// Executable example for the resources module of `tom_core_server`.
///
/// Demonstrates the one thing the module adds over the kernel's text provider:
/// the locale is an **argument**, not ambient state. A server renders for many
/// users in many languages in the same event loop, so there is no moment at
/// which it could meaningfully "switch to German".
///
/// The steps below cover the whole surface a caller touches — building a bundle
/// set, resolving a key in a named locale, the per-key fallback chain, the
/// `null` a miss answers with, parameter substitution, and the locale a
/// principal carries. All of it runs in memory: bundles are maps, and nothing
/// here opens a file or a connection.
///
/// Run with `dart run example/resources/resources_example.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification and not just a transcript. The same behaviour is
/// covered by `test/resources_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The bundle set the steps below resolve against.
///
/// `de` is deliberately **half translated**: it has the subject line and not
/// the footer, which is what a translation in progress looks like and what the
/// per-key fallback exists for. `de_AT` is thinner still — a greeting and
/// nothing else — so the chain's three rungs are each reachable on their own.
TomLocalizedTextResources buildResources() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'mail': {
        'subject': 'Your invoice',
        'greeting': 'Hello {firstname},',
        'footer': 'Sent by {company}.',
      },
    },
    'de': {
      'mail': {'subject': 'Ihre Rechnung', 'greeting': 'Hallo {firstname},'},
    },
    // Austrian German overrides the greeting alone. It has no subject, which
    // is what makes the *middle* rung of the chain observable: `mail.subject`
    // in `de_AT` must land on `de`, not on the default.
    'de_AT': {
      'mail': {'greeting': 'Grüß dich {firstname},'},
    },
  },
);

void run() {
  final texts = buildResources();

  // 1. A locale is an argument. Two recipients, one call site, one instant.
  final english = texts.textOrNull('mail.subject', locale: TomTextLocale('en'));
  final german = texts.textOrNull('mail.subject', locale: TomTextLocale('de'));
  print('1. subject en/de => $english / $german');
  check(
    english == 'Your invoice' && german == 'Ihre Rechnung',
    'the same key resolves differently per call, with no state switched',
  );

  // 2. The chain is exact tag, then bare language, then the default locale.
  final austrian = texts.textOrNull(
    'mail.greeting',
    locale: TomTextLocale('de', 'AT'),
    parameters: {'firstname': 'Anna'},
  );
  print('2. greeting de_AT => $austrian');
  check(
    austrian == 'Grüß dich Anna,',
    'the exact tag answers before the bare language does',
  );

  // 3. The middle rung. `de_AT` has no subject, so this falls through — to the
  //    bare language, not to the default. That is the distinction the chain
  //    exists for: an Austrian reader gets the German subject, and would only
  //    get the English one if nobody had written a German subject either.
  final austrianSubject = texts.textOrNull(
    'mail.subject',
    locale: TomTextLocale('de', 'AT'),
  );
  print('3. subject de_AT => $austrianSubject');
  check(
    austrianSubject == 'Ihre Rechnung',
    'a key the country variant does not carry is answered by its bare '
    'language, not by the default locale',
  );
  check(
    texts.resolveLocale(TomTextLocale('de', 'AT'))?.tag == 'de_AT',
    'and the bundle the chain starts from is still the exact tag — the '
    'fallthrough is per key, so it says nothing about the locale as a whole',
  );

  // 4. Fallback is per key, not per bundle: the German bundle has no footer,
  //    so this one key falls through while its neighbours stay German.
  final footer = texts.textOrNull(
    'mail.footer',
    locale: TomTextLocale('de'),
    parameters: {'company': 'Tom'},
  );
  print('4. footer de => $footer');
  check(
    footer == 'Sent by Tom.',
    'a half-translated bundle serves what it has and falls through for the '
    'rest, rather than reverting the whole message',
  );
  check(
    texts.isTranslated('mail.subject', TomTextLocale('de')) &&
        !texts.isTranslated('mail.footer', TomTextLocale('de')),
    'and a caller can ask which of the two just happened',
  );

  // 5. A miss is null, never the key. On a screen the key is the right
  //    failure; in an email nobody sees the subject before the recipient does.
  final missing = texts.textOrNull('mail.nothing.here');
  print('5. unknown key => $missing');
  check(missing == null, 'an unknown key resolves to null, not to itself');
  check(
    !texts.exists('mail.nothing.here'),
    'and `exists` answers the same question without rendering',
  );

  // 6. A placeholder with no value is left standing rather than blanked, so a
  //    proof-reader sees it. `null` counts as absent for the same reason.
  final unfilled = texts.textOrNull(
    'mail.greeting',
    locale: TomTextLocale('en'),
    parameters: {'firstname': null},
  );
  print('6. greeting with a null parameter => $unfilled');
  check(
    unfilled == 'Hello {firstname},',
    'an absent value leaves the placeholder visible instead of writing "null"',
  );

  // 7. The recipient's locale comes off the principal, so the caller does not
  //    have to decide what "their language" means.
  final principal = TomPrincipal()
    ..language = 'de'
    ..clientLanguage = 'en';
  final fromPrincipal = TomTextLocale.fromPrincipal(principal);
  print('7. locale from principal => $fromPrincipal');
  check(
    '$fromPrincipal' == 'de',
    'the stored language wins over the client one, which is only a fallback',
  );

  // 8. Which locales the set actually carries — the question a deployment asks
  //    when a translation is reported missing.
  print('8. bundles => ${texts.locales}');
  check(
    texts.hasLocale(TomTextLocale('de', 'AT')) &&
        !texts.hasLocale(TomTextLocale('fr')),
    'hasLocale is exact: it answers "did someone write this translation"',
  );

  // 9. The completeness check a deployment runs in CI. `isTranslated` reports
  //    the bundle somebody *wrote*, un-chained, which is what makes it the
  //    right question here: `exists` would answer true for every key, because
  //    the chain always reaches the default locale. Asking it key by key turns
  //    "is the German translation finished" into an answer rather than a
  //    reading of the file.
  final untranslated = [
    for (final key in _keysOf(texts, texts.defaultLocale))
      if (!texts.isTranslated(key, TomTextLocale('de'))) key,
  ];
  print('9. untranslated in de => $untranslated');
  check(
    untranslated.length == 1 && untranslated.single == 'mail.footer',
    'the completeness check names the keys a locale has not translated, and '
    'only those',
  );
  check(
    _keysOf(texts, texts.defaultLocale).every(texts.exists),
    'while `exists` answers true for all of them — the chain reaches the '
    'default locale for every key, which is why it cannot be the check',
  );

  print('\nResources example completed.');
}

/// The keys [locale]'s own bundle carries, fully qualified.
///
/// The completeness check needs the key set to compare *against*, and the
/// default locale's bundle is what defines it: a key nobody wrote in the
/// default locale is not a translation that is missing, it is a key that does
/// not exist.
List<String> _keysOf(TomLocalizedTextResources texts, TomTextLocale locale) => [
  for (final section in ['mail'])
    for (final key in ['subject', 'greeting', 'footer'])
      if (texts.isTranslated('$section.$key', locale)) '$section.$key',
];

void main() {
  run();
}
