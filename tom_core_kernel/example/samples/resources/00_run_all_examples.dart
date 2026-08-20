/// Runner for all resources examples.
///
/// Execute this file to run all resources module examples:
/// ```
/// dart run --enable-asserts example/samples/resources/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_resource_provider_example.dart' as resource_provider;
import '02_config_resource_provider_example.dart' as config_provider;
import '03_resource_fallback_example.dart' as resource_fallback;
import '04_app_singleton_example.dart' as app_singleton;

/// Standalone entry point for running resources examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all resources examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Resources System Samples                        ║');
  print(
    '╚══════════════════════════════════════════════════════════════════╝\n',
  );

  resource_provider.run();
  config_provider.run();
  resource_fallback.run();
  app_singleton.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
