/// Database-free walkthrough of the `core_server_sample` server core.
///
/// Everything here runs without MariaDB or a live server: it exercises the two
/// pieces that do not need a database — the domain ↔ record mapping and the
/// four-state field authorization. The live HTTP boot + persistence round-trip
/// against the bundled Docker MariaDB is documented in the README and gated on
/// the workspace's Docker integration step (`readme_and_example_plan` item 28).
///
/// Run it with:
///
/// ```sh
/// dart run example/run_all_examples.dart
/// ```
library;

import 'package:core_server_sample/core_server_sample.dart';
import 'package:todo_domain/todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // The domain entities are observable TomClasses; constructing one reflects
  // itself, so reflection must be live before any mapping runs.
  initializeReflection();

  _demoMapping();
  _demoAuthorization();
}

/// Shows the domain (client form model) ↔ record (server DB model) boundary in
/// both directions: a freshly built item flattens to a row, and a row loaded
/// from the database rebuilds the observable entity.
void _demoMapping() {
  print('== Domain <-> record mapping ==');

  // A user the server loaded from `todo_users`.
  final ownerRecord = TodoUserRecord()
    ..id = 7
    ..displayName = 'Ada'
    ..email = 'ada@example.com'
    ..role = 'owner';
  final owner = userFromRecord(ownerRecord);
  print('Loaded user: ${owner.displayName.get()} '
      '(id=${owner.id.get()}, role=${owner.role.get()})');

  // A new item built on the client, not yet persisted (empty id).
  final item = TodoItem()
    ..title.set('Write the README')
    ..priorityValue = TodoPriority.high
    ..labelValue = TodoLabel.docs
    ..assigneeId.set('7');

  // Flattened for INSERT into `todo_items`, with its owning list id supplied.
  final row = itemToRecord(item, listId: 4);
  print('New item -> row: title=${row.title}, priority=${row.priority}, '
      'assignee_id=${row.assigneeId}, list_id=${row.listId}, '
      'id=${row.id} (null => INSERT)');

  // …and the round-trip back to the observable model the client edits.
  final reloaded = itemFromRecord(row..id = 3);
  print('Row -> item: ${reloaded.title.get()} '
      'priority=${reloaded.priorityValue.name} id=${reloaded.id.get()}');
  print('');
}

/// Resolves the four authorization states for the seeded demo roles, exactly as
/// the server does per request from the `tom_resource_grant` rows.
void _demoAuthorization() {
  print('== Four-state field authorization ==');

  // The same grants seeded by migration [001]-todo_authz_grants.sql, built
  // in-memory here so the demo needs no database.
  final grantsByRole = <String, List<TomResourceGrant>>{
    'owner': _grants('owner', {
      TodoItemResourceKeys.title: TomAuthState.full,
      TodoItemResourceKeys.done: TomAuthState.full,
      TodoItemResourceKeys.priority: TomAuthState.full,
      TodoItemResourceKeys.assigneeId: TomAuthState.full,
    }),
    'member': _grants('member', {
      TodoItemResourceKeys.title: TomAuthState.full,
      TodoItemResourceKeys.done: TomAuthState.full,
      TodoItemResourceKeys.priority: TomAuthState.none,
      TodoItemResourceKeys.assigneeId: TomAuthState.read,
    }),
    'viewer': _grants('viewer', {
      TodoItemResourceKeys.title: TomAuthState.read,
      TodoItemResourceKeys.done: TomAuthState.disabled,
      TodoItemResourceKeys.priority: TomAuthState.read,
      TodoItemResourceKeys.assigneeId: TomAuthState.read,
    }),
  };

  for (final entry in grantsByRole.entries) {
    final authorizer = TodoFieldAuthorizer.fromGrants(entry.value);
    print('Role "${entry.key}":');
    for (final key in TodoItemResourceKeys.all) {
      print('  $key -> ${authorizer.stateOf(key).name} '
          '(${_rendering(authorizer.stateOf(key))})');
    }
  }
  print('');
}

/// Builds the grant rows for one role from a `(resourceKey -> state)` map.
List<TomResourceGrant> _grants(String role, Map<String, TomAuthState> states) =>
    [
      for (final e in states.entries)
        TomResourceGrant(
          roleName: role,
          resourceKey: e.key,
          accessLevel: e.value,
        ),
    ];

/// The UI rendering each state maps to (the client half of the four-state
/// story), for readable output.
String _rendering(TomAuthState state) => switch (state) {
      TomAuthState.full => 'editable',
      TomAuthState.read => 'read-only',
      TomAuthState.disabled => 'greyed-out',
      TomAuthState.none => 'hidden',
    };
