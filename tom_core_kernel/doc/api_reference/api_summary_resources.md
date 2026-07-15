# Tom Core Kernel API Reference: Resources Module

Singleton-based resource management for application text and configuration, with
hierarchical dot-notation key access and lazy initialization from JSON maps or
loader functions.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTextResourceProvider](#tomtextresourceprovider)
  - [TomConfigResourceProvider](#tomconfigresourceprovider)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/resources/tom_resource_provider.dart`.

This module provides two process-wide singleton providers. `TomTextResourceProvider`
stores and retrieves text-based resources (localized strings, UI labels, error
messages) as well as arbitrary object values (TextStyles, Colors, and other
non-String UI values) for unified resource management. `TomConfigResourceProvider`
stores and retrieves configuration values such as API endpoints, feature flags,
and timeouts. Both support flat keys and hierarchical dot-notation paths (e.g.
`app.title`), lazy initialization through an optional `loader` function, and
direct initialization from a map. When a key is missing, the getters return the
key itself as a fallback (or `null` for the `*OrNull` variants) to help identify
missing resources during development.

## Class Hierarchy

```
TomTextResourceProvider

TomConfigResourceProvider
```

## Classes

### TomTextResourceProvider

A singleton provider for text resources (localized strings, UI labels, error
messages) that also supports retrieval of arbitrary object values via
`existsObject`/`getObject`. Singleton access is via `getAppResources`; values
are looked up by flat keys or dot-notation paths.

#### Constructors

```dart
TomTextResourceProvider()
TomTextResourceProvider.load(Map<String, dynamic> Function() loader)
TomTextResourceProvider.from(Map<String, dynamic> resources)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional loader invoked the first time `getAppResources` lazily creates a provider. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppResourceProvider` | `static void setAppResourceProvider(TomTextResourceProvider provider)` | Installs `provider` as the application-wide text resource provider. |
| `getAppResources` | `static TomTextResourceProvider getAppResources()` | Returns the application-wide provider, lazily creating one (using `loader` if set) on first access. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resources` | `Map<String, dynamic>` | The map containing all text resources, possibly nested for dot-notation access. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exists` | `bool exists(String s)` | Whether a String value exists at path `s` (flat key or dot path). |
| `existsObject` | `bool existsObject(String s)` | Whether any value (String or non-String UI value) exists at path `s`. |
| `getObject` | `Object getObject(String s)` | Returns the value at path `s` (any type), or the key `s` itself if not found. |
| `getObjectOrNull` | `Object? getObjectOrNull(String s)` | Returns the value at path `s` (any type), or `null` if not found. |
| `getText` | `String getText(String s)` | Returns the String value at path `s`, or the key `s` itself if not found. |
| `getTextOrNull` | `String? getTextOrNull(String s)` | Returns the String value at path `s`, or `null` if not found. |

### TomConfigResourceProvider

A singleton provider for configuration values (API endpoints, feature flags,
timeouts, and other settings). Singleton access is via `getAppConfig`; values
are looked up by flat keys or dot-notation paths.

#### Constructors

```dart
TomConfigResourceProvider()
TomConfigResourceProvider.load(Map<String, dynamic> Function() loader)
TomConfigResourceProvider.from(Map<String, dynamic> resources)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional loader invoked the first time `getAppConfig` lazily creates a provider. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppConfigProvider` | `static void setAppConfigProvider(TomConfigResourceProvider provider)` | Installs `provider` as the application-wide configuration provider. |
| `getAppConfig` | `static TomConfigResourceProvider getAppConfig()` | Returns the application-wide provider, lazily creating one (using `loader` if set) on first access. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resources` | `Map<String, dynamic>` | The map containing all configuration values, possibly nested for dot-notation access. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exists` | `bool exists(String s)` | Whether any value exists at path `s` (flat key or dot path). |
| `getText` | `Object getText(String s)` | Returns the value at path `s` (any type), or the key `s` itself if not found. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
