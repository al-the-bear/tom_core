# Tom Core Server API Reference: Tracing Module

The OpenTelemetry tracer behind the kernel's tracing seam: the spans the
framework opens through `TomTracing` turned into OpenTelemetry SDK spans,
sampled parent-first, and exported over OTLP/HTTP to a collector. The seam
itself — `TomTracing`, `TomTracer`, `TomSpan`, `TomSpanKind` and the
in-memory `TomRecordingTracer` — is `tom_core_kernel`'s `context` module; see
the kernel's
[api_summary_context.md](../../../tom_core_kernel/doc/api/api_summary_context.md).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTracingException](#tomtracingexception)
  - [TomOtelTracer](#tomoteltracer)
  - [TomUntracedClient](#tomuntracedclient)
  - [TomInMemorySpanExporter](#tominmemoryspanexporter)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/tracing/otel_tracer.dart`.

`TomOtelTracer` is the one place in the package that imports the
OpenTelemetry SDK (`package:opentelemetry`). Each span the framework starts
becomes an SDK span; its ids become the framework's `TomTraceContext`, so the
`trace_id` and `span_id` of log lines and the `traceparent` of outgoing calls
are the exported ones. Ended spans go to the SDK's span processors — a batch
processor over the OTLP/HTTP protobuf exporter in a deployment
(`TomOtelTracer.otlp`), a simple processor over a `TomInMemorySpanExporter` in a
test.

`TomServer.start` installs one through `TomServer.configureTracing` when the
configuration's `tracing` is on (`TomOtelTracer.fromConfiguration`): spans go
to `<otlpEndpoint>/v1/traces` with `otlpHeaders`, new traces are sampled at
`tracingSamplePercent`. A span continuing a parent is sampled as its parent is;
an unsampled span is still made and propagated, flagged unsampled, but not
exported.

`TomUntracedClient` is the HTTP client the exporter sends through: its calls
run `TomTracing.untraced`, so an export produces no spans of its own, and its
`close` lets the calls in flight finish, so the last batch of a shutting-down
server is delivered. `TomTracingException` is every failure the module raises.

## Class Hierarchy

```text
TomServerException  (little_things)
    └── TomTracingException

TomTracer  (tom_core_kernel)
    └── TomOtelTracer  (implements; also implements TomClosable)

BaseClient  (package:http)
    └── TomUntracedClient

SpanExporter  (package:opentelemetry)
    └── TomInMemorySpanExporter  (implements)
```

## Classes

### TomTracingException

Tracing cannot be set up as configured. Always the server's own failure
(`clientThrow: false`).

| Key | Meaning |
| --- | ------- |
| `tracing.config.no_endpoint` | `tracing` is on and `otlpEndpoint` is empty: there is nowhere to export the spans to. |
| `tracing.config.invalid_sample_percent` | A sample percentage outside 0 to 100. Parameter `samplePercent`. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomTracingException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

### TomOtelTracer

A `TomTracer` recording spans with the OpenTelemetry SDK and handing them to
its processors. A span continuing a parent — of this process, or the remote
position a caller sent in its `traceparent` — is sampled as its parent is. A
new trace is sampled with the probability `samplePercent`, decided from the
random low bytes of its trace id, so every process deciding for one trace
decides alike. An unsampled span is made and propagated, but not exported.

- **Implements:** `TomTracer`, `TomClosable`

#### Constructors

```dart
TomOtelTracer({
  required List<otel_sdk.SpanProcessor> processors,
  Map<String, Object> resource = const {'service.name': 'tom_server'},
  int samplePercent = 100,
  TomUntracedClient? exportClient,
})
factory TomOtelTracer.otlp({
  required Uri endpoint,
  Map<String, String> headers = const {},
  Map<String, Object> resource = const {'service.name': 'tom_server'},
  int samplePercent = 100,
  Duration exportInterval = const Duration(seconds: 5),
  http.Client? client,
})
```

The generative constructor hands spans to `processors` (the SDK's
`SpanProcessor`s), describes the process with the `resource` attributes —
`service.name` at least — and throws `tracing.config.invalid_sample_percent`
for a `samplePercent` outside 0 to 100. `exportClient` is the client the
processors' exporter sends through, when the caller built one: `flush` and
`shutdown` wait for its exports to finish.

`TomOtelTracer.otlp` exports to the OTLP/HTTP receiver at `endpoint` — its base
URL, to which `/v1/traces` is appended — in protobuf, with `headers` on every
export. Spans are batched by the SDK's `BatchSpanProcessor` and sent every
`exportInterval`, or when a batch is full. The exporter sends through a
`TomUntracedClient` over `client`, by default the kernel's
`TomResilientClient`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `samplePercent` | `int` | The probability, in percent, that a new trace is sampled (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromConfiguration` | `static TomOtelTracer? fromConfiguration(TomBaseServerConfiguration configuration, {required String serviceName})` | The tracer `configuration` asks for, or `null` when its `tracing` is off: `TomOtelTracer.otlp` to `otlpEndpoint`, with `otlpHeaders` read by `TomOtlpHttpTransport.parseHeaders`, sampled at `tracingSamplePercent`, with `serviceName` as `service.name`. Throws `tracing.config.no_endpoint` when tracing is on and no endpoint is configured, `tracing.config.invalid_sample_percent` for a percentage outside 0 to 100, and `otlp.config.invalid_headers` for headers that cannot be read. |
| `startSpan` | `TomSpan startSpan(String name, {TomSpanKind kind = TomSpanKind.internal, TomTraceContext? parent, Map<String, Object> attributes = const {}})` | *(override)* Starts an SDK span continuing `parent` (its trace, span, `sampled` flag and `tracestate`), or a new trace when `parent` is `null`, and answers it as a `TomSpan` whose `context` carries the SDK's ids. Attribute values keep their types — strings, booleans, integers, doubles and lists of one of those; anything else is recorded as its `toString()`. A `tracestate` the SDK cannot read is still carried on in the framework's context. |
| `flush` | `Future<void> flush()` | *(override)* Exports what the processors hold, and completes when the export has been answered. |
| `shutdown` | `Future<void> shutdown()` | *(override)* Exports what the processors hold and stops them, completing when the last export has been answered. Spans started afterwards are not exported. |
| `close` | `Future<void> close()` | *(override)* `shutdown` — the shutdown cleanup's final export. |

### TomUntracedClient

A `package:http` client whose calls are never traced — what a telemetry
exporter sends through, so an export does not produce spans to export. A call
counts as in flight until its response body has been read.

- **Extends:** `http.BaseClient` (`package:http`)

#### Constructors

```dart
TomUntracedClient(this._inner)
```

Sends through `_inner`, an `http.Client`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `idle` | `Future<void>` | *(getter)* Completes when no call is in flight — at once when none is. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<http.StreamedResponse> send(http.BaseRequest request)` | *(override)* Sends `request` through the inner client inside `TomTracing.untraced`. |
| `close` | `void close()` | *(override)* Closes the inner client once the calls in flight have finished. The SDK's exporter starts its last export and closes its client in the same breath; closing at once would drop that export — the spans of a server's last seconds. |

### TomInMemorySpanExporter

A span exporter keeping every exported span in memory — for tests, under the
SDK's `SimpleSpanProcessor`.

- **Implements:** `otel_sdk.SpanExporter` (`package:opentelemetry`)

#### Constructors

```dart
TomInMemorySpanExporter()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `spans` | `List<otel_sdk.ReadOnlySpan>` | The exported spans, in the order they ended (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `export` | `void export(List<otel_sdk.ReadOnlySpan> spans)` | *(override)* Adds `spans` to `spans`. |
| `named` | `List<otel_sdk.ReadOnlySpan> named(String name)` | The exported spans named `name`. |
| `childrenOf` | `List<otel_sdk.ReadOnlySpan> childrenOf(otel_sdk.ReadOnlySpan span)` | The exported spans whose parent is `span`. |
| `attributeOf` | `static Object? attributeOf(otel_sdk.ReadOnlySpan span, String key)` | The value of attribute `key` of `span`, or `null`. |
| `forceFlush` | `void forceFlush()` | *(override, deprecated)* Does nothing; flushing is the processor's. |
| `shutdown` | `void shutdown()` | *(override)* Does nothing. |

## Enums

None — this module declares no enums.

## Global Functions and Constants

None — this module declares no top-level functions or constants.
