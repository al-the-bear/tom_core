/// Runner for all scheduling examples.
///
/// Execute this file to run all scheduling module examples:
/// ```
/// dart run example/samples/scheduling/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
///
/// The four files build on each other and are worth reading in order: the
/// substrate, then the declarative route on top of it, then the trigger kinds,
/// then the guarantee every job body has to live with.
library;

import '../../run_all_samples.reflection.dart';

import '01_memory_substrate_example.dart' as memory_substrate;
import '02_declared_job_example.dart' as declared_job;
import '03_schedule_kinds_example.dart' as schedule_kinds;
import '04_execution_guarantee_example.dart' as execution_guarantee;

/// Standalone entry point for running scheduling examples.
Future<void> main() async {
  // Example 02 discovers its jobs by annotation, so the reflection build has to
  // be initialised before anything scans it.
  initializeReflection();
  await run();
}

/// Run all scheduling examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('Running Scheduling Examples...\n');
  print('=' * 60);

  print('\n01: Memory Substrate Example');
  print('-' * 40);
  await memory_substrate.run();
  print('✓ Memory substrate examples passed\n');

  print('02: Declared Job Example');
  print('-' * 40);
  await declared_job.run();
  print('✓ Declared job examples passed\n');

  print('03: Schedule Kinds Example');
  print('-' * 40);
  await schedule_kinds.run();
  print('✓ Schedule kind examples passed\n');

  print('04: Execution Guarantee Example');
  print('-' * 40);
  await execution_guarantee.run();
  print('✓ Execution guarantee examples passed\n');

  print('=' * 60);
  print('All Scheduling examples completed successfully!');
}
