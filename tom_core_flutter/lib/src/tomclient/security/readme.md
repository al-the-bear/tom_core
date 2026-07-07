# security

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Client-side authentication building blocks. Today this is the annotation that
tags a class as a two-factor (2FA) adaptor so a runtime can discover and
dispatch the available client 2FA mechanisms by reflection.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomClient2FAAdaptor` | Reflection-discoverable annotation (`@tomReflector`-registered) marking a class as a client 2FA adaptor; carries the mechanism via `type` (e.g. `'totp'`, `'sms'`). |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Tag a client adaptor with the 2FA mechanism it implements. A runtime can
// then enumerate all `@TomClient2FAAdaptor`-annotated classes via reflection
// and dispatch by `type`.
@TomClient2FAAdaptor('totp')
class TotpAdaptor {
  // ... TOTP challenge/verify implementation ...
}
```

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
