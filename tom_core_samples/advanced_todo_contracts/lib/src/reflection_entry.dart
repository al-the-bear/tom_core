/// Reflection root for `advanced_todo_contracts`.
///
/// The reflection generator is seeded from this file (see `build.yaml`): it
/// treats the file as a runnable program, follows the imports, and emits
/// `reflection_entry.reflection.dart` capturing every `@tomReflector` wire DTO.
///
/// The generated `initializeReflection()` is **not** re-exported from the
/// package barrel: the servers and Flutter clients each build their *own*
/// combined seed (domain entities + these DTOs) and run that single
/// `initializeReflection()` — re-exporting a second one here would collide with
/// theirs. The one consumer that installs *this* seed directly is the contract
/// round-trip test, which imports `reflection_entry.reflection.dart` to reflect
/// the DTOs in isolation. This file is never executed in production.
library;

import 'admin_dtos.dart';
import 'graded_field_dto.dart';
import 'grant_matrix_dto.dart';
import 'login_dtos.dart';
import 'resource_bundle_dto.dart';
import 'share_request.dart';

/// Touches each reflected DTO so the imports are retained and the generator can
/// reach every wire type. Never invoked in production.
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
