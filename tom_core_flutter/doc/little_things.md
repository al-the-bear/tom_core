# Little Things Module

Small client-side helpers for `tom_core_flutter`. Currently this module
provides two **exception types** layered on the kernel's exception model.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Why a distinct type](#why-a-distinct-type)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Extends | Meaning |
| ---- | ------- | ------- |
| `TomClientException` | `TomException` (kernel) | A failure raised on the client side |
| `TomClientUIException` | `TomClientException` | A client failure whose message is safe to show the user |

Both are thin subtypes — they carry the same payload as the kernel
[`TomException`](../../tom_core_kernel/doc/security/security.md) (`key`,
`defaultUserMessage`, `parameters`, `stack`, `rootException`, `autoLog`) and add
only a **semantic type** that client code can branch on.

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Raise a user-facing error:
throw TomClientUIException(
  'login.failed',
  'Could not sign you in. Please try again.',
);

// Wrap an internal failure, surfacing only presentable ones:
try {
  await initialize();
} catch (e) {
  if (e is TomClientUIException) rethrow; // already presentable
  throw TomClientUIException(
    'app.initialization.failed',
    'The application could not start.',
    rootException: e,
  );
}
```

## Why a distinct type

The value of these classes is the **type**, not the message. UI layers catch a
generic `TomException`, then check `e is TomClientUIException` to decide whether
the error can be displayed verbatim or must be wrapped/sanitized first. Throwing
a plain `TomException` would force callers to inspect `key` strings; the subtype
makes the "is this safe to show?" decision a compile-checked `is` test.

## Core Components

### `TomClientException`

A client-originated error. Use it for failures that should be handled in code
but are **not** necessarily safe to present to a user.

### `TomClientUIException`

A client error intended for display. Throw it when `defaultUserMessage` is a
finished, user-appropriate message. The common pattern is
`if (e is TomClientUIException) rethrow;` to let presentable errors bubble up.

---

## Dependencies

- **`tom_core_kernel`**: the base `TomException` (logging, UUID, server-error
  tracking) that both types extend.
