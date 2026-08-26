# Resources Module

Resource text chosen by the **recipient's** locale rather than the process's.
The kernel's `TomTextResourceProvider` is a singleton with one installed bundle
— exactly right for a client, where there is one user looking at one screen, and
exactly wrong for a server, which renders text for many users in many languages
concurrently. This module makes the locale an argument.

## Table of Contents

- [Overview](#overview)
- [Why the Kernel Provider Is Not Enough](#why-the-kernel-provider-is-not-enough)
- [Naming a Locale](#naming-a-locale)
- [The Fallback Chain](#the-fallback-chain)
  - [Asking the other question](#asking-the-other-question)
- [A Miss Is Null, Never the Key](#a-miss-is-null-never-the-key)
- [Parameters](#parameters)
- [Installing a Bundle Set](#installing-a-bundle-set)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTextLocale` | class | A language, optionally narrowed by a country |
| `TomLocalizedTextResources` | class | One `TomTextResourceProvider` per locale, plus the rule for picking one |
| `TomResourceLocaleException` | class | Raised when a locale cannot be formed from what a caller supplied |

## Why the Kernel Provider Is Not Enough

`TomTextResourceProvider` holds **one** bundle, swapped when the user's language
changes. There is no moment at which a server could meaningfully "switch to
German": it is answering a German user and an English one in the same event
loop. So the locale has to travel with the lookup.

That is the *only* thing this module adds. Everything about how a key resolves
— the dot-notation tree walk, the flat-key fallback, what counts as a String —
stays in `TomTextResourceProvider`; `TomLocalizedTextResources` holds a provider
per locale and decides which one answers. Reimplementing the walk would give a
deployment two resolution semantics for one bundle format, and the first key
that resolved on the client but not in an email would be a genuinely hard bug to
see.

## Naming a Locale

`TomTextLocale` is deliberately not Dart's `Locale` — that lives in `dart:ui`
and would drag Flutter into a server package — and not a bare `String`, which
would leave every call site to decide whether `de-AT`, `de_AT` and `DE_at` name
the same bundle. They do:

```dart
TomTextLocale('DE', 'at').tag;         // 'de_AT'
TomTextLocale.parse('de-at').tag;      // 'de_AT'
TomTextLocale.parse('de').tag;         // 'de'
TomTextLocale.parse('zh-Hans-CN').tag; // 'zh_CN'
```

Both separators are accepted because both are in the wild: POSIX and Java write
`_`, BCP 47 and HTTP write `-`. A bundle keyed one way that a user record spells
the other way is a silent miss, not an error, which is why normalisation is the
constructor's job rather than each caller's.

The last line is the same argument one step further. A BCP 47 tag does not put
the region in a fixed position: for the languages that have more than one script,
the script comes first, so China is the *third* subtag of `zh-Hans-CN`. The
region is therefore found by shape — the first subtag that could be an ISO 3166-1
alpha-2 code — with scripts, extlangs and variants skipped and a singleton
(`en-US-x-private`) ending the search. Reading the second subtag positionally
gave `zh_HANS`, a key naming no locale, and because the chain still reached bare
`zh` the deployment saw Chinese text and never learnt that its `zh_CN` bundle was
unreachable.

That shape is enforced rather than assumed. A country that is not two letters
raises `TomResourceLocaleException` instead of becoming an unmatchable bundle
key:

```dart
TomTextLocale('de', 'AUT');            // throws
TomTextLocale.lenient('de', 'AUT').tag; // 'de'
```

Use `TomTextLocale.lenient` for a value this process does not control. A
principal's country and a 2FA context's arrive from a client request, and a
client sending `AUT` should cost the country, not the delivery — so those paths
drop an unusable country rather than refuse it. A bundle for the bare language
exists; the refused key never did.

For a user, `TomTextLocale.fromPrincipal` reads the locale off the principal
(leniently, for exactly that reason):

```dart
final locale = TomTextLocale.fromPrincipal(principal); // may be null
```

The **stored** language (`TomPrincipal.language` / `.country`) wins over the
client device's (`.clientLanguage` / `.clientCountry`). A mail is read later,
often elsewhere, so the user's recorded preference is the durable answer; the
device locale is a fact about one sign-in and serves only when there is no
preference to honour. A principal that names neither yields `null` rather than a
guess, so the deployment's default locale is applied in one place instead of
each caller inventing `'en'`.

## The Fallback Chain

A lookup walks, in order:

1. the requested locale's exact tag (`de_AT`),
2. its bare language (`de`),
3. the default locale's tag, then its bare language.

Per **key**, not per bundle. A half-translated `de` bundle therefore serves the
strings it has and falls through to the default locale for the rest, which is
what a translation in progress actually looks like. The alternative — a bundle
being all-or-nothing — means the first untranslated key silently reverts a whole
message to another language.

```dart
texts.textOrNull('email.password_reset.subject', locale: TomTextLocale('de', 'AT'));
// de_AT if it has the key, else de, else the default locale
```

*Which* locale the chain ends at belongs to the deployment. `defaultLocale` is a
required constructor argument with no framework-supplied value, so a set built
with `TomTextLocale('fr')` falls through to French. There is no privileged
language, and that is deliberate: a built-in English would be precisely the
ambient assumption this module exists to remove.

`resolveLocale` reports which bundle a lookup *would* read from, so a caller that
must state the language it rendered — a `Content-Language` header, a stored copy
of a sent mail — can say so truthfully rather than echoing what was asked for.

It answers `null` when the chain reaches no bundle, which is not the same as the
set being empty. Every chain ends with the default locale's own tags, so `null`
says precisely that the set carries no bundle for its **default** locale — a set
holding only `fr` with a default of `en` answers `null` for `de` while carrying a
perfectly usable `fr`. That distinction matters because the usual
`resolveLocale(requested) ?? defaultLocale` reads as dead code to anyone who took
`null` for "empty", when it is the branch that fires on exactly that wiring fault
— and names a language nothing was rendered in.

### Asking the other question

`exists` follows the chain, which is right for "will this render". A
**completeness check** wants the opposite: whether somebody actually wrote the
German. `exists` answers `true` for every key the default locale carries, so a
test built on it passes on a `de` bundle that is entirely empty — precisely the
gap such a test exists to find. `isTranslated(key, locale)` is un-chained and
answers that question:

```dart
texts.exists('email.password_reset.text', locale: austrian);      // true — via the default (en)
texts.isTranslated('email.password_reset.text', austrian);        // false
```

`advanced_ops_server`'s `ops_digest_test.dart` uses it to turn a translation gap
into a red suite rather than a blank line in somebody's mail.

## A Miss Is Null, Never the Key

`TomTextResourceProvider.getText` answers an unknown key with the key itself. On
a screen that is the right failure: the button reads
`two_factor.totp.enrol.submit`, which is unmistakable and gets fixed. In an
email it is not — nobody sees the subject line before the recipient does.

So this module offers only `textOrNull`, and the caller decides how loudly to
fail. `TomEmailService` fails at send, before anything is queued.

## Parameters

Placeholders use the same `{name}` convention as the client's parameterised
text, so one bundle serves both tiers and a translator sees one placeholder
syntax rather than two:

```yaml
email:
  password_reset:
    subject: "Reset your password, {firstname}"
```

```dart
texts.textOrNull(
  'email.password_reset.subject',
  locale: locale,
  parameters: {'firstname': principal.user.firstname},
);
```

A placeholder with no matching parameter is left as written rather than blanked
or reported. Bodies legitimately contain braces — inline CSS above all — so
treating an unmatched brace as a fault would fail on correct templates; and a
*visible* `{firstname}` in a proof-read mail is caught by the person proof-reading
it, which an empty gap is not.

A parameter whose value is `null` counts as absent, so it lands in exactly that
case. `parameters` is `Map<String, Object?>` and the example above shows why:
`TomUser.firstname` is nullable, so a caller writing the obvious thing hands over
a null without meaning anything by it. Interpolating it would produce `Reset your
password, null` — text that reads as finished and so slips past the proof-reader
the rule above depends on. Leaving `{firstname}` standing puts the missing value
where somebody will see it.

`TomLocalizedTextResources.substitute` is exposed as a static so a caller holding
text from elsewhere — a database column, a message already resolved — substitutes
it the same way rather than writing a second `replaceAll` loop.

## Installing a Bundle Set

```dart
final texts = TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': loadYamlMap('resources/text_en.yaml'),
    'de': loadYamlMap('resources/text_de.yaml'),
  },
);

TomBean.withType(TomLocalizedTextResources, texts);
```

`TomLocalizedTextResources.ofProviders` takes providers that are already
constructed, for a deployment whose bundles come from somewhere with its own
loading rules — a database, an asset archive, `TomTextResourceProvider.load`.

`TomLocalizedTextResources.resolve()` answers the installed bean, or `null`. It
is nullable with **no** fallback: an empty default would render every message
blank, and a blank message that was *sent* is worse than a wiring error that was
raised.

## Core Components

| Component | File | Responsibility |
| --------- | ---- | -------------- |
| `TomTextLocale` | `localized_text_resources.dart` | Normalised language/country pair; parsing, the fallback tags, derivation from a principal |
| `TomLocalizedTextResources` | `localized_text_resources.dart` | Bundle-per-locale storage, chain resolution, parameter substitution, bean lookup |
| `TomResourceLocaleException` | `localized_text_resources.dart` | A locale that cannot be formed; not client-visible |

## Dependencies

- `tom_core_kernel` — `TomTextResourceProvider` (the resolution this module
  layers over), `TomPrincipal`, `TomBean`.
- `little_things` — `TomServerException`, the base of
  `TomResourceLocaleException`.

Consumers: the messaging module's `TomEmailService` (see `doc/messaging.md`).
Any server-side text rendered *for a user* rather than *for the process* belongs
here.
