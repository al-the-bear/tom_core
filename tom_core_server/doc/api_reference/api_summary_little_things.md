# Tom Core Server API Reference: Little Things Module

The base exception type for every error raised by `tom_core_server`, adding
isolate attribution and request correlation to the kernel exception.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomServerException](#tomserverexception)

## Overview

Source: `lib/src/tomserver/little_things/server_exception.dart`.

`TomServerException` is the root of the server's exception hierarchy: every
server exception type (e.g. `TomEndpointHandlerException`, `TomCacheException`,
`MariadbMigrationException`, and `LoginException`) subtypes it, so a
`catch (e) on TomServerException` reaches all of them. Over the kernel's
`TomException` it adds two server-specific concerns: **isolate attribution** —
it captures `isolateName` at construction so a logged or serialized error
identifies the worker isolate that produced it — and **request correlation** —
when the surrounding zone carries a `TomRequestId`, the constructor copies its
UUID into `TomException.requestUuid`, linking the error to the request that
triggered it. The `clientThrow` flag marks whether the exception is safe to
surface to the client.

## Class Hierarchy

```
TomException  (kernel)
    └── TomServerException
```

## Classes

### TomServerException

Base class for every exception raised by `tom_core_server`, extending the
kernel's `TomException` with isolate attribution and request correlation.

- **Extends:** `TomException`

#### Constructors

```dart
TomServerException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  bool clientThrow = true,
})
```

Copies the current zone's `TomRequestId` UUID into `requestUuid` when present.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isolateName` | `String` | The debug name of the isolate that constructed this exception (falls back to `"unnamed isolate"`). |
| `clientThrow` | `bool` | Whether this exception is safe to propagate to the client (default `true`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The base `TomException` string extended with `isolateName`, the `clientThrow` flag, and the correlated request UUID. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
