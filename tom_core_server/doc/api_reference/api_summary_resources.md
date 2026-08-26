# Tom Core Server API Reference: Resources Module

Locale-aware text resolution for the server: one `TomTextResourceProvider` per
locale, plus the rule for picking one from the recipient's language rather than
the process's.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomResourceLocaleException](#tomresourcelocaleexception)
  - [TomTextLocale](#tomtextlocale)
  - [TomLocalizedTextResources](#tomlocalizedtextresources)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/resources/localized_text_resources.dart`.

The kernel's `TomTextResourceProvider` holds one bundle and is swapped when the
user's language changes — correct on a client, wrong on a server, which renders
for many users in many languages concurrently. This module makes the locale an
argument instead of ambient state, and adds nothing else: the dot-notation walk,
the flat-key fallback and the String check all remain the provider's, so a key
resolves identically in a bundle whether the client or the server reads it.

`TomTextLocale` is a normalised language/country pair — case-folded, accepting
both `de_AT` and `de-AT`, and derivable from a `TomPrincipal`.
`TomLocalizedTextResources` maps locale tags to providers and resolves a key
along a fallback chain (exact tag, bare language, then the default locale's
chain) **per key**, so a half-translated bundle serves what it has and falls
through for the rest. A miss answers `null` rather than echoing the key: the
provider's key-as-fallback is right on a screen and unacceptable in a subject
line, so the caller decides how loudly to fail. `TomResourceLocaleException`
reports a locale that cannot be formed.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomResourceLocaleException

TomTextLocale
TomLocalizedTextResources
```

## Classes

### TomResourceLocaleException

Raised when a locale cannot be formed from what a caller supplied. Not
client-visible (`clientThrow` defaults to `false`): the malformed value came from
configuration or a user record, and quoting it back to a browser describes the
deployment rather than the fault.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomResourceLocaleException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
  bool clientThrow = false,
})
```

### TomTextLocale

A language, optionally narrowed by a country. Not `dart:ui`'s `Locale` (which
would drag Flutter into a server package) and not a bare `String` (which would
leave every call site to decide whether `de-AT`, `de_AT` and `DE_at` are the same
bundle — they are).

- **Extends:** none

#### Constructors

```dart
TomTextLocale(String language, [String? country])
factory TomTextLocale.parse(String tag)
```

`TomTextLocale` lowercases the language, uppercases the country, and treats a
blank country as none. An empty language raises `TomResourceLocaleException`.
`parse` accepts both `_` and `-` as the separator.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `language` | `String` | ISO 639-1, lowercase. |
| `country` | `String?` | ISO 3166-1 alpha-2, uppercase; `null` when the locale names only a language. |
| `tag` | `String` | The bundle key: `de` or `de_AT`. |
| `fallbackTags` | `List<String>` | This locale's tags from most to least specific. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromPrincipal` | `static TomTextLocale? fromPrincipal(TomPrincipal principal)` | The locale to render for a principal, or `null` when it names none. The stored `language`/`country` wins over the device's `clientLanguage`/`clientCountry`. |
| `operator ==` / `hashCode` | — | Equality is by `tag`, so a locale can key a bundle map. |

### TomLocalizedTextResources

One `TomTextResourceProvider` per locale, plus the rule for picking one.

- **Extends:** none

#### Constructors

```dart
factory TomLocalizedTextResources({
  required Map<String, Map<String, dynamic>> bundles,
  required TomTextLocale defaultLocale,
})

TomLocalizedTextResources.ofProviders({
  required Map<String, TomTextResourceProvider> bundles,
  required TomTextLocale defaultLocale,
})
```

The default constructor builds providers from raw resource maps keyed by locale
tag; tags are normalised through `TomTextLocale.parse`, so `text_de-AT.yaml` and
`text_de_AT.yaml` name the same bundle. `ofProviders` takes providers that are
already constructed, for bundles loaded from a database or an asset archive.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultLocale` | `TomTextLocale` | The locale that answers when the requested one has nothing to say. |
| `locales` | `List<String>` | The locale tags this set carries, in insertion order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `textOrNull` | `String? textOrNull(String key, {TomTextLocale? locale, Map<String, Object?> parameters = const {}})` | The text at `key` for `locale`, with `{name}` placeholders substituted; `null` when no bundle in the chain has the key. |
| `exists` | `bool exists(String key, {TomTextLocale? locale})` | Whether `key` resolves anywhere in the fallback chain — "will a render find something". |
| `isTranslated` | `bool isTranslated(String key, TomTextLocale locale)` | Whether `key` is in that locale's **own** bundle, un-chained — "did somebody write this translation". |
| `hasLocale` | `bool hasLocale(TomTextLocale locale)` | Whether a bundle exists for the locale's **exact** tag — "did this deployment ship this bundle". |
| `resolveLocale` | `TomTextLocale? resolveLocale(TomTextLocale? locale)` | The locale a lookup would read from, following the fallback chain; `null` when the set carries nothing. |
| `substitute` | `static String substitute(String template, Map<String, Object?> parameters)` | Substitutes `{name}` in a template. Exposed so text from elsewhere is substituted the same way. |
| `resolve` | `static TomLocalizedTextResources? resolve()` | The bundle set this deployment installed, or `null`. Nullable with no fallback: an empty default would render every message blank. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
