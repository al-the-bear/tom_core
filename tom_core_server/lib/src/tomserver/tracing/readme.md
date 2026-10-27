# tracing

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The OpenTelemetry tracer of a Tom server. The framework opens its spans through
`tom_core_kernel`'s tracing seam, `TomTracing` — a server span per request, a
client span per SQL statement and outgoing HTTP call, a span per transaction,
job run, outbox send and outbox delivery. This module supplies the tracer that
records them with the OpenTelemetry SDK and exports them over OTLP/HTTP to a
collector, the same `otlpEndpoint` the metrics are pushed to. It is the only
module that imports `package:opentelemetry`.

**Tracing is off by default, and off costs nothing**: with no tracer installed
no span object is made. The trace context — `traceparent` in and out, the
`trace_id` and `span_id` of every log line — is carried either way. With
`tracing` on, `TomServer.start` installs the tracer (`configureTracing`) and the
ids in log lines and `traceparent` headers become the exported spans' ids. A
span continuing a caller is sampled as the caller's `traceparent` says; a new
trace is sampled at `tracingSamplePercent`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomOtelTracer` | The kernel's `TomTracer` over the OpenTelemetry SDK. `TomOtelTracer.otlp` exports protobuf to `<endpoint>/v1/traces`, batched every 5 s; `fromConfiguration` builds it from `tracing`, `otlpEndpoint`, `otlpHeaders` and `tracingSamplePercent`; `flush`, `shutdown` and `close` wait for the exports in flight. Parent-based sampling, new traces decided from the trace id. |
| `TomTracingException` | `tracing.config.no_endpoint` and `tracing.config.invalid_sample_percent`. |
| `TomUntracedClient` | The HTTP client the exporter sends through: its calls are never traced, `idle` completes when none is in flight, and `close` lets the ones in flight finish. |
| `TomInMemorySpanExporter` | Keeps exported spans in memory for a test: `spans`, `named`, `childrenOf`, `attributeOf`. |

## Quick start

```dart
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final exported = TomInMemorySpanExporter();
  TomTracing.install(
    TomOtelTracer(processors: [otel_sdk.SimpleSpanProcessor(exported)]),
  );

  await TomTracing.trace('import', (span) async {
    span?.setAttribute('tom.import.rows', 3);
    await TomTracing.trace('parse', (_) async {});
  });

  final parent = exported.named('import').single;
  print(exported.childrenOf(parent).single.name); // parse
  print(TomInMemorySpanExporter.attributeOf(parent, 'tom.import.rows')); // 3
  TomTracing.install(null);
}
```

In a server nothing is wired by hand: set `tracing: true` (`TRACING=true`) and
`otlpEndpoint`, and `TomServer.start` installs the tracer as `TomServer.tracer`
and registers it for a final export at shutdown.

See [`doc/tracing.md`](../../../../doc/tracing.md) for the configuration, every
span the framework records with its name and attributes, the sampling rule,
how a trace is carried across calls and through the outbox, the rule that keeps
bound SQL values out of spans, and what is not traced, and
`example/tracing/tracing_example.dart` for a request traced end to end — its
transaction and outgoing call as children, the callee continuing the call, and
the tree exported over OTLP — checking its own results.
`test/tracing_test.dart` covers the module without a database,
`test/tracing_db_test.dart` (tagged `db`) the span tree of a request that
queries MariaDB or PostgreSQL, and `test/tracing_otel_test.dart` (tagged
`otel`, run by `tool/run_otel_tests.sh`) the export read by an OpenTelemetry
Collector. `test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
