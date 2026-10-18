// CE-CL — the client-application descriptor root.
//
// The smallest of the eight gap classes, and the one whose shape is entirely
// in its defaults: every field is optional, so a headless client and a
// full-screen one are the same call with different arguments. That is the
// point worth seeing — there is no second constructor and no "minimal" mode.
//
// Run with:
//   dart run --enable-asserts example/client_application_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

void main() {
  requireAsserts();
  print('== CE-CL: client application ==');

  // A screen-bearing client names its platforms, its entry route and the
  // screens it carries.
  final adminConsole = TomClientApplication(
    clientId: 'admin_console',
    displayName: 'Admin Console',
    platforms: ['web', 'macos'],
    entryRoute: 'dashboard',
    screenIds: ['dashboard', 'userList'],
    serverBaseUrl: 'https://api.example.com',
  );

  print(
    '  ${adminConsole.clientId}: ${adminConsole.screenIds.length} screens '
    'on ${adminConsole.platforms.join(", ")}, entry '
    '"${adminConsole.entryRoute}"',
  );
  assert(adminConsole.screenIds.length == 2);
  assert(adminConsole.entryRoute == 'dashboard');

  // A headless client is the same call with the screen fields left out. The
  // empty list is the answer rather than a null a caller has to test for,
  // which is why every collection field defaults to an empty one.
  final importer = TomClientApplication(clientId: 'importer');

  print(
    '  ${importer.clientId}: ${importer.screenIds.length} screens, '
    'entry "${importer.entryRoute}"',
  );
  assert(importer.screenIds.isEmpty);
  assert(importer.platforms.isEmpty);
  assert(importer.entryRoute == '');
  assert(importer.serverBaseUrl == '');

  print('  every field optional; absence is an empty collection, never null');
}
