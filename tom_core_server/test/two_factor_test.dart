/// Tests for the server-side second-factor subsystem: the adaptor contract, the
/// mechanism registry, the built-in TOTP adaptor, and the two-pass login flow
/// that ties them together.
///
/// The whole flow is connection-free — the interim challenge travels in a JWT
/// signed and RSA-encrypted with the framework's bundled default keys — so a
/// complete `pass1 → challenge → pass2 → session` round trip runs in-process,
/// with no user store, no HTTP and no clock stubbing beyond what TOTP itself
/// needs.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// The RFC 4226 / RFC 6238 reference secret, in the base32 form an
/// authenticator is provisioned with.
///
/// Used here only as *a* working secret for the adaptor's policy tests; that it
/// reproduces the RFC's published codes is the kernel's concern
/// (`TomTotp` in `tom_core_kernel/test/security_test.dart`).
const String _rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

/// Builds the wire message the server consumes. [password] doubles as the
/// primary credential on pass 1 and as the submitted factor on pass 2 — the
/// message's single credential slot, which is exactly why no wire field had to
/// be added for 2FA.
TomAuthenticationMessage _message({
  String userName = 'alice',
  String password = 's3cret',
}) => TomAuthenticationMessage()
  ..client = 'web'
  ..userName = userName
  ..password = password
  ..organization = 'acme'
  ..application = 'console'
  ..process = 'login'
  ..clientLanguage = 'en'
  ..clientCountry = 'US'
  ..clientTimezone = 'UTC';

/// Builds a principal that may or may not still owe a second factor, so a test
/// can drive both branches of pass 1 from the same shape.
TomPrincipal _principal(
  TomAuthenticationData a, {
  bool requires2FA = false,
  String? twoFactorType,
  List<String> roles = const ['admin'],
}) => TomPrincipal(
  authenticated: true,
  context: {},
  requires2FA: requires2FA,
  twoFactorType: twoFactorType,
  clientId: 0,
  organization: a.organization,
  organizationId: 0,
  application: a.application,
  applicationId: 0,
  process: a.process,
  processId: 0,
  language: a.language,
  country: a.country,
  clientCountry: a.country,
  clientLanguage: a.language,
  clientTimezone: a.timezone,
  user: TomUser(
    id: 1,
    username: a.username,
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timeZone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: roles),
);

/// An authentication service that answers with a fixed principal shape.
class _StubAuthService implements TomAuthenticationService {
  _StubAuthService({
    this.requires2FA = false,
    this.twoFactorType,
  });

  final bool requires2FA;
  final String? twoFactorType;

  @override
  Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData a) async =>
      TomAuthenticationInfo(
        _principal(a, requires2FA: requires2FA, twoFactorType: twoFactorType),
        TomAccessControlDefinition(),
      );
}

/// A mechanism whose "code" is a constant, so the flow tests can assert
/// challenge/verify/retry semantics without depending on the clock.
///
/// Also records what the framework handed it, which is how the tests check that
/// the opaque blobs really do survive the round trip through the token.
class _FakeAdaptor implements Tom2FAService {
  _FakeAdaptor({this.failIssueWith});

  /// The one submission this mechanism accepts.
  static const String expected = '424242';

  /// The displayable hint it advertises.
  static const String hint = '***-**-4711';

  /// Thrown from [issueChallenge] instead of returning, for the pass-1 error
  /// paths (a user who cannot be challenged, a mechanism whose gateway is down).
  final Object? failIssueWith;

