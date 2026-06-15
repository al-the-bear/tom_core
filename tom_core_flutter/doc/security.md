# Security Module

Client-side security annotations for `tom_core_flutter`. Currently the module
provides a single marker annotation used to tag client two-factor (2FA)
authentication adaptors so a runtime can discover them by reflection.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [How Discovery Works](#how-discovery-works)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomClient2FAAdaptor` | `const` annotation (`@tomReflector`) | Tags a class as a client-side 2FA adaptor for a given `type` |

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

@TomClient2FAAdaptor('totp')
class TotpAdaptor {
  // ... client TOTP implementation ...
}
```

The annotation carries a single `type` string identifying the 2FA mechanism
(e.g. `'totp'`, `'sms'`).

## How Discovery Works

`TomClient2FAAdaptor` is itself `@tomReflector`-registered, so it appears in the
generated reflection data. A runtime can enumerate classes annotated with it and
dispatch to the right adaptor based on its `type` — without the framework
hard-coding the set of supported 2FA mechanisms.

Because the class participates in reflection, its signature (name, the `type`
field, the `const` constructor) is a contract: changing it requires
regenerating reflection for consumers.

## Core Components

### `TomClient2FAAdaptor`

A `const` annotation with one positional argument, `type`. Apply it to a
client-side 2FA adaptor class; read `type` back via reflection to route
authentication flows.

---

## Dependencies

- **`tom_core_kernel`**: the `@tomReflector` marker that makes the annotation
  reflection-discoverable.
