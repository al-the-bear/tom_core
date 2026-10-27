# Tom Core Kernel API Reference: Settings Module

The message and result classes for retrieving client-specific settings,
authorization context, and localization data from the server; and feature
flags — the flag API, its OpenFeature-shaped provider contract, the rule-based
and static providers, and the `/feature-flags` API a client fetches its flags
from.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomGetSettingsMessage](#tomgetsettingsmessage)
  - [TomGetSettingsResult](#tomgetsettingsresult)
  - [TomFeatureFlags](#tomfeatureflags)
  - [TomFlagContext](#tomflagcontext)
  - [TomFlagResolution](#tomflagresolution)
  - [TomFlagProvider](#tomflagprovider)
  - [TomStaticFlagProvider](#tomstaticflagprovider)
  - [TomFlagRule](#tomflagrule)
  - [TomFlagDefinition](#tomflagdefinition)
  - [TomRuleFlagProvider](#tomruleflagprovider)
  - [TomFeatureFlagsClient](#tomfeatureflagsclient)
  - [TomFeatureFlagsException](#tomfeatureflagsexception)
- [Enums](#enums)
  - [TomFlagResolutionReason](#tomflagresolutionreason)
- [Global Functions and Constants](#global-functions-and-constants)
- [The tomFeatureFlagsApi Endpoint](#the-tomfeatureflagsapi-endpoint)

## Overview

Sources: `lib/src/tombase/settings/settings_client_authorization.dart`,
`lib/src/tombase/settings/feature_flags.dart`,
`lib/src/tombase/settings/feature_flags_contract.dart`.

This module defines the request/response pair used by clients to obtain their
configuration and authorization from the server. `TomGetSettingsMessage` carries
the authorization token that authenticates the settings request.
`TomGetSettingsResult` carries the server's response: text and configuration
resources, the user's authorization context (groups, roles, entitlements,
resource keys), the application context (organization, process, application),
and localization preferences (server- and client-side country, language and
timezone). Both classes are annotated with `@tomReflector` for reflected
serialization.

Feature flags are read through `TomFeatureFlags`, which asks the installed
`TomFlagProvider` and never throws: an unknown flag, a value of another type or
a failing provider answer the caller's default, with a
`TomFlagResolutionReason` saying why. `TomRuleFlagProvider` holds
`TomFlagDefinition`s whose `TomFlagRule`s target tenants, roles and a stable
percentage of principals; `TomStaticFlagProvider` holds values already
evaluated — a client's snapshot, fetched by `TomFeatureFlagsClient.fetch` from
`GET /feature-flags` (`tomFeatureFlagsApi`).

## Class Hierarchy

```
TomGetSettingsMessage  (@tomReflector)

TomGetSettingsResult  (@tomReflector)

TomFeatureFlags          (abstract final, static-only)
TomFlagContext
TomFlagResolution<T>
TomFlagRule
TomFlagDefinition

TomFlagProvider          (abstract)
├── TomStaticFlagProvider
└── TomRuleFlagProvider

TomFeatureFlagsClient    (abstract final, static-only)

TomException
└── TomFeatureFlagsException
```

## Classes

### TomGetSettingsMessage

Message class for requesting client settings from the server. It encapsulates
the authorization token the server uses to determine which settings and
permissions to return.

- **Annotations:** `@tomReflector` — reflected JSON serialization. The field is
  mutable and the class declares no constructor, so the deserializer can create
  an instance and assign into it.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authorizationToken` | `String?` | The authorization token (typically a JWT bearer token) authenticating the settings request. Default `null`: the field has no initializer, so an unset token is `null` however the message was built — the convention every string on `TomGetSettingsResult` follows. A server treats `null` and empty alike, as an anonymous request it may answer with default settings. |

### TomGetSettingsResult

Result class containing client settings, authorization data, and localization —
everything a client needs to configure itself.

- **Annotations:** `@tomReflector` — reflected JSON serialization. Every field
  is mutable and every constructor parameter optional, so the deserializer can
  create an instance and assign into it.
- **Mutable on the client by design.** The authorization lists decide what a
  client shows, never what it may do — the server judges every call against the
  bearer token's principal — so a client editing its copy grants itself
  nothing. A consumer wanting a guard takes an unmodifiable snapshot
  (`Set.unmodifiable(settings.roles)`) where it receives the result.

#### Constructors

```dart
TomGetSettingsResult({
  Map<String, Object?>? texts,
  Map<String, Object?>? config,
  Iterable<String>? groups,
  Iterable<String>? roles,
  Iterable<String>? entitlements,
  Iterable<String>? resourceKeys,
  String? organization,
  String? process,
  String? application,
  String? country,
  String? language,
  String? timezone,
  String? clientLanguage,
  String? clientCountry,
  String? clientTimezone,
})
```

All collection parameters default to fresh, empty mutable collections so callers
can mutate them in place. All string parameters default to `null`, and the
fields carry no initializer either, so an unset string is `null` however the
instance was made — including through the reflected deserialization path, which
is how a client receives one. `null` therefore means "the server did not set
this", distinguishably from an organization or language the server deliberately
answered as the empty string. Consumers must null-check rather than reach for
`.isEmpty`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `texts` | `Map<String, Object?>` | Localized text resources for UI rendering. |
| `config` | `Map<String, Object?>` | Application configuration settings that control behavior. |
| `groups` | `Set<String>` | Security groups the user belongs to (server-authoritative). |
| `roles` | `Set<String>` | Roles assigned to the user (e.g. `admin`, `editor`, `viewer`). |
| `entitlements` | `Set<String>` | Fine-grained permissions for specific features or operations. |
| `resourceKeys` | `Set<String>` | Resource keys (screens, modules, data sets) the user may access. |
| `organization` | `String?` | The organization context for this session (default `null`). |
| `process` | `String?` | The business process/workflow context (default `null`). |
| `application` | `String?` | The application identifier selecting the configuration to use (default `null`). |
| `country` | `String?` | Server-determined country for localization — conventionally ISO 3166-1 alpha-2, not validated (default `null`). |
| `language` | `String?` | Server-determined language for localization — conventionally ISO 639-1, not validated (default `null`). |
| `timezone` | `String?` | Server-determined timezone for the session — conventionally an IANA identifier, not validated (default `null`). |
| `clientCountry` | `String?` | Client's preferred country — conventionally ISO 3166-1 alpha-2, not validated (default `null`). |
| `clientLanguage` | `String?` | Client's preferred language — conventionally ISO 639-1, not validated, so a regional tag passes through (default `null`). |
| `clientTimezone` | `String?` | Client's timezone — conventionally an IANA identifier (e.g. `America/New_York`), not validated (default `null`). |

The localization formats are conventions: every field is a plain string that
neither the constructor nor the deserializer checks, so a consumer relying on a
format validates it where it uses the value.

Localization is carried in server/client pairs — `country`/`clientCountry`,
`language`/`clientLanguage`, `timezone`/`clientTimezone`. The server field is
the decision, the client field the request; `server ?? client` yields the
effective value, and the two differing (with the server field non-`null`) is how
a consumer detects an override. A `null` server field means no opinion was
expressed, not agreement.

### TomFeatureFlags

The flag API. Every read asks `provider`, with the context passed or, without
one, `TomFlagContext.current()`.

- **Kind:** abstract final class; static members only.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `provider` | `TomFlagProvider` | The installed provider; an empty `TomStaticFlagProvider` until one is assigned, so every flag reads its default. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `isEnabled(String flagKey, {bool defaultValue = false, TomFlagContext? context})` | `Future<bool>` | Whether the flag is on. |
| `getString(String flagKey, {required String defaultValue, TomFlagContext? context})` | `Future<String>` | The string value. |
| `getInt(String flagKey, {required int defaultValue, TomFlagContext? context})` | `Future<int>` | The whole-number value. |
| `getDouble(String flagKey, {required double defaultValue, TomFlagContext? context})` | `Future<double>` | The number value; an integral one is widened. |
| `getObject(String flagKey, {required Map<String, Object?> defaultValue, TomFlagContext? context})` | `Future<Map<String, Object?>>` | The structured value. |
| `details<T>(String flagKey, T defaultValue, [TomFlagContext? context])` | `Future<TomFlagResolution<T>>` | The flag resolved as a `T`, with the reason. `defaultValue` with `flagNotFound` when the provider answers `null`, `typeMismatch` when the value is not a `T`, `error` (and the error) when the provider throws. A map value is cast to `Map<String, Object?>`. Never throws. |

### TomFlagContext

Who a flag is evaluated for — OpenFeature's evaluation context.

#### Constructors

```dart
const TomFlagContext({
  String? targetingKey,
  String? tenant,
  Set<String> roles = const {},
  Map<String, Object?> attributes = const {},
})
```

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `current()` | `TomFlagContext` | The context of the current zone: the authenticated `TomPrincipal`'s `qualifiedId` as `targetingKey` and its roles, and `TomTenantContext.currentId`. An unauthenticated or absent principal gives no targeting key and no roles. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `targetingKey` | `String?` | The id percentages are bucketed by, or `null` for no one in particular. |
| `tenant` | `String?` | The tenant, or `null` for none. |
| `roles` | `Set<String>` | The principal's roles. |
| `attributes` | `Map<String, Object?>` | Anything else a provider may target on. |

### TomFlagResolution

The outcome of evaluating one flag, generic in the value type `T`.

#### Constructors

```dart
const TomFlagResolution(
  T value,
  TomFlagResolutionReason reason, {
  String? variant,
  Object? error,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `value` | `T` | The value the caller receives. |
| `reason` | `TomFlagResolutionReason` | Why it is this value. |
| `variant` | `String?` | The deciding rule, `rule:<index>`, or `null`. |
| `error` | `Object?` | What went wrong, for `TomFlagResolutionReason.error`. |
| `usedCallerDefault` | `bool` | Whether the caller's default was used for want of a value — `flagNotFound`, `typeMismatch` or `error`. |

### TomFlagProvider

A source of flag values — the OpenFeature provider contract, reduced to one
generic resolution. `TomFeatureFlags` checks the type and falls back to the
caller's default, so a provider never has to.

- **Kind:** abstract class.

#### Constructors

```dart
const TomFlagProvider()
```

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve(String flagKey, TomFlagContext context)` | `FutureOr<TomFlagResolution<Object?>?>` | The raw value of the flag with its reason, or `null` when the flag is unknown. Abstract. |
| `evaluateAll(TomFlagContext context)` | `FutureOr<Map<String, Object?>>` | Every flag this provider can answer for the context, by key — what a client fetches. Answers an empty map unless overridden. |

### TomStaticFlagProvider

A provider of fixed values: a client's snapshot of what the server evaluated for
it, or a test's.

- **Extends:** `TomFlagProvider`.

#### Constructors

```dart
const TomStaticFlagProvider(Map<String, Object?> values)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `values` | `Map<String, Object?>` | The values, by flag key. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve(String flagKey, TomFlagContext context)` | `TomFlagResolution<Object?>?` | The value with reason `staticValue`, or `null` for a key it does not hold. |
| `evaluateAll(TomFlagContext context)` | `Map<String, Object?>` | `values`. |

### TomFlagRule

One targeting rule of a `TomFlagDefinition`. A rule matches when every
condition it states holds; a condition left `null` matches everyone.

#### Constructors

```dart
const TomFlagRule({
  required Object? value,
  Set<String>? tenants,
  Set<String>? roles,
  num? percentage,
})
```

Asserts `percentage` is 0 to 100.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `value` | `Object?` | The value the rule gives. |
| `tenants` | `Set<String>?` | The tenants it applies to, or `null` for any. |
| `roles` | `Set<String>?` | The roles it applies to — one suffices — or `null` for any principal. |
| `percentage` | `num?` | The share of principals it applies to, 0 to 100 (fractions allowed), or `null` for all. A context without a targeting key is in no percentage. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `matches(String flagKey, TomFlagContext context)` | `bool` | Whether the rule applies to the context for the flag. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `bucketOf(String flagKey, String targetingKey)` | `int` | The bucket, 0 to 9999: the first four bytes of SHA-256(`<flagKey>:<targetingKey>`) modulo 10 000. A percentage `p` takes the buckets below `p * 100`, so a principal stays in or out across requests and processes and raising the percentage only adds principals. |

### TomFlagDefinition

A flag: its default and its rules.

#### Constructors

```dart
const TomFlagDefinition({
  required String key,
  required Object? defaultValue,
  List<TomFlagRule> rules = const [],
  bool exposed = false,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The flag key. |
| `defaultValue` | `Object?` | The value when no rule matches. |
| `rules` | `List<TomFlagRule>` | The rules, tried in order. |
| `exposed` | `bool` | Whether a client may read the flag. A flag is server-only unless it says so. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `evaluate(TomFlagContext context)` | `TomFlagResolution<Object?>` | The first matching rule's value — reason `split` for a percentage rule, else `targetingMatch`, variant `rule:<index>` — or `defaultValue` with reason `defaultValue`. |

### TomRuleFlagProvider

The built-in provider: flag definitions held in memory, usually read from
configuration.

- **Extends:** `TomFlagProvider`.

#### Constructors

```dart
TomRuleFlagProvider(Iterable<TomFlagDefinition> flags)
```

#### Factory Constructors

| Constructor | Description |
| ----------- | ----------- |
| `TomRuleFlagProvider.fromConfiguration(Object? config)` | The flags of a map from flag key to definition (`default`, optional `rules` and `exposed`; a rule's `value`, optional `tenants`, `roles`, `percentage`). A key is letters, digits, `.`, `_`, `-`, starting with a letter or digit. Throws a `FormatException` naming the flag for an unknown setting or a value of the wrong shape. YAML maps and lists become plain Dart ones. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `flags` | `Map<String, TomFlagDefinition>` | The flags, by key. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve(String flagKey, TomFlagContext context)` | `TomFlagResolution<Object?>?` | The flag evaluated for the context, or `null` for an unknown key. |
| `evaluateAll(TomFlagContext context)` | `Map<String, Object?>` | Every `exposed` flag evaluated for the context — what the server hands a client. Server-only flags are left out. |

### TomFeatureFlagsClient

Fetches a client's feature flags from a Tom server.

- **Kind:** abstract final class; static members only.

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `fetch(Uri baseUri, {String? bearerToken, http.Client? client})` | `Future<TomStaticFlagProvider>` | `GET /feature-flags` against `baseUri`, as the caller `bearerToken` authenticates (anonymous without one), answered as a provider to install in `TomFeatureFlags.provider`. `client` defaults to the framework's outgoing client, closed after the call. Throws `TomFeatureFlagsException` (`feature_flags.fetch.failed`) when the server does not answer `200` with a `flags` map, or the call fails. |

### TomFeatureFlagsException

Thrown when a client cannot fetch its feature flags. The key is
`feature_flags.fetch.failed`; `parameters` carries the `uri`, and the `status`
when the server answered.

- **Extends:** `TomException`.

#### Constructors

```dart
TomFeatureFlagsException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

## Enums

### TomFlagResolutionReason

Why a flag resolved to the value it did — OpenFeature's resolution reasons.

| Value | Meaning |
| ----- | ------- |
| `defaultValue` | The flag's own default: no rule matched. |
| `targetingMatch` | A rule targeting the tenant or the roles matched. |
| `split` | A percentage rule placed the principal in the rollout. |
| `staticValue` | The value is fixed, not evaluated per context. |
| `flagNotFound` | The flag is unknown to the provider; the caller's default was used. |
| `typeMismatch` | The flag's value is of another type; the caller's default was used. |
| `error` | The provider failed; the caller's default was used. |

## Global Functions and Constants

| Name | Type | Description |
| ---- | ---- | ----------- |
| `tomFeatureFlagsApiId` | `String` | `tomFeatureFlags` — the id the API is registered and bound under. |
| `tomFeatureFlagsEvaluateEndpointId` | `String` | `evaluateFlags` — the id of its one endpoint. |
| `tomFeatureFlagsApi` | `TomApi` | The feature-flag API — see below. |
| `registerTomFeatureFlagsApi()` | `void` | Registers `tomFeatureFlagsApi` with the global `tomRemoteApis` registry; idempotent. |

## The tomFeatureFlagsApi Endpoint

Base URI `/feature-flags`, under `TomPublicAccess`: an anonymous caller is
evaluated too, as no one in particular.

| Endpoint id | Method | URI | Request type | Result |
| ----------- | ------ | --- | ------------ | ------ |
| `evaluateFlags` | GET | `` | — | `{"flags": {"<key>": <value>, ...}}` — every flag the server exposes to clients, evaluated for the caller |
