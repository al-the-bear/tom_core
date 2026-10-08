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
- [Loading from an Asynchronous Source](#loading-from-an-asynchronous-source)
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

"Missing" includes a key that is **present in the bundle and holds `null`** —
the common case being JSON emitted by translation tooling for an untranslated
string. Every accessor on both providers collapses it onto absence: `exists` and
`existsObject` report `false`, the `*OrNull` accessors return `null`, and
`getText` / `getObject` echo the key. There is no third state to report it with,
so a caller that needs the distinction reads `provider.resources` directly —
`containsKey` for a flat key, `lookupObjectInTree` for a dotted path (it reports
a present null as `found: true` and an absent key as `found: false`).

A dotted key is tried as a path first and as a literal flat key second; the
text accessors also fall through to the flat key when the path lands on a
non-String, where the object accessors take the path's value as final. A bundle
holding **one key in both shapes** can therefore answer the two families
differently, so the resolvers `tomLog.warn` once per such key per bundle,
naming it.

A dotted path descends only through a `Map` whose keys are **all Strings** —
tested against the runtime keys, not the declared type, so `Map<String, String>`
and a String-keyed `Map<dynamic, dynamic>` both traverse. A `List` does not
(`'items.0'` is not an index), and neither does a `Map` holding any non-String
key (`'byCode.1'` cannot reach into a `Map<int, String>`). Both are still
reachable as *terminal* values — the last segment is never descended into — so a
list is read by fetching it whole and indexing in Dart. A path through either
misses silently, echoing the key back like any other miss.

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

The bundle is a `Map<String, dynamic>` and holds values of any type — "text"
names the purpose, not the value type, and the object family is what keeps
look-and-feel values (TextStyles, Colors) in the same bundle as the strings they
style. Note that the String family reports a non-String value as *absent*:
`getText` on a Color echoes the key back, so such values are read with
`getObject`/`getObjectOrNull`. A non-String value does not belong in
`TomConfigResourceProvider` on account of its type; see that class for the axis
the two providers actually differ on.

#### Constructors

```dart
TomTextResourceProvider()
TomTextResourceProvider.load(Map<String, dynamic> Function() loader)
TomTextResourceProvider.from(Map<String, dynamic> resources)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional loader consulted by the default constructor — *every* construction, not just the singleton's. Declares how to build a bundle; setting it installs nothing, and it stays set until something assigns `null`, so later locally-scoped providers are populated from it too. Synchronous by design — see [Loading from an asynchronous source](#loading-from-an-asynchronous-source). |
| `appResourcesRevision` | `TomInt` | Observable revision counter, incremented whenever the installed bundle changes. Observe it to re-derive text computed from the bundle (see `TomObservableEnum`). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppResourceProvider` | `static void setAppResourceProvider(TomTextResourceProvider provider)` | Installs `provider` as the application-wide text resource provider and bumps `appResourcesRevision`. |
| `getAppResources` | `static TomTextResourceProvider getAppResources()` | Returns the installed application-wide provider. Throws `TomResourceException` (`resources.text_provider.not_installed`) if `setAppResourceProvider` has not run. |
| `notifyAppResourcesChanged` | `static void notifyAppResourcesChanged()` | Bumps `appResourcesRevision`. Call after mutating the installed provider's `resources` map in place. A manual contract by design: `resources` hands out the live map, because a read-only view would either leave nested values writable or, as a deep copy, drop the element type of stored collections. |
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

Both providers hold values of any type, so the choice between them is one of
purpose, not of value type: this one is for how the application is *set up*,
`TomTextResourceProvider` for what the user *sees*. The consequences are that
configuration is not rendered, so it has no revision counter to observe, and
that its three accessors are a strict subset of the text provider's six.

**No revision, by design.** Configuration is installed at bootstrap and captured
by its consumers when they are built — a declared client setting takes its
baseline at declaration, a `TomProperty` at construction — so a counter would
notify nothing that could act on it. `setAppConfigProvider` therefore announces
nothing, and deliberately does not bump the text provider's
`appResourcesRevision`. Replacing the provider later is allowed: every read after
the call answers from the new one, while a value captured before it keeps its
old value, so an application that swaps configuration at a session boundary —
a per-user bundle after sign-in — rebuilds what depends on it itself.

Values are `Object`, so reading one usually means casting it. Cast
`getObjectOrNull`, not `getObject`: `getObject` echoes the key back as a
`String` when the key is absent, so `getObject('api.timeout') as int` throws on
exactly
the case the lenient fallback exists to survive — and `as int?` throws with it,
because the echoed key is a non-null `String`.

#### Constructors

```dart
TomConfigResourceProvider()
TomConfigResourceProvider.load(Map<String, dynamic> Function() loader)
TomConfigResourceProvider.from(Map<String, dynamic> resources)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional loader consulted by the default constructor — *every* construction, not just the singleton's. Declares how to build a bundle; setting it installs nothing, and it stays set until something assigns `null`, so later locally-scoped providers are populated from it too. Synchronous by design — see [Loading from an asynchronous source](#loading-from-an-asynchronous-source). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setAppConfigProvider` | `static void setAppConfigProvider(TomConfigResourceProvider provider)` | Installs `provider` as the application-wide configuration provider. Announces nothing — no configuration revision exists, and `appResourcesRevision` is not bumped; reads after the call see the new provider, values captured earlier do not. |
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
| `getObject` | `Object getObject(String s)` | Returns the value at path `s` (any type), or the key `s` itself — **as a `String`** — if not found. A direct `as int` therefore throws on a miss, and so does `as int?`. |
| `getObjectOrNull` | `Object? getObjectOrNull(String s)` | Returns the value at path `s` (any type), or `null` if not found. The accessor to cast: `getObjectOrNull('api.timeout') as int? ?? 5000`. |

## Loading from an Asynchronous Source

Both `loader` fields are `Map<String, dynamic> Function()` — synchronous, and
deliberately so. `getText` is synchronous, so the bundle must be in memory
before the first read, and a constructor cannot await. An `async` closure
returns `Future<Map<String, dynamic>>`, which does not match the field type, so
`TomTextResourceProvider.load(() async => ...)` does not compile.

`loader` and `.load` are therefore for bundles that can be produced without
awaiting: a computed map, a compiled-in constant, an already-decoded string.
An asynchronous source is resolved first and installed with `.from(...)`:

```dart
Future<void> initializeResources(
  Future<String> Function(String assetPath) readAsset,
) async {
  final strings = await readAsset('assets/strings.json');
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(jsonDecode(strings) as Map<String, dynamic>),
  );
}
```

One `await` in `main()` buys synchronous reads at every other call site.
`tom_core_kernel` has no Flutter dependency, so the read itself comes from the
application: `rootBundle.loadString` in Flutter,
`(path) => File(path).readAsString()` on a server — the same shape either way.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
