# Tom Core Kernel API Reference: Metrics Module

Counters, gauges and histograms recorded in process, gauges computed when they
are read, and one sorted snapshot of all of them that both the Prometheus text
rendering and an OTLP exporter read.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomMetricsException](#tommetricsexception)
  - [TomMetric](#tommetric)
  - [TomCounter](#tomcounter)
  - [TomGauge](#tomgauge)
  - [TomHistogram](#tomhistogram)
  - [TomHistogramData](#tomhistogramdata)
  - [TomMetricPoint](#tommetricpoint)
  - [TomMetricFamily](#tommetricfamily)
  - [TomObservedValue](#tomobservedvalue)
  - [TomMetricObservation](#tommetricobservation)
  - [TomMetricRegistry](#tommetricregistry)
  - [TomMetrics](#tommetrics)
- [Enums](#enums)
  - [TomMetricKind](#tommetrickind)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tombase/metrics/metrics.dart`,
`lib/src/tombase/metrics/prometheus_text.dart`.

A `TomMetricRegistry` holds the instruments of one isolate. An instrument is
created on first request and handed back for the same name afterwards, so a
module asks for its instrument where it records and two modules naming one
series share it. Three kinds record as they go — `TomCounter`, `TomGauge`,
`TomHistogram` — and a fourth, the **observed gauge** registered with
`observe`, is computed by a callback each time a snapshot is taken, for a value
cheaper to read than to keep current (a pool's idle connections, a queue's
backlog).

A **series** is an instrument plus one set of label values. Labels must name a
bounded dimension — a route pattern, a job name, a data source — because every
distinct label set is held for the life of the process.

`collect()` answers the snapshot: one `TomMetricFamily` per instrument or
observed name, sorted by name, each holding its `TomMetricPoint`s sorted by
label set, so two snapshots of the same state render identically.
`tomPrometheusText` renders a snapshot in the Prometheus text exposition format
(the server's `/metrics` endpoint serves it with `tomPrometheusContentType`);
`tom_core_server`'s `TomOtlpMetricsExporter` reads the same snapshot, using
`startTime` as the start of its cumulative values.

`TomMetrics.registry` is the registry the framework records into — the
scheduler its job runs, the server its requests, statements, pools, caches and
rate-limit refusals. Misuse — an invalid name, a name requested as two kinds, a
histogram requested again with other buckets, a negative counter increment —
throws `TomMetricsException` with a `metrics.*` key. See
[`doc/metrics/metrics.md`](../metrics/metrics.md) for the narrative guide.

## Class Hierarchy

```
TomException  (kernel)
    └── TomMetricsException

TomMetric  (sealed)
    ├── TomCounter
    ├── TomGauge
    └── TomHistogram

TomHistogramData  (one histogram series' state)
TomMetricPoint  (one series in a snapshot)
TomMetricFamily  (one instrument in a snapshot)
TomObservedValue  (one value an observation callback reports)
TomMetricObservation  (a registered callback)
TomMetricRegistry  (the instruments of one isolate)
TomMetrics  (abstract final — holds TomMetrics.registry)
```

## Classes

### TomMetricsException

A misuse of the metrics API. Thrown synchronously by the call that misused it;
`parameters` always carries the `metric` name.

- **Extends:** `TomException`

```dart
TomMetricsException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, StackTrace? stack, Object? rootException, bool autoLog = false, String? uuid, TomServerCallError? serverCallError})
```

| Key | Thrown by | When | Other parameters |
| --- | --------- | ---- | ---------------- |
| `metrics.name.invalid` | `counter`, `gauge`, `histogram`, `observe` | The name does not match `[a-zA-Z_:][a-zA-Z0-9_:]*`, or a counter's name ends in `_total` (the rendering appends it). | — |
| `metrics.name.conflict` | `counter`, `gauge`, `histogram`, `observe` | The name is already registered as another kind or as an observed gauge, or a histogram is requested again with other buckets. | `kind` (when another kind holds the name) |
| `metrics.label.invalid` | `add`, `set`, `record` | A label name does not match `[a-zA-Z_][a-zA-Z0-9_]*` or starts with `__` (reserved by Prometheus). | `label` |
| `metrics.counter.negative` | `TomCounter.add` | A negative increment. | `value` |

### TomMetric

One instrument of a `TomMetricRegistry`. Sealed: the three subclasses are the
only instruments, and a registry is the only place they are created (their
constructors are private).

- **Kind:** sealed class.
- **Subclasses:** `TomCounter`, `TomGauge`, `TomHistogram`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `final String` | The series name, without the `_total` a counter is read with. |
| `help` | `final String` | What the series measures, one line — the `# HELP` text and the OTLP description. |
| `unit` | `final String` | The unit, as UCUM (`s`, `By`, `1`), or empty. The name carries it too (`_seconds`, `_bytes`), because that is what a Prometheus reader sees. |
| `kind` | `TomMetricKind` *(getter)* | What kind of instrument this is. |

### TomCounter

A total that only grows: requests served, statements failed, runs ended. Read
as `<name>_total`.

- **Extends:** `TomMetric`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `kind` | `TomMetricKind` *(getter, override)* | `TomMetricKind.counter`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `add` | `void add([num value = 1, Map<String, String> labels = const {}])` | Adds `value` to the series `labels` names. Throws `metrics.counter.negative` for a negative value: a counter that went down reads as a process restart to every rate computed from it. |
| `valueOf` | `double valueOf([Map<String, String> labels = const {}])` | The current total of the series; zero when never added to. Label order does not matter. |

### TomGauge

A value set whenever it changes: connections open, the timestamp of the last
success.

- **Extends:** `TomMetric`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `kind` | `TomMetricKind` *(getter, override)* | `TomMetricKind.gauge`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `set` | `void set(num value, [Map<String, String> labels = const {}])` | Sets the series `labels` names to `value`. |
| `valueOf` | `double? valueOf([Map<String, String> labels = const {}])` | The current value of the series, or `null` if never set. |

### TomHistogram

Observations sorted into fixed buckets: request latencies, job start lag. Read
as cumulative `_bucket` series with an `le` label, plus `_sum` and `_count`.

- **Extends:** `TomMetric`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `buckets` | `final List<double>` | The upper bounds of the buckets, ascending and unmodifiable; an observation above the last falls into the implicit `+Inf` bucket. An observation equal to a bound falls into that bound's bucket. |
| `kind` | `TomMetricKind` *(getter, override)* | `TomMetricKind.histogram`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `record` | `void record(num value, [Map<String, String> labels = const {}])` | Records `value` in the series `labels` names. |
| `recordDuration` | `void recordDuration(Duration duration, [Map<String, String> labels = const {}])` | Records `duration` in seconds, at microsecond resolution. |
| `time` | `Future<T> time<T>(Future<T> Function() body, [Map<String, String> labels = const {}])` | Runs `body` and records how long it took, whether it returned or threw; the result or the error is handed on. |
| `valueOf` | `TomHistogramData? valueOf([Map<String, String> labels = const {}])` | A copy of the series' data, or `null` if nothing was recorded. |

### TomHistogramData

The state of one histogram series: a count per bucket, the number of
observations and their sum. What `valueOf` and a snapshot hand out is a copy,
so it does not change under the reader.

- **Kind:** class (no public constructor).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `bounds` | `final List<double>` | The bucket upper bounds, ascending. |
| `counts` | `List<int>` *(getter)* | Observations per bucket — **not** cumulative — one more than `bounds`, the last being the `+Inf` bucket. Unmodifiable. |
| `count` | `int` *(getter)* | How many observations were recorded. |
| `sum` | `double` *(getter)* | The sum of every observation. |

### TomMetricPoint

One series of a `TomMetricFamily` at the moment of the snapshot.

#### Constructors

```dart
const TomMetricPoint(Map<String, String> labels, {double value = 0, TomHistogramData? histogram})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `labels` | `final Map<String, String>` | The series' labels. |
| `value` | `final double` | The value of a counter or gauge series. |
| `histogram` | `final TomHistogramData?` | The data of a histogram series, `null` for any other kind. |

### TomMetricFamily

One instrument's series at the moment of the snapshot — an element of what
`TomMetricRegistry.collect` answers and what `tomPrometheusText` renders.

#### Constructors

```dart
const TomMetricFamily({required String name, required String help, required String unit, required TomMetricKind kind, required List<TomMetricPoint> points})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `final String` | The series name, without the `_total` a counter is read with. |
| `help` | `final String` | What the series measures. |
| `unit` | `final String` | The UCUM unit, or empty. |
| `kind` | `final TomMetricKind` | The instrument kind; an observed gauge is `gauge`. |
| `points` | `final List<TomMetricPoint>` | Every series, sorted by label set. |

### TomObservedValue

One value an observation callback reports: `value` for the series `labels`
names.

#### Constructors

```dart
const TomObservedValue(num value, [Map<String, String> labels = const {}])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `value` | `final num` | The value. |
| `labels` | `final Map<String, String>` | The series' labels. |

### TomMetricObservation

A registered observation — what `TomMetricRegistry.observe` returns.

- **Kind:** class (no public constructor).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `final String` | The gauge the callback reports. |
| `help` | `final String` | What the gauge measures. |
| `unit` | `final String` | The UCUM unit, or empty. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `cancel` | `void cancel()` | Stops reporting; the gauge's series disappear from the next snapshot. Calling it again does nothing. |

### TomMetricRegistry

The instruments of one isolate, and the snapshot of them.

Instruments are created on first request and returned again for the same name
afterwards. A name requested as two kinds, or as a histogram with other
buckets, is refused with `metrics.name.conflict`.

#### Constructors

```dart
TomMetricRegistry({DateTime Function()? clock})
```

An empty registry. `clock` (default `DateTime.now`) stamps `startTime`;
it is injectable for tests.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `observationTimeout` | `Duration` | How long a snapshot waits for one observation callback before counting it as failed. Default five seconds. |
| `startTime` | `DateTime` *(getter)* | When the totals began accumulating — the registry's creation or its last `reset`. An OTLP export reports cumulative values from this instant. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `counter` | `TomCounter counter(String name, {required String help, String unit = ''})` | The counter named `name`, created with `help` and `unit` on first use. A name ending in `_total` is refused (`metrics.name.invalid`). |
| `gauge` | `TomGauge gauge(String name, {required String help, String unit = ''})` | The gauge named `name`, created on first use. |
| `histogram` | `TomHistogram histogram(String name, {required String help, String unit = '', List<double> buckets = tomLatencyBuckets})` | The histogram named `name` with `buckets`, created on first use; requested again with other buckets, refused. |
| `observe` | `TomMetricObservation observe(String name, {required String help, String unit = '', required TomMetricObserver observer})` | Registers `observer` to report the gauge `name` at every snapshot. Several observations may report one name: their series are merged and the first to report a label set wins. A name an instrument already holds is refused. |
| `collect` | `Future<List<TomMetricFamily>> collect()` | Every instrument and observation, read now; families sorted by name, points by label set. An observer that throws or exceeds `observationTimeout` contributes nothing, is logged at warn level and is counted in `tom_metrics_observation_failures{metric}` — a counter that appears in the same snapshot. |
| `reset` | `void reset()` | Clears every value and restarts `startTime`; instruments and observations stay registered. For tests, which share the process registry. |

### TomMetrics

Holds the registry the framework records into.

- **Kind:** abstract final class (static members only).

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `registry` | `static final TomMetricRegistry` | The registry of this isolate. A worker isolate has its own, which nothing exports; work done there is measured where its result comes back. |

## Enums

### TomMetricKind

What an instrument measures, and so how its points are read.

| Value | Description |
| ----- | ----------- |
| `counter` | A monotonically increasing total. |
| `gauge` | A value that goes up and down. |
| `histogram` | A distribution of observations in fixed buckets. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomLatencyBuckets` | `const List<double> tomLatencyBuckets` | `0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10` — bucket bounds in seconds for latencies of milliseconds to seconds: an HTTP request, an SQL statement, a pool acquire. The default of `histogram`. |
| `tomLagBuckets` | `const List<double> tomLagBuckets` | `0.1, 0.5, 1, 5, 15, 30, 60, 300, 900, 3600` — bucket bounds in seconds for delays of seconds to an hour: how late a job started, how long it ran. |
| `TomMetricObserver` | `typedef TomMetricObserver = FutureOr<Iterable<TomObservedValue>> Function()` | Computes an observed gauge's values when a snapshot is taken; may be synchronous or asynchronous. |
| `tomPrometheusContentType` | `const String tomPrometheusContentType` | `text/plain; version=0.0.4; charset=utf-8` — the `Content-Type` a scrape of `tomPrometheusText` is served with. |
| `tomPrometheusText` | `String tomPrometheusText(Iterable<TomMetricFamily> families)` | `families` in the Prometheus text exposition format 0.0.4: `# HELP` and `# TYPE` per family, a counter as `<name>_total`, a histogram as cumulative `_bucket{le="…"}` lines ending in `+Inf`, then `_sum` and `_count`. Labels are sorted by name (`le` last) and escaped; whole numbers render without a decimal point. A pure function — no HTTP. |
