/// The default backend: a seeded, fully working in-memory [TodoApi].
///
/// It mirrors what `core_server_sample` exposes — the same demo users, the same
/// todo items, and the **same four-state authorization matrix** its migration
/// seeds into `tom_resource_grant` — so the client behaves identically whether
/// it runs against this backend (the offline teaching default, and what the
/// widget tests drive) or the live server. Keeping the matrix here in one place
/// is what lets the four ACL states render distinctly without a database.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

import 'todo_api.dart';

/// An in-memory implementation of [TodoApi], seeded with demo data.
class InMemoryTodoApi implements TodoApi {
  /// Creates the backend and seeds its users, items and grant matrix.
  InMemoryTodoApi() {
    _seedUsers();
    _seedItems();
  }

  final List<User> _users = [];
  final List<TodoItem> _items = [];
  int _nextId = 1;

  /// The resolved per-field [TomAuthState] for each demo role.
  ///
  /// This is the client-side twin of the grants `core_server_sample` seeds:
  ///
  /// | field      | owner | member | viewer   |
  /// | ---------- | ----- | ------ | -------- |
  /// | title      | full  | full   | read     |
  /// | done       | full  | full   | disabled |
  /// | priority   | full  | none   | read     |
  /// | assigneeId | full  | read   | read     |
  ///
  /// Read straight down the columns to see all four states: `owner` is fully
  /// editable, `member` cannot see `priority` (none) and cannot change the
  /// assignee (read), and `viewer` can toggle nothing — `done` renders disabled
  /// while the rest are read-only.
  static const Map<String, Map<String, TomAuthState>> _grantMatrix = {
    'owner': {
      'todo.item.title': TomAuthState.full,
      'todo.item.done': TomAuthState.full,
      'todo.item.priority': TomAuthState.full,
      'todo.item.assigneeId': TomAuthState.full,
    },
    'member': {
      'todo.item.title': TomAuthState.full,
      'todo.item.done': TomAuthState.full,
      'todo.item.priority': TomAuthState.none,
      'todo.item.assigneeId': TomAuthState.read,
    },
    'viewer': {
      'todo.item.title': TomAuthState.read,
      'todo.item.done': TomAuthState.disabled,
      'todo.item.priority': TomAuthState.read,
      'todo.item.assigneeId': TomAuthState.read,
    },
  };

  /// The demo accounts, by username. The password is not checked beyond being
  /// non-empty — this is a teaching backend, not a credential store.
  static const Map<String, String> demoAccounts = {
    'alice': 'owner',
    'bob': 'member',
    'val': 'viewer',
  };

  void _seedUsers() {
    void add(String id, String username, String name, String role) {
      _users.add(
        User()
          ..id.set(id)
          ..displayName.set(name)
          ..email.set('$username@todo.example')
          ..role.set(role),
      );
    }

    add('1', 'alice', 'Alice (owner)', 'owner');
    add('2', 'bob', 'Bob (member)', 'member');
    add('3', 'val', 'Val (viewer)', 'viewer');
  }

  void _seedItems() {
    void add(
      String title,
      String desc,
      bool done,
      TodoPriority priority,
      TodoLabel label,
      String assigneeId,
    ) {
      final item = TodoItem()
        ..id.set('${_nextId++}')
        ..title.set(title)
        ..description.set(desc)
        ..done.set(done)
        ..assigneeId.set(assigneeId)
        ..priorityValue = priority
        ..labelValue = label;
      _items.add(item);
    }

    add(
      'Write the article',
      'Draft the core_client_sample walkthrough.',
      false,
      TodoPriority.high,
      TodoLabel.docs,
      '1',
    );
    add(
      'Fix the login redirect',
      'Bounce back to the list after auth.',
      false,
      TodoPriority.critical,
      TodoLabel.bug,
      '2',
    );
    add(
      'Tidy the seed data',
      'Round out the demo todo set.',
      true,
      TodoPriority.low,
      TodoLabel.chore,
      '2',
    );
  }

  @override
  Future<LoginResult> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    final role = demoAccounts[key];
    final texts = TomTextResourceProvider.getAppResources();
    if (role == null) {
      throw TodoApiException(texts.getText('login.error.unknownAccount'));
    }
    if (password.isEmpty) {
      throw TodoApiException(texts.getText('login.error.emptyPassword'));
    }
    final user = _users.firstWhere((u) => u.role.get() == role);
    return LoginResult(user: _copyUser(user), token: 'demo-token-$key');
  }

  @override
  Future<List<TodoItem>> listItems() async => [
    for (final item in _items) _copyItem(item),
  ];

  @override
  Future<TodoItem> saveItem(TodoItem item) async {
    final id = item.id.get();
    if (id.isEmpty) {
      final created = _copyItem(item)..id.set('${_nextId++}');
      _items.add(created);
      return _copyItem(created);
    }
    final index = _items.indexWhere((existing) => existing.id.get() == id);
    if (index < 0) {
      throw TodoApiException('No todo item with id "$id".');
    }
    _items[index] = _copyItem(item);
    return _copyItem(_items[index]);
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id.get() == id);
  }

  @override
  Future<Map<String, TomAuthState>> fieldStates(String role) async {
    final granted = _grantMatrix[role] ?? const {};
    return {
      for (final key in gradableItemKeys)
        key: granted[key] ?? TomAuthState.none,
    };
  }

  // Hand out detached copies so a caller editing a returned entity never mutates
  // the store until it calls saveItem — the straight request→refresh model.
  TodoItem _copyItem(TodoItem source) => TodoItem()
    ..id.set(source.id.get())
    ..title.set(source.title.get())
    ..description.set(source.description.get())
    ..done.set(source.done.get())
    ..priority.set(source.priority.get())
    ..label.set(source.label.get())
    ..assigneeId.set(source.assigneeId.get())
    ..dueDate.set(source.dueDate.get());

  User _copyUser(User source) => User()
    ..id.set(source.id.get())
    ..displayName.set(source.displayName.get())
    ..email.set(source.email.get())
    ..role.set(source.role.get());
}
