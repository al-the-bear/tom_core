/// Runner for all shutdown cleanup examples.
///
/// Execute this file to run all shutdown cleanup module examples:
/// ```
/// dart run --enable-asserts example/samples/shutdown_cleanup/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_shutdown_handler_example.dart' as shutdown_handler;
import '02_advanced_shutdown_example.dart' as advanced_shutdown;
import '03_shutdown_execution_example.dart' as shutdown_execution;

/// Standalone entry point for running shutdown cleanup examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all shutdown cleanup examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  sampleGroupHeader('Shutdown Cleanup');

  await shutdown_handler.run();
  print('✓ Shutdown handler examples passed\n');

  await advanced_shutdown.run();
  print('✓ Advanced shutdown examples passed\n');

  await shutdown_execution.run();
  print('✓ Shutdown execution examples passed\n');

  sampleGroupFooter('Shutdown Cleanup');
}
