# context

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Zone-scoped ambient context. Lets a request, tenant, or user identity flow down
a call tree without threading it through every function signature, by storing
lazily-evaluated entries in the current Dart `Zone`.

The **tenant** — the isolation boundary whose data, caches and jobs these are —
has a slot of its own, `TomTenantContext`, set once at the edge (a request, a
job run). It is not the **organization**, a business unit inside a tenant; the
framework never infers one from the other. The `'tenant'` entry in the quick
start below is an ordinary named value.

The **trace** the work belongs to has a slot too, `TomTraceContext`, in the W3C
Trace Context form: a server request continues the caller's `traceparent` (or
starts a trace) and runs inside it, the structured log output writes its
ids into every line as `trace_id` and `span_id`, and an outgoing call through
`TomResilientClient` carries a child span of it.

The **request id** of the unit of work — a request, a job run, a socket message —
sits beside the trace, `TomRequestId`: every log line carries it as
`request_id`, and a server exception and an audit entry name it. Work no caller
started (a job run) takes the trace id of a new trace (`runRoot`); one step of a
longer conversation (a socket message) takes `<trace id>-<span id>` of a new
span (`runChild`).

The **spans** of a trace — the timed, named steps a tracing backend shows — are
recorded through `TomTracing` (`tracing.dart`). The framework opens a span
around a request, an SQL statement, a transaction, an outgoing HTTP call, a job
run and an outbox delivery; an installed `TomTracer` decides what becomes of
it. No tracer is installed by default, and then no span is made at all: the
instrumented code asks whether a tracer is installed and runs exactly as it
would without tracing. A span's `context` is the `TomTraceContext` its work runs
in, so log lines and outgoing `traceparent` headers name the span they were
written in. `tom_core_server` provides the OpenTelemetry tracer;
`TomRecordingTracer` keeps spans in memory for tests.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomExecutionContext` | Holds a map of named context entries and runs a body inside a zone that exposes them; supports parent-context inheritance. |
| `TomContextEntry<T>` | A single named entry wrapping a lazy value provider. |
| `TomContextProviders` | Built-in providers for common context values. |
| `TomZoneValues` | Backing store keyed into the zone alongside the context. |
| `TomTenantContext` | The current tenant in the zone: `currentId`, `run`, `require`, `validate`, `qualify`. |
| `TomTenantException` | `tenancy.id.invalid` / `tenancy.context.missing`. |
| `TomTenantScopedCommand` | Runs a `TomCommand` inside a tenant wherever it executes, a worker isolate included. |
| `TomTenantEvent` | An event-triggered job's event, naming the tenant the run belongs to. |
| `TomTraceContext` | The W3C trace and span in the zone: `parse` a `traceparent` (`null` when invalid) and its `tracestate` (`validTraceState`), `newRoot`, `child`, `traceparent`, `headers`, `current`, `run`. |
| `TomRequestId` | The id of the current unit of work in the zone: `TomRequestId()` (a v4 UUID), `of`, `tryOf`, `isValid`, `value`, `current`, `run`, `runRoot` (optionally the first span of its trace: `spanName`, `spanKind`, `spanAttributes`), `runChild`. |
| `TomSpanKind` | The OpenTelemetry span kinds: `internal`, `server`, `client`, `producer`, `consumer`. |
| `TomSpan` | One span being recorded: `context`, `name`, `setName`, `setAttribute`, `recordError`, `setError`, `end`. |
| `TomTracer` | Makes spans (`startSpan`), `flush`, `shutdown`. Installed with `TomTracing.install`. |
| `TomTracing` | The installed tracer and the ways to open spans with it: `install`, `tracer`, `isRecording`, `currentSpan`, `start` (`childOnly` starts nothing outside a trace), `within`, `ending`, `trace`, `untraced`. |
| `TomRecordingTracer` | A tracer keeping ended spans in memory (`spans`, `open`, `named`, `childrenOf`, `clear`) — for tests. |
| `TomRecordedSpan` | A span `TomRecordingTracer` recorded: `kind`, `attributes`, `errors`, `errorDescription`, `started`, `ended`. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final ctx = TomExecutionContext({
    // Always write the type parameter: the constructor takes a
    // Map<String, TomContextEntry>, so a raw TomContextEntry(() => 'acme')
    // here infers TomContextEntry<dynamic> and the typed read below would
    // silently return null.
    'tenant': TomContextEntry<String>(() => 'acme'),
  });

  ctx.runInContext(() {
    final tenant =
        TomExecutionContext.getValueFromCurrentZone<String>('tenant');
    print(tenant); // acme
  });
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
