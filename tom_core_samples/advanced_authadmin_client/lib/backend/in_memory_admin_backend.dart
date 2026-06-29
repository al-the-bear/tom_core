/// The default backend: a seeded, fully working in-memory [AdminBackend]
/// (step 32).
///
/// It mirrors what `advanced_auth_server`'s `/admin/*` API exposes — the same
/// demo accounts the app client uses (so the two consoles line up), a small set
/// of roles and a group, and the **same four-state grant matrix** the auth server
/// seeds (`projectRole` × field resource key). Keeping the model here in one
/// place is what lets the admin screens and the grant-matrix editor render and
/// round-trip without a server or database.
///
/// The principal is implicit in the session: [login] records the current user,
/// and every administrative call requires that user to hold the `admin` role —
/// exactly the `@TomRoleAccess(['admin'])` gate the live server enforces on each
/// endpoint. A signed-in non-admin is refused with `admin.access.forbidden`, the
/// stable key the shell (step 33) rejects a non-admin login on.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'admin_backend.dart';

/// An in-memory implementation of [AdminBackend], seeded with demo data.
class InMemoryAdminBackend implements AdminBackend {
  /// Creates the backend and seeds its users, roles, groups and grant matrix.
  InMemoryAdminBackend() {
    _seed();
  }

  final List<UserDto> _users = [];
  final List<RoleDto> _roles = [];
  final List<GroupDto> _groups = [];

  // role name -> (fieldResourceKey -> access); the editable grant matrix.
  final Map<String, Map<String, TomAuthState>> _grants = {};

  // The plaintext passwords created accounts carry (teaching backend only —
  // never logged, never returned). Seeded accounts use a shared demo password.
  final Map<String, String> _passwords = {};

  // user id -> the role keys assigned to that principal. Drives the `admin`
  // gate and records role assignments.
  final Map<String, Set<String>> _userRoles = {};

  int _nextId = 100;
  String? _currentUserId;

  /// The shared demo password every seeded account accepts.
  static const String demoPassword = 'pw';

  /// The canned public login bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.loginBundle()` (D-A11) so the offline console installs
  /// the exact same sign-in chrome the live auth server serves — the widget
  /// tests stay socket-free while still proving the screen renders
  /// *server-delivered* texts. The console reads the `adminLogin.*` keys.
  static const Map<String, Object?> loginTexts = {
    'login.title': 'Advanced Todo — Sign in',
    'login.intro': 'Try alice, bob or val (any non-empty password).',
    'login.username.label': 'Username',
    'login.username.hint': 'alice, bob or val',
    'login.password.label': 'Password',
    'login.submit': 'Sign in',
    'adminLogin.title': 'Advanced Todo — Admin sign in',
    'adminLogin.intro':
        'Sign in as admin (password pw). A non-admin (alice, bob, val) is rejected.',
    'adminLogin.username.label': 'Username',
    'adminLogin.username.hint': 'admin',
    'adminLogin.password.label': 'Password',
    'adminLogin.submit': 'Sign in',
  };

  /// The canned authenticated console bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.adminConsoleBundle()` (D-A11) — the reflected editors'
  /// field labels (`user.*`/`role.*`/`group.*`, keyed `<formId>.<tomId>.label`)
  /// and the grant-matrix screen texts, plus the `adminConsole.title` shell
  /// chrome (no form override, no grade counterpart). The session installs this
  /// right after an admin sign-in so every console screen renders
  /// server-delivered texts while the widget tests stay socket-free.
  static const Map<String, Object?> fullTexts = {
    'adminConsole.title': 'Advanced Todo — Admin console',
    'user.username.label': 'Username',
    'user.password.label': 'Password',
    'user.displayName.label': 'Display name',
    'user.email.label': 'Email',
    'user.status.label': 'Status',
    'role.key.label': 'Key',
    'role.name.label': 'Name',
    'group.name.label': 'Name',
    'grants.title': 'Grant matrix',
    'grants.column.none': 'None',
    'grants.column.read': 'Read',
    'grants.column.full': 'Full',
    'grants.save': 'Save grants',
  };

  /// The four-state field resource keys, mirroring the server's wire keys
  /// (`TodoItemResourceKeys`). Held as plain strings because the admin console is
  /// domain-agnostic: it edits whatever resource keys the server reports.
  static const String _kTitle = 'todo.item.title';
  static const String _kStatus = 'todo.item.status';
  static const String _kPriority = 'todo.item.priority';
  static const String _kAssigneeId = 'todo.item.assigneeId';
  static const String _kDueDate = 'todo.item.dueDate';
  static const String _kEstimate = 'todo.item.estimate';
  static const String _kDescription = 'todo.item.description';

