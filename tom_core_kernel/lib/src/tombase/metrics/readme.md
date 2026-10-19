# metrics

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

In-process metrics. A `TomMetricRegistry` holds counters, gauges and histograms
that are recorded as work happens, plus gauges computed by a callback when they
are read; `collect()` answers one sorted snapshot of all of them. The snapshot
is what leaves the process: `tomPrometheusText` renders it for a Prometheus
scrape (the server's `/metrics` endpoint), and `tom_core_server`'s OTLP exporter
reads the same snapshot, so a series is defined once however it is exported.

The framework records into `TomMetrics.registry` — the scheduler its job runs
(`tom_job_*`), the server its requests, statements, pools, caches and
rate-limit refusals — and an application adds its own series to the same
registry. The registry is per isolate, and labels must be bounded: every
distinct label set is a series held for the life of the process.

## Key types & functions

| Type | Responsibility |
| ---- | -------------- |
| `TomMetricRegistry` | The instruments of one isolate: creates each on first request, returns it again afterwards, and answers the snapshot (`collect`). |
| `TomMetrics` | Holds `TomMetrics.registry`, the registry the framework records into. |
| `TomMetric` | The sealed base of the three instruments: name, help, unit, kind. |
| `TomCounter` | A total that only grows; read as `<name>_total`. |
| `TomGauge` | A value set whenever it changes. |
| `TomHistogram` | Observations sorted into fixed buckets; read as `_bucket`, `_sum`, `_count`. |
| `TomHistogramData` | One histogram series: a count per bucket, the number of observations, their sum. |
| `TomMetricObserver` | The callback an observed gauge is computed by when a snapshot is taken. |
| `TomObservedValue` | One value such a callback reports, with its labels. |
| `TomMetricObservation` | A registered callback; `cancel` removes it. |
| `TomMetricFamily` | One instrument in a snapshot: its metadata and its series. |
| `TomMetricPoint` | One series in a snapshot: labels plus a value or histogram data. |
| `TomMetricKind` | `counter`, `gauge` or `histogram`. |
| `TomMetricsException` | A misuse: an invalid name or label, one name as two kinds, a negative counter increment. |
| `tomLatencyBuckets` / `tomLagBuckets` | Bucket bounds in seconds — milliseconds-to-seconds latencies, seconds-to-an-hour delays. |
| `tomPrometheusText` / `tomPrometheusContentType` | The snapshot in the Prometheus text exposition format 0.0.4, and the `Content-Type` it is served with. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> main() async {
  final registry = TomMetricRegistry();

  // Ask for an instrument where you record; the same name returns it again.
  final exports = registry.counter(
    'report_exports',
    help: 'Reports exported, by format.',
  );
  exports.add(1, {'format': 'pdf'});

  final latency = registry.histogram(
    'report_render_seconds',
    help: 'How long rendering a report took.',
    unit: 's',
  );
  await latency.time(() async => 'rendered');

  // A value cheaper to read than to keep current is observed at snapshot time.
  registry.observe(
    'report_queue_depth',
    help: 'Reports waiting to render.',
    observer: () => [const TomObservedValue(3)],
  );

  final text = tomPrometheusText(await registry.collect());
  assert(text.contains('report_exports_total{format="pdf"} 1'));
  assert(text.contains('report_queue_depth 3'));
  print(text);
}
```

See [`doc/metrics/metrics.md`](../../../../doc/metrics/metrics.md) for the
series the framework records and how they are exported.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
