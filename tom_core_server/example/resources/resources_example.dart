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
/// per-key fallback exists for.
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

  // 3. Fallback is per key, not per bundle: the German bundle has no footer,
  //    so this one key falls through while its neighbours stay German.
  final footer = texts.textOrNull(
    'mail.footer',
    locale: TomTextLocale('de'),
    parameters: {'company': 'Tom'},
  );
  print('3. footer de => $footer');
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

  // 4. A miss is null, never the key. On a screen the key is the right
  //    failure; in an email nobody sees the subject before the recipient does.
  final missing = texts.textOrNull('mail.nothing.here');
  print('4. unknown key => $missing');
  check(missing == null, 'an unknown key resolves to null, not to itself');
  check(
    !texts.exists('mail.nothing.here'),
    'and `exists` answers the same question without rendering',
  );

  // 5. A placeholder with no value is left standing rather than blanked, so a
  //    proof-reader sees it. `null` counts as absent for the same reason.
  final unfilled = texts.textOrNull(
    'mail.greeting',
    locale: TomTextLocale('en'),
    parameters: {'firstname': null},
  );
  print('5. greeting with a null parameter => $unfilled');
  check(
    unfilled == 'Hello {firstname},',
    'an absent value leaves the placeholder visible instead of writing "null"',
  );

  // 6. The recipient's locale comes off the principal, so the caller does not
  //    have to decide what "their language" means.
  final principal = TomPrincipal()
    ..language = 'de'
    ..clientLanguage = 'en';
  final fromPrincipal = TomTextLocale.fromPrincipal(principal);
  print('6. locale from principal => $fromPrincipal');
  check(
    '$fromPrincipal' == 'de',
    'the stored language wins over the client one, which is only a fallback',
  );

  // 7. Which locales the set actually carries — the question a deployment asks
  //    when a translation is reported missing.
  print('7. bundles => ${texts.locales}');
  check(
    texts.hasLocale(TomTextLocale('de', 'AT')) &&
        !texts.hasLocale(TomTextLocale('fr')),
    'hasLocale is exact: it answers "did someone write this translation"',
  );

  print('\nResources example completed.');
}

void main() {
  run();
}
