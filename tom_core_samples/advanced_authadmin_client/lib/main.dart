/// Entry point for `advanced_authadmin_client` — the administrator console for
/// the advanced Tom Core full-stack sample (step 33).
///
/// Before the first frame the Flutter client platform is registered via
/// `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code that
/// probes the runtime gets the Flutter implementation, and an empty application
/// resource provider is installed so any widget that probes the singleton finds
/// a valid scope. The console then runs over an [AdminSession] wrapping the
/// chosen [AdminBackend].
///
/// Reflection bootstrap (`initializeReflection`) is intentionally *not* wired
/// yet: step 33's login + shell are reflection-free. It arrives in step 34, when
/// the user/role/group editor forms bind reflected DTOs through
/// `lib/reflection_seed.dart`.
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

void main() {
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );

  runApp(AdminConsoleApp(session: AdminSession(_buildBackend())));
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
