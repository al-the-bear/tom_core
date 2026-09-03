/// Widget tests for the Grants destination (`GrantsScreen`): the `projectRole` ×
/// field-resource-key grant matrix editor over the seeded in-memory backend.
///
/// The matrix is the four-state authorization grid: each cell cycles
/// `none → disabled → read → full` on tap, and Save writes the whole
/// [GrantMatrixDto] back through `putGrants` then re-reads it. The contract:
/// editing a cell and saving issues the expected matrix to the backend, and a
/// reload reflects exactly what was persisted.
///
/// Socket-free, but driven through the same shared harness: sign in, then open
/// the rail's Grants destination. The grants screen itself carries no `TomForm`,
/// but signing in renders the reflected [AdminLoginForm], so the console's
/// `initializeReflection()` runs once in [setUpAll] like the CRUD suites.
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'support/admin_console_harness.dart';

void main() {
  setUpAll(initializeReflection);

  const ownerTitle = Key('grant-cell-owner-todo.item.title');

  // The label the cell renders for each state (distinct per state). Reading is
  // position-independent — the finder walks the element tree, not the screen.
  String labelOf(WidgetTester tester, Key cell) => tester
      .widget<Text>(
        find.descendant(of: find.byKey(cell), matching: find.byType(Text)),
      )
      .data!;

  // Tapping is *not* position-independent. The grid scrolls horizontally and the
  // matrix spans eight graded keys (the seven form fields plus
  // `todo.item.attachment`), so `todo.item.title` — last in the sorted column
  // order — lies beyond the right edge of the 800×600 test surface. A tap at an
  // off-screen offset hit-tests nothing and silently does nothing, so scroll the
  // cell into view first. This is a property of the narrow test viewport, not of
  // the screen: a real window either fits the grid or lets the user scroll to it.
  Future<void> tapCell(WidgetTester tester, Key cell) async {
    await tester.ensureVisible(find.byKey(cell));
    await tester.pump();
    await tester.tap(find.byKey(cell));
  }

  testWidgets('TC-35-01: the Grants tab renders the seeded matrix', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Grants');

    expect(find.byKey(const Key('grants-screen')), findsOneWidget);
    // owner.title is seeded full; viewer.status is seeded disabled.
    expect(labelOf(tester, ownerTitle), 'Full');
    expect(
      labelOf(tester, const Key('grant-cell-viewer-todo.item.status')),
      'Disabled',
    );
  });

  testWidgets('TC-35-02: a cell cycles none → disabled → read → full on tap', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Grants');

    // owner.title starts Full; the next tap wraps to Hidden, then climbs.
    expect(labelOf(tester, ownerTitle), 'Full');
    await tapCell(tester, ownerTitle);
    await tester.pump();
    expect(labelOf(tester, ownerTitle), 'Hidden');
    await tapCell(tester, ownerTitle);
    await tester.pump();
    expect(labelOf(tester, ownerTitle), 'Disabled');
    await tapCell(tester, ownerTitle);
    await tester.pump();
    expect(labelOf(tester, ownerTitle), 'Read');
  });

  testWidgets('TC-35-03: Save is disabled until a cell changes', (
    tester,
  ) async {
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await openDestination(tester, 'Grants');

    // The grants-save key is on the TomFilledButton wrapper; the enabled/disabled
    // state lives on the FilledButton it renders, so reach through to it.
    FilledButton saveButton() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('grants-save')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(saveButton().onPressed, isNull); // pristine

    await tapCell(tester, ownerTitle);
    await tester.pump();
    expect(saveButton().onPressed, isNotNull); // dirty
  });

  testWidgets('TC-35-04: saving issues the edited matrix to the backend', (
    tester,
  ) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Grants');

    // owner.title Full → Hidden (one wrap), then persist.
    await tapCell(tester, ownerTitle);
    await tester.pump();
    await tester.tap(find.byKey(const Key('grants-save')));
    await tester.pumpAndSettle();

    final saved = await backend.getGrants();
    expect(saved.accessFor('owner', 'todo.item.title'), TomAuthState.none);
    // Other cells are untouched.
    expect(saved.accessFor('owner', 'todo.item.status'), TomAuthState.full);
    expect(
      saved.accessFor('viewer', 'todo.item.status'),
      TomAuthState.disabled,
    );
  });

  testWidgets('TC-35-05: a reload reflects the persisted matrix', (
    tester,
  ) async {
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    await openDestination(tester, 'Grants');

    // Edit two taps (Full → Hidden → Disabled) and save.
    await tapCell(tester, ownerTitle);
    await tapCell(tester, ownerTitle);
    await tester.pump();
    expect(labelOf(tester, ownerTitle), 'Disabled');
    await tester.tap(find.byKey(const Key('grants-save')));
    await tester.pumpAndSettle();

    // After save, Save reverts to disabled (the grid is clean again) and the
    // cell shows the re-read state.
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('grants-save')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(labelOf(tester, ownerTitle), 'Disabled');

    // A fresh console over the same backend loads the persisted matrix.
    await tester.pumpWidget(AdminConsoleApp(session: AdminSession(backend)));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), InMemoryAdminBackend.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await openDestination(tester, 'Grants');

    expect(labelOf(tester, ownerTitle), 'Disabled');
  });
}
