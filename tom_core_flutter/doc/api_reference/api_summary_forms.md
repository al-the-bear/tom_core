# Tom Core Flutter API Reference: Forms Module

Legacy observable form model — fields that resolve their labels/validation
messages from kernel text resources, and a form aggregate over them.

> **Superseded by the `TomForm` framework in `tom_flutter_ui`.** Retained for
> existing consumers (e.g. `tom_uam_client`); the `Old` suffix marks the legacy
> surface.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomFieldOld&lt;T&gt;](#tomfieldoldt)
  - [TomEmailField&lt;T&gt;](#tomemailfieldt)
  - [TomPasswordField&lt;T&gt;](#tompasswordfieldt)
  - [TomFormOld](#tomformold)

## Overview

Source: `lib/src/tomclient/forms/tom_fields.dart`, `lib/src/tomclient/forms/tom_form.dart`.

A `TomFieldOld<T>` is an observable single value (it extends the kernel
`TomObject<T>`) that knows its `formName`/`fieldName`, resolves its display text
and error messages from the kernel `TomTextResourceProvider` under the key
`"$formName.$fieldName"`, and builds its own widget. `TomEmailField` and
`TomPasswordField` add built-in validators. `TomFormOld` is a `TomMap` of fields
that offers form-wide `validate`/`save`/`errors` and widget building.

## Class Hierarchy

```
TomObject<T>  (kernel)
    └── TomFieldOld<T>
            ├── TomEmailField<T>
            └── TomPasswordField<T>

TomMap<String, TomFieldOld>  (kernel)
    └── TomFormOld
```

## Classes

### TomFieldOld&lt;T&gt;

Observable form field: a `TomObject<T>` whose label/validation text is resolved
from kernel text resources and that builds its own input widget.

- **Extends:** `TomObject<T>`
- **Type Parameters:** `T` — the converted (saved) value type.

#### Constructors

```dart
TomFieldOld(
  String formName,
  String fieldName,
  T initialValue, {
  bool obscureText = false,
  T Function(String)? valueConverter,
  String Function(T)? valueToTextConverter,
  String? Function(String)? inputValidator,
  String? Function(String)? valueValidator,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `formName` | `String` | Owning form name; first half of the resource key. |
| `fieldName` | `String` | Field name; second half of the resource key. |
| `initialValue` | `T` | Value the field is seeded with and reset to. |
| `obscureText` | `bool` | Whether the input hides its characters (passwords). |
| `currentRawValue` | `String` | The current raw text entered by the user. |
| `t` | `String Function(String)` | Resource-text lookup (throws if the key is missing). |
| `tOrNull` | `String? Function(String)` | Resource-text lookup returning `null` if absent. |
| `errorText` | `String?` | Current validation error message, or `null` when valid. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `validate` | `bool validate()` | Runs the validators; returns `true` when the field is valid and populates `errorText` otherwise. |
| `save` | `T save()` | Converts `currentRawValue` to `T` and stores it as the field value. |
| `set` | `T set(T value)` | *(override)* Sets the value and notifies observers. |
| `reset` | `void reset()` | Restores `initialValue` and clears the raw value. |
| `getField` | `Widget getField()` | Builds the Flutter input widget for the field. |

### TomEmailField&lt;T&gt;

`TomFieldOld` pre-wired with an e-mail validator (required + valid-email).

- **Extends:** `TomFieldOld<T>`

#### Constructors

```dart
TomEmailField(
  String formName,
  String fieldName,
  T initialValue, {
  bool obscureText,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isValidEmail` | `static bool isValidEmail(String s)` | Whether `s` is a syntactically valid e-mail address. |

### TomPasswordField&lt;T&gt;

`TomFieldOld` pre-wired with a password validator (required + minimum length 4)
and `obscureText` defaulting to `true`.

- **Extends:** `TomFieldOld<T>`

#### Constructors

```dart
TomPasswordField(
  String formName,
  String fieldName,
  T initialValue, {
  bool obscureText = true,
})
```

### TomFormOld

Observable collection of `TomFieldOld`s keyed by field name, with form-wide
operations.

- **Extends:** `TomMap<String, TomFieldOld>`

#### Constructors

```dart
TomFormOld(Map<String, TomFieldOld> form)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getFields` | `List<Widget> getFields()` | Builds the widget for every field, in iteration order. |
| `getField` | `Widget getField(String name)` | Builds the widget for the field registered under `name`. |
| `validate` | `bool validate()` | Validates every field (no short-circuit) and returns `true` only when all pass. |
| `errors` | `Map<String, String?> errors()` | Current error message per field, keyed by field name. |
| `save` | `Map<String, Object> save()` | Saves every field (notifications muted across the batch) and returns the converted values by field name. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
