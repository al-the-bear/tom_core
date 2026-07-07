// Widget test for the login flow: the app starts at the login screen, rejects a
// bad account inline, and on a good login swaps to the todo list. Drives the
// in-memory backend so the test never touches a socket.

import 'package:core_client_sample/api/in_memory_todo_api.dart';
import 'package:core_client_sample/app/app_session.dart';
import 'package:core_client_sample/app/todo_app.dart';
import 'package:core_client_sample/reflection_seed.dart';
import 'package:core_client_sample/resources/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(appTexts),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(TodoApp(session: AppSession(InMemoryTodoApi())));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String user, String pw) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), user);
    await tester.enterText(fields.at(1), pw);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('CCS-LOGIN-01: starts on the sign-in screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Tom Todo — sign in'), findsOneWidget);
  });

  testWidgets('CCS-LOGIN-02: a good login lands on the todo list',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'alice', 'pw');
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('role: owner'), findsOneWidget);
  });

  testWidgets('CCS-LOGIN-03: a bad account surfaces an inline error',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'nobody', 'pw');
    expect(find.textContaining('Unknown account'), findsOneWidget);
    // Still on the login screen.
    expect(find.text('Tom Todo — sign in'), findsOneWidget);
  });

  testWidgets('CCS-LOGIN-04: logout returns to the sign-in screen',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'alice', 'pw');
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Tom Todo — sign in'), findsOneWidget);
  });
}
