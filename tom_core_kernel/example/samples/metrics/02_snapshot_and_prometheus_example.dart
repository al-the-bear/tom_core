/// Example: what leaves the process — the snapshot and its Prometheus text
///
/// - [TomMetricRegistry.collect] — one sorted [TomMetricFamily] per instrument,
///   each holding its [TomMetricPoint]s
/// - [TomMetricRegistry.observe] — a gauge computed by a [TomMetricObserver]
///   when the snapshot is taken, and what happens when that callback fails
/// - [tomPrometheusText] — the snapshot in the Prometheus text exposition
///   format, shown in full so the rendering is visible rather than described
/// - [TomMetricObservation.cancel] and [TomMetricRegistry.reset]
///
/// The OTLP exporter in `tom_core_server` reads the same snapshot, which is why
/// a series is defined once however it is exported.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/metrics/02_snapshot_and_prometheus_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// [registry]'s snapshot, with logging off for its duration.
///
/// A failing observer is logged at warn level — right in a service, where it
/// is the only trace of the failure, but noise between two lines of a sample
/// that provokes it on purpose. The failure is still counted and asserted on.
Future<List<TomMetricFamily>> quietCollect(TomMetricRegistry registry) async {
  tomLog.pushLogLevel(TomLogLevel.none);
  try {
    return await registry.collect();
  } finally {
    tomLog.popLogLevel();
  }
}

/// Runs the snapshot demonstrations.
Future<void> run() async {
  print('=== 02: Snapshot and Prometheus Example ===\n');

  final registry = TomMetricRegistry();

  // ---------------------------------------------------------------------------
  // Example 1: an observed gauge is read when the snapshot is taken
  // ---------------------------------------------------------------------------
  print('1. An observed gauge is computed at snapshot time:');

  // A queue whose depth is cheaper to read than to keep current.
  final queue = <String, int>{'pdf': 2, 'csv': 0};
  var reads = 0;
  final depth = registry.observe(
    'report_queue_depth',
    help: 'Reports waiting to render, by format.',
    observer: () {
      reads++;
      return [
        for (final e in queue.entries)
          TomObservedValue(e.value, {'format': e.key}),
      ];
    },
  );
  final readsBeforeCollect = reads;
  queue['csv'] = 5;
  final first = await registry.collect();
  final depthPoints = first.single.points;
  final readsAfterCollect = reads;

  print('   - reads before collect():  $readsBeforeCollect');
  print('   - reads after one collect: $readsAfterCollect');
  print(
    '   - series, in label order:  '
    '${[for (final p in depthPoints) '${p.labels['format']}=${p.value}']}\n',
  );

  // ---------------------------------------------------------------------------
  // Example 2: the Prometheus text of a snapshot
  // ---------------------------------------------------------------------------
  print('2. The snapshot as a Prometheus scrape sees it:');

  registry.counter('report_exports', help: 'Reports exported, by format.').add(
    3,
    {'format': 'pdf'},
  );
  registry
      .histogram(
        'report_render_seconds',
        help: 'How long rendering a report took.',
        unit: 's',
        buckets: const [0.5, 2],
      )
      .record(1.25);
  final text = tomPrometheusText(await registry.collect());
  print(text.split('\n').map((l) => '   | $l').join('\n'));
  print('   Content-Type: $tomPrometheusContentType\n');

  // ---------------------------------------------------------------------------
  // Example 3: a failing observer costs its own series, nothing else
  // ---------------------------------------------------------------------------
  print('3. A failing observer is counted, not propagated:');

  registry.observe(
    'report_cache_entries',
    help: 'Entries in the report cache.',
    observer: () => throw StateError('cache unavailable'),
  );
  final withFailure = await quietCollect(registry);
  final byName = {for (final f in withFailure) f.name: f};
  final failures = byName['tom_metrics_observation_failures']!.points.single;

  print('   - families still returned: ${byName.keys.toList()}');
  print(
    '   - failures counted for:    ${failures.labels['metric']} '
    '= ${failures.value}\n',
  );

  // ---------------------------------------------------------------------------
  // Example 4: cancel() and reset()
  // ---------------------------------------------------------------------------
  print('4. cancel() removes an observation, reset() clears the values:');

  depth.cancel();
  final startedAt = registry.startTime;
  registry.reset();
  // The cache observer still fails; this snapshot is about the other two.
  final afterReset = await quietCollect(registry);
  final exportsAfterReset = afterReset
      .firstWhere((f) => f.name == 'report_exports')
      .points;

  print(
    '   - queue depth reported:    '
    '${afterReset.any((f) => f.name == 'report_queue_depth')}',
  );
  print('   - report_exports series:   ${exportsAfterReset.length}');
  print(
    '   - startTime restarted:     '
    '${!registry.startTime.isBefore(startedAt)}\n',
  );

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  // Example 1
  assert(readsBeforeCollect == 0, 'Registering an observer does not call it');
  assert(readsAfterCollect == 1, 'Each snapshot calls each observer once');
  assert(
    depthPoints.map((p) => '${p.labels['format']}=${p.value}').join(' ') ==
        'csv=5.0 pdf=2.0',
    'The value at snapshot time, points sorted by label set',
  );

  // Example 2: families sorted by name; a counter gains _total; a histogram's
  // buckets are cumulative and end in +Inf.
  assert(
    text ==
        '# HELP report_exports_total Reports exported, by format.\n'
            '# TYPE report_exports_total counter\n'
            'report_exports_total{format="pdf"} 3\n'
            '# HELP report_queue_depth Reports waiting to render, by format.\n'
            '# TYPE report_queue_depth gauge\n'
            'report_queue_depth{format="csv"} 5\n'
            'report_queue_depth{format="pdf"} 2\n'
            '# HELP report_render_seconds How long rendering a report took.\n'
            '# TYPE report_render_seconds histogram\n'
            'report_render_seconds_bucket{le="0.5"} 0\n'
            'report_render_seconds_bucket{le="2"} 1\n'
            'report_render_seconds_bucket{le="+Inf"} 1\n'
            'report_render_seconds_sum 1.25\n'
            'report_render_seconds_count 1\n',
    'The exposition format, exactly',
  );
  assert(
    tomPrometheusContentType == 'text/plain; version=0.0.4; charset=utf-8',
    'The content type of format 0.0.4',
  );

  // Example 3
  assert(
    byName.containsKey('report_exports') &&
        byName.containsKey('report_queue_depth'),
    'The other families are unaffected by one failing observer',
  );
  assert(
    byName['report_cache_entries']!.points.isEmpty,
    'The failing observer contributes no series to this snapshot',
  );
  assert(
    failures.labels['metric'] == 'report_cache_entries' && failures.value == 1,
    'The failure is counted by metric, in the same snapshot',
  );

  // Example 4
  assert(
    !afterReset.any((f) => f.name == 'report_queue_depth'),
    'A cancelled observation disappears from the next snapshot',
  );
  assert(
    exportsAfterReset.isEmpty,
    'reset() clears the values but keeps the instrument registered',
  );
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
