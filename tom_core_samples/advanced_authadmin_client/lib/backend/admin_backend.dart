/// The backend contract the admin console talks to, independent of transport.
///
/// Every screen under `lib/screens/` is written against this seam, not a
/// concrete backend, so the same widgets drive either the seeded
/// [InMemoryAdminBackend]
/// (the offline teaching default — and what the widget tests bind, never
/// touching a socket) or the [LiveAdminBackend], which delegates to
/// `advanced_client_core` over HTTP. Keeping the seam here is what makes the
/// admin widget tests deterministic.
///
/// The seam carries all sixteen [AdminApiService] operations — the
/// Users/Roles/Groups CRUD, the grant matrix, assignments and the admin
/// resource bundle — and adds six members that API does not own. Four are the
/// **session** ([AdminBackend.login], [AdminBackend.submitSecondFactor],
/// [AdminBackend.pendingChallenge], [AdminBackend.logout]),
/// one is the **pre-sign-in bundle** ([AdminBackend.loginResources]) the login
/// screen needs
/// before any token exists, and one is the **byte transport**
/// ([AdminBackend.files]) the
/// avatar slot needs. All but [AdminBackend.pendingChallenge] and
/// [AdminBackend.files] are
/// `AuthApiService` members that the live wiring routes through `AuthClient`,
/// so what this seam genuinely invents is one piece of challenge state and one
/// second seam for bytes.
///
/// Nor is the carry signature-for-signature, deliberately. The wire contract
/// addresses a row from the payload — `updateUser(UserDto)` carries the id in
/// the DTO it is already sending, and `deleteUser(EntityIdRequest)` in a DTO
/// that exists for nothing else — while a UI seam should not make a screen
/// build a request object to delete a row, so here the id is a leading
/// parameter. [LiveAdminBackend] is the one place the two shapes meet.
///
/// Every administrative operation requires the `admin` role: each `/admin/*`
/// endpoint's contract declares `TomRoleAccess(['admin'])`
/// (`TomApiEndpoint.access`) and the live server's pipeline enforces it, and
/// the in-memory fake mirrors that gate so a non-admin principal is refused
/// identically either way.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Raised when an admin-backend call fails — rejected credentials, a missing
/// session, a non-admin caller, or an unknown row.
///
/// A single typed failure the screens catch and surface: the in-memory backend
/// throws it directly, and [LiveAdminBackend] wraps the client core's transport
/// exceptions (`AuthClientException`/`AdminApiException`/`TomAuthExpiredException`)
/// in it. It carries a human [message] to show the user and, when the underlying
/// failure had one, the server's stable error [key] so a caller can branch
/// without parsing the message.
///
/// The console branches on exactly two: `admin.no_session` and
/// `auth.session_expired`, which together mean "re-authenticate". Every other
/// key is surfaced rather than matched — `admin.access.forbidden` among them,
/// because a forbidden operation is not a lost session, and because the
/// non-admin sign-in is already rejected by the admin probe failing at all
/// rather than by the key it carried.
class AdminBackendException implements Exception {
  /// What went wrong, fit to show the user.
  final String message;

  /// The server's stable error key when one was available (e.g.
  /// `auth.login.failed`, `admin.access.forbidden`), else null.
  final String? key;

  /// Whether a refused [AdminBackend.submitSecondFactor] may simply be tried
  /// again with a new code.
  ///
  /// Carries `AuthClientException.canRetrySecondFactor` across the seam — the
  /// only signal separating "wrong code, try again" from "the challenge is
  /// spent, start over", which are different screens.
  final bool canRetrySecondFactor;

  /// Creates the exception with a human [message] and an optional stable [key].
  const AdminBackendException(
    this.message, {
    this.key,
    this.canRetrySecondFactor = false,
  });

  @override
  String toString() =>
      'AdminBackendException: $message${key == null ? '' : ' ($key)'}';
}

/// The admin-console backend the authadmin client reads and edits against.
///
/// Authenticates an administrator, then administers the auth database: accounts,
/// roles, groups (with membership), the `(role, fieldResourceKey) → TomAuthState`
/// grant matrix, and role/group assignments. The live implementation enforces the
/// `admin`-role gate server-side; the in-memory fake mirrors the same gate so the
/// console behaves identically either way.
abstract class AdminBackend {
  /// Authenticates [request], stores the session, and returns the resolved
  /// principal + token pair. Throws [AdminBackendException] when rejected.
  ///
  /// Login itself does not require the `admin` role (it is the public auth
  /// endpoint); the role gate is enforced on every administrative call below, so
  /// a signed-in non-admin is refused the moment they touch admin data. The
  /// admin shell's `AdminSession.login` uses that to reject a non-admin at the
  /// login screen.
  ///
  /// A [LoginResult] with `requires2FA` set is **not** a session: the stored
  /// token is an interim challenge carrier, so the shell's `admin` probe must
  /// wait until [submitSecondFactor] completes the login.
  Future<LoginResult> login(LoginRequest request);

