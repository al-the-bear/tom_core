/// Runner for all context examples.
///
/// Execute this file to run all context module examples:
/// ```
/// dart run --enable-asserts example/samples/context/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_basic_context_example.dart' as basic_context;
import '02_context_nesting_example.dart' as context_nesting;
import '03_context_providers_example.dart' as context_providers;
import '04_async_and_zonevalues_example.dart' as async_zonevalues;
import '05_trace_context_example.dart' as trace_context;

/// Standalone entry point for running context examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all context examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  sampleGroupHeader('Context');

  basic_context.run();
  print('✓ Basic context examples passed\n');

  context_nesting.run();
  print('✓ Context nesting examples passed\n');

  context_providers.run();
  print('✓ Context providers examples passed\n');

  await async_zonevalues.run();
  print('✓ Async and zone-values examples passed\n');

  await trace_context.run();
  print('✓ Trace context examples passed\n');

  sampleGroupFooter('Context');
}
