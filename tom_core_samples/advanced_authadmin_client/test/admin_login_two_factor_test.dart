/// Widget tests for the admin console's two-pass login.
///
/// The seeded `auth_db` enrols **no** administrator in TOTP, so
/// [InMemoryAdminBackend] enrols none either — an offline console that demanded
/// a code the real one does not would teach the wrong thing. But an enrolment is
/// an *account* property the console does not control: the day someone enrols
/// `admin`, a console that ignored `requires2FA` would store the interim token
/// and then fail every call. That is what these tests pin down, by injecting the
/// enrolment the fake takes as a constructor argument.
///
/// Socket-free, and the crypto is not faked: the backend verifies with the
/// kernel's own [TomTotp], so these tests derive their code exactly the way an
/// authenticator app does.
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // The chrome is server-delivered: the canned bundle carries the
    // `adminTwoFactor.*` scope the code phase renders from.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(
        Map<String, dynamic>.from(InMemoryAdminBackend.loginTexts),
      ),
    );
  });

  final loginFinder = find.byKey(const Key('admin-login-screen'));
  final shellFinder = find.byKey(const Key('admin-shell-screen'));
  final errorFinder = find.byKey(const Key('admin-login-error'));
  final attemptsFinder = find.byKey(const Key('admin-login-attempts'));

  /// The code an authenticator would show right now for the seeded secret.
  String currentCode() =>
      TomTotp.codeFor(InMemoryAdminBackend.demoTotpSecret);

  /// A code the backend will refuse: any six-digit value outside the accepted
  /// skew window. Computed rather than hardcoded, because a literal could
  /// coincidentally *be* the valid code and turn a real failure into a flake.
  String wrongCode() {
    final key = TomTotp.decodeBase32(InMemoryAdminBackend.demoTotpSecret);
    final counter = TomTotp.counterFor(period: InMemoryAdminBackend.totpPeriod);
    final accepted = <String>{
      for (var offset = -InMemoryAdminBackend.totpWindowSteps;
          offset <= InMemoryAdminBackend.totpWindowSteps;
          offset++)
        TomTotp.generateCode(
            key, counter + offset, InMemoryAdminBackend.totpDigits),
    };
    for (var candidate = 0; candidate < 10; candidate++) {
      final code = '$candidate' * InMemoryAdminBackend.totpDigits;
      if (!accepted.contains(code)) return code;
    }
    throw StateError('no refusable code available');
  }

  /// Pumps the console over a backend in which [twoFactorUsernames] are enrolled.
  Future<void> pumpConsole(
    WidgetTester tester, {
    Set<String> twoFactorUsernames = const {'admin'},
  }) async {
    await tester.pumpWidget(
      AdminConsoleApp(
        session: AdminSession(
          InMemoryAdminBackend(twoFactorUsernames: twoFactorUsernames),
        ),
      ),
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
      'TC-33-07: an enrolled admin stops at the code phase instead of the shell',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);

    // The password was accepted, but this is not a session — and the `admin`
    // probe has deliberately not run, because the interim token authorizes
    // nothing and the probe would fail for the wrong reason.
    expect(loginFinder, findsOneWidget);
    expect(
        find.text('Advanced Todo — Admin two-step verification'), findsOneWidget);
    expect(shellFinder, findsNothing);
    expect(find.text('3 attempt(s) remaining.'), findsOneWidget);
    expect(errorFinder, findsNothing);
  });

  testWidgets('TC-33-08: a valid code completes the login and opens the shell',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);
    await submitCode(tester, currentCode());

    // Pass 2 done, then the `admin` probe — the shell opens on its default
    // destination exactly as a single-pass admin login opens it.
    expect(shellFinder, findsOneWidget);
    expect(find.byKey(const Key('users-screen')), findsOneWidget);
    expect(loginFinder, findsNothing);
  });

  testWidgets(
      'TC-33-09: a wrong code shows a retryable error with the attempts remaining',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);
    await submitCode(tester, wrongCode());

    expect(errorFinder, findsOneWidget);
    expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
    expect(shellFinder, findsNothing);

    // Retryable means exactly that: the right code still opens the console.
    await submitCode(tester, currentCode());
    expect(shellFinder, findsOneWidget);
  });

  testWidgets('TC-33-10: a third wrong code returns to the password screen',
      (tester) async {
    await pumpConsole(tester);
    await signIn(tester, 'admin', InMemoryAdminBackend.demoPassword);

    final bad = wrongCode();
    await submitCode(tester, bad);
    expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
    await submitCode(tester, bad);
    expect(find.text('1 attempt(s) remaining.'), findsOneWidget);
    await submitCode(tester, bad);

    expect(find.text('Advanced Todo — Admin sign in'), findsOneWidget);
    expect(attemptsFinder, findsNothing);
    expect(errorFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });

  testWidgets(
      'TC-33-11: an enrolled non-admin is still refused, one pass later',
      (tester) async {
    await pumpConsole(tester, twoFactorUsernames: {'alice'});
    await signIn(tester, 'alice', InMemoryAdminBackend.demoPassword);

    // Pass 1 succeeded — the second factor is an account property, not a role
    // check — so the code phase opens for her too.
    expect(
        find.text('Advanced Todo — Admin two-step verification'), findsOneWidget);
    await submitCode(tester, currentCode());

    // …and only now does the `admin` probe run, and refuse her.
    expect(errorFinder, findsOneWidget);
    expect(find.text('Administrator access is required.'), findsOneWidget);
    expect(loginFinder, findsOneWidget);
    expect(shellFinder, findsNothing);
  });
}
