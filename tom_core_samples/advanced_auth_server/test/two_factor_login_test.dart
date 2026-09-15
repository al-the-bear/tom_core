/// End-to-end tests for the auth server's two-pass login.
///
/// These cover the *sample's* half of the flow — the wire contract and the
/// deployment wiring — over the real framework machinery underneath: the
/// mechanism is enrolled as **data** (two columns on the account row), the
/// secret is reached through the resolver the boot installs, and both passes go
/// through [AuthTokenService], which delegates to `TomAuthenticationServer`.
/// Nothing here re-implements challenge issuance, attempt counting, or code
/// verification; the point is precisely that the sample does not have to.
///
/// The framework's own unit coverage of the adaptor contract, the registry, and
/// the claim round trip lives in `tom_core_server/test/two_factor_test.dart` and
/// `tom_core_kernel/test/security_test.dart`.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// The `@dev,test` [004] seed's TOTP secret, mirrored here so the test derives
/// the very codes a live `dave` login would need. A sample credential only.
const String _daveSecret = 'JBSWY3DPEHPK3PXP';

/// Builds a login request (tenant fields fixed; the single-tenant server ignores
/// them for the credential check).
LoginRequest _login(String username, String password) => LoginRequest(
  username: username,
  password: password,
  app: 'todo',
  org: 'acme',
);

/// `dave` — active, password `dave-pass`, enrolled in TOTP against
/// [_daveSecret]. The mirror of the [005] migration seed, as a plain row.
UserRecord _dave() => applyPassword(
  UserRecord()
    ..id = 5
    ..username = 'dave'
    ..displayName = 'Dave Dijkstra'
    ..email = 'dave@example.com'
    ..status = UserStatus.active.name
    ..twoFactorType = TomTotp2FAService.mechanismType
    ..twoFactorSecret = _daveSecret,
  'dave-pass',
);

/// `ada` — active, password `s3cret`, **not** enrolled: both 2FA columns stay
/// null, which is what makes her login single-pass.
UserRecord _ada() => applyPassword(
  UserRecord()
    ..id = 1
    ..username = 'ada'
    ..displayName = 'Ada Lovelace'
    ..email = 'ada@example.com'
    ..status = UserStatus.active.name,
  's3cret',
);

/// A token service over a store holding [_ada] and [_dave].
AuthTokenService _service() => AuthTokenService(
  AdvancedAuthenticationService(
    InMemoryAuthUserStore(
      users: [_ada(), _dave()],
      roleKeysByUserId: const {
        1: ['editor'],
        5: ['editor'],
      },
      groupNamesByUserId: const {
        5: ['Engineering'],
      },
    ),
  ),
  issuer: 'tom',
);

/// The TOTP code the verifier expects right now, derived with the adaptor's own
/// helpers so the test and the verifier can never drift apart.
String _currentCode({int stepOffset = 0}) => TomTotp.generateCode(
  TomTotp.decodeBase32(_daveSecret),
  TomTotp.counterFor(period: TomTotp2FAService.globalSettingPeriod) +
      stepOffset,
  TomTotp2FAService.globalSettingDigits,
);

/// A code that is well-formed but wrong: far enough outside the accepted window
/// that no clock skew can make it pass.
String _wrongCode() => _currentCode(stepOffset: 1000);

/// Completes pass 2 for [result] with [code], the way a client does.
Future<LoginResult> _submit(
  AuthTokenService service,
  LoginResult result,
  String code,
) => service.submitSecondFactor(
  SecondFactorRequest(code: code, challengeToken: result.authzToken),
);

