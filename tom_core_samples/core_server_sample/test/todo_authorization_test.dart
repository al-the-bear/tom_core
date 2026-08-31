/// Database-free unit tests for [TodoFieldAuthorizer] — the four-state grade
/// resolver that is half of what this sample teaches.
///
/// The authorizer takes grants, not a connection, so every property it has
/// verifies in memory. Two of those properties are ones the documents lean on
/// and nothing asserted:
///
///   * **the closed-safe default** — an ungranted key resolves to `none`, so the
///     failure mode of forgetting a grant is an invisible field rather than an
///     editable one;
///   * **the most-permissive merge** — when several grants touch one key the
///     wider grade wins, so holding a role that grants write is not undone by
///     another that grants less.
///
/// The last group closes the loop the endpoint actually walks: the rows migration
/// `[001]` seeds, grouped by role and folded through this authorizer, must equal
/// the matrix the README prints. That link was previously made only by
/// `example/run_all_examples.dart` (which asserts three of the twelve cells) and
/// by the live suite (which needs Docker), so re-grading a field in the migration
/// could leave the README wrong on any machine without a database.
library;

import 'package:core_server_sample/core_server_sample.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'documented_authorization.dart';

void main() {
  group('the gradable field vocabulary', () {
    test('names exactly the keys the migration seeds', () {
      // `gradableTodoItemKeys` is the enumeration `fieldStates` walks, and the
      // migration is what puts grades behind those keys. If they disagree, a
      // seeded grade either never reaches a response (key missing from the list)
      // or a listed field is reported `none` for every role (no seeded row) —
      // both silent, both a wrong matrix on the wire.
      expect(
        seededGrants().map((g) => g.resourceKey).toSet(),
        equals(gradableTodoItemKeys.toSet()),
      );
    });
  });

  group('stateOf', () {
    test('resolves each of the four stored grades', () {
      // All four states in one authorizer, because the point of the model is the
      // two that binary authorization cannot express — `disabled` and `none`.
      final authorizer = _authorizerFor({
        'todo.item.title': TomAuthState.full,
        'todo.item.done': TomAuthState.disabled,
        'todo.item.priority': TomAuthState.none,
        'todo.item.assigneeId': TomAuthState.read,
      });

      expect(authorizer.stateOf('todo.item.title'), TomAuthState.full);
      expect(authorizer.stateOf('todo.item.done'), TomAuthState.disabled);
      expect(authorizer.stateOf('todo.item.priority'), TomAuthState.none);
      expect(authorizer.stateOf('todo.item.assigneeId'), TomAuthState.read);
    });

    test('an ungranted key resolves to none — the closed-safe default', () {
      // The safety property the design rests on, stated for both shapes of
      // "ungranted": a key outside the vocabulary entirely, and a vocabulary key
      // whose grant row someone forgot. Neither may come back editable.
      final authorizer = _authorizerFor({'todo.item.title': TomAuthState.full});

      expect(authorizer.stateOf('todo.item.dueDate'), TomAuthState.none);
      expect(authorizer.stateOf('todo.item.done'), TomAuthState.none);
    });

    test('an empty grant list grades everything none', () {
      // The degenerate case is worth pinning on its own: a role with no rows at
      // all — a new role, or a failed migration — sees nothing rather than
      // everything. It is also what makes a mis-parsed seed file fail loudly in
      // the matrix group below instead of passing on an empty list.
      final authorizer = TodoFieldAuthorizer.fromGrants(const []);

      expect(authorizer.fieldStates.values, everyElement(TomAuthState.none));
    });
  });

  group('merging grants for one key', () {
    test('the most permissive grade wins, whichever order it arrives in', () {
      // Order-independence is the part worth asserting. A fold that simply
      // overwrote would pass one of these two and fail the other, and which one
      // depends on the row order the database happens to return.
      expect(
        _merged([TomAuthState.read, TomAuthState.full]),
        TomAuthState.full,
      );
      expect(
        _merged([TomAuthState.full, TomAuthState.read]),
        TomAuthState.full,
      );
    });

    test('a denying grant cannot take away what another grants', () {
      // The rule stated as its consequence: holding a second role that grants
      // less must not revoke access the first role gave.
      expect(
        _merged([TomAuthState.full, TomAuthState.none]),
        TomAuthState.full,
      );
      expect(
        _merged([TomAuthState.none, TomAuthState.disabled]),
        TomAuthState.disabled,
      );
    });

    test('fromGrants ignores roleName, so the caller must group first', () {
      // The trap behind `fieldStates()`' three-line grouping loop, pinned so it
      // is not "simplified" away. `fromGrants` unions every row it is handed,
      // regardless of which role each belongs to — handing it the whole table
      // grades every field by the most permissive role in the system, which for
      // the seeded data means the viewer's response would claim owner rights.
      final everyRole = seededGrants();
      final unfiltered = TodoFieldAuthorizer.fromGrants(everyRole);

      expect(
        unfiltered.fieldStates.values,
        everyElement(TomAuthState.full),
        reason: 'owner grants full on every field and would win the union',
      );
      expect(
        TodoFieldAuthorizer.fromGrants(
          everyRole.where((g) => g.roleName == 'viewer'),
        ).stateOf('todo.item.done'),
        TomAuthState.disabled,
      );
    });
  });

  group('fieldStates', () {
    test('is total over the gradable vocabulary', () {
      // Total, not merely non-empty: every gradable field must carry a grade so
      // a client can render the whole form from one response without deciding
      // what an absent key means.
      final authorizer = _authorizerFor({'todo.item.title': TomAuthState.read});

      expect(authorizer.fieldStates.keys, equals(gradableTodoItemKeys));
      expect(authorizer.fieldStates['todo.item.title'], TomAuthState.read);
      expect(authorizer.fieldStates['todo.item.priority'], TomAuthState.none);
    });

    test('ignores grants for keys outside the vocabulary', () {
      // A grant can be stored for any key; `fieldStates` reports the item form.
      // Silently dropping the extra is the intended behaviour — the response is
      // a fixed shape, not a dump of the grant table — but it is exactly the
      // kind of behaviour that is assumed rather than checked.
      final authorizer = _authorizerFor({
        'todo.item.title': TomAuthState.full,
        'todo.project.name': TomAuthState.full,
      });

      expect(authorizer.fieldStates.keys, equals(gradableTodoItemKeys));
      expect(authorizer.stateOf('todo.project.name'), TomAuthState.full);
    });
  });

  group('canEdit and canSee', () {
    // The worked example both the README's "Four-state authorization" section
    // and the completion document print, made executable. (Cited by title, not
    // by number: a number renumbers silently when a section is inserted above
    // it, which is the same drift these suites exist to catch.) The comments
    // beside those printed lines are claims about this class;
    // asserting them is what stops the documents explaining behaviour the code
    // no longer has.
    final viewer = _authorizerFor({
      'todo.item.title': TomAuthState.read,
      'todo.item.done': TomAuthState.disabled,
      'todo.item.priority': TomAuthState.read,
      'todo.item.assigneeId': TomAuthState.read,
    });

    test('canEdit is true only for full', () {
      expect(viewer.canEdit('todo.item.title'), isFalse);
      expect(viewer.canEdit('todo.item.done'), isFalse);
      expect(viewer.canEdit('todo.item.dueDate'), isFalse);
      expect(
        _authorizerFor({
          'todo.item.title': TomAuthState.full,
        }).canEdit('todo.item.title'),
        isTrue,
      );
    });

    test('canSee is false only for none — disabled is still visible', () {
      // The distinction the four-state model exists for: `disabled` is a control
      // the user can see and cannot operate, which a binary "may I?" collapses
      // into the same answer as "hidden".
      expect(viewer.canSee('todo.item.assigneeId'), isTrue);
      expect(viewer.canSee('todo.item.done'), isTrue);
      expect(viewer.canSee('todo.item.dueDate'), isFalse);
    });
  });

  group('the seeded grants resolve to the documented matrix', () {
    test('every seeded role folds to the states the README prints', () {
      // The request-time path, database-free: group the seeded rows by role and
      // fold each role's own grants — the same two steps `fieldStates()` takes —
      // then compare against the response the README publishes. Re-grading a
      // field in `[001]` now fails here until the README is updated, on any
      // machine, instead of only under Docker.
      final expected = documentedMatrix();
      final resolved = {
        for (final role in seededGrantsByRole().entries)
          role.key: TodoFieldAuthorizer.fromGrants(
            role.value,
          ).fieldStates.map((field, state) => MapEntry(field, state.name)),
      };

      expect(resolved, equals(expected));
    });

    test('the seeded roles between them exercise all four states', () {
      // Stated separately because the equality above would still pass if both
      // the migration and the README lost a state together. Seeding only `full`
      // and `none` would make the sample teach binary authorization while
      // claiming to teach four-state.
      final states = seededGrants().map((g) => g.accessLevel).toSet();
      expect(states, equals(TomAuthState.values.toSet()));
    });
  });
}

/// An authorizer over [grades], as one role's grant rows.
///
/// The role name is arbitrary — `fromGrants` does not read it (see the
/// `fromGrants ignores roleName` test) — so it is fixed here rather than
/// parameterised, which would suggest it mattered.
TodoFieldAuthorizer _authorizerFor(Map<String, TomAuthState> grades) =>
    TodoFieldAuthorizer.fromGrants([
      for (final entry in grades.entries)
        TomResourceGrant(
          roleName: 'test-role',
          resourceKey: entry.key,
          accessLevel: entry.value,
        ),
    ]);

/// The state one key resolves to when granted [grades] in that order.
TomAuthState _merged(List<TomAuthState> grades) =>
    TodoFieldAuthorizer.fromGrants([
      for (final grade in grades)
        TomResourceGrant(
          roleName: 'test-role',
          resourceKey: 'todo.item.title',
          accessLevel: grade,
        ),
    ]).stateOf('todo.item.title');
