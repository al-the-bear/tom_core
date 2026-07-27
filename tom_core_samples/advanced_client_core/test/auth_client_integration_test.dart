/// Live integration tests for [AuthClient] (step 22): logs in against a running
/// `advanced_auth_server` on `localhost:8081` with the seeded accounts and
/// asserts the returned principal plus stored bearer — for `alice`, whose login
/// is single-pass, and for `dave`, who owes a TOTP second factor (csex3).
///
/// This needs the auth server *and* its database up (see
/// `../advanced_auth_server/README.md`). Because neither is guaranteed in a
/// headless CI/dev box, the tests **skip themselves at runtime when the server
/// is unreachable** (a connection refusal calls [markTestSkipped] instead of
/// failing) — the unit suites (`auth_client_test.dart`,
/// `auth_client_two_factor_test.dart`) carry the always-on coverage; these prove
/// the wire path end-to-end when an operator brings the server up locally.
///
/// The two-pass case is the only place the *whole* csex3 loop runs over a real
/// socket: the client's own suite fakes the transport, and the server's fakes
/// the client. Here the real [AuthClient] talks to the real
/// `TomAuthenticationServer` through the real `/auth/*` endpoints, against a
/// secret that came out of the database rather than out of a fixture.
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

/// The code `dave`'s authenticator would be showing right now.
///
/// This is the client standing in for the authenticator app, so it derives the
/// code the way an app would: through the kernel's [TomTotp] primitive — the
/// same one the server verifies with, which is precisely why the client needs
/// no dependency on the server package to produce a code it will accept.
///
/// [stepOffset] shifts the time step; a large offset yields a well-formed code
/// far outside the accepted skew window, i.e. a *wrong* one.
String _daveCode({int stepOffset = 0}) => TomTotp.generateCode(
      TomTotp.decodeBase32(_daveSecret),
      TomTotp.counterFor() + stepOffset,
    );

void main() {
  setUpAll(initializeReflection);

  group('AuthClient (live auth server)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test('TC-22-11: logs in alice and stores the bearer', () async {
      // The live transport is owned here so it can be closed regardless of
      // outcome (and so a connection refusal is observable as a SocketException).
      final transport = IoJsonTransport();
      final client = AuthClient(Uri.parse(_authBaseUri), transport: transport);

      final LoginResult result;
      try {
        result = await client.login(
            LoginRequest(username: 'alice', password: 'alice-pass'));
      } on SocketException catch (e) {
        markTestSkipped(
            'auth server not reachable on $_authBaseUri — start '
            'advanced_auth_server to run this integration test ($e)');
        return;
      } finally {
        transport.close();
      }

      expect(result.user.username, equals('alice'));
      expect(result.authzToken, isNotEmpty);
      expect(TomBearerAuthentication.authorizationToken,
          equals(result.authzToken));
      // Alice owes no second factor, so pass 1 *is* the whole login.
      expect(result.requires2FA, isFalse);
      expect(client.pendingChallenge, isNull);
    });

    // The csex3 loop over a real socket: the only place where the real
    // AuthClient, the real TomAuthenticationServer, the real endpoints and a
    // secret that came out of the database all take part in one run. The
    // package's own suites necessarily fake one side or the other — the client
    // suite fakes the transport, the server suite fakes the client — so a
    // disagreement between the two halves (a claim name, a status code, the
    // shape of the retry body) could only ever surface here.
    test('TC-22-12: completes dave\'s two-pass login and ends up authenticated',
        () async {
      final transport = IoJsonTransport();
      final client = AuthClient(Uri.parse(_authBaseUri), transport: transport);

      try {
        final pass1 = await client.login(
            LoginRequest(username: 'dave', password: 'dave-pass'));

        // Pass 1 stops half-way: the right password alone does not authenticate
        // an enrolled account.
        expect(pass1.requires2FA, isTrue);
        expect(pass1.twoFactorType, equals('totp'));
        final challenge = client.pendingChallenge;
        expect(challenge, isNotNull,
            reason: 'the interim token must carry the challenge');
        expect(challenge!.type, equals('totp'));
        expect(challenge.isExpired(), isFalse);
        expect(TomBearerAuthentication.getPrincipal().authenticated, isFalse,
            reason: 'an interim token must not authenticate its bearer');

        // A wrong code is refused but retryable, and spends one attempt.
        final before = client.pendingChallenge!.attemptsRemaining;
        await expectLater(
          client.submitSecondFactor(_daveCode(stepOffset: 1000)),
          throwsA(isA<AuthClientException>()
              .having((e) => e.canRetrySecondFactor, 'canRetry', isTrue)),
        );
        expect(client.pendingChallenge!.attemptsRemaining, equals(before - 1),
            reason: 'the refusal must hand back a token with the attempt spent');

        // The right code completes the login against that re-issued token.
        final pass2 = await client.submitSecondFactor(_daveCode());

        expect(pass2.requires2FA, isFalse);
        expect(pass2.user.username, equals('dave'));
        expect(pass2.authzToken, isNotEmpty);
        expect(TomBearerAuthentication.authorizationToken,
            equals(pass2.authzToken));
        // The done-when of the whole todo: pass 2 yields the session a
        // 2FA-free login would have, with nothing left to answer.
        expect(client.pendingChallenge, isNull);
        expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
      } on SocketException catch (e) {
        markTestSkipped(
            'auth server not reachable on $_authBaseUri — start '
            'advanced_auth_server to run this integration test ($e)');
        return;
      } finally {
        transport.close();
      }
    });
  });
}
