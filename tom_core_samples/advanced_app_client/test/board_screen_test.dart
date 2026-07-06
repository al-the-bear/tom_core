/// Widget tests for the board screen (step 29): the workspace/project picker
/// and the status-column item board over the seeded [InMemoryAppBackend].
///
/// Socket-free — the board reads through [AppSession.guard] against the in-memory
/// fake, which builds the reflected domain tree, so the app's own
/// `initializeReflection()` runs once in [setUpAll] and the resource provider is
/// installed per test. The contract is the step's done bar: items render grouped
/// by `status`, and tapping a card opens its detail.
library;

import 'package:advanced_app_client/app/app.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  final aliceLogin = LoginRequest(username: 'alice', password: 'pw');
  final boardFinder = find.byKey(const Key('board-screen'));
  final detailFinder = find.byKey(const Key('item-detail-screen'));

  // The seeded items: i-1 ('todo') and i-2 ('inProgress').
  const draftItem = 'Draft the landing copy';
  const contactItem = 'Wire the contact form';

  Future<void> pumpBoard(WidgetTester tester) async {
    final session = AppSession(InMemoryAppBackend());
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await session.login(aliceLogin);
    await tester.pumpAndSettle();
  }

  testWidgets('TC-29-01: items render grouped by status', (tester) async {
    await pumpBoard(tester);
    expect(boardFinder, findsOneWidget);

    final todoColumn = find.byKey(const Key('status-column-todo'));
    final inProgressColumn = find.byKey(const Key('status-column-inProgress'));

    // Each item sits in its own status column…
    expect(
      find.descendant(of: todoColumn, matching: find.text(draftItem)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inProgressColumn, matching: find.text(contactItem)),
      findsOneWidget,
    );
    // …and not in the other's.
    expect(
      find.descendant(of: inProgressColumn, matching: find.text(draftItem)),
      findsNothing,
    );
  });

  testWidgets('TC-29-02: tapping an item opens its detail', (tester) async {
    await pumpBoard(tester);
    expect(detailFinder, findsNothing);

    await tester.tap(find.text(draftItem));
    await tester.pumpAndSettle();

    expect(detailFinder, findsOneWidget);
    // The detail shows the tapped item's title in its app bar.
    expect(find.text(draftItem), findsWidgets);
  });

  testWidgets('TC-29-03: the picker shows the seeded workspace and project',
      (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('workspace-picker')), findsOneWidget);
    expect(find.byKey(const Key('project-picker')), findsOneWidget);
    expect(find.text('Acme Engineering'), findsOneWidget);
    expect(find.text('Website relaunch'), findsOneWidget);
  });
}
