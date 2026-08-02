/// The default backend: a seeded, fully working in-memory [AppBackend] (step 26).
///
/// It mirrors what `advanced_app_server` exposes — the same demo accounts, a
/// small workspace→project→list→item tree, and the **same per-resource role
/// grants** the auth server seeds — so the client behaves identically whether it
/// runs against this backend (the offline teaching default, and what the widget
/// tests drive) or the live stack. Keeping the ownership/share model here in one
/// place is what lets the four ACL states render distinctly without a server or
/// database: [resourceRoles] exposes each accessible resource's [ProjectRole],
/// which the app installs as a framework [TomResourceRoleAdapter] and the item
/// screen narrows by the shared [projectRoleFieldGrades] matrix.
///
/// The principal is implicit in the session: [login] records the current user,
/// and every later call filters by what that user owns or is shared into and
/// resolves their effective [ProjectRole] on the resource — exactly the seam the
/// live server enforces from the bearer token.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_backend.dart';

/// An in-memory implementation of [AppBackend], seeded with demo data.
class InMemoryAppBackend implements AppBackend {
  /// Creates the backend and seeds its users, resource tree and shares.
  /// Builds the seeded offline backend.
  ///
  /// [files] replaces the blob store, which is what lets a caller hold the store
  /// it planted bytes in, or wrap it to suspend a transfer mid-flight. Left
  /// unset it is a fresh [TomMemoryFileTransferClient] — the shape `main`
  /// installs for the `test` environment, where nobody is holding it.
  InMemoryAppBackend({TomFileTransferClient? files})
      : files = files ?? TomMemoryFileTransferClient() {
    _seed();
  }

  final List<UserDto> _users = [];
  final List<Workspace> _workspaces = [];
  final List<Project> _projects = [];
  final List<TodoList> _lists = [];
  final List<TodoItem> _items = [];
  final List<TodoComment> _comments = [];

  /// Active shares: each maps a resource to a grantee at a [ProjectRole].
  final List<ShareRequest> _shares = [];

  /// The offline blob store, standing in for the server's file endpoint.
  ///
  /// By default the kernel's own in-memory transfer client, so the file field
  /// the board wires (upload / progress / cancel / download / delete) runs its
  /// *real* code path offline — and [listAttachments] answers from the same
  /// store the upload wrote to, exactly as the server's `HEAD` does.
  @override
  final TomFileTransferClient files;

  int _nextId = 100;
  String? _currentUserId;

  /// The challenge a two-factor [login] left outstanding, and the user it
  /// belongs to. Both null unless a login is half finished — which is precisely
  /// the state in which [_currentUserId] is still null, so no data call
  /// succeeds.
  Tom2FAChallenge? _pendingChallenge;
  String? _pendingUserId;

  /// The canned public login bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.loginBundle()` (D-A11) so the offline app installs the
  /// exact same sign-in chrome the live auth server serves — the widget tests
  /// stay socket-free while still proving the screen renders *server-delivered*
  /// texts.
  static const Map<String, Object?> loginTexts = {
    'login.title': 'Advanced Todo — Sign in',
    'login.intro':
        'Try alice, bob or carol (any non-empty password), or dave for two-step verification.',
    'login.username.label': 'Username',
    'login.username.hint': 'alice, bob, carol or dave',
    'login.password.label': 'Password',
    'login.submit': 'Sign in',
    'twoFactor.title': 'Advanced Todo — Two-step verification',
    'twoFactor.intro': 'Enter the {digits}-digit code from your authenticator '
        'app.',
    'twoFactor.code.label': 'Verification code',
    'twoFactor.code.hint': '000000',
    'twoFactor.submit': 'Verify',
    'twoFactor.cancel': 'Back to sign in',
    'twoFactor.attemptsRemaining': '{count} attempt(s) remaining.',
    'adminLogin.title': 'Advanced Todo — Admin sign in',
    'adminLogin.intro':
        'Sign in as admin (password pw). A non-admin (alice, bob, carol) is rejected.',
    'adminLogin.username.label': 'Username',
    'adminLogin.username.hint': 'admin',
    'adminLogin.password.label': 'Password',
    'adminLogin.submit': 'Sign in',
  };

