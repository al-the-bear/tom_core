/// Runner for all logging examples.
///
/// Execute this file to run all logging module examples:
/// ```
/// dart run example/samples/tombase/logging/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_basic_logging_example.dart' as basic_logging;
import '02_log_levels_example.dart' as log_levels;
import '03_log_formatting_example.dart' as log_formatting;
import '04_advanced_logging_example.dart' as advanced_logging;

/// Standalone entry point for running logging examples.
void main() {
  initializeReflection();
  run();
}

/// Run all logging examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running Logging Examples...\n');
  print('=' * 60);

  print('\n01: Basic Logging Example');
  print('-' * 40);
  basic_logging.run();
  print('✓ Basic logging examples passed\n');

  print('02: Log Levels Example');
  print('-' * 40);
  log_levels.run();
  print('✓ Log levels examples passed\n');

  print('03: Log Formatting Example');
  print('-' * 40);
  log_formatting.run();
  print('✓ Log formatting examples passed\n');

  print('04: Advanced Logging Example');
  print('-' * 40);
  advanced_logging.run();
  print('✓ Advanced logging examples passed\n');

  print('=' * 60);
  print('All logging examples completed successfully!');
}
