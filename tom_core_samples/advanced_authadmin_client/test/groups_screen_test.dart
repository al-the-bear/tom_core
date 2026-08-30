/// Widget tests for the Groups destination (`GroupsScreen`): list, create, edit,
/// and delete groups through the bound [GroupForm] plus the membership
/// checklist, over the seeded in-memory backend.
///
/// Membership is the extra here: a group's members are a checklist over every
/// account, so the tests assert the checklist pre-checks current members on edit
/// and that toggling a box folds into the saved [GroupDto.memberUserIds].
/// Socket-free and reflection-driven, like the Users and Roles suites.
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

  testWidgets('TC-34-G01: the Groups tab lists the seeded group + member count',
      (tester) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Groups');

    expect(find.byKey(const Key('groups-screen')), findsOneWidget);
    expect(find.byKey(const Key('groups-tile-g-eng')), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
  });

  testWidgets('TC-34-G02: creating a group with a member adds it to the list',
      (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Groups');

    await tester.tap(find.byKey(const Key('groups-create')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Design');
    await tester.tap(find.byKey(const Key('group-member-u-alice')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    expect(find.text('Design'), findsOneWidget);
    final design =
        (await backend.listGroups()).firstWhere((g) => g.name == 'Design');
    expect(design.memberUserIds, ['u-alice']);
  });

  testWidgets('TC-34-G03: the editor pre-checks a group\'s current members',
      (tester) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Groups');

    await tester.tap(find.byKey(const Key('groups-tile-g-eng')));
    await tester.pumpAndSettle();

    CheckboxListTile box(String id) => tester.widget<CheckboxListTile>(
          find.descendant(
            of: find.byKey(Key('group-member-$id')),
            matching: find.byType(CheckboxListTile),
          ),
        );
    expect(box('u-bob').value, isTrue);
    expect(box('u-carol').value, isTrue);
    expect(box('u-alice').value, isFalse);
  });

  testWidgets('TC-34-G04: removing a member updates the saved membership',
      (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Groups');

    await tester.tap(find.byKey(const Key('groups-tile-g-eng')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-member-u-bob')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    final eng = (await backend.listGroups()).firstWhere((g) => g.id == 'g-eng');
    expect(eng.memberUserIds, ['u-carol']);
    expect(find.text('1 member'), findsOneWidget);
  });

  testWidgets('TC-34-G05: deleting a group removes its row', (tester) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Groups');

    await tester.tap(find.byKey(const Key('groups-delete-g-eng')));
    await tester.pumpAndSettle();
    await confirmDelete(tester);

    expect(find.byKey(const Key('groups-tile-g-eng')), findsNothing);
    expect((await backend.listGroups()).isEmpty, isTrue);
  });
}
