# metrics

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

What reads the server's metrics, and the HTTP series it records itself. The
instruments live in `tom_core_kernel`'s `metrics` module; the server records its
requests, statements, connection pools, cache lookups and rate-limit refusals
into the same process registry the kernel's scheduler records its jobs into,
`TomMetrics.registry`. This module exposes that registry two ways: a
**Prometheus scrape** answered at `GET /metrics`, and an **OTLP push** to a
collector over HTTP with JSON bodies. Both read the same instruments, so a
series exists once however it leaves the process.

**The series are recorded whether or not anything reads them**; which export is
on is configuration (`metricsEndpoint`, `otlpEndpoint`). The scrape is answered
at the outer edge of the pipeline, before authentication — infrastructure like a
probe, with a bearer token of its own (`metricsToken`) compared in constant
time. The `route` label is the endpoint's pattern (`/tasks/<id>`), never the raw
path, and a request no endpoint matched is `unmatched`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `tomRequestMetricsMiddleware` | Records `tom_http_server_requests` {method, route, status} and `tom_http_server_request_duration_seconds` {method, route} for every request; `TomServer` places it outside both error layers. |
| `tomMetricsEndpointMiddleware` | Answers `GET` / `HEAD` of the scrape path with the registry in the Prometheus text format, checking the bearer token when one is set; passes every other request on. |
| `tomUnmatchedRoute` | `'unmatched'` — the `route` label of a request no endpoint matched. |
| `TomOtlpHttpTransport` | Posts OTLP/HTTP JSON bodies to `<endpoint>/v1/<signal>` with configured headers; `parseHeaders` reads the `OTEL_EXPORTER_OTLP_HEADERS` form. Signal-neutral — a trace exporter posts `v1/traces` through the same transport. |
| `TomOtlpMetricsExporter` | Pushes the registry every interval, cumulatively; a failed push is logged and the next carries the same totals; `close` pushes once more. |
| `tomOtlpMetricsJson` | A snapshot as an OTLP `ExportMetricsServiceRequest` in the JSON encoding. |
| `TomOtlpExportException` | `otlp.export.failed` and `otlp.config.invalid_headers`. |

## Quick start

```dart
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(tomRequestLogInfoMiddleware())
      .addMiddleware(tomMetricsEndpointMiddleware(token: 's3cret'))
      .addMiddleware(tomRequestMetricsMiddleware())
      .addHandler((_) => Response.notFound(''));

  await handler(Request('GET', Uri.parse('http://localhost/wp-admin')));

  final refused = await handler(
    Request('GET', Uri.parse('http://localhost/metrics')),
  );
  print(refused.statusCode); // 401 — no token

  final scrape = await handler(
    Request(
      'GET',
      Uri.parse('http://localhost/metrics'),
      headers: {'authorization': 'Bearer s3cret'},
    ),
  );
  print(scrape.statusCode); // 200
  // tom_http_server_requests_total{method="GET",route="unmatched",status="404"} 1
  final text = await scrape.readAsString();
  print(text
      .split('\n')
      .firstWhere((l) => l.startsWith('tom_http_server_requests_total')));
}
```

In a server nothing is wired by hand: set `metricsEndpoint: true` (and
`metricsToken`) for a scrape, `otlpEndpoint` for a push, and `TomServer.start`
installs the middleware and starts `TomServer.metricsExporter`.

See [`doc/metrics.md`](../../../../doc/metrics.md) for every series the
framework records, the scrape endpoint, the configuration keys, the OTLP export,
the cardinality rules and what is not measured, and
`example/metrics/metrics_example.dart` for the request series, the scrape, the
token and an OTLP push to an in-process receiver, checking its own results.
`test/metrics_test.dart` covers the module without a database,
`test/metrics_db_test.dart` (tagged `db`) the statement and pool series against
MariaDB or PostgreSQL, and `test/metrics_otel_test.dart` (tagged `otel`, run by
`tool/run_otel_tests.sh`) the exports read by promtool and an OpenTelemetry
Collector. `test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
