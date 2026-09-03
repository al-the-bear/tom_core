/// Widget tests for the share dialog ([ShareDialog]): granting another user a
/// [ProjectRole] on the selected project, driven from the board.
///
/// This is the cross-user half of the four-state model — sharing is how `carol`
/// gains viewer access to a project alice owns. Socket-free: the board and
/// dialog read/write through [AppSession.guard] against the seeded
/// [InMemoryAppBackend], which records the share, so the grantee's next read
/// sees the project. The contract: sharing adds the grantee (and the owner-only
/// rule surfaces inline for a non-owner).
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

  LoginRequest login(String user) => LoginRequest(username: user, password: 'pw');

  /// Pumps the board signed in as [user] over a fresh backend, returning the
  /// live backend so a test can re-read the resulting access.
  Future<InMemoryAppBackend> pumpBoard(WidgetTester tester, String user) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = InMemoryAppBackend();
    final session = AppSession(backend);
    await tester.pumpWidget(AdvancedTodoApp(session: session));
    await session.login(login(user));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> openShareDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('share-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-31-01: owner shares the project and the grantee gains access',
      (tester) async {
    final backend = await pumpBoard(tester, 'alice');

    // Carol has no access before the share.
    await backend.login(login('carol'));
    expect(await backend.listProjects('w-1'), isEmpty);
    await backend.login(login('alice')); // restore the board's principal

    await openShareDialog(tester);
    await tester.enterText(
        find.byKey(const Key('share-grantee-input')), 'u-carol');
    await tester.tap(find.byKey(const Key('share-submit-button')));
    await tester.pumpAndSettle();

    // The dialog closed (success) and the snackbar confirms it.
    expect(find.byKey(const Key('share-dialog')), findsNothing);
    expect(find.text('Project shared'), findsOneWidget);

    // Carol now sees the shared project (default role: viewer).
    await backend.login(login('carol'));
    final projects = await backend.listProjects('w-1');
    expect(projects.map((p) => p.id.get()), contains('p-1'));
  });

  testWidgets('TC-31-02: a non-owner share is rejected inline',
      (tester) async {
    // Bob is an editor on the project (seeded share); only the owner may share.
    await pumpBoard(tester, 'bob');

    await openShareDialog(tester);
    await tester.enterText(
        find.byKey(const Key('share-grantee-input')), 'u-carol');
    await tester.tap(find.byKey(const Key('share-submit-button')));
    await tester.pumpAndSettle();

    // The dialog stays open with the owner-only error surfaced inline.
    expect(find.byKey(const Key('share-dialog')), findsOneWidget);
    expect(find.byKey(const Key('share-error')), findsOneWidget);
  });

  testWidgets('TC-31-03: an empty grantee is blocked before any backend call',
      (tester) async {
    await pumpBoard(tester, 'alice');

    await openShareDialog(tester);
    await tester.tap(find.byKey(const Key('share-submit-button')));
    await tester.pumpAndSettle();

    // Validation kept us on the dialog with the prompt to enter an id.
    expect(find.byKey(const Key('share-dialog')), findsOneWidget);
    expect(find.byKey(const Key('share-error')), findsOneWidget);
  });
}
