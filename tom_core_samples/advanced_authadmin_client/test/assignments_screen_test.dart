/// Widget tests for the Assignments destination (step 36): assigning a role
/// and/or a group to a user over the seeded in-memory backend.
///
/// The contract here is the step's done bar: picking a role and/or a group for a
/// user and saving issues the expected [AssignmentRequest], and the persisted
/// effect is what the backend reports afterwards — a role lands in
/// `backend.rolesOf(userId)` (the seam has no UI read-back for roles), a group
/// lands in `listGroups().memberUserIds` and is reflected back in the user's row
/// subtitle on reload.
///
/// Socket-free (the assign editor binds no `TomForm`), driven through the same
/// shared harness: sign in, then open the rail's Assignments destination. Signing
/// in renders the reflected [AdminLoginForm] (todo 13), so the console's
/// `initializeReflection()` runs once in [setUpAll].
library;

import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/admin_console_harness.dart';

void main() {
  setUpAll(initializeReflection);

  /// Opens the assign editor for [userId] and selects a role and/or a group by
  /// its menu label, then saves.
  Future<void> assignTo(
    WidgetTester tester,
    String userId, {
    String? role,
    String? group,
  }) async {
    await tester.tap(find.byKey(Key('assignments-assign-$userId')));
    await tester.pumpAndSettle();
    if (role != null) {
      await tester.tap(find.byKey(const Key('assignment-role-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(role).last);
      await tester.pumpAndSettle();
    }
    if (group != null) {
      await tester.tap(find.byKey(const Key('assignment-group-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(group).last);
      await tester.pumpAndSettle();
    }
    await saveEditor(tester);
  }

  testWidgets('TC-36-01: the Assignments tab lists the seeded users',
      (tester) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Assignments');

    expect(find.byKey(const Key('assignments-screen')), findsOneWidget);
    expect(find.byKey(const Key('assignments-tile-u-alice')), findsOneWidget);
    // Bob and Carol seed into Engineering; the subtitle reads it back.
    expect(find.text('Groups: Engineering'), findsNWidgets(2));
  });

  testWidgets('TC-36-02: assigning a role persists to the backend',
      (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Assignments');

    expect(backend.rolesOf('u-alice'), isNot(contains('editor')));
    await assignTo(tester, 'u-alice', role: 'Editor');

    // alice keeps her seeded 'owner' role and gains 'editor'.
    expect(backend.rolesOf('u-alice'), containsAll(<String>['owner', 'editor']));
  });

  testWidgets('TC-36-03: assigning a group persists and updates the row',
      (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Assignments');

    // alice starts in no group.
    expect(
      find.descendant(
        of: find.byKey(const Key('assignments-tile-u-alice')),
        matching: find.text('No groups'),
      ),
      findsOneWidget,
    );

    await assignTo(tester, 'u-alice', group: 'Engineering');

    final groups = await backend.listGroups();
    final eng = groups.firstWhere((g) => g.id == 'g-eng');
    expect(eng.memberUserIds, contains('u-alice'));
    // The reload after save reflects the new membership in the subtitle.
    expect(
      find.descendant(
        of: find.byKey(const Key('assignments-tile-u-alice')),
        matching: find.text('Groups: Engineering'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TC-36-04: an empty selection is refused and the editor stays',
      (tester) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Assignments');

    await tester.tap(find.byKey(const Key('assignments-assign-u-alice')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    // The dialog stays open with an inline error; nothing was assigned.
    expect(find.byKey(const Key('admin-editor-dialog')), findsOneWidget);
    expect(find.byKey(const Key('admin-editor-error')), findsOneWidget);
  });

  testWidgets('TC-36-05: a role and a group can be assigned together',
      (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Assignments');

    await assignTo(tester, 'u-alice', role: 'Commenter', group: 'Engineering');

    expect(backend.rolesOf('u-alice'), contains('commenter'));
    final groups = await backend.listGroups();
    final eng = groups.firstWhere((g) => g.id == 'g-eng');
    expect(eng.memberUserIds, contains('u-alice'));
  });
}
