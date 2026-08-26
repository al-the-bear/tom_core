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
  - [Two ways to read a principal's locale](#two-ways-to-read-a-principals-locale)
- [The Fallback Chain](#the-fallback-chain)
  - [Asking the other question](#asking-the-other-question)
- [A Miss Is Null, Never the Key](#a-miss-is-null-never-the-key)
- [Parameters](#parameters)
- [Installing a Bundle Set](#installing-a-bundle-set)
  - [The keys are validated, not just normalised](#the-keys-are-validated-not-just-normalised)
- [Core Components](#core-components)
- [Verification](#verification)
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

Shape is necessary and not sufficient, though, and the insufficiency is the
common case rather than an edge one. ISO 3166-1 permanently withholds `AA`,
`QM`–`QZ`, `XA`–`XZ` and `ZZ` from assignment so that applications can use them
privately, and applications do: this stack writes `XX` for "no country", CLDR
writes `ZZ`. They are two letters, so a shape check admits precisely the class
of value guaranteed never to name a bundle.

```dart
TomTextLocale('en', 'XX');              // throws — XX is not a country
TomTextLocale.lenient('en', 'XX').tag;  // 'en'
```

`XX` is not a value somebody has to go out of their way to produce.
`TomLoginMessage.clientCountry` **defaults** to it, so any client whose device
names no region sends it verbatim and it lands on `TomPrincipal.clientCountry`
through an ordinary sign-in. Before the range was refused, `fromPrincipal` built
`en_XX` from exactly that principal — a key nothing carries, resolved through
bare `en`, reported nowhere. The text came out right and the deployment could
not learn that its regional bundles were unreachable.

The kernel's `TomContextProviders.getCountry` answers the same sentinel, which
is where the other half of this belongs — see [Two Ways to Read a Principal's
Locale](#two-ways-to-read-a-principals-locale).

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

### Two Ways to Read a Principal's Locale

`fromPrincipal` is not the only thing that reads those fields. The kernel's
`TomContextProviders` exposes all four as context entries —
`getLanguage`, `getCountry`, `getClientLanguage`, `getClientCountry`. The two
are not rivals, because they answer different questions:

| | `TomContextProviders` | `TomTextLocale.fromPrincipal` |
| --- | --- | --- |
| Reads | one named field | the stored pair, else the device pair |
| When absent | a sentinel (`'en'`, `'XX'`) | `null` |
| Answers | *what the principal says* | *what to render in* |

The kernel's accessors deliberately do not choose between the pairs: a caller
that needs one specific claim — an audit entry recording what the device said, a
diagnostic naming what the user chose — must be able to ask for that one and not
be handed a blend. **`fromPrincipal` is authoritative for rendering text for a
recipient**, and it is the only one of the two that makes the precedence
decision.

What makes this worth stating is that the accessors *compose*, and composing
them looks like the obvious route to a locale:

```dart
TomTextLocale(TomExecutionContext.getLanguage(), TomExecutionContext.getCountry());
```

For a principal that names no locale, that reads `'en'` and `'XX'` — and `en_XX`
is a bundle key nothing carries. Because the country invariant refuses the
user-assigned range, this now throws rather than falling through to `en` in
silence. Reach for `fromPrincipal` instead, and let the `null` fall through to
the deployment's default.

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
    'en': TomYaml.loadYamlFile('resources/text_en.yaml'),
    'de': TomYaml.loadYamlFile('resources/text_de.yaml'),
  },
);

TomBean.withType(TomLocalizedTextResources, texts);
```

`TomYaml.loadYamlFile` comes from the configuration module and is the usual
source on this tier; it throws `PathNotFoundException` when the file is absent,
which is the right failure for a bundle the deployment declared. For a message
naming the path, check `existsSync` first — `advanced_ops_server`'s
`ops_texts.dart` does, because a bundle missing from a container image is
otherwise reported as a bare filesystem error at startup.

`TomLocalizedTextResources.ofProviders` takes providers that are already
constructed, for a deployment whose bundles come from somewhere with its own
loading rules — a database, an asset archive, `TomTextResourceProvider.load`.

`TomLocalizedTextResources.resolve()` answers the installed bean, or `null`. It
is nullable with **no** fallback: an empty default would render every message
blank, and a blank message that was *sent* is worse than a wiring error that was
raised.

### The Keys Are Validated, Not Just Normalised

Constructing a bundle set parses every key, so the map is not merely data: a key
that names **no language** raises `TomResourceLocaleException` at construction.

```dart
TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {'': {'greeting': 'Hello'}},  // throws resources.locale.empty_language
);
```

That is an empty key, a blank one, or one whose first subtag is empty (`_AT`).
Everything else parses — `parse` finds the region by shape and drops what cannot
be one, so `es-419` and `en_XX` become `es` and `en` rather than being refused.
A missing language is the one thing it cannot recover from. The check lives in
`ofProviders`, which the factory delegates to, so both constructors carry it.

Worth expecting because of where keys come from. Deriving them from file names
(`text_de-AT.yaml` → `de-AT`) is the documented pattern, so a stray `text_.yaml`
or a mis-globbed directory entry is a **bootstrap failure** — and the message
names a locale rather than the file that produced it. Where the path is worth
reporting, check it at the loader; `advanced_ops_server`'s `ops_texts.dart` does
exactly that for a missing file.

The other consequence of normalising into a map is quieter: two keys can name
one locale, and the last of them wins with nothing said.

```dart
bundles: {'en': {...}, 'en_XX': {...}}  // one bundle; the second wins
```

Usually that is the intent — `de-AT` and `de_AT` *should* be one bundle. It
stops being the intent when the second key is one the deployment believed was a
separate regional variant: `en_XX` looks like a country and is not one, so
`locales` reports a single `en` and the set is indistinguishable from one
written that way on purpose.

## Core Components

| Component | File | Responsibility |
| --------- | ---- | -------------- |
| `TomTextLocale` | `localized_text_resources.dart` | Normalised language/country pair; parsing, the fallback tags, derivation from a principal |
| `TomLocalizedTextResources` | `localized_text_resources.dart` | Bundle-per-locale storage, chain resolution, parameter substitution, bean lookup |
| `TomResourceLocaleException` | `localized_text_resources.dart` | A locale that cannot be formed; not client-visible. Raised by `TomTextLocale`'s constructor — and so by the bundle-set constructors, which parse their keys |

## Verification

`test/resources_test.dart` covers the module: naming a locale — case folding,
both separator conventions, the region found by shape rather than by position,
the countries that are refused (the malformed ones, and the user-assigned codes
that are well-formed but can never name one) and the boundary variant that drops
one instead — and resolving through a bundle set, where the per-key fall-through, the
configured default, the `null` for a miss, parameter substitution and the
`exists`/`isTranslated`/`resolveLocale` distinctions are each pinned.

The bundle keys are pinned on both sides: the language-less ones that throw
(through each constructor separately, since a deployment loading from a database
reaches only `ofProviders`), the ones that merely normalise, and the pair that
collapses onto a single tag.

It renders against `test/fixtures/localized_texts.dart`, a deliberately
half-translated set that `test/email_service_test.dart` shares. That
incompleteness is the point of the fixture: against a fully translated set, an
implementation ignoring the locale altogether passes every assertion.

`advanced_ops_server`'s `ops_digest_test.dart` shows the other use — turning a
translation gap into a red suite rather than a blank line in somebody's mail.

## Dependencies

- `tom_core_kernel` — `TomTextResourceProvider` (the resolution this module
  layers over), `TomPrincipal`, `TomBean`.
- `little_things` — `TomServerException`, the base of
  `TomResourceLocaleException`.

Not a dependency of the module, but of anyone installing one: the
**configuration** module supplies `TomYaml.loadYamlFile`, which is how a bundle
gets from a YAML file into the `bundles` map (see `doc/configuration.md`). This
module takes maps and does not read files, so the loader is the caller's choice
— but it is the same loader the rest of the tier uses, and that buys one thing
worth having: `loadYamlFile` expands `${VAR}` and `${VAR:default}` from the
environment, so a bundle can carry a deployment-specific support address or base
URL without a second mechanism for getting it there.

Consumers: the messaging module's `TomEmailService` (see `doc/messaging.md`).
Any server-side text rendered *for a user* rather than *for the process* belongs
here.