void main() {
  setUp(() {
    // This test program has no generated reflection, so the registry's
    // annotation scan finds nothing and the adaptor is wired by hand — the
    // documented fallback, and the same call a deployment makes for a mechanism
    // of its own. Annotation discovery itself is covered in tom_core_server.
    Tom2FARegistry.reset();
    Tom2FARegistry.register(
      TomTotp2FAService.mechanismType,
      TomTotp2FAService(),
    );
    TomBearerAuthentication.clearTokens();
  });

  tearDown(TomBearerAuthentication.clearTokens);

  group('pass 1 — the challenge', () {
    test(
      'an enrolled account gets an interim pair and the mechanism key',
      () async {
        final result = await _service().login(_login('dave', 'dave-pass'));

        expect(result.requires2FA, isTrue);
        expect(result.twoFactorType, TomTotp2FAService.mechanismType);
        expect(result.authToken, isNotEmpty);
        expect(result.authzToken, isNotEmpty);
      },
    );

    test('the interim token does not authenticate its bearer', () async {
      final result = await _service().login(_login('dave', 'dave-pass'));

      TomBearerAuthentication.setTokens(result.authToken, result.authzToken);
      final principal = TomBearerAuthentication.getPrincipal();

      // The whole safety of handing the challenge to the client rests on this:
      // the interim token names dave, but authorizes nothing.
      expect(principal.username, 'dave');
      expect(principal.authenticated, isFalse);
      expect(principal.requires2FA, isTrue);
    });

    test('the challenge detail travels in the token, not in the DTO', () async {
      final result = await _service().login(_login('dave', 'dave-pass'));
      TomBearerAuthentication.setTokens(result.authToken, result.authzToken);

      final challenge = TomBearerAuthentication.pendingTwoFactorChallenge;

      expect(challenge, isNotNull);
      expect(challenge!.type, TomTotp2FAService.mechanismType);
      expect(challenge.attempt, 0);
      expect(
        challenge.attemptsRemaining,
        TomTotp2FAService.globalSettingAttemptsAllowed,
      );
      expect(challenge.isExpired(), isFalse);
      // The mechanism describes its own input shape, so a UI can size the code
      // field without knowing that this deployment chose TOTP.
      expect(
        challenge.clientData['digits'],
        TomTotp2FAService.globalSettingDigits,
      );
    });

    test('a non-enrolled account still logs in on pass 1 alone', () async {
      final result = await _service().login(_login('ada', 's3cret'));

      expect(result.requires2FA, isFalse);
      expect(result.twoFactorType, isEmpty);

      TomBearerAuthentication.setTokens(result.authToken, result.authzToken);
      expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
      expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);
    });

    test('wrong credentials are refused before any challenge is issued', () {
      expect(
        _service().login(_login('dave', 'wrong')),
        throwsA(isA<TomLoginException>()),
      );
    });
  });

  group('pass 2 — completing the login', () {
    test('a valid code yields the pair a 2FA-free login would have', () async {
      final service = _service();
      final pending = await service.login(_login('dave', 'dave-pass'));

      final completed = await _submit(service, pending, _currentCode());

      expect(completed.requires2FA, isFalse);
      expect(completed.twoFactorType, isEmpty);
      expect(completed.user.username, 'dave');
      expect(completed.user.id, '5');
      expect(completed.user.email, 'dave@example.com');
      expect(completed.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);

      TomBearerAuthentication.setTokens(
        completed.authToken,
        completed.authzToken,
      );
      final principal = TomBearerAuthentication.getPrincipal();

      // Indistinguishable from a single-pass session: authenticated, no
      // leftover challenge, and carrying the roles pass 1 resolved.
      expect(principal.authenticated, isTrue);
      expect(principal.requires2FA, isFalse);
      expect(TomBearerAuthentication.pendingTwoFactorChallenge, isNull);
      expect(principal.aci.roles, contains('editor'));
      expect(principal.aci.groups, contains('Engineering'));
    });

    test('a code from the adjacent time step is still accepted', () async {
      final service = _service();
      final pending = await service.login(_login('dave', 'dave-pass'));

      // Clock skew between the authenticator and the server is normal; the
      // adaptor's window is what stops it being a login failure.
      final completed = await _submit(
        service,
        pending,
        _currentCode(stepOffset: -1),
      );

      expect(completed.requires2FA, isFalse);
      expect(completed.authToken, isNotEmpty);
    });

    test('a missing challenge token is refused outright', () {
      expect(
        _service().submitSecondFactor(SecondFactorRequest(code: '000000')),
        throwsA(isA<TomLoginException>()),
      );
    });
  });

  group('pass 2 — refusal and retry', () {
    test(
      'a wrong code hands back a re-issued token with one attempt spent',
      () async {
        final service = _service();
        final pending = await service.login(_login('dave', 'dave-pass'));

        final failure = await _submit(service, pending, _wrongCode())
            .then<Object?>((r) => r)
            .onError<TomLoginException>((error, _) => error);

        expect(failure, isA<SecondFactorRetryException>());
        final retry = failure as SecondFactorRetryException;
        expect(retry.challengeToken, isNotEmpty);
        // Not the token that was submitted: it is the *advanced* one.
        expect(retry.challengeToken, isNot(pending.authzToken));

        TomBearerAuthentication.setTokens(
          retry.challengeToken,
          retry.challengeToken,
        );
        final challenge = TomBearerAuthentication.pendingTwoFactorChallenge;
        expect(challenge, isNotNull);
        expect(challenge!.attempt, 1);
        expect(
          challenge.attemptsRemaining,
          TomTotp2FAService.globalSettingAttemptsAllowed - 1,
        );
      },
    );

    test(
      'retrying with the right code against the re-issued token succeeds',
      () async {
        final service = _service();
        final pending = await service.login(_login('dave', 'dave-pass'));

        final retry = await _submit(service, pending, _wrongCode())
            .then<Object?>((r) => r)
            .onError<TomLoginException>((error, _) => error);

        final completed = await service.submitSecondFactor(
          SecondFactorRequest(
            code: _currentCode(),
            challengeToken:
                (retry as SecondFactorRetryException).challengeToken,
          ),
        );

        expect(completed.requires2FA, isFalse);
        TomBearerAuthentication.setTokens(
          completed.authToken,
          completed.authzToken,
        );
        expect(TomBearerAuthentication.getPrincipal().authenticated, isTrue);
      },
    );

    test(
      'attempts are exhausted, and the last refusal offers no retry token',
      () async {
        final service = _service();
        var token = (await service.login(
          _login('dave', 'dave-pass'),
        )).authzToken;

        final failures = <TomLoginException>[];
        for (
          var attempt = 0;
          attempt < TomTotp2FAService.globalSettingAttemptsAllowed;
          attempt++
        ) {
          final failure = await service
              .submitSecondFactor(
                SecondFactorRequest(code: _wrongCode(), challengeToken: token),
              )
              .then<Object?>((r) => r)
              .onError<TomLoginException>((error, _) => error);
          failures.add(failure as TomLoginException);
          if (failure is SecondFactorRetryException)
            token = failure.challengeToken;
        }

        // Each earlier refusal is retryable; the last one is terminal — the
        // client is sent back to pass 1 rather than left holding a spent token.
        for (final earlier in failures.take(failures.length - 1)) {
          expect(earlier, isA<SecondFactorRetryException>());
        }
        expect(failures.last, isNot(isA<SecondFactorRetryException>()));
        expect(failures.last.key, contains('2fa'));
      },
    );

    // A token whose counter already *reads* exhausted is never handed to a
    // client — one is re-issued only while attempts remain — so that guard is
    // reachable only with an externally minted token, and is covered where such
    // a token can be built: tom_core_server's `two_factor_test.dart`.

    test('replaying an earlier token wins nothing — the allowance is spent '
        'per token, not per presentation', () async {
      Tom2FAMemoryAttemptStore.shared.clear();
      addTearDown(Tom2FAMemoryAttemptStore.shared.clear);
      final service = _service();
      final pending = await service.login(_login('dave', 'dave-pass'));

      // Spend an attempt, then throw away the re-issued token and present the
      // original again.
      await _submit(
        service,
        pending,
        _wrongCode(),
      ).then<Object?>((r) => r).onError<TomLoginException>((error, _) => error);

      final replayed = await _submit(
        service,
        pending,
        _currentCode(),
      ).then<Object?>((r) => r).onError<TomLoginException>((error, _) => error);

      // The counter rides in the token, so without a record of what has been
      // answered this replay was indistinguishable from the first presentation
      // — and a *correct* code presented on a spent token would have completed
      // the login, which is the same hole an attacker walks through with a
      // wrong one. `Tom2FAAttemptStore` records the answer, so each token in
      // the chain is answerable once and the allowance is the chain's.
      expect(replayed, isA<TomLoginException>());
      expect(
        (replayed as TomLoginException).key,
        'login.error.2fa.challenge-already-answered',
      );
    });
  });

  group('LoginUnauthorizedErrorHandler — the retry token on the wire', () {
    final handler = const LoginUnauthorizedErrorHandler();
    final request = Request(
      'POST',
      Uri.parse('http://localhost/auth/second-factor'),
    );

    test(
      'a retryable refusal carries the re-issued token in the 401 body',
      () async {
        final response = handler.handleInvocationError(
          SecondFactorRetryException(
            'login.error.2fa.invalid-code',
            'rejected',
            challengeToken: 'the-advanced-token',
          ),
          StackTrace.current,
          request,
        );

        expect(response.statusCode, 401);
        final body = await response.readAsString();
        expect(body, contains('login.error.2fa.invalid-code'));
        // Without this the client would retry against its stale copy and the
        // attempt counter — which lives in the token — would never advance.
        expect(body, contains('the-advanced-token'));
      },
    );

    test('a terminal refusal carries no token to retry with', () async {
      final response = handler.handleInvocationError(
        TomLoginException(
          'login.error.2fa.attempts-exhausted',
          'spent',
          reason: TomLoginFailure.rateLimited,
        ),
        StackTrace.current,
        request,
      );

      expect(response.statusCode, 401);
      expect(await response.readAsString(), isNot(contains('challengeToken')));
    });
  });
}