  int issued = 0;
  int verified = 0;
  Tom2FAContext? lastVerifyContext;
  Tom2FASubmission? lastSubmission;

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    if (failIssueWith != null) throw failIssueWith!;
    return const Tom2FAChallengeSpec(
      hint: hint,
      clientData: {'shape': 'digits-6'},
      verificationData: {'nonce': 'n-1'},
      attemptsAllowed: 3,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async {
    verified++;
    lastVerifyContext = context;
    lastSubmission = submission;
    return submission.submitted == expected;
  }
}

/// The JWT registered claims, the validity window and the encrypted blob — all
/// of which differ between two tokens minted a moment apart for reasons that
/// have nothing to do with 2FA.
const _volatileClaims = {
  'iat',
  'exp',
  'nbf',
  'iss',
  'jti',
  'aud',
  'sub',
  'validFrom',
  'validUntil',
  'encrypted',
};

/// The identity claims of [jwt], with the volatile ones stripped — what must be
/// *identical* between a completed pass 2 and a login that never needed one.
Map<String, dynamic> _identityClaims(String jwt) {
  final payload = Map<String, dynamic>.from(
    TomClientJwtToken(jwt, decrypt: false).payload ?? const {},
  );
  payload.removeWhere((key, _) => _volatileClaims.contains(key));
  return payload;
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  group('Tom2FARegistry', () {
    tearDown(Tom2FARegistry.reset);

    // MUST stay ahead of the reflection test below: initializeReflection() is
    // process-global and irreversible, so this is the only window in which the
    // no-reflection state can be observed at all.
    test('tolerates a program with no generated reflection', () {
      // Annotation discovery is a convenience on top of register(), not a
      // precondition of it — a deployment that wires its adaptors by hand must
      // not have its logins fail because there was nothing to scan.
      expect(() => Tom2FARegistry.lookup('anything'), returnsNormally);
      expect(Tom2FARegistry.registeredTypes, isEmpty);
    });

    test('resolves a hand-registered adaptor', () {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.register('fake', adaptor);
      expect(identical(Tom2FARegistry.lookup('fake'), adaptor), isTrue);
      expect(Tom2FARegistry.registeredTypes, contains('fake'));
    });

    test('returns null for an unknown mechanism', () {
      expect(Tom2FARegistry.lookup('carrier-pigeon'), isNull);
    });

    test('re-registering the same instance is a no-op', () {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.register('fake', adaptor);
      expect(() => Tom2FARegistry.register('fake', adaptor), returnsNormally);
    });

    // Two mechanisms answering to one key is a wiring bug; picking one silently
    // would surface it much later and much less clearly.
    test('rejects a second, different adaptor for the same key', () {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      expect(
        () => Tom2FARegistry.register('fake', _FakeAdaptor()),
        throwsA(isA<Tom2FAException>()),
      );
    });

    test('Tom2FAException is a server exception that is not client-throwable',
        () {
      final e = Tom2FAException('authentication.2fa.x', 'boom');
      expect(e, isA<TomServerException>());
      expect(e.clientThrow, isFalse);
    });

    test('reset drops every registration', () {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      Tom2FARegistry.reset();
      expect(Tom2FARegistry.lookup('fake'), isNull);
    });

    // The dispatch the framework actually relies on: an adaptor is found by its
    // @Tom2FAAdaptor annotation, with nothing naming it anywhere in the server.
    test('discovers annotated adaptors by reflection', () {
      initializeReflection();
      Tom2FARegistry.reset();
      expect(
        Tom2FARegistry.lookup(TomTotp2FAService.mechanismType),
        isA<TomTotp2FAService>(),
      );
      expect(Tom2FARegistry.registeredTypes, contains('totp'));
    });
  });

  // The RFC vectors for the derivation itself live with the derivation, in
  // `tom_core_kernel/test/security_test.dart` (group `TomTotp`). What is tested
  // here is only what this adaptor adds on top: policy — the secret source, the
  // accepted skew window, the digit width, and the failure modes those produce.
  group('TomTotp2FAService adaptor', () {
    late TomTotpSecretResolver? savedResolver;
    late int savedWindow;

    setUp(() {
      savedResolver = TomTotp2FAService.globalSettingSecretResolver;
      savedWindow = TomTotp2FAService.globalSettingWindowSteps;
      TomTotp2FAService.globalSettingSecretResolver = (_) => _rfcSecretBase32;
    });

    tearDown(() {
      TomTotp2FAService.globalSettingSecretResolver = savedResolver;
      TomTotp2FAService.globalSettingWindowSteps = savedWindow;
    });

    Tom2FAContext context() => Tom2FAContext(
          principal: _principal(
            TomAuthenticationData(
              username: 'alice',
              organization: 'acme',
              application: 'console',
              process: 'login',
              language: 'en',
              country: 'US',
              timezone: 'UTC',
              client: 'web',
            ),
          ),
        );

    Tom2FASubmission submission(String code) => Tom2FASubmission(
          submitted: code,
          challenge: Tom2FAChallenge(
            type: 'totp',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            attempt: 1,
          ),
        );

    /// The code an authenticator would show right now, [stepsOff] time steps
    /// away from the server's current step.
    ///
    /// Derived through the kernel primitive the verifier itself uses, so the
    /// test cannot drift out of agreement with what it is checking.
    String currentCode({int stepsOff = 0}) => TomTotp.generateCode(
          TomTotp.decodeBase32(_rfcSecretBase32),
          TomTotp.counterFor(period: TomTotp2FAService.globalSettingPeriod) +
              stepsOff,
          TomTotp2FAService.globalSettingDigits,
        );

    test('issues a challenge describing the code shape but delivering nothing',
        () async {
      final spec = await TomTotp2FAService().issueChallenge(context());
      expect(spec.hint, isEmpty);
      expect(spec.clientData['digits'], TomTotp2FAService.globalSettingDigits);
      expect(
        spec.clientData['periodSeconds'],
        TomTotp2FAService.globalSettingPeriod.inSeconds,
      );
      // Nothing secret travels: the secret is re-resolved on pass 2.
      expect(spec.verificationData, isEmpty);
    });

    test('fails the login when no authenticator is enrolled', () async {
      TomTotp2FAService.globalSettingSecretResolver = (_) => null;
      await expectLater(
        TomTotp2FAService().issueChallenge(context()),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.not-enrolled',
          ),
        ),
      );
    });

    test('accepts the current code', () async {
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isTrue,
      );
    });

