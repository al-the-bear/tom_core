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

`TomServer.start` answers `/ready` with `TomFrameworkReadinessAnalyzer` unless
the application installed a readiness analyzer of its own (configuration key
`frameworkReadiness`, on by default): every registered data source operational
and answering `SELECT 1`, no database migration running or failed, every started
message outbox delivering. The body is `ready` or `not ready` followed by one
line per check. Liveness is left alone.

A graceful shutdown (`TomServer.shutdown`, run on SIGTERM and SIGINT) begins
with `TomHealthServer.markShuttingDown()`: from then on `/ready` answers
`503 shutting down` without asking its analyzer, so the load balancer stops
sending traffic, while `/health` still asks its liveness analyzer — a draining process is
alive.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHealthService` | Abstract contract: `Future<Response> health()` and `ready()` — a `Response` because the status code is part of the answer. |
| `TomHealthServer` | Default service; runs `livenessAnalyzer` for `/health` and `readinessAnalyzer` for `/ready`, turning each verdict into the response. Both are read-only; install through `installLivenessAnalyzer` / `installReadinessAnalyzer`, which log the replacement, and `resetHealthChecks()` to go back to the defaults. `markShuttingDown()` turns readiness to `503 shutting down` for a graceful shutdown; `isShuttingDown` reads it. Each analyzer runs under `healthTimeout` (five seconds by default, `installHealthTimeout` to change it), so one that hangs or throws still yields an unhealthy verdict rather than stopping the probe from answering — a throw would otherwise reach the pipeline's error envelope, a 500 carrying JSON where the probe expects plain text. |
| `TomHealthAnalyzer` | Abstract probe that decides the health verdict. |
| `TomHealthStatus` · `TomHealthVerdict` | What an analyzer concludes: the verdict a probe acts on, and the message a person reads. Two verdicts, because HTTP offers a probe two answers. |
| `TomDefaultHealthAnalyzer` | Always-healthy analyzer used when no custom probe is supplied. |
| `TomFrameworkReadinessAnalyzer` | The framework's readiness checks — data sources, migrations, started outboxes — with `dataSourceTimeout` (two seconds) and the optional `maxOutboxWait` (off by default: a shared backlog would take every node out of the load balancer at once). Compose it into an application analyzer by asking it first. |
| `TomReadinessCheck` | One check of that analyzer: `subject`, `passed`, `detail`; `checks()` returns them. |

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
that checks its own results, and
`example/healthcheck/readiness_logging_example.dart` for the framework readiness
checks and the JSON log line of a request. `test/healthcheck_test.dart` covers the module and
`test/endpoints_pipeline_test.dart` pins the route it is served on, in the group
`healthcheck GET /health route` — the analyzer is reachable in-process, but the
path a load balancer polls is only a fact once something serves it.
`test/structured_logs_readiness_test.dart` and its `db`-tagged sibling cover the
framework readiness checks, and `test/graceful_shutdown_test.dart` readiness
during a shutdown. `test/examples_test.dart` runs the examples and
`test/readme_quick_start_test.dart` runs the snippet above, so neither can drift
away from the code.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
