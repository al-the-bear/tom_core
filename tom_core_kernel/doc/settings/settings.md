# Settings Module

The Settings module provides client-server communication for retrieving application settings, authorization information, and localization preferences, and the feature flags a deployment switches without a release.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [1. Import the Module](#1-import-the-module)
  - [2. Build the Endpoint](#2-build-the-endpoint)
  - [3. Create a Settings Request](#3-create-a-settings-request)
  - [4. Process the Response](#4-process-the-response)
- [Core Components](#core-components)
  - [TomGetSettingsMessage](#tomgetsettingsmessage)
  - [TomGetSettingsResult](#tomgetsettingsresult)
    - [Constructor](#constructor)
- [Usage Examples](#usage-examples)
  - [Basic Settings Retrieval](#basic-settings-retrieval)
  - [Role-Based Feature Access](#role-based-feature-access)
  - [Localized Text Display](#localized-text-display)
  - [Multi-Tenant Configuration](#multi-tenant-configuration)
- [Best Practices](#best-practices)
  - [1. Cache Settings Appropriately](#1-cache-settings-appropriately)
  - [2. Handle Missing Values Gracefully](#2-handle-missing-values-gracefully)
  - [3. Validate Authorization Early](#3-validate-authorization-early)
  - [4. Separate Concerns](#4-separate-concerns)
  - [5. Use Type-Safe Configuration Access](#5-use-type-safe-configuration-access)
- [Feature Flags](#feature-flags)
  - [Reading a flag](#reading-a-flag)
  - [Rules](#rules)
  - [Defining flags in configuration](#defining-flags-in-configuration)
  - [Providers](#providers)
  - [The client's flags](#the-clients-flags)
  - [Error keys](#error-keys)
- [Dependencies](#dependencies)
  - [What this module does *not* depend on](#what-this-module-does-not-depend-on)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomGetSettingsMessage` | class | Reflected request for client settings. |
| `TomGetSettingsResult` | class | Reflected settings response (texts, roles, …). |
| `TomFeatureFlags` | abstract final class | The flag API: typed reads with a caller default, through the installed provider. |
| `TomFlagContext` | class | Who a flag is evaluated for: targeting key, tenant, roles, attributes. |
| `TomFlagResolutionReason` | enum | Why a flag resolved to its value. |
| `TomFlagResolution` | class | One evaluation: the value, its reason and the deciding rule. |
| `TomFlagProvider` | abstract class | The provider contract, shaped after OpenFeature's. |
| `TomStaticFlagProvider` | class | Fixed values — a client's snapshot, or a test's. |
| `TomFlagRule` | class | A targeting rule: tenants, roles, percentage. |
| `TomFlagDefinition` | class | A flag: its default, its rules, whether a client may read it. |
| `TomRuleFlagProvider` | class | The built-in provider: flag definitions read from configuration. |
| `TomFeatureFlagsException` | class | A client could not fetch its flags (extends `TomException`). |
| `TomFeatureFlagsClient` | abstract final class | Fetches a client's evaluated flags from a server. |

This module enables clients to:
- Request configuration and text resources from the server
- Receive user authorization context (groups, roles, entitlements)
- Obtain localization preferences (country, language, timezone)

The settings system follows a request-response pattern where the client sends a `TomGetSettingsMessage` and receives a `TomGetSettingsResult` containing all necessary configuration data.

The second half of the module is [feature flags](#feature-flags): values read
through `TomFeatureFlags`, evaluated per tenant, role or stable percentage of
principals by the installed `TomFlagProvider`, and fetched by a client from the
server's `GET /feature-flags` (`tomFeatureFlagsApi`).

## Quick Start

### 1. Import the Module

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

### 2. Build the Endpoint

This module declares the two DTOs and nothing else — the exchange runs over
`TomServerEndpoint` from the `http_connection` module. Settings is an ordinary
bearer-authenticated endpoint of the API server, not part of the authentication
exchange, so it addresses the API base URI. Building an endpoint opens no
connection; the channel creates its HTTP client on the first call.

```dart
final endpoint =
    TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult>(
      TomServerChannel('api.example.com', 443),
      TomServerCallSpecs(
        'POST',
        Uri.parse('https://api.example.com/settings'),
        includeBearerAuthentication: true,
      ),
    );
```

A real client takes the host and URI from
`TomClientRemoteContext.current!.baseUri` rather than spelling them out.

### 3. Create a Settings Request

```dart
final message = TomGetSettingsMessage()
  ..authorizationToken = 'Bearer your-jwt-token';
```

### 4. Process the Response

`send` answers a `(result, error)` pair rather than throwing: a refused
connection, an expired deadline and an HTTP error all arrive as an error value,
so the pair has to be checked before the result is read.

```dart
final (result, error) = await endpoint.send(message);
if (error?.hasError ?? false) {
  // No settings to apply — see TomServerCallError.errorKey.
  return;
}

// Access configuration
final theme = result.config['theme'];

// Access localized text
final welcomeMessage = result.texts['welcome'];

// Check authorization
if (result.roles.contains('admin')) {
  // Enable admin features
}
```

## Core Components

Both classes are annotated with `@tomReflector`, and that annotation is why they
are shaped the way they are. The reflected serializer builds an instance through
a zero-argument constructor and then assigns each field by name, so every field
here is public, mutable and non-`final`, and neither class declares a `fromJson`
constructor or a `toJson` method — there is no hand-written serialization in the
module at all. Adding a field to either class is therefore the whole of
extending the wire contract; the [Dependencies](#dependencies) section covers
the `build_runner` step that makes it take effect.

The fields stay mutable on the **client** too, where a result is an answer the
server gave, and that is a decision rather than an oversight. The authorization
lists in a result decide what a client *shows*, never what it may do: the
server judges every call against the principal in the bearer token, so a client
that runs `settings.roles.add('admin')` changes its own screen and grants
itself nothing — the call behind the button it now shows is refused. Protecting
the lists with unmodifiable views, or splitting the type into a mutable server
builder and an immutable client value, would complicate the reflected round
trip for protection the server already provides. Code that wants to guard
itself against editing the answer takes an unmodifiable snapshot where it
receives it, as [Separate Concerns](#4-separate-concerns) shows.

### TomGetSettingsMessage

The request message for fetching settings from the server.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `authorizationToken` | `String?` | `null` | JWT bearer token for authentication |

The field has no initializer, so an unset token is `null` however the message
was built — through the constructor or the reflected deserializer's
zero-argument path — the same convention every string on `TomGetSettingsResult`
follows. A server treats `null` and an empty string alike, as an anonymous
request it may answer with default settings; a server testing the token checks
both (`token == null || token.isEmpty`).

### TomGetSettingsResult

The response containing all settings data.

#### Constructor

Every parameter is named and optional, so the class is constructible with no
arguments at all — which is what the reflected deserializer does before
assigning the fields it found on the wire.

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
});
```

Two default contracts follow from it, and both matter to callers:

- **Every collection defaults to a fresh, empty, mutable collection** — a new
  instance per result, never a shared const. So `result.roles.add(...)` and
  `result.config['k'] = v` work on a result built with no arguments, and two
  results never alias each other's state.
- **Every string defaults to `null`**, and the fields carry no initializer
  either, so an unset string is `null` however the instance was made — including
  through deserialization. `null` therefore means "the server did not set this",
  distinguishably from a value the server deliberately answered as `""`.
  Consumers null-check rather than reach for `.isEmpty`.

The mutable-collection contract exists for the server side, which typically
builds a result incrementally rather than in one call:

```dart
/// The settings this principal gets, assembled as each source is consulted.
TomGetSettingsResult buildSettings(User user, Tenant tenant) {
  // No arguments: every collection starts empty and mutable, every string null.
  final result = TomGetSettingsResult();

  result.texts.addAll(tenant.textBundle);
  result.config.addAll(tenant.defaults);

  for (final role in user.roles) {
    result.roles.add(role.name);
    result.entitlements.addAll(role.entitlements);
  }

  result.organization = tenant.id;
  result.clientLanguage = user.preferredLanguage;

  return result;
}
```

#### Resources

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `texts` | `Map<String, Object?>` | `{}` (fresh) | Localized text resources for UI |
| `config` | `Map<String, Object?>` | `{}` (fresh) | Application configuration values |

#### Authorization

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `groups` | `Set<String>` | `{}` (fresh) | Security groups the user belongs to |
| `roles` | `Set<String>` | `{}` (fresh) | Roles assigned to the user |
| `entitlements` | `Set<String>` | `{}` (fresh) | Fine-grained permissions |
| `resourceKeys` | `Set<String>` | `{}` (fresh) | Accessible resource identifiers |

Sets, because membership is the only question these four are asked: a grant is
held or not, a role the server resolved through two groups is still one role,
and `contains` is a hash lookup. On the wire each travels as a JSON array — a
set is an `Iterable` — and the reflected deserializer builds the set from it,
so a duplicate the server sent collapses on arrival. The constructor takes any
`Iterable<String>` (a principal's ACI lists, say) and copies it into a new set.

#### Application Context

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `organization` | `String?` | `null` | Organization context |
| `process` | `String?` | `null` | Business process identifier |
| `application` | `String?` | `null` | Application identifier |

#### Localization

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `country` | `String?` | `null` | Server-side country — conventionally ISO 3166-1 alpha-2 |
| `language` | `String?` | `null` | Server-side language — conventionally ISO 639-1 |
| `timezone` | `String?` | `null` | Server-side timezone — conventionally an IANA identifier |
| `clientCountry` | `String?` | `null` | Client's preferred country — conventionally ISO 3166-1 alpha-2 |
| `clientLanguage` | `String?` | `null` | Client's preferred language — conventionally ISO 639-1 |
| `clientTimezone` | `String?` | `null` | Client's timezone — conventionally an IANA identifier |

The formats are **conventions, not validation.** Each field is a plain string,
and nothing checks it — not the constructor, not the reflected deserializer.
Country and language are usually ISO codes, but a deployment may need a
regional tag (`'de-CH'`) or an internal code, and a settings DTO that refused an
unexpected value would turn one odd field into a failed settings request. A
consumer that depends on a format checks it where it uses the value — the
kernel's `TomTimezone.fromName` answers `null` for an identifier the timezone
database does not know, which is the point at which that consumer learns it.

The three localization concepts are each carried as a **pair**: the server
states what it decided, the client states what it asked for. A consumer reads
the server field first and falls back to the client one, and compares the two
when it needs to know it was overridden:

```dart
final effectiveZone = settings.timezone ?? settings.clientTimezone;
final zoneOverridden =
    settings.timezone != null && settings.timezone != settings.clientTimezone;
```

A `null` server field means the server expressed no opinion — which is not the
same as agreeing with the client, and is why the fallback and the
override-detection are two different expressions.

## Usage Examples

### Basic Settings Retrieval

```dart
typedef AppStartup = ({String theme, int maxItems, String language, String country});

Future<AppStartup?> initializeApp(
  TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult> endpoint,
) async {
  final message = TomGetSettingsMessage()
    ..authorizationToken = TomBearerAuthentication.authorizationToken;

  final (settings, error) = await endpoint.send(message);
  if (error?.hasError ?? false) return null;

  return (
    theme: settings.config['theme'] as String? ?? 'light',
    maxItems: settings.config['maxItems'] as int? ?? 50,
    language: settings.clientLanguage ?? 'en',
    country: settings.clientCountry ?? 'US',
  );
}
```

### Role-Based Feature Access

```dart
/// The feature keys this principal may use, derived from the settings the
/// server returned.
Set<String> enabledFeatures(TomGetSettingsResult settings) => {
  // Always available.
  'profile',

  // Only for users holding the 'view-reports' entitlement.
  if (settings.entitlements.contains('view-reports')) 'reports',

  // Only for admins.
  if (settings.roles.contains('admin')) 'admin-panel',
};
```

Deciding *what* is enabled is a kernel concern and belongs in plain Dart, as
above; deciding what it *looks like* is not. A UI tier renders from the
returned set and never re-reads `roles` or `entitlements` itself — which is
also why a Flutter app usually skips this step and binds widgets to the
four-state `TomAuthState` model directly.

### Localized Text Display

```dart
String getLocalizedText(TomGetSettingsResult settings, String key) {
  return settings.texts[key]?.toString() ?? 'Missing: $key';
}

// Usage
final welcomeText = getLocalizedText(settings, 'welcome_message');
final errorText = getLocalizedText(settings, 'error_generic');
```

### Multi-Tenant Configuration

```dart
void describeTenant(TomGetSettingsResult settings) {
  print('Organization: ${settings.organization}');
  print('Application: ${settings.application}');
  print('Process: ${settings.process}');

  // Tenant-specific branding travels in `config` like any other value; the
  // module attaches no meaning to it, so the consumer names the keys.
  final branding = settings.config['branding'] as Map<String, Object?>?;
  print('Primary colour: ${branding?['primaryColor'] as String? ?? '#000000'}');
}
```

## Best Practices

### 1. Cache Settings Appropriately

Settings don't change frequently. Cache the result and refresh periodically or on specific events:

```dart
class SettingsCache {
  SettingsCache(this._endpoint);

  final TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult> _endpoint;

  TomGetSettingsResult? _cached;
  DateTime? _lastFetch;

  Future<TomGetSettingsResult?> getSettings() async {
    final cached = _cached;
    if (cached != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < Duration(minutes: 15)) {
        return cached;
      }
    }

    final (result, error) = await _endpoint.send(TomGetSettingsMessage());
    // A failed refresh keeps the previous value rather than emptying the cache.
    if (error?.hasError ?? false) return cached;

    _cached = result;
    _lastFetch = DateTime.now();
    return result;
  }
}
```

### 2. Handle Missing Values Gracefully

Which values need a fallback follows from the
[defaults](#constructor): the eight string fields default to `null` and
arrive as `null` whenever the server left them unset, so each one needs a `??`
at the point of use. The six collections do not — they are always present and
always mutable, so `settings.roles.isEmpty` is a meaningful test rather than a
possible null dereference. Values read out of `texts` and `config` are a third
case: the map is there, but any given key may be absent, and its static type is
`Object?`.

```dart
// String field: may be null, so supply a fallback.
final language = settings.clientLanguage ?? 'en';

// Map entry: the map always exists, the key may not — cast and fall back.
final pageSize = (settings.config['pageSize'] as int?) ?? 20;

// Collection: never null, so no `??` — just ask.
if (settings.roles.isEmpty) { /* unauthorized */ }
```

### 3. Validate Authorization Early

Check required roles/entitlements at app startup:

```dart
void validateAccess(TomGetSettingsResult settings) {
  if (!settings.roles.contains('user')) {
    throw TomException('startup.validate.role_missing', 'User role required');
  }
}
```

### 4. Separate Concerns

Keep the questions the UI asks separate from UI logic, and take the answer as
it arrived — a snapshot the rest of the client cannot edit:

```dart
/// What the signed-in user may be *shown*. The server still judges every call
/// the user makes; these answers only decide which controls appear.
class AuthorizationService {
  AuthorizationService(TomGetSettingsResult settings)
    : _roles = Set.unmodifiable(settings.roles),
      _entitlements = Set.unmodifiable(settings.entitlements),
      _resourceKeys = Set.unmodifiable(settings.resourceKeys);

  final Set<String> _roles;
  final Set<String> _entitlements;
  final Set<String> _resourceKeys;

  bool canViewReports() => _entitlements.contains('view-reports');
  bool canEditUsers() => _roles.contains('admin');
  bool hasResourceAccess(String key) => _resourceKeys.contains(key);
}
```

The snapshot is the consumer's choice, not the result's: a received
`TomGetSettingsResult` is mutable by design (see [Core
Components](#core-components)), and taking the copy here means code elsewhere
that edits the result cannot change what this service answers.

### 5. Use Type-Safe Configuration Access

Create typed accessors for configuration values:

```dart
extension ConfigExtensions on TomGetSettingsResult {
  int get maxUploadSize => (config['maxUploadSize'] as int?) ?? 10485760;
  bool get darkModeEnabled => (config['darkMode'] as bool?) ?? false;
  String get apiVersion => (config['apiVersion'] as String?) ?? 'v1';
}
```

## Feature Flags

A feature flag is a value a deployment switches without a release: a feature on
for one tenant, a role, or a growing share of principals; a limit raised for
one customer. The flags are read through `TomFeatureFlags`, which asks the
installed `TomFlagProvider` — a contract shaped after the OpenFeature provider,
so a vendor or OpenFeature-compatible service can be plugged in without changing
a call site.

### Reading a flag

```dart
if (await TomFeatureFlags.isEnabled('new-checkout')) {
  // the new checkout
}
final limit = await TomFeatureFlags.getInt(
  'export-row-limit',
  defaultValue: 1000,
);
```

| Member | Returns | Description |
| ------ | ------- | ----------- |
| `isEnabled(flagKey, {defaultValue = false, context})` | `Future<bool>` | Whether the flag is on. |
| `getString(flagKey, {required defaultValue, context})` | `Future<String>` | A string flag. |
| `getInt(flagKey, {required defaultValue, context})` | `Future<int>` | A whole-number flag. |
| `getDouble(flagKey, {required defaultValue, context})` | `Future<double>` | A number flag; an integral value reads as a `double`. |
| `getObject(flagKey, {required defaultValue, context})` | `Future<Map<String, Object?>>` | A structured flag. |
| `details<T>(flagKey, defaultValue, [context])` | `Future<TomFlagResolution<T>>` | The value with its reason and the deciding rule. |
| `provider` | `TomFlagProvider` | The installed provider; without one every flag reads its default. |

**A read never throws.** An unknown flag, a value of another type and a provider
that fails all answer the caller's default; `details` says which, as
`TomFlagResolutionReason.flagNotFound`, `typeMismatch` or `error` (the last with
the provider's error in `TomFlagResolution.error`). `usedCallerDefault` is true
for exactly those three. A value that came from the flag says how:
`defaultValue` (no rule matched), `targetingMatch` (a tenant or role rule),
`split` (a percentage rule) or `staticValue` (a fixed snapshot), and `variant`
names the deciding rule as `rule:<index>`.

**Who is asking** is taken from the zone unless a `context` is passed:
`TomFlagContext.current()` reads the authenticated principal's qualified id (the
`targetingKey`) and roles, and the tenant of `TomTenantContext`. An
unauthenticated principal is no one in particular — no targeting key, no roles.
On a server every request runs in such a zone, so a handler reads flags for its
caller without passing anything.

```dart
final forAcme = await TomFeatureFlags.isEnabled(
  'new-checkout',
  context: const TomFlagContext(tenant: 'acme', roles: {'beta'}),
);
```

### Rules

A `TomFlagDefinition` has a `defaultValue` and `rules`, tried in order; the
first `TomFlagRule` that matches gives its `value`. A rule matches when every
condition it states holds:

| Condition | Matches when |
| --------- | ------------ |
| `tenants` | The context's tenant is one of them. |
| `roles` | The principal holds at least one of them. |
| `percentage` | The principal falls in the first `percentage` percent (0 to 100, fractions allowed) of the flag's buckets. A context without a targeting key is in no percentage. |

A condition left out matches everyone. The bucket (`TomFlagRule.bucketOf`) is
the first four bytes of SHA-256(`<flagKey>:<targetingKey>`) modulo 10 000, so a
principal stays in or out of a rollout across requests and processes, every
flag rolls out to a different slice of principals, and raising the percentage
only adds principals.

### Defining flags in configuration

`TomRuleFlagProvider.fromConfiguration` reads a map from flag key to definition
— on a server, the `featureFlags` key of the configuration resources:

```yaml
featureFlags:
  new-checkout:
    default: false
    exposed: true                  # a client may read it
    rules:
      - tenants: [acme]
        value: true
      - roles: [beta-tester]
        value: true
      - percentage: 25             # of principals, by a stable hash
        value: true
  export-row-limit:
    default: 1000
```

A flag key is letters, digits, `.`, `_` and `-`, starting with a letter or
digit. A definition needs `default` and may carry `rules` (a list) and `exposed`
(a boolean, `false` unless given); a rule needs `value` and may carry `tenants`
and `roles` (non-empty lists) and `percentage` (0 to 100). Anything else — an
unknown setting, a value of the wrong shape — throws a `FormatException` naming
the flag, and nothing is installed. Values are plain Dart values (maps and
lists, never YAML nodes), so a flag value encodes as JSON.

**`exposed` decides what a client sees.** A flag is server-only unless it says
otherwise: an operational switch is nothing a browser needs to see.
`TomRuleFlagProvider.evaluateAll` answers the exposed flags only, evaluated for
the context; `resolve` answers every flag.

### Providers

| Provider | Where |
| -------- | ----- |
| `TomRuleFlagProvider` | Flags and their rules in configuration — the server's. |
| `TomStaticFlagProvider` | Values already evaluated — a client's snapshot fetched from the server, or a test's fixture. Its reason is `staticValue`. |

Another source is plugged in by extending `TomFlagProvider` and assigning it to
`TomFeatureFlags.provider`:

```dart
class VendorFlagProvider extends TomFlagProvider {
  VendorFlagProvider(this.values);

  final Map<String, Object?> values;

  @override
  TomFlagResolution<Object?>? resolve(String flagKey, TomFlagContext context) =>
      values.containsKey(flagKey)
      ? TomFlagResolution(
          values[flagKey],
          TomFlagResolutionReason.targetingMatch,
        )
      : null;
}
```

`resolve` answers the raw value with its reason, or `null` for an unknown flag;
`TomFeatureFlags` checks the type and falls back to the caller's default, so a
provider never has to. It may answer synchronously or with a `Future`.
`evaluateAll` answers every flag a client may read for a context — what the
server's endpoint serves; a provider that cannot enumerate keeps the inherited
empty map.

### The client's flags

The `/feature-flags` API (`tomFeatureFlagsApi`, id `tomFeatureFlagsApiId`) has
one endpoint, `GET /feature-flags` (`tomFeatureFlagsEvaluateEndpointId`), under
`TomPublicAccess`: an anonymous caller is evaluated too, as no one in
particular. It answers `{"flags": {"<key>": <value>, ...}}` — the exposed flags
evaluated for the caller's tenant, roles and id, so a client sees its own values
and never the rules. `registerTomFeatureFlagsApi` registers it in
`tomRemoteApis`; the server registers it among its framework APIs.

A client fetches the snapshot once — at start, after a sign-in — and reads flags
locally:

```dart
TomFeatureFlags.provider = await TomFeatureFlagsClient.fetch(
  Uri.parse('https://api.example.com'),
  bearerToken: accessToken,
);
if (await TomFeatureFlags.isEnabled('new-checkout')) {
  // the new checkout
}
```

`fetch` takes an optional `http.Client` (the framework's outgoing client when
omitted, closed after the call) and answers a `TomStaticFlagProvider`. A server
that does not answer `200` with a `flags` map, or a call that fails, throws
`TomFeatureFlagsException`; a client that would rather run on defaults catches
it and keeps the provider it has.

`example/samples/settings/02_feature_flags_example.dart` walks the module in
seven numbered examples: installing the flags of a configuration, an anonymous
caller's default, a tenant rule, a role rule, a percentage rollout reaching
about one principal in ten, a read that never throws, and a client's snapshot
holding only the exposed flags.

### Error keys

| Key | Raised by | When |
| --- | --------- | ---- |
| `feature_flags.fetch.failed` | `TomFeatureFlagsClient.fetch` | The server did not answer `200` with a `flags` map (`parameters`: `uri`, `status`), or the call failed (`parameters`: `uri`; the failure is the `rootException`). |

A read through `TomFeatureFlags` raises nothing, and a malformed configuration
throws a `FormatException` (on a server, wrapped as
`configuration.feature_flags.invalid`).

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `feature_flags.dart` | `FutureOr`, so a provider may answer synchronously |
| `dart:convert` | dart | `feature_flags.dart`, `feature_flags_contract.dart` | `utf8` for the bucket hash; `jsonDecode` for the fetched flags |
| `crypto` | package | `feature_flags.dart` | `sha256`, the stable percentage bucket |
| `http` | package | `feature_flags_contract.dart` | `http.Client`, the client `TomFeatureFlagsClient.fetch` calls through |
| [context](../context/context.md) | module | `feature_flags.dart` | `TomTenantContext.currentId`, the tenant of `TomFlagContext.current()` |
| [http_connection](../http_connection/http_connection.md) | module | `feature_flags_contract.dart` | `TomApi`, `TomApiEndpoint`, `TomHttpMethod`, `tomRemoteApis` and `TomHttpClientFactory`, for the `/feature-flags` contract and its client |
| [little_things](../little_things/little_things.md) | module | `feature_flags.dart`, `feature_flags_contract.dart` | `getFromCurrentZone`, how `TomFlagContext.current()` finds the principal; `TomException`, the base of `TomFeatureFlagsException` |
| [reflection](../reflection/reflection.md) | module | `settings_client_authorization.dart` | `@tomReflector`, the annotation both settings classes carry — and what makes the wire round trip work, because the JSON conversion in both directions is driven by the generated reflection data |
| [security](../security/security.md) | module | `feature_flags.dart`, `feature_flags_contract.dart` | `TomPrincipal`, whose qualified id and roles a flag is evaluated for; `TomPublicAccess`, the access policy of the endpoint |

`settings_client_authorization.dart` imports reflection and nothing else. It
declares two annotated data classes: no transport, no storage, no validation. A
package that consumes these DTOs therefore needs a **`build_runner` step** — `tom_reflection_generator`
as a dev dependency and `dart run build_runner build` — or the classes will
serialize to nothing.

### What this module does *not* depend on

Two modules are easy to mistake for dependencies of the settings DTOs because
their subject matter runs through them, and `settings_client_authorization.dart`
imports neither (Security is imported by the feature-flag files, for the
principal a flag is evaluated for and the endpoint's access policy — not by the
DTOs):

| Module | Its actual relationship |
| ------ | ----------------------- |
| [Security](../security/security.md) | Produces the token that [`TomGetSettingsMessage.authorizationToken`](#tomgetsettingsmessage) carries, and consumes the `roles` / `groups` / `entitlements` / `resourceKeys` the result returns. The field is a plain `String?`; this module neither parses nor validates it |
| [Resources](../resources/resources.md) | A typical consumer of the returned `texts` map, which it can load as a resource bundle. The field is a plain `Map<String, dynamic>`; this module attaches no meaning to it |

Carrying a payload is not depending on a module. The distinction matters when
changing the fields: a break here is felt by whatever *produces* and *consumes*
the payload at either end of the wire, and the compiler will not point at any
of it.
