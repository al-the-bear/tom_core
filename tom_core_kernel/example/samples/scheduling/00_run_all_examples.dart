/// Runner for all scheduling examples.
///
/// Execute this file to run all scheduling module examples:
/// ```
/// dart run --enable-asserts example/samples/scheduling/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
///
/// The five files build on each other and are worth reading in order: the
/// substrate, then the declarative route on top of it, then the trigger kinds,
/// then the guarantee every job body has to live with — and finally the same
/// substrate on disk, which is the only one of them that says anything across a
/// restart.
library;

import '../../sample_bootstrap.dart';

import '01_memory_substrate_example.dart' as memory_substrate;
import '02_declared_job_example.dart' as declared_job;
import '03_schedule_kinds_example.dart' as schedule_kinds;
import '04_execution_guarantee_example.dart' as execution_guarantee;
import '05_durable_store_example.dart' as durable_store;

/// Standalone entry point for running scheduling examples.
Future<void> main() async {
  // Example 02 discovers its jobs by annotation, so the reflection build has to
  // be initialised before anything scans it.
  bootstrapSamples();
  await run();
}

/// Run all scheduling examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  sampleGroupHeader('Scheduling');

  await memory_substrate.run();
  print('✓ Memory substrate examples passed\n');

  await declared_job.run();
  print('✓ Declared job examples passed\n');

  await schedule_kinds.run();
  print('✓ Schedule kind examples passed\n');

  await execution_guarantee.run();
  print('✓ Execution guarantee examples passed\n');

  await durable_store.run();
  print('✓ Durable store examples passed\n');

  sampleGroupFooter('Scheduling');
}
