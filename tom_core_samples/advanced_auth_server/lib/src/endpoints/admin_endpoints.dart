/// The auth server's `/admin/*` HTTP surface — account/role/group CRUD,
/// assignments, and the four-state grant matrix (step 12).
///
/// Three collaborators, split by responsibility (the same seam philosophy as
/// the step-10 `AuthUserStore` and the step-11 `AuthTokenService`):
///
/// - [AdminStore] is the data seam the admin operations read and write through.
///   [RepositoryAdminStore] is the production implementation over the `auth_db`
///   repository singletons (plus the framework's `tom_resource_grant` table),
///   wired at boot (step 13); [InMemoryAdminStore] is a seeded, database-free
///   store for unit tests.
/// - [AdminService] is the pure logic over an [AdminStore]: it maps the wire
///   DTOs to/from the persistence records, projects the grant rows to/from the
///   [GrantMatrixDto], and materialises a matrix back into [TomResourceGrant]
///   rows via [TomGradedAccessControlInformation.toGrants]. It has no
///   server/zone/reflection dependency, so the CRUD and grant round-trip are
///   unit-tested directly against a seeded store.
/// - [AdvancedAdminApiService] is the thin `@tomComponent` adapter the endpoint
///   pipeline routes to. It binds each [AdminApiService] method to its registry
///   endpoint (`tomRemoteApis['admin'][...]`) and gates every one with
///   `@TomRoleAccess(['admin'])`; it carries the production wiring and is
///   exercised end-to-end at boot (step 13).
///
/// A non-admin caller is rejected by the pipeline's access check *before* the
/// method runs (it throws the access-denied [TomEndpointHandlerException]). The
/// default server error handler masks every fault behind an opaque 500, so
/// [forbiddenOnAccessDenied] maps that one exception to HTTP 403; the auth-server
/// boot (step 13) installs it as the server-level error handler.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../auth/password_hashing.dart';
import '../persistence/auth_mapping.dart';
import '../persistence/auth_persistence_model.dart';

/// Repository for the framework's [TomResourceGrant] table (`tom_resource_grant`).
///
/// The grant table is owned by `tom_core_server` (datasource `main`); the
/// auth-server boot (step 13) registers `main` against the same `auth_db`
/// connection, so this singleton reads/writes the grant rows alongside the
/// auth records.
class GrantRepository extends TomSqlDatasourceRepository<TomResourceGrant, int> {}

/// Process-wide singleton grant repository.
final grantRepository = GrantRepository();

/// The data seam the admin operations read and write through.
///
/// Splitting every admin read/write onto a small interface lets [AdminService]
/// run against the real repositories at boot and a seeded in-memory store under
/// test, with identical logic on both.
abstract class AdminStore {
  /// All user account rows.
  Future<List<UserRecord>> allUsers();

  /// The account row with [id], or `null` when none exists.
  Future<UserRecord?> findUser(int id);

  /// Inserts or updates [record], returning the persisted row (with its id).
  Future<UserRecord> saveUser(UserRecord record);

  /// Deletes the account with [id].
  Future<void> removeUser(int id);

  /// All role rows.
  Future<List<RoleRecord>> allRoles();

  /// The role row whose [RoleRecord.roleKey] is [key], or `null` when none
  /// exists.
  Future<RoleRecord?> findRoleByKey(String key);

  /// Inserts or updates [record], returning the persisted row.
  Future<RoleRecord> saveRole(RoleRecord record);

  /// Deletes the role whose [RoleRecord.roleKey] is [key]. A no-op when absent.
  Future<void> removeRoleByKey(String key);

  /// All group rows.
  Future<List<GroupRecord>> allGroups();

  /// The group row with [id], or `null` when none exists.
  Future<GroupRecord?> findGroup(int id);

  /// The membership rows of the group with [groupId], in storage order.
  Future<List<GroupMemberRecord>> membersOfGroup(int groupId);

