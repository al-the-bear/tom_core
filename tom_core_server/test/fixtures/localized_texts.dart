/// A mid-translation bundle set, and a principal that carries a locale.
///
/// Two suites render against these. `resources_test.dart` asserts the fallback
/// chain itself; `email_service_test.dart` asserts that a templated mail picks
/// a locale and resolves its sub-keys. Both need the same thing: a set that is
/// **deliberately incomplete**, because a fully translated set cannot tell a
/// working chain from an implementation that ignores the locale entirely.
///
/// That incompleteness is the whole value of the fixture and it is stated
/// nowhere in either suite's assertions — a suite reads `startsWith('Öffnen
/// Sie')` and looks like an ordinary German expectation. So a second copy would
/// be a second thing to keep true, and the day the two drifted, both suites
/// would still be green while testing different chains.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// The three-locale bundle set both suites render against.
///
/// Incomplete on two axes, each of which some assertion depends on:
///
/// - `de` carries `password_reset` but not `welcome`, so an untranslated key
///   has somewhere to fall through *to* — the default locale.
/// - `de_AT` carries only `password_reset.subject`, so the fall-through is
///   per-key rather than per-bundle: the Austrian subject with the German body
///   is what a translation in progress actually looks like.
///
/// `no_text` and `no_subject` are the templates a mail cannot be built from,
/// and exist so the email service's two loud failures have something to fail
/// on.
///
/// `messaging.list` carries the separators `requiredList` joins with, and the
/// German conjunction differs from the English one — which is what lets a suite
/// tell a locale-aware join from a hard-coded comma. The *missing*-separator
/// case is not modelled here: a bundle set without them is one line to build in
/// the suite that needs it, and adding a fourth axis of incompleteness to this
/// fixture would make every assertion in both suites harder to read.
TomLocalizedTextResources fixtureTexts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      // The list separators `requiredList` joins with. English in the default
      // bundle and German in `de`, so a suite can tell a locale-aware join from
      // a hard-coded comma — which is the one thing a single-locale fixture
      // cannot distinguish.
      'messaging': {
        'list': {'separator': ', ', 'last': ' and '},
      },
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
      'messaging': {
        'list': {'separator': ', ', 'last': ' und '},
      },
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

/// A signed-in user whose stored and device locales are each set separately.
///
/// The four locale fields default to `null` rather than to a plausible value,
/// so a test naming one of them is naming the *only* thing that could have
/// produced its answer — which is what `TomTextLocale.fromPrincipal`'s
/// precedence rule has to be asserted against.
TomPrincipal fixturePrincipal({
  String? email = 'erin@example.com',
  String? language,
  String? country,
  String? clientLanguage,
  String? clientCountry,
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(
    id: '7',
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
