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

/// A transport that answers a different body on each call, so a renewal can be
/// told apart from the login it replaces.
class _SequenceTransport extends TomServiceLoginTransport {
  final List<String> bodies;
  final Object? throwsFrom;

  int callCount = 0;

  _SequenceTransport(this.bodies, {this.throwsFrom});

  @override
  Future<TomServiceLoginResponse> postJson(Uri uri, String requestBody) async {
    callCount++;
    if (throwsFrom != null && callCount >= 2) throw throwsFrom!;
    final body =
        bodies[callCount <= bodies.length ? callCount - 1 : bodies.length - 1];
    return TomServiceLoginResponse(200, body);
  }
}

/// Builds a signed token whose encrypted section carries [entitlements].
String _serviceToken({
  String username = 'svc-app',
  List<String> entitlements = const [],
  Duration expiresIn = const Duration(hours: 2),
}) => TomServerJwtToken(
  {'username': username, 'userId': 42},
  encryptedData: {'entitlements': entitlements},
  expiresIn: expiresIn,
).getJWT('tom');

/// A token whose payload carries no `exp`, as a foreign auth server may issue.
///
/// Hand-built: `TomServerJwtToken` always stamps an expiry, and the reader
/// decodes rather than verifies, so the unsigned shape is enough to carry the
/// claims this case is about.
String _tokenWithoutExpiry() {
  String segment(Map<String, Object?> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${segment(const {'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment(const {'username': 'svc-app', 'userId': 42, 'iss': 'tom'})}.'
      'not-a-signature';
}

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
    test('reads a fully configured deployment identity', () {
      final credential = TomServiceCredential.fromConfiguration(_configured());
      expect(credential, isNotNull);
      expect(credential!.username, 'svc-app');
      expect(credential.credential, 's3cret');
      expect(credential.loginUri.host, 'auth.test');
      expect(credential.loginUri.port, 8081);
      expect(credential.organization, 'org');
    });

    test('an untouched configuration yields null', () {
      expect(TomServiceCredential.fromConfiguration(_Config()), isNull);
    });

    test('a partially configured deployment yields null rather than half a '
        'credential', () {
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
    });

    test('an unusable URI yields null', () {
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

    test('whitespace within a real credential is presented as written', () {
      // The credential is trimmed to decide whether one was *configured*, and
      // nowhere else. A secret is opaque: if the auth server expects a
      // trailing space then that space has to reach it, and a framework that
      // quietly reshaped the value would turn a correct deployment into a
      // rejected login -- which the redaction policy then makes
      // undiagnosable. That is the all-whitespace credential of the
      // partial-configuration test, inverted. `_blankToNull` splits
      // `smtpPassword` the same way.
      final credential = TomServiceCredential.fromConfiguration(
        _configured(credential: ' s3cret '),
      );
      expect(credential, isNotNull);
      expect(credential!.credential, ' s3cret ');
      final body = jsonDecode(credential.toRequestBody()) as Map;
      expect(body['password'], ' s3cret ');
    });

    test('the locale fields are the message type defaults, not a second copy '
        'of them', () {
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

    test('toString never leaks the credential', () {
      final text = TomServiceCredential.fromConfiguration(
        _configured(),
      )!.toString();
      expect(text, contains('svc-app'));
      expect(text, isNot(contains('s3cret')));
    });
  });

  group('TomServerSelfLogin.logIn', () {
    test('posts the credential to the configured login URI', () async {
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
    });

    test(
      'reconstructs the deployment principal, entitlements and all',
      () async {
        final transport = _FakeTransport(
          _kernelSpelling(
            _serviceToken(entitlements: ['feature.tasks', 'feature.reports']),
          ),
        );
        final session = await TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        );

        expect(session.principal.user.username, 'svc-app');
        expect(
          session.principal.aci.entitlements,
          containsAll(['feature.tasks', 'feature.reports']),
        );
      },
    );

    test('accepts the short authToken/authzToken spelling too', () async {
      final transport = _FakeTransport(
        _shortSpelling(_serviceToken(entitlements: ['feature.tasks'])),
      );
      final session = await TomServerSelfLogin.logIn(
        TomServiceCredential.fromConfiguration(_configured())!,
        transport: transport,
      );
      expect(session.principal.aci.entitlements, contains('feature.tasks'));
    });

    test('a rejected credential throws', () async {
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

    test('an unreachable auth server throws, it does not degrade', () async {
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

    test('an unreachable auth server carries the call detail', () async {
      // "Could not be reached" as a sentence is something an operator reads; a
      // TomServerCallError is something anything can branch on. The kernel
      // raises one for a refused or failed call, and until the base
      // constructor forwarded the parameter there was nowhere to put it — so
      // the status and body the transport actually saw were dropped, leaving
      // only whatever the message had interpolated.
      final refused = TomServerConnectionException(
        'error.unknown_server_error',
        'no upstream',
        serverCallError: TomServerCallError(
          statusCode: 502,
          response: 'bad gateway',
        ),
      );
      final transport = _FakeTransport('', throws: refused);

      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>()
              .having((e) => e.key, 'key', 'server.selflogin.unreachable')
              .having(
                (e) => e.serverCallError?.statusCode,
                'serverCallError.statusCode',
                502,
              )
              .having((e) => e.rootException, 'rootException', same(refused)),
        ),
      );
    });

    test('a non-HTTP failure leaves the call detail unset', () async {
      // The control. Without it the assertion above is satisfied by a field
      // that is filled with something regardless of what was caught.
      final transport = _FakeTransport('', throws: StateError('no route'));
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.serverCallError,
            'serverCallError',
            isNull,
          ),
        ),
      );
    });

    test('a tokenless success body throws', () async {
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

    test('a non-JSON body throws', () async {
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

    // The last thing between a response and a principal, and the one failure
    // that arrives from *inside* another library. The body is well-formed and
    // both token fields are present and non-empty, so `_readTokens` passes —
    // and then the string is not a JWT. The test above covers a body that is
    // not JSON; this is the different case of a well-formed body whose token
    // field is rubbish, which an auth server behind a misconfigured proxy
    // produces. It must still come back keyed, not as whatever
    // `dart_jsonwebtoken` threw.
    test('a token field that is not a JWT throws', () async {
      final transport = _FakeTransport(_kernelSpelling('not-a-jwt'));
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>()
              .having((e) => e.key, 'key', 'server.selflogin.bad_token')
              // The auth server is named: a deployment dials one URI for this
              // and the operator has to know which one answered rubbish.
              .having(
                (e) => e.toString(),
                'message',
                contains('auth.test:8081'),
              ),
        ),
      );
    });

    // A JWT whose payload is a JSON *string* rather than an object decodes
    // without complaint and then fails the cast in the payload getter — a
    // `TypeError`, not a `StateError`, and from a third library again. One key
    // covers the family precisely because the caller's move is the same for
    // every member of it.
    test('a token whose payload is not an object throws', () async {
      String seg(String s) =>
          base64Url.encode(utf8.encode(s)).replaceAll('=', '');
      final token =
          '${seg('{"alg":"HS256","typ":"JWT"}')}.${seg('"not-an-object"')}.sig';
      final transport = _FakeTransport(_kernelSpelling(token));
      await expectLater(
        TomServerSelfLogin.logIn(
          TomServiceCredential.fromConfiguration(_configured())!,
          transport: transport,
        ),
        throwsA(
          isA<TomServerSelfLoginException>().having(
            (e) => e.key,
            'key',
            'server.selflogin.bad_token',
          ),
        ),
      );
    });
  });

  group('TomServerSelfLogin.loginAndInstall', () {
    test('a configured deployment installs its own principal', () async {
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

    test('an unconfigured deployment is a silent no-op — nothing is sent and '
        'nothing is installed', () async {
      final transport = _FakeTransport(_kernelSpelling(_serviceToken()));

      final installed = await TomServerSelfLogin.loginAndInstall(
        _Config(),
        transport: transport,
      );

      expect(installed, isFalse);
      expect(transport.callCount, 0, reason: 'no call may be attempted');
      expect(TomServerPrincipal.isConfigured, isFalse);
    });

    test('a configured deployment that cannot log in throws rather than '
        'running uncapped', () async {
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

  group('the server principal is renewed before its token expires', () {
    // The cap is only as current as the principal behind it: a server
    // principal installed once at start-up keeps capping every user at the
    // entitlements it held then, so an authorization change made in the auth
    // server reaches this deployment at its next restart and not before. And
    // because nothing checked expiry, nothing said so — the boot log announced
    // the login and then went quiet.
    setUp(TomServerSelfLogin.stopRenewal);
    tearDown(TomServerSelfLogin.stopRenewal);

    group('the delay arithmetic', () {
      final now = DateTime.utc(2026, 3, 4, 12);

      test('renews one lead time before expiry', () {
        expect(
          TomServerSelfLogin.renewalDelayFor(
            now.add(const Duration(minutes: 30)),
            now: now,
            lead: const Duration(minutes: 2),
          ),
          const Duration(minutes: 28),
        );
      });

      test(
        'a token whose life is shorter than the lead renews at the floor',
        () {
          // Not an error — a deployment may issue very short service tokens —
          // but the loop must not busy-wait, and the clamp is what stops it.
          expect(
            TomServerSelfLogin.renewalDelayFor(
              now.add(const Duration(seconds: 10)),
              now: now,
              lead: const Duration(minutes: 2),
            ),
            TomServerSelfLogin.minimumRenewalDelay,
          );
        },
      );

      test('an expiry already past renews at the floor, not in the past', () {
        expect(
          TomServerSelfLogin.renewalDelayFor(
            now.subtract(const Duration(minutes: 5)),
            now: now,
            lead: const Duration(minutes: 2),
          ),
          TomServerSelfLogin.minimumRenewalDelay,
        );
      });

      test('a token with no expiry cannot be scheduled against', () {
        expect(
          TomServerSelfLogin.renewalDelayFor(
            null,
            now: now,
            lead: Duration.zero,
          ),
          isNull,
        );
      });
    });

    test('the login reports when the session expires', () async {
      final transport = _FakeTransport(
        _kernelSpelling(_serviceToken(expiresIn: const Duration(minutes: 30))),
      );

      final session = await TomServerSelfLogin.logIn(
        TomServiceCredential.fromConfiguration(_configured())!,
        transport: transport,
      );

      expect(session.principal.user.username, 'svc-app');
      expect(session.expiresAt, isNotNull);
      expect(
        session.expiresAt!.difference(DateTime.now().toUtc()).inMinutes,
        closeTo(30, 1),
      );
    });

    test('installing arms the renewal and says until when', () async {
      final transport = _FakeTransport(
        _kernelSpelling(_serviceToken(expiresIn: const Duration(hours: 2))),
      );

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );

      expect(TomServerSelfLogin.isRenewing, isTrue);
      expect(TomServerSelfLogin.installedUntil, isNotNull);
    });

    test('renewal installs the entitlements the auth server holds now', () async {
      // The whole point: an entitlement removed upstream stops capping at the
      // old value without anyone restarting the deployment.
      final transport = _SequenceTransport([
        _kernelSpelling(
          _serviceToken(entitlements: ['feature.tasks', 'feature.reports']),
        ),
        _kernelSpelling(_serviceToken(entitlements: ['feature.tasks'])),
      ]);

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );
      expect(
        TomServerPrincipal.current!.aci.entitlements,
        containsAll(['feature.tasks', 'feature.reports']),
      );

      final renewed = await TomServerSelfLogin.renewNow();

      expect(renewed, isTrue);
      expect(transport.callCount, 2);
      expect(
        TomServerPrincipal.current!.aci.entitlements,
        isNot(contains('feature.reports')),
        reason:
            'the second install is what makes the cap current — a renewal that '
            'left the old principal in place would be a timer that changes '
            'nothing',
      );
    });

    test('a failed renewal keeps the principal it has', () async {
      // The direction of the failure is the whole safety argument. Clearing
      // the principal *widens* access — every user's grant stops being capped
      // — so a renewal that cannot reach the auth server must leave the last
      // good cap standing and say so.
      final transport = _SequenceTransport([
        _kernelSpelling(_serviceToken(entitlements: ['feature.tasks'])),
      ], throwsFrom: StateError('auth server down'));

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );

      final renewed = await TomServerSelfLogin.renewNow();

      expect(renewed, isFalse);
      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(
        TomServerPrincipal.current!.aci.entitlements,
        contains('feature.tasks'),
      );
      expect(
        TomServerSelfLogin.isRenewing,
        isTrue,
        reason: 'a failed renewal schedules another try rather than giving up',
      );
    });

    test('renewal can be declined at the call', () async {
      final transport = _FakeTransport(_kernelSpelling(_serviceToken()));

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
        renew: false,
      );

      expect(TomServerSelfLogin.isRenewing, isFalse);
      expect(TomServerPrincipal.isConfigured, isTrue);
    });

    test('a token with no expiry is installed but not renewed', () async {
      // Nothing to schedule against. Installing anyway is right — the cap is
      // real — but pretending to renew it would be a timer with no deadline.
      final transport = _FakeTransport(_kernelSpelling(_tokenWithoutExpiry()));

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );

      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(TomServerSelfLogin.isRenewing, isFalse);
      expect(TomServerSelfLogin.installedUntil, isNull);
    });

    test('stopping disarms the loop', () async {
      final transport = _FakeTransport(_kernelSpelling(_serviceToken()));
      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );
      expect(TomServerSelfLogin.isRenewing, isTrue);

      TomServerSelfLogin.stopRenewal();

      expect(TomServerSelfLogin.isRenewing, isFalse);
      expect(
        TomServerPrincipal.isConfigured,
        isTrue,
        reason:
            'stopping the renewal is not clearing the principal — clearing '
            'widens access, which is never the answer to a timer',
      );
    });

    test('the loop fires on its own', () async {
      // The one test that lets a real timer run: everything above proves the
      // pieces, and this proves they are wired to each other.
      final transport = _SequenceTransport([
        _kernelSpelling(
          _serviceToken(
            entitlements: ['feature.tasks'],
            expiresIn: const Duration(seconds: 1),
          ),
        ),
        _kernelSpelling(_serviceToken(entitlements: ['feature.renewed'])),
      ]);

      await TomServerSelfLogin.loginAndInstall(
        _configured(),
        transport: transport,
      );

      await Future<void>.delayed(
        TomServerSelfLogin.minimumRenewalDelay + const Duration(seconds: 1),
      );

      expect(transport.callCount, greaterThanOrEqualTo(2));
      expect(
        TomServerPrincipal.current!.aci.entitlements,
        contains('feature.renewed'),
      );
    });
  });

  group('End to end: the installed principal caps user grants', () {
    test(
      'a deployment entitled to read only caps a full user to read',
      () async {
        await TomServerSelfLogin.loginAndInstall(
          _configured(),
          transport: _FakeTransport(
            _kernelSpelling(
              _serviceToken(entitlements: ['feature.tasks.read']),
            ),
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
      },
    );

    test('an unconfigured deployment leaves the same user at full', () async {
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
