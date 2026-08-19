/// HTTP Connection Examples Runner
///
/// This file runs all http_connection examples in sequence.
///
/// To run this file:
/// ```bash
/// dart run --enable-asserts example/samples/http_connection/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

// Import all example files
import '01_http_client_example.dart' as http_client;
import '02_connection_config_example.dart' as connection_config;
import '03_retry_policies_example.dart' as retry_policies;
import '04_api_endpoint_definition_example.dart' as api_endpoints;
import '05_remote_context_example.dart' as remote_context;
import '06_auth_retry_example.dart' as auth_retry;

/// Standalone entry point for running HTTP connection examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all HTTP connection examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom HTTP Connection System Samples                  ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  // Run all examples
  http_client.run();
  connection_config.run();
  retry_policies.run();
  api_endpoints.run();
  remote_context.run();
  await auth_retry.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
