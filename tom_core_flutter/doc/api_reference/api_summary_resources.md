# Tom Core Flutter API Reference: Resources Module

Typed, eagerly-resolved configuration properties read from the kernel config
resource providers.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomProperty&lt;T&gt;](#tompropertyt)
  - [TomStringProperty](#tomstringproperty)
  - [TomIntProperty](#tomintproperty)
  - [TomDoubleProperty](#tomdoubleproperty)
  - [TomBoolProperty](#tomboolproperty)
- [Exceptions](#exceptions)
  - [TomPropertyException](#tompropertyexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomclient/resources/tom_properties.dart`.

A `TomProperty<T>` reads its value for `key` from the application
`TomConfigResourceProvider` **once, at construction**, and caches it. The value
is read with `get()` or the `~` operator. Resolution rules (at construction):
one configuration lookup answers both whether the key is present and what it
holds; an existing key is cast to `T`, widening a configured `int` when `T`
accepts a `double`; an absent key uses the `withDefault` default; an absent key
with no default throws. The value is eager and
immutable — later
config changes are not reflected, so construct the property after the config
providers are populated. Use the typed subclasses for the four non-nullable
value types they name rather than the generic over those types; when `T` is
nullable the generic is the intended form, because every subclass closes over
a non-nullable type and so cannot express an optional value:

```dart
final region = TomProperty<String?>.withDefault('app.region', null);
```

`key` is passed to the provider unchanged, so a property inherits **dot
notation over nested maps**: `'app.db.host'` resolves either through nested
`app` / `db` maps or as a flat entry of that literal name. The nested walk runs
first and the flat lookup is its fallback, so a config carrying both spellings
answers with the nested one. Descent stops at the last segment, so an interior
node is itself a resolvable value — `TomProperty<Map<String, dynamic>>` holds a
subtree, which no typed subclass can.

## Class Hierarchy

```
TomProperty<T>
    ├── TomStringProperty   (T = String)
    ├── TomIntProperty      (T = int)
    ├── TomDoubleProperty   (T = double)
    └── TomBoolProperty     (T = bool)

TomException (kernel)
    └── TomClientException
            └── TomPropertyException
```

## Classes

### TomProperty&lt;T&gt;

A typed configuration value resolved and cached at construction.

- **Type Parameters:** `T` — the value type.

#### Constructors

Both constructors resolve `key` in their body, so **every failure below is a
construction failure** — it surfaces wherever the property is built, which for
the intended declaration-block usage is application start-up.

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| default | `TomProperty(String key)` | Resolves `key` from config at construction. Throws on an absent key, and on a present value that cannot be cast to `T`. |
| `withDefault` | `TomProperty.withDefault(String key, T value)` | Resolves `key`, falling back to `value` when the key is absent. Still throws on a present value that cannot be cast to `T` — the default covers an absent key, not an unusable one. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `get` | `T get()` | Returns the resolved, cached value. |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `~` | `T operator ~()` | Returns the resolved, cached value (operator form of `get`). |

### TomStringProperty

A `TomProperty` holding a `String` config value.

- **Extends:** `TomProperty<String>`

#### Constructors

```dart
TomStringProperty(String key)
TomStringProperty.withDefault(String key, String value)
```

### TomIntProperty

A `TomProperty` holding an `int` config value.

- **Extends:** `TomProperty<int>`

#### Constructors

```dart
TomIntProperty(String key)
TomIntProperty.withDefault(String key, int value)
```

### TomDoubleProperty

A `TomProperty` holding a `double` config value.

A configured whole number widens rather than being refused: no configuration
file can say "double" — `rate: 2` in YAML and `"rate": 2` in JSON both decode
to an `int` — and the reflected path already fills a declared `double` field
from one, so without this a single file could fill a field and fail the
matching property. `TomConfig` on the server widens identically.

The widening is reached only *after* a cast has failed, which is what keeps it
from converting a value some other `T` already accepted: `0.0 is num` is true,
so a check placed before the cast would turn `TomProperty<num>` over a
configured `2` into a `double`. It does not narrow (`2.5` under
`TomIntProperty` is still a mismatch — narrowing needs a rounding policy) and
it does not parse (`'2'` is still a mismatch).

- **Extends:** `TomProperty<double>`

#### Constructors

```dart
TomDoubleProperty(String key)
TomDoubleProperty.withDefault(String key, double value)
```

### TomBoolProperty

A `TomProperty` holding a `bool` config value.

- **Extends:** `TomProperty<bool>`

#### Constructors

```dart
TomBoolProperty(String key)
TomBoolProperty.withDefault(String key, bool value)
```

## Exceptions

Both failures raise `TomPropertyException`, declared in this module. One type
covers both conditions and `key` tells them apart, which is what callers match
on — the same shape the kernel's own resources module uses. Neither is
auto-logged: both propagate out of a constructor, so the failure is visible
without a log line.

Both are thrown from the resolution that both constructors run, so a property
that constructs successfully never raises afterwards — `get()` and `~` only
return the cached value.

### TomPropertyException

- **Extends:** `TomClientException` (and so the kernel `TomException`)

#### Constructors

```dart
TomPropertyException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

See `TomException` (kernel) for the meaning of each argument. The types above
are the *kernel constructor's*, reached through Dart super-parameters — which
resolve against the immediate superclass, not against the field's original
declaration. The two can differ: `uuid`'s field is a non-nullable `late String`
while the parameter is `String?`, because omitting it is how a caller asks for a
generated one. `stack` is `StackTrace?`, the width `TomException`'s constructor
declares.

| `key` | Condition | Message |
| ----- | --------- | ------- |
| `resources.property.not_configured` | The key is absent and no default was supplied | `Obligatory resource <key> not found in configuration resources` |
| `resources.property.type_mismatch` | The key is present but its value cannot be cast to `T`, and is not an `int` a `double` would accept | `Could not set property of type <T> from value of property <key> with value <value>` |

`parameters` carries `key` for both, and additionally `expectedType` and
`value` for a type mismatch, so a log formatter can render the failure without
parsing the message. `rootException` carries the `TypeError` the cast raised,
which is the only record of the value's *actual* type — the message names only
the type that was wanted. That matters most for a generic mismatch: a
configured `['alpha', 'beta']` read as `List<String>` fails on the element
type, and the message reports `with value [alpha, beta]`, which is what the
operator wrote and looks perfectly valid.

`rootException` carries the `TypeError` the cast raised, on the type-mismatch
path only. It is worth reading: the message names the type that was *wanted*
and the value, but never the value's actual runtime type — the `TypeError` is
the only record of it.

**Absent** means the configuration resolves to nothing at the key, which
includes a key whose configured value is `null` — in a YAML config,
`app.region:` with no value does not satisfy an obligatory property.

The cast failure is raised for both constructors. A default is consulted only
on the absent branch, so `TomProperty.withDefault` does not soften a mistyped
value: a config entry of the wrong type fails at start-up whether or not a
fallback was supplied.

A failure to *read* the configuration at all — an unreadable source, or a
lookup before `TomConfigResourceProvider.setAppConfigProvider` has run —
propagates as itself and is never rewritten into a `TomPropertyException`. The
type-mismatch report is raised only for a genuine cast failure, so seeing one
is evidence about the configured value, not about the config source.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
