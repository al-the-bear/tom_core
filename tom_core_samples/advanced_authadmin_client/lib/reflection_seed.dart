/// Reflection seed for `advanced_authadmin_client` — the single entry point the
/// reflection generator reads to decide what to emit into
/// `reflection_seed.reflection.dart` (see `build.yaml`).
///
/// What needs reflecting, and why: a `TomForm` is itself a `TomClass`, and
/// `bind`/`save` enumerate a form's fields through kernel reflection — so both
/// the `@tomReflector` entities the forms bind AND the `@tomReflector` forms
/// themselves must be in the reflected graph. The admin console binds
/// *client-local* reflected drafts ([UserDraft]/[RoleDraft]/[GroupDraft]) in its
/// forms, and round-trips the reflection-first wire DTOs
/// ([UserDto]/[RoleDto]/[GroupDto]/[GrantMatrixDto]/…) through the client core —
/// so the seed pulls in the drafts, the three forms over them, AND the contract
/// DTOs.
///
/// Why one seed reflects everything: the generated `initializeReflection()`
/// *assigns* the reflection data (last writer wins), so exactly one seed's
/// `initializeReflection()` may run per program. This file is that one seed.
library;

// ignore: unused_import
import 'domain/admin_drafts.dart';
// ignore: unused_import
import 'domain/admin_login_credentials.dart';
// ignore: unused_import
import 'forms/admin_login_form.dart';
// ignore: unused_import
import 'forms/user_form.dart';
// ignore: unused_import
import 'forms/role_form.dart';
// ignore: unused_import
import 'forms/group_form.dart';
// The reflection-first contract DTOs the live admin backend round-trips through
// the client core: they must be in this one combined seed so
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
export 'domain/admin_drafts.dart';
export 'domain/admin_login_credentials.dart';
export 'forms/admin_login_form.dart';
export 'forms/user_form.dart';
export 'forms/role_form.dart';
export 'forms/group_form.dart';
export 'reflection_seed.reflection.dart';

// Contract-DTO capture anchor. In a Flutter package the generator's closure
// resolution partially fails (a Material/analyzer summary RangeError under the
// cached-summary path), so a bare barrel import or a `main()` that merely
// *constructs* the DTOs does NOT get them into the reflected graph — the
// client-local drafts only make it in because the reflected forms reference them
// as type-argument types, and the generator follows that type graph. So we
// anchor each contract DTO the same way the forms anchor the drafts: as a
// *field type* on a reflected holder. This holder is generator plumbing only —
// never constructed or reflected at runtime; it exists solely so the type-graph
// walk reaches every wire DTO the admin console round-trips through
// advanced_client_core. (Regenerate with `--no-cache`; see reflection_generation.sh.)
@tomReflector
class _ContractDtoAnchor {
  CreateUserRequest? createUserRequest;
  RoleDto? roleDto;
  GroupDto? groupDto;
  AssignmentRequest? assignmentRequest;
  LoginRequest? loginRequest;
  UserDto? userDto;
  LoginResult? loginResult;
  ShareRequest? shareRequest;
  GrantMatrixDto? grantMatrixDto;
  ResourceBundleDto? resourceBundleDto;
  GradedFieldDto? gradedFieldDto;
}

// The reflection generator treats this file as a runnable program and requires a
// `main`. It is never executed by the app (the entry point is `main.dart`). The
// bare type reference marks the capture anchor as "used" without constructing or
// reflecting it.
void main() {
  _ContractDtoAnchor;
}