  /// The canned authenticated full bundle, mirroring `advanced_app_server`'s
  /// `AppResourceBundles.appBundle()` (D-A11) — the item-form field labels
  /// (keyed `todo.item.<field>.label` so the label key tracks the grade key)
  /// plus the `board.*` chrome that has no grade counterpart. The session
  /// installs this right after sign-in so every post-login screen renders
  /// server-delivered texts while the widget tests stay socket-free.
  static const Map<String, Object?> fullTexts = {
    'todo.item.title.label': 'Title',
    'todo.item.status.label': 'Status',
    'todo.item.priority.label': 'Priority',
    'todo.item.assigneeId.label': 'Assignee id',
    'todo.item.dueDate.label': 'Due date',
    'todo.item.estimate.label': 'Estimate (h)',
    'todo.item.description.label': 'Description',
    'board.title': 'My Board',
    'board.empty': 'No items yet',
    'board.signedInAs': 'Signed in as {name}',
    'board.workspace': 'Workspace',
    'board.project': 'Project',
    'board.emptyProject': 'No items in this project yet.',
    'board.shared': 'Project shared',
    'board.shareTooltip': 'Share project',
    'board.signOut': 'Sign out',
    'board.item.save': 'Save',
    'board.item.delete': 'Delete',
    'board.item.loadError': 'Could not load item.',
    // The attachment's own chrome. Under `board.*`, never `todo.item.*`: the
    // server derives its gradable field set from the `todo.item.*` keys, and
    // the attachment is a file slot authorized by the item's resource state,
    // not an eighth graded field.
    'board.item.attachment.label': 'Attachment',
    'board.item.attachment.description':
        'One file per task. It uploads as soon as you pick it.',
    'board.item.attachment.present': 'Has an attachment ({size})',
    'board.item.attachment.downloaded': 'Downloaded {name} ({size})',
    'board.item.comment.add': 'Add comment',
    'board.item.comment.title': 'Add a comment',
    'board.item.comment.hint': 'Write a comment…',
    'board.item.comment.submit': 'Post comment',
    'board.item.comment.added': 'Comment added',
    'board.share': 'Share',
    'share.title': 'Share project',
    'share.granteeRequired': 'Enter a grantee user id (e.g. u-carol).',
    'share.grantee.label': 'Grantee user id',
    'share.grantee.hint': 'u-carol',
    'share.role': 'Role',
    'share.cancel': 'Cancel',
    // The framework's file-field chrome, worded at the global level
    // `TomFileLabels` resolves it from — one wording for every file field in
    // the app. Mirrors the server bundle's `file.*` / `file_transfer.*` /
    // `error.file*` blocks.
    'file.choose': 'Choose file…',
    'file.none': '— no file attached',
    'file.dropzoneHint': 'Tap to choose a file',
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
    'error.fileExtension': 'That file type is not allowed.',
    'error.fileTooLarge': 'That file is too large.',
    'file_transfer.not_found': 'That file is no longer on the server.',
    'file_transfer.rejected': 'The server refused that file.',
    'file_transfer.cancelled': 'Transfer cancelled.',
    'file_transfer.invalid_slot': 'That file location is not valid.',
    'file_transfer.invalid_descriptor':
        'The server sent an unreadable response.',
    // Enum display text (G-RES-5), keyed `global.<enumtype>.<value>`. Mirrors the
    // server's `assets/resources_app.json` `global.*` tree; the domain enums
    // carry no hardcoded strings, so the board columns, item dropdowns and the
    // share role picker resolve their text from here.
    'global.todostatus.backlog': 'Backlog',
    'global.todostatus.todo': 'To do',
    'global.todostatus.inprogress': 'In progress',
    'global.todostatus.inreview': 'In review',
    'global.todostatus.done': 'Done',
    'global.todostatus.cancelled': 'Cancelled',
    'global.todopriority.low': 'Low',
    'global.todopriority.medium': 'Medium',
    'global.todopriority.high': 'High',
    'global.todopriority.critical': 'Critical',
    'global.todolabel.feature': 'Feature',
    'global.todolabel.bug': 'Bug',
    'global.todolabel.chore': 'Chore',
    'global.todolabel.docs': 'Docs',
    'global.todolabel.research': 'Research',
    'global.projectrole.owner': 'Owner',
    'global.projectrole.editor': 'Editor',
    'global.projectrole.commenter': 'Commenter',
    'global.projectrole.viewer': 'Viewer',
  };

