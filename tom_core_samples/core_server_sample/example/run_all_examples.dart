/// Database-free walkthrough of the `core_server_sample` server core.
///
/// Everything here runs without MariaDB or a live server: it exercises the two
/// pieces that do not need a database — the domain ↔ record mapping and the
/// four-state field authorization. Each demo asserts its own deterministic
/// result, so this file doubles as a headless smoke test: it reports a pass/fail
/// tally and exits non-zero on any failure. The live HTTP boot + persistence
/// round-trip against the bundled Docker MariaDB is documented in the README and
/// gated on the workspace's Docker integration step (`readme_and_example_plan`
/// item 28).
///
/// Run it with:
///
/// ```sh
/// dart run example/run_all_examples.dart
/// ```
library;

import 'dart:io';

import 'package:core_server_sample/core_server_sample.dart';
import 'package:todo_domain/todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // The domain entities are observable TomClasses; constructing one reflects
  // itself, so reflection must be live before any mapping runs.
  initializeReflection();

  final demos = <String, void Function()>{
    'domain <-> record mapping': _demoMapping,
    'four-state field authorization': _demoAuthorization,
  };

  print('=' * 60);
  print('Running all core_server_sample examples (database-free)');
  print('=' * 60);

  var passed = 0;
  final failures = <String, String>{};

  for (final entry in demos.entries) {
    stdout.write('\nRunning: ${entry.key}... ');
    try {
      entry.value();
      print('✓ PASSED');
      passed++;
    } catch (e, stack) {
      print('✗ FAILED');
      failures[entry.key] = '$e\n$stack';
    }
  }

  print('\n${'=' * 60}');
  print('Results: $passed passed, ${failures.length} failed');
  print('=' * 60);

  if (failures.isNotEmpty) {
    print('\nFailures:');
    for (final entry in failures.entries) {
      print('\n--- ${entry.key} ---');
      print(entry.value);
    }
    exit(1);
  }

  print('\nAll examples passed!');
}

/// Shows the domain (client form model) ↔ record (server DB model) boundary in
/// both directions: a freshly built item flattens to a row, and a row loaded
/// from the database rebuilds the observable entity.
void _demoMapping() {
  print('\n== Domain <-> record mapping ==');

  // A user the server loaded from `todo_users`.
  final ownerRecord = TodoUserRecord()
    ..id = 7
    ..displayName = 'Ada'
    ..email = 'ada@example.com'
    ..role = 'owner';
  final owner = userFromRecord(ownerRecord);
  print('Loaded user: ${owner.displayName.get()} '
      '(id=${owner.id.get()}, role=${owner.role.get()})');
  // expected output: Loaded user: Ada (id=7, role=owner)
  _expect(owner.displayName.get() == 'Ada', 'user displayName round-trips');
  _expect(owner.role.get() == 'owner', 'user role round-trips');

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
  // expected output: New item -> row: title=Write the README, priority=high,
  //   assignee_id=7, list_id=4, id=null (null => INSERT)
  _expect(row.title == 'Write the README', 'item title flattens to row');
  _expect(row.priority == 'high', 'priority enum flattens to its name');
  _expect(row.listId == 4, 'owning list id is supplied');
  _expect(row.id == null, 'a not-yet-persisted item has a null id (INSERT)');

  // …and the round-trip back to the observable model the client edits.
  final reloaded = itemFromRecord(row..id = 3);
  print('Row -> item: ${reloaded.title.get()} '
      'priority=${reloaded.priorityValue.name} id=${reloaded.id.get()}');
  // expected output: Row -> item: Write the README priority=high id=3
  _expect(reloaded.priorityValue == TodoPriority.high,
      'priority name re-parses to the typed enum');
  _expect(reloaded.id.get() == '3', 'assigned id survives the round-trip');
}

/// Resolves the four authorization states for the seeded demo roles, exactly as
/// the server does per request from the `tom_resource_grant` rows.
void _demoAuthorization() {
  print('\n== Four-state field authorization ==');

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
  // expected output (excerpt): viewer's done -> disabled (greyed-out),
  //   member's priority -> none (hidden), owner's title -> full (editable)
  final viewer = TodoFieldAuthorizer.fromGrants(grantsByRole['viewer']!);
  _expect(viewer.stateOf(TodoItemResourceKeys.done) == TomAuthState.disabled,
      'viewer sees a disabled (greyed-out) done toggle');
  final member = TodoFieldAuthorizer.fromGrants(grantsByRole['member']!);
  _expect(member.stateOf(TodoItemResourceKeys.priority) == TomAuthState.none,
      'member has no (hidden) priority field');
  final owner = TodoFieldAuthorizer.fromGrants(grantsByRole['owner']!);
  _expect(owner.stateOf(TodoItemResourceKeys.title) == TomAuthState.full,
      'owner edits (full) the title field');
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

/// Throws a [StateError] when [ok] is false so the aggregator's tally records a
/// failure (a silent wrong-output regression becomes a hard, non-zero exit).
void _expect(bool ok, String what) {
  if (!ok) throw StateError('expectation failed: $what');
}
