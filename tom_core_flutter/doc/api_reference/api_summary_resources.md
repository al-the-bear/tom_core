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
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomclient/resources/tom_properties.dart`.

A `TomProperty<T>` reads its value for `key` from the application
`TomConfigResourceProvider` **once, at construction**, and caches it. The value
is read with `get()` or the `~` operator. Resolution rules (at construction): an
existing key is cast to `T`; an absent key uses the `withDefault` default; an
absent key with no default throws. The value is eager and immutable — later
config changes are not reflected, so construct the property after the config
providers are populated. Use the typed subclasses for the four non-nullable
value types they name rather than the generic over those types; when `T` is
nullable the generic is the intended form, because every subclass closes over
a non-nullable type and so cannot express an optional value:

```dart
final region = TomProperty<String?>.withDefault('app.region', null);
```

## Class Hierarchy

```
TomProperty<T>
    ├── TomStringProperty   (T = String)
    ├── TomIntProperty      (T = int)
    ├── TomDoubleProperty   (T = double)
    └── TomBoolProperty     (T = bool)
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

This module declares no exception type. Both failures are raised as a bare
`Exception` with an interpolated message, so they are catchable only as
`Exception` and distinguishable only by inspecting `toString()`. Neither
carries a stable code, and neither is auto-logged.

Both are thrown from the resolution that both constructors run, so a property
that constructs successfully never raises afterwards — `get()` and `~` only
return the cached value.

| Condition | Message |
| --------- | ------- |
| The key is absent and no default was supplied | `Obligatory resource <key> not found in configuration resources` |
| The key is present but its value cannot be cast to `T` | `Could not set property of type <T> from value of property <key> with value <value>` |

**Absent** means `TomConfigResourceProvider.exists` reports nothing at the key,
which includes a key whose configured value is `null` — in a YAML config,
`app.region:` with no value does not satisfy an obligatory property.

The cast failure is raised for both constructors. A default is consulted only
on the absent branch, so `TomProperty.withDefault` does not soften a mistyped
value: a config entry of the wrong type fails at start-up whether or not a
fallback was supplied.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
