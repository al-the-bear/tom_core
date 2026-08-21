# shutdown_cleanup

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Orderly teardown. `TomShutdownCleanup` collects disposables, closables, and OS
signal handlers and runs them when the process shuts down, so resources
(connections, isolates, files) are released deterministically.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomShutdownCleanup` | Registry of cleanup actions; runs registered closables/disposables/signal handlers on shutdown. |
| `TomDisposable` | Contract for objects with a `dispose()` lifecycle. |
| `TomClosable` | Contract for objects with a `close()` lifecycle. |
| `TomCloseAdaptor` | Adapts a close-style method into a `TomClosable`, via the global `tomReflector` — so the target's class must carry `@tomReflector`. |
| `tomShutdownCleanup` | The shared global `TomShutdownCleanup` instance. |
| `TomSignalHandler` | Typedef for an OS-signal callback. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

class CacheService implements TomClosable {
  @override
  Future<void> close() async => print('cache flushed');
}

void main() {
  // Register resources on the shared instance; they run in registration
  // order when a shutdown signal arrives. Listening for SIGHUP and SIGINT
  // is already active — the instance arms it on construction — so this
  // registration is the entire setup.
  tomShutdownCleanup.addClosable(CacheService());
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
