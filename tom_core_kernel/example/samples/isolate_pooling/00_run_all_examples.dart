/// Runner for all isolate_pooling examples.
///
/// Execute this file to run all isolate pooling module examples:
/// ```
/// dart run example/samples/isolate_pooling/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import 'dart:io';

import '../../run_all_samples.reflection.dart';

import '01_worker_basics_example.dart' as worker_basics;
import '02_worker_pool_example.dart' as worker_pool;
import '03_worker_creator_communication_example.dart' as worker_creator;
import '04_worker_pool_supervision_example.dart' as worker_pool_supervision;
import '05_creator_backchannel_example.dart' as creator_backchannel;

/// Standalone entry point for running isolate pooling examples.
///
/// The pool examples intentionally leave some worker isolates running to
/// demonstrate real-world usage (see `02_worker_pool_example.dart`), so the
/// process would not terminate on its own. Force an explicit `exit` once the
/// examples finish — the same lifecycle contract the master runner
/// (`example/run_all_samples.dart`) applies. The shared [run] must not exit,
/// because the master runner calls it mid-sequence.
Future<void> main() async {
  initializeReflection();
  try {
    await run();
  } catch (e, st) {
    print('\n❌ ERROR running isolate pooling examples: $e');
    print(st);
    exit(1);
  }
  exit(0);
}

/// Run all isolate pooling examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('Running Isolate Pooling Examples...\n');
  print('=' * 60);

  print('\n01: Worker Basics Example');
  print('-' * 40);
  await worker_basics.run();
  print('✓ Worker basics examples passed\n');

  print('02: Worker Pool Example');
  print('-' * 40);
  await worker_pool.run();
  print('✓ Worker pool examples passed\n');

  print('03: Worker-Creator Communication Example');
  print('-' * 40);
  await worker_creator.run();
  print('✓ Worker-creator communication examples passed\n');

  print('04: Worker Pool Liveness Supervision Example');
  print('-' * 40);
  await worker_pool_supervision.run();
  print('✓ Worker pool supervision examples passed\n');

  print('05: Creator Backchannel Example');
  print('-' * 40);
  await creator_backchannel.run();
  print('✓ Creator backchannel examples passed\n');

  print('=' * 60);
  print('All isolate pooling examples completed successfully!');
}
