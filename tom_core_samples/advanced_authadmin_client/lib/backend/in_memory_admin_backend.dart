/// The default backend: a seeded, fully working in-memory [AdminBackend].
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
/// exactly the contract-declared `TomRoleAccess(['admin'])` gate
/// (`TomApiEndpoint.access`) the live server's pipeline enforces on each
/// endpoint. A signed-in non-admin is refused with `admin.access.forbidden`, the
/// stable key the shell's `AdminSession.login` rejects a non-admin login on.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'admin_backend.dart';

/// An in-memory implementation of [AdminBackend], seeded with demo data.
class InMemoryAdminBackend implements AdminBackend {
  /// Creates the backend and seeds its users, roles, groups and grant matrix.
  ///
  /// [files] replaces the blob store, which is what lets a caller hold the store
  /// it planted an avatar in. Left unset it is a fresh
  /// [TomMemoryFileTransferClient] — the shape the console installs offline,
  /// where nobody is holding it.
  ///
  /// [twoFactorUsernames] enrols the named accounts in TOTP. It defaults to
  /// **empty**, because the live `auth_db` enrols no administrator and this
  /// backend's job is to mirror it — an offline console that demanded a code the
  /// real one does not would teach the wrong thing. It is a parameter rather
  /// than a constant because an enrolment is an *account* property the console
  /// does not control: the day someone enrols `admin`, the console must still
  /// work, and this is what lets a test prove it does without a server.
  InMemoryAdminBackend({
    TomFileTransferClient? files,
    Set<String> twoFactorUsernames = const {},
  })  : files = files ?? TomMemoryFileTransferClient(),
        _twoFactorUsernames = twoFactorUsernames {
    _seed();
  }

  /// The offline blob store standing in for the auth server's file endpoint.
  ///
  /// The kernel's own in-memory transfer client, so the avatar field runs its
  /// *real* code path offline — pick, upload, progress, cancel, describe,
  /// download, delete — against the same slot addresses the live server serves.
  @override
  final TomFileTransferClient files;

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

  /// The usernames enrolled in TOTP (see the constructor).
  final Set<String> _twoFactorUsernames;

  /// The challenge a two-factor [login] left outstanding, and the user it
  /// belongs to. Both null unless a login is half finished — which is exactly
  /// when [_currentUserId] is still null, so every admin call is refused.
  Tom2FAChallenge? _pendingChallenge;
  String? _pendingUserId;

  int _nextId = 100;
  String? _currentUserId;

  /// The base32 TOTP secret an enrolled demo account carries — RFC 6238's own
  /// test vector, the same one the auth server seeds for `dave`.
  static const String demoTotpSecret = 'JBSWY3DPEHPK3PXP';

  /// The TOTP policy, mirroring `TomTotp2FAService`'s `globalSetting*` statics
  /// (which live in `tom_core_server`, out of a Flutter app's reach). The
  /// *verification* is not restated: [submitSecondFactor] runs the kernel's own
  /// [TomTotp].
  static const int totpDigits = TomTotp.defaultDigits;

  /// The mechanism key challenges are issued under.
  static const String totpMechanism = 'totp';

  /// One TOTP time step, in seconds.
  static const int totpPeriodSeconds = 30;

  /// One TOTP time step.
  static const Duration totpPeriod = Duration(seconds: totpPeriodSeconds);

  /// Steps either side of "now" accepted, tolerating clock skew.
  static const int totpWindowSteps = 1;

  /// Submissions one challenge tolerates before it is spent.
  static const int totpAttemptsAllowed = 3;

  /// How long a challenge stays answerable.
  static const Duration totpChallengeValidity = Duration(minutes: 5);

  /// The shared demo password every seeded account accepts.
  static const String demoPassword = 'pw';

  /// The canned public login bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.loginBundle()` so the offline console installs
  /// the exact same sign-in chrome the live auth server serves — the widget
  /// tests stay socket-free while still proving the screen renders
  /// *server-delivered* texts. The console reads the `adminLogin.*` /
  /// `adminTwoFactor.*` keys; the `login.*` scope is mirrored verbatim for
  /// fidelity, while the app client's sibling `twoFactor.*` scope is left out —
  /// no console widget can address it.
  static const Map<String, Object?> loginTexts = {
    'login.title': 'Advanced Todo — Sign in',
    'login.intro':
        'Try alice, bob or carol (any non-empty password), dave to be challenged '
            'for a second factor, or erin to be offered one.',
    'login.username.label': 'Username',
    'login.username.hint': 'alice, bob, carol, dave or erin',
    'login.password.label': 'Password',
    'login.submit': 'Sign in',
    'adminLogin.title': 'Advanced Todo — Admin sign in',
    'adminLogin.intro':
        'Sign in as admin (password pw). A non-admin (alice, bob, carol) is rejected.',
    'adminLogin.username.label': 'Username',
    'adminLogin.username.hint': 'admin',
    'adminLogin.password.label': 'Password',
    'adminLogin.submit': 'Sign in',
    'adminTwoFactor.title': 'Advanced Todo — Admin two-step verification',
    'adminTwoFactor.intro':
        'Enter the {digits}-digit code from your authenticator app.',
    'adminTwoFactor.code.label': 'Verification code',
    'adminTwoFactor.code.hint': '000000',
    'adminTwoFactor.submit': 'Verify',
    'adminTwoFactor.cancel': 'Back to sign in',
    'adminTwoFactor.attemptsRemaining': '{count} attempt(s) remaining.',
  };

