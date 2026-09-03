/// Database-free unit tests for the field-grade resolver (step 18): folding a
/// role's [TomResourceGrant]s into per-field [TomAuthState] grades is pure over
/// the [GrantStore] seam, so it verifies against a seeded [InMemoryGrantStore]
/// with no server or MariaDB.
///
/// The seed is the grant matrix the auth server's `[001]-auth_authz_grants.sql`
/// seeds, transcribed exactly, and each role's resolved field states are
/// asserted to reproduce it. The grant records are plain classes, so no
/// reflection setup is needed.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The seeded field-grade matrix: the expected per-field state for each role.
//
//   Field        owner  editor  commenter  viewer
//   title        full   full    read       read
//   status       full   full    full       read
//   priority     full   full    read       read
//   assigneeId   full   full    read       none
//   dueDate      full   full    read       read
//   estimate     full   read    none       none
//   description  full   full    read       read
const Map<ProjectRole, Map<String, TomAuthState>> seededGrantMatrix = {
  ProjectRole.owner: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.full,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.full,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.editor: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.full,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.read,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.commenter: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.read,
    'todo.item.assigneeId': TomAuthState.read,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
  ProjectRole.viewer: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.read,
    'todo.item.priority': TomAuthState.read,
    'todo.item.assigneeId': TomAuthState.none,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
};

/// Flattens [seededGrantMatrix] into the grant rows the auth server seeds.
List<TomResourceGrant> seedGrants() => [
      for (final role in seededGrantMatrix.entries)
        for (final field in role.value.entries)
          TomResourceGrant(
            roleName: role.key.name,
            resourceKey: field.key,
            accessLevel: field.value,
          ),
    ];

void main() {
  final resolver = FieldGradeResolver(InMemoryGrantStore(seedGrants()));

  group('reproduces the seeded grant matrix', () {
    for (final role in ProjectRole.values) {
      test('${role.name} resolves every field to its seeded grade', () async {
        final states = await resolver.resolveItemFieldStates(role);
        expect(states, seededGrantMatrix[role]);
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
          resourceKey: 'todo.item.title',
          accessLevel: TomAuthState.read,
        ),
        TomResourceGrant(
          roleName: ProjectRole.editor.name,
          resourceKey: 'todo.item.title',
          accessLevel: TomAuthState.full,
        ),
      ]));
      final graded = await resolver.gradesForRole(ProjectRole.editor);
      expect(graded.resolveState('todo.item.title'), TomAuthState.full);
    });

    test('a field with no grant row degrades to none (closed/safe)', () async {
      // The role has a grant for title only; every other gradable field has no
      // row and must resolve to none (hidden), the framework's safe default.
      final resolver = FieldGradeResolver(InMemoryGrantStore([
        TomResourceGrant(
          roleName: ProjectRole.viewer.name,
          resourceKey: 'todo.item.title',
          accessLevel: TomAuthState.read,
        ),
      ]));
      final states = await resolver.resolveItemFieldStates(ProjectRole.viewer);
      expect(states['todo.item.title'], TomAuthState.read);
      expect(states['todo.item.status'], TomAuthState.none);
      expect(states['todo.item.estimate'], TomAuthState.none);
    });

    test('resolved states cover every gradable field, in display order', () async {
      final states = await resolver.resolveItemFieldStates(ProjectRole.owner);
      expect(states.keys, orderedEquals(seededGrantMatrix[ProjectRole.owner]!.keys));
    });

    test('the gradable key set is derived from the server bundle (step 21)',
        () {
      // Step 21: the resolver no longer carries an inline key list — its default
      // set is the server resource bundle's gradable keys, so the graded set
      // tracks the texts the server serves.
      expect(resolver.gradableItemKeys,
          orderedEquals(AppResourceBundles.gradableItemKeys()));
    });
  });
}
