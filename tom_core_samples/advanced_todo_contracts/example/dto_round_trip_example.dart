/// A wire DTO off the server and back, with no hand-written serializer.
///
/// The DTOs in this package are plain reflected classes. A server writes one
/// with [dtoToJsonString]; a client rebuilds it with [dtoFromJson]. Both go
/// through the kernel's reflection path, so the one thing a program must do
/// first is install a reflection seed that covers the DTOs.
///
/// This example reuses the seed the package already generates for its tests,
/// `test/run_all_tests.reflection.dart` (rooted at `test/run_all_tests.dart`,
/// which constructs every DTO once). A consumer installs its own combined seed
/// instead — the client core does, covering its forms as well — because a
/// program runs exactly one.
///
/// The value shown is the half-finished login: a [LoginResult] asking for a
/// second factor. Note what the JSON carries and what `toString` does not: the
/// tokens are on the wire, and never in a log line.
///
/// ## Running it
///
/// No infrastructure:
///
/// ```sh
/// dart run example/dto_round_trip_example.dart
/// ```
library;

import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

import '../test/run_all_tests.reflection.dart';

void main() {
  initializeReflection();

  final sent = LoginResult(
    user: UserDto(id: '4', username: 'dave', displayName: 'Dave'),
    authToken: 'interim-auth',
    authzToken: 'interim-authz',
    expiresAt: DateTime.utc(2026, 6, 28, 12, 5),
    requires2FA: true,
    twoFactorType: 'totp',
  );

  // What the server writes.
  final json = dtoToJsonString(sent);
  stdout.writeln('wire:     $json');

  // What the client rebuilds.
  final received = dtoFromJson<LoginResult>(
    dtoToMap(sent), // or: jsonDecode(json) as Map<String, Object?>
  );
  stdout
    ..writeln('restored: $received')
    ..writeln(
      'second factor pending: ${received.requires2FA} '
      '(${received.twoFactorType}), expires ${received.expiresAt.toUtc()}',
    );
}
