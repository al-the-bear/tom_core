/// Entry point for `advanced_authadmin_client` — the administrator console for
/// the advanced Tom Core full-stack sample (steps 33–34).
///
/// Before the first frame these bootstraps run: [initializeReflection] (from
/// this app's `reflection_seed.dart`) registers the reflected drafts and the
/// user/role/group editor forms so the admin screens' `TomForm` bind/save
/// round-trips resolve (step 34); the Flutter client platform is registered via
/// `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code that
/// probes the runtime gets the Flutter implementation; and the public login
/// resource bundle is fetched through the backend seam and installed as the
/// singleton [TomTextResourceProvider], so the admin sign-in screen renders
/// server-delivered chrome rather than any hardcoded string. The console then
/// runs over an [AdminSession] wrapping the chosen [AdminBackend].
///
/// The **default** run mode is the live stack: started with no dart-defines the
/// console drives the local auth server's `/admin/*` API through a
/// [LiveAdminBackend], reading its URLs from the [AdvancedClientConfig] config
/// bean (G-ENV-2). The seeded [InMemoryAdminBackend] is a testing convenience,
/// opt-in only via `--dart-define=TEST_MODE=true` (G-ENV-3) — never a default
/// reached by forgetting a flag.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'app/admin_app.dart';
import 'backend/backend.dart';
import 'reflection_seed.dart';

Future<void> main() async {
  initializeReflection();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  AdvancedClientConfig.registerDefault();

  final session = AdminSession(_buildBackend());

  // Fetch + install the server-delivered login chrome before the first frame.
  await session.loadLoginResources();

  runApp(AdminConsoleApp(session: session));
}

/// Builds the backend the console drives: a [LiveAdminBackend] over the auth
/// server by default, or the seeded [InMemoryAdminBackend] under `TEST_MODE`.
///
/// The live wiring reads the server URLs from the [AdvancedClientConfig] config
/// bean (never `String.fromEnvironment`) and shares a single [IoJsonTransport]
/// between the [AuthClient] (login/token storage) and the [AuthorizedHttp] the
/// [AdminApiClient] sends on, so the bearer the login stores is the one every
/// `/admin/*` call presents.
AdminBackend _buildBackend() {
  const testMode = bool.fromEnvironment('TEST_MODE');
  if (testMode) return InMemoryAdminBackend();

  final config = AdvancedClientConfig.resolve();
  final transport = IoJsonTransport();
  final auth = AuthClient(Uri.parse(config.authServerUrl), transport: transport);
  final api = AdminApiClient(
      Uri.parse(config.adminServerUrl), AuthorizedHttp(transport, auth));
  return LiveAdminBackend(auth, api);
}