  /// The canned authenticated console bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.adminConsoleBundle()` — the reflected editors'
  /// field labels (`user.*`/`role.*`/`group.*`, keyed `<formId>.<tomId>.label`)
  /// and the grant-matrix screen texts, plus the `adminConsole.title` shell
  /// chrome (no form override, no grade counterpart). The session installs this
  /// right after an admin sign-in so every console screen renders
  /// server-delivered texts while the widget tests stay socket-free.
  static const Map<String, Object?> fullTexts = {
    'adminConsole.title': 'Advanced Todo — Admin console',
    'adminConsole.signOut': 'Sign out',
    'adminConsole.nav.users': 'Users',
    'adminConsole.nav.roles': 'Roles',
    'adminConsole.nav.groups': 'Groups',
    'adminConsole.nav.grants': 'Grants',
    'adminConsole.nav.assignments': 'Assignments',
    'user.username.label': 'Username',
    'user.password.label': 'Password',
    'user.displayName.label': 'Display name',
    'user.email.label': 'Email',
    'user.status.label': 'Status',
    'user.status.active': 'Active',
    'user.status.suspended': 'Suspended',
    'role.key.label': 'Key',
    'role.name.label': 'Name',
    'group.name.label': 'Name',
    'grants.title': 'Grant matrix',
    'grants.unsaved': 'Unsaved changes',
    // No `grants.column.*` wording here: the matrix cells label themselves from
    // the framework's own state names (`global.tomauthstate.<name>`, seeded
    // below), which is what keeps the matrix reading the same as every other
    // place a `TomAuthState` is rendered.
    'grants.save': 'Save grants',
    'grants.empty': 'No grants to edit.',
    'grants.roleColumn': 'Role',
    // Shared admin console chrome (dialogs, CRUD list actions, assignments).
    'admin.cancel': 'Cancel',
    'admin.save': 'Save',
    'admin.delete.label': 'Delete',
    'admin.delete.confirm': 'Delete "{name}"?',
    'admin.users.create': 'New user',
    'admin.users.edit': 'Edit user',
    'admin.users.empty': 'No users yet.',
    // The avatar's own chrome. Under `admin.users.*` with the rest of this
    // screen's wording, not under `user.*`: the `user.<member>.label` keys are
    // the reflected editor's *bound field* labels, and the avatar is not a bound
    // member of `UserDraft` — it is a file slot that transfers on pick.
    'admin.users.avatar.label': 'Avatar',
    'admin.users.avatar.description':
        'Uploads as soon as you pick it — Save is not needed.',
    'admin.users.avatar.downloaded': 'Downloaded {name} ({size})',
    'admin.roles.create': 'New role',
    'admin.roles.edit': 'Edit role',
    'admin.roles.empty': 'No roles yet.',
    'admin.groups.create': 'New group',
    'admin.groups.edit': 'Edit group',
    'admin.groups.empty': 'No groups yet.',
    'admin.groups.members': 'Members',
    'admin.groups.memberCount': '{count} member',
    'admin.groups.memberCountPlural': '{count} members',
    // The framework's file-field chrome, worded at the global level
    // `TomFileLabels` resolves it from — one wording for every file field in the
    // console. Mirrors the auth server bundle's `file.*` / `file_transfer.*` /
    // `error.file*` blocks, and reads "image" rather than "file" because the one
    // file field this console has is an avatar.
    'file.choose': 'Choose image…',
    'file.none': '— no avatar set',
    'file.dropzoneHint': 'Tap to choose an image',
    'file.selected': '{name} ({size})',
    'file.download': 'Download',
    'file.clear': 'Remove',
    'file.cancel': 'Cancel',
    'file.retry': 'Retry',
    'file.uploading': 'Uploading {percent}%',
    'file.downloading': 'Downloading {percent}%',
    'file.uploadingBusy': 'Uploading…',
    'file.downloadingBusy': 'Downloading…',
    'file.uploaded': 'Uploaded.',
    'file.downloaded': 'Downloaded.',
    'file.removed': 'Removed.',
    'file.done': 'Done.',
    'file.cancelled': 'Transfer cancelled.',
    'file.rejectedTitle': 'File rejected',
    'file.rejectedDismiss': 'OK',
    'error.fileExtension': 'Avatars must be a PNG or a JPEG.',
    'error.fileTooLarge': 'That image is too large.',
    'file_transfer.not_found': 'That file is no longer on the server.',
    'file_transfer.rejected': 'The server refused that file.',
    'file_transfer.cancelled': 'Transfer cancelled.',
    'file_transfer.invalid_slot': 'That file location is not valid.',
    'file_transfer.invalid_descriptor': 'The server sent an unreadable response.',
    'admin.assignments.title': 'Assign roles and groups',
    'admin.assignments.assignTo': 'Assign to {name}',
    'admin.assignments.assigned': 'Assigned to {name}.',
    'admin.assignments.chooseError': 'Choose a role or a group to assign.',
    'admin.assignments.assign': 'Assign',
    'admin.assignments.noGroups': 'No groups',
    'admin.assignments.groups': 'Groups: {groups}',
    'admin.assignments.roleLabel': 'Role',
    'admin.assignments.noRole': '— No role —',
    'admin.assignments.groupLabel': 'Group',
    'admin.assignments.noGroup': '— No group —',
    // Enum display text (G-RES-5) for the kernel's TomAuthState, keyed
    // `global.tomauthstate.<value>`; the grant-matrix cells resolve their
    // four-state labels from here rather than a hardcoded switch.
    'global.tomauthstate.none': 'Hidden',
    'global.tomauthstate.disabled': 'Disabled',
    'global.tomauthstate.read': 'Read',
    'global.tomauthstate.full': 'Full',
  };

