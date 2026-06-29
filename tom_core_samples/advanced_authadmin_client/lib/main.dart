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
/// The console runs against the seeded [InMemoryAdminBackend] by default. Pass
/// both `--dart-define=AUTH_SERVER_URL=http://localhost:8081` and
/// `--dart-define=ADMIN_SERVER_URL=http://localhost:8081` to drive the live auth
/// server's `/admin/*` API through a [LiveAdminBackend].
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

  final session = AdminSession(_buildBackend());

  // Fetch + install the server-delivered login chrome before the first frame.
  await session.loadLoginResources();

  runApp(AdminConsoleApp(session: session));
}

/// Builds the backend the console drives: the seeded in-memory fake by default,
/// or a [LiveAdminBackend] over the auth server when both URLs are supplied.
///
/// The live wiring shares a single [IoJsonTransport] between the [AuthClient]
/// (login/token storage) and the [AuthorizedHttp] the [AdminApiClient] sends on,
/// so the bearer the login stores is the one every `/admin/*` call presents.
AdminBackend _buildBackend() {
  const authUrl = String.fromEnvironment('AUTH_SERVER_URL');
  const adminUrl = String.fromEnvironment('ADMIN_SERVER_URL');
  if (authUrl.isEmpty || adminUrl.isEmpty) return InMemoryAdminBackend();

  final transport = IoJsonTransport();
  final auth = AuthClient(Uri.parse(authUrl), transport: transport);
  final api = AdminApiClient(Uri.parse(adminUrl), AuthorizedHttp(transport, auth));
  return LiveAdminBackend(auth, api);
}
