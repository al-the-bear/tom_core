# Tom Core Kernel API Reference: Settings Module

The message and result classes for retrieving client-specific settings,
authorization context, and localization data from the server.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomGetSettingsMessage](#tomgetsettingsmessage)
  - [TomGetSettingsResult](#tomgetsettingsresult)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/settings/settings_client_authorization.dart`.

This module defines the request/response pair used by clients to obtain their
configuration and authorization from the server. `TomGetSettingsMessage` carries
the authorization token that authenticates the settings request.
`TomGetSettingsResult` carries the server's response: text and configuration
resources, the user's authorization context (groups, roles, entitlements,
resource keys), the application context (organization, process, application),
and localization preferences (server- and client-side country/language plus the
client timezone). Both classes are annotated with `@tomReflector` for reflected
serialization.

## Class Hierarchy

```
TomGetSettingsMessage  (@tomReflector)

TomGetSettingsResult  (@tomReflector)
```

## Classes

### TomGetSettingsMessage

Message class for requesting client settings from the server. It encapsulates
the authorization token the server uses to determine which settings and
permissions to return.

- **Extends:** annotated with `@tomReflector`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authorizationToken` | `String?` | The authorization token (typically a JWT bearer token) authenticating the settings request; if null or empty, the server may return default/anonymous settings (default `""`). |

### TomGetSettingsResult

Result class containing client settings, authorization data, and localization —
everything a client needs to configure itself.

- **Extends:** annotated with `@tomReflector`.

#### Constructors

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
  String? clientLanguage,
  String? clientCountry,
  String? clientTimeZone,
})
```

All collection parameters default to fresh, empty mutable collections so callers
can mutate them in place.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `texts` | `Map<String, Object?>` | Localized text resources for UI rendering. |
| `config` | `Map<String, Object?>` | Application configuration settings that control behavior. |
| `groups` | `List<String>` | Security groups the user belongs to (server-authoritative). |
| `roles` | `List<String>` | Roles assigned to the user (e.g. `admin`, `editor`, `viewer`). |
| `entitlements` | `List<String>` | Fine-grained permissions for specific features or operations. |
| `resourceKeys` | `List<String>` | Resource keys (screens, modules, data sets) the user may access. |
| `organization` | `String?` | The organization context for this session (default `""`). |
| `process` | `String?` | The business process/workflow context (default `""`). |
| `application` | `String?` | The application identifier selecting the configuration to use (default `""`). |
| `country` | `String?` | Server-determined country code for localization (default `""`). |
| `language` | `String?` | Server-determined language code for localization (default `""`). |
| `clientCountry` | `String?` | Client's preferred country code, ISO 3166-1 alpha-2 (default `""`). |
| `clientLanguage` | `String?` | Client's preferred language code, ISO 639-1 (default `""`). |
| `clientTimeZone` | `String?` | Client's IANA timezone identifier (e.g. `America/New_York`) (default `""`). |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
