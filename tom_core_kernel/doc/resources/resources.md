# Resources Module

The Resources module provides singleton-based resource management for applications, enabling centralized access to text resources (localized strings, UI labels) and configuration values (settings, feature flags).

## Table of Contents

- [Overview](#overview)
- [Bootstrap](#bootstrap)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Architecture Notes](#architecture-notes)
- [Dependencies](#dependencies)

---

## Overview

The module consists of two main providers:

| Provider | Holds | Accessors | Observable |
|----------|-------|-----------|------------|
| `TomTextResourceProvider` | Everything the user sees: localized strings, UI labels, messages — and the non-String values that travel with them, such as TextStyles and Colors | String family (`getText`, `getTextOrNull`, `exists`) **and** object family (`getObject`, `getObjectOrNull`, `existsObject`) | Yes — `appResourcesRevision` |
| `TomConfigResourceProvider` | How the application is set up: API endpoints, feature flags, timeouts | Object family only (`getText` returns `Object`, plus `getObjectOrNull` and `exists`) | No |

**Both bundles are `Map<String, dynamic>` and both hold values of any type.**
The split is by *purpose*, not by value type: a Color belonging to the theme is
a text resource, and a `bool` feature flag is configuration. Two consequences
follow, and they are the reason the split is worth having:

- Only the text provider is observable. `appResourcesRevision` exists because a
  locale or theme switch has to re-render; configuration is read at the point of
  use and does not.
- Only the text provider has the String-specific accessors. `getText` on a
  non-String value reports the key as missing (that is what "text accessor"
  means), so a TextStyle stored in the text bundle is read with `getObject` /
  `getObjectOrNull`, not `getText`.

So do not reach for `TomConfigResourceProvider` merely because a value is not a
`String` — it has no revision counter, and its accessors are a strict subset.

Both providers share similar patterns:
- **Singleton access** for application-wide resource sharing
- **Explicit bootstrap** — the singleton is installed once at startup; there is
  no lazy first-access creation (see [Bootstrap](#bootstrap))
- **Hierarchical key access** using dot notation (e.g., `'app.settings.theme'`),
  which walks String-keyed maps only — see
  [What a segment can descend into](#what-a-segment-can-descend-into)
- **Deferred loading** with optional loader functions
- **Fallback behavior** returning the key when a resource is not found

## Bootstrap

Both providers must be installed before anything reads them:

```dart
TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider.from({}));
TomConfigResourceProvider.setAppConfigProvider(TomConfigResourceProvider.from({}));
```

`getAppResources()` and `getAppConfig()` throw
`resources.text_provider.not_installed` /
`resources.config_provider.not_installed` until that has happened. An
application with no bundle installs an empty one — every lookup then echoes its
key, which is the intended degradation. Not installing at all is a bootstrap
bug, and it is reported at the first read rather than rendering the whole UI in
raw keys.

Installation is the *only* way a bundle becomes application-wide, and that is
what keeps `appResourcesRevision` honest: every installed bundle went through
the one call that bumps the counter. A lazily self-installing lookup could not
make that promise — it used to put a bundle in place at revision 0, so
observers registered before the first lookup never heard about the bundle that
the lookup itself had just loaded.

Test suites install in `setUp` (or, for Flutter packages, once in
`test/flutter_test_config.dart`), exactly as an application installs in
`main()`.

`clearAppResourceProvider()` / `clearAppConfigProvider()` return the process to
the un-bootstrapped state. They are annotated `@visibleForTesting`: without
them the first install is unobservable, because nothing else can get back to
"nothing installed". Clearing deliberately does *not* bump the revision —
observers woken by it would read a bundle that is no longer there.

## Quick Start

### 1. Set Up Text Resources

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Option A: Build the bundle in a function. The loader runs here, during the
// install — not at first access — so it has to produce the map without
// awaiting. For a source that only yields a `Future` (a JSON asset, a file, a
// download), see "Loading Resources from JSON Assets" below.
TomTextResourceProvider.setAppResourceProvider(
  TomTextResourceProvider.load(() => {
    'app': {
      'title': 'My Application',
      'version': '1.0.0',
    },
    'messages': {
      'welcome': 'Welcome to the app!',
      'goodbye': 'See you later!',
    },
  }),
);

// Option B: Create from an existing map
final provider = TomTextResourceProvider.from({
  'greeting': 'Hello, World!',
});
TomTextResourceProvider.setAppResourceProvider(provider);
```

### 2. Access Text Resources

```dart
// Get the singleton instance
final resources = TomTextResourceProvider.getAppResources();

// Retrieve text values
String title = resources.getText('app.title');           // 'My Application'
String welcome = resources.getText('messages.welcome');  // 'Welcome to the app!'

// Check if a resource exists
if (resources.exists('messages.optional')) {
  showMessage(resources.getText('messages.optional'));
}

// Missing resources return the key itself
String missing = resources.getText('unknown.key');       // 'unknown.key'
```

### 3. Set Up Configuration

```dart
// Install the configuration bundle at startup.
TomConfigResourceProvider.setAppConfigProvider(
  TomConfigResourceProvider.load(() => {
    'api': {
      'baseUrl': 'https://api.example.com',
      'timeout': 30000,
    },
    'features': {
      'darkMode': true,
      'analytics': false,
      'maxItems': 100,
    },
  }),
);
```

### 4. Access Configuration

```dart
final config = TomConfigResourceProvider.getAppConfig();

// Retrieve typed configuration values. Cast the nullable accessor and supply a
// default — see "Reading a typed configuration value" below for why.
final apiUrl = config.getObjectOrNull('api.baseUrl') as String? ?? '';       // 'https://api.example.com'
final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;       // 30000
final darkMode = config.getObjectOrNull('features.darkMode') as bool? ?? false; // true

// Check if configuration exists
if (config.exists('features.experimental')) {
  enableExperimentalFeatures();
}
```

#### Reading a typed configuration value

`getText` returns `Object` and, on a miss, echoes the key back **as a
`String`**. That lenient fallback is right for text — a label renders as its key
instead of crashing — but configuration is cast, so the miss lands on the cast:

```dart
config.getText('api.timeout') as int   // 30000 when present
config.getText('api.retries') as int   // throws: String is not a subtype of int
config.getText('api.retries') as int?  // throws too — the miss value is a
                                       // non-null String, not null
```

The `TypeError` names `String` and `int` and never names the key, so it does not
say which setting is missing. Two forms avoid it:

```dart
// Preferred: one lookup, cannot throw on absence.
final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;

// Equivalent, two lookups — use when the branch does more than pick a default.
final retries = config.exists('api.retries')
    ? config.getText('api.retries') as int
    : 3;
```

Cast `getText` directly only where a miss is genuinely impossible.

### 5. Easy client integration

Use a simple extension like this to make text resources and configuration available anywhere

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../sample_app_state.dart';

extension TomResourceExtension on Object {
  String Function(String) get t =>
      TomTextResourceProvider.getAppResources().getText;
  bool Function(String) get translationExists =>
      TomTextResourceProvider.getAppResources().exists;
  Object Function(String) get c =>
      TomConfigResourceProvider.getAppConfig().getText;
  bool Function(String) get configExists =>
      TomConfigResourceProvider.getAppConfig().exists;

  /// Reads a configuration value of type [T], falling back to [orElse] when the
  /// key is absent. Goes through `getObjectOrNull` so a miss is `null` and takes
  /// the default, rather than the echoed key blowing up the cast.
  T config<T>(String key, T orElse) =>
      TomConfigResourceProvider.getAppConfig().getObjectOrNull(key) as T? ??
      orElse;
}
```

```dart
final timeout = config('api.timeout', 5000);        // int
final darkMode = config('features.darkMode', false); // bool
```

You find this file in the UAM sample application.

## Core Components

### TomTextResourceProvider

A singleton provider for application-facing resources: text (localized strings,
labels, messages) plus the arbitrary object values that belong with it —
TextStyles, Colors, and other look-and-feel settings. The String family and the
object family below address the same bundle; which one you use depends on the
type of the value at the key, not on which provider holds it.

#### Static Members

| Member | Type | Description |
|--------|------|-------------|
| `loader` | `Map<String, dynamic> Function()?` | Optional function the default constructor builds the bundle from — every construction, not just the singleton's. Declares *how* to build, not *when* to install. **Process-wide and persistent**: it stays set, so later providers built for local scopes pick it up too. **Synchronous** — asynchronous sources are awaited before the install instead |
| `appResourcesRevision` | `TomInt` | Observable revision counter, bumped whenever the installed bundle changes |
| `notifyAppResourcesChanged()` | Method | Bumps `appResourcesRevision` after an in-place edit of the installed bundle |
| `setAppResourceProvider()` | Method | Sets the application-wide provider instance and bumps `appResourcesRevision` |
| `getAppResources()` | Method | Returns the installed provider; throws `resources.text_provider.not_installed` if there is none |

#### Constructors

| Constructor | Description |
|-------------|-------------|
| `TomTextResourceProvider()` | Creates provider using static `loader` if set |
| `TomTextResourceProvider.load(loader)` | Creates provider with a custom loader function |
| `TomTextResourceProvider.from(map)` | Creates provider from an existing map |

#### Instance Members

| Member | Type | Description |
|--------|------|-------------|
| `resources` | `Map<String, dynamic>` | The resource bundle. Assigning a new map to the **installed** provider bumps `appResourcesRevision` |
| `exists(key)` | `bool` | Checks if a **String** value exists at the path |
| `existsObject(key)` | `bool` | Checks if **any** value (of any type) exists at the path |
| `getText(key)` | `String` | Returns the text value, or the **key itself** if not found |
| `getTextOrNull(key)` | `String?` | Returns the text value (Strings only), or **`null`** if not found |
| `getObject(key)` | `Object` | Returns the value (any type), or the **key itself** if not found |
| `getObjectOrNull(key)` | `Object?` | Returns the value (any type), or **`null`** if not found |

### TomConfigResourceProvider

A singleton provider for how the application is set up — endpoints, feature
flags, timeouts. It holds values of any type, as the text provider does; what
distinguishes it is that its contents are read at the point of use rather than
rendered, so it carries no revision counter and no String-specific accessors.

#### Static Members

| Member | Type | Description |
|--------|------|-------------|
| `loader` | `Map<String, dynamic> Function()?` | Optional function the default constructor builds the bundle from — every construction, not just the singleton's. Declares *how* to build, not *when* to install. **Process-wide and persistent**: it stays set, so later providers built for local scopes pick it up too. **Synchronous** — asynchronous sources are awaited before the install instead |
| `setAppConfigProvider()` | Method | Sets the application-wide provider instance |
| `getAppConfig()` | Method | Returns the installed provider; throws `resources.config_provider.not_installed` if there is none |

#### Constructors

| Constructor | Description |
|-------------|-------------|
| `TomConfigResourceProvider()` | Creates provider using static `loader` if set |
| `TomConfigResourceProvider.load(loader)` | Creates provider with a custom loader function |
| `TomConfigResourceProvider.from(map)` | Creates provider from an existing map |

#### Instance Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `exists(key)` | `bool` | Checks if any value exists at the path |
| `getText(key)` | `Object` | Returns the value (any type), or the **key itself** if not found |
| `getObjectOrNull(key)` | `Object?` | Returns the value (any type), or **`null`** if not found |

> **Note:** both accessors return `Object`, so callers cast. Cast
> `getObjectOrNull` with a default — `config.getObjectOrNull('api.timeout') as
> int? ?? 5000` — not `getText`, whose echoed key is a `String` that makes the
> cast throw. See [Reading a typed configuration value](#reading-a-typed-configuration-value).
> The three accessors here are the whole surface. `getTextOrNull` — the only
> genuinely String-specific accessor in the module — lives on
> [`TomTextResourceProvider`](#tomtextresourceprovider), as do `getObject` and
> `existsObject`, whose roles are filled here by `getText` and `exists`.

### Fallback: key vs. null

The `getText` / `getObject` accessors return the **lookup key itself** when a
resource is missing. This is convenient during development — an unresolved key
renders visibly instead of crashing — but it means "missing" and "the value
happens to equal the key" are indistinguishable. When you need to branch on
presence (rather than render a placeholder), prefer the `OrNull` variants:

```dart
final resources = TomTextResourceProvider.getAppResources();

// Placeholder behaviour — shows the key when missing.
String label = resources.getText('screens.home.title');

// Presence behaviour — null when missing.
String? optional = resources.getTextOrNull('screens.home.subtitle');
if (optional != null) showSubtitle(optional);

// getObjectOrNull avoids the exists()+get double lookup. Both providers have it.
final retries = resources.getObjectOrNull('api.retries') as int? ?? 3;

final config = TomConfigResourceProvider.getAppConfig();
final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;
```

On the config provider this is not merely tidier — it is the difference between
a default and a crash, because `getText`'s echoed key is a `String` and the
cast that follows it is not.

#### A key that is present and holds null

"Missing" covers one more case than the name suggests: a key that **is** in the
bundle but holds `null` is reported exactly like a key that was never there.
Every accessor on both providers behaves this way, for a flat key and a dotted
path alike:

```dart
final resources = TomTextResourceProvider.from({
  'flat': null,
  'nested': {'leaf': null},
});

resources.exists('flat');              // false
resources.existsObject('nested.leaf'); // false
resources.getTextOrNull('flat');       // null
resources.getObjectOrNull('flat');     // null
resources.getObject('nested.leaf');    // 'nested.leaf' — the key echoed back
```

This is worth knowing because bundles are usually JSON, `null` is a legal JSON
value, and translation tooling routinely emits it for a string that has not been
translated yet. Such a key takes the missing branch and renders its key — which
is the intended fallback, just reached by a route you did not plan for.

The accessors have nowhere to report a third state: `exists` returns `bool` and
`getObjectOrNull` returns `Object?`, so "present, but null" has no slot. The
information is not lost, though — `resources` is public, and the underlying
`getObjectFromTree` distinguishes the two cases (it returns `null` for a present
null and throws for an absent key). A caller that needs the distinction reads it
directly:

```dart
final untranslated = resources.resources.containsKey('flat') &&
    resources.getTextOrNull('flat') == null;
```

### Observing bundle changes

Text derived from the resource bundle — a translated label held in a widget, a
localized enum caption — has to be re-derived when the bundle is swapped, for
example on a language change. `TomTextResourceProvider.appResourcesRevision` is
a `TomInt` that exists for exactly that: observe it, and re-read your resources
when it fires.

```dart
// Retain the returned observer — observers are held weakly.
final observer = TomTextResourceProvider.appResourcesRevision >> (_) {
  rebuildLocalizedCaptions();
};

// Installing a new bundle bumps the revision, so the observer fires.
TomTextResourceProvider.setAppResourceProvider(
  TomTextResourceProvider.from(germanResources),
);

// Assigning a new map to the *installed* provider bumps it too.
TomTextResourceProvider.getAppResources().resources = frenchResources;
```

In-place mutation of the map cannot be detected — the setter never runs — so
announce it yourself:

```dart
TomTextResourceProvider.getAppResources().resources['app.title'] = 'Renamed';
TomTextResourceProvider.notifyAppResourcesChanged();
```

Assigning `resources` on a provider that is *not* the installed one is silent by
design: a provider nobody reads from has not changed anything
application-visible.

`appResourcesRevision` is what `TomObservableEnum` observes to keep its display
strings current, so a language switch re-renders bound widgets without the
caller rebuilding them — see [`observable`](../observable/observable.md).

## Usage Examples

### Loading Resources from JSON Assets

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

// Call this from main(), before runApp(). Asset loading is asynchronous and
// the providers are not, so the bundles are awaited here and installed once
// they are in hand — which is also the moment `appResourcesRevision` moves.
Future<void> initializeResources() async {
  final strings = await rootBundle.loadString('assets/strings.json');
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(jsonDecode(strings) as Map<String, dynamic>),
  );

  final config = await rootBundle.loadString('assets/config.json');
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from(jsonDecode(config) as Map<String, dynamic>),
  );
}
```

Note what this does *not* do: it does not await inside a `loader`. `loader` is
`Map<String, dynamic> Function()` — synchronous — and that is deliberate rather
than an oversight. `getText` is synchronous, so the bundle has to be in memory
before the first read, and a constructor cannot await. An `async` closure would
return `Future<Map<String, dynamic>>` and no longer match the field type, so
`TomTextResourceProvider.load(() async => ...)` does not compile.

The rule that follows is short: **produce the map first, then install it.**
`loader` and `.load` are for bundles you can build without awaiting — a computed
map, a compiled-in constant, an already-decoded string. Everything else is
awaited in `main()` and installed with `.from(...)`, as above. The one `await`
in `initializeResources()` is the whole cost, and it buys synchronous reads
everywhere else in the application.

`tom_core_kernel` has no Flutter dependency, so `rootBundle` above comes from
the application, not from this package; on a server or in a plain Dart script
substitute `File(...).readAsString()`, which has the same shape.

### Environment-Specific Configuration

```dart
void setupEnvironment(String environment) {
  final configs = {
    'dev': {
      'api': {'baseUrl': 'https://dev.api.example.com', 'debug': true},
    },
    'prod': {
      'api': {'baseUrl': 'https://api.example.com', 'debug': false},
    },
  };
  
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from(configs[environment]!),
  );
}
```

### Localization Support

```dart
class LocalizationService {
  void setLocale(String locale) {
    final localizedStrings = loadStringsForLocale(locale);
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(localizedStrings),
    );
  }
  
  String translate(String key) {
    return TomTextResourceProvider.getAppResources().getText(key);
  }
}
```

### Feature Flags

```dart
class FeatureFlags {
  static bool isEnabled(String feature) {
    final config = TomConfigResourceProvider.getAppConfig();
    return config.getObjectOrNull('features.$feature') as bool? ?? false;
  }
}

// Usage
if (FeatureFlags.isEnabled('newCheckout')) {
  showNewCheckoutFlow();
} else {
  showLegacyCheckoutFlow();
}
```

## Best Practices

### 1. Initialize Early

Set up resource providers during application initialization, before any UI code attempts to access resources:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize resources first
  await initializeResources();
  
  runApp(MyApp());
}
```

### 2. Use Hierarchical Keys

Organize resources with meaningful hierarchical keys for better maintainability:

```dart
// Good: Organized hierarchy
'screens.home.title'
'screens.home.welcomeMessage'
'errors.network.timeout'
'errors.network.noConnection'

// Avoid: Flat, unclear keys
'homeTitle'
'welcomeMsg'
'timeoutError'
```

### 3. Handle Missing Resources Gracefully

The providers return the key when a resource is not found. Use this for debugging but handle missing resources appropriately in production:

```dart
String getRequiredText(String key) {
  final resources = TomTextResourceProvider.getAppResources();
  final value = resources.getText(key);
  
  if (value == key) {
    // Log missing resource in development
    assert(() {
      print('Warning: Missing resource key: $key');
      return true;
    }());
  }
  
  return value;
}
```

### 4. Type Safety for Configuration

Read configuration through one typed helper rather than casting at each call
site — the helper is the single place the absent-key and wrong-type cases are
decided:

```dart
T getConfig<T>(String key, T defaultValue) {
  final value = TomConfigResourceProvider.getAppConfig().getObjectOrNull(key);
  return value is T ? value : defaultValue;
}

// Usage
final timeout = getConfig<int>('api.timeout', 5000);
final debugMode = getConfig<bool>('debug.enabled', false);
```

The `is T` test rather than `as T?` because it also absorbs a *configured* value
of the wrong type. Which of the two you want is a real choice: `as T?` lets a
`"thirty seconds"` in the config file fail loudly at startup, while `is T`
quietly uses the default. Prefer `as T?` for settings a broken value would make
the application misbehave with, and `is T` for genuinely optional tuning knobs.

### 5. Avoid Reloading in Production

The singleton pattern means resources are loaded once. If you need to update resources at runtime (e.g., for locale changes), explicitly set a new provider:

```dart
void updateLocale(String newLocale) {
  final newResources = loadResourcesForLocale(newLocale);
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(newResources),
  );
}
```

## Architecture Notes

### Singleton Pattern

Both providers use the singleton pattern with an explicit bootstrap. `setAppResourceProvider()` / `setAppConfigProvider()` install the instance; `getAppResources()` / `getAppConfig()` return it for all subsequent calls, and throw if the install never happened. See [Bootstrap](#bootstrap).

### Hierarchical Access

Resources support dot-notation access (e.g., `'app.settings.theme'`) through the
`getObjectFromTree` function from the JSON utilities module. This allows for
organized, nested resource structures.

#### What a segment can descend into

Only a `Map` whose keys are **all Strings**. The check is against the runtime
keys, not the declared type, so a `Map<String, String>` and a
`Map<dynamic, dynamic>` holding String keys both traverse. Two shapes that JSON
produces routinely do not:

| Shape | Path *through* it | Reachable as a terminal value |
|-------|-------------------|-------------------------------|
| `List` | ✗ — `'items.0'` does not index it | ✓ `getObject('items')` |
| `Map` with any non-String key | ✗ — `'byCode.1'` cannot reach into a `Map<int, String>` | ✓ `getObject('byCode')` |

Only the path *through* these is closed; the last segment is never descended
into, so both values come back intact when you ask for them whole. **A list is
therefore read by fetching it and indexing in Dart:**

```dart
final config = TomConfigResourceProvider.getAppConfig();

// Dotted paths stop at the list — 'rateLimits.0.endpoint' would miss.
final rateLimits = config.getObjectOrNull('limits.rateLimits') as List? ?? [];
final firstEndpoint = (rateLimits.first as Map)['endpoint'];
```

Note the failure mode: a path into a list or an int-keyed map misses
**silently**. The tree walk fails, the flat-key lookup finds nothing, and the
fallback echoes the key — so `getText('items.0.label')` renders the literal text
`items.0.label` in the UI, with no error raised anywhere. If a dotted path is
rendering as itself, check the shape of what it walks through before assuming
the key is missing.

---

## Dependencies

This module depends on:

- **JSON Module**: `getObjectFromTree`, the tree walk behind every dotted-path
  lookup
- **Observable Module**: `TomInt`, the type of `appResourcesRevision`. This is
  the module's only outward-facing signal — it is what carries a bundle change
  to everything derived from the bundle, so a locale switch reaches bound
  widgets at all
- **Little Things Module**: `TomException`, the base of `TomResourceException`
- **`package:meta`**: `@visibleForTesting` only; no runtime behaviour
