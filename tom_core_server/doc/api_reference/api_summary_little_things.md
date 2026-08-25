# Tom Core Server API Reference: Little Things Module

The base exception type for every error raised by `tom_core_server`, adding
isolate attribution and request correlation to the kernel exception — and
`LoginException`, the one subclass declared beside it.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomServerException](#tomserverexception)
- [Global Functions and Constants](#global-functions-and-constants)

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

The module declares one of those subtypes itself: `LoginException`, which sits
here rather than in `authentication` so the 2FA subsystem can throw it without
importing the server that catches it. It adds no members — its constructor
forwards the base payload minus `clientThrow`, which is therefore always the
base default `true`. It is documented in
[api_summary_authentication.md](api_summary_authentication.md#loginexception),
under the module a reader meets it in; the index files it there too, and this
summary gives it no section of its own so that the two documents cannot drift
apart.

## Class Hierarchy

```
TomException  (kernel)
    └── TomServerException
            ├── LoginException   (declared here; documented under Authentication)
            └── …                (every other module's exception type)
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
  Object? stack,
  Object? rootException,
  bool autoLog = false,
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
