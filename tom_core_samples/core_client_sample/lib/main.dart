/// Entry point for `core_client_sample` — the Tom Core Flutter todo client.
///
/// Three things must happen before the first frame:
///
///  1. [initializeReflection] — the forms bind reflected `@tomReflector`
///     entities ([TodoItem], [User], [LoginCredentials]); their field metadata
///     comes from the generated `reflection_seed.reflection.dart`, so reflection
///     must be registered before any form is constructed.
///  2. The client platform is registered via
///     `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code
///     that probes the runtime gets the Flutter implementation.
///  3. An (empty) application resource provider is installed so any widget that
///     probes the singleton finds a valid scope. The app resolves its labels
///     through `labelTextOverride`, so no resource file is required.
///
/// The app runs against the in-memory backend by default ([InMemoryTodoApi]);
/// pass `--dart-define=LIVE_SERVER_URL=http://localhost:8080` to enable the
/// "refresh from live server" read path against a running `core_server_sample`.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'api/in_memory_todo_api.dart';
import 'api/live_todo_read_client.dart';
import 'app/app_session.dart';
import 'app/todo_app.dart';
import 'reflection_seed.dart';

void main() {
  initializeReflection();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );

  const liveUrl = String.fromEnvironment('LIVE_SERVER_URL');
  final liveClient = liveUrl.isEmpty ? null : LiveTodoReadClient(liveUrl);

  runApp(
    TodoApp(
      session: AppSession(InMemoryTodoApi()),
      liveClient: liveClient,
    ),
  );
}
