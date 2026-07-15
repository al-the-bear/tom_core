import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

TomAuthenticationData _login(String username, {Object? password}) =>
    TomAuthenticationData(
      username: username,
      key: password,
      organization: 'acme',
      application: 'console',
      process: 'login',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    );

/// A minimal service: only `alice`/`s3cret` is accepted.
class _DemoAuthService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData a) async {
    if (a.username != 'alice' || a.key != 's3cret') {
      throw LoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
        parameters: {'username': a.username},
      );
    }
    final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
    return dummy.authenticateUser(a);
  }
}

/// Builds the wire message [TomAuthenticationServer] consumes.
TomAuthenticationMessage _message({
  String userName = 'alice',
  String password = 's3cret',
  String organization = 'acme',
}) => TomAuthenticationMessage()
  ..client = 'web'
  ..userName = userName
  ..password = password
  ..organization = organization
  ..application = 'console'
  ..process = 'login'
  ..clientLanguage = 'en'
  ..clientCountry = 'US'
  ..clientTimezone = 'UTC';

/// Builds a principal carrying [roles], so the encrypted authorization-token
/// payload has something to round-trip. Mirrors the construction the dummy
/// service uses, but lets the test seed the identity, roles, and auth flag.
TomPrincipal _principal(
  TomAuthenticationData a, {
  List<String> roles = const [],
  bool? authenticated,
}) => TomPrincipal(
  authenticated: authenticated ?? (a.username != 'GUEST'),
  context: {},
  requires2FA: false,
  twoFactorType: null,
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

/// A stub service that records how it was called and either returns a
/// caller-supplied [TomAuthenticationInfo] or throws [throwThis]. Lets a test
/// assert *which* service a flow routed to and drive both the success and the
/// two error-mapping branches of [TomAuthenticationServer.authenticateUser].
class _RecordingAuthService implements TomAuthenticationService {
  _RecordingAuthService({this.build, this.throwThis});

  /// Produces the success result; ignored when [throwThis] is set.
  final TomAuthenticationInfo Function(TomAuthenticationData)? build;

  /// When set, thrown instead of returning — used for the error paths.
  final Object? throwThis;

  int calls = 0;
  TomAuthenticationData? lastData;

  @override
  Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData a) async {
    calls++;
    lastData = a;
    if (throwThis != null) throw throwThis!;
    return build!(a);
  }
}

