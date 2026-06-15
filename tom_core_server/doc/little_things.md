# Little Things Module

The server-side base exception. This module contributes a single type,
`TomServerException`, which every other `tom_core_server` exception extends.

## Table of Contents

- [Overview](#overview)
- [TomServerException](#tomserverexception)
- [Isolate Attribution](#isolate-attribution)
- [Request Correlation](#request-correlation)
- [The clientThrow Flag](#the-clientthrow-flag)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomServerException` | class | Base class for all server-raised exceptions; extends the kernel's `TomException` |

The kernel already provides `TomException` (UUID tracking, parameters,
auto-logging, request UUID). `TomServerException` layers two server-specific
concerns on top: it records **which isolate** produced the error and it
**correlates** the error with the active request.

## TomServerException

```dart
throw TomServerException(
  'PAYMENT_FAILED',
  'The payment could not be processed',
  clientThrow: false, // internal detail — do not surface to the caller
);
```

Because every server exception subtypes `TomServerException`, a single catch
clause reaches all of them:

```dart
try {
  await handleRequest();
} on TomServerException catch (e) {
  log.error('${e.isolateName}: ${e.key} (req ${e.requestUuid})');
  if (e.clientThrow) respondWith(e.defaultUserMessage);
  else respondWith('Internal error');
}
```

## Isolate Attribution

Server work is spread across an isolate pool, so the bare error message alone
does not tell you which worker failed. `TomServerException` captures
`Isolate.current.debugName` into `isolateName` at construction time (falling
back to `"unnamed isolate"` when the isolate has no debug name), and appends it
to `toString()`. This makes a logged error self-identifying without the call
site having to record the isolate explicitly.

## Request Correlation

The endpoints pipeline sets a `TomRequestId` in the zone for the lifetime of a
request. When a `TomServerException` is constructed inside that zone, its
constructor reads the id via `getFromCurrentZone<TomRequestId>()` and copies the
UUID into the inherited `requestUuid` field. The error is therefore linked to
the request that triggered it without any code threading the id through the call
stack. Outside a request zone (e.g. during startup) `requestUuid` is simply left
unset.

## The clientThrow Flag

`clientThrow` (default `true`) marks whether the exception is safe to surface to
the caller. The endpoints pipeline may relay the user message of a
`clientThrow: true` exception, while a `clientThrow: false` exception should be
masked behind a generic error response — use it for internal failures whose
detail must not leak.

## Core Components

- **`TomServerException`** — the base server exception. Adds `isolateName`
  (originating worker), `clientThrow` (client-safe flag), and zone-based
  `requestUuid` population to the kernel's `TomException`.

## Dependencies

- `tom_core_kernel` — `TomException` (the base class), `getFromCurrentZone`.
- The server module — `TomRequestId` (the zone-carried request identifier).
- `dart:isolate` — `Isolate.current` for the worker's debug name.
