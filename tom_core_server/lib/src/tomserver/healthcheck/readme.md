# healthcheck

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A pluggable liveness/health endpoint. `TomHealthService.health()` returns a
status string; `TomHealthServer` is the default implementation, delegating the
actual assessment to a `HealthAnalyzer` (the `DefaultHealthAnalyzer` reports
healthy). Swap in a custom analyzer to probe datasources, caches, or downstream
services.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHealthService` | Abstract contract: `Future<String> health()`. |
| `TomHealthServer` | Default service; runs the configured `HealthAnalyzer` and renders its verdict. |
| `HealthAnalyzer` | Abstract probe that decides the health verdict. |
| `DefaultHealthAnalyzer` | Always-healthy analyzer used when no custom probe is supplied. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final TomHealthService service = TomHealthServer();
  final status = await service.health();

  print(status); // OK  (from the default DefaultHealthAnalyzer)
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
