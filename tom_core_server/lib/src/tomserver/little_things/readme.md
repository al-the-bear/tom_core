# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The server-side base exception. `TomServerException` extends the kernel's
`TomException` with the originating isolate name, a `clientThrow` flag (whether
the message may surface to the caller or must be masked as an internal error),
and automatic correlation with the active `TomRequestId` when one is present in
the current zone. Every other server module raises a subclass of this type.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomServerException` | Base server error: carries `key` + `defaultUserMessage`, records `isolateName`, exposes `clientThrow`, and copies the active request UUID into `requestUuid` for correlation. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  final err = TomServerException(
    'error.order.not-found',
    'No order matched the supplied id.',
    clientThrow: true,
  );

  print(err.key);         // error.order.not-found
  print(err.clientThrow); // true  (safe to surface to the client)
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
