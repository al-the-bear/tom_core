// Widget tests for the detail screen: CRUD through the bound form, plus the
// per-role four-state authorization rendering. These are the heart of what the
// sample teaches — the same TodoItemForm renders differently for owner, member
// and viewer because it is constructed with the session's resolved field matrix.

import 'package:core_client_sample/api/in_memory_todo_api.dart';
import 'package:core_client_sample/app/app_session.dart';
import 'package:core_client_sample/app/todo_app.dart';
import 'package:core_client_sample/reflection_seed.dart';
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

  Future<AppSession> pumpSignedIn(WidgetTester tester, String user) async {
    // A tall viewport so the detail form's fields and Save button all fit
    // on-screen (the default 800×600 window scrolls the button out of reach).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AppSession(InMemoryTodoApi());
    await tester.pumpWidget(TodoApp(session: session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), user);
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> openFirstItem(WidgetTester tester) async {
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
  }

  testWidgets('CCS-CRUD-01: owner sees every gradable field on a todo',
      (tester) async {
    await pumpSignedIn(tester, 'alice');
    await openFirstItem(tester);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Assignee id'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('CCS-CRUD-02: member never sees priority (TomAuthState.none)',
      (tester) async {
    await pumpSignedIn(tester, 'bob');
    await openFirstItem(tester);
    expect(find.text('Title'), findsOneWidget);
    // priority is `none` for member → the field collapses to nothing.
    expect(find.text('Priority'), findsNothing);
  });

  testWidgets('CCS-CRUD-03: owner creates a todo and it appears in the list',
      (tester) async {
    await pumpSignedIn(tester, 'alice');
    await tester.tap(find.byTooltip('New todo'));
    await tester.pumpAndSettle();

    // The Title field is the first TextField on the detail screen.
    await tester.enterText(find.byType(TextField).first, 'Fresh todo');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh todo'), findsOneWidget);
  });

  testWidgets('CCS-CRUD-04: saving a new todo with an empty title is blocked',
      (tester) async {
    await pumpSignedIn(tester, 'alice');
    await tester.tap(find.byTooltip('New todo'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Still on the detail screen — validation kept us here.
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });
}
