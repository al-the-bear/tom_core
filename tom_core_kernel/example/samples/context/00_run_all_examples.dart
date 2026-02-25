/// Runner for all context examples.
///
/// Execute this file to run all context module examples:
/// ```
/// dart run example/samples/tombase/context/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_basic_context_example.dart' as basic_context;
import '02_context_nesting_example.dart' as context_nesting;
import '03_context_providers_example.dart' as context_providers;
import '04_advanced_context_example.dart' as advanced_context;

/// Standalone entry point for running context examples.
Future<void> main() async {
  initializeReflection();
  await run();
}

/// Run all context examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('Running Context Examples...\n');
  print('=' * 60);

  print('\n01: Basic Context Example');
  print('-' * 40);
  basic_context.run();
  print('✓ Basic context examples passed\n');

  print('02: Context Nesting Example');
  print('-' * 40);
  context_nesting.run();
  print('✓ Context nesting examples passed\n');

  print('03: Context Providers Example');
  print('-' * 40);
  context_providers.run();
  print('✓ Context providers examples passed\n');

  print('04: Advanced Context Example');
  print('-' * 40);
  await advanced_context.run();
  print('✓ Advanced context examples passed\n');

  print('=' * 60);
  print('All context examples completed successfully!');
}
