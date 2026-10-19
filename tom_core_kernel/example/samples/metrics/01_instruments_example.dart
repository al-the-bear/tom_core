/// Example: the three recording instruments of a [TomMetricRegistry]
///
/// - [TomCounter] — a total that only grows
/// - [TomGauge] — a value set when it changes
/// - [TomHistogram] — observations sorted into fixed buckets
///
/// It also shows the two rules every instrument shares: a name is one
/// instrument for the life of the registry (asking again returns the same
/// object), and a label set is one series (label order does not matter). And it
/// provokes each misuse the registry refuses, so the [TomMetricsException] keys
/// are shown rather than described.
///
/// `02_snapshot_and_prometheus_example.dart` owns what leaves the process — the
/// snapshot, observed gauges and the Prometheus text — and
/// `03_scheduler_metrics_example.dart` the series the scheduler records.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/metrics/01_instruments_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// The key of the [TomMetricsException] [body] throws, or `null`.
String? keyOf(void Function() body) {
  try {
    body();
    return null;
  } on TomMetricsException catch (e) {
    return e.key;
  }
}

/// Runs the instrument demonstrations.
Future<void> run() async {
  print('=== 01: Instruments Example ===\n');

  // A registry of its own: the samples leave TomMetrics.registry — the one the
  // framework records into — to the framework.
  final registry = TomMetricRegistry();

  // ---------------------------------------------------------------------------
  // Example 1: a counter, and one series per label set
  // ---------------------------------------------------------------------------
  print('1. A counter grows per label set:');

  final exports = registry.counter(
    'report_exports',
    help: 'Reports exported, by format.',
  );
  exports.add(); // one, with no labels
  exports.add(2, {'format': 'pdf'});
  exports.add(1, {'format': 'csv'});
  exports.add(1, {'format': 'pdf'});

  final unlabelled = exports.valueOf();
  final pdf = exports.valueOf({'format': 'pdf'});
  final neverAdded = exports.valueOf({'format': 'xlsx'});
  final sameInstrument = identical(
    registry.counter('report_exports', help: 'ignored the second time'),
    exports,
  );

  print('   - unlabelled series:      $unlabelled');
  print('   - format=pdf series:      $pdf');
  print('   - format=xlsx (untouched): $neverAdded');
  print('   - same name, same object: $sameInstrument\n');

  // ---------------------------------------------------------------------------
  // Example 2: a gauge, set rather than added to
  // ---------------------------------------------------------------------------
  print('2. A gauge holds the last value set:');

  final openSessions = registry.gauge(
    'report_sessions_open',
    help: 'Report sessions open, by region.',
  );
  openSessions.set(4, {'region': 'eu', 'tier': 'free'});
  openSessions.set(3, {'tier': 'free', 'region': 'eu'}); // same series
  final eu = openSessions.valueOf({'region': 'eu', 'tier': 'free'});
  final unset = openSessions.valueOf({'region': 'us', 'tier': 'free'});

  print('   - region=eu,tier=free:     $eu (label order is irrelevant)');
  print('   - never set:               $unset\n');

  // ---------------------------------------------------------------------------
  // Example 3: a histogram, its buckets and its two shortcuts
  // ---------------------------------------------------------------------------
  print('3. A histogram sorts observations into buckets:');

  final render = registry.histogram(
    'report_render_seconds',
    help: 'How long rendering a report took.',
    unit: 's',
    buckets: const [0.1, 1, 10],
  );
  render.record(0.05);
  render.record(1); // a value equal to a bound falls into that bound's bucket
  render.recordDuration(const Duration(milliseconds: 2500));
  render.record(42); // above the last bound: the implicit +Inf bucket
  final timed = await render.time(() async => 'rendered', {'kind': 'timed'});

  final data = render.valueOf()!;
  print('   - per-bucket counts:       ${data.counts} (le 0.1, 1, 10, +Inf)');
  print('   - count / sum:             ${data.count} / ${data.sum}');
  print('   - time() handed back:      $timed');
  print(
    '   - the timed series:        ${render.valueOf({'kind': 'timed'})!.count} '
    'observation\n',
  );

  // ---------------------------------------------------------------------------
  // Example 4: what the registry refuses
  // ---------------------------------------------------------------------------
  print('4. Misuse is refused with a keyed TomMetricsException:');

  final negative = keyOf(() => exports.add(-1));
  final totalSuffix = keyOf(
    () => registry.counter('report_exports_total', help: 'h'),
  );
  final badName = keyOf(() => registry.gauge('report-errors', help: 'h'));
  final twoKinds = keyOf(() => registry.gauge('report_exports', help: 'h'));
  final otherBuckets = keyOf(
    () => registry.histogram('report_render_seconds', help: 'h'),
  );
  final badLabel = keyOf(() => openSessions.set(1, {'__region': 'eu'}));

  print('   - a negative increment:    $negative');
  print('   - a counter named _total:  $totalSuffix');
  print('   - a hyphen in the name:    $badName');
  print('   - a counter as a gauge:    $twoKinds');
  print('   - other buckets:           $otherBuckets');
  print('   - a reserved label name:   $badLabel\n');

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  // Example 1
  assert(unlabelled == 1, 'add() with no arguments adds one, unlabelled');
  assert(pdf == 3, 'Each add to a label set accumulates in that series only');
  assert(neverAdded == 0, 'A counter series never added to reads zero');
  assert(sameInstrument, 'Asking for a name again returns the same counter');

  // Example 2
  assert(eu == 3, 'A gauge keeps the last value; label order is one series');
  assert(unset == null, 'A gauge series never set reads null, not zero');

  // Example 3
  assert(
    data.counts.join(',') == '1,1,1,1',
    'One observation in each bucket: 0.05, 1 (on the bound), 2.5, 42 (+Inf)',
  );
  assert(
    data.count == 4 && (data.sum - 45.55).abs() < 1e-9,
    'Count and sum of all four',
  );
  assert(timed == 'rendered', 'time() hands back what the body returned');
  assert(render.buckets.join(',') == '0.1,1.0,10.0', 'The buckets as given');

  // Example 4
  assert(negative == 'metrics.counter.negative', 'A counter only grows');
  assert(totalSuffix == 'metrics.name.invalid', 'The rendering adds _total');
  assert(badName == 'metrics.name.invalid', 'Names are Prometheus names');
  assert(twoKinds == 'metrics.name.conflict', 'One name, one kind');
  assert(otherBuckets == 'metrics.name.conflict', 'One name, one bucket set');
  assert(badLabel == 'metrics.label.invalid', '__ labels are reserved');
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
