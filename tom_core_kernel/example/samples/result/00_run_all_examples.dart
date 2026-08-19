/// Runner for all result examples.
///
/// Execute this file to run all result module examples:
/// ```
/// dart run --enable-asserts example/samples/result/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_result_envelope_example.dart' as result_envelope;
import '02_error_details_example.dart' as error_details;
import '03_result_wire_format_example.dart' as result_wire_format;

/// Standalone entry point for running result examples.
void main() {
  initializeReflection();
  run();
}

/// Run all result examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('Running Result Examples...\n');
  print('=' * 60);

  print('\n01: Result Envelope Example');
  print('-' * 40);
  result_envelope.run();
  print('✓ Result envelope examples passed\n');

  print('02: Error Details Example');
  print('-' * 40);
  error_details.run();
  print('✓ Error detail examples passed\n');

  print('03: Result Wire Format Example');
  print('-' * 40);
  result_wire_format.run();
  print('✓ Result wire-format examples passed\n');

  print('=' * 60);
  print('All Result examples completed successfully!');
}
