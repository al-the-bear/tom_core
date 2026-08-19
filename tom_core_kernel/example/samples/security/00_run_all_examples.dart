/// Runner for all security examples.
///
/// Execute this file to run all security module examples:
/// ```
/// dart run --enable-asserts example/samples/security/00_run_all_examples.dart
/// ```
///
/// Or run all samples together:
/// ```bash
/// dart run --enable-asserts example/run_all_samples.dart
/// ```
library;

import '../../sample_bootstrap.dart';

import '01_user_principal_example.dart' as user_principal;
import '02_access_control_example.dart' as access_control;
import '03_advanced_access_control_example.dart' as advanced_access;
import '04_bearer_authentication_example.dart' as bearer_auth;
import '05_ui_authorization_example.dart' as ui_authorization;
import '06_graded_access_example.dart' as graded_access;

/// Standalone entry point for running security examples.
void main() {
  bootstrapSamples();
  run();
}

/// Run all security examples.
/// Called from run_all_samples.dart or can be run standalone via main().
void run() {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Security System Samples                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝\n');

  user_principal.run();
  access_control.run();
  advanced_access.run();
  bearer_auth.run();
  ui_authorization.run();
  graded_access.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
