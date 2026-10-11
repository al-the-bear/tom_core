/// One authenticated call through the client core: resolve the config, log in
/// through [AuthClient], and list the caller's workspaces through
/// [AppApiClient].
///
/// This is the path both Flutter clients take on every screen, reduced to the
/// three steps that make it up:
///
/// 1. **Config.** [AdvancedClientConfig.registerDefault] seeds the
///    local-development URLs as a kernel bean, and
///    [AdvancedClientConfig.resolve] reads them back — the clients never read a
///    URL anywhere else.
/// 2. **Login.** [AuthClient.login] exchanges credentials for the token pair
///    and stores it in the kernel's `TomBearerAuthentication`.
/// 3. **The call.** [AppApiClient] sends through [AuthorizedHttp], which
///    attaches the stored bearer and, on a `401`, refreshes it once and retries —
///    so the call site never handles a token.
///
/// ## Running it
///
/// It needs the running stack: the auth server on `:8081` and the app server on
/// `:8080`, with their databases. `tool/run_cross_tier_integration.sh` boots all
/// four; the packages' own READMEs start them one at a time. Then, from this
/// package:
///
/// ```sh
/// dart run example/authenticated_call_example.dart
/// ```
///
/// With nothing listening it says which servers it needs and exits with
/// status 2 rather than printing a socket stack trace.
///
/// The work is in [listWorkspacesAs], which takes the transport as a parameter:
/// `main` hands it the real [HttpJsonTransport], and
/// `test/examples_test.dart` hands it a fake one, so the sequence this example
/// teaches is exercised by the suite without a server.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
// The client core's own reflection seed. It is not exported from the barrel
// (see the note there): a program installs exactly one seed, and a standalone
// program like this one installs this one.
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> main() async {
  initializeReflection();
  final config = AdvancedClientConfig.registerDefault();

  final transport = HttpJsonTransport();
  try {
    final names = await listWorkspacesAs(
      config,
      transport,
      username: 'alice',
      password: 'alice-pass',
    );
    stdout.writeln('alice sees ${names.length} workspace(s):');
    for (final name in names) {
      stdout.writeln('  - $name');
    }
  } on SocketException catch (e) {
    stderr.writeln(
      'No server answered (${e.message}). Start advanced_auth_server on '
      '${config.authServerUrl} and advanced_app_server on '
      '${config.appServerUrl} first — tool/run_cross_tier_integration.sh '
      'boots both with their databases.',
    );
    exitCode = 2;
  } finally {
    transport.close();
  }
}

/// Logs in as [username] against [config]'s auth server and returns the names
/// of the workspaces the app server shows that user.
///
/// One [transport] is shared by the [AuthClient] and the [AppApiClient], which
/// is how the clients wire it at runtime.
Future<List<String>> listWorkspacesAs(
  AdvancedClientConfig config,
  JsonTransport transport, {
  required String username,
  required String password,
}) async {
  TomBearerAuthentication.bearerAuthentication = TomBearerAuthentication();

  final auth = AuthClient(
    Uri.parse(config.authServerUrl),
    transport: transport,
  );
  final api = AppApiClient(
    Uri.parse(config.appServerUrl),
    AuthorizedHttp(transport, auth),
  );

  await auth.login(LoginRequest(username: username, password: password));
  final workspaces = await api.listWorkspaces();
  return [for (final workspace in workspaces) workspace.name.get()];
}
