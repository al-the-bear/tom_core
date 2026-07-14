/// The typed service interfaces — the implementation seam shared by the servers
/// (which implement them against persistence) and the client core (which
/// implements them over HTTP, and with an in-memory fake for widget tests).
///
/// These are plain abstract Dart classes, not server-framework annotated types:
/// the contracts package depends only on `tom_core_kernel` + the domain model so
/// it can also be consumed by the Flutter-free client core. The wire details for
/// each method — URI, HTTP method, and the four-state access level declared on
/// the endpoint (`TomApiEndpoint.access`) — live next to the registry in
/// `api_registry.dart` (`authApi`/`adminApi`/`appApi`); each method's dartdoc
/// names the endpoint id that ties the two together.
///
/// Methods return the reflected domain entities (the app's working currency,
/// projected to/from JSON at the transport boundary) and the step-4 DTOs.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'admin_dtos.dart';
import 'entity_id_request.dart';
import 'grant_matrix_dto.dart';
import 'login_dtos.dart';
import 'resource_bundle_dto.dart';
import 'share_request.dart';

/// Authentication surface of the auth server (`/auth/*`).
///
/// `login` is the only public endpoint; the rest require a valid token.
abstract class AuthApiService {
  /// `authLogin` — `POST /auth/login` (public). Exchanges credentials for the
  /// signed token pair and the resolved principal.
  Future<LoginResult> login(LoginRequest request);

  /// `authLoginResources` — `GET /auth/resources/login` (public). The small,
  /// genuinely-public set of login-screen texts (`login.*` / `adminLogin.*`
  /// keys) a client installs *before* anyone signs in, so the login form needs
  /// no bundled UI strings (D-A9: a public login-resources endpoint, chosen over
  /// guest login).
  Future<ResourceBundleDto> loginResources();

  /// `authRefresh` — `POST /auth/refresh` (authenticated). Issues a fresh token
  /// pair for the still-valid caller.
  Future<LoginResult> refresh();

  /// `authLogout` — `POST /auth/logout` (authenticated). Invalidates the
  /// caller's cached principal.
  Future<void> logout();

  /// `authMe` — `GET /auth/me` (authenticated). Echoes the resolved principal.
  Future<UserDto> me();
}

/// Administration surface of the auth server (`/admin/*`).
///
/// Every method requires the `admin` role; all mutate the auth database
/// (accounts, roles, groups, the grant matrix, assignments).
abstract class AdminApiService {
  /// `adminListUsers` — `GET /admin/users`.
  Future<List<UserDto>> listUsers();

  /// `adminCreateUser` — `POST /admin/users`. The one place a plaintext
  /// password crosses the wire.
  Future<UserDto> createUser(CreateUserRequest request);

  /// `adminUpdateUser` — `PUT /admin/users/{id}`. [user] carries the mutable
  /// profile/status fields (no password); its `id` is the addressed account
  /// (the `{id}` path capture binds onto `UserDto.id` via `urlParameterMapping`).
  Future<UserDto> updateUser(UserDto user);

  /// `adminDeleteUser` — `DELETE /admin/users/{id}`. The `{id}` path capture
  /// binds onto [EntityIdRequest.id].
  Future<void> deleteUser(EntityIdRequest request);

  /// `adminListRoles` — `GET /admin/roles`.
  Future<List<RoleDto>> listRoles();

  /// `adminCreateRole` — `POST /admin/roles`.
  Future<RoleDto> createRole(RoleDto role);

  /// `adminUpdateRole` — `PUT /admin/roles/{key}`. [role] carries the mutable
  /// name; its `key` is the addressed role (the `{key}` path capture binds onto
  /// `RoleDto.key` via `urlParameterMapping`).
  Future<RoleDto> updateRole(RoleDto role);

  /// `adminDeleteRole` — `DELETE /admin/roles/{key}`. The `{key}` path capture
  /// binds onto [EntityIdRequest.id].
  Future<void> deleteRole(EntityIdRequest request);

  /// `adminListGroups` — `GET /admin/groups`.
  Future<List<GroupDto>> listGroups();

  /// `adminCreateGroup` — `POST /admin/groups`.
  Future<GroupDto> createGroup(GroupDto group);

  /// `adminUpdateGroup` — `PUT /admin/groups/{id}` (name + membership). Its `id`
  /// is the addressed group (the `{id}` path capture binds onto `GroupDto.id`
  /// via `urlParameterMapping`).
  Future<GroupDto> updateGroup(GroupDto group);

  /// `adminDeleteGroup` — `DELETE /admin/groups/{id}`. The `{id}` path capture
  /// binds onto [EntityIdRequest.id].
  Future<void> deleteGroup(EntityIdRequest request);

  /// `adminGetGrants` — `GET /admin/grants`. The full
  /// `(role, resourceKey) → TomAuthState` matrix.
  Future<GrantMatrixDto> getGrants();

