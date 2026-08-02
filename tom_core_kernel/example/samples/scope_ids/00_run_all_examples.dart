/// Runner for all scope IDs examples.
///
/// Execute this file to run all scope IDs module examples:
/// ```
/// dart run example/samples/scope_ids/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_scope_basics_example.dart' as scope_basics;
import '02_inscope_builder_example.dart' as inscope_builder;
import '03_scope_mixin_example.dart' as scope_mixin;

/// Standalone entry point for running scope IDs examples.
void main() {
  initializeReflection();
  run();
}

/// Run all scope IDs examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Scope IDs System Samples                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  scope_basics.run();
  inscope_builder.run();
  scope_mixin.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
