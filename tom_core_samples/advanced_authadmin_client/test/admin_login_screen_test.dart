/// Widget tests for the admin login + shell (step 33): the console's sign-in
/// driving [AdminSession.login] through the seeded in-memory backend, and the
/// shell it opens onto once an administrator is authenticated.
///
/// Socket- and reflection-free — the console runs over [InMemoryAdminBackend]
/// and the login is a plain Material form (no reflected `TomForm`), so unlike the
/// app client's login test this one needs no `initializeReflection`. The
/// contract is the step's done bar: an admin proceeds to the console shell; a
/// signed-in non-admin is rejected at login with an access error and never
/// leaves the page.
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loginFinder = find.byKey(const Key('admin-login-screen'));
  final shellFinder = find.byKey(const Key('admin-shell-screen'));
  final errorFinder = find.byKey(const Key('admin-login-error'));

  Future<void> pumpConsole(WidgetTester tester) async {
    await tester.pumpWidget(
      AdminConsoleApp(session: AdminSession(InMemoryAdminBackend())),
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

  testWidgets('TC-33-01: the console starts on the admin sign-in screen',
      (tester) async {
    await pumpConsole(tester);
    expect(loginFinder, findsOneWidget);
    expect(find.text('Advanced Todo — Admin sign in'), findsOneWidget);
    expect(shellFinder, findsNothing);
  });

  testWidgets('TC-33-02: an admin login proceeds to the console shell',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);

    expect(shellFinder, findsOneWidget);
    expect(find.text('Signed in as Administrator'), findsOneWidget);
    expect(loginFinder, findsNothing);
  });

  testWidgets(
      'TC-33-03: a signed-in non-admin is rejected with an access error',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'alice', InMemoryAdminBackend.demoPassword);

    // Authenticated, but the admin probe refused: an inline error, still on
    // login, the shell never opened.
    expect(errorFinder, findsOneWidget);
    expect(find.text('Administrator access is required.'), findsOneWidget);
    expect(loginFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });

  testWidgets('TC-33-04: bad credentials show an inline error without leaving',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', 'wrong');

    expect(errorFinder, findsOneWidget);
    expect(find.text('Invalid administrator credentials.'), findsOneWidget);
    expect(loginFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });

  testWidgets('TC-33-05: empty credentials fail validation and never submit',
      (tester) async {
    await pumpConsole(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Validation blocked the submit: no backend error, still on login.
    expect(errorFinder, findsNothing);
    expect(loginFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });

  testWidgets('TC-33-06: signing out from the shell routes back to login',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);
    expect(shellFinder, findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pumpAndSettle();

    expect(loginFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });
}