  /// Completes a two-pass login by submitting the one-time [code], returning
  /// exactly the pair a 2FA-free [login] would have produced.
  ///
  /// Throws [AdminBackendException] when the code is refused;
  /// [AdminBackendException.canRetrySecondFactor] says whether the challenge
  /// survived. The sample seeds no 2FA-enrolled administrator — but an
  /// enrolment is an *account* property the console does not control, so
  /// handling it is what keeps the console usable the day someone enrols
  /// `admin`.
  Future<LoginResult> submitSecondFactor(String code);

  /// The challenge a [login] left pending, or null when none is outstanding —
  /// mechanism, attempts remaining, expiry, and the `clientData['digits']` the
  /// code field sizes itself from.
  Tom2FAChallenge? get pendingChallenge;

  /// Ends the session and discards the stored token pair — including a
  /// half-finished two-factor login.
  Future<void> logout();

  /// Fetches the public login resource bundle (screen texts) the admin console
  /// installs before the sign-in screen builds. Reachable unauthenticated.
  Future<ResourceBundleDto> loginResources();

  /// Fetches the authenticated full resource bundle (every console screen's
  /// texts) the console installs right after an admin sign-in, so the user,
  /// role, group, and grant screens render server-delivered strings. Requires an
  /// `admin` session (the `/admin/resources` endpoint is role-gated).
  Future<ResourceBundleDto> resources();

  // ----- Users -------------------------------------------------------------

  /// All accounts (`GET /admin/users`).
  Future<List<UserDto>> listUsers();

  /// Creates an account from [request] (`POST /admin/users`), returning the
  /// password-free projection with its assigned id.
  Future<UserDto> createUser(CreateUserRequest request);

  /// Updates the mutable profile/status of the account [id]
  /// (`PUT /admin/users`, which addresses the account by `UserDto.id`); the
  /// password is never changed here.
  Future<UserDto> updateUser(String id, UserDto user);

  /// Removes the account [id] (`DELETE /admin/users/{id}`).
  Future<void> deleteUser(String id);

  // ----- Roles -------------------------------------------------------------

  /// All roles (`GET /admin/roles`).
  Future<List<RoleDto>> listRoles();

  /// Creates a role (`POST /admin/roles`).
  Future<RoleDto> createRole(RoleDto role);

  /// Updates the role with [key] (`PUT /admin/roles`, addressed by
  /// `RoleDto.key`).
  Future<RoleDto> updateRole(String key, RoleDto role);

  /// Removes the role with [key] (`DELETE /admin/roles/{key}`).
  Future<void> deleteRole(String key);

  // ----- Groups ------------------------------------------------------------

  /// All groups with their membership (`GET /admin/groups`).
  Future<List<GroupDto>> listGroups();

  /// Creates a group (`POST /admin/groups`).
  Future<GroupDto> createGroup(GroupDto group);

  /// Updates the name + membership of the group [id] (`PUT /admin/groups`,
  /// addressed by `GroupDto.id`).
  Future<GroupDto> updateGroup(String id, GroupDto group);

  /// Removes the group [id] (`DELETE /admin/groups/{id}`).
  Future<void> deleteGroup(String id);

  // ----- Grants + assignments ----------------------------------------------

  /// The full `(role, fieldResourceKey) → TomAuthState` matrix (`GET
  /// /admin/grants`).
  Future<GrantMatrixDto> getGrants();

  /// Replaces the grant matrix (`PUT /admin/grants`).
  Future<void> putGrants(GrantMatrixDto matrix);

  /// Assigns a role and/or group to a user (`POST /admin/assignments`).
  Future<void> assign(AssignmentRequest request);

  // ----- Files -------------------------------------------------------------

  /// The console's byte transport — how a user's avatar is uploaded, described,
  /// downloaded and removed.
  ///
  /// A **second seam beside the JSON one**, not a set of methods on it. Bytes do
  /// not travel as JSON: a payload worth storing is a payload not worth holding
  /// in memory, so files move over the framework file endpoint through
  /// [TomFileTransferClient], which streams in both directions. Proxying every
  /// transfer through a `Future<List<int>>` on this interface would undo exactly
  /// that.
  ///
  /// Avatars live at [AppFileSlots.userAvatar] on the **auth** server, whose
  /// `auth_users.avatar_ref` column is an exposed `@TomFileReference`. There is
  /// no batch descriptor call as there is for the board's attachments: the
  /// console edits one account at a time, so a single `HEAD`
  /// ([TomFileTransferClient.describe]) on open is the whole read path.
  TomFileTransferClient get files;
}
