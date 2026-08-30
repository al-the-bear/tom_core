/// The client-local reflected entities the admin editor forms bind.
///
/// The wire DTOs (`UserDto`/`RoleDto`/`GroupDto`/…) in `advanced_todo_contracts`
/// are reflection-first value records: `@tomReflector` classes with plain
/// non-`final` fields, which is what the JSON round-trip needs but *not* what a
/// bound `TomForm` needs — that requires a [TomClass] whose members are
/// observables. So each editor gets a small client-local *draft* instead —
/// exactly the `LoginCredentials` pattern the app client uses. The screens fold a
/// draft into the matching wire DTO on save and hydrate it from a DTO on edit.
///
/// Drafts carry only the fields an admin edits: a user's profile + status (its
/// id is server-assigned and its password is set only at creation); a role's
/// key + name; a group's name (membership is edited as a checklist, not a scalar
/// field, so it is not a draft field). Like every reflected type they are
/// `@tomReflector` and seeded through `reflection_seed.dart`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A user account draft: profile, status and (on creation) a password.
@tomReflector
class UserDraft extends TomClass {
  /// Login name. A stable key once created (the editor renders it read-only on
  /// edit), so it is set only when creating an account.
  late final username = TomString('');

  /// Initial password — folded into `CreateUserRequest` on creation only; never
  /// shown or sent on edit (the seam has no password-change operation).
  late final password = TomString('');

  /// Human-facing name.
  late final displayName = TomString('');

  /// Contact email.
  late final email = TomString('');

  /// Account lifecycle as a wire status token (`active`/`suspended`); edited via
  /// a dropdown so the console stays domain-agnostic (no `UserStatus` import).
  late final status = TomString('active');
}

/// A role draft: a stable key plus a human-facing name.
@tomReflector
class RoleDraft extends TomClass {
  /// Stable role key (e.g. `auditor`); rendered read-only when editing.
  late final key = TomString('');

  /// Human-facing role name.
  late final name = TomString('');
}

/// A group draft: the human-facing name (membership is edited separately).
@tomReflector
class GroupDraft extends TomClass {
  /// Human-facing group name.
  late final name = TomString('');
}
