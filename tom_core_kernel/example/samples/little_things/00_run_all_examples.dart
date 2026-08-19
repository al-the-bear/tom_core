/// Runner for all little_things examples.
///
/// Execute this file to run all little_things module examples:
/// ```
/// dart run --enable-asserts example/samples/little_things/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_utility_functions_example.dart' as utility_functions;
import '02_zone_helpers_example.dart' as zone_helpers;
import '03_tom_exception_example.dart' as tom_exception;
import '04_formatting_and_exceptions_example.dart' as formatting_exceptions;

/// Standalone entry point for running little things examples.
Future<void> main() async {
  initializeReflection();
  await run();
}

/// Run all little things examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('Running Little Things Examples...\n');
  print('=' * 60);

  print('\n01: Utility Functions Example');
  print('-' * 40);
  utility_functions.run();
  print('✓ Utility functions examples passed\n');

  print('02: Zone Helpers Example');
  print('-' * 40);
  await zone_helpers.run();
  print('✓ Zone helpers examples passed\n');

  print('03: TomException Example');
  print('-' * 40);
  tom_exception.run();
  print('✓ TomException examples passed\n');

  print('04: Formatting and Exceptions Example');
  print('-' * 40);
  await formatting_exceptions.run();
  print('✓ Formatting and exception examples passed\n');

  print('=' * 60);
  print('All little_things examples completed successfully!');
}
