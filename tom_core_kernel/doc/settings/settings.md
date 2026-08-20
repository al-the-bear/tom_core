# Settings Module

The Settings module provides client-server communication for retrieving application settings, authorization information, and localization preferences.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

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

### TomGetSettingsMessage

The request message for fetching settings from the server.

| Property | Type | Description |
|----------|------|-------------|
| `authorizationToken` | `String?` | JWT bearer token for authentication |

### TomGetSettingsResult

The response containing all settings data.

#### Resources

| Property | Type | Description |
|----------|------|-------------|
| `texts` | `Map<String, Object?>` | Localized text resources for UI |
| `config` | `Map<String, Object?>` | Application configuration values |

#### Authorization

| Property | Type | Description |
|----------|------|-------------|
| `groups` | `List<String>` | Security groups the user belongs to |
| `roles` | `List<String>` | Roles assigned to the user |
| `entitlements` | `List<String>` | Fine-grained permissions |
| `resourceKeys` | `List<String>` | Accessible resource identifiers |

#### Application Context

| Property | Type | Description |
|----------|------|-------------|
| `organization` | `String?` | Organization context |
| `process` | `String?` | Business process identifier |
| `application` | `String?` | Application identifier |

#### Localization

| Property | Type | Description |
|----------|------|-------------|
| `country` | `String?` | Server-side country code |
| `language` | `String?` | Server-side language code |
| `clientCountry` | `String?` | Client's preferred country (ISO 3166-1) |
| `clientLanguage` | `String?` | Client's preferred language (ISO 639-1) |
| `clientTimeZone` | `String?` | Client's timezone (IANA format) |

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

Always provide defaults for optional settings:

```dart
final pageSize = (settings.config['pageSize'] as int?) ?? 20;
final language = settings.clientLanguage ?? 'en';
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
