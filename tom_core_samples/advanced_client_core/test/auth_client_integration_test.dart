/// Live integration tests for [AuthClient]: logs in against a running
/// `advanced_auth_server` on `localhost:8081` with the seeded accounts and
/// asserts the returned principal plus stored bearer — for `alice`, whose login
/// is single-pass; for `dave`, who owes a TOTP second factor; and for
/// `erin`, who owes one and holds none, so her login is *offered* one.
///
/// This needs the auth server *and* its database up (see
/// `../advanced_auth_server/README.md`). Because neither is guaranteed in a
/// headless CI/dev box, the tests **skip themselves at runtime when the server
/// is unreachable** (a connection refusal calls [markTestSkipped] instead of
/// failing) — the unit suites (`auth_client_test.dart`,
/// `auth_client_two_factor_test.dart`) carry the always-on coverage; these prove
/// the wire path end-to-end when an operator brings the server up locally.
///
/// The two-pass cases are the only place the *whole* second-factor loop runs
/// over a real socket: the client's own suite fakes the transport, and the
/// server's fakes the client. Here the real [AuthClient] talks to the real
/// `TomAuthenticationServer` through the real `/auth/*` endpoints, against a
/// secret that came out of the database rather than out of a fixture — and, in
/// erin's case, against one that did not exist until the test asked for it.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _authBaseUri = 'http://localhost:8081';

/// The TOTP secret the `@dev,test` [005] migration enrols `dave` with.
///
/// Mirrored here so the test can derive the very codes the *server* will expect;
/// a sample credential, which is exactly why that migration is environment
/// tagged and never reaches production.
const _daveSecret = 'JBSWY3DPEHPK3PXP';

/// The code an authenticator holding [secret] would be showing right now.
///
/// This is the client standing in for the authenticator app, so it derives the
/// code the way an app would: through the kernel's [TomTotp] primitive — the
/// same one the server verifies with, which is precisely why the client needs
/// no dependency on the server package to produce a code it will accept. It is
/// also why the enrolment leg below needs no app at all: a secret the server
/// just minted is a secret this can already answer for.
///
/// [stepOffset] shifts the time step; a large offset yields a well-formed code
/// far outside the accepted skew window, i.e. a *wrong* one.
String _codeFor(String secret, {int stepOffset = 0}) => TomTotp.generateCode(
  TomTotp.decodeBase32(secret),
  TomTotp.counterFor() + stepOffset,
);

