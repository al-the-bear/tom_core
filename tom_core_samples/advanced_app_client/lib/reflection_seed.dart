// Reflection entry point: the single seed file the reflection generator reads
// to decide what to emit into `reflection_seed.reflection.dart` (see build.yaml).
//
// What needs reflecting, and why: a `TomForm` is itself a `TomClass`, and
// `bind`/`save` enumerate a form's fields through kernel reflection — so both
// the @tomReflector domain entities the forms bind AND the @tomReflector forms
// themselves must be in the reflected graph. This app binds the shared
// advanced_todo_domain entities ([TodoItem] and friends) plus the client-local
// [LoginCredentials], so the seed imports all the sources.
//
// Why one seed reflects everything: the generated `initializeReflection()`
// *assigns* the reflection data (last writer wins), so exactly one seed's
// `initializeReflection()` may run per program. This file is that one seed — it
// must cover every reflected type the app touches, which is why it pulls in
// advanced_todo_domain's entities even though they live in another package.

// ignore: unused_import
import 'domain/login_credentials.dart';
// ignore: unused_import
import 'forms/login_form.dart';
// ignore: unused_import
import 'forms/todo_item_form.dart';
// ignore: unused_import
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
// The reflection-first contract DTOs the live app backend round-trips through
// the client core (LoginRequest/LoginResult/ShareRequest/GrantMatrixDto/
// ResourceBundleDto/…): they must be in this one combined seed so
// `dtoFromJson`/`dtoToJsonString` resolve at runtime.
// ignore: unused_import
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
// `tomReflector` for the contract-DTO capture anchor below.
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Re-export the client-local reflected types so they are discoverable through
// this one entry point, plus the generated output so `main.dart` and the tests
// get `initializeReflection()` from here (keeping
// `reflection_seed.reflection.dart` — do-not-edit, regenerate-only — an
// implementation detail).
export 'domain/login_credentials.dart';
export 'forms/login_form.dart';
export 'forms/todo_item_form.dart';
// advanced_todo_domain is imported (above) for generator discovery but
// intentionally NOT re-exported: its library carries its own
// `initializeReflection`, which would collide with the one this seed exports
// below. Callers import advanced_todo_domain directly for its entities.
export 'reflection_seed.reflection.dart';

// Contract-DTO capture anchor. In a Flutter package the generator's closure
// resolution partially fails (a Material/analyzer summary RangeError), so a bare
// barrel import or a `main()` that merely *constructs* the DTOs does NOT get
// them into the reflected graph — the domain entities only make it in because
// the reflected forms reference them as field/type-argument types, and the
// generator follows that type graph even through the crash. So we anchor each
// contract DTO the same way the forms anchor the domain: as a *field type* on a
// reflected holder. This holder is generator plumbing only — never constructed
// or reflected at runtime; it exists solely so the type-graph walk reaches every
// wire DTO the live app round-trips through advanced_client_core.
@tomReflector
class _ContractDtoAnchor {
  CreateUserRequest? createUserRequest;
  RoleDto? roleDto;
  GroupDto? groupDto;
  AssignmentRequest? assignmentRequest;
  LoginRequest? loginRequest;
  SecondFactorRequest? secondFactorRequest;
  TwoFactorEnrolmentRequest? twoFactorEnrolmentRequest;
  UserDto? userDto;
  LoginResult? loginResult;
  ShareRequest? shareRequest;
  GrantMatrixDto? grantMatrixDto;
  ResourceBundleDto? resourceBundleDto;
}

// The reflection generator treats this file as a runnable program and requires a
// `main`. It is never executed by the app (the entry point is `main.dart`). The
// bare type reference marks the capture anchor as "used" without constructing or
// reflecting it.
void main() {
  _ContractDtoAnchor;
}
