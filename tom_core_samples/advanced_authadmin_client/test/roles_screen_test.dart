/// Widget tests for the Roles destination (`RolesScreen`): list, create, edit,
/// and delete roles through the bound [RoleForm], over the seeded in-memory
/// backend.
///
/// The role key is the stable identifier the grant matrix keys on, so the tests
/// assert it is editable on create but read-only on edit (only the name changes).
/// Socket-free and reflection-driven, like the Users suite.
library;

import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'support/admin_console_harness.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  testWidgets('TC-34-R01: the Roles tab lists the seeded roles', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Roles');

    expect(find.byKey(const Key('roles-screen')), findsOneWidget);
    expect(find.byKey(const Key('roles-tile-admin')), findsOneWidget);
    expect(find.byKey(const Key('roles-tile-owner')), findsOneWidget);
    expect(find.byKey(const Key('roles-tile-viewer')), findsOneWidget);
  });

  testWidgets('TC-34-R02: creating a role adds it to the list', (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Roles');

    await tester.tap(find.byKey(const Key('roles-create')));
    await tester.pumpAndSettle();

    // Create form: key (editable), name.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'auditor');
    await tester.enterText(fields.at(1), 'Auditor');
    await saveEditor(tester);

    expect(find.byKey(const Key('roles-tile-auditor')), findsOneWidget);
    expect((await backend.listRoles()).any((r) => r.key == 'auditor'), isTrue);
  });

  testWidgets('TC-34-R03: a duplicate key is refused with an inline error', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Roles');

    await tester.tap(find.byKey(const Key('roles-create')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'owner'); // already exists
    await tester.enterText(fields.at(1), 'Owner again');
    await saveEditor(tester);

    // The backend refusal surfaces as the dialog's inline banner; it stays open.
    expect(find.byKey(const Key('admin-editor-dialog')), findsOneWidget);
    expect(find.byKey(const Key('admin-editor-error')), findsOneWidget);
  });

  testWidgets('TC-34-R04: editing renames a role; its key is read-only', (
    tester,
  ) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Roles');

    await tester.tap(find.byKey(const Key('roles-tile-viewer')));
    await tester.pumpAndSettle();

    // Edit form: key (read-only), name.
    final fields = find.byType(TextField);
    final key = tester.widget<TextField>(fields.at(0));
    expect(key.enabled, isFalse);
    await tester.enterText(fields.at(1), 'Read-only viewer');
    await saveEditor(tester);

    final viewer = (await backend.listRoles()).firstWhere(
      (r) => r.key == 'viewer',
    );
    expect(viewer.name, 'Read-only viewer');
  });

  testWidgets('TC-34-R05: deleting a role removes its row', (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Roles');

    await tester.tap(find.byKey(const Key('roles-delete-commenter')));
    await tester.pumpAndSettle();
    await confirmDelete(tester);

    expect(find.byKey(const Key('roles-tile-commenter')), findsNothing);
    expect(
      (await backend.listRoles()).any((r) => r.key == 'commenter'),
      isFalse,
    );
  });
}