void main() {
  setUpAll(initializeReflection);

  group('AuthClient (live auth server)', () {
    setUp(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );
    tearDown(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );

    test('TC-22-11: logs in alice and stores the bearer', () async {
      // The live transport is owned here so it can be closed regardless of
      // outcome (and so a connection refusal is observable as a SocketException).
      final transport = IoJsonTransport();
      final client = AuthClient(Uri.parse(_authBaseUri), transport: transport);

      final LoginResult result;
      try {
        result = await client.login(
          LoginRequest(username: 'alice', password: 'alice-pass'),
        );
      } on SocketException catch (e) {
        markTestSkipped(
          'auth server not reachable on $_authBaseUri — start '
          'advanced_auth_server to run this integration test ($e)',
        );
        return;
      } finally {
        transport.close();
      }

      expect(result.user.username, equals('alice'));
      expect(result.authzToken, isNotEmpty);
      expect(
        TomBearerAuthentication.authorizationToken,
        equals(result.authzToken),
      );
      // Alice owes no second factor, so pass 1 *is* the whole login.
      expect(result.requires2FA, isFalse);
      expect(client.pendingChallenge, isNull);
    });

    // The two-pass login over a real socket: the only place where the real
    // AuthClient, the real TomAuthenticationServer, the real endpoints and a
    // secret that came out of the database all take part in one run. The
    // package's own suites necessarily fake one side or the other — the client
    // suite fakes the transport, the server suite fakes the client — so a
    // disagreement between the two halves (a claim name, a status code, the
    // shape of the retry body) could only ever surface here.
    test(
      'TC-22-12: completes dave\'s two-pass login and ends up authenticated',
      () async {
        final transport = IoJsonTransport();
        final client = AuthClient(
          Uri.parse(_authBaseUri),
          transport: transport,
        );

        try {
          final pass1 = await client.login(
            LoginRequest(username: 'dave', password: 'dave-pass'),
          );

          // Pass 1 stops half-way: the right password alone does not authenticate
          // an enrolled account.
          expect(pass1.requires2FA, isTrue);
          expect(pass1.twoFactorType, equals('totp'));
          final challenge = client.pendingChallenge;
          expect(
            challenge,
            isNotNull,
            reason: 'the interim token must carry the challenge',
          );
          expect(challenge!.type, equals('totp'));
          expect(challenge.isExpired(), isFalse);
          expect(
            TomBearerAuthentication.getPrincipal().authenticated,
            isFalse,
            reason: 'an interim token must not authenticate its bearer',
          );

          // A wrong code is refused but retryable, and spends one attempt.
          final before = client.pendingChallenge!.attemptsRemaining;
          await expectLater(
            client.submitSecondFactor(_codeFor(_daveSecret, stepOffset: 1000)),
            throwsA(
              isA<AuthClientException>().having(
                (e) => e.canRetrySecondFactor,
                'canRetry',
                isTrue,
              ),
            ),
          );
          expect(
            client.pendingChallenge!.attemptsRemaining,
            equals(before - 1),
            reason: 'the refusal must hand back a token with the attempt spent',
          );

          // The right code completes the login against that re-issued token.
          final pass2 = await client.submitSecondFactor(_codeFor(_daveSecret));

          expect(pass2.requires2FA, isFalse);
          expect(pass2.user.username, equals('dave'));
          expect(pass2.authzToken, isNotEmpty);
          expect(
            TomBearerAuthentication.authorizationToken,
            equals(pass2.authzToken),
          );
          // What the whole two-pass flow exists to produce: pass 2 yields the
          // session a 2FA-free login would have, with nothing left to answer.
          expect(client.pendingChallenge, isNull);
          expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
        } on SocketException catch (e) {
          markTestSkipped(
            'auth server not reachable on $_authBaseUri — start '
            'advanced_auth_server to run this integration test ($e)',
          );
          return;
        } finally {
          transport.close();
        }
      },
    );

    // Mid-run enrolment over a real socket: a factor that did not exist when the
    // run started is offered, declined, set up, and then *challenged* on the
    // next login. Three sign-ins in one test rather than three tests, because
    // the beats are a sequence over one account's server-side state — split up,
    // each would silently depend on the previous having run, and a re-run of
    // just one of them would face a database the others had already moved.
    //
    // Nothing here needs an authenticator app: the secret arrives in the
    // enrolment's `clientData` and the code is derived from it with the kernel's
    // own [TomTotp], exactly as the Flutter panel's user derives one by hand.
    test('TC-22-13: erin declines the offer, then enrols a TOTP factor and is '
        'challenged on it', () async {
      final transport = IoJsonTransport();
      final client = AuthClient(Uri.parse(_authBaseUri), transport: transport);

      try {
        // ── 1. Offered, and free to decline ────────────────────────────────
        // Erin holds the `two_factor_optional` role and no factor, so pass 1
        // stops at an *offer* rather than a challenge — the branch that only
        // exists once a policy distinguishes "must have one" from "may".
        final offer1 = await client.login(
          LoginRequest(username: 'erin', password: 'erin-pass'),
        );
        expect(offer1.requires2FAEnrolment, isTrue);
        expect(
          offer1.requires2FA,
          isFalse,
          reason: 'nothing to answer yet — there is no factor',
        );
        expect(
          offer1.availableTwoFactorMethods.map((m) => m.type),
          contains('totp'),
        );
        // Descriptors, not labels: what crosses the wire is resource *keys*,
        // so the client renders text it looked up rather than text the auth
        // server chose (G-RES-5).
        expect(
          offer1.availableTwoFactorMethods.single.displayNameKey,
          equals('two_factor.totp.name'),
        );
        expect(offer1.twoFactorEnrolmentSkippable, isTrue);
        expect(
          TomBearerAuthentication.getPrincipal().authenticated,
          isFalse,
          reason: 'an enrolment token must not authenticate its bearer',
        );
        expect(
          client.pendingEnrolment!.hasOffer,
          isFalse,
          reason: 'still choosing: no mechanism has been begun',
        );

        final skipped = await client.skipEnrolment();
        expect(skipped.requires2FAEnrolment, isFalse);
        expect(skipped.user.username, equals('erin'));
        expect(
          TomBearerAuthentication.getPrincipal().authenticated,
          isTrue,
          reason: 'declining a skippable offer still yields a session',
        );
        await client.logout();

        // ── 2. Offered again, and enrolled ─────────────────────────────────
        // Declining stored nothing, so the next login is the same offer. That
        // is what `skippable` means under an `optional` policy — a decline
        // postpones, it does not opt out.
        final offer2 = await client.login(
          LoginRequest(username: 'erin', password: 'erin-pass'),
        );
        expect(offer2.requires2FAEnrolment, isTrue);

        await client.beginEnrolment('totp');
        final pending = client.pendingEnrolment!;
        expect(pending.hasOffer, isTrue);
        expect(pending.type, equals('totp'));
        final secret = pending.clientData['secret']! as String;
        expect(
          secret,
          matches(RegExp(r'^[A-Z2-7]+$')),
          reason: 'the shown secret must be typable base32',
        );
        expect(pending.clientData['otpauthUri'], contains('erin'));

        // A wrong confirmation is refused but retryable, and does not re-roll
        // the secret — the authenticator the user has already scanned must stay
        // valid across a mistyped digit.
        await expectLater(
          client.confirmEnrolment(_codeFor(secret, stepOffset: 1000)),
          throwsA(
            isA<AuthClientException>().having(
              (e) => e.canRetrySecondFactor,
              'canRetry',
              isTrue,
            ),
          ),
        );
        expect(client.pendingEnrolment!.clientData['secret'], equals(secret));

        final enrolled = await client.confirmEnrolment(_codeFor(secret));
        expect(enrolled.requires2FAEnrolment, isFalse);
        expect(
          enrolled.requires2FA,
          isFalse,
          reason:
              'deriving a code from the new secret already proved '
              'possession — a confirmation issues the real tokens outright',
        );
        expect(enrolled.user.username, equals('erin'));
        expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
        await client.logout();

        // ── 3. Challenged on the factor just enrolled ──────────────────────
        // The round trip the whole capability exists for, and the one beat no
        // faked half can produce: the secret the *server* stored is the secret
        // the *client* was shown, or this code would not verify.
        final pass1 = await client.login(
          LoginRequest(username: 'erin', password: 'erin-pass'),
        );
        expect(pass1.requires2FA, isTrue);
        expect(
          pass1.requires2FAEnrolment,
          isFalse,
          reason: 'a held factor is challenged, never re-offered',
        );
        expect(client.pendingChallenge!.type, equals('totp'));

        final pass2 = await client.submitSecondFactor(_codeFor(secret));
        expect(pass2.user.username, equals('erin'));
        expect(pass2.authzToken, isNotEmpty);
        expect(client.pendingChallenge, isNull);
        expect(client.pendingEnrolment, isNull);
        expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
      } on SocketException catch (e) {
        markTestSkipped(
          'auth server not reachable on $_authBaseUri — start '
          'advanced_auth_server to run this integration test ($e)',
        );
        return;
      } finally {
        transport.close();
      }
    });
  });
}