    test('rejects a wrong code', () async {
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission('000000'),
        ),
        isFalse,
      );
    });

    test('rejects a code of the wrong length without hashing anything',
        () async {
      expect(
        await TomTotp2FAService().verifySubmission(context(), submission('12')),
        isFalse,
      );
    });

    test('tolerates one time step of clock skew either way', () async {
      TomTotp2FAService.globalSettingWindowSteps = 1;
      final adaptor = TomTotp2FAService();
      expect(
        await adaptor.verifySubmission(context(), submission(currentCode(stepsOff: -1))),
        isTrue,
      );
      expect(
        await adaptor.verifySubmission(context(), submission(currentCode(stepsOff: 1))),
        isTrue,
      );
    });

    test('rejects a code from outside the accepted window', () async {
      TomTotp2FAService.globalSettingWindowSteps = 1;
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode(stepsOff: 5)),
        ),
        isFalse,
      );
    });

    test('rejects everything when the deployment wired no resolver', () async {
      TomTotp2FAService.globalSettingSecretResolver = null;
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isFalse,
      );
    });
  });

  // The two-pass flow end to end. These tests mutate global service settings, so
  // setUp/tearDown snapshot and restore them to keep the suite order-independent.
  group('TomAuthenticationServer two-pass flow', () {
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    late _FakeAdaptor adaptor;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      // Deterministic token payloads: no resource-key redaction of public claims.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      adaptor = _FakeAdaptor();
      Tom2FARegistry.reset();
      Tom2FARegistry.register('fake', adaptor);
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true, twoFactorType: 'fake');
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
    });

    /// Runs pass 1 and returns the interim token the client would present back.
    Future<TomClientJwtToken> issuedChallenge() async {
      final pass1 = await server.authenticatePass1(_message());
      expect(pass1.error, isEmpty, reason: 'pass 1 should not fail');
      return TomClientJwtToken(pass1.authorizationToken);
    }

    test('pass 1 answers with a challenge instead of a session', () async {
      final pass1 = await server.authenticatePass1(_message());

      expect(pass1.error, isEmpty);
      expect(pass1.requires2FA, isTrue);
      expect(pass1.twoFactorType, 'fake');
      expect(adaptor.issued, 1);

      final token = TomClientJwtToken(pass1.authorizationToken);
      final challenge = Tom2FAChallenge.fromClaims(token.payload);
      expect(challenge, isNotNull);
      expect(challenge!.type, 'fake');
      expect(challenge.hint, '***-**-4711');
      expect(challenge.attempt, 0);
      expect(challenge.attemptsAllowed, 3);
      expect(challenge.clientData['shape'], 'digits-6');
      expect(challenge.isExpired(), isFalse);
    });

    // The interim token carries the real access-control payload, so what stops
    // it from being a usable session is the derived principal — asserted here
    // because every access check in the framework goes through this one flag.
    test('the interim token does not authenticate its bearer', () {
      // Guard the whole assertion in one place: authenticated must be false
      // even though the username is a real one and the roles are present.
      return issuedChallenge().then((token) {
        final principal =
            TomBearerAuthentication.convertTokenPayloadToPrincipal(token);
        expect(principal.username, 'alice');
        expect(principal.aci.roles, contains('admin'));
        expect(principal.requires2FA, isTrue);
        expect(principal.twoFactorType, 'fake');
        expect(principal.authenticated, isFalse);
      });
    });

    test('the verification blob is server-only', () async {
      final pass1 = await server.authenticatePass1(_message());

      // Present in the encrypted section...
      final decrypted = TomClientJwtToken(pass1.authorizationToken);
      expect(
        decrypted.secretData?[Tom2FAClaims.verificationData],
        containsPair('nonce', 'n-1'),
      );
      // ...and nowhere in the claims a client can read without the private key.
      final public =
          TomClientJwtToken(pass1.authorizationToken, decrypt: false);
      expect(public.payload, isNot(contains(Tom2FAClaims.verificationData)));
    });

    test('pass 2 hands the adaptor the challenge and its own blob back',
        () async {
      final token = await issuedChallenge();
      await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );

      expect(adaptor.verified, 1);
      expect(adaptor.lastSubmission!.submitted, '424242');
      // Already counted, so an adaptor sees the state its answer produces.
      expect(adaptor.lastSubmission!.challenge.attempt, 1);
      expect(
        adaptor.lastSubmission!.verificationData,
        containsPair('nonce', 'n-1'),
      );
      expect(adaptor.lastVerifyContext!.principal.username, 'alice');
      expect(adaptor.lastVerifyContext!.organization, 'acme');
    });

    test('a correct answer completes the login', () async {
      final token = await issuedChallenge();
      final pass2 = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );

      expect(pass2.error, isEmpty);
      expect(pass2.requires2FA, isFalse);
      expect(pass2.authenticationToken, isNotEmpty);

      final completed = TomClientJwtToken(pass2.authorizationToken);
      expect(completed.payload?[Tom2FAClaims.requires2FA], 'false');
      expect(completed.payload?[Tom2FAClaims.type], isNull);
      expect(Tom2FAChallenge.fromClaims(completed.payload), isNull);
      // The completed token carries no verification payload at all, so a
      // mechanism secret cannot outlive the challenge it was minted for.
      expect(
        completed.secretData,
        isNot(contains(Tom2FAClaims.verificationData)),
      );
      // The access-control payload survives both passes.
      expect(completed.secretData!['roles'], contains('admin'));

      final principal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(completed);
      expect(principal.authenticated, isTrue);
      expect(principal.requires2FA, isFalse);
    });

    // The todo's actual acceptance criterion: after the second factor, the
    // client holds exactly the token a pass1-only login would have given it.
    test('the completed token is the one a 2FA-free login would have issued',
        () async {
      final token = await issuedChallenge();
      final pass2 = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );

      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final control = await server.authenticatePass1(_message());

      expect(
        _identityClaims(pass2.authorizationToken),
        _identityClaims(control.authorizationToken),
      );
    });

    test('a wrong answer is retryable and spends exactly one attempt', () async {
      final token = await issuedChallenge();
      final retry = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: token,
      );

      expect(retry.error, 'login.error.2fa.invalid-code');
      expect(retry.requires2FA, isTrue);
      expect(retry.authorizationToken, isNotEmpty);

      final reissued = TomClientJwtToken(retry.authorizationToken);
      final challenge = Tom2FAChallenge.fromClaims(reissued.payload);
      expect(challenge!.attempt, 1);
      expect(challenge.attemptsRemaining, 2);
      // Re-issued with its blob intact, so the next attempt is answerable.
      expect(
        reissued.secretData?[Tom2FAClaims.verificationData],
        containsPair('nonce', 'n-1'),
      );

      // And the retry token completes the login normally.
      final pass2 = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: reissued,
      );
      expect(pass2.error, isEmpty);
    });

    test('the attempt counter cannot be rewound within one challenge', () async {
      var token = await issuedChallenge();
      for (var attempt = 1; attempt <= 2; attempt++) {
        final retry = await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );
        expect(retry.error, 'login.error.2fa.invalid-code');
        token = TomClientJwtToken(retry.authorizationToken);
        expect(Tom2FAChallenge.fromClaims(token.payload)!.attempt, attempt);
      }

      // Third and last allowed attempt: wrong again burns the challenge.
      final burned = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: token,
      );
      expect(burned.error, 'login.error.2fa.attempts-exhausted');
      expect(burned.authorizationToken, isEmpty);
      expect(adaptor.verified, 3);
    });

    test('an exhausted challenge is refused without consulting the adaptor',
        () async {
      final exhausted = Tom2FAChallenge(
        type: 'fake',
        attempt: 3,
        attemptsAllowed: 3,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );
      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: _tokenCarrying(exhausted),
      );

      expect(result.error, 'login.error.2fa.attempts-exhausted');
      expect(adaptor.verified, 0);
    });

    test('a lapsed challenge is refused without consulting the adaptor',
        () async {
      final lapsed = Tom2FAChallenge(
        type: 'fake',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: _tokenCarrying(lapsed),
      );

      expect(result.error, 'login.error.2fa.expired');
      expect(result.authorizationToken, isEmpty);
      expect(adaptor.verified, 0);
    });

    test('a token carrying no challenge cannot complete a login', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final plain = await server.authenticatePass1(_message());

      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: TomClientJwtToken(plain.authorizationToken),
      );
      expect(result.error, 'login.error.2fa.no-challenge');
    });

    test('pass 2 outside a request zone and without a token fails cleanly',
        () async {
      final result = await server.authenticatePass2(_message());
      expect(result.error, 'login.error.2fa.no-challenge');
      expect(result.authenticationToken, isEmpty);
    });

    test('a challenge for an unregistered mechanism cannot be answered',
        () async {
      final token = await issuedChallenge();
      Tom2FARegistry.reset();

      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );
      expect(result.error, 'login.error.2fa.unsupported-mechanism');
    });

    test('pass 1 fails when the account names a mechanism nobody implements',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true, twoFactorType: 'carrier-pigeon');
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
      expect(result.authenticationToken, isEmpty);
    });

    test('pass 1 fails when the account names no mechanism at all', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true);
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
    });

    // An adaptor that cannot challenge this user (no enrolled device) must fail
    // the login rather than show a prompt that can never be satisfied.
    test('a LoginException from the adaptor surfaces its own key', () async {
      Tom2FARegistry.reset();
      Tom2FARegistry.register(
        'fake',
        _FakeAdaptor(
          failIssueWith: LoginException(
            'login.error.2fa.not-enrolled',
            'nothing enrolled',
          ),
        ),
      );
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.not-enrolled');
      expect(result.authorizationToken, isEmpty);
    });

    test('an unexpected adaptor fault is masked behind the generic error',
        () async {
      Tom2FARegistry.reset();
      Tom2FARegistry.register(
        'fake',
        _FakeAdaptor(failIssueWith: StateError('gateway down')),
      );
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.unknown');
    });

    test('a principal that owes no factor logs in on pass 1 alone', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isFalse);
      expect(adaptor.issued, 0);
      expect(
        TomClientJwtToken(result.authorizationToken, decrypt: false)
            .payload?[Tom2FAClaims.requires2FA],
        'false',
      );
    });
  });
}

/// Mints an interim token carrying [challenge] for a fixed principal.
///
/// Lets a test present a challenge in a state pass 1 will not naturally produce
/// (already exhausted, already lapsed) without stubbing the clock.
TomClientJwtToken _tokenCarrying(Tom2FAChallenge challenge) {
  final principal = _principal(
    TomAuthenticationData(
      username: 'alice',
      organization: 'acme',
      application: 'console',
      process: 'login',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    ),
    requires2FA: true,
    twoFactorType: challenge.type,
  );
  final (publicInfo, privateInfo) =
      TomBearerAuthentication.convertPrincipalToTokenPayload(
    principal,
    null,
    'US',
    'en',
    challenge: challenge,
    twoFactorVerification: const {'nonce': 'n-1'},
  );
  return TomClientJwtToken(
    TomServerJwtToken(publicInfo, encryptedData: privateInfo).getJWT('tom'),
  );
}
