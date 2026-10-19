/// Runner for all metrics examples.
///
/// Execute this file to run all metrics module examples:
/// ```
/// dart run --enable-asserts example/samples/metrics/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
///
/// The three files go from recording to reading: the instruments, then the
/// snapshot and its Prometheus text, then the series the scheduler records
/// into the process registry.
library;

import '../../sample_bootstrap.dart';

import '01_instruments_example.dart' as instruments;
import '02_snapshot_and_prometheus_example.dart' as snapshot_and_prometheus;
import '03_scheduler_metrics_example.dart' as scheduler_metrics;

/// Standalone entry point for running metrics examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all metrics examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  sampleGroupHeader('Metrics');

  await instruments.run();
  print('✓ Instrument examples passed\n');

  await snapshot_and_prometheus.run();
  print('✓ Snapshot and Prometheus examples passed\n');

  await scheduler_metrics.run();
  print('✓ Scheduler metrics examples passed\n');

  sampleGroupFooter('Metrics');
}
