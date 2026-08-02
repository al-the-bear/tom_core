/// Widget tests for the two-pass login: the second-factor phase of the sign-in
/// screen, driven through the seeded in-memory backend.
///
/// Socket-free — the screen runs over [InMemoryAppBackend], whose `dave` account
/// carries the *same* TOTP secret the auth server's `[005]-auth_two_factor_seed`
/// migration seeds. The fake does not fake the crypto: it verifies with the
/// kernel's own [TomTotp], so these tests derive their code exactly the way a
/// human derives one from an authenticator app, and a code that passes here is a
/// code that passes against the live server.
///
/// The contract is csexe4's done bar, in three outcomes: a valid code reaches
/// the board; a wrong code shows a retryable error with the attempts remaining;
/// the third wrong code spends the challenge and returns to the password screen.
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
    // The screen chrome is server-delivered (todo 8): install the same canned
    // login bundle the in-memory backend serves, which now carries the
    // `twoFactor.*` scope the code phase renders from.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(
        Map<String, dynamic>.from(InMemoryAppBackend.loginTexts),
      ),
    );
  });

  final boardFinder = find.byKey(const Key('board-screen'));
  final errorFinder = find.byKey(const Key('login-error'));
  final attemptsFinder = find.byKey(const Key('login-attempts'));

  const secret = 'JBSWY3DPEHPK3PXP';

  /// The code an authenticator would show right now for the seeded secret.
  String currentCode() => TomTotp.codeFor(secret);

  /// A six-digit code the backend will refuse: any value outside the accepted
  /// skew window. Computed rather than hardcoded, because a literal could
  /// coincidentally *be* the valid code and turn a real failure into a flake.
  String wrongCode() {
    final key = TomTotp.decodeBase32(secret);
    final counter = TomTotp.counterFor(period: InMemoryAppBackend.totpPeriod);
    final accepted = <String>{
      for (var offset = -InMemoryAppBackend.totpWindowSteps;
          offset <= InMemoryAppBackend.totpWindowSteps;
          offset++)
        TomTotp.generateCode(
            key, counter + offset, InMemoryAppBackend.totpDigits),
    };
    for (var candidate = 0; candidate < 10; candidate++) {
      final code = '$candidate' * InMemoryAppBackend.totpDigits;
      if (!accepted.contains(code)) return code;
    }
    throw StateError('no refusable code available');
  }

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

  Future<void> submitCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TC-28-05: a 2FA account stops at the code phase instead of the board',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'dave', 'dave-pass');

    // The password was accepted, but this is not a session: the interim token
    // authorizes nothing, so the shell must still be on the sign-in screen.
    expect(find.text('Advanced Todo — Two-step verification'), findsOneWidget);
    expect(boardFinder, findsNothing);
    // The field is sized from the challenge, and all three attempts are intact.
    expect(find.text('3 attempt(s) remaining.'), findsOneWidget);
    expect(errorFinder, findsNothing);
  });

  testWidgets('TC-28-06: a valid code completes the login and reaches the board',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'dave', 'dave-pass');
    await submitCode(tester, currentCode());

    expect(boardFinder, findsOneWidget);
    expect(find.text('Signed in as Dave Dijkstra (2FA)'), findsOneWidget);
  });

  testWidgets(
      'TC-28-07: a wrong code shows a retryable error with the attempts remaining',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'dave', 'dave-pass');
    await submitCode(tester, wrongCode());

    // Still in the code phase, with the attempt spent — the count moves whether
    // or not the code was right, exactly as the server's token-carried counter
    // does.
    expect(find.text('Advanced Todo — Two-step verification'), findsOneWidget);
    expect(errorFinder, findsOneWidget);
    expect(attemptsFinder, findsOneWidget);
    expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
    expect(boardFinder, findsNothing);

    // Retryable means exactly that: the right code still completes the login.
    await submitCode(tester, currentCode());
    expect(boardFinder, findsOneWidget);
  });

  testWidgets('TC-28-08: a third wrong code returns to the password screen',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'dave', 'dave-pass');

    final bad = wrongCode();
    await submitCode(tester, bad);
    expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
    await submitCode(tester, bad);
    expect(find.text('1 attempt(s) remaining.'), findsOneWidget);
    await submitCode(tester, bad);

    // The challenge is spent, so the code phase is gone: the user is back at
    // username/password with the refusal still on screen explaining why.
    expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
    expect(attemptsFinder, findsNothing);
    expect(errorFinder, findsOneWidget);
    expect(boardFinder, findsNothing);
  });
}
