/// The wire registry — the single source of each endpoint's URI, HTTP method,
/// request/response type, and four-state access level.
///
/// Built on the kernel's `TomApi`/`TomApiEndpoint` model (the same mechanism the
/// migrated `tom_uam` codespec uses), so it resolves entirely from the
/// `tom_core_kernel` barrel and stays consumable by the Flutter-free client
/// core. The server-side `@tomService`/`@TomEndpoint` annotations live in
/// `tom_core_server` and therefore cannot appear here — the servers re-declare
/// their endpoint classes against this registry when they are built.
///
/// Access is declared **directly on each endpoint** via `TomApiEndpoint.access`
/// (G-API-3, full form / C-12): the kernel `TomAccessControl` values
/// (`TomPublicAccess`/`TomAuthenticatedAccess`/`TomRoleAccess`) are the
/// authoritative per-endpoint policy, and the server pipeline extracts them on
/// first call unless an implementation handler overrides them locally. There is
/// no companion access map — the endpoint declaration is the single source.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'admin_dtos.dart';
import 'entity_id_request.dart';
import 'grant_matrix_dto.dart';
import 'login_dtos.dart';
import 'resource_bundle_dto.dart';
import 'share_request.dart';

/// The `admin` role key — defined **once** here in the contracts package and
/// reused everywhere the admin gate is expressed (G-API-4), so the literal
/// `'admin'` is never restated across the registry or the server handlers.
const String adminRole = 'admin';

/// Access policy shared by every `/admin/*` endpoint: the `admin` role only.
///
/// Declared once on the contract side and referenced directly as the `access:`
/// of each `/admin/*` endpoint below (G-API-3 / G-API-4) — so neither the
/// registry nor a handler restates `TomRoleAccess(['admin'])` inline. Being a
/// single `const` value, every `/admin/*` endpoint shares the same instance.
const TomRoleAccess adminAccess = TomRoleAccess([adminRole]);

