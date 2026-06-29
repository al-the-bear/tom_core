/// The backend contract the admin console talks to, independent of transport
/// (step 32).
///
/// Every admin screen (steps 33–36) is written against this seam, not a concrete
/// backend, so the same widgets drive either the seeded [InMemoryAdminBackend]
/// (the offline teaching default — and what the widget tests bind, never
/// touching a socket) or the [LiveAdminBackend], which delegates to
/// `advanced_client_core` over HTTP. Keeping the seam here is what makes the
/// admin widget tests deterministic.
///
/// The seam mirrors [AdminApiService] one-to-one — the Users/Roles/Groups CRUD,
/// the grant matrix, and assignments — plus the two **session** operations
/// ([login]/[logout]) the admin API client does not own (the live wiring routes
/// those through `AuthClient`). Every administrative operation requires the
/// `admin` role: the live server gates each `/admin/*` endpoint with
/// `@TomRoleAccess(['admin'])`, and the in-memory fake mirrors that gate so a
/// non-admin principal is refused identically either way.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

/// Raised when an admin-backend call fails — rejected credentials, a missing
/// session, a non-admin caller, or an unknown row.
///
/// A single typed failure the screens catch and surface: the in-memory backend
/// throws it directly, and [LiveAdminBackend] wraps the client core's transport
/// exceptions (`AuthClientException`/`AdminApiException`/`AuthorizedHttpException`)
/// in it. It carries a human [message] to show the user and, when the underlying
/// failure had one, the server's stable error [key] so a caller can branch
/// without parsing the message (e.g. the shell rejects a non-admin login by
/// keying on `admin.access.forbidden`).
class AdminBackendException implements Exception {
  /// What went wrong, fit to show the user.
  final String message;

  /// The server's stable error key when one was available (e.g.
  /// `auth.login.failed`, `admin.access.forbidden`), else null.
  final String? key;

  /// Creates the exception with a human [message] and an optional stable [key].
  const AdminBackendException(this.message, {this.key});

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
  /// admin shell (step 33) uses that to reject a non-admin at the login screen.
  Future<LoginResult> login(LoginRequest request);

  /// Ends the session and discards the stored token pair.
  Future<void> logout();

  /// Fetches the public login resource bundle (screen texts) the admin console
  /// installs before the sign-in screen builds. Reachable unauthenticated.
  Future<ResourceBundleDto> loginResources();

  // ----- Users -------------------------------------------------------------

  /// All accounts (`GET /admin/users`).
  Future<List<UserDto>> listUsers();

  /// Creates an account from [request] (`POST /admin/users`), returning the
  /// password-free projection with its assigned id.
  Future<UserDto> createUser(CreateUserRequest request);

  /// Updates the mutable profile/status of the account [id] (`PUT
  /// /admin/users/{id}`); the password is never changed here.
  Future<UserDto> updateUser(String id, UserDto user);

  /// Removes the account [id] (`DELETE /admin/users/{id}`).
  Future<void> deleteUser(String id);

  // ----- Roles -------------------------------------------------------------

  /// All roles (`GET /admin/roles`).
  Future<List<RoleDto>> listRoles();

  /// Creates a role (`POST /admin/roles`).
  Future<RoleDto> createRole(RoleDto role);

  /// Updates the role with [key] (`PUT /admin/roles/{key}`).
  Future<RoleDto> updateRole(String key, RoleDto role);

  /// Removes the role with [key] (`DELETE /admin/roles/{key}`).
  Future<void> deleteRole(String key);

  // ----- Groups ------------------------------------------------------------

  /// All groups with their membership (`GET /admin/groups`).
  Future<List<GroupDto>> listGroups();

  /// Creates a group (`POST /admin/groups`).
  Future<GroupDto> createGroup(GroupDto group);

  /// Updates the name + membership of the group [id] (`PUT /admin/groups/{id}`).
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
}