  /// `adminPutGrants` — `PUT /admin/grants`. Replaces the matrix; the server
  /// materialises it into `TomResourceGrant` rows.
  Future<void> putGrants(GrantMatrixDto matrix);

  /// `adminAssign` — `POST /admin/assignments`. Assigns a role and/or group to
  /// a user.
  Future<void> assign(AssignmentRequest request);

  /// `adminResources` — `GET /admin/resources` (admin-gated). The admin
  /// console's full text bundle (admin forms + grants texts), installed after
  /// sign-in. Admin-gated because only administrators reach the console (D-A10:
  /// the auth server serves the admin console's full bundle).
  Future<ResourceBundleDto> resources();
}

/// Application surface of the app server (the todo board).
///
/// Every method requires authentication except [health]; reads are filtered to
/// what the principal owns or is shared into, and writes are re-checked
/// field-by-field server-side against the principal's four-state grade.
abstract class AppApiService {
  /// `appHealth` — `GET /status` (public). Application status JSON; no
  /// persistence. Served at `/status`, not `/health`: the framework's built-in
  /// [TomHealthService] already owns the plain-text `GET /health` liveness probe
  /// (auto-mounted in every server), so an app-defined `/health` would collide
  /// with — and be shadowed by — it. `/health` = infra liveness, `/status` =
  /// typed app status.
  Future<Map<String, Object>> health();

  /// `appListWorkspaces` — `GET /workspaces`. Workspaces the principal owns or
  /// is shared into.
  Future<List<Workspace>> listWorkspaces();

  /// `appListProjects` — `GET /projects?workspaceId=`. Visible projects in a
  /// workspace.
  Future<List<Project>> listProjects(String workspaceId);

  /// `appCreateProject` — `POST /projects`. The principal becomes the owner.
  Future<Project> createProject(Project project);

  /// `appListLists` — `GET /lists?projectId=`. Lists in a visible project.
  Future<List<TodoList>> listLists(String projectId);

  /// `appListItems` — `GET /items?listId=`. Items in a visible list; the client
  /// resolves each field's grade locally from its resource-role map ([appResourceRoles]).
  Future<List<TodoItem>> listItems(String listId);

  /// `appCreateItem` — `POST /items`. Rejects writes to fields the principal's
  /// grade is not `full` on.
  Future<TodoItem> createItem(TodoItem item);

  /// `appUpdateItem` — `PUT /items/{id}`. Field-level authorized: a write to a
  /// field graded below `full` is rejected. The `{id}` path capture binds onto
  /// `TodoItem.id` via `urlParameterMapping`.
  Future<TodoItem> updateItem(TodoItem item);

  /// `appDeleteItem` — `DELETE /items/{id}` (owner/editor only). The `{id}` path
  /// capture binds onto [EntityIdRequest.id].
  Future<void> deleteItem(EntityIdRequest request);

  /// `appAddComment` — `POST /items/{id}/comments` (commenter and above). The
  /// `{id}` path capture binds onto `TodoComment.itemId` (a non-identity
  /// `{'id': 'itemId'}` `urlParameterMapping`).
  Future<TodoComment> addComment(TodoComment comment);

  /// `appShare` — `POST /share`. Owner shares a resource with a user at a role.
  Future<void> share(ShareRequest request);

  /// `appRevokeShare` — `DELETE /share/{id}` (owner only).
  ///
  /// The one **retained bare-`String` path-parameter example** (G-API-2): every
  /// other by-id endpoint binds its `{id}` onto a typed request DTO, but this
  /// handler keeps the direct `String id` so the framework's primitive
  /// path-parameter coercion stays demonstrated in the sample.
  Future<void> revokeShare(String id);

  /// `appResources` — `GET /resources` (authenticated). The app client's full
  /// text bundle (board + item-form texts: `todo.item.*`, `board.*`, …),
  /// installed after sign-in. Any authenticated principal may read it; the texts
  /// are display strings, not data (D-A10: the app server serves the app
  /// client's full bundle).
  Future<ResourceBundleDto> resources();

  /// `appResourceRoles` — `GET /resource-roles` (authenticated). The principal's
  /// effective resource-role map: `<type>:<id>` (e.g. `project:1`, `item:1`) →
  /// role name (`owner`/`editor`/`viewer`/`commenter`). The app server resolves
  /// the principal's ownership grants (C-5) and share delegations (C-6) through
  /// the framework delegation resolver, then expands each grant down its
  /// containment chain so a project grant surfaces every contained item — the
  /// exact key set the client's exact-match resource-role adapter needs to grade
  /// fields (RCC2). The authz token is an opaque bearer client-side, so the map
  /// is fetched here rather than read from a claim.
  Future<Map<String, String>> resourceRoles();
}
