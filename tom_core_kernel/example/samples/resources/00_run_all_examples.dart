/// Runner for all resources examples.
///
/// Execute this file to run all resources module examples:
/// ```
/// dart run example/samples/tombase/resources/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run example/run_all_samples.dart
/// ```
library;

import '../../run_all_samples.reflection.dart';

import '01_resource_provider_example.dart' as resource_provider;
import '02_config_resource_provider_example.dart' as config_provider;

/// Standalone entry point for running resources examples.
void main() {
  initializeReflection();
  run();
}

/// Run all resources examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Resources System Samples                        ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  resource_provider.run();
  config_provider.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
