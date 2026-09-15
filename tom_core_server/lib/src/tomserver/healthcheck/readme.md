# healthcheck

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A pluggable liveness/health endpoint. `TomHealthService.health()` answers with
the analyzer's message as the body and its **verdict as the status code** — 200
healthy, 503 unhealthy — so an ordinary probe, which reads the code and nothing
else, stops sending traffic to a process that says it cannot serve.
`TomHealthServer` is the default implementation, delegating the actual
assessment to a `TomHealthAnalyzer` (the `TomDefaultHealthAnalyzer` reports
healthy). Swap in a custom analyzer to probe datasources, caches, or downstream
services.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHealthService` | Abstract contract: `Future<Response> health()` — a `Response` because the status code is part of the answer. |
| `TomHealthServer` | Default service; runs the configured `TomHealthAnalyzer` and turns its verdict into the response. |
| `TomHealthAnalyzer` | Abstract probe that decides the health verdict. |
| `TomHealthStatus` · `TomHealthVerdict` | What an analyzer concludes: the verdict a probe acts on, and the message a person reads. Two verdicts, because HTTP offers a probe two answers. |
| `TomDefaultHealthAnalyzer` | Always-healthy analyzer used when no custom probe is supplied. |

## Quick start

```dart
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final TomHealthService service = TomHealthServer();
  final response = await service.health();

  print(response.statusCode);              // 200
  print(await response.readAsString());    // OK  (TomDefaultHealthAnalyzer)
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