  /// Inserts or updates [record], returning the persisted row.
  Future<GroupRecord> saveGroup(GroupRecord record);

  /// Deletes the group with [id] (membership is cleared separately by the
  /// service via [replaceGroupMembers]).
  Future<void> removeGroup(int id);

  /// Replaces the membership of the group with [groupId] by [members] (deletes
  /// the existing rows, inserts the new ones).
  Future<void> replaceGroupMembers(int groupId, List<GroupMemberRecord> members);

  /// Records a `(user, role)` assignment. Duplicate assignments are tolerated.
  Future<void> addUserRole(int userId, int roleId);

  /// Records a `(group, user)` membership. Duplicate memberships are tolerated.
  Future<void> addGroupMember(int groupId, int userId);

  /// All grant rows across every role.
  Future<List<TomResourceGrant>> allGrants();

  /// Replaces every grant for [roleName] with [grants] (deletes the role's
  /// existing rows, inserts the new ones).
  Future<void> replaceGrantsForRole(String roleName, List<TomResourceGrant> grants);
}

/// The query-backed [AdminStore] wired at boot (step 13).
///
/// Reads/writes through the process-wide singleton repositories. Requires a live
/// `auth_db` connection and the reflection runtime, so it is exercised
/// end-to-end rather than in the unit tests (which use [InMemoryAdminStore]).
class RepositoryAdminStore implements AdminStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAdminStore();

  @override
  Future<List<UserRecord>> allUsers() => userRepository.findAll();

  @override
  Future<UserRecord?> findUser(int id) => userRepository.findById(id);

  @override
  Future<UserRecord> saveUser(UserRecord record) => userRepository.save(record);

  @override
  Future<void> removeUser(int id) => userRepository.deleteById(id);

  @override
  Future<List<RoleRecord>> allRoles() => roleRepository.findAll();

  @override
  Future<RoleRecord?> findRoleByKey(String key) async {
    final matches = await roleRepository.findByQuerySentence(
      'FIND BY role_key = :key',
      {'key': key},
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<RoleRecord> saveRole(RoleRecord record) => roleRepository.save(record);

  @override
  Future<void> removeRoleByKey(String key) async {
    final role = await findRoleByKey(key);
    final id = role?.id;
    if (id != null) await roleRepository.deleteById(id);
  }

  @override
  Future<List<GroupRecord>> allGroups() => groupRepository.findAll();

  @override
  Future<GroupRecord?> findGroup(int id) => groupRepository.findById(id);

  @override
  Future<List<GroupMemberRecord>> membersOfGroup(int groupId) async {
    final members = await groupMemberRepository.findByQuerySentence(
      'FIND BY group_id = :groupId',
      {'groupId': groupId},
    );
    return members.toList();
  }

  @override
  Future<GroupRecord> saveGroup(GroupRecord record) =>
      groupRepository.save(record);

  @override
  Future<void> removeGroup(int id) => groupRepository.deleteById(id);

  @override
  Future<void> replaceGroupMembers(
    int groupId,
    List<GroupMemberRecord> members,
  ) async {
    for (final existing in await membersOfGroup(groupId)) {
      final id = existing.id;
      if (id != null) await groupMemberRepository.deleteById(id);
    }
    for (final member in members) {
      await groupMemberRepository.save(member);
    }
  }

  @override
  Future<void> addUserRole(int userId, int roleId) async {
    await userRoleRepository.save(
      UserRoleRecord()
        ..userId = userId
        ..roleId = roleId,
    );
  }

  @override
  Future<void> addGroupMember(int groupId, int userId) async {
    await groupMemberRepository.save(
      GroupMemberRecord()
        ..groupId = groupId
        ..userId = userId,
    );
  }

  @override
  Future<List<TomResourceGrant>> allGrants() => grantRepository.findAll();

  @override
  Future<void> replaceGrantsForRole(
    String roleName,
    List<TomResourceGrant> grants,
  ) async {
    final existing = await grantRepository.findByQuerySentence(
      'FIND BY role_name = :roleName',
      {'roleName': roleName},
    );
    for (final grant in existing) {
      if (grant.id >= 0) await grantRepository.deleteById(grant.id);
    }
    for (final grant in grants) {
      await grantRepository.save(grant);
    }
  }
}

/// A seeded, database-free [AdminStore] for tests (and local scaffolding).
///
/// Holds every row in plain lists and assigns surrogate ids on insert, so a test
/// can exercise the full admin surface — including the grant round-trip — with
/// no connection or reflection.
class InMemoryAdminStore implements AdminStore {
  final List<UserRecord> _users;
  final List<RoleRecord> _roles;
  final List<GroupRecord> _groups;
  final List<GroupMemberRecord> _groupMembers;
  final List<UserRoleRecord> _userRoles;
  final List<TomResourceGrant> _grants;

  int _nextUserId = 1;
  int _nextRoleId = 1;
  int _nextGroupId = 1;
  int _nextMemberId = 1;
  int _nextUserRoleId = 1;

  /// Seeds the store with the given rows (each list defaults to empty). Ids are
  /// taken from the seeded rows where present and the auto-increment counters
  /// advance past them.
  InMemoryAdminStore({
    List<UserRecord>? users,
    List<RoleRecord>? roles,
    List<GroupRecord>? groups,
    List<GroupMemberRecord>? groupMembers,
    List<UserRoleRecord>? userRoles,
    List<TomResourceGrant>? grants,
  })  : _users = [...?users],
        _roles = [...?roles],
        _groups = [...?groups],
        _groupMembers = [...?groupMembers],
        _userRoles = [...?userRoles],
        _grants = [...?grants] {
    _nextUserId = _maxId(_users.map((u) => u.id)) + 1;
    _nextRoleId = _maxId(_roles.map((r) => r.id)) + 1;
    _nextGroupId = _maxId(_groups.map((g) => g.id)) + 1;
    _nextMemberId = _maxId(_groupMembers.map((m) => m.id)) + 1;
    _nextUserRoleId = _maxId(_userRoles.map((a) => a.id)) + 1;
  }

  static int _maxId(Iterable<int?> ids) =>
      ids.fold<int>(0, (max, id) => (id != null && id > max) ? id : max);

  /// The recorded `(user, role)` assignments (test introspection).
  List<UserRoleRecord> get userRoleRows => List.unmodifiable(_userRoles);

  @override
  Future<List<UserRecord>> allUsers() async => List.of(_users);

  @override
  Future<UserRecord?> findUser(int id) async {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  Future<UserRecord> saveUser(UserRecord record) async {
    if (record.id == null) {
      record.id = _nextUserId++;
      _users.add(record);
    } else {
      _replace(_users, record, (u) => u.id == record.id);
    }
    return record;
  }

  @override
  Future<void> removeUser(int id) async => _users.removeWhere((u) => u.id == id);

  @override
  Future<List<RoleRecord>> allRoles() async => List.of(_roles);

  @override
  Future<RoleRecord?> findRoleByKey(String key) async {
    for (final role in _roles) {
      if (role.roleKey == key) return role;
    }
    return null;
  }

  @override
  Future<RoleRecord> saveRole(RoleRecord record) async {
    if (record.id == null) {
      record.id = _nextRoleId++;
      _roles.add(record);
    } else {
      _replace(_roles, record, (r) => r.id == record.id);
    }
    return record;
  }

  @override
  Future<void> removeRoleByKey(String key) async =>
      _roles.removeWhere((r) => r.roleKey == key);

  @override
  Future<List<GroupRecord>> allGroups() async => List.of(_groups);

  @override
  Future<GroupRecord?> findGroup(int id) async {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  @override
  Future<List<GroupMemberRecord>> membersOfGroup(int groupId) async =>
      [for (final m in _groupMembers) if (m.groupId == groupId) m];

  @override
  Future<GroupRecord> saveGroup(GroupRecord record) async {
    if (record.id == null) {
      record.id = _nextGroupId++;
      _groups.add(record);
    } else {
      _replace(_groups, record, (g) => g.id == record.id);
    }
    return record;
  }

  @override
  Future<void> removeGroup(int id) async =>
      _groups.removeWhere((g) => g.id == id);

  @override
  Future<void> replaceGroupMembers(
    int groupId,
    List<GroupMemberRecord> members,
  ) async {
    _groupMembers.removeWhere((m) => m.groupId == groupId);
    for (final member in members) {
      member.id ??= _nextMemberId++;
      _groupMembers.add(member);
    }
  }

  @override
  Future<void> addUserRole(int userId, int roleId) async {
    _userRoles.add(
      UserRoleRecord()
        ..id = _nextUserRoleId++
        ..userId = userId
        ..roleId = roleId,
    );
  }

  @override
  Future<void> addGroupMember(int groupId, int userId) async {
    _groupMembers.add(
      GroupMemberRecord()
        ..id = _nextMemberId++
        ..groupId = groupId
        ..userId = userId,
    );
  }

  @override
  Future<List<TomResourceGrant>> allGrants() async => List.of(_grants);

  @override
  Future<void> replaceGrantsForRole(
    String roleName,
    List<TomResourceGrant> grants,
  ) async {
    _grants.removeWhere((g) => g.roleName == roleName);
    _grants.addAll(grants);
  }

  static void _replace<T>(List<T> list, T value, bool Function(T) matches) {
    for (var i = 0; i < list.length; i++) {
      if (matches(list[i])) {
        list[i] = value;
        return;
      }
    }
    list.add(value);
  }
}

/// Pure admin logic over an [AdminStore]: account/role/group CRUD, assignments,
/// and the grant matrix.
///
/// Maps the wire DTOs to/from the `auth_db` records (reusing the step-7
/// `auth_mapping` conversions and the step-9 password helper) and the grant rows
/// to/from the [GrantMatrixDto]. No server/zone/reflection dependency, so every
/// path is unit-testable against a seeded [InMemoryAdminStore].
class AdminService {
  /// The data seam the operations read and write through.
  final AdminStore store;

  /// Builds the service over [store] (a repository-backed store at boot, a
  /// seeded in-memory store under test).
  AdminService(this.store);

  // ----- Users -------------------------------------------------------------

  /// Lists every account as a password-free [UserDto].
  Future<List<UserDto>> listUsers() async =>
      [for (final record in await store.allUsers()) userRecordToDto(record)];

  /// Creates an account from [request], hashing the plaintext password into the
  /// server-only credential columns (step-9 helper) before persisting.
  Future<UserDto> createUser(CreateUserRequest request) async {
    final record = applyPassword(
      createUserRequestToRecord(request),
      request.password,
    );
    return userRecordToDto(await store.saveUser(record));
  }

  /// Applies the mutable profile/status fields of [user] onto the account with
  /// [id], preserving the stored password. Throws when no such account exists.
  Future<UserDto> updateUser(String id, UserDto user) async {
    final record = await _requireUser(id);
    return userRecordToDto(await store.saveUser(applyUserDto(record, user)));
  }

  /// Deletes the account with [id].
  Future<void> deleteUser(String id) async {
    final key = int.tryParse(id);
    if (key != null) await store.removeUser(key);
  }

  Future<UserRecord> _requireUser(String id) async {
    final key = int.tryParse(id);
    final record = key == null ? null : await store.findUser(key);
    if (record == null) {
      throw TomEndpointHandlerException(
        'admin.user.not_found',
        'No user with id $id',
      );
    }
    return record;
  }

  // ----- Roles -------------------------------------------------------------

  /// Lists every role as a [RoleDto].
  Future<List<RoleDto>> listRoles() async =>
      [for (final record in await store.allRoles()) roleRecordToDto(record)];

  /// Creates a role from [role].
  Future<RoleDto> createRole(RoleDto role) async =>
      roleRecordToDto(await store.saveRole(roleDtoToRecord(role)));

  /// Updates the role with stable [key], renaming/re-keying it from [role].
  /// Throws when no such role exists.
  Future<RoleDto> updateRole(String key, RoleDto role) async {
    final record = await store.findRoleByKey(key);
    if (record == null) {
      throw TomEndpointHandlerException(
        'admin.role.not_found',
        'No role with key $key',
      );
    }
    record
      ..roleKey = role.key
      ..name = role.name;
    return roleRecordToDto(await store.saveRole(record));
  }

  /// Deletes the role whose stable key is [key].
  Future<void> deleteRole(String key) => store.removeRoleByKey(key);

  // ----- Groups ------------------------------------------------------------

  /// Lists every group with its membership.
  Future<List<GroupDto>> listGroups() async {
    final groups = await store.allGroups();
    return [
      for (final group in groups)
        groupToDto(group, await store.membersOfGroup(group.id ?? -1)),
    ];
  }

  /// Creates a group from [group] and materialises its membership.
  Future<GroupDto> createGroup(GroupDto group) async {
    final saved = await store.saveGroup(groupDtoToRecord(group));
    final groupId = saved.id!;
    await store.replaceGroupMembers(
      groupId,
      groupMemberRecords(group, groupId: groupId),
    );
    return groupToDto(saved, await store.membersOfGroup(groupId));
  }

  /// Updates the group with [id] (name + membership). Throws when no such group
  /// exists.
  Future<GroupDto> updateGroup(String id, GroupDto group) async {
    final key = int.tryParse(id);
    final record = key == null ? null : await store.findGroup(key);
    if (record == null) {
      throw TomEndpointHandlerException(
        'admin.group.not_found',
        'No group with id $id',
      );
    }
    record.name = group.name;
    final saved = await store.saveGroup(record);
    final groupId = saved.id!;
    await store.replaceGroupMembers(
      groupId,
      groupMemberRecords(group, groupId: groupId),
    );
    return groupToDto(saved, await store.membersOfGroup(groupId));
  }

  /// Deletes the group with [id] together with its membership.
  Future<void> deleteGroup(String id) async {
    final key = int.tryParse(id);
    if (key == null) return;
    await store.replaceGroupMembers(key, const []);
    await store.removeGroup(key);
  }

  // ----- Assignments -------------------------------------------------------

  /// Assigns a role and/or group to the user in [request]. An empty role key /
  /// group id skips that half of the assignment.
  Future<void> assign(AssignmentRequest request) async {
    final userId = int.tryParse(request.userId);
    if (userId == null) return;
    if (request.roleKey.isNotEmpty) {
      final role = await store.findRoleByKey(request.roleKey);
      final roleId = role?.id;
      if (roleId != null) await store.addUserRole(userId, roleId);
    }
    if (request.groupId.isNotEmpty) {
      final groupId = int.tryParse(request.groupId);
      if (groupId != null) await store.addGroupMember(groupId, userId);
    }
  }

  // ----- Grants ------------------------------------------------------------

  /// Projects every stored grant into the `(roleName, resourceKey) → state`
  /// matrix.
  Future<GrantMatrixDto> getGrants() async {
    final matrix = <String, Map<String, TomAuthState>>{};
    for (final grant in await store.allGrants()) {
      (matrix[grant.roleName] ??= <String, TomAuthState>{})[grant.resourceKey] =
          grant.accessLevel;
    }
    return GrantMatrixDto(matrix);
  }

  /// Replaces the grant matrix: for each role in [matrix], materialises its row
  /// into [TomResourceGrant] rows via [TomGradedAccessControlInformation.toGrants]
  /// and persists them through the store.
  Future<void> putGrants(GrantMatrixDto matrix) async {
    for (final role in matrix.roles) {
      final graded =
          TomGradedAccessControlInformation(grades: matrix.matrix[role]);
      await store.replaceGrantsForRole(role, graded.toGrants(role));
    }
  }
}

/// The message key the endpoint pipeline throws when an access check fails.
///
/// Coupled to `TomEndpointHandler`'s access-denied throw in `tom_core_server`;
/// kept as a named constant so the boot-installed [forbiddenOnAccessDenied]
/// handler maps exactly that exception (and nothing else) to HTTP 403.
const String endpointAccessDeniedKey =
    'endpoint_handler.handle_method_call.access_denied';

/// Server-level error handler that maps an access-control rejection to HTTP 403.
///
/// The endpoint pipeline enforces `@TomRoleAccess` *before* the method runs and,
/// on denial, throws the access-denied [TomEndpointHandlerException] — which the
/// default server handler would mask behind an opaque 500. Installing this on the
/// server configuration (step 13) turns that one exception into a `403 Forbidden`
/// carrying the stable key; every other fault returns `null`, falling through to
/// the server's default handler.
Response? forbiddenOnAccessDenied(
  Request request,
  Object error,
  StackTrace stack,
) {
  if (error is TomException && error.key == endpointAccessDeniedKey) {
    return Response.forbidden(
      jsonEncode({'error': error.key}),
      headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
    );
  }
  return null;
}

/// The `@tomComponent` implementing the registry's `admin` API.
///
/// Bound to the fifteen `adminApi` endpoints (`tomRemoteApis['admin']`); the
/// bean container instantiates it through the no-argument constructor, which
/// wires the production [AdminService] over the repository-backed store. Every
/// endpoint is gated with `@TomRoleAccess(['admin'])` (the registry's
/// `adminApiAccess` map is informational, not auto-applied), so the pipeline
/// rejects a non-admin caller before the method runs.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'admin')
class AdvancedAdminApiService implements AdminApiService {
  /// Production admin logic over the repository-backed store.
  final AdminService _admin = AdminService(const RepositoryAdminStore());

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminListUsers')
  @override
  Future<List<UserDto>> listUsers() => _admin.listUsers();

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminCreateUser')
  @override
  Future<UserDto> createUser(CreateUserRequest request) =>
      _admin.createUser(request);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminUpdateUser')
  @override
  Future<UserDto> updateUser(String id, UserDto user) =>
      _admin.updateUser(id, user);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminDeleteUser')
  @override
  Future<void> deleteUser(String id) => _admin.deleteUser(id);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminListRoles')
  @override
  Future<List<RoleDto>> listRoles() => _admin.listRoles();

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminCreateRole')
  @override
  Future<RoleDto> createRole(RoleDto role) => _admin.createRole(role);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminUpdateRole')
  @override
  Future<RoleDto> updateRole(String key, RoleDto role) =>
      _admin.updateRole(key, role);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminDeleteRole')
  @override
  Future<void> deleteRole(String key) => _admin.deleteRole(key);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminListGroups')
  @override
  Future<List<GroupDto>> listGroups() => _admin.listGroups();

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminCreateGroup')
  @override
  Future<GroupDto> createGroup(GroupDto group) => _admin.createGroup(group);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminUpdateGroup')
  @override
  Future<GroupDto> updateGroup(String id, GroupDto group) =>
      _admin.updateGroup(id, group);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminDeleteGroup')
  @override
  Future<void> deleteGroup(String id) => _admin.deleteGroup(id);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminGetGrants')
  @override
  Future<GrantMatrixDto> getGrants() => _admin.getGrants();

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminPutGrants')
  @override
  Future<void> putGrants(GrantMatrixDto matrix) => _admin.putGrants(matrix);

  @TomRoleAccess(['admin'])
  @TomApiEndpointImplementation(apiId: 'admin', endpointId: 'adminAssign')
  @override
  Future<void> assign(AssignmentRequest request) => _admin.assign(request);
}
