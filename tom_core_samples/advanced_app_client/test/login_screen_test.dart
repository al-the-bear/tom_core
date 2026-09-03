/// Widget tests for the bound login screen ([LoginScreen]): the `TomForm` over
/// credentials driving [AppSession.login] through the seeded in-memory backend.
///
/// Socket-free — the screen runs over [InMemoryAppBackend]. The fake builds the
/// reflected domain tree and the form binds reflected credentials, so the app's
/// own `initializeReflection()` runs once in [setUpAll] and the resource
/// provider is installed per test. The contract: a valid login proceeds to the
/// board; a rejected login shows an inline error without leaving the page.
library;

import 'package:advanced_app_client/app/app.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // The screen chrome (title/intro/submit) is server-delivered: install the
    // same canned login bundle the in-memory backend serves so the rendered
    // texts match what the live auth server would deliver.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(
        Map<String, dynamic>.from(InMemoryAppBackend.loginTexts),
      ),
    );
  });

  final boardFinder = find.byKey(const Key('board-screen'));
  final errorFinder = find.byKey(const Key('login-error'));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AdvancedTodoApp(session: AppSession(InMemoryAppBackend())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String user, String pw) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), user);
    await tester.enterText(fields.at(1), pw);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-28-01: the app starts on the sign-in screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(boardFinder, findsNothing);
  });

  testWidgets('TC-28-02: a valid login proceeds to the board', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'alice', 'pw');

    expect(boardFinder, findsOneWidget);
    expect(find.text('Signed in as Alice (owner)'), findsOneWidget);
  });

  testWidgets(
      'TC-28-03: a rejected login shows an inline error without leaving the page',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'mallory', 'pw');

    expect(errorFinder, findsOneWidget);
    // Still on the login screen — the shell never swapped to the board.
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(boardFinder, findsNothing);
  });

  testWidgets('TC-28-04: empty credentials fail validation and never submit',
      (tester) async {
    await pumpApp(tester);
    // Tap Sign in with both fields empty.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // No backend call was made (no inline backend error) and we stay on login.
    expect(errorFinder, findsNothing);
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(boardFinder, findsNothing);
  });
}
