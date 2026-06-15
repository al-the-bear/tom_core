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
}