  void _seed() {
    // Demo accounts mirror the app client's (alice/bob/val) plus a dedicated
    // administrator. Only `admin` holds the `admin` role, so the others are the
    // non-admin path the shell rejects.
    void user(String id, String username, String name, List<String> roles) {
      _users.add(UserDto(
        id: id,
        username: username,
        displayName: name,
        email: '$username@todo.example',
      ));
      _passwords[id] = demoPassword;
      _userRoles[id] = {...roles};
    }

    user('u-admin', 'admin', 'Administrator', const ['admin']);
    user('u-alice', 'alice', 'Alice (owner)', const ['owner']);
    user('u-bob', 'bob', 'Bob (editor)', const ['editor']);
    user('u-val', 'val', 'Val (viewer)', const ['viewer']);

    // The application roles: the `admin` console role plus the four project
    // roles the grant matrix grades.
    _roles.addAll(const [
      RoleDto(key: 'admin', name: 'Administrator'),
      RoleDto(key: 'owner', name: 'Owner'),
      RoleDto(key: 'editor', name: 'Editor'),
      RoleDto(key: 'commenter', name: 'Commenter'),
      RoleDto(key: 'viewer', name: 'Viewer'),
    ]);

    _groups.add(GroupDto(
      id: 'g-eng',
      name: 'Engineering',
      memberUserIds: const ['u-bob', 'u-val'],
    ));

    // The four-state grant matrix, identical to the app client's twin so the two
    // consoles describe the same authorization model.
    _grants.addAll({
      'owner': {
        _kTitle: TomAuthState.full,
        _kStatus: TomAuthState.full,
        _kPriority: TomAuthState.full,
        _kAssigneeId: TomAuthState.full,
        _kDueDate: TomAuthState.full,
        _kEstimate: TomAuthState.full,
        _kDescription: TomAuthState.full,
      },
      'editor': {
        _kTitle: TomAuthState.full,
        _kStatus: TomAuthState.full,
        _kPriority: TomAuthState.full,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.full,
        _kEstimate: TomAuthState.read,
        _kDescription: TomAuthState.full,
      },
      'commenter': {
        _kTitle: TomAuthState.read,
        _kStatus: TomAuthState.read,
        _kPriority: TomAuthState.none,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.read,
        _kEstimate: TomAuthState.none,
        _kDescription: TomAuthState.read,
      },
      'viewer': {
        _kTitle: TomAuthState.read,
        _kStatus: TomAuthState.disabled,
        _kPriority: TomAuthState.read,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.read,
        _kEstimate: TomAuthState.none,
        _kDescription: TomAuthState.read,
      },
    });
  }

