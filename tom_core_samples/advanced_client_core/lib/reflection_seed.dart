// Reflection entry point for the client core's OWN tests.
//
// The client core's typed parsers round-trip two families of reflected types
// through the kernel reflection path:
//
//   * the shared advanced_todo_domain entities (Workspace/Project/TodoList/
//     TodoItem/TodoComment) the app-API parsers build, and
//   * the reflection-first contract DTOs (LoginRequest/LoginResult/UserDto/
//     RoleDto/GroupDto/GrantMatrixDto/ShareRequest/GradedFieldDto/…) the
//     `dtoFromJson`/`dtoToJsonString` helpers serialize.
//
// The generated `initializeReflection()` *assigns* the reflection registry
// (last writer wins), so exactly one seed may run per program — and it must
// cover BOTH families. Neither advanced_todo_domain's own seed nor
// advanced_todo_contracts' own seed covers the other, so this file is the one
// combined seed the client-core tests install (the Flutter apps build their own
// combined seed that additionally covers their forms).
//
// This seed is intentionally NOT re-exported from `advanced_client_core.dart`:
// the Flutter apps that consume the client core install their own
// `initializeReflection`, so exporting this one from the public barrel would
// collide with theirs. The client-core tests import this file directly.

// ignore: unused_import
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
// ignore: unused_import
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

// Re-export only the generated combined `initializeReflection()`. The two source
// barrels are imported (above) for generator discovery but intentionally NOT
// re-exported: each carries its own `initializeReflection`, which would collide
// with the combined one this seed exports.
export 'reflection_seed.reflection.dart' show initializeReflection;

// The reflection generator treats this file as a runnable program and requires a
// `main`. It is never executed; this stub satisfies that generator contract.
void main() {}
