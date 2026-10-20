# Metrics Module

The Metrics module records numbers about a running process — how many requests,
how long they took, how far behind a job queue is — and hands them out as one
snapshot. It answers what logs and alerts cannot: *how is the system doing
right now, and how has that changed*, as series a monitoring system can graph,
aggregate across nodes and alert on.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [Runnable examples](#runnable-examples)
- [Design](#design)
  - [One snapshot, two exports](#one-snapshot-two-exports)
  - [A registry per isolate](#a-registry-per-isolate)
  - [Labels must be bounded](#labels-must-be-bounded)
- [Instruments](#instruments)
  - [Counters](#counters)
  - [Gauges](#gauges)
  - [Histograms](#histograms)
  - [Observed gauges](#observed-gauges)
  - [Names, units and conflicts](#names-units-and-conflicts)
- [The Snapshot](#the-snapshot)
  - [When an observer fails](#when-an-observer-fails)
- [Prometheus Text](#prometheus-text)
- [Series the Framework Records](#series-the-framework-records)
- [Testing Code That Records](#testing-code-that-records)
- [Error Keys](#error-keys)
- [Best Practices](#best-practices)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomMetricRegistry` | class | The instruments of one isolate; creates each on first request and answers the snapshot (`collect`). |
| `TomMetrics` | abstract final class | Holds `TomMetrics.registry`, the registry the framework records into. |
| `TomMetric` | sealed class | The base of the three recording instruments: `name`, `help`, `unit`, `kind`. |
| `TomCounter` | class | A total that only grows. |
| `TomGauge` | class | A value set whenever it changes. |
| `TomHistogram` | class | Observations sorted into fixed buckets. |
| `TomHistogramData` | class | One histogram series: per-bucket counts, the observation count, the sum. |
| `TomMetricObserver` | typedef | The callback an observed gauge is computed by at snapshot time. |
| `TomObservedValue` | class | One value an observer reports, with its labels. |
| `TomMetricObservation` | class | A registered observer; `cancel` removes it. |
| `TomMetricFamily` | class | One instrument in a snapshot. |
| `TomMetricPoint` | class | One series in a snapshot. |
| `TomMetricKind` | enum | `counter`, `gauge`, `histogram`. |
| `TomMetricsException` | class | A misuse of the API, raised with a `metrics.*` key. |
| `tomLatencyBuckets` / `tomLagBuckets` | const | Bucket bounds in seconds for latencies and for delays. |
| `tomPrometheusText` | function | A snapshot in the Prometheus text exposition format 0.0.4. |
| `tomPrometheusContentType` | const | The `Content-Type` that text is served with. |

A **series** is an instrument plus one set of label values:
`http_requests_total{route="/orders", status="200"}` and
`http_requests_total{route="/orders", status="500"}` are two series of one
counter. Everything the module stores is per series.

## Quick Start

Ask the registry for an instrument where you record, and record:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

final _exports = TomMetrics.registry.counter(
  'report_exports',
  help: 'Reports exported, by format.',
);

final _render = TomMetrics.registry.histogram(
  'report_render_seconds',
  help: 'How long rendering a report took.',
  unit: 's',
);

Future<List<int>> exportReport(Report report, String format) async {
  final bytes = await _render.time(() => render(report, format));
  _exports.add(1, {'format': format});
  return bytes;
}
```

Asking twice for the same name returns the same instrument, so two places that
record one series do not need to share a variable. Nothing else is needed to
export: a `tom_core_server` server serves `TomMetrics.registry` on `/metrics`,
and its OTLP exporter pushes the same registry when configured.

### Runnable examples

Everything in this guide is demonstrated, and asserted, in
[`example/samples/metrics/`](../../example/samples/metrics/).

| File | What it shows |
| ---- | ------------- |
| [`01_instruments_example.dart`](../../example/samples/metrics/01_instruments_example.dart) | Counters, gauges and histograms; one name is one instrument, one label set one series; every misuse the registry refuses, by key |
| [`02_snapshot_and_prometheus_example.dart`](../../example/samples/metrics/02_snapshot_and_prometheus_example.dart) | Observed gauges read at snapshot time, the exact Prometheus text of a snapshot, a failing observer counted rather than propagated, `cancel` and `reset` |
| [`03_scheduler_metrics_example.dart`](../../example/samples/metrics/03_scheduler_metrics_example.dart) | The `tom_job_*` series a `TomScheduler` records: the backlog of a run nobody has started, its start lag, outcomes, the last success |

```bash
dart run --enable-asserts example/samples/metrics/00_run_all_examples.dart
```

## Design

### One snapshot, two exports

Metrics leave a Tom process two ways: **pulled** by a Prometheus scrape of the
server's `/metrics` endpoint, and **pushed** over OTLP by `tom_core_server`'s
`TomOtlpMetricsExporter` to an OpenTelemetry collector. Both read
`TomMetricRegistry.collect()`, so a series is defined once — where it is
recorded — and appears identically in both. The kernel holds the registry and
the Prometheus rendering, because neither needs a server: a CLI tool or a
worker can record and render too. Everything that speaks HTTP is in the server
package.

The snapshot is plain data — `TomMetricFamily` and `TomMetricPoint` — not a
view onto live instruments, so an exporter can take its time over it while
recording continues.

### A registry per isolate

A registry is ordinary Dart memory, and isolates share none, so each isolate has
its own `TomMetrics.registry`. The framework records on the isolate that serves
requests and runs the scheduler — the one the exporters read. Work done in a
worker isolate is measured where its result comes back (the job's
`tom_job_run_duration_seconds` covers the round trip to a worker pool), not
inside the worker, whose registry nothing reads.

### Labels must be bounded

Every distinct label set is a series held in memory for the life of the process
and shipped on every scrape. A label therefore names a **bounded** dimension: a
route pattern rather than a URL, a job name, a data source, an outcome from a
fixed list. A user id, a request id or a raw path as a label grows the registry
without limit — the registry does not cap it, because no cap would be right for
every caller. Put such values in a log line or a trace instead.

## Instruments

### Counters

A `TomCounter` only grows. `add(value, labels)` adds `value` (one by default)
to the series `labels` names; a negative `value` throws
`metrics.counter.negative`, because a counter that went down reads as a process
restart to every rate a monitoring system computes from it. Count events, and
let the reader derive rates.

A counter is named without `_total`; the Prometheus rendering appends it, and a
name that already ends in `_total` is refused (`metrics.name.invalid`).

### Gauges

A `TomGauge` holds the last value `set` for each series: connections open, a
queue's depth, the timestamp of the last success. `valueOf` answers `null` for a
series never set — distinct from a gauge set to zero.

### Histograms

A `TomHistogram` sorts observations into fixed buckets, and keeps their count
and sum. That is what lets a reader compute percentiles and averages *across
nodes*, which per-node percentiles cannot be combined into. `record(value)`
takes a number, `recordDuration(duration)` a `Duration` in seconds, and
`time(body)` runs an asynchronous body and records how long it took, whether it
returned or threw.

The buckets are fixed when the histogram is created. Two sets are provided:

| Constant | Bounds (seconds) | For |
| -------- | ---------------- | --- |
| `tomLatencyBuckets` | 0.005 … 10 | Requests, statements, pool acquires — milliseconds to seconds. The default. |
| `tomLagBuckets` | 0.1 … 3600 | Delays measured in seconds to an hour — job start lag and run time. |

An observation equal to a bound falls into that bound's bucket; one above the
last falls into the implicit `+Inf` bucket.

### Observed gauges

Some values are cheaper to read than to keep current: a pool's idle connections,
a cache's size, a queue's backlog that lives in a database. For those,
`observe(name, help:, observer:)` registers a `TomMetricObserver` — a callback,
synchronous or asynchronous, returning `TomObservedValue`s — that is called
each time a snapshot is taken. It costs nothing between scrapes.

`observe` returns a `TomMetricObservation`; `cancel()` removes it, and its
series disappear from the next snapshot. Several observations may report one
name — two pools reporting `db_pool_idle` with different `pool` labels — and
their series are merged, the first to report a label set winning. The scheduler
uses this for its backlog gauges, registering them in `start()` and cancelling
them in `close()`.

### Names, units and conflicts

Names follow Prometheus: `[a-zA-Z_:][a-zA-Z0-9_:]*`, `snake_case`, with the unit
as a suffix (`_seconds`, `_bytes`). Label names follow `[a-zA-Z_][a-zA-Z0-9_]*`
and may not start with `__`, which Prometheus reserves. `unit` is the UCUM unit
(`s`, `By`, `1`) an OTLP export carries; the Prometheus text carries the unit in
the name only.

An instrument is created on first request and returned for the same name
afterwards. A name requested as another kind — a counter as a gauge, an
instrument as an observed gauge — or a histogram requested again with other
buckets, is refused with `metrics.name.conflict`, so two modules cannot
silently record incompatible data under one name. The `help` and `unit` of a
second request are ignored: the first request defines the instrument.

## The Snapshot

`collect()` reads every instrument and calls every observer, and answers a
`List<TomMetricFamily>`: one family per name, sorted by name, each holding its
`TomMetricPoint`s sorted by label set. Two snapshots of the same state are
therefore identical, and so is their rendering — a scrape diff shows changes,
not reordering.

A point carries `value` for a counter or gauge, and `histogram`, a
`TomHistogramData`, for a histogram: `bounds`, `counts` per bucket (not
cumulative — the Prometheus rendering accumulates), `count` and `sum`. The
snapshot holds copies, so recording during an export does not change what the
exporter is reading.

`startTime` is when the registry's totals began — its creation or its last
`reset`. An OTLP export reports cumulative values from that instant, which is
how a collector tells a restarted process from a counter that went down.

### When an observer fails

An observer that throws, or does not answer within `observationTimeout` (five
seconds by default), contributes nothing to that snapshot. The rest of the
snapshot is unaffected — one broken pool gauge does not blank the scrape. The
failure is logged at warn level and counted in
`tom_metrics_observation_failures_total{metric="<name>"}`, which appears in the
same snapshot, so a dashboard can tell a gauge that is zero from one that could
not be read.

## Prometheus Text

`tomPrometheusText(families)` renders a snapshot in the Prometheus text
exposition format 0.0.4, the format every Prometheus-compatible scraper reads:

```text
# HELP report_exports_total Reports exported, by format.
# TYPE report_exports_total counter
report_exports_total{format="pdf"} 3
# HELP report_render_seconds How long rendering a report took.
# TYPE report_render_seconds histogram
report_render_seconds_bucket{le="0.5"} 0
report_render_seconds_bucket{le="2"} 1
report_render_seconds_bucket{le="+Inf"} 1
report_render_seconds_sum 1.25
report_render_seconds_count 1
```

A counter gains `_total`; a histogram becomes cumulative `_bucket` series with
an `le` label, then `_sum` and `_count`. Labels are sorted by name (`le` last)
and escaped; whole numbers render without a decimal point. The function is
pure — it knows nothing about HTTP. Whatever serves it sets
`tomPrometheusContentType` (`text/plain; version=0.0.4; charset=utf-8`) as the
response's `Content-Type`; in a Tom server that is the `/metrics` endpoint.

## Series the Framework Records

The framework records into `TomMetrics.registry`. From this package, the
scheduler and the outgoing HTTP client (`TomResilientClient`):

| Series | Kind | Labels | Meaning |
| ------ | ---- | ------ | ------- |
| `tom_job_start_lag_seconds` | histogram | `job` | How late an attempt started after its run became due. |
| `tom_job_run_duration_seconds` | histogram | `job` | How long an attempt ran. |
| `tom_job_runs_total` | counter | `job`, `outcome` | Attempts ended: `succeeded`, `retried`, `failed`. |
| `tom_job_last_success_timestamp_seconds` | gauge | `job` | When the job last succeeded on this node. |
| `tom_job_backlog` | observed gauge | `job` | Runs due and unclaimed. |
| `tom_job_backlog_age_seconds` | observed gauge | `job` | How long the oldest of them has been due. |
| `tom_http_client_attempts` | counter | `destination`, `outcome` | Outgoing HTTP attempts: `ok`, `retryable_status`, `error`. |
| `tom_http_client_retries` | counter | `destination` | Outgoing HTTP attempts repeated. |
| `tom_http_client_rejections` | counter | `destination`, `reason` | Outgoing calls refused without being sent: `circuit_open`, `bulkhead_full`. |
| `tom_http_client_circuit_open` | observed gauge | `destination` | `1` while the destination's circuit is open or half-open, `0` while closed. |
| `tom_metrics_observation_failures_total` | counter | `metric` | Observers that threw or timed out — see [When an observer fails](#when-an-observer-fails). |

See [Scheduling → Metrics](../scheduling/scheduling.md#metrics) for what each
job series answers and the alert rules they support, and
[HTTP Connection → Metrics](../http_connection/http_connection.md#metrics) for
the client series; the messaging outbox runs
as the job `messaging.outbox`, so its lag is these series. `tom_core_server`
adds the HTTP, SQL, connection-pool, cache and rate-limit series and documents
them with the server.

## Testing Code That Records

`TomMetrics.registry` is process-wide, so a test that asserts on what the
framework recorded resets it first, and reads the instrument directly:

```dart
setUp(TomMetrics.registry.reset);

test('a run records its start lag', () async {
  // ... drive a TomScheduler with a hand-moved clock ...
  final lag = TomMetrics.registry
      .histogram('tom_job_start_lag_seconds', help: '', buckets: tomLagBuckets)
      .valueOf({'job': 'nightly-report'});
  expect(lag!.count, 1);
});
```

`reset()` clears values and restarts `startTime` but keeps instruments and
observations registered — a module that cached its instrument in a field keeps
recording into the same object. For code that takes a registry as a parameter,
a fresh `TomMetricRegistry()` per test needs no reset at all; its `clock`
parameter makes `startTime` deterministic.

## Error Keys

Every misuse throws a `TomMetricsException` synchronously, from the call that
misused the API. `parameters` always carries `metric`.

| Key | When | Other parameters |
| --- | ---- | ---------------- |
| `metrics.name.invalid` | An invalid metric name, or a counter named with `_total`. | — |
| `metrics.name.conflict` | A name already registered as another kind or as an observed gauge, or a histogram requested again with other buckets. | `kind` |
| `metrics.label.invalid` | An invalid label name, or one starting with `__`. | `label` |
| `metrics.counter.negative` | A negative counter increment. | `value` |

## Best Practices

- **Hold the instrument in a field, ask the registry once.** The lookup is a map
  read, but a field makes the series' definition — name, help, unit, buckets —
  sit in one visible place.
- **Bound every label.** Route patterns, not URLs; outcomes from a fixed list,
  not error messages.
- **Count events, not rates.** A counter plus the reader's `rate()` is correct
  across restarts and scrape gaps; a rate computed in process is not.
- **Prefer a histogram to an average gauge.** An average cannot be combined
  across nodes, and hides the tail that alerts are for.
- **Observe what lives elsewhere.** A value in a database or a pool is read by
  an observer at scrape time rather than kept current by every code path that
  changes it.
- **Keep observers fast.** Every scrape waits for every observer, up to
  `observationTimeout` each.

## Limitations

- **Labels are not capped.** An unbounded label grows the registry for the life
  of the process; the registry neither limits nor reports cardinality.
  <!-- unpinned: absence — no cardinality limit exists -->
- **Each isolate's registry is its own.** Nothing aggregates worker isolates'
  registries; record on the isolate the exporters read.
  <!-- unpinned: absence — no cross-isolate aggregation exists -->
- **Buckets are fixed at creation.** A histogram cannot be re-bucketed, and the
  same name with other buckets is refused.
  <!-- pinned: test/metrics_test.dart › one name is one instrument; a second kind is refused -->
- **A failing observer is skipped, not retried.** Its series are missing from
  that snapshot; the failure is counted in
  `tom_metrics_observation_failures_total`.
  <!-- pinned: test/metrics_test.dart › a failing or hanging observation is skipped and counted -->
- **Observers run one after another.** A snapshot takes as long as its slowest
  observers together, bounded by `observationTimeout` each.
  <!-- unpinned: absence — no concurrent observation exists -->
- **There is no summary (quantile) instrument and no exemplars.** Histograms
  cover the quantile use case across nodes.
  <!-- unpinned: absence — no summary instrument exists -->

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `metrics.dart` | `FutureOr` in `TomMetricObserver`, `Future.timeout` for `observationTimeout` |
| `tom_basics` | package | `metrics.dart` | `tomLog`, which reports a failing observer |
| [little_things](../little_things/little_things.md) | module | `metrics.dart` | `TomException`, base of `TomMetricsException` |

`prometheus_text.dart` imports only `metrics.dart`. Nothing here imports
`dart:io`, so the module compiles for the web.