void main() {
  group('TomAuthenticationData', () {
    test('carries the per-attempt fields', () {
      final d = _login('alice', password: 's3cret');
      expect(d.username, 'alice');
      expect(d.key, 's3cret');
      expect(d.organization, 'acme');
      expect(d.application, 'console');
      expect(d.process, 'login');
      expect(d.client, 'web');
    });

    test('key is optional (null for guests)', () {
      expect(_login('GUEST').key, isNull);
    });
  });

  group('TomDummyAuthenticationService', () {
    test('authenticates any non-GUEST user', () async {
      final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
      final info = await dummy.authenticateUser(_login('bob'));
      expect(info.principal.authenticated, isTrue);
      expect(info.principal.user.username, 'bob');
    });

    test('treats GUEST as unauthenticated', () async {
      final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
      final info = await dummy.authenticateUser(_login('GUEST'));
      expect(info.principal.authenticated, isFalse);
    });

    test('defaults showErrorMessage to true', () {
      expect(TomDummyAuthenticationService().showErrorMessage, isTrue);
    });

    test('returns a TomAuthenticationInfo pairing principal and acd', () async {
      final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
      final info = await dummy.authenticateUser(_login('bob'));
      expect(info, isA<TomAuthenticationInfo>());
      expect(info.acd, isA<TomAccessControlDefinition>());
    });
  });

  group('TomAuthenticationService contract', () {
    final service = _DemoAuthService();

    test('accepts the correct credential', () async {
      final info =
          await service.authenticateUser(_login('alice', password: 's3cret'));
      expect(info.principal.user.username, 'alice');
    });

    test('rejects a wrong credential with a LoginException', () {
      expect(
        () => service.authenticateUser(_login('alice', password: 'nope')),
        throwsA(isA<LoginException>()),
      );
    });

    test('LoginException carries its key/parameters and is a server exception',
        () async {
      try {
        await service.authenticateUser(_login('mallory'));
        fail('expected LoginException');
      } on LoginException catch (e) {
        expect(e.key, 'error.invalid-user-or-password');
        expect(e.parameters, containsPair('username', 'mallory'));
        expect(e, isA<TomServerException>());
      }
    });
  });

  group('Adaptor annotations', () {
    test('TomAuthenticationAdaptor defaults to neither guest- nor user-only', () {
      final a = TomAuthenticationAdaptor();
      expect(a.guestOnly, isFalse);
      expect(a.userOnly, isFalse);
    });

    test('TomAuthenticationAdaptor records guestOnly/userOnly', () {
      expect(TomAuthenticationAdaptor(guestOnly: true).guestOnly, isTrue);
      expect(TomAuthenticationAdaptor(userOnly: true).userOnly, isTrue);
    });

    test('Tom2FAAdaptor carries its mechanism type and canonicalizes', () {
      const totp = Tom2FAAdaptor('totp');
      const totpAgain = Tom2FAAdaptor('totp');
      expect(totp.type, 'totp');
      expect(identical(totp, totpAgain), isTrue);
    });
  });

  group('TomAuthenticationServer', () {
    test('defaults the JWT issuer to "tom"', () {
      expect(TomAuthenticationServer.globalSettingJwtOrganization, 'tom');
    });

    test('defaults both services to the dummy service', () {
      expect(
        TomAuthenticationServer.globalSettingUserAuthenticationService,
        isA<TomDummyAuthenticationService>(),
      );
      expect(
        TomAuthenticationServer.globalSettingGuestAuthenticationService,
        isA<TomDummyAuthenticationService>(),
      );
    });

    test('authenticatePass2 is unimplemented (throws UnsupportedError)', () {
      expect(
        () => TomAuthenticationServer().authenticatePass2(
          TomAuthenticationMessage(),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // The login orchestration (authenticateUser and the authenticatePass1 /
  // authenticateGuest flows that delegate to it) is the meat of the module:
  // it routes to the guest or user service, mints the authentication +
  // authorization JWTs on success, and maps a LoginException / any other error
  // to a failed result. All of it is connection-free — the JWTs are signed and
  // RSA-encrypted with the framework's bundled default configuration — so the
  // full flow is unit-testable without a live server or user store. These tests
  // mutate global service/protection settings, so setUp/tearDown snapshot and
  // restore them to keep the suite order-independent.
  group('TomAuthenticationServer login flow', () {
    late TomAuthenticationService savedUserService;
    late TomAuthenticationService savedGuestService;
    late String savedIssuer;
    late bool savedProtectionDefault;

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedGuestService =
          TomAuthenticationServer.globalSettingGuestAuthenticationService;
      savedIssuer = TomAuthenticationServer.globalSettingJwtOrganization;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      // Deterministic token payloads: no resource-key redaction of public claims.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomAuthenticationServer.globalSettingGuestAuthenticationService =
          savedGuestService;
      TomAuthenticationServer.globalSettingJwtOrganization = savedIssuer;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
    });

    test('authenticatePass1 issues both tokens and stamps the identity claims',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _RecordingAuthService(
        build: (a) => TomAuthenticationInfo(
          _principal(a),
          TomAccessControlDefinition(),
        ),
      );

      final result =
          await TomAuthenticationServer().authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.authenticationToken, isNotEmpty);
      expect(result.authorizationToken, isNotEmpty);

      final auth = TomClientJwtToken(result.authenticationToken, decrypt: false);
      expect(auth.issuer, TomAuthenticationServer.globalSettingJwtOrganization);
      expect(auth.payload?['username'], 'alice');
      expect(auth.payload?['organization'], 'acme');
    });

    test('the authorization token carries the encrypted access-control payload',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _RecordingAuthService(
        build: (a) => TomAuthenticationInfo(
          _principal(a, roles: ['admin']),
          TomAccessControlDefinition(),
        ),
      );

      final result =
          await TomAuthenticationServer().authenticatePass1(_message());

      // Decoding with decrypt:true exercises the RSA encrypt→decrypt round-trip
      // end to end (server-side encrypt in getJWT, client-side decrypt here).
      final authz = TomClientJwtToken(result.authorizationToken);
      expect(authz.secretData, isNotNull);
      expect(authz.secretData!['roles'], contains('admin'));
    });

    test('authenticatePass1 routes to the user service', () async {
      final userService = _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );
      final guestService = _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          userService;
      TomAuthenticationServer.globalSettingGuestAuthenticationService =
          guestService;

      await TomAuthenticationServer().authenticatePass1(_message());

      expect(userService.calls, 1);
      expect(guestService.calls, 0);
    });

    test('authenticateGuest routes to the guest service and stays unauthenticated',
        () async {
      final userService = _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );
      final guestService = _RecordingAuthService(
        build: (a) => TomAuthenticationInfo(
          _principal(a, authenticated: false),
          TomAccessControlDefinition(),
        ),
      );
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          userService;
      TomAuthenticationServer.globalSettingGuestAuthenticationService =
          guestService;

      final result = await TomAuthenticationServer()
          .authenticateGuest(_message(userName: 'GUEST', password: ''));

      expect(guestService.calls, 1);
      expect(userService.calls, 0);
      expect(result.error, isEmpty);

      final auth = TomClientJwtToken(result.authenticationToken, decrypt: false);
      expect(auth.payload?['username'], 'GUEST');
    });

    test('a LoginException maps to a failed result carrying its key, no tokens',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _RecordingAuthService(
        throwThis: LoginException('auth.bad-credentials', 'nope'),
      );

      final result =
          await TomAuthenticationServer().authenticatePass1(_message());

      expect(result.error, 'auth.bad-credentials');
      expect(result.authenticationToken, isEmpty);
      expect(result.authorizationToken, isEmpty);
    });

    test('an unexpected error maps to the generic login.error.unknown result',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _RecordingAuthService(throwThis: StateError('boom'));

      final result =
          await TomAuthenticationServer().authenticatePass1(_message());

      expect(result.error, 'login.error.unknown');
      expect(result.authenticationToken, isEmpty);
      expect(result.authorizationToken, isEmpty);
    });

    test('the issued token stamps the configured JWT issuer', () async {
      TomAuthenticationServer.globalSettingJwtOrganization = 'acme-corp';
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );

      final result =
          await TomAuthenticationServer().authenticatePass1(_message());

      final auth = TomClientJwtToken(result.authenticationToken, decrypt: false);
      expect(auth.issuer, 'acme-corp');
    });

    test('authenticateUser delegates to the guest service when guestLogin is true',
        () async {
      final userService = _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );
      final guestService = _RecordingAuthService(
        build: (a) =>
            TomAuthenticationInfo(_principal(a), TomAccessControlDefinition()),
      );
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          userService;
      TomAuthenticationServer.globalSettingGuestAuthenticationService =
          guestService;

      await TomAuthenticationServer().authenticateUser(_message(), true);

      expect(guestService.calls, 1);
      expect(userService.calls, 0);
    });
  });
}
