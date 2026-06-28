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
/// Access is captured in the companion `*ApiAccess` maps (keyed by endpoint id)
/// because `TomApiEndpoint` has no access field; the kernel `TomAccessControl`
/// values (`TomPublicAccess`/`TomAuthenticatedAccess`/`TomRoleAccess`) are the
/// authoritative per-endpoint policy the servers enforce.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'admin_dtos.dart';
import 'graded_field_dto.dart';
import 'grant_matrix_dto.dart';
import 'login_dtos.dart';
import 'share_request.dart';

/// Access policy shared by every `/admin/*` endpoint.
const TomRoleAccess _adminOnly = TomRoleAccess(['admin']);

/// Authentication API (`/auth/*`) — credential exchange and session lifecycle.
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
    ),
    TomApiEndpoint<LoginResult, Object?>(
      id: 'authRefresh',
      uri: '/refresh',
      method: TomHttpMethod.post,
      requestTypes: const [],
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'authLogout',
      uri: '/logout',
      method: TomHttpMethod.post,
      requestTypes: const [],
    ),
    TomApiEndpoint<UserDto, Object?>(
      id: 'authMe',
      uri: '/me',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
  ],
);

/// Per-endpoint access for [authApi]; only `authLogin` is public.
const Map<String, TomAccessControl> authApiAccess = {
  'authLogin': TomPublicAccess(),
  'authRefresh': TomAuthenticatedAccess(),
  'authLogout': TomAuthenticatedAccess(),
  'authMe': TomAuthenticatedAccess(),
};

/// Administration API (`/admin/*`) — accounts, roles, groups, the grant matrix,
/// and assignments. Every endpoint is `admin`-gated.
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
    ),
    TomApiEndpoint<UserDto, CreateUserRequest>(
      id: 'adminCreateUser',
      uri: '/users',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<UserDto, UserDto>(
      id: 'adminUpdateUser',
      uri: '/users/{id}',
      method: TomHttpMethod.put,
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'adminDeleteUser',
      uri: '/users/{id}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
    ),
    TomApiEndpoint<List<RoleDto>, Object?>(
      id: 'adminListRoles',
      uri: '/roles',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<RoleDto, RoleDto>(
      id: 'adminCreateRole',
      uri: '/roles',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<RoleDto, RoleDto>(
      id: 'adminUpdateRole',
      uri: '/roles/{key}',
      method: TomHttpMethod.put,
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'adminDeleteRole',
      uri: '/roles/{key}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
    ),
    TomApiEndpoint<List<GroupDto>, Object?>(
      id: 'adminListGroups',
      uri: '/groups',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<GroupDto, GroupDto>(
      id: 'adminCreateGroup',
      uri: '/groups',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<GroupDto, GroupDto>(
      id: 'adminUpdateGroup',
      uri: '/groups/{id}',
      method: TomHttpMethod.put,
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'adminDeleteGroup',
      uri: '/groups/{id}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
    ),
    TomApiEndpoint<GrantMatrixDto, Object?>(
      id: 'adminGetGrants',
      uri: '/grants',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<Object?, GrantMatrixDto>(
      id: 'adminPutGrants',
      uri: '/grants',
      method: TomHttpMethod.put,
    ),
    TomApiEndpoint<Object?, AssignmentRequest>(
      id: 'adminAssign',
      uri: '/assignments',
      method: TomHttpMethod.post,
    ),
  ],
);

/// Per-endpoint access for [adminApi]; every endpoint requires the `admin` role.
const Map<String, TomAccessControl> adminApiAccess = {
  'adminListUsers': _adminOnly,
  'adminCreateUser': _adminOnly,
  'adminUpdateUser': _adminOnly,
  'adminDeleteUser': _adminOnly,
  'adminListRoles': _adminOnly,
  'adminCreateRole': _adminOnly,
  'adminUpdateRole': _adminOnly,
  'adminDeleteRole': _adminOnly,
  'adminListGroups': _adminOnly,
  'adminCreateGroup': _adminOnly,
  'adminUpdateGroup': _adminOnly,
  'adminDeleteGroup': _adminOnly,
  'adminGetGrants': _adminOnly,
  'adminPutGrants': _adminOnly,
  'adminAssign': _adminOnly,
};

/// Application API (the todo board) — authenticated except `appHealth`.
final TomApi appApi = TomApi(
  id: 'app',
  name: 'Todo Application API',
  description: 'Workspaces, projects, lists, items, comments and sharing.',
  uri: '',
  endpoints: [
    TomApiEndpoint<Map<String, Object>, Object?>(
      id: 'appHealth',
      uri: '/health',
      method: TomHttpMethod.get,
      includeBearerAuthentication: false,
      requestTypes: const [],
    ),
    TomApiEndpoint<List<Workspace>, Object?>(
      id: 'appListWorkspaces',
      uri: '/workspaces',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<List<Project>, Object?>(
      id: 'appListProjects',
      uri: '/projects',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<Project, Project>(
      id: 'appCreateProject',
      uri: '/projects',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<List<TodoList>, Object?>(
      id: 'appListLists',
      uri: '/lists',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<List<TodoItem>, Object?>(
      id: 'appListItems',
      uri: '/items',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<TodoItem, TodoItem>(
      id: 'appCreateItem',
      uri: '/items',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<TodoItem, TodoItem>(
      id: 'appUpdateItem',
      uri: '/items/{id}',
      method: TomHttpMethod.put,
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'appDeleteItem',
      uri: '/items/{id}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
    ),
    TomApiEndpoint<TodoComment, TodoComment>(
      id: 'appAddComment',
      uri: '/items/{id}/comments',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<List<GradedFieldDto>, Object?>(
      id: 'appItemFieldStates',
      uri: '/items/{id}/field-states',
      method: TomHttpMethod.get,
      requestTypes: const [],
    ),
    TomApiEndpoint<Object?, ShareRequest>(
      id: 'appShare',
      uri: '/share',
      method: TomHttpMethod.post,
    ),
    TomApiEndpoint<Object?, Object?>(
      id: 'appRevokeShare',
      uri: '/share/{id}',
      method: TomHttpMethod.delete,
      requestTypes: const [],
    ),
  ],
);

/// Per-endpoint access for [appApi]; everything but `appHealth` is
/// authenticated. Resource- and field-level authorization is enforced inside
/// the handlers (shares + the four-state grade), not by these blanket levels.
const Map<String, TomAccessControl> appApiAccess = {
  'appHealth': TomPublicAccess(),
  'appListWorkspaces': TomAuthenticatedAccess(),
  'appListProjects': TomAuthenticatedAccess(),
  'appCreateProject': TomAuthenticatedAccess(),
  'appListLists': TomAuthenticatedAccess(),
  'appListItems': TomAuthenticatedAccess(),
  'appCreateItem': TomAuthenticatedAccess(),
  'appUpdateItem': TomAuthenticatedAccess(),
  'appDeleteItem': TomAuthenticatedAccess(),
  'appAddComment': TomAuthenticatedAccess(),
  'appItemFieldStates': TomAuthenticatedAccess(),
  'appShare': TomAuthenticatedAccess(),
  'appRevokeShare': TomAuthenticatedAccess(),
};

/// Registers [authApi], [adminApi] and [appApi] with the global
/// [tomRemoteApis] registry. Idempotent — registering an API replaces any prior
/// definition under the same id. Call once at client or server startup.
void registerAdvancedTodoApis() {
  tomRemoteApis
    ..register(authApi)
    ..register(adminApi)
    ..register(appApi);
}
