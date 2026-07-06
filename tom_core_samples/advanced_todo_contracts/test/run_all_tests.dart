/// Reflection seed root for the `advanced_todo_contracts` **tests** (G-REFL-2).
///
/// The contracts package is a library — it carries no runtime `main()`, so it
/// ships no reflection seed in `lib/`. Reflection is needed only to run this
/// package's own round-trip tests, so the single seed lives here in `test/`:
/// the reflection generator treats this file as its root (see `build.yaml`),
/// follows the import graph from `main()`, and emits
/// `run_all_tests.reflection.dart` next to it. The contract round-trip test
/// installs that one seed via `setUpAll(initializeReflection)`.
///
/// The `main()` merely *touches* each reflected wire DTO so the imports are
/// retained and the generator can reach every type; it is never run as a
/// program.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

void main() {
  CreateUserRequest();
  RoleDto();
  GroupDto();
  AssignmentRequest();
  LoginRequest();
  UserDto();
  LoginResult();
  ShareRequest();
  GrantMatrixDto();
  ResourceBundleDto();
  GradedFieldDto();
}
