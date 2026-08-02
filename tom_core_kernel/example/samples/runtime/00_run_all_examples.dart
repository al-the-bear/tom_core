/// Runner for all runtime examples.
///
/// Execute this file to run all runtime module examples:
/// ```
/// dart run example/samples/runtime/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_platform_detection_example.dart' as platform_detection;
import '02_environment_platform_example.dart' as environment_platform;
import '03_initialization_sequence_example.dart' as initialization_sequence;
import '04_advanced_runtime_example.dart' as advanced_runtime;

/// Standalone entry point for running runtime examples.
void main() {
  initializeReflection();
  run();
}

/// Run all runtime examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running Runtime Examples...\n');
  print('=' * 60);

  print('\n01: Platform Detection Example');
  print('-' * 40);
  platform_detection.run();
  print('✓ Platform detection examples passed\n');

  print('02: Environment Platform Example');
  print('-' * 40);
  environment_platform.run();
  print('✓ Environment platform examples passed\n');

  print('03: Initialization Sequence Example');
  print('-' * 40);
  initialization_sequence.run();
  print('✓ Initialization sequence examples passed\n');

  print('04: Advanced Runtime Example');
  print('-' * 40);
  advanced_runtime.run();
  print('✓ Advanced runtime examples passed\n');

  print('=' * 60);
  print('All runtime examples completed successfully!');
}
