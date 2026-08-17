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
/// Nothing is forced to `exit` on the success path. Every example closes the
/// workers and pools it opens — `02_worker_pool_example.dart` ends by closing
/// its pool and asserting that a later dispatch is refused — and a closed
/// worker's isolate shuts its own receive port, so once [run] returns there is
/// nothing left holding the event loop open and the process terminates by
/// itself. Should a later example leak a worker, this runner will hang rather
/// than exit; that is the signal wanted, because these files exist to model
/// the lifecycle and a leak in one of them is a defect in the example.
///
/// The failure path does exit explicitly, so that a caller reading only the
/// exit code sees a non-zero status. The shared [run] must not exit either
/// way — the master runner (`example/run_all_samples.dart`) calls it
/// mid-sequence.
Future<void> main() async {
  initializeReflection();
  try {
    await run();
  } catch (e, st) {
    print('\n❌ ERROR running isolate pooling examples: $e');
    print(st);
    exit(1);
  }
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
