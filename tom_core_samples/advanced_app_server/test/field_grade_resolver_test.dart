/// Database-free unit tests for the field-grade resolver (step 18): folding a
/// role's [TomResourceGrant]s into per-field [TomAuthState] grades is pure over
/// the [GrantStore] seam, so it verifies against a seeded [InMemoryGrantStore]
/// with no server or MariaDB.
///
/// The seed is the §A.4 grant matrix transcribed exactly — the same data the
/// auth server's `[001]-auth_authz_grants.sql` seeds — and each role's resolved
/// field states are asserted to reproduce it. The grant records are plain
/// classes, so no reflection setup is needed.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The §A.4 field-grade matrix: the expected per-field state for each role.
//
//   Field        owner  editor  commenter  viewer
//   title        full   full    read       read
//   status       full   full    full       read
//   priority     full   full    read       read
//   assigneeId   full   full    read       none
//   dueDate      full   full    read       read
//   estimate     full   read    none       none
//   description  full   full    read       read
const Map<ProjectRole, Map<String, TomAuthState>> a4Matrix = {
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
    TodoItemResourceKeys.assigneeId: TomAuthState.full,
    TodoItemResourceKeys.dueDate: TomAuthState.full,
    TodoItemResourceKeys.estimate: TomAuthState.read,
    TodoItemResourceKeys.description: TomAuthState.full,
  },
  ProjectRole.commenter: {
    TodoItemResourceKeys.title: TomAuthState.read,
    TodoItemResourceKeys.status: TomAuthState.full,
    TodoItemResourceKeys.priority: TomAuthState.read,
    TodoItemResourceKeys.assigneeId: TomAuthState.read,
    TodoItemResourceKeys.dueDate: TomAuthState.read,
    TodoItemResourceKeys.estimate: TomAuthState.none,
    TodoItemResourceKeys.description: TomAuthState.read,
  },
  ProjectRole.viewer: {
    TodoItemResourceKeys.title: TomAuthState.read,
    TodoItemResourceKeys.status: TomAuthState.read,
    TodoItemResourceKeys.priority: TomAuthState.read,
    TodoItemResourceKeys.assigneeId: TomAuthState.none,
    TodoItemResourceKeys.dueDate: TomAuthState.read,
    TodoItemResourceKeys.estimate: TomAuthState.none,
    TodoItemResourceKeys.description: TomAuthState.read,
  },
};

/// Flattens [a4Matrix] into the grant rows the auth server seeds.
List<TomResourceGrant> seedGrants() => [
      for (final role in a4Matrix.entries)
        for (final field in role.value.entries)
          TomResourceGrant(
            roleName: role.key.name,
            resourceKey: field.key,
            accessLevel: field.value,
          ),
    ];

void main() {
  final resolver = FieldGradeResolver(InMemoryGrantStore(seedGrants()));

  group('reproduces the §A.4 matrix', () {
    for (final role in ProjectRole.values) {
      test('${role.name} resolves every field to its seeded grade', () async {
        final states = await resolver.resolveItemFieldStates(role);
        expect(states, a4Matrix[role]);
      });
    }
  });

  group('grade folding', () {
    test('a key granted twice widens to the most permissive grade', () async {
      // Two rows grade the same key for one role; the fold keeps the stronger
      // (read vs full -> full), matching TomGradedAccessControlInformation.
      final resolver = FieldGradeResolver(InMemoryGrantStore([
        TomResourceGrant(
          roleName: ProjectRole.editor.name,
          resourceKey: TodoItemResourceKeys.title,
          accessLevel: TomAuthState.read,
        ),
        TomResourceGrant(
          roleName: ProjectRole.editor.name,
          resourceKey: TodoItemResourceKeys.title,
          accessLevel: TomAuthState.full,
        ),
      ]));
      final graded = await resolver.gradesForRole(ProjectRole.editor);
      expect(graded.resolveState(TodoItemResourceKeys.title), TomAuthState.full);
    });

    test('a field with no grant row degrades to none (closed/safe)', () async {
      // The role has a grant for title only; every other gradable field has no
      // row and must resolve to none (hidden), the framework's safe default.
      final resolver = FieldGradeResolver(InMemoryGrantStore([
        TomResourceGrant(
          roleName: ProjectRole.viewer.name,
          resourceKey: TodoItemResourceKeys.title,
          accessLevel: TomAuthState.read,
        ),
      ]));
      final states = await resolver.resolveItemFieldStates(ProjectRole.viewer);
      expect(states[TodoItemResourceKeys.title], TomAuthState.read);
      expect(states[TodoItemResourceKeys.status], TomAuthState.none);
      expect(states[TodoItemResourceKeys.estimate], TomAuthState.none);
    });

    test('resolved states cover every gradable field, in display order', () async {
      final states = await resolver.resolveItemFieldStates(ProjectRole.owner);
      expect(states.keys, orderedEquals(TodoItemResourceKeys.all));
    });
  });
}
