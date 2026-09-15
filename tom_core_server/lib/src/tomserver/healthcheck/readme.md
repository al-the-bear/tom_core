# healthcheck

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Two pluggable probe endpoints: `GET /health` (**liveness** — am I running) and
`GET /ready` (**readiness** — can I serve traffic). Each answers with its
analyzer's message as the body and the **verdict as the status code** — 200
healthy, 503 unhealthy — so an ordinary probe, which reads the code and nothing
else, is correct without configuration.

Two routes because the questions have opposite consequences: a failing liveness
probe restarts the process, a failing readiness probe takes it out of the load
balancer and leaves it running. A dependency being down belongs on readiness.
`TomHealthServer` is the default implementation, delegating each route to its
own `TomHealthAnalyzer` (both default to the always-healthy
`TomDefaultHealthAnalyzer`).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHealthService` | Abstract contract: `Future<Response> health()` and `ready()` — a `Response` because the status code is part of the answer. |
| `TomHealthServer` | Default service; runs `livenessAnalyzer` for `/health` and `readinessAnalyzer` for `/ready`, turning each verdict into the response. Both are read-only; install through `installLivenessAnalyzer` / `installReadinessAnalyzer`, which log the replacement, and `resetHealthAnalyzers()` to go back to the defaults. |
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

  final readiness = await service.ready();
  print(readiness.statusCode);             // 200 — the same default
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
