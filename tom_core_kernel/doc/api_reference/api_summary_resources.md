# Tom Core Kernel API Reference: Resources Module

Singleton-based resource management for application text and configuration, with
hierarchical dot-notation key access and explicit bootstrap from JSON maps or
loader functions.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomResourceException](#tomresourceexception)
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
`app.title`), deferred loading through an optional `loader` function, and
direct initialization from a map. When a key is missing, the getters return the
key itself as a fallback (or `null` for the `*OrNull` variants) to help identify
missing resources during development.

Both singletons are installed explicitly, before anything reads them:
`getAppResources` and `getAppConfig` throw
`resources.text_provider.not_installed` / `resources.config_provider.not_installed`
rather than creating a provider on first access. That is what makes
`appResourcesRevision` trustworthy — every installed bundle went through the one
call that bumps it. An application with no bundle installs an empty one.

## Class Hierarchy

```
TomBaseException
  └── TomException
        └── TomResourceException

TomTextResourceProvider

TomConfigResourceProvider
```

## Classes

### TomResourceException

Thrown when the providers are used outside their contract — currently one
condition on each: a lookup before a bundle was installed.

| Key | Raised by | Condition |
| --- | --------- | --------- |
| `resources.text_provider.not_installed` | `TomTextResourceProvider.getAppResources` | No text bundle installed. |
| `resources.config_provider.not_installed` | `TomConfigResourceProvider.getAppConfig` | No configuration bundle installed. |

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
| `loader` | `Map<String, dynamic> Function()?` | Optional loader consulted by the default constructor. Declares how to load a bundle; setting it installs nothing. |
| `appResourcesRevision` | `TomInt` | Observable revision counter, incremented whenever the installed bundle changes. Observe it to re-derive text computed from the bundle (see `TomObservableEnum`). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppResourceProvider` | `static void setAppResourceProvider(TomTextResourceProvider provider)` | Installs `provider` as the application-wide text resource provider and bumps `appResourcesRevision`. |
| `getAppResources` | `static TomTextResourceProvider getAppResources()` | Returns the installed application-wide provider. Throws `TomResourceException` (`resources.text_provider.not_installed`) if `setAppResourceProvider` has not run. |
| `notifyAppResourcesChanged` | `static void notifyAppResourcesChanged()` | Bumps `appResourcesRevision`. Call after mutating the installed provider's `resources` map in place. |
| `clearAppResourceProvider` | `@visibleForTesting static void clearAppResourceProvider()` | Returns the process to the un-bootstrapped state. Does not bump `appResourcesRevision` — there is no bundle left for observers to re-derive from. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resources` | `Map<String, dynamic>` | The map containing all text resources, possibly nested for dot-notation access. Assigning a new map to the *installed* provider bumps `appResourcesRevision`; in-place mutation cannot be detected. |

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
| `loader` | `Map<String, dynamic> Function()?` | Optional loader consulted by the default constructor. Declares how to load a bundle; setting it installs nothing. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppConfigProvider` | `static void setAppConfigProvider(TomConfigResourceProvider provider)` | Installs `provider` as the application-wide configuration provider. |
| `clearAppConfigProvider` | `@visibleForTesting static void clearAppConfigProvider()` | Returns the process to the un-bootstrapped state. |
| `getAppConfig` | `static TomConfigResourceProvider getAppConfig()` | Returns the installed application-wide provider. Throws `TomResourceException` (`resources.config_provider.not_installed`) if `setAppConfigProvider` has not run. |

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
