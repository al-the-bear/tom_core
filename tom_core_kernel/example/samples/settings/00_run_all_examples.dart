/// Runner for all settings examples.
///
/// Execute this file to run all settings module examples:
/// ```
/// dart run --enable-asserts example/samples/settings/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_client_authorization_example.dart' as client_authorization;

/// Standalone entry point for running settings examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all settings examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  sampleGroupHeader('Settings');

  client_authorization.run();
  print('✓ Client authorization examples passed\n');

  sampleGroupFooter('Settings');
}
