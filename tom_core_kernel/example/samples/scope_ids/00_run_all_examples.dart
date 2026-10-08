/// Runner for all scope IDs examples.
///
/// Execute this file to run all scope IDs module examples:
/// ```
/// dart run --enable-asserts example/samples/scope_ids/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_scope_basics_example.dart' as scope_basics;
import '02_scope_capture_example.dart' as scope_capture;
import '03_scope_mixin_example.dart' as scope_mixin;

/// Standalone entry point for running scope IDs examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all scope IDs examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  sampleGroupHeader('Scope IDs');

  scope_basics.run();
  scope_capture.run();
  scope_mixin.run();

  sampleGroupFooter('Scope IDs');
}