  /// The demo accounts, by username → user id. The password is not verified
  /// beyond being non-empty — this is a teaching backend, not a credential
  /// store.
  static const Map<String, String> demoAccounts = {
    'alice': 'u-alice',
    'bob': 'u-bob',
    'carol': 'u-carol',
    'dave': 'u-dave',
  };

  /// The accounts enrolled in TOTP, by user id → base32 secret.
  ///
  /// `dave` carries the same secret the auth server's
  /// `[005]-auth_two_factor_seed` migration seeds (RFC 6238's own test vector),
  /// so a code that satisfies the offline backend satisfies the live one and
  /// the README's instructions hold either way.
  static const Map<String, String> twoFactorSecrets = {
    'u-dave': 'JBSWY3DPEHPK3PXP',
  };

  /// The TOTP policy, mirroring `TomTotp2FAService`'s `globalSetting*` statics.
  ///
  /// Restated here rather than imported because that adaptor lives in
  /// `tom_core_server`, which a Flutter app cannot depend on. The *verification*
  /// is not restated: [submitSecondFactor] runs the kernel's own [TomTotp], so
  /// the offline backend accepts exactly the codes the server accepts instead of
  /// approximating them.
  static const int totpDigits = TomTotp.defaultDigits;

  /// The mechanism key the challenge is issued under — `TomTotp2FAService`'s
  /// `mechanismType`, which lives server-side.
  static const String totpMechanism = 'totp';

  /// One TOTP time step, in seconds (RFC 6238 default).
  static const int totpPeriodSeconds = 30;

  /// One TOTP time step (RFC 6238 default).
  static const Duration totpPeriod = Duration(seconds: totpPeriodSeconds);

  /// Steps either side of "now" accepted, tolerating clock skew.
  static const int totpWindowSteps = 1;

  /// Submissions one challenge tolerates before it is spent.
  static const int totpAttemptsAllowed = 3;

  /// How long a challenge stays answerable.
  static const Duration totpChallengeValidity = Duration(minutes: 5);

  void _seed() {
    void user(String id, String username, String name) => _users.add(UserDto(
          id: id,
          username: username,
          displayName: name,
          email: '$username@todo.example',
        ));
    user('u-alice', 'alice', 'Alice (owner)');
    user('u-bob', 'bob', 'Bob (editor)');
    user('u-carol', 'carol', 'Carol (viewer)');
    // Dave owns nothing and is shared into nothing — deliberately, because the
    // live `app_db` seeds him the same way. He exists here for the *second
    // factor*, so signing in as him proves the two-pass flow and then lands on
    // the board's empty state, exactly as it does against the real servers.
    user('u-dave', 'dave', 'Dave Dijkstra (2FA)');

    _workspaces.add(Workspace()
      ..id.set('w-1')
      ..name.set('Acme Engineering')
      ..ownerId.set('u-alice'));

    _projects.add(Project()
      ..id.set('p-1')
      ..workspaceId.set('w-1')
      ..name.set('Website relaunch')
      ..description.set('The Q3 marketing-site rebuild.')
      ..colour.set('#3366FF'));

    _lists.add(TodoList()
      ..id.set('l-1')
      ..projectId.set('p-1')
      ..name.set('Sprint backlog')
      ..position.set(0));

    _items.add(TodoItem()
      ..id.set('i-1')
      ..listId.set('l-1')
      ..title.set('Draft the landing copy')
      ..description.set('First pass at the hero section.')
      ..statusValue = TodoStatus.todo
      ..priorityValue = TodoPriority.high
      ..labelValue = TodoLabel.docs
      ..assigneeId.set('u-bob')
      ..reporterId.set('u-alice'));
    _items.add(TodoItem()
      ..id.set('i-2')
      ..listId.set('l-1')
      ..title.set('Wire the contact form')
      ..statusValue = TodoStatus.inProgress
      ..priorityValue = TodoPriority.medium
      ..labelValue = TodoLabel.feature
      ..reporterId.set('u-alice'));

    // Bob is shared into the project as an editor; Carol starts with no access
    // (the share test grants it).
    _shares.add(ShareRequest(
      resourceType: 'project',
      resourceId: 'p-1',
      granteeUserId: 'u-bob',
      projectRole: ProjectRole.editor,
    ));
  }

