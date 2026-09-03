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
/// **Everything on screen below the app-bar title is the framework's.** The
/// phase is one widget — `Tom2FAFlowPanel` over a `SessionTwoFactorController` —
/// so these tests address its keys (`tom-2fa-*`), not this app's. That is the
/// property tcca5 is about: an application gets the chooser, the QR code, the
/// digit field, the attempt counter and the skip rule without writing any of
/// them, and a test that had to reach for app-local keys would mean it had.
///
/// Two halves, matching the two branches a first pass can take:
///
///  * **challenge** (TC-28-05..08) — `dave` already holds a factor, so the login
///    stops at a code prompt: a valid code reaches the board; a wrong one is
///    retryable with the attempts remaining; the third spends the challenge.
///  * **enrolment** (TC-2FA-E1..E6) — `erin` owes a factor and holds none, so
///    she is *offered* one: choose, confirm and land on the board; decline and
///    land there too; and — the round trip the whole feature exists for — sign
///    in again and be *challenged* on the factor just enrolled.
///
/// Two accounts rather than one flag: which accounts owe a factor is seed data
/// in both run modes (`_secrets` / `twoFactorEnrolling` here, the
/// `two_factor_secret` column and the `two_factor_*` role rows live), so signing
/// in as `alice` still goes straight to the board and the suites whose subject
/// is the board, an item or a share are unaffected.
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
    // The screen chrome is server-delivered: install the same canned
    // login bundle the in-memory backend serves, which carries both this app's
    // `twoFactor.title` and the framework flow's own `two_factor.*` keys.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(
        Map<String, dynamic>.from(InMemoryAppBackend.loginTexts),
      ),
    );
  });

  final boardFinder = find.byKey(const Key('board-screen'));
  final errorFinder = find.byKey(const Key('tom-2fa-error'));
  final attemptsFinder = find.byKey(const Key('tom-2fa-attempts'));
  final chooserFinder = find.byKey(const Key('tom-2fa-chooser'));
  final enrolmentFinder = find.byKey(const Key('tom-2fa-enrolment'));
  final challengeFinder = find.byKey(const Key('tom-2fa-challenge'));
  final skipFinder = find.byKey(const Key('tom-2fa-skip'));

  const seededSecret = 'JBSWY3DPEHPK3PXP';

  /// The code an authenticator would show right now for [secret].
  String currentCode(String secret) => TomTotp.codeFor(secret);

  /// A code the backend will refuse for [secret]: any value outside the accepted
  /// skew window. Computed rather than hardcoded, because a literal could
  /// coincidentally *be* the valid code and turn a real failure into a flake.
  String wrongCode(String secret) {
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

  /// Mounts the app over [backend]. The backend is passed in (rather than built
  /// here) so the enrolment tests can keep hold of it across a sign-out — the
  /// factor a confirmation stores lives on the instance.
  Future<void> pumpApp(WidgetTester tester, InMemoryAppBackend backend) async {
    await tester.pumpWidget(AdvancedTodoApp(session: AppSession(backend)));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String user, String pw) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), user);
    await tester.enterText(fields.at(1), pw);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  /// Answers the outstanding challenge through the framework's TOTP panel.
  Future<void> submitChallenge(WidgetTester tester, String code) async {
    await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')), code);
    await tester.tap(find.byKey(const Key('tom-2fa-totp-challenge-submit')));
    await tester.pumpAndSettle();
  }

  /// Confirms the half-built factor through the framework's TOTP panel.
  ///
  /// The QR code makes the enrolment panel taller than the 800×600 test surface,
  /// so the submit button starts below the fold — scroll to it first, as the
  /// user does. Anything else would be tapping a widget nobody can reach.
  Future<void> submitEnrolment(WidgetTester tester, String code) async {
    final submit = find.byKey(const Key('tom-2fa-totp-enrolment-submit'));
    await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')), code);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  /// The secret the enrolment panel is currently showing, read back off the
  /// screen the way a user reads it — so the code these tests derive is derived
  /// from what was actually displayed, not from backend state they reached
  /// around the UI to fetch.
  String displayedSecret(WidgetTester tester) {
    final shown = tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byKey(const Key('tom-2fa-totp-secret')),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;
    return shown.replaceAll(' ', '');
  }

  group('challenge branch — an account that already holds a factor', () {
    testWidgets(
        'TC-28-05: a 2FA account stops at the code phase instead of the board',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'dave', 'dave-pass');

      // The password was accepted, but this is not a session: the interim token
      // authorizes nothing, so the shell must still be on the sign-in screen.
      expect(find.text('Advanced Todo — Two-step verification'), findsOneWidget);
      expect(challengeFinder, findsOneWidget);
      expect(boardFinder, findsNothing);
      // The field is sized from the challenge, and all three attempts are intact.
      expect(find.text('3 attempt(s) remaining.'), findsOneWidget);
      expect(errorFinder, findsNothing);
      // A held factor is challenged, never re-offered: no chooser, no skip.
      expect(chooserFinder, findsNothing);
      expect(skipFinder, findsNothing);
    });

    testWidgets(
        'TC-28-06: a valid code completes the login and reaches the board',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'dave', 'dave-pass');
      await submitChallenge(tester, currentCode(seededSecret));

      expect(boardFinder, findsOneWidget);
      expect(find.text('Signed in as Dave Dijkstra (2FA)'), findsOneWidget);
    });

    testWidgets(
        'TC-28-07: a wrong code shows a retryable error with the attempts remaining',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'dave', 'dave-pass');
      await submitChallenge(tester, wrongCode(seededSecret));

      // Still in the code phase, with the attempt spent — the count moves
      // whether or not the code was right, exactly as the server's
      // token-carried counter does.
      expect(find.text('Advanced Todo — Two-step verification'), findsOneWidget);
      expect(errorFinder, findsOneWidget);
      expect(attemptsFinder, findsOneWidget);
      expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
      expect(boardFinder, findsNothing);

      // Retryable means exactly that: the right code still completes the login.
      await submitChallenge(tester, currentCode(seededSecret));
      expect(boardFinder, findsOneWidget);
    });

    testWidgets('TC-28-08: a third wrong code returns to the password screen',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'dave', 'dave-pass');

      final bad = wrongCode(seededSecret);
      await submitChallenge(tester, bad);
      expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
      await submitChallenge(tester, bad);
      expect(find.text('1 attempt(s) remaining.'), findsOneWidget);
      await submitChallenge(tester, bad);

      // The challenge is spent, so the code phase is gone: the user is back at
      // username/password with the refusal still on screen explaining why.
      expect(find.text('Advanced Todo — Sign in'), findsOneWidget);
      expect(challengeFinder, findsNothing);
      expect(attemptsFinder, findsNothing);
      expect(find.byKey(const Key('login-error')), findsOneWidget);
      expect(boardFinder, findsNothing);
    });
  });

  group('enrolment branch — an account offered a factor it does not hold', () {
    // `erin` is the offer's account, as `dave` is the challenge's: she is in
    // `twoFactorEnrolling` and holds no secret, exactly as the live `[005]`
    // migration seeds her with the `two_factor_optional` role and a NULL
    // `two_factor_secret`. Which account is offered a factor is seed data in
    // both modes, so these tests sign in as the account that owes one rather
    // than flipping a switch on the backend.

    testWidgets('TC-2FA-E1: the first login lands on the method chooser',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'erin', 'erin-pass');

      expect(chooserFinder, findsOneWidget);
      expect(boardFinder, findsNothing);
      // Labelled from the mechanism descriptor's resource keys, not a literal.
      expect(find.byKey(const Key('tom-2fa-method-totp')), findsOneWidget);
      expect(find.text('Authenticator app'), findsOneWidget);
      // The offer is skippable, so the affordance is there — and it is there
      // *because the server said so*, which is what the next test pins down.
      expect(skipFinder, findsOneWidget);
      // Skipping is free under an `optional` policy, so no grace warning.
      expect(find.byKey(const Key('tom-2fa-skip-cost')), findsNothing);
    });

    testWidgets(
        'TC-2FA-E2: choosing TOTP shows the QR code, the typable secret and the account',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'erin', 'erin-pass');
      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      expect(enrolmentFinder, findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-totp-secret')), findsOneWidget);
      // The account the factor is for, so a user with several in one app can
      // tell the QR codes apart. It comes from the session's pending account —
      // there is no logged-in user yet.
      expect(find.byKey(const Key('tom-2fa-totp-account')), findsOneWidget);
      expect(find.text('erin'), findsOneWidget);
      // The secret is real base32 of the seeded length, grouped for typing.
      expect(displayedSecret(tester), matches(RegExp(r'^[A-Z2-7]{32}$')));
    });

    testWidgets(
        'TC-2FA-E3: confirming with a code from the shown secret completes the login',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'erin', 'erin-pass');
      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      await submitEnrolment(tester, currentCode(displayedSecret(tester)));

      expect(boardFinder, findsOneWidget);
      expect(find.text('Signed in as Erin Nakamura (2FA setup)'), findsOneWidget);
    });

    testWidgets('TC-2FA-E4: a wrong confirmation code is retryable',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'erin', 'erin-pass');
      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      final secret = displayedSecret(tester);
      await submitEnrolment(tester, wrongCode(secret));

      // Still enrolling, with the attempt spent and the same secret on screen —
      // a refusal must not silently re-roll the factor being set up, or the
      // authenticator the user already scanned would be stale.
      expect(enrolmentFinder, findsOneWidget);
      expect(errorFinder, findsOneWidget);
      expect(find.text('2 attempt(s) remaining.'), findsOneWidget);
      expect(displayedSecret(tester), secret);
      expect(boardFinder, findsNothing);

      await submitEnrolment(tester, currentCode(secret));
      expect(boardFinder, findsOneWidget);
    });

    testWidgets('TC-2FA-E5: declining a skippable offer signs in without one',
        (tester) async {
      await pumpApp(tester, InMemoryAppBackend());
      await signIn(tester, 'erin', 'erin-pass');
      await tester.ensureVisible(skipFinder);
      await tester.pumpAndSettle();
      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      expect(boardFinder, findsOneWidget);
      expect(find.text('Signed in as Erin Nakamura (2FA setup)'), findsOneWidget);
    });

    testWidgets(
        'TC-2FA-E6: after enrolling, the next sign-in is challenged on the new factor',
        (tester) async {
      // The whole point of enrolment, and the one assertion that needs the two
      // halves of this file to meet: the factor a confirmation stores is a
      // factor the *next* login is challenged on. One backend instance across
      // both sign-ins, because that is where the enrolment landed.
      final backend = InMemoryAppBackend();
      await pumpApp(tester, backend);
      await signIn(tester, 'erin', 'erin-pass');
      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();
      final secret = displayedSecret(tester);
      await submitEnrolment(tester, currentCode(secret));
      expect(boardFinder, findsOneWidget);

      await tester.tap(find.byKey(const Key('logout-button')));
      await tester.pumpAndSettle();
      await signIn(tester, 'erin', 'erin-pass');

      // Challenged, not offered: the account now holds a factor.
      expect(challengeFinder, findsOneWidget);
      expect(chooserFinder, findsNothing);
      await submitChallenge(tester, currentCode(secret));
      expect(boardFinder, findsOneWidget);
    });
  });
}
