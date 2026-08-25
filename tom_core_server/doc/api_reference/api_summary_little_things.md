# Tom Core Server API Reference: Little Things Module

The base exception type for every error raised by `tom_core_server`, adding
isolate attribution and request correlation to the kernel exception — plus
`TomLoginException`, the one subclass declared beside it, and `TomRequestId`,
the correlation id the base reads out of the zone.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomRequestId](#tomrequestid)
  - [TomServerException](#tomserverexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/little_things/request_id.dart`,
`lib/src/tomserver/little_things/server_exception.dart`.

`TomServerException` is the root of the server's exception hierarchy: every
server exception type (e.g. `TomEndpointHandlerException`, `TomCacheException`,
`MariadbMigrationException`, and `TomLoginException`) subtypes it, so a single
`on TomServerException catch (e)` clause reaches all of them. Over the kernel's
`TomException` it adds two server-specific concerns: **isolate attribution** —
it captures `isolateName` at construction so a logged or serialized error
identifies the worker isolate that produced it — and **request correlation** —
when the surrounding zone carries a `TomRequestId`, the constructor copies its
UUID into `TomException.requestUuid`, linking the error to the request that
triggered it. The `clientThrow` flag marks whether the exception is safe to
surface to the client.

The module declares one of those subtypes itself: `TomLoginException`, which
sits here rather than in `authentication` so the 2FA subsystem can throw it
without importing the server that catches it. It adds no members — its
constructor forwards the base payload minus `clientThrow`, so a
`TomLoginException` always carries the base default `true` — and because the
field is `final`, that is an invariant of the type rather than a starting value.
It is documented in
[api_summary_authentication.md](api_summary_authentication.md#tomloginexception),
under the module a reader meets it in; the index files it there too, and this
summary gives it no section of its own so that the two documents cannot drift
apart.

## Class Hierarchy

```
TomRequestId          (standalone)

TomException  (kernel)
    └── TomServerException
            ├── TomLoginException  (declared here; documented under Auth)
            └── …                  (every other module's exception type)
```

## Classes

### TomRequestId

A per-request correlation id. `tomDefaultAuthenticationMiddleware` (server
module) creates one per incoming request and publishes it into the request zone,
so any code under that request can recover it with
`getFromCurrentZone<TomRequestId>()`. It is read by the `TomServerException`
constructor, by the endpoints pipeline, and by
`TomAuditTrail.currentRequestId()`.

It is declared in this module rather than beside the middleware that produces it
so that the package's most depended-upon module does not import its largest one.

#### Constructors

```dart
TomRequestId()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `uuid` | `String` | A freshly generated v4 UUID identifying this request (`late final`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Returns `"TomRequestId: <uuid>"`. |

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
| `isolateName` | `final String` | The debug name of the isolate that constructed this exception (falls back to `"unnamed isolate"`). |
| `clientThrow` | `final bool` | Whether this exception is safe to propagate to the client (default `true`). Fixed at construction — a catch site that must not surface a particular failure masks it in the response it builds. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The base `TomException` string extended with `isolateName`, the `clientThrow` flag, and — only when the exception was raised inside a request — a labelled ` request: <uuid>` segment. The segment is omitted entirely when `requestUuid` is null. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
