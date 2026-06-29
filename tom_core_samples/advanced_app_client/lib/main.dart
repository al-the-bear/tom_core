/// Entry point for `advanced_app_client` — the end-user task board for the
/// advanced Tom Core full-stack sample (step 27).
///
/// Four things happen before the first frame:
///
///  1. [initializeReflection] (from this app's `reflection_seed.dart`) registers
///     the reflected `@tomReflector` entities the backend constructs and the
///     forms bind — the shared `advanced_todo_domain` entities plus the
///     client-local `LoginCredentials`/`LoginForm`, all captured by the one
///     generated seed. It must run before any reflected type is built (the
///     in-memory backend seeds its tree in its constructor), so it comes first.
///  2. The Flutter client platform is registered via
///     `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code
///     that probes the runtime gets the Flutter implementation.
///  3. An (empty) application resource provider is installed so any widget that
///     probes the singleton finds a valid scope.
///  4. The app runs over an [AppSession] wrapping the chosen [AppBackend].
///
/// The app runs against the seeded [InMemoryAppBackend] by default. Pass both
/// `--dart-define=AUTH_SERVER_URL=http://localhost:8081` and
/// `--dart-define=APP_SERVER_URL=http://localhost:8080` to drive the live stack
/// (`advanced_auth_server` + `advanced_app_server`) through a [LiveAppBackend].
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'app/app.dart';
import 'backend/backend.dart';
import 'reflection_seed.dart';

void main() {
  initializeReflection();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );

  runApp(AdvancedTodoApp(session: AppSession(_buildBackend())));
}

/// Builds the backend the app drives: the seeded in-memory fake by default, or
/// a [LiveAppBackend] over the auth + app servers when both URLs are supplied.
///
/// The live wiring shares a single [IoJsonTransport] between the [AuthClient]
/// (login/token storage) and the [AuthorizedHttp] the [AppApiClient] sends on,
/// so the bearer the login stores is the one every board call presents.
AppBackend _buildBackend() {
  const authUrl = String.fromEnvironment('AUTH_SERVER_URL');
  const appUrl = String.fromEnvironment('APP_SERVER_URL');
  if (authUrl.isEmpty || appUrl.isEmpty) return InMemoryAppBackend();

  final transport = IoJsonTransport();
  final auth = AuthClient(Uri.parse(authUrl), transport: transport);
  final api = AppApiClient(Uri.parse(appUrl), AuthorizedHttp(transport, auth));
  return LiveAppBackend(auth, api);
}