  /// The id of the logged-in principal, or throws if no session is active.
  String get _principalId {
    final id = _currentUserId;
    if (id == null) {
      throw const AppBackendException('Not logged in.', key: 'app.no_session');
    }
    return id;
  }

  @override
  Future<LoginResult> login(LoginRequest request) async {
    final key = request.username.trim().toLowerCase();
    final id = demoAccounts[key];
    if (id == null) {
      throw const AppBackendException(
        'Unknown account. Try alice, bob, carol or dave.',
        key: 'auth.login.failed',
      );
    }
    if (request.password.isEmpty) {
      throw const AppBackendException(
        'Password must not be empty.',
        key: 'auth.login.failed',
      );
    }
    // A new login abandons whatever challenge was outstanding.
    _pendingChallenge = null;
    _pendingUserId = null;
    final user = _users.firstWhere((u) => u.id == id);

    if (twoFactorSecrets.containsKey(id)) {
      // Pass 1 of two: the password was right, but this is *not* a session.
      // `_currentUserId` stays null, so every other method throws
      // `app.no_session` until [submitSecondFactor] completes the login —
      // mirroring the live interim token, which authorizes nothing.
      _pendingUserId = id;
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
        user: user,
        requires2FA: true,
        twoFactorType: totpMechanism,
        authToken: 'demo-2fa-challenge-$key',
        authzToken: 'demo-2fa-challenge-$key',
        expiresAt: _pendingChallenge!.expiresAt,
      );
    }

    _currentUserId = id;
    return LoginResult(
      user: user,
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
      throw const AppBackendException(
        'No pending two-factor challenge — sign in first.',
        key: 'login.error.2fa.no-challenge',
      );
    }
    if (challenge.isExpired()) {
      _clearChallenge();
      throw const AppBackendException(
        'The two-factor challenge has expired.',
        key: 'login.error.2fa.expired',
      );
    }

