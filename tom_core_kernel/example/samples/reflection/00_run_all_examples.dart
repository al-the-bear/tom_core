/// Reflection Examples Runner
///
/// This file runs all reflection examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run --enable-asserts example/samples/reflection/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

// Import all example files
import '01_basic_reflection_example.dart' as basic;
import '02_nested_objects_example.dart' as nested;
import '03_collections_example.dart' as collections;
import '04_datetime_types_example.dart' as datetime;
import '05_tomclass_integration_example.dart' as tomclass;
import '06_advanced_reflection_example.dart' as advanced;

/// Standalone entry point for running reflection examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all reflection examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║           Tom Reflection System Samples                          ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  basic.run();
  nested.run();
  collections.run();
  datetime.run();
  tomclass.run();
  advanced.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
