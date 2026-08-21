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
and localization preferences (server- and client-side country, language and
timezone). Both classes are annotated with `@tomReflector` for reflected
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

- **Annotations:** `@tomReflector` — reflected JSON serialization. The field is
  mutable and the class declares no constructor, so the deserializer can create
  an instance and assign into it.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authorizationToken` | `String?` | The authorization token (typically a JWT bearer token) authenticating the settings request; if null or empty, the server may return default/anonymous settings (default `""`). This is the one string in the module that really does default to the empty string — it is a field initializer, so an unset token reads as `""` rather than `null` and the two are not distinguishable here. `TomGetSettingsResult`'s strings default to `null` instead; do not carry the convention across. |

### TomGetSettingsResult

Result class containing client settings, authorization data, and localization —
everything a client needs to configure itself.

- **Annotations:** `@tomReflector` — reflected JSON serialization. Every field
  is mutable and every constructor parameter optional, so the deserializer can
  create an instance and assign into it.

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
| `groups` | `List<String>` | Security groups the user belongs to (server-authoritative). |
| `roles` | `List<String>` | Roles assigned to the user (e.g. `admin`, `editor`, `viewer`). |
| `entitlements` | `List<String>` | Fine-grained permissions for specific features or operations. |
| `resourceKeys` | `List<String>` | Resource keys (screens, modules, data sets) the user may access. |
| `organization` | `String?` | The organization context for this session (default `null`). |
| `process` | `String?` | The business process/workflow context (default `null`). |
| `application` | `String?` | The application identifier selecting the configuration to use (default `null`). |
| `country` | `String?` | Server-determined country code for localization (default `null`). |
| `language` | `String?` | Server-determined language code for localization (default `null`). |
| `timezone` | `String?` | Server-determined IANA timezone identifier for the session (default `null`). |
| `clientCountry` | `String?` | Client's preferred country code, ISO 3166-1 alpha-2 (default `null`). |
| `clientLanguage` | `String?` | Client's preferred language code, ISO 639-1 (default `null`). |
| `clientTimezone` | `String?` | Client's IANA timezone identifier (e.g. `America/New_York`) (default `null`). |

Localization is carried in server/client pairs — `country`/`clientCountry`,
`language`/`clientLanguage`, `timezone`/`clientTimezone`. The server field is
the decision, the client field the request; `server ?? client` yields the
effective value, and the two differing (with the server field non-`null`) is how
a consumer detects an override. A `null` server field means no opinion was
expressed, not agreement.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
