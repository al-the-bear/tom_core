/// Runner for all logging examples.
///
/// Execute this file to run all logging module examples:
/// ```
/// dart run --enable-asserts example/samples/logging/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_basic_logging_example.dart' as basic_logging;
import '02_log_levels_example.dart' as log_levels;
import '03_log_formatting_example.dart' as log_formatting;
import '04_advanced_logging_example.dart' as advanced_logging;
import '05_isolate_and_remote_logging_example.dart' as isolate_remote;
import '06_log_replay_and_isolate_plumbing_example.dart' as log_replay_plumbing;

/// Standalone entry point for running logging examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all logging examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('Running Logging Examples...\n');
  print('=' * 60);
  print('');

  basic_logging.run();
  print('✓ Basic logging examples passed\n');

  log_levels.run();
  print('✓ Log levels examples passed\n');

  log_formatting.run();
  print('✓ Log formatting examples passed\n');

  advanced_logging.run();
  print('✓ Advanced logging examples passed\n');

  // Only the deterministic remote round-trip participates in the aggregate
  // runner; the isolate demonstration spawns a real background isolate and is
  // exposed through that example's standalone main() only.
  isolate_remote.run();
  print('✓ Remote logging round-trip examples passed\n');

  await log_replay_plumbing.run();
  print('✓ Log replay and isolate plumbing examples passed\n');

  print('=' * 60);
  print('All logging examples completed successfully!');
}