/// Authentication API (`/auth/*`) — credential exchange and session lifecycle.
///
/// `authLogin` and `authLoginResources` are the two public endpoints (credential
/// exchange and the pre-login texts); the rest require authentication.
final TomApi authApi = TomApi(
  id: 'auth',
  name: 'Authentication API',
  description: 'Credential login and token lifecycle.',
  uri: '/auth',
  endpoints: [
    TomApiEndpoint<LoginResult, LoginRequest>(
      id: 'authLogin',
      uri: '/login',
      method: TomHttpMethod.post,
      includeBearerAuthentication: false,
      access: TomPublicAccess(),
    ),
    TomApiEndpoint<ResourceBundleDto, Object?>(
      id: 'authLoginResources',
      uri: '/resources/login',
      method: TomHttpMethod.get,
      includeBearerAuthentication: false,
      requestTypes: const [],
      access: TomPublicAccess(),
    ),
    TomApiEndpoint<LoginResult, Object?>(
      id: 'authRefresh',
      uri: '/refresh',
      method: TomHttpMethod.post,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'authLogout',
      uri: '/logout',
      method: TomHttpMethod.post,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<UserDto, Object?>(
      id: 'authMe',
      uri: '/me',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
  ],
);

/// Administration API (`/admin/*`) — accounts, roles, groups, the grant matrix,
/// and assignments. Every endpoint is `admin`-gated via [adminAccess].
final TomApi adminApi = TomApi(
  id: 'admin',
  name: 'Administration API',
  description: 'Account, role, group, grant and assignment management.',
  uri: '/admin',
  endpoints: [
    TomApiEndpoint<List<UserDto>, Object?>(
      id: 'adminListUsers',
      uri: '/users',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: adminAccess,
    ),
    TomApiEndpoint<UserDto, CreateUserRequest>(
      id: 'adminCreateUser',
      uri: '/users',
      method: TomHttpMethod.post,
      access: adminAccess,
    ),
    TomApiEndpoint<UserDto, UserDto>(
      id: 'adminUpdateUser',
      uri: '/users/{id}',
      method: TomHttpMethod.put,
      // `{id}` → `UserDto.id` (identity): the addressed account.
      urlParameterMapping: const {'id': 'id'},
      access: adminAccess,
    ),
    TomApiEndpoint<Object?, EntityIdRequest>(
      id: 'adminDeleteUser',
      uri: '/users/{id}',
      method: TomHttpMethod.delete,
      // `{id}` → `EntityIdRequest.id` (identity).
      urlParameterMapping: const {'id': 'id'},
      access: adminAccess,
    ),
    TomApiEndpoint<List<RoleDto>, Object?>(
      id: 'adminListRoles',
      uri: '/roles',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: adminAccess,
    ),
    TomApiEndpoint<RoleDto, RoleDto>(
      id: 'adminCreateRole',
      uri: '/roles',
      method: TomHttpMethod.post,
      access: adminAccess,
    ),
    TomApiEndpoint<RoleDto, RoleDto>(
      id: 'adminUpdateRole',
      uri: '/roles/{key}',
      method: TomHttpMethod.put,
      // `{key}` → `RoleDto.key` (identity): the addressed role.
      urlParameterMapping: const {'key': 'key'},
      access: adminAccess,
    ),
    TomApiEndpoint<Object?, EntityIdRequest>(
      id: 'adminDeleteRole',
      uri: '/roles/{key}',
      method: TomHttpMethod.delete,
      // `{key}` → `EntityIdRequest.id` (non-identity rename).
      urlParameterMapping: const {'key': 'id'},
      access: adminAccess,
    ),
    TomApiEndpoint<List<GroupDto>, Object?>(
      id: 'adminListGroups',
      uri: '/groups',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: adminAccess,
    ),
    TomApiEndpoint<GroupDto, GroupDto>(
      id: 'adminCreateGroup',
      uri: '/groups',
      method: TomHttpMethod.post,
      access: adminAccess,
    ),
    TomApiEndpoint<GroupDto, GroupDto>(
      id: 'adminUpdateGroup',
      uri: '/groups/{id}',
      method: TomHttpMethod.put,
      // `{id}` → `GroupDto.id` (identity): the addressed group.
      urlParameterMapping: const {'id': 'id'},
      access: adminAccess,
    ),
    TomApiEndpoint<Object?, EntityIdRequest>(
      id: 'adminDeleteGroup',
      uri: '/groups/{id}',
      method: TomHttpMethod.delete,
      // `{id}` → `EntityIdRequest.id` (identity).
      urlParameterMapping: const {'id': 'id'},
      access: adminAccess,
    ),
    TomApiEndpoint<GrantMatrixDto, Object?>(
      id: 'adminGetGrants',
      uri: '/grants',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: adminAccess,
    ),
    TomApiEndpoint<Object?, GrantMatrixDto>(
      id: 'adminPutGrants',
      uri: '/grants',
      method: TomHttpMethod.put,
      access: adminAccess,
    ),
    TomApiEndpoint<Object?, AssignmentRequest>(
      id: 'adminAssign',
      uri: '/assignments',
      method: TomHttpMethod.post,
      access: adminAccess,
    ),
    TomApiEndpoint<ResourceBundleDto, Object?>(
      id: 'adminResources',
      uri: '/resources',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: adminAccess,
    ),
  ],
);

/// Application API (the todo board) — authenticated except `appHealth`.
///
/// Everything but `appHealth` is authenticated; resource- and field-level
/// authorization is enforced inside the handlers (shares + the four-state
/// grade), not by these blanket per-endpoint levels.
final TomApi appApi = TomApi(
  id: 'app',
  name: 'Todo Application API',
  description: 'Workspaces, projects, lists, items, comments and sharing.',
  uri: '',
  endpoints: [
    TomApiEndpoint<Map<String, Object>, Object?>(
      id: 'appHealth',
      // `/status`, not `/health`: the framework's built-in TomHealthService
      // auto-mounts a plain-text `GET /health` liveness probe in every server,
      // so an app `/health` would collide with (and be shadowed by) it.
      uri: '/status',
      method: TomHttpMethod.get,
      includeBearerAuthentication: false,
      requestTypes: const [],
      access: TomPublicAccess(),
    ),
    TomApiEndpoint<List<Workspace>, Object?>(
      id: 'appListWorkspaces',
      uri: '/workspaces',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<List<Project>, Object?>(
      id: 'appListProjects',
      uri: '/projects',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Project, Project>(
      id: 'appCreateProject',
      uri: '/projects',
      method: TomHttpMethod.post,
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<List<TodoList>, Object?>(
      id: 'appListLists',
      uri: '/lists',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<List<TodoItem>, Object?>(
      id: 'appListItems',
      uri: '/items',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<TodoItem, TodoItem>(
      id: 'appCreateItem',
      uri: '/items',
      method: TomHttpMethod.post,
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<TodoItem, TodoItem>(
      id: 'appUpdateItem',
      uri: '/items/{id}',
      method: TomHttpMethod.put,
      // `{id}` → `TodoItem.id` (identity): the addressed item.
      urlParameterMapping: const {'id': 'id'},
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Object?, EntityIdRequest>(
      id: 'appDeleteItem',
      uri: '/items/{id}',
      method: TomHttpMethod.delete,
      // `{id}` → `EntityIdRequest.id` (identity).
      urlParameterMapping: const {'id': 'id'},
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<TodoComment, TodoComment>(
      id: 'appAddComment',
      uri: '/items/{id}/comments',
      method: TomHttpMethod.post,
      // The demonstrative non-identity mapping: the item id lives on the
      // comment's `itemId` field, so `{id}` → `TodoComment.itemId`.
      urlParameterMapping: const {'id': 'itemId'},
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Object?, ShareRequest>(
      id: 'appShare',
      uri: '/share',
      method: TomHttpMethod.post,
      access: TomAuthenticatedAccess(),
    ),
    // The one retained bare-`String` path-parameter example (G-API-2): no typed
    // request DTO and no `urlParameterMapping`, so the `{id}` capture reaches the
    // handler through the framework's primitive path-parameter coercion. Every
    // other by-id endpoint above binds `{id}` onto a typed request DTO instead.
    TomApiEndpoint<Object?, Object?>(
      id: 'appRevokeShare',
      uri: '/share/{id}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<ResourceBundleDto, Object?>(
      id: 'appResources',
      uri: '/resources',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Map<String, String>, Object?>(
      id: 'appResourceRoles',
      uri: '/resource-roles',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: TomAuthenticatedAccess(),
    ),
  ],
);

/// Registers [authApi], [adminApi] and [appApi] with the global
/// [tomRemoteApis] registry. Idempotent — registering an API replaces any prior
/// definition under the same id. Call once at client or server startup.
void registerAdvancedTodoApis() {
  tomRemoteApis
    ..register(authApi)
    ..register(adminApi)
    ..register(appApi);
}
