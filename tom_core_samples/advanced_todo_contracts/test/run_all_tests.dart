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
///
/// Every one of the fifteen is named, and they are grouped in the order
/// `dtos.dart` exports their files. The generator does not need the list to be
/// complete — the barrel import already reaches every type — so completeness is
/// for the reader: grouped this way the `main()` is a fifteen-line inventory
/// checkable against the barrel by scanning rather than by counting, and a DTO
/// added to an existing file has one obvious place to go. Keep it that way; a
/// list that is merely *sufficient* gives a later author no way to tell whether
/// an omission is deliberate.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

void main() {
  // add_child_requests.dart
  AddCommentRequest();
  AddSubtaskRequest();
  // admin_dtos.dart
  CreateUserRequest();
  RoleDto();
  GroupDto();
  AssignmentRequest();
  // entity_id_request.dart
  EntityIdRequest();
  // file_descriptor_dto.dart
  FileDescriptorDto();
  // graded_field_dto.dart
  GradedFieldDto();
  // grant_matrix_dto.dart
  GrantMatrixDto();
  // login_dtos.dart
  LoginRequest();
  SecondFactorRequest();
  TwoFactorEnrolmentRequest();
  UserDto();
  LoginResult();
  // resource_bundle_dto.dart
  ResourceBundleDto();
  // share_request.dart
  ShareRequest();
}
