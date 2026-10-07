/// Widget tests for the Users destination (`UsersScreen`): list, create, edit,
/// and delete accounts through the bound [UserForm], all over the seeded
/// in-memory backend.
///
/// Socket-free and reflection-driven — the editor forms bind reflected drafts, so
/// the console's `initializeReflection()` runs once in [setUpAll] and the
/// resource provider is installed per test (mirroring the app client's
/// detail-screen suite). Each flow drives the whole console (sign in, then the
/// rail's Users tab) through the shared harness.
library;

import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'support/admin_console_harness.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  testWidgets('TC-34-U01: the Users tab lists the seeded accounts', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());

    expect(find.byKey(const Key('users-screen')), findsOneWidget);
    expect(find.byKey(const Key('users-tile-u-admin')), findsOneWidget);
    expect(find.byKey(const Key('users-tile-u-alice')), findsOneWidget);
    expect(find.byKey(const Key('users-tile-u-bob')), findsOneWidget);
    expect(find.byKey(const Key('users-tile-u-carol')), findsOneWidget);
  });

  testWidgets('TC-34-U02: creating an account adds it to the list', (
    tester,
  ) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);

    await tester.tap(find.byKey(const Key('users-create')));
    await tester.pumpAndSettle();

    // Create form: username, password, displayName, email (no status yet).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'carol');
    await tester.enterText(fields.at(1), 'pw');
    await tester.enterText(fields.at(2), 'Carol');
    await tester.enterText(fields.at(3), 'carol@todo.example');
    await saveEditor(tester);

    expect(find.byKey(const Key('admin-editor-dialog')), findsNothing);
    expect(find.text('Carol'), findsOneWidget);
    final users = await backend.listUsers();
    expect(users.any((u) => u.username == 'carol'), isTrue);
  });

  testWidgets('TC-34-U03: an empty username fails validation, no row is added', (
    tester,
  ) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    final before = (await backend.listUsers()).length;

    await tester.tap(find.byKey(const Key('users-create')));
    await tester.pumpAndSettle();
    await saveEditor(tester); // submit with everything blank

    // Validation blocked the save: the dialog stays open and nothing persisted.
    expect(find.byKey(const Key('admin-editor-dialog')), findsOneWidget);
    expect((await backend.listUsers()).length, before);
  });

  testWidgets(
    'TC-34-U04: editing updates the profile (username stays the key)',
    (tester) async {
      final backend = InMemoryAdminBackend();
      await pumpSignedInConsole(tester, backend);

      await tester.tap(find.byKey(const Key('users-tile-u-bob')));
      await tester.pumpAndSettle();

      // Edit form: username (read-only), displayName, email, status (dropdown).
      final fields = find.byType(TextField);
      final username = tester.widget<TextField>(fields.at(0));
      expect(username.enabled, isFalse); // the stable key is not editable
      await tester.enterText(fields.at(1), 'Bob Edited');
      await saveEditor(tester);

      expect(find.text('Bob Edited'), findsOneWidget);
      final bob = (await backend.listUsers()).firstWhere(
        (u) => u.id == 'u-bob',
      );
      expect(bob.displayName, 'Bob Edited');
      expect(bob.username, 'bob'); // unchanged
    },
  );

  testWidgets('TC-34-U05: deleting an account removes its row', (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);

    await tester.tap(find.byKey(const Key('users-delete-u-carol')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-delete-confirm')), findsOneWidget);
    await confirmDelete(tester);

    expect(find.byKey(const Key('users-tile-u-carol')), findsNothing);
    expect((await backend.listUsers()).any((u) => u.id == 'u-carol'), isFalse);
  });

  testWidgets(
    'TC-34-U06: editing sets the account\'s stored language, then clears it',
    (tester) async {
      final backend = InMemoryAdminBackend();
      await pumpSignedInConsole(tester, backend);
      Future<UserDto> bob() async =>
          (await backend.listUsers()).firstWhere((u) => u.id == 'u-bob');
      expect((await bob()).language, '', reason: 'seeded with no preference');

      // The edit form ends with language and country, the last two inputs.
      await tester.tap(find.byKey(const Key('users-tile-u-bob')));
      await tester.pumpAndSettle();
      var fields = find.byType(TextField);
      final count = fields.evaluate().length;
      await tester.enterText(fields.at(count - 2), ' DE ');
      await tester.enterText(fields.at(count - 1), 'at');
      await saveEditor(tester);

      expect(find.byKey(const Key('admin-editor-dialog')), findsNothing);
      expect((await bob()).language, 'de');
      expect((await bob()).country, 'AT');

      // Re-opening shows what is stored; emptying the language clears both,
      // because a country alone is no preference.
      await tester.tap(find.byKey(const Key('users-tile-u-bob')));
      await tester.pumpAndSettle();
      fields = find.byType(TextField);
      expect(
        tester.widget<TextField>(fields.at(count - 2)).controller?.text,
        'de',
      );
      await tester.enterText(fields.at(count - 2), '');
      await saveEditor(tester);

      expect((await bob()).language, '');
      expect((await bob()).country, '');
    },
  );

  testWidgets(
    'TC-34-U07: a language or country that is not a code fails validation '
    'with the bundle\'s wording, and nothing is saved',
    (tester) async {
      final backend = InMemoryAdminBackend();
      await pumpSignedInConsole(tester, backend);

      await tester.tap(find.byKey(const Key('users-tile-u-bob')));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      final count = fields.evaluate().length;
      await tester.enterText(fields.at(count - 2), 'Deutsch');
      await tester.enterText(fields.at(count - 1), 'Austria');
      await saveEditor(tester);

      expect(find.byKey(const Key('admin-editor-dialog')), findsOneWidget);
      // Each validator raises its own key, and the field renders the
      // installed bundle's sentence for it rather than the key.
      expect(find.text(TomCtr.text('error.language')), findsOneWidget);
      expect(find.text(TomCtr.text('error.country')), findsOneWidget);
      expect(TomCtr.text('error.language'), isNot('error.language'));
      final bob = (await backend.listUsers()).firstWhere(
        (u) => u.id == 'u-bob',
      );
      expect(bob.language, '');
      expect(bob.country, '');
    },
  );
}
