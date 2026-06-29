/// The default backend: a seeded, fully working in-memory [AppBackend] (step 26).
///
/// It mirrors what `advanced_app_server` exposes — the same demo accounts, a
/// small workspace→project→list→item tree, and the **same four-state field
/// authorization matrix** the auth server seeds — so the client behaves
/// identically whether it runs against this backend (the offline teaching
/// default, and what the widget tests drive) or the live stack. Keeping the
/// matrix and the ownership/share model here in one place is what lets the four
/// ACL states render distinctly without a server or database.
///
/// The principal is implicit in the session: [login] records the current user,
/// and every later call filters by what that user owns or is shared into and
/// resolves field grades through their effective [ProjectRole] on the resource —
/// exactly the seam the live server enforces from the bearer token.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_backend.dart';

/// An in-memory implementation of [AppBackend], seeded with demo data.
class InMemoryAppBackend implements AppBackend {
  /// Creates the backend and seeds its users, resource tree and shares.
  InMemoryAppBackend() {
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

  int _nextId = 100;
  String? _currentUserId;

  /// The canned public login bundle, mirroring `advanced_auth_server`'s
  /// `AuthResourceBundles.loginBundle()` (D-A11) so the offline app installs the
  /// exact same sign-in chrome the live auth server serves — the widget tests
  /// stay socket-free while still proving the screen renders *server-delivered*
  /// texts.
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

  /// The canned authenticated full bundle, mirroring `advanced_app_server`'s
  /// `AppResourceBundles.appBundle()` (D-A11) — the item-form field labels
  /// (keyed `${TodoItemResourceKeys.<field>}.label` so the label key tracks the
  /// grade key) plus the `board.*` chrome that has no grade counterpart. The
  /// session installs this right after sign-in so every post-login screen
  /// renders server-delivered texts while the widget tests stay socket-free.
  static const Map<String, Object?> fullTexts = {
    '${TodoItemResourceKeys.title}.label': 'Title',
    '${TodoItemResourceKeys.status}.label': 'Status',
    '${TodoItemResourceKeys.priority}.label': 'Priority',
    '${TodoItemResourceKeys.assigneeId}.label': 'Assignee id',
    '${TodoItemResourceKeys.dueDate}.label': 'Due date',
    '${TodoItemResourceKeys.estimate}.label': 'Estimate (h)',
    '${TodoItemResourceKeys.description}.label': 'Description',
    'board.title': 'My Board',
    'board.empty': 'No items yet',
    'board.item.save': 'Save',
    'board.item.delete': 'Delete',
    'board.item.comment.add': 'Add comment',
    'board.share': 'Share',
  };

  /// The demo accounts, by username → user id. The password is not verified
  /// beyond being non-empty — this is a teaching backend, not a credential
  /// store.
  static const Map<String, String> demoAccounts = {
    'alice': 'u-alice',
    'bob': 'u-bob',
    'val': 'u-val',
  };

  /// The resolved per-field [TomAuthState] for each [ProjectRole].
  ///
  /// This is the client-side twin of the grants `advanced_auth_server` seeds.
  /// Read down the columns to see all four states:
  ///
  /// | field       | owner | editor | commenter | viewer   |
  /// | ----------- | ----- | ------ | --------- | -------- |
  /// | title       | full  | full   | read      | read     |
  /// | status      | full  | full   | read      | disabled |
  /// | priority    | full  | full   | none      | read     |
  /// | assigneeId  | full  | read   | read      | read     |
  /// | dueDate     | full  | full   | read      | read     |
  /// | estimate    | full  | read   | none      | none     |
  /// | description | full  | full   | read      | read     |
  ///
  /// `owner` is fully editable; `editor` cannot reassign or edit the estimate
  /// (read); `commenter` cannot see `priority`/`estimate` (none); `viewer` can
  /// toggle nothing — `status` renders disabled while the rest are read-only.
  static const Map<ProjectRole, Map<String, TomAuthState>> _grantMatrix = {
    ProjectRole.owner: {
      TodoItemResourceKeys.title: TomAuthState.full,
      TodoItemResourceKeys.status: TomAuthState.full,
      TodoItemResourceKeys.priority: TomAuthState.full,
      TodoItemResourceKeys.assigneeId: TomAuthState.full,
      TodoItemResourceKeys.dueDate: TomAuthState.full,
      TodoItemResourceKeys.estimate: TomAuthState.full,
      TodoItemResourceKeys.description: TomAuthState.full,
    },
    ProjectRole.editor: {
      TodoItemResourceKeys.title: TomAuthState.full,
      TodoItemResourceKeys.status: TomAuthState.full,
      TodoItemResourceKeys.priority: TomAuthState.full,
      TodoItemResourceKeys.assigneeId: TomAuthState.read,
      TodoItemResourceKeys.dueDate: TomAuthState.full,
      TodoItemResourceKeys.estimate: TomAuthState.read,
      TodoItemResourceKeys.description: TomAuthState.full,
    },
    ProjectRole.commenter: {
      TodoItemResourceKeys.title: TomAuthState.read,
      TodoItemResourceKeys.status: TomAuthState.read,
      TodoItemResourceKeys.priority: TomAuthState.none,
      TodoItemResourceKeys.assigneeId: TomAuthState.read,
      TodoItemResourceKeys.dueDate: TomAuthState.read,
      TodoItemResourceKeys.estimate: TomAuthState.none,
      TodoItemResourceKeys.description: TomAuthState.read,
    },
    ProjectRole.viewer: {
      TodoItemResourceKeys.title: TomAuthState.read,
      TodoItemResourceKeys.status: TomAuthState.disabled,
      TodoItemResourceKeys.priority: TomAuthState.read,
      TodoItemResourceKeys.assigneeId: TomAuthState.read,
      TodoItemResourceKeys.dueDate: TomAuthState.read,
      TodoItemResourceKeys.estimate: TomAuthState.none,
      TodoItemResourceKeys.description: TomAuthState.read,
    },
  };

  void _seed() {
    void user(String id, String username, String name) => _users.add(UserDto(
          id: id,
          username: username,
          displayName: name,
          email: '$username@todo.example',
        ));
    user('u-alice', 'alice', 'Alice (owner)');
    user('u-bob', 'bob', 'Bob (editor)');
    user('u-val', 'val', 'Val (viewer)');

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

    // Bob is shared into the project as an editor; Val starts with no access
    // (the share test grants it).
    _shares.add(const ShareRequest(
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
        'Unknown account. Try alice, bob or val.',
        key: 'auth.login.failed',
      );
    }
    if (request.password.isEmpty) {
      throw const AppBackendException(
        'Password must not be empty.',
        key: 'auth.login.failed',
      );
    }
    _currentUserId = id;
    final user = _users.firstWhere((u) => u.id == id);
    return LoginResult(
      user: user,
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
    return [
      for (final item in _items)
        if (item.listId.get() == listId) _copyItem(item),
    ];
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
  Future<Map<String, TomAuthState>> itemFieldStates(String itemId) async {
    final principal = _principalId;
    final item = _items.firstWhere(
      (i) => i.id.get() == itemId,
      orElse: () => throw AppBackendException('No item with id "$itemId".',
          key: 'app.item.not_found'),
    );
    final project = _projectOfList(item.listId.get());
    final role = project == null ? null : _roleOnProject(project, principal);
    final granted = role == null ? const {} : _grantMatrix[role]!;
    return {
      for (final key in TodoItemResourceKeys.all)
        key: granted[key] ?? TomAuthState.none,
    };
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
        return share.projectRole;
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
