# Resources Module

Typed, UI-bound access to the kernel **configuration** resources. A
`TomProperty<T>` resolves a single config key to a typed value **once, at
construction**, and caches it — handy for binding a config value to a field on
a service or view-model.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Resolution Rules](#resolution-rules)
- [Core Components](#core-components)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Holds | Notes |
| ---- | ----- | ----- |
| `TomProperty<T>` | `T` | Generic base; prefer a typed subclass, except when `T` is nullable |
| `TomStringProperty` | `String` | |
| `TomIntProperty` | `int` | |
| `TomDoubleProperty` | `double` | |
| `TomBoolProperty` | `bool` | |
| `TomPropertyException` | — | Raised when resolution fails; one type, two `key` codes |

Each reads from the application
[`TomConfigResourceProvider`](../../tom_core_kernel/doc/resources/resources.md)
(the same provider the kernel uses for config lookups).

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Given config: { 'app.title': 'My App', 'app.retries': 3 }
final title = TomStringProperty('app.title');
print(~title);        // 'My App'  (operator form)
print(title.get());   // 'My App'  (method form)

// Fall back to a default when the key is absent:
final retries = TomIntProperty.withDefault('app.retries', 5);
```

## Resolution Rules

Evaluated **once, in the constructor**, from a **single** config lookup — one
read answers both whether the key is present and what it holds, on the failure
path as much as the success path:

1. If the config key resolves to a value, it is cast to `T` (a failed cast
   throws `TomPropertyException` with the key
   `resources.property.type_mismatch`, naming the key and value, and carrying
   the `TypeError` as its `rootException`).
2. Otherwise, if a default was supplied via `.withDefault`, the default is used.
3. Otherwise (absent key, no default) construction throws
   `TomPropertyException` with the key `resources.property.not_configured`.

A failure to read the configuration at all is not one of these: it propagates
as whatever the provider raised, and is never re-reported as a cast failure.

### How a key resolves

The key is passed to the provider unchanged, so a property inherits the
provider's **dot notation over nested maps**. `'app.db.host'` finds either a
`host` entry inside a `db` map inside an `app` map, or a flat entry literally
named `'app.db.host'`.

The two are not equal alternatives. The nested walk runs **first** and the flat
lookup is its fallback, so a config holding both spellings answers with the
nested one:

```dart
// { 'app': {'title': 'nested'}, 'app.title': 'flat' }
~TomStringProperty('app.title');   // 'nested'
```

Descent stops at the last segment, which makes an interior node a value in its
own right. No typed subclass can hold one, so fetching a subtree is a second
place the generic is the intended form:

```dart
final db = TomProperty<Map<String, dynamic>>('app.db');
```

A path that reaches a real subtree but finds nothing in it is an ordinary miss
— rule 2 or 3 above, not an error of its own.

Because resolution is eager, construct the property **after** the config
providers are populated, and re-read is not supported — a later config change is
not reflected.

## Core Components

### `TomProperty<T>`

The generic base. Reads `key` from config at construction and caches the typed
result. Read it back with `get()` or the `~` operator. The config-provider
lookups it uses are private implementation detail, not part of the public
surface.

Prefer a typed subclass over the generic for the four non-nullable value types
below. **When `T` is nullable the generic is the intended form** — the
subclasses close over non-nullable `String`, `int`, `double` and `bool`, so
none of them can hold an optional value:

```dart
final region = TomProperty<String?>.withDefault('app.region', null);
if (~region == null) useDefaultRegion();
```

### Typed subclasses

`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`, and
`TomBoolProperty` fix `T` and offer the same two constructors — the plain
`(key)` form (throws if absent) and `.withDefault(key, value)`.

### `TomPropertyException`

A `TomClientException` — and so a kernel `TomException` — raised by both
failure paths. Catch it around the *declaration*, not the read: resolution
happens in the constructor, so a property that constructs successfully never
raises afterwards.

| `key` | Raised when |
| ----- | ----------- |
| `resources.property.not_configured` | The key is absent and no default was supplied. |
| `resources.property.type_mismatch` | The key holds a value that cannot be cast to `T`. |

`parameters` carries the key, plus `expectedType` and `value` on the mismatch
path; `rootException` carries the `TypeError`, which is the only record of the
value's actual runtime type — the message names only the type that was wanted.

## Limitations

- **Absent key without default throws `TomPropertyException`** naming the
  obligatory key (`Obligatory resource <key> not found in configuration
  resources`). Default *presence* is tracked separately from the default value,
  so a `.withDefault(key, null)` over a nullable `T` honours the explicit `null`
  rather than treating it as "no default".
- **Eager and immutable** — the value is captured at construction and never
  re-read.
- **A key configured with no value counts as absent.** The lookup reports a key
  that was never written and one written as `null` identically, and a property
  reads both as "not there": `app.region:` in a config file fails an obligatory
  property and loses to a default. A configured `null` can therefore never
  override a non-null default. A caller who must tell "explicitly unset" from
  "never configured" has to ask the provider's own map — `resources` is public,
  so `containsKey` settles a flat key and `getObjectFromTree` a dotted one —
  because a property offers no way to express the difference.

---

## Dependencies

- **`tom_core_kernel`**: `TomConfigResourceProvider`, the resource provider
  every property reads from — resolution is a single `getObjectOrNull` call on
  the provider returned by its `getAppConfig()`.
  It is populated by `setAppConfigProvider`, which is the call an application
  must make before constructing any property. The *text* provider family
  (`setAppResourceProvider`) is a separate installation with its own backing
  map and is not consulted here, so installing it instead leaves every property
  unresolved.
