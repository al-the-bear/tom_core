/// Isolate Pooling Examples Runner
///
/// This file runs all isolate pooling examples in sequence.
/// These examples demonstrate how to use TomWorker and TomWorkerPool
/// for parallel task execution across isolates.
///
/// To run this file:
/// ```bash
/// dart run example/tombase/isolate_pooling/00_run_all_examples.dart
/// ```
library;

// Import all example files
import 'dart:io';

import '01_worker_basics_example.dart' as worker_basics;
import '02_worker_pool_example.dart' as worker_pool;
import '03_creator_backchannel_example.dart' as creator_backchannel;

void main() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║             Tom Isolate Pooling System Examples                  ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples (async because isolate operations are async)
  await worker_basics.run();
  await worker_pool.run();
  await creator_backchannel.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Examples Complete!                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝');

  exit(0);
}
