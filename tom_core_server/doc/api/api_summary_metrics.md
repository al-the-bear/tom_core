# Tom Core Server API Reference: Metrics Module

How the server's metrics leave the process: the request series every request
records, the Prometheus scrape endpoint answered ahead of authentication, and
the OTLP/HTTP transport and the metrics exporter built on it. The instruments
and the registry they are recorded into are `tom_core_kernel`'s `metrics`
module — see the kernel's
[api_summary_metrics.md](../../../tom_core_kernel/doc/api/api_summary_metrics.md).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomOtlpExportException](#tomotlpexportexception)
  - [TomOtlpHttpTransport](#tomotlphttptransport)
  - [TomOtlpMetricsExporter](#tomotlpmetricsexporter)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/metrics/metrics_middleware.dart`,
`lib/src/tomserver/metrics/otlp_exporter.dart`.

Every module records into the kernel's process registry, `TomMetrics.registry`.
`tomRequestMetricsMiddleware` records the request series — labelled by the
endpoint's route pattern, which the endpoint pipeline writes into
`TomRequestLogInfo.route`, or `tomUnmatchedRoute` — and
`tomMetricsEndpointMiddleware` answers a scrape of the registry in the
Prometheus text format, with an optional bearer token. `TomServer.start`
installs both at the outer edge of its pipeline, the scrape only when
`metricsEndpoint` is on.

`TomOtlpHttpTransport` posts OTLP/HTTP JSON bodies to `<endpoint>/v1/<signal>`
and knows no signal; `TomOtlpMetricsExporter` is its first user, pushing
`tomOtlpMetricsJson` of the registry to `v1/metrics` every interval and once more
on `close`. The tracing module's span exporter posts to `urlOf('traces')` with
the same headers.
`TomServer.start` creates the exporter as `TomServer.metricsExporter` when
`otlpEndpoint` names a receiver. `TomOtlpExportException` is every failure the
module raises.

## Class Hierarchy

```text
TomServerException  (little_things)
    └── TomOtlpExportException

TomClosable  (tom_core_kernel)
    └── TomOtlpMetricsExporter  (implements)

TomOtlpHttpTransport  (standalone)
```

## Classes

### TomOtlpExportException

An OTLP export that did not reach the receiver or was refused by it, and
headers that cannot be read. Always the server's own failure
(`clientThrow: false`).

| Key | Meaning |
| --- | ------- |
| `otlp.export.failed` | The receiver could not be reached, did not answer within the transport's `timeout`, or answered other than `2xx`. Parameters `signal`, `url`, and `status` when it answered. |
| `otlp.config.invalid_headers` | A headers entry with no `=`. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomOtlpExportException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

### TomOtlpHttpTransport

Posts OTLP/HTTP JSON bodies to a receiver — the OpenTelemetry Collector, Grafana
Alloy, a vendor's agent. Signal-neutral: the metrics exporter posts `metrics`,
the tracing module's span exporter `traces`, through one endpoint and one set
of headers.

- **Extends:** none

#### Constructors

```dart
TomOtlpHttpTransport({
  required Uri endpoint,
  Map<String, String> headers = const {},
  Duration timeout = const Duration(seconds: 10),
  http.Client? client,
})
```

`client` defaults to a `TomResilientClient` (the kernel's) over a new
`http.Client`, so a push runs under the receiver's timeout and circuit breaker;
a test passes its own.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `endpoint` | `Uri` | The receiver's base URL, such as `http://collector:4318`, to which `/v1/<signal>` is appended (final). |
| `headers` | `Map<String, String>` | Sent with every export — typically an `authorization` or a vendor key (final). |
| `timeout` | `Duration` | How long an export may take before it is abandoned (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parseHeaders` | `static Map<String, String> parseHeaders(String text)` | The headers `text` names in the `key=value,key=value` form of `OTEL_EXPORTER_OTLP_HEADERS`: keys trimmed and lower-cased, values percent-decoded, empty entries skipped. Throws `otlp.config.invalid_headers` for an entry with no `=`. |
| `urlOf` | `Uri urlOf(String signal)` | The URL `signal` (`metrics`, `traces`, `logs`) is posted to: the endpoint's path with `v1/<signal>` appended. |
| `export` | `Future<void> export(String signal, Map<String, Object?> body)` | Posts `body`, JSON-encoded with `content-type: application/json` and `headers`, to `urlOf(signal)`, untraced (`TomTracing.untraced`), so a push records no span of its own. Throws `otlp.export.failed` when the receiver cannot be reached, does not answer within `timeout`, or answers anything but a `2xx`. |
| `close` | `void close()` | Closes the HTTP client. |

### TomOtlpMetricsExporter

Pushes a `TomMetricRegistry`'s snapshot to an OTLP receiver every `interval`,
**cumulatively** — each push carries every series' total since the registry's
start time, so a lost push loses nothing. A failed periodic push is logged as a
warning and the next carries the same totals; `close` stops the pushes after one
final push, so a shutdown does not lose what was counted since the last one.

- **Implements:** `TomClosable`

#### Constructors

```dart
TomOtlpMetricsExporter({
  required TomOtlpHttpTransport transport,
  TomMetricRegistry? registry,
  Map<String, String> resource = const {},
  Duration interval = const Duration(seconds: 60),
  DateTime Function()? clock,
})
```

`registry` defaults to `TomMetrics.registry`; `clock`, the time each point is
stamped with, to `DateTime.now`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `transport` | `TomOtlpHttpTransport` | Where the snapshots go (final). |
| `registry` | `TomMetricRegistry` | What is exported (final). |
| `resource` | `Map<String, String>` | The resource attributes describing this process — `service.name` at least (final). |
| `interval` | `Duration` | How often `start` pushes (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `export` | `Future<void> export()` | Takes a snapshot and pushes it once to `v1/metrics`; throws as `TomOtlpHttpTransport.export` does. |
| `start` | `void start()` | Pushes every `interval` until `close`. A second call, or a call after `close`, does nothing. |
| `close` | `Future<void> close()` | *(override)* Stops the timer, pushes once more (a failure is logged, not thrown) and closes the transport. Idempotent. |

## Enums

None — this module declares no enums.

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomUnmatchedRoute` | `const String` | `'unmatched'` — the `route` label of a request no endpoint matched, so a scan of random paths adds one series rather than one per path. |
| `tomRequestMetricsMiddleware` | `Middleware tomRequestMetricsMiddleware()` | Records `tom_http_server_requests` {`method`, `route`, `status`} and `tom_http_server_request_duration_seconds` {`method`, `route`} for every request, with `route` read from the request's `TomRequestLogInfo.route` (`tomUnmatchedRoute` when no endpoint set one). An error that escapes every inner layer is counted as a `500` and rethrown. |
| `tomMetricsEndpointMiddleware` | `Middleware tomMetricsEndpointMiddleware({String path = '/metrics', String token = '', TomMetricRegistry? registry})` | Answers `GET` `path` with `registry`'s snapshot (`TomMetrics.registry` unless given) as `tomPrometheusText`, content type `tomPrometheusContentType`, and `HEAD` with no body; passes every other request on. With a non-empty `token` a scrape must present `Authorization: Bearer <token>`, compared in time that depends on the token's length only, and is otherwise answered `401` with `WWW-Authenticate: Bearer` and no body. |
| `tomOtlpMetricsJson` | `Map<String, Object?> tomOtlpMetricsJson(List<TomMetricFamily> families, {required Map<String, String> resource, required DateTime startTime, required DateTime time})` | `families` as an OTLP `ExportMetricsServiceRequest` in the JSON encoding, under the scope `tom_core`: counters as cumulative monotonic sums, gauges as gauges, histograms as cumulative explicit-bucket histograms; every point stamped `time`, sums and histograms also `startTime`. 64-bit integers are strings, as the protobuf JSON mapping writes them. |

`tomUnmatchedRoute`, `tomRequestMetricsMiddleware` and
`tomMetricsEndpointMiddleware` live in `metrics_middleware.dart`;
`tomOtlpMetricsJson` in `otlp_exporter.dart`, beside the exporter.
