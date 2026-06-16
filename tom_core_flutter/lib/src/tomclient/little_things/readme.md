# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Small client-side cross-cutting helpers. Today this is the client exception
family: thin semantic subtypes of the kernel `TomException` that let client code
distinguish failures raised in the Flutter client (and those safe to show in the
UI) by **type**, not just by message.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomClientException` | Client-side `TomException`; same `key` / `defaultUserMessage` / `parameters` / `stack` / `rootException` / `autoLog` payload, distinguishable via `is TomClientException`. |
| `TomClientUIException` | A `TomClientException` whose `defaultUserMessage` is safe and intended for display; consumers branch on its type to bubble presentable errors to the UI. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  try {
    throw TomClientUIException('login.failed', 'Could not sign in.');
  } on TomClientUIException catch (e) {
    // Presentable — safe to surface to the user.
    print(e.defaultUserMessage); // prints: Could not sign in.
  } on TomClientException catch (_) {
    // Other client failures handled generically.
  }
}
```

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
