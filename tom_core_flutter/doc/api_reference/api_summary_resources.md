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

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| default | `TomProperty(String key)` | Resolves `key` from config at construction; throws if absent. |
| `withDefault` | `TomProperty.withDefault(String key, T value)` | Resolves `key`, falling back to `value` when the key is absent. |

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

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
