/// Runner for all JSON examples.
///
/// Execute this file to run all JSON module examples:
/// ```
/// dart run --enable-asserts example/samples/json/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_json_formatting_example.dart' as json_formatting;
import '02_json_navigation_example.dart' as json_navigation;
import '03_json_config_resolution_example.dart' as json_config_resolution;
import '04_json_serialization_example.dart' as json_serialization;

/// Standalone entry point for running JSON examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all JSON examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running JSON Examples...\n');
  print('=' * 60);

  print('\n01: JSON Formatting Example');
  print('-' * 40);
  json_formatting.run();
  print('✓ JSON formatting examples passed\n');

  print('02: JSON Navigation Example');
  print('-' * 40);
  json_navigation.run();
  print('✓ JSON navigation examples passed\n');

  print('03: JSON Config Resolution Example');
  print('-' * 40);
  json_config_resolution.run();
  print('✓ JSON config resolution examples passed\n');

  print('04: JSON Serialization Example');
  print('-' * 40);
  json_serialization.run();
  print('✓ JSON serialization examples passed\n');

  print('=' * 60);
  print('All JSON examples completed successfully!');
}
