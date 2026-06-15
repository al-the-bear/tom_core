# Forms Module (legacy)

The forms module provides the **legacy** form primitives of
`tom_core_flutter`: observable input fields backed by Material `TextField`s, and
an observable form aggregate. They extend the kernel observable types
(`TomObject`, `TomMap`) so a form and its fields participate in the normal Tom
observation model.

> **Status:** these `…Old` types are retained for existing consumers (e.g.
> `tom_uam_client`). New code should prefer the richer `TomForm`/`TomField`
> framework in `tom_flutter_ui`.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Validation model](#validation-model)
- [Resource keys](#resource-keys)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Extends | Purpose |
| ---- | ------- | ------- |
| `TomFieldOld<T>` | `TomObject<T>` | A single observable field bound to a `TextField` |
| `TomEmailField<T>` | `TomFieldOld<T>` | Field requiring a non-empty, valid email |
| `TomPasswordField<T>` | `TomFieldOld<T>` | Field requiring a non-empty password (min. 4 chars), obscured |
| `TomFormOld` | `TomMap<String, TomFieldOld>` | An observable collection of fields keyed by name |

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

final form = TomFormOld({
  'email': TomEmailField<String>('login', 'email', ''),
  'password': TomPasswordField<String>('login', 'password', ''),
});

// Build the field widgets inside any layout:
//   Column(children: form.getFields())

// Validate and read back the values:
if (form.validate()) {
  final values = form.save(); // { 'email': '...', 'password': '...' }
}
```

## Validation model

A field runs two distinct validation passes:

| Pass | When it runs | On failure |
| ---- | ------------ | ---------- |
| **Input validators** | On every keystroke (controller listener) | The edit is **rejected** — text reverts to `currentRawValue` |
| **Value validators** | On demand via `validate()` | `errorText` is set; the text is **not** reverted |

`TomEmailField` and `TomPasswordField` add value validators. An input-pattern
validator is added automatically when a `"$formName.$fieldName.pattern"`
resource key resolves to a regular expression.

`validate()` returns `true` only when all value validators pass. `TomFormOld.validate()`
runs **every** field (no short-circuit) so all error messages are populated in a
single call; read them with `errors()`.

## Resource keys

Field labels, helper text, the input pattern, and error messages are resolved
from the kernel `TomTextResourceProvider` under the prefix
`"$formName.$fieldName"`:

| Key suffix | Used for |
| ---------- | -------- |
| `.label` | `TextField` label |
| `.helperText` | `TextField` helper text |
| `.pattern` | Optional input regex (per-keystroke) |
| `.errors.pattern` | Message when the input pattern fails |
| `.errors.required` | Message when an email/password field is empty |
| `.errors.validEmail` | Message when an email is malformed |
| `.errors.minimumLength` | Message when a password is shorter than 4 |

Missing keys fall back to the key itself, so an unconfigured field still
renders and surfaces a (developer-visible) placeholder message.

## Core Components

### `TomFieldOld<T>`

| Member | Description |
| ------ | ----------- |
| `validate()` | Runs value validators; sets `errorText`; returns validity |
| `save()` | Converts the current text to `T`, stores and returns it |
| `reset()` | Restores `initialValue` and syncs the editor |
| `set(value)` | Sets the value and mirrors it into the editor |
| `getField()` | Builds the Material `TextField` (rebuilds on error change) |
| `errorText` | Current error message, or `null` |
| `currentRawValue` | Last accepted raw text |
| `t` / `tOrNull` / `c` / `configExists` | Resource/config lookup helpers |

### `TomEmailField<T>` / `TomPasswordField<T>`

Add the email / password value validators described above.
`TomEmailField.isValidEmail(String)` exposes the email check as a static.

### `TomFormOld`

| Member | Description |
| ------ | ----------- |
| `getFields()` | Widgets for every field, in order |
| `getField(name)` | Widget for one named field |
| `validate()` | Validates all fields (no short-circuit) |
| `errors()` | Field name → current error message |
| `save()` | Field name → converted value (notifications muted across the batch) |

---

## Dependencies

- **Flutter** (`material`): `TextField`, `TextEditingController`, `ValueNotifier`.
- **`tom_core_kernel`**: `TomObject` / `TomMap` (observation), and
  `TomTextResourceProvider` / `TomConfigResourceProvider` (resource lookup).
