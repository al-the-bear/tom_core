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
import '07_resource_role_authorization_example.dart' as resource_roles;
import '08_server_principal_meet_example.dart' as server_principal_meet;
import '09_two_factor_login_example.dart' as two_factor_login;
import '10_oauth_contract_example.dart' as oauth_contract;
import '11_access_control_definition_example.dart' as acl_definition;

/// Standalone entry point for running security examples.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

/// Run all security examples.
/// Called from run_all_samples.dart or can be run standalone via main().
Future<void> run() async {
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║              Tom Security System Samples                         ║');
  print(
    '╚══════════════════════════════════════════════════════════════════╝\n',
  );

  user_principal.run();
  access_control.run();
  advanced_access.run();
  bearer_auth.run();
  ui_authorization.run();
  graded_access.run();
  resource_roles.run();
  server_principal_meet.run();
  two_factor_login.run();
  await oauth_contract.run();
  acl_definition.run();

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                    All Samples Complete!                         ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}
