/// Tests for **server self-login** — the deployment authenticating as itself
/// and installing its own principal, plus the guard that an unconfigured
/// deployment is untouched.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A configuration that skips the generated reflection (the merged values are
/// irrelevant here) so the self-login fields can be set directly.
class _Config extends TomBaseServerConfiguration {
  _Config() : super(const []);

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A fully configured deployment identity.
_Config _configured({
  String uri = 'http://auth.test:8081/auth/login',
  String username = 'svc-app',
  String credential = 's3cret',
}) => _Config()
  ..authServerLoginUri = uri
  ..serviceAccountName = username
  ..serviceAccountCredential = credential
  ..serviceAccountOrganization = 'org'
  ..serviceAccountApplication = 'app';

/// A transport that answers with a canned response and records what it was
/// asked to send.
class _FakeTransport extends TomServiceLoginTransport {
  final int status;
  final String body;
  final Object? throws;

  Uri? sentTo;
  String? sentBody;
  int callCount = 0;

  _FakeTransport(this.body, {this.status = 200, this.throws});

  @override
  Future<TomServiceLoginResponse> postJson(Uri uri, String requestBody) async {
    callCount++;
    sentTo = uri;
    sentBody = requestBody;
    if (throws != null) throw throws!;
    return TomServiceLoginResponse(status, body);
  }
}

/// Builds a signed token whose encrypted section carries [entitlements].
String _serviceToken({
  String username = 'svc-app',
  List<String> entitlements = const [],
}) => TomServerJwtToken(
  {'username': username, 'userId': 42},
  encryptedData: {'entitlements': entitlements},
).getJWT('tom');

/// A login response body in the kernel's [TomAuthenticationResult] spelling.
String _kernelSpelling(String token) => jsonEncode({
  'error': '',
  'authenticationToken': token,
  'authorizationToken': token,
});

/// The same body in the short spelling application login DTOs commonly use.
String _shortSpelling(String token) =>
    jsonEncode({'authToken': token, 'authzToken': token});

void main() {
  setUp(TomServerPrincipal.clear);
  tearDown(TomServerPrincipal.clear);

  group('TomServiceCredential.fromConfiguration', () {
    test(
      'SL01: reads a fully configured deployment identity [2026-07-28] (OK)',
      () {
        final credential = TomServiceCredential.fromConfiguration(
          _configured(),
        );
        expect(credential, isNotNull);
        expect(credential!.username, 'svc-app');
        expect(credential.credential, 's3cret');
        expect(credential.loginUri.host, 'auth.test');
        expect(credential.loginUri.port, 8081);
        expect(credential.organization, 'org');
      },
    );

    test('SL02: an untouched configuration yields null [2026-07-28] (OK)', () {
      expect(TomServiceCredential.fromConfiguration(_Config()), isNull);
    });

    test(
      'SL03: a partially configured deployment yields null rather than half a '
      'credential [2026-07-28] (OK)',
      () {
        expect(
          TomServiceCredential.fromConfiguration(
            _Config()..authServerLoginUri = 'http://auth.test/auth/login',
          ),
          isNull,
        );
        expect(
          TomServiceCredential.fromConfiguration(
            _configured()..serviceAccountCredential = '',
          ),
          isNull,
        );
        expect(
          TomServiceCredential.fromConfiguration(
            _configured()..serviceAccountName = '   ',
          ),
          isNull,
        );
        expect(
          TomServiceCredential.fromConfiguration(
            // Whitespace is the shape an unset `${SERVICE_CREDENTIAL}` leaves
            // behind in a templated configuration -- present, non-empty, and
            // not a secret. Read literally it passes the "is this configured?"
            // test and buys a login that cannot succeed, then reports it as a
            // *rejected* credential rather than a missing one.
            _configured()..serviceAccountCredential = '   ',
          ),
          isNull,
        );
      },
    );

    test('SL06: whitespace within a real credential is presented as written '
        '[2026-08-21] (OK)', () {
      // The credential is trimmed to decide whether one was *configured*, and
      // nowhere else. A secret is opaque: if the auth server expects a
      // trailing space then that space has to reach it, and a framework that
      // quietly reshaped the value would turn a correct deployment into a
      // rejected login -- which the redaction policy then makes
      // undiagnosable. That is the same fault as the one above, inverted.
      // `_blankToNull` splits `smtpPassword` the same way.
      final credential = TomServiceCredential.fromConfiguration(
        _configured(credential: ' s3cret '),
      );
      expect(credential, isNotNull);
      expect(credential!.credential, ' s3cret ');
      final body = jsonDecode(credential.toRequestBody()) as Map;
      expect(body['password'], ' s3cret ');
    });

    test('SL07: the locale fields are the message type defaults, not a second '
        'copy of them [2026-08-21] (OK)', () {
      final body =
          jsonDecode(
                TomServiceCredential.fromConfiguration(
                  _configured(),
                )!.toRequestBody(),
              )
              as Map<String, dynamic>;

      // What actually goes on the wire, pinned so a reader of this test can
      // see it without going to look it up: a deployment is a process, not a
      // device, so it asserts no country -- `XX` is the ISO 3166-1
      // user-assigned code the kernel uses for "none" -- and no timezone but
      // UTC.
      expect(body['clientLanguage'], 'en');
      expect(body['clientCountry'], 'XX');
      expect(body['clientTimezone'], 'utc');

      // And the relationship those three stand in, which is the part that can
      // rot unobserved. The body is built by hand -- deliberately, so the
      // credential never meets a general serialiser -- and the price of that
      // is that nothing otherwise makes it agree with the type it claims to be
      // shaped as. They are that type's own defaults, so a kernel that moves
      // one fails here instead of leaving the deployment asserting a value the
      // auth server stopped expecting.
      final defaults = TomAuthenticationMessage();
      expect(body['clientLanguage'], defaults.clientLanguage);
      expect(body['clientCountry'], defaults.clientCountry);
      expect(body['clientTimezone'], defaults.clientTimezone);
    });

    test('SL04: an unusable URI yields null [2026-07-28] (OK)', () {
      expect(
        TomServiceCredential.fromConfiguration(
          _configured(uri: 'not a uri at all'),
        ),
        isNull,
      );
      expect(
        TomServiceCredential.fromConfiguration(_configured(uri: '/auth/login')),
        isNull,
        reason: 'a path without scheme and host cannot be dialled',
      );
    });

    test('SL05: toString never leaks the credential [2026-07-28] (OK)', () {
      final text = TomServiceCredential.fromConfiguration(
        _configured(),
      )!.toString();
      expect(text, contains('svc-app'));
      expect(text, isNot(contains('s3cret')));
    });
  });

  group('TomServerSelfLogin.logIn', () {
    test(
      'SL10: posts the credential to the configured login URI [2026-07-28] (OK)',
      () async {
        final transport = _FakeTransport(_kernelSpelling(_serviceToken()));
        await TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        );

        expect(transport.sentTo.toString(), 'http://auth.test:8081/auth/login');
        final sent = jsonDecode(transport.sentBody!) as Map<String, dynamic>;
        expect(sent['userName'], 'svc-app');
        expect(sent['password'], 's3cret');
        expect(sent['organization'], 'org');
      },
    );

    test('SL11: reconstructs the deployment principal, entitlements and all '
        '[2026-07-28] (OK)', () async {
      final transport = _FakeTransport(
        _kernelSpelling(
          _serviceToken(entitlements: ['feature.tasks', 'feature.reports']),
        ),
      );
      final principal = await TomServerSelfLogin.logIn(
        TomServiceCredential.fromConfiguration(_configured())!,
        transport: transport,
      );

      expect(principal.user.username, 'svc-app');
      expect(
        principal.aci.entitlements,
        containsAll(['feature.tasks', 'feature.reports']),
      );
    });

    test('SL12: accepts the short authToken/authzToken spelling too '
        '[2026-07-28] (OK)', () async {
      final transport = _FakeTransport(
        _shortSpelling(_serviceToken(entitlements: ['feature.tasks'])),
      );
      final principal = await TomServerSelfLogin.logIn(
        TomServiceCredential.fromConfiguration(_configured())!,
        transport: transport,
      );
      expect(principal.aci.entitlements, contains('feature.tasks'));
    });

    test('SL13: a rejected credential throws [2026-07-28] (OK)', () async {
      final transport = _FakeTransport('{"error":"nope"}', status: 401);
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.key,
            'key',
            'server.selflogin.rejected',
          ),
        ),
      );
    });

    test('SL14: an unreachable auth server throws, it does not degrade '
        '[2026-07-28] (OK)', () async {
      final transport = _FakeTransport('', throws: StateError('no route'));
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.key,
            'key',
            'server.selflogin.unreachable',
          ),
        ),
      );
    });

    test('SL15: a tokenless success body throws [2026-07-28] (OK)', () async {
      final transport = _FakeTransport('{"error":""}');
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.key,
            'key',
            'server.selflogin.no_token',
          ),
        ),
      );
    });

    test('SL16: a non-JSON body throws [2026-07-28] (OK)', () async {
      final transport = _FakeTransport('<html>gateway timeout</html>');
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.key,
            'key',
            'server.selflogin.bad_response',
          ),
        ),
      );
    });
  });

  group('TomServerSelfLogin.loginAndInstall', () {
    test('SL20: a configured deployment installs its own principal '
        '[2026-07-28] (OK)', () async {
      final transport = _FakeTransport(
        _kernelSpelling(_serviceToken(entitlements: ['feature.tasks'])),
      );

      final installed = await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );

      expect(installed, isTrue);
      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(
        TomServerPrincipal.current!.aci.entitlements,
        contains('feature.tasks'),
      );
    });

    test(
      'SL21: an unconfigured deployment is a silent no-op — nothing is sent and '
      'nothing is installed [2026-07-28] (OK)',
      () async {
        final transport = _FakeTransport(_kernelSpelling(_serviceToken()));

        final installed = await TomServerSelfLogin.loginAndInstall(
          _Config(),
          transport: transport,
        );

        expect(installed, isFalse);
        expect(transport.callCount, 0, reason: 'no call may be attempted');
        expect(TomServerPrincipal.isConfigured, isFalse);
      },
    );

    test('SL22: a configured deployment that cannot log in throws rather than '
        'running uncapped [2026-07-28] (OK)', () async {
      final transport = _FakeTransport('{}', status: 503);
      await expectLater(
        TomServerSelfLogin.loginAndInstall(_configured(), transport: transport),
        throwsA(isA<TomServerSelfLoginException>()),
      );
      expect(
        TomServerPrincipal.isConfigured,
        isFalse,
        reason: 'a failed login must leave no principal behind',
      );
    });
  });

  group('End to end: the installed principal caps user grants', () {
    test('SL30: a deployment entitled to read only caps a full user to read '
        '[2026-07-28] (OK)', () async {
      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: _FakeTransport(
          _kernelSpelling(_serviceToken(entitlements: ['feature.tasks.read'])),
        ),
      );

      final control = TomGradedAccess(
        full: const TomEntitlementAccess([r'^feature\.tasks\.write$']),
        read: const TomEntitlementAccess([r'^feature\.tasks\.read$']),
      );
      final user = TomPrincipal(
        authenticated: true,
        user: TomUser(id: 1, username: 'alice'),
        aci: TomAccessControlInformation(
          entitlements: ['feature.tasks.write', 'feature.tasks.read'],
        ),
      );

      expect(control.resolveAuthState(user), TomAuthState.read);
    });

    test('SL31: an unconfigured deployment leaves the same user at full '
        '[2026-07-28] (OK)', () async {
      await TomServerSelfLogin.loginAndInstall(
        _Config(),
        transport: _FakeTransport('{}'),
      );

      final control = TomGradedAccess(
        full: const TomEntitlementAccess([r'^feature\.tasks\.write$']),
        read: const TomEntitlementAccess([r'^feature\.tasks\.read$']),
      );
      final user = TomPrincipal(
        authenticated: true,
        user: TomUser(id: 1, username: 'alice'),
        aci: TomAccessControlInformation(
          entitlements: ['feature.tasks.write', 'feature.tasks.read'],
        ),
      );

      expect(control.resolveAuthState(user), TomAuthState.full);
    });
  });
}
