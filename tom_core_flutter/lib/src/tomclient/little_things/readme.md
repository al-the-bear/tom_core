# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Small client-side cross-cutting helpers. Today this is the client exception
family: thin semantic subtypes of the kernel `TomException` that let client code
distinguish failures raised in the Flutter client (and those safe to show in the
UI) by **type**, not just by message.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomClientException` | Client-side `TomException`, distinguishable via `is TomClientException`. Forwards the kernel's whole argument list — `key`, `defaultUserMessage`, `uuid`, `requestUuid`, `parameters`, `stack`, `rootException`, `autoLog`, `serverCallError` — because every client exception type chains through this constructor, so one missing here is missing from all of them. |
| `TomClientUIException` | A `TomClientException` whose `defaultUserMessage` is safe and intended for display; consumers branch on its type to bubble presentable errors to the UI. |

## Quick start

```dart complete
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

## Naming the request a failure belongs to

`uuid`, `requestUuid` and `serverCallError` say *which* failure this is rather
than what it was, and a client has a use for each: a failure rebuilt from a
server's error envelope must keep the identity the far side logged it under; the
client is the side that issues requests, so it holds the correlation id; and a
client is where outbound HTTP calls originate.

`TomUserPreferencesClientException` is the first to fill them. Every rejection
carries the answer as a `TomServerCallError`, and when the server replied with
the framework's error envelope its `requestUuid` is copied onto the exception —
so the client's report and the server's log line name the same request. The
server's `uuid` is *not* borrowed: this exception was raised here, not rebuilt
from the server's.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