    // Spend the attempt *before* verifying, as the server does: the count must
    // move whether or not the code turns out to be right, or a client could
    // retry forever.
    final consumed = challenge.withConsumedAttempt();
    if (_verifyTotp(twoFactorSecrets[userId]!, code)) {
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
      throw const AppBackendException(
        'No two-factor attempts remain. Sign in again.',
        key: 'login.error.2fa.attempts-exhausted',
      );
    }
    // Retryable: keep the challenge with the attempt spent, so the next call
    // counts against a state the caller cannot roll back — the same reason the
    // live client stores the re-issued interim token before it throws.
    _pendingChallenge = consumed;
    throw const AppBackendException(
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
  Future<ResourceBundleDto> resources() async =>
      ResourceBundleDto(Map<String, Object?>.from(fullTexts));

  @override
  Future<List<Workspace>> listWorkspaces() async {
    final principal = _principalId;
    return [
      for (final w in _workspaces)
        if (_canSeeWorkspace(w, principal)) _copyWorkspace(w),
    ];
  }

  @override
  Future<List<Project>> listProjects(String workspaceId) async {
    final principal = _principalId;
    return [
      for (final p in _projects)
        if (p.workspaceId.get() == workspaceId &&
            _roleOnProject(p, principal) != null)
          _copyProject(p),
    ];
  }

  @override
  Future<List<TodoList>> listLists(String projectId) async {
    final principal = _principalId;
    final project = _projectById(projectId);
    if (project == null || _roleOnProject(project, principal) == null) {
      return const [];
    }
    return [
      for (final l in _lists)
        if (l.projectId.get() == projectId) _copyList(l),
    ];
  }

  @override
  Future<List<TodoItem>> listItems(String listId) async {
    final principal = _principalId;
    final project = _projectOfList(listId);
    if (project == null || _roleOnProject(project, principal) == null) {
      return const [];
    }
    final visible = [
      for (final item in _items)
        if (item.listId.get() == listId) _copyItem(item),
    ];
    // The attachment key is stamped from the blob store, never carried on the
    // stored item — mirroring the server, where the file columns are absent
    // from the writable bindings so a client cannot mint a storage key.
    for (final item in visible) {
      final stored = await files.describe(AppFileSlots.itemAttachment(item.id.get()));
      item.attachment.set(stored?.key ?? '');
    }
    return visible;
  }

  @override
  Future<List<FileDescriptorDto>> listAttachments(String listId) async {
    final descriptors = <FileDescriptorDto>[];
    for (final item in await listItems(listId)) {
      final slot = AppFileSlots.itemAttachment(item.id.get());
      final stored = await files.describe(slot);
      if (stored == null) continue;
      descriptors.add(FileDescriptorDto.fromMetadata(slot, stored));
    }
    return descriptors;
  }

  @override
  Future<TodoItem> saveItem(TodoItem item) async {
    final principal = _principalId;
    final id = item.id.get();
    if (id.isEmpty) {
      final project = _projectOfList(item.listId.get());
      if (project == null || !_canWrite(_roleOnProject(project, principal))) {
        throw const AppBackendException(
          'You cannot add items to this list.',
          key: 'app.access.forbidden',
        );
      }
      final created = _copyItem(item)..id.set('i-${_nextId++}');
      _items.add(created);
      return _copyItem(created);
    }
    final index = _items.indexWhere((existing) => existing.id.get() == id);
    if (index < 0) {
      throw AppBackendException('No item with id "$id".',
          key: 'app.item.not_found');
    }
    final project = _projectOfList(_items[index].listId.get());
    if (project == null || !_canWrite(_roleOnProject(project, principal))) {
      throw const AppBackendException(
        'You cannot edit this item.',
        key: 'app.access.forbidden',
      );
    }
    _items[index] = _copyItem(item);
    return _copyItem(_items[index]);
  }

  @override
  Future<void> deleteItem(String id) async {
    final principal = _principalId;
    final index = _items.indexWhere((item) => item.id.get() == id);
    if (index < 0) return;
    final project = _projectOfList(_items[index].listId.get());
    if (project == null || !_canWrite(_roleOnProject(project, principal))) {
      throw const AppBackendException(
        'You cannot delete this item.',
        key: 'app.access.forbidden',
      );
    }
    _items.removeAt(index);
  }

  @override
  Future<TodoComment> addComment(String itemId, TodoComment comment) async {
    final principal = _principalId;
    final item = _items.firstWhere(
      (i) => i.id.get() == itemId,
      orElse: () => throw AppBackendException('No item with id "$itemId".',
          key: 'app.item.not_found'),
    );
    final project = _projectOfList(item.listId.get());
    if (project == null || _roleOnProject(project, principal) == null) {
      throw const AppBackendException(
        'You cannot comment on this item.',
        key: 'app.access.forbidden',
      );
    }
    final created = _copyComment(comment)
      ..id.set('c-${_nextId++}')
      ..itemId.set(itemId)
      ..authorId.set(principal);
    _comments.add(created);
    return _copyComment(created);
  }

  @override
  Future<Map<String, String>> resourceRoles() async {
    final principal = _principalId;
    // The principal's effective role on every resource they can reach: each
    // accessible project, and every item within it (the sample grants at project
    // level, so an item inherits its project's role). Keyed `<type>:<id>` (the
    // shared convention), the value is the role's [Enum.name] — exactly the
    // `resourceRoles` claim the live token carries and the app installs as a
    // [TomResourceRoleAdapter].
    final roles = <String, String>{};
    for (final project in _projects) {
      final role = _roleOnProject(project, principal);
      if (role == null) continue;
      roles['${ResourceRoleKeys.projectType}:${project.id.get()}'] = role.name;
      for (final list
          in _lists.where((l) => l.projectId.get() == project.id.get())) {
        for (final item
            in _items.where((i) => i.listId.get() == list.id.get())) {
          roles['${ResourceRoleKeys.itemType}:${item.id.get()}'] = role.name;
        }
      }
    }
    return roles;
  }

  @override
  Future<void> share(ShareRequest request) async {
    final principal = _principalId;
    final project = _projectById(request.resourceId);
    if (request.resourceType != 'project' || project == null) {
      throw const AppBackendException(
        'Only projects can be shared in this demo.',
        key: 'app.share.unsupported',
      );
    }
    if (_roleOnProject(project, principal) != ProjectRole.owner) {
      throw const AppBackendException(
        'Only the owner can share a project.',
        key: 'app.access.forbidden',
      );
    }
    _shares.removeWhere((s) =>
        s.resourceType == request.resourceType &&
        s.resourceId == request.resourceId &&
        s.granteeUserId == request.granteeUserId);
    _shares.add(request);
  }

  // ----- Access resolution -------------------------------------------------

  /// The principal's effective [ProjectRole] on [project], or null when they
  /// have no access: owner of the workspace → owner, else the shared role, else
  /// none.
  ProjectRole? _roleOnProject(Project project, String principal) {
    final workspace = _workspaceById(project.workspaceId.get());
    if (workspace != null && workspace.ownerId.get() == principal) {
      return ProjectRole.owner;
    }
    for (final share in _shares) {
      if (share.resourceType == 'project' &&
          share.resourceId == project.id.get() &&
          share.granteeUserId == principal) {
        return share.projectRoleValue;
      }
    }
    return null;
  }

  bool _canSeeWorkspace(Workspace workspace, String principal) {
    if (workspace.ownerId.get() == principal) return true;
    return _projects.any((p) =>
        p.workspaceId.get() == workspace.id.get() &&
        _roleOnProject(p, principal) != null);
  }

  /// Whether [role] may create/update items (owner or editor).
  bool _canWrite(ProjectRole? role) =>
      role == ProjectRole.owner || role == ProjectRole.editor;

  Workspace? _workspaceById(String id) {
    for (final w in _workspaces) {
      if (w.id.get() == id) return w;
    }
    return null;
  }

  Project? _projectById(String id) {
    for (final p in _projects) {
      if (p.id.get() == id) return p;
    }
    return null;
  }

  Project? _projectOfList(String listId) {
    for (final l in _lists) {
      if (l.id.get() == listId) return _projectById(l.projectId.get());
    }
    return null;
  }

  // ----- Detached copies (request→refresh model) ---------------------------

  Workspace _copyWorkspace(Workspace s) => Workspace()
    ..id.set(s.id.get())
    ..name.set(s.name.get())
    ..ownerId.set(s.ownerId.get())
    ..createdAt.set(s.createdAt.get());

  Project _copyProject(Project s) => Project()
    ..id.set(s.id.get())
    ..workspaceId.set(s.workspaceId.get())
    ..name.set(s.name.get())
    ..description.set(s.description.get())
    ..colour.set(s.colour.get())
    ..archived.set(s.archived.get());

  TodoList _copyList(TodoList s) => TodoList()
    ..id.set(s.id.get())
    ..projectId.set(s.projectId.get())
    ..name.set(s.name.get())
    ..position.set(s.position.get());

  TodoItem _copyItem(TodoItem s) => TodoItem()
    ..id.set(s.id.get())
    ..listId.set(s.listId.get())
    ..title.set(s.title.get())
    ..description.set(s.description.get())
    ..status.set(s.status.get())
    ..priority.set(s.priority.get())
    ..label.set(s.label.get())
    ..assigneeId.set(s.assigneeId.get())
    ..reporterId.set(s.reporterId.get())
    ..dueDate.set(s.dueDate.get())
    ..estimateHours.set(s.estimateHours.get())
    ..createdAt.set(s.createdAt.get())
    ..updatedAt.set(s.updatedAt.get());

  TodoComment _copyComment(TodoComment s) => TodoComment()
    ..id.set(s.id.get())
    ..itemId.set(s.itemId.get())
    ..authorId.set(s.authorId.get())
    ..body.set(s.body.get())
    ..createdAt.set(s.createdAt.get());
}
