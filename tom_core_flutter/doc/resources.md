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
| `TomProperty<T>` | `T` | Generic base; prefer a typed subclass |
| `TomStringProperty` | `String` | |
| `TomIntProperty` | `int` | |
| `TomDoubleProperty` | `double` | |
| `TomBoolProperty` | `bool` | |

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

Evaluated **once, in the constructor**:

1. If the config key exists, its value is cast to `T` (a failed cast throws a
   descriptive `Exception` naming the key and value).
2. Otherwise, if a default was supplied via `.withDefault`, the default is used.
3. Otherwise (absent key, no default) construction throws.

Because resolution is eager, construct the property **after** the config
providers are populated, and re-read is not supported — a later config change is
not reflected.

## Core Components

### `TomProperty<T>`

The generic base. Reads `key` from config at construction and caches the typed
result. Read it back with `get()` or the `~` operator. The `t`,
`translationExists`, `c`, and `configExists` getters expose the underlying
text/config providers.

### Typed subclasses

`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`, and
`TomBoolProperty` fix `T` and offer the same two constructors — the plain
`(key)` form (throws if absent) and `.withDefault(key, value)`.

## Limitations

- **Absent key without default throws a `LateInitializationError`**, not the
  intended "Obligatory resource not found" message: the no-default constructor
  leaves the internal default field uninitialized, so the fallback branch
  surfaces the framework error first. The construction still fails (the intended
  outcome); only the error *type/message* differs. Treat this as a known
  limitation rather than a guaranteed message.
- **Eager and immutable** — the value is captured at construction and never
  re-read.

---

## Dependencies

- **`tom_core_kernel`**: `TomConfigResourceProvider` /
  `TomTextResourceProvider`, the resource providers the property reads from.
