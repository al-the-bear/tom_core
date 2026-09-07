# Settings Module

The Settings module provides client-server communication for retrieving application settings, authorization information, and localization preferences.

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
- [Dependencies](#dependencies)
  - [What this module does *not* depend on](#what-this-module-does-not-depend-on)

---

## Overview

This module enables clients to:
- Request configuration and text resources from the server
- Receive user authorization context (groups, roles, entitlements)
- Obtain localization preferences (country, language, timezone)

The settings system follows a request-response pattern where the client sends a `TomGetSettingsMessage` and receives a `TomGetSettingsResult` containing all necessary configuration data.

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

### TomGetSettingsMessage

The request message for fetching settings from the server.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `authorizationToken` | `String?` | `""` | JWT bearer token for authentication |

The empty-string default is a field initializer, and it is the one place in the
module where an unset string reads as `""` rather than `null`. Every string on
`TomGetSettingsResult` defaults to `null` instead — do not carry the convention
across.

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
  List<String>? groups,
  List<String>? roles,
  List<String>? entitlements,
  List<String>? resourceKeys,
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
| `groups` | `List<String>` | `[]` (fresh) | Security groups the user belongs to |
| `roles` | `List<String>` | `[]` (fresh) | Roles assigned to the user |
| `entitlements` | `List<String>` | `[]` (fresh) | Fine-grained permissions |
| `resourceKeys` | `List<String>` | `[]` (fresh) | Accessible resource identifiers |

#### Application Context

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `organization` | `String?` | `null` | Organization context |
| `process` | `String?` | `null` | Business process identifier |
| `application` | `String?` | `null` | Application identifier |

#### Localization

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `country` | `String?` | `null` | Server-side country code |
| `language` | `String?` | `null` | Server-side language code |
| `timezone` | `String?` | `null` | Server-side timezone (IANA format) |
| `clientCountry` | `String?` | `null` | Client's preferred country (ISO 3166-1) |
| `clientLanguage` | `String?` | `null` | Client's preferred language (ISO 639-1) |
| `clientTimezone` | `String?` | `null` | Client's timezone (IANA format) |

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

Keep authorization checks separate from UI logic:

```dart
class AuthorizationService {
  final TomGetSettingsResult settings;
  
  AuthorizationService(this.settings);
  
  bool canViewReports() => settings.entitlements.contains('view-reports');
  bool canEditUsers() => settings.roles.contains('admin');
  bool hasResourceAccess(String key) => settings.resourceKeys.contains(key);
}
```

### 5. Use Type-Safe Configuration Access

Create typed accessors for configuration values:

```dart
extension ConfigExtensions on TomGetSettingsResult {
  int get maxUploadSize => (config['maxUploadSize'] as int?) ?? 10485760;
  bool get darkModeEnabled => (config['darkMode'] as bool?) ?? false;
  String get apiVersion => (config['apiVersion'] as String?) ?? 'v1';
}
```

---

## Dependencies

`settings_client_authorization.dart` is the module's only source file, and it
has exactly one import:

| Dependency | Used for |
| ---------- | -------- |
| [**Reflection Module**](../reflection/reflection.md) | `@tomReflector`, the annotation both classes carry. It is the whole of the dependency — and it is what makes the wire round trip work, because the JSON conversion in both directions is driven by the generated reflection data |

That is the entire list. The module declares two annotated data classes and
nothing else: no transport, no storage, no validation. A package that consumes
these DTOs therefore needs a **`build_runner` step** — `tom_reflection_generator`
as a dev dependency and `dart run build_runner build` — or the classes will
serialize to nothing.

### What this module does *not* depend on

Two modules are easy to mistake for dependencies because their subject matter
runs through the DTOs, and neither is imported:

| Module | Its actual relationship |
| ------ | ----------------------- |
| [Security](../security/security.md) | Produces the token that [`TomGetSettingsMessage.authorizationToken`](#tomgetsettingsmessage) carries, and consumes the `roles` / `groups` / `entitlements` / `resourceKeys` the result returns. The field is a plain `String?`; this module neither parses nor validates it |
| [Resources](../resources/resources.md) | A typical consumer of the returned `texts` map, which it can load as a resource bundle. The field is a plain `Map<String, dynamic>`; this module attaches no meaning to it |

Carrying a payload is not depending on a module. The distinction matters when
changing the fields: a break here is felt by whatever *produces* and *consumes*
the payload at either end of the wire, and the compiler will not point at any
of it.