  /// The four-state field resource keys, mirroring the server's wire keys
  /// (`todo.item.*`). Held as plain strings because the admin console is
  /// domain-agnostic: it edits whatever resource keys the server reports.
  static const String _kTitle = 'todo.item.title';
  static const String _kStatus = 'todo.item.status';
  static const String _kPriority = 'todo.item.priority';
  static const String _kAssigneeId = 'todo.item.assigneeId';
  static const String _kDueDate = 'todo.item.dueDate';
  static const String _kEstimate = 'todo.item.estimate';
  static const String _kDescription = 'todo.item.description';

  /// The item's **file column** — graded per role like the seven fields above,
  /// but enforced on the file endpoint rather than in the item payload. It is
  /// part of the same table and the same role rows, so the demo matrix carries
  /// it too: without it the demo console would offer one fewer column than the
  /// live one, and the screen it teaches would not be the screen that ships.
  static const String _kAttachment = 'todo.item.attachment';

  void _seed() {
    // Demo accounts mirror the app client's (alice/bob/carol) plus a dedicated
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
    user('u-carol', 'carol', 'Carol (viewer)', const ['viewer']);

    // The application roles: the `admin` console role plus the four project
    // roles the grant matrix grades.
    _roles.addAll([
      RoleDto(key: 'admin', name: 'Administrator'),
      RoleDto(key: 'owner', name: 'Owner'),
      RoleDto(key: 'editor', name: 'Editor'),
      RoleDto(key: 'commenter', name: 'Commenter'),
      RoleDto(key: 'viewer', name: 'Viewer'),
    ]);

    _groups.add(GroupDto(
      id: 'g-eng',
      name: 'Engineering',
      memberUserIds: const ['u-bob', 'u-carol'],
    ));

    // The four-state grant matrix at the values the auth server's
    // `[003]-auth_demo_seed@dev,test.sql` seeds, so the demo console opens on the
    // same matrix the live one does. It is re-typed rather than imported: this
    // console is domain-agnostic on purpose (it edits whatever resource keys the
    // server reports), so it does not depend on advanced_todo_domain and cannot
    // read `projectRoleFieldGrades`.
    _grants.addAll({
      'owner': {
        _kTitle: TomAuthState.full,
        _kStatus: TomAuthState.full,
        _kPriority: TomAuthState.full,
        _kAssigneeId: TomAuthState.full,
        _kDueDate: TomAuthState.full,
        _kEstimate: TomAuthState.full,
        _kDescription: TomAuthState.full,
        _kAttachment: TomAuthState.full,
      },
      'editor': {
        _kTitle: TomAuthState.full,
        _kStatus: TomAuthState.full,
        _kPriority: TomAuthState.full,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.full,
        _kEstimate: TomAuthState.read,
        _kDescription: TomAuthState.full,
        _kAttachment: TomAuthState.full,
      },
      'commenter': {
        _kTitle: TomAuthState.read,
        _kStatus: TomAuthState.read,
        _kPriority: TomAuthState.none,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.read,
        _kEstimate: TomAuthState.none,
        _kDescription: TomAuthState.read,
        _kAttachment: TomAuthState.read,
      },
      'viewer': {
        _kTitle: TomAuthState.read,
        _kStatus: TomAuthState.disabled,
        _kPriority: TomAuthState.read,
        _kAssigneeId: TomAuthState.read,
        _kDueDate: TomAuthState.read,
        _kEstimate: TomAuthState.none,
        _kDescription: TomAuthState.read,
        _kAttachment: TomAuthState.read,
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
    // A new login abandons whatever challenge was outstanding.
    _clearChallenge();

    if (_twoFactorUsernames.contains(key)) {
      // Pass 1 of two: the password was right, but this is not a session, so
      // `_currentUserId` stays null and every admin call is still refused —
      // mirroring the live interim token, which authorizes nothing.
      _pendingUserId = match.id;
      _pendingChallenge = Tom2FAChallenge(
        type: totpMechanism,
        expiresAt: DateTime.now().toUtc().add(totpChallengeValidity),
        attemptsAllowed: totpAttemptsAllowed,
        clientData: const {
          'digits': totpDigits,
          'periodSeconds': totpPeriodSeconds,
        },
      );
      return LoginResult(
        user: match,
        requires2FA: true,
        twoFactorType: totpMechanism,
        authToken: 'demo-2fa-challenge-$key',
        authzToken: 'demo-2fa-challenge-$key',
        expiresAt: _pendingChallenge!.expiresAt,
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
  Tom2FAChallenge? get pendingChallenge => _pendingChallenge;

  @override
  Future<LoginResult> submitSecondFactor(String code) async {
    final challenge = _pendingChallenge;
    final userId = _pendingUserId;
    if (challenge == null || userId == null) {
      throw const AdminBackendException(
        'No pending two-factor challenge — sign in first.',
        key: 'login.error.2fa.no-challenge',
      );
    }
    if (challenge.isExpired()) {
      _clearChallenge();
      throw const AdminBackendException(
        'The two-factor challenge has expired.',
        key: 'login.error.2fa.expired',
      );
    }

    // Spend the attempt *before* verifying, as the server does: the count must
    // move whether or not the code turns out to be right.
    final consumed = challenge.withConsumedAttempt();
    if (_verifyTotp(demoTotpSecret, code)) {
      _clearChallenge();
      _currentUserId = userId;
      final user = _users.firstWhere((u) => u.id == userId);
      return LoginResult(
        user: user,
        authToken: 'demo-auth-${user.username}',
        authzToken: 'demo-authz-${user.username}',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
    }

    if (consumed.isExhausted) {
      _clearChallenge();
      throw const AdminBackendException(
        'No two-factor attempts remain. Sign in again.',
        key: 'login.error.2fa.attempts-exhausted',
      );
    }
    _pendingChallenge = consumed;
    throw const AdminBackendException(
      'That code is not valid.',
      key: 'login.error.2fa.invalid-code',
      canRetrySecondFactor: true,
    );
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
    _clearChallenge();
  }

  void _clearChallenge() {
    _pendingChallenge = null;
    _pendingUserId = null;
  }

  /// Whether [code] is a TOTP code for [secret] within the accepted skew
  /// window, using the kernel's own generator so the offline backend accepts
  /// exactly what the server does.
  bool _verifyTotp(String secret, String code) {
    final submitted = code.trim();
    if (submitted.length != totpDigits) return false;
    final key = TomTotp.decodeBase32(secret);
    if (key.isEmpty) return false;
    final counter = TomTotp.counterFor(period: totpPeriod);
    for (var offset = -totpWindowSteps; offset <= totpWindowSteps; offset++) {
      if (TomTotp.generateCode(key, counter + offset, totpDigits) == submitted) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<ResourceBundleDto> loginResources() async =>
      ResourceBundleDto(Map<String, Object?>.from(loginTexts));

  @override
  Future<ResourceBundleDto> resources() async {
    // The console bundle is admin-gated, exactly like the live
    // `GET /admin/resources` endpoint's contract-declared
    // `TomRoleAccess(['admin'])` (`TomApiEndpoint.access`).
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
              grade.resourceKey: grade.accessState,
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
  /// server's contract-declared `TomRoleAccess(['admin'])` gate
  /// (`TomApiEndpoint.access`). Throws `admin.no_session` when no
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
