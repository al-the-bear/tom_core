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
import 'file_descriptor_dto.dart';
import 'grant_matrix_dto.dart';
import 'login_dtos.dart';
import 'resource_bundle_dto.dart';
import 'share_request.dart';

/// Authentication surface of the auth server (`/auth/*`).
///
/// `login`, `submitSecondFactor`, the three enrolment passes and
/// `loginResources` are public — together they are exactly the surface a caller
/// reaches *before* it holds a session token. `refresh`, `logout` and `me`
/// require a valid one.
abstract class AuthApiService {
  /// `authLogin` — `POST /auth/login` (public). Exchanges credentials for the
  /// signed token pair and the resolved principal.
  Future<LoginResult> login(LoginRequest request);

  /// `authSecondFactor` — `POST /auth/second-factor` (public). Completes a
  /// login that came back with `LoginResult.requires2FA`, exchanging the interim
  /// token plus the submitted factor for the final token pair — the same pair a
  /// 2FA-free login would have produced.
  Future<LoginResult> submitSecondFactor(SecondFactorRequest request);

  /// `authBeginEnrolment` — `POST /auth/enrol/begin` (public). Starts setting up
  /// the mechanism the user picked from
  /// `LoginResult.availableTwoFactorMethods`, returning an interim token whose
  /// claims carry what the client must show (for TOTP: the `otpauth://` URI and
  /// the base32 secret).
  Future<LoginResult> beginEnrolment(TwoFactorEnrolmentRequest request);

  /// `authConfirmEnrolment` — `POST /auth/enrol/confirm` (public). Proves the
  /// factor works, records it, and completes the login with the final token
  /// pair — no further challenge, because deriving a code from the just-issued
  /// secret already demonstrated possession.
  Future<LoginResult> confirmEnrolment(TwoFactorEnrolmentRequest request);

  /// `authSkipEnrolment` — `POST /auth/enrol/skip` (public). Declines a
  /// skippable offer and completes the login with no factor. Refused unless the
  /// presented token itself says declining was permitted.
  Future<LoginResult> skipEnrolment(TwoFactorEnrolmentRequest request);

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

  /// `appCreateWorkspace` — `POST /workspaces`. The principal becomes the owner
  /// both ways: the persisted `ownerId` column is stamped with their id (so the
  /// framework `@TomDbScope(field: 'ownerId')` owner-scope makes the row theirs)
  /// and an explicit C-5 owner grant is recorded (mirroring `createProject`).
  Future<Workspace> createWorkspace(Workspace workspace);

  /// `appUpdateWorkspace` — `PUT /workspaces/{id}`. **Owner-only by
  /// construction**: the update routes through the framework CRUD repository,
  /// whose `@TomDbScope` write enforcement rejects an update to a workspace the
  /// caller does not own with a `TomDataScopeAuthorizationException` — the app
  /// server maps that to **403** (the RCB9 live write-rejection path). The `{id}`
  /// path capture binds onto `Workspace.id` via `urlParameterMapping`.
  Future<Workspace> updateWorkspace(Workspace workspace);

  /// `appDeleteWorkspace` — `DELETE /workspaces/{id}`. Owner-only by the same
  /// `@TomDbScope` write enforcement as [updateWorkspace]. The `{id}` path
  /// capture binds onto [EntityIdRequest.id].
  Future<void> deleteWorkspace(EntityIdRequest request);

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

  /// `appListAttachments` — `GET /attachments?listId=`. The attachment
  /// descriptors of the visible items in [listId], one entry per item that
  /// actually has a file; an item with an empty slot is simply absent.
  ///
  /// This is the board's paperclip source. Each entry is exactly what a `HEAD`
  /// against `app_items/<id>/attachment` returns ([FileDescriptorDto] wraps the
  /// kernel's [TomFileMetadata] losslessly), so the list view renders the
  /// presence, media type and size without moving a single byte — and without
  /// one round trip per item.
  Future<List<FileDescriptorDto>> listAttachments(String listId);

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

  /// `appListComments` — `GET /items/{id}/comments`. The item's comment thread,
  /// oldest first, for any principal that may *read* the item (C-3): a viewer
  /// sees the history without being able to add to it. The `{id}` path capture
  /// binds onto [EntityIdRequest.id] even though the GET carries no body.
  Future<List<TodoComment>> listComments(EntityIdRequest request);

  /// `appListSubtasks` — `GET /items/{id}/subtasks`. The item's subtasks in
  /// `position` order, gated by the same read scope as [listComments].
  Future<List<Subtask>> listSubtasks(EntityIdRequest request);

  /// `appAddSubtask` — `POST /items/{id}/subtasks` (editor and above, i.e. the
  /// same gate as editing the parent item — a subtask is part of the item, not a
  /// comment on it). The `{id}` path capture binds onto `Subtask.itemId`.
  Future<Subtask> addSubtask(Subtask subtask);

  /// `appUpdateSubtask` — `PUT /subtasks/{id}` (editor and above). Used to
  /// toggle `done`; the gate is resolved from the *parent item*, so a subtask
  /// can never be edited by someone who could not edit the item it belongs to.
  Future<Subtask> updateSubtask(Subtask subtask);

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