  @override
  Future<LoginResult> login(LoginRequest request) async {
    final key = request.username.trim().toLowerCase();
    UserDto? match;
    for (final user in _users) {
      if (user.username == key) {
        match = user;
        break;
      }
    }
    if (match == null || _passwords[match.id] != request.password) {
      throw const AdminBackendException(
        'Invalid administrator credentials.',
        key: 'auth.login.failed',
      );
    }
    _currentUserId = match.id;
    return LoginResult(
      user: match,
      authToken: 'demo-auth-$key',
      authzToken: 'demo-authz-$key',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
  }

  @override
  Future<ResourceBundleDto> loginResources() async =>
      ResourceBundleDto(Map<String, Object?>.from(loginTexts));

  @override
  Future<ResourceBundleDto> resources() async {
    // The console bundle is admin-gated, exactly like the live
    // `GET /admin/resources` endpoint's `@TomRoleAccess(['admin'])`.
    _requireAdmin();
    return ResourceBundleDto(Map<String, Object?>.from(fullTexts));
  }

  // ----- Users -------------------------------------------------------------

  @override
  Future<List<UserDto>> listUsers() async {
    _requireAdmin();
    return [for (final user in _users) _copyUser(user)];
  }

  @override
  Future<UserDto> createUser(CreateUserRequest request) async {
    _requireAdmin();
    if (request.username.trim().isEmpty) {
      throw const AdminBackendException(
        'A username is required.',
        key: 'admin.user.invalid',
      );
    }
    final id = 'u-${_nextId++}';
    final created = UserDto(
      id: id,
      username: request.username,
      displayName: request.displayName,
      email: request.email,
    );
    _users.add(created);
    _passwords[id] = request.password;
    _userRoles[id] = <String>{};
    return _copyUser(created);
  }

  @override
  Future<UserDto> updateUser(String id, UserDto user) async {
    _requireAdmin();
    final index = _users.indexWhere((u) => u.id == id);
    if (index < 0) {
      throw AdminBackendException('No user with id "$id".',
          key: 'admin.user.not_found');
    }
    // Update the mutable profile/status; id and username are stable keys.
    final existing = _users[index];
    final updated = UserDto(
      id: existing.id,
      username: existing.username,
      displayName: user.displayName,
      email: user.email,
      status: user.status,
    );
    _users[index] = updated;
    return _copyUser(updated);
  }

  @override
  Future<void> deleteUser(String id) async {
    _requireAdmin();
    _users.removeWhere((u) => u.id == id);
    _passwords.remove(id);
    _userRoles.remove(id);
  }

  // ----- Roles -------------------------------------------------------------

  @override
  Future<List<RoleDto>> listRoles() async {
    _requireAdmin();
    return [for (final role in _roles) role];
  }

  @override
  Future<RoleDto> createRole(RoleDto role) async {
    _requireAdmin();
    if (role.key.trim().isEmpty) {
      throw const AdminBackendException('A role key is required.',
          key: 'admin.role.invalid');
    }
    if (_roles.any((r) => r.key == role.key)) {
      throw AdminBackendException('A role "${role.key}" already exists.',
          key: 'admin.role.duplicate');
    }
    _roles.add(role);
    return role;
  }

  @override
  Future<RoleDto> updateRole(String key, RoleDto role) async {
    _requireAdmin();
    final index = _roles.indexWhere((r) => r.key == key);
    if (index < 0) {
      throw AdminBackendException('No role with key "$key".',
          key: 'admin.role.not_found');
    }
    final updated = RoleDto(key: key, name: role.name);
    _roles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteRole(String key) async {
    _requireAdmin();
    _roles.removeWhere((r) => r.key == key);
  }

  // ----- Groups ------------------------------------------------------------

  @override
  Future<List<GroupDto>> listGroups() async {
    _requireAdmin();
    return [for (final group in _groups) _copyGroup(group)];
  }

  @override
  Future<GroupDto> createGroup(GroupDto group) async {
    _requireAdmin();
    final created = GroupDto(
      id: 'g-${_nextId++}',
      name: group.name,
      memberUserIds: group.memberUserIds,
    );
    _groups.add(created);
    return _copyGroup(created);
  }

  @override
  Future<GroupDto> updateGroup(String id, GroupDto group) async {
    _requireAdmin();
    final index = _groups.indexWhere((g) => g.id == id);
    if (index < 0) {
      throw AdminBackendException('No group with id "$id".',
          key: 'admin.group.not_found');
    }
    final updated = GroupDto(
      id: id,
      name: group.name,
      memberUserIds: group.memberUserIds,
    );
    _groups[index] = updated;
    return _copyGroup(updated);
  }

  @override
  Future<void> deleteGroup(String id) async {
    _requireAdmin();
    _groups.removeWhere((g) => g.id == id);
  }

  // ----- Grants + assignments ----------------------------------------------

  @override
  Future<GrantMatrixDto> getGrants() async {
    _requireAdmin();
    return GrantMatrixDto(_grants);
  }

  @override
  Future<void> putGrants(GrantMatrixDto matrix) async {
    _requireAdmin();
    _grants
      ..clear()
      ..addAll({
        for (final role in matrix.roles)
          role: {
            for (final grade in matrix.gradesFor(role))
              grade.resourceKey: grade.access,
          },
      });
  }

  @override
  Future<void> assign(AssignmentRequest request) async {
    _requireAdmin();
    if (_users.every((u) => u.id != request.userId)) {
      throw AdminBackendException('No user with id "${request.userId}".',
          key: 'admin.user.not_found');
    }
    if (request.roleKey.isNotEmpty) {
      if (_roles.every((r) => r.key != request.roleKey)) {
        throw AdminBackendException('No role with key "${request.roleKey}".',
            key: 'admin.role.not_found');
      }
      (_userRoles[request.userId] ??= <String>{}).add(request.roleKey);
    }
    if (request.groupId.isNotEmpty) {
      final index = _groups.indexWhere((g) => g.id == request.groupId);
      if (index < 0) {
        throw AdminBackendException('No group with id "${request.groupId}".',
            key: 'admin.group.not_found');
      }
      final group = _groups[index];
      if (!group.memberUserIds.contains(request.userId)) {
        _groups[index] = GroupDto(
          id: group.id,
          name: group.name,
          memberUserIds: [...group.memberUserIds, request.userId],
        );
      }
    }
  }

  /// The role keys assigned to [userId] (test introspection; the seam has no
  /// read-back for a user's roles).
  Set<String> rolesOf(String userId) =>
      Set.unmodifiable(_userRoles[userId] ?? const <String>{});

  // ----- Access resolution -------------------------------------------------

  /// Asserts an active session that holds the `admin` role, mirroring the
  /// server's `@TomRoleAccess(['admin'])` gate. Throws `admin.no_session` when no
  /// one is logged in and `admin.access.forbidden` for a non-admin principal.
  void _requireAdmin() {
    final id = _currentUserId;
    if (id == null) {
      throw const AdminBackendException('Not logged in.',
          key: 'admin.no_session');
    }
    if (!(_userRoles[id]?.contains('admin') ?? false)) {
      throw const AdminBackendException(
        'Administrator access is required.',
        key: 'admin.access.forbidden',
      );
    }
  }

  UserDto _copyUser(UserDto s) => UserDto(
        id: s.id,
        username: s.username,
        displayName: s.displayName,
        email: s.email,
        status: s.status,
      );

  GroupDto _copyGroup(GroupDto s) => GroupDto(
        id: s.id,
        name: s.name,
        memberUserIds: s.memberUserIds,
      );
}
