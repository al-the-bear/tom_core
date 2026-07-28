# Tom Core Kernel API Reference: Result Module

The canonical success-or-error envelope every Tom operation returns, so an
application outcome — including a failure — travels as a normal response body
rather than as an HTTP error.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomResult](#tomresult)
  - [TomErrorResult](#tomerrorresult)
  - [TomFieldError](#tomfielderror)
- [Enums](#enums)
  - [TomErrorSeverity](#tomerrorseverity)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/result/result.dart`.

The module draws one line: **transport failure vs application outcome**. Only
5xx responses are transport errors; everything the application itself decided —
a validation rejection, a "not found", a business-rule refusal — comes back in a
normal 2xx body as a `TomResult`. A result is in exactly one arm, success
(carrying a `value` of type `T`, which may legitimately be `null` for operations
with no payload) or error (carrying a `TomErrorResult`).

The wire form carries an explicit `success` boolean, so a client branches on a
discriminator rather than on which key happens to be present:

```json
{ "success": true,  "value": { ... } }
{ "success": false, "error": { "code": "…", "severity": "error", … } }
```

`TomErrorResult.code` is the join key: server logic raises it, and user-facing
copy is resolved *from* it, so message text never has to be duplicated on both
sides. `TomResult.fromJson` deliberately leaves the success `value` as the raw
decoded payload — converting it to a typed `T` is a call-site concern, which
keeps the envelope itself free of any reflection dependency.

The types implement `TomJsonSerializable` (from the `json` module) and nothing
else; the envelope is usable unchanged on client and server.

## Class Hierarchy

```
TomResult<T>       (implements TomJsonSerializable)
TomErrorResult     (implements TomJsonSerializable)
TomFieldError      (implements TomJsonSerializable)

TomErrorSeverity   (enum)
```

## Classes

### TomResult

The success-or-error envelope. Always in exactly one arm: never both, never
neither.

- **Implements:** `TomJsonSerializable`
- **Type parameters:** `T` — the success payload type.

#### Constructors

```dart
const TomResult.success([T? value])
const TomResult.failure(TomErrorResult error)
factory TomResult.fromJson(Map<String, Object?> json)
```

`fromJson` treats a missing `success` key as success when there is no `error`,
and substitutes the code `UNKNOWN_ERROR` when the error arm is unparseable — so
a malformed payload still yields a well-formed result.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `value` | `T?` | The success payload; possibly `null` on the success arm, always `null` on the error arm. |
| `error` | `TomErrorResult?` | The structured error; `null` on the success arm. |
| `isSuccess` | `bool` | Whether this is the success arm (getter — true exactly when `error` is `null`). |
| `isError` | `bool` | Whether this is the error arm (getter). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* Emits the `success` discriminator plus whichever arm is populated. |
| `toString` | `String toString()` | *(override)* `TomResult.success(…)` / `TomResult.failure(…)`. |

### TomErrorResult

A structured application error. Not an exception and not a transport error — it
is a normal result value returned in a 2xx body.

- **Implements:** `TomJsonSerializable`

#### Constructors

```dart
const TomErrorResult(
  String code, {
  String? message,
  List<TomFieldError> fieldErrors = const [],
  bool retryable = false,
  TomErrorSeverity severity = TomErrorSeverity.error,
})

factory TomErrorResult.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `code` | `String` | The machine-readable code clients branch on and copy is keyed to. Stable across releases. |
| `message` | `String?` | An optional default/developer message; user-facing text resolves from `code`, not from here. |
| `fieldErrors` | `List<TomFieldError>` | Per-field details when the failure is attributable to specific input; empty for whole-operation errors. |
| `retryable` | `bool` | Whether retrying the same operation unchanged could reasonably yield a different outcome. |
| `severity` | `TomErrorSeverity` | Presentation hint for the client. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* Omits `message` when null and `fieldErrors` when empty. |
| `toString` | `String toString()` | *(override)* Code, message, severity, retryable flag and field-error count. |

### TomFieldError

A single field-level detail inside a `TomErrorResult`.

- **Implements:** `TomJsonSerializable`

#### Constructors

```dart
const TomFieldError(String field, String code, {String? message})
factory TomFieldError.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The offending field or dotted field path, e.g. `email` or `address.postalCode`. |
| `code` | `String` | The machine-readable code for this field, keyed to copy exactly like the top-level code. |
| `message` | `String?` | Optional default/developer message. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* Omits `message` when null. |
| `toString` | `String toString()` | *(override)* `TomFieldError(field: code)`. |

## Enums

### TomErrorSeverity

How serious an error is — a hint the client uses to choose a presentation (a
toast, a blocking dialog, a field annotation).

| Value | Meaning |
| ----- | ------- |
| `info` | Informational; the operation may have partially succeeded or produced a non-blocking notice. |
| `warning` | The user should see it, but it does not block the outcome. |
| `error` | A normal application error — the operation did not succeed. |
| `fatal` | Severe/unexpected; the user generally cannot proceed. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `wireName` | `String` | The stable lowercase wire token (the enum name). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromWire` | `static TomErrorSeverity fromWire(Object? value)` | Parses a wire token, falling back to `error` for `null` or an unrecognized value — so a severity added by a newer server never breaks an older client. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
