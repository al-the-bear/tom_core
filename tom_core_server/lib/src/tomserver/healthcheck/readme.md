# healthcheck

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A pluggable liveness/health endpoint. `TomHealthService.health()` returns a
status string; `TomHealthServer` is the default implementation, delegating the
actual assessment to a `TomHealthAnalyzer` (the `TomDefaultHealthAnalyzer`
reports healthy). Swap in a custom analyzer to probe datasources, caches, or
downstream services.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHealthService` | Abstract contract: `Future<String> health()`. |
| `TomHealthServer` | Default service; runs the configured `TomHealthAnalyzer` and returns its string as the body, unchanged. |
| `TomHealthAnalyzer` | Abstract probe that decides the health verdict. |
| `TomDefaultHealthAnalyzer` | Always-healthy analyzer used when no custom probe is supplied. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final TomHealthService service = TomHealthServer();
  final status = await service.health();

  print(status); // OK  (from the default TomDefaultHealthAnalyzer)
}
```

See [`doc/healthcheck.md`](../../../../doc/healthcheck.md) for the verdict
contract and how a deployment supplies its own analyzer, and
`example/healthcheck/healthcheck_example.dart` for a connection-free walkthrough
that checks its own results. `test/healthcheck_test.dart` covers the module and
`test/endpoints_pipeline_test.dart` pins the route it is served on, in the group
`healthcheck GET /health route` — the analyzer is reachable in-process, but the
path a load balancer polls is only a fact once something serves it.
`test/examples_test.dart` runs the example and
`test/readme_quick_start_test.dart` runs the snippet above, so neither can drift
away from the code.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
