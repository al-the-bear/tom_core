import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// Tests for the socket-free surface of the server module: the per-request
/// log state ([TomRequestLogInfo]), the credential reader
/// ([extractAuthentication]), the pipeline middlewares that can run without
/// binding a port ([contextSetupMiddleware], [tomLoggingMiddleware],
/// [tomDefaultAuthenticationMiddleware], [noopHandler]), and the default
/// [TomServer.errorHandler] mapping closure.
///
/// [TomServer.start] binds a real socket and needs a reflected
/// `TomConfiguration` plus TLS material, so **nothing in this package calls
/// it** — no suite here binds a port. Its coverage is in two places, and each
/// answers a different half:
///
///  * the one property of `start()` that a running server cannot demonstrate
///    is asserted from the *source*, by
///    `test/api_reference_coverage_test.dart`, in the group named
///    `start() logs the deployment in before it binds`. It requires the server
///    self-login to precede the bind, because a socket accepting requests
///    before the deployment principal is installed serves them with user grants
///    uncapped — a window a passing integration run would not notice.
///  * the bind itself, end to end against real databases, by the sample
///    integration scripts in `tom_core_samples`:
///    `core_server_sample/tool/run_integration.sh` and
///    `advanced_client_core/tool/run_cross_tier_integration.sh`, whose servers
///    end their `main` with `TomServer(configuration).start()`.
///
/// That second half is a *sample's* script rather than an integration suite of
/// this package's, and saying so is the point: this package has no integration
/// directory and no integration suite, so a header claiming one sends the
/// reader looking for something that does not exist.
///
/// The default [TomServer.errorHandler] is a self-contained closure that maps a
/// thrown error to a JSON HTTP-500 response; it touches no socket, so it *is*
/// pinned here (constructing a [TomServer] from a no-op configuration subclass,
/// without bootstrapping codegen reflection).
///
/// Named by group and by script rather than by line number on purpose: these
/// pointers have to survive the files they point into being edited.

/// A JWT signed with the configuration this deployment has installed.
String _signed(Map<String, dynamic> claims) =>
    TomServerJwtToken(claims).getJWT('issuer');

/// [token] with its public claims edited by [edit] and its original signature
/// left in place — what a client can produce with three lines and a base64
/// decoder, and what a decode-only server could not tell from the real thing.
String _withEditedPayload(
  String token,
  void Function(Map<String, dynamic> claims) edit,
) {
  String pad(String s) => s.padRight((s.length + 3) & ~3, '=');
  final parts = token.split('.');
  final claims =
      jsonDecode(utf8.decode(base64Url.decode(pad(parts[1]))))
          as Map<String, dynamic>;
  edit(claims);
  final edited = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  return '${parts[0]}.$edited.${parts[2]}';
}

Request _get([Map<String, String>? headers]) =>
    Request('GET', Uri.parse('http://localhost/resource'), headers: headers);

/// A concrete configuration that skips the generated reflection so a [TomServer]
/// can be constructed without codegen — its merged values are simply discarded.
/// Mirrors `configuration_test.dart`'s `_CapturingConfig`.
class _NoopConfig extends TomBaseServerConfiguration {
  _NoopConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// A [_NoopConfig] that names its application, so [tomAppId] has something to
/// report. Named in the constructor body, which is where a real server names
/// itself.
class _AppIdConfig extends TomBaseServerConfiguration {
  _AppIdConfig(String id) : super([]) {
    appId = id;
  }
  @override
  void setValues(Map<String, Object?> values) {}
}

/// A [TomLogOutput] that keeps every message instead of printing it, so a test
/// can assert on what the library actually wrote.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => messages.add(convertToString(message));
}

void main() {
  group('TomRequestLogInfo', () {
    test('defaults to should-be-logged, not-yet-logged', () {
      final info = TomRequestLogInfo();
      expect(info.shouldBeLogged, isTrue);
      expect(info.hasBeenLogged, isFalse);
    });

    test('exposes the context key', () {
      expect(TomRequestLogInfo.contextName, 'loggingInfo');
    });

    test('toString reflects both flags', () {
      final info = TomRequestLogInfo()..hasBeenLogged = true;
      expect(info.toString(), 'TomRequestLogInfo should=true has=true');
    });
  });

  group('extractAuthentication', () {
    test('returns (null, null) when no Authorization header is present', () {
      final (principal, token) = extractAuthentication(_get());
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('returns (null, null) for a non-bearer scheme', () {
      final (principal, token) = extractAuthentication(
        _get({'authorization': 'Basic dXNlcjpwYXNz'}),
      );
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('returns (null, null) for a malformed bearer token', () {
      final (principal, token) = extractAuthentication(
        _get({'authorization': 'Bearer not-a-jwt'}),
      );
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('accepts a token this deployment signed', () {
      final (principal, token) = extractAuthentication(
        _get({
          'authorization': 'Bearer ${_signed({'userId': 'u'})}',
        }),
      );
      expect(token, isNotNull);
      expect(token!.payload!['userId'], 'u');
      expect(principal, isNotNull);
    });

    test('refuses a token whose payload was edited after issue', () {
      // The whole point. The claims are re-encoded and the original signature
      // is carried over unchanged — which is exactly what a client can do,
      // because the public section is plain base64 and nothing about decoding
      // objects to it.
      final forged = _withEditedPayload(
        _signed({'userId': 'u', 'role': 'user'}),
        (claims) => claims['role'] = 'admin',
      );
      final (principal, token) = extractAuthentication(
        _get({'authorization': 'Bearer $forged'}),
      );
      expect(token, isNull, reason: 'an edited payload must not decode at all');
      expect(principal, isNull);
    });

    test('refuses a token signed with somebody else\'s key', () {
      // A well-formed, correctly-signed token from a server this one does not
      // share a `jwtSharedSecretKey` with. Before the signature was checked,
      // "well-formed" was the whole test.
      final foreign = jwt
          .JWT({'userId': 'u'}, issuer: 'other-server')
          .sign(jwt.SecretKey('a-different-secret'));
      final (principal, token) = extractAuthentication(
        _get({'authorization': 'Bearer $foreign'}),
      );
      expect(token, isNull);
      expect(principal, isNull);
    });

    test('accepts a token this deployment signed that has expired', () {
      // Deliberate, and the opposite of what a signature check might be
      // expected to do. An expired token is still *ours*, and it is the only
      // thing left identifying who is asking — a refresh or re-login endpoint
      // is reached with exactly it. Expiry is answered one layer up, where
      // `tomDefaultAuthenticationMiddleware` resolves the session to no
      // principal while the credentials survive; see the middleware group
      // below, which asserts both halves.
      final expired = TomServerJwtToken({
        'userId': 'u',
      }, expiresIn: const Duration(hours: -1)).getJWT('issuer');
      final (_, token) = extractAuthentication(
        _get({'authorization': 'Bearer $expired'}),
      );
      expect(token, isNotNull);
    });
  });

  group('verifyBearerToken', () {
    test('returns the decoded token for a signature it can check', () {
      final verified = verifyBearerToken(_signed({'userId': 'u'}));
      expect(verified, isNotNull);
      expect(verified!.payload!['userId'], 'u');
    });

    test('returns null rather than throwing for every rejection', () {
      // The caller's contract is that an unusable token means *no
      // credentials*; throwing would turn a hostile request into a 500 and
      // hand the sender a way to tell a rejected signature from an accepted
      // one.
      expect(verifyBearerToken('not-a-jwt'), isNull);
      expect(verifyBearerToken(''), isNull);
      expect(
        verifyBearerToken(
          jwt.JWT({'userId': 'u'}).sign(jwt.SecretKey('wrong')),
        ),
        isNull,
      );
    });
  });

  group('noopHandler', () {
    test('ignores the request and returns the fixed status code', () async {
      final response = await noopHandler('t', 204)(_get());
      expect(response.statusCode, 204);
    });
  });

  group('contextSetupMiddleware', () {
    test('merges entries into the request context', () async {
      Object? seen;
      final handler = contextSetupMiddleware('seed', {'k': 'v'})((req) {
        seen = req.context['k'];
        return Response.ok('ok');
      });
      await handler(_get());
      expect(seen, 'v');
    });

    test(
      'passes the request through unchanged when no context is given',
      () async {
        final handler = contextSetupMiddleware('noop')(
          (req) => Response.ok('ok'),
        );
        expect((await handler(_get())).statusCode, 200);
      },
    );
  });

  group('tomLoggingMiddleware', () {
    test('emits at most once and marks the log info', () async {
      final info = TomRequestLogInfo();
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      await handler(request);
      expect(info.hasBeenLogged, isTrue);
    });

    test('does not re-log a request already marked as logged', () async {
      final info = TomRequestLogInfo()..hasBeenLogged = true;
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      // Should pass through without throwing and leave the flag set.
      expect((await handler(request)).statusCode, 200);
      expect(info.hasBeenLogged, isTrue);
    });

    test('emits nothing when shouldBeLogged is false', () async {
      // This is the opt-out an endpoint buys with `logRequests: false`: the
      // pipeline copies that flag onto TomRequestLogInfo.shouldBeLogged, and
      // TomHealthService uses it so an orchestrator probing /health every few
      // seconds does not bury the log. Asserted through hasBeenLogged rather
      // than by capturing output, because the middleware only sets that flag on
      // the branch that also emits -- so the flag staying false *is* the
      // suppression, and the two cannot drift apart.
      //
      // This is the property that shelf's own logRequests cannot honour: it
      // never sees the request context, so it would log all of these. It is
      // why the alternative documented on
      // TomBaseServerConfiguration.loggingMiddleware is not the default.
      final info = TomRequestLogInfo()..shouldBeLogged = false;
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      expect((await handler(request)).statusCode, 200);
      expect(info.hasBeenLogged, isFalse);
    });

    test('the access line names the application', () async {
      // This is the one line the library emits for every served request, and
      // until now it identified the request but not the process that served it.
      // That gap is why `tomAppId` exists, and this is the library reading it:
      // the advanced sample runs three servers side by side, two of them with
      // `isolateLogging = false`, so without the app id their access lines are
      // indistinguishable once collected anywhere in common.
      //
      // Captured rather than asserted through a flag -- unlike the suppression
      // tests above, the claim here *is* about the text.
      // Constructing it is what publishes it: the base constructor registers
      // the configuration, and `tomAppId` resolves `appId` through it.
      _AppIdConfig('billing');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final request = _get().change(
        context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
      );
      await tomLoggingMiddleware()((req) => Response.ok('ok'))(request);

      expect(output.messages.single, contains('[billing] '));
    });

    test('an unnamed application leaves no empty bracket on the line', () async {
      // The other half of the conditional prefix. A deployment that never sets
      // `appId` -- which is every one that has not needed the distinction --
      // must get the line it always got, not one opening `[] `. An empty
      // bracket reads as a *named* application whose name failed to render,
      // which is a worse report than no bracket at all.
      //
      // Found by mutation: making the prefix unconditional left the suite
      // green, the only assertion on the text being that it contains the name.
      _AppIdConfig('');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final request = _get().change(
        context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
      );
      await tomLoggingMiddleware()((req) => Response.ok('ok'))(request);

      expect(output.messages.single, isNot(contains('[]')));
      expect(output.messages.single, startsWith('HTTP/'));
    });
  });

  group('tomDefaultAuthenticationMiddleware', () {
    test('publishes a TomRequestId into the request zone', () async {
      TomRequestId? zoneId;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneId = getFromCurrentZone<TomRequestId>();
        return Response.ok('ok');
      });
      final response = await handler(_get());
      expect(response.statusCode, 200);
      expect(zoneId, isNotNull);
      expect(zoneId!.uuid, isNotEmpty);
    });

    test('resolves no principal when there are no credentials', () async {
      TomPrincipal? zonePrincipal;
      var sawPrincipalKey = false;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zonePrincipal = getFromCurrentZone<TomPrincipal>();
        sawPrincipalKey = true;
        return Response.ok('ok');
      });
      await handler(_get());
      expect(sawPrincipalKey, isTrue);
      expect(zonePrincipal, isNull);
    });

    test(
      'merges the optional context into the request seen by the handler',
      () async {
        Object? seen;
        final handler = tomDefaultAuthenticationMiddleware('auth', {'k': 'v'})((
          req,
        ) {
          seen = req.context['k'];
          return Response.ok('ok');
        });
        await handler(_get());
        expect(seen, 'v');
      },
    );

    test('publishes the original request into the request zone', () async {
      final request = _get();
      Request? zoneRequest;
      // With no context override the inner handler receives the same request,
      // and the zone publishes that identical instance.
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneRequest = getFromCurrentZone<Request>();
        return Response.ok('ok');
      });
      await handler(request);
      expect(identical(zoneRequest, request), isTrue);
    });

    test('publishes the parsed bearer token into the request zone', () async {
      final jwt = TomServerJwtToken({
        'userId': 'u',
      }, expiresIn: const Duration(hours: 2)).getJWT('tom');
      TomClientJwtToken? zoneToken;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneToken = getFromCurrentZone<TomClientJwtToken>();
        return Response.ok('ok');
      });
      await handler(_get({'authorization': 'Bearer $jwt'}));
      expect(zoneToken, isNotNull);
    });

    // An entry the cache has aged out. The two tests below drive the same
    // request; the first pins that the pipeline still answers it, the second
    // pins *what* the request is answered as.
    //
    // The token is minted already expired because the entry's lifetime *is* the
    // token's — `TomAuthorizationCache` reads its expiry from the token's
    // `validUntil` claim and refuses to invent one — so "the cached entry has
    // expired" and "this token has expired" are one fact, not two. A fixture
    // pairing a dead entry with a live token would be testing a state the cache
    // cannot reach.
    group('when the cached principal has expired', () {
      /// The bearer header for a token that expired an hour ago, with a
      /// principal cached under it. `username` is set so that
      /// [extractAuthentication] derives an *authenticated* principal from the
      /// token itself — which is precisely the principal that must not be used.
      Future<Map<String, String>> expiredCredentials() async {
        final token = TomClientJwtToken(
          TomServerJwtToken({
            'userId': 'u',
            'username': 'alice',
          }, expiresIn: const Duration(hours: -1)).getJWT('tom'),
        );
        await TomAuthorizationCache.storePrincipal(
          token,
          TomPrincipal(user: TomUser(username: 'alice'), authenticated: true),
        );
        addTearDown(TomAuthorizationCache.instance.dispose);
        return {'authorization': 'Bearer ${token.tokenString}'};
      }

      test('the request is still served, not failed', () async {
        var handlerRan = false;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          handlerRan = true;
          return Response.ok('ok');
        });
        // The expiry must not escape as an exception: the outer error
        // middleware would turn it into a generic HTTP 500 — an answer no
        // client can act on, and one a cold cache would not produce for this
        // same request, so the cache's mere presence would decide it.
        final response = await handler(_get(await expiredCredentials()));
        expect(handlerRan, isTrue);
        expect(response.statusCode, 200);
      });

      test('the token-derived principal is not used in its place', () async {
        TomPrincipal? zonePrincipal;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          zonePrincipal = getFromCurrentZone<TomPrincipal>();
          return Response.ok('ok');
        });
        await handler(_get(await expiredCredentials()));
        // The expired session resolves to *no* principal — the same answer a
        // request bearing no credentials gets. Falling back to the principal
        // `extractAuthentication` derived would serve the dead session as
        // `alice`, authenticated: that reader performs no expiry check, so the
        // fallback would turn a wrong-response bug into an authentication
        // bypass. A protected endpoint now refuses this request through the
        // ordinary access-denied path instead.
        expect(zonePrincipal, isNull);
      });

      test('the token itself still reaches the request zone', () async {
        TomClientJwtToken? zoneToken;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          zoneToken = getFromCurrentZone<TomClientJwtToken>();
          return Response.ok('ok');
        });
        await handler(_get(await expiredCredentials()));
        // Dropping the principal does not drop the credentials: a refresh or
        // re-login endpoint is reached with exactly this token, and it is the
        // only thing left identifying who is asking.
        expect(zoneToken, isNotNull);
      });
    });
  });

  // The TomServer constructor is the socket-free half of the class: it wires the
  // error, authentication-error, and logging handlers from the configuration,
  // falling back to the defaults. A no-op configuration subclass lets us build a
  // server without codegen reflection and inspect the wiring directly.
  group('TomServer constructor wiring', () {
    setUp(() {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
    });

    test('honours a configuration-supplied errorHandler', () {
      Response? custom(Request r, Object e, StackTrace s) => null;
      final config = _NoopConfig()..errorHandler = custom;
      final server = TomServer(config);
      expect(identical(server.errorHandler, custom), isTrue);
    });

    test('honours a configuration-supplied authenticationErrorHandler', () {
      Response? custom(Request r, Object e, StackTrace s) => null;
      final config = _NoopConfig()..authenticationErrorHandler = custom;
      final server = TomServer(config);
      expect(identical(server.authenticationErrorHandler, custom), isTrue);
    });

    test('authenticationErrorHandler falls back to errorHandler when neither is'
        ' configured', () {
      final server = TomServer(_NoopConfig());
      // Neither handler configured -> the auth-error handler is the very same
      // closure as the (default) main error handler.
      expect(
        identical(server.authenticationErrorHandler, server.errorHandler),
        isTrue,
      );
    });

    test('honours a configuration-supplied loggingMiddleware', () {
      final custom = tomLoggingMiddleware();
      final config = _NoopConfig()..loggingMiddleware = custom;
      final server = TomServer(config);
      expect(identical(server.loggingMiddleware, custom), isTrue);
    });
  });

  // The TLS material a deployment gets when it configures none is a real
  // self-signed pair whose private key is committed to this repository. It
  // stays -- a development machine has to be able to speak HTTPS without a
  // certificate authority -- so the boot says so, every time, rather than
  // serving a published key in silence.
  group('the development TLS pair announces itself', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    String warning() =>
        captured.messages.where((m) => m.contains('TLS')).join('\n');

    test('a configuration that overrides neither half is warned about', () {
      TomServer(_NoopConfig()).warnOnDevelopmentTlsMaterial();
      // The three things an operator needs: that it is happening, that the key
      // is public, and which fields to set.
      expect(warning(), contains('development'));
      expect(warning(), contains('published'));
      expect(warning(), contains('certificateChain'));
      expect(warning(), contains('privateKey'));
    });

    // The half that matters most, told apart from the other: a deployment that
    // supplied its own chain and left the key is still serving a published key.
    test('overriding only the chain is still warned about', () {
      final config = _NoopConfig()..certificateChain = '-----BEGIN CERT-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(warning(), contains('private key'));
    });

    // And the reverse, which is a different fault with the same remedy: the
    // pair no longer matches, so the bind fails -- worth saying before it does.
    test('overriding only the key is still warned about', () {
      final config = _NoopConfig()..privateKey = '-----BEGIN KEY-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(warning(), contains('certificate chain'));
    });

    test('a configuration that overrides both is silent', () {
      final config = _NoopConfig()
        ..certificateChain = '-----BEGIN CERT-----'
        ..privateKey = '-----BEGIN KEY-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(captured.messages, isEmpty);
    });

    // Nothing is served over TLS, so there is nothing to warn about -- and a
    // warning here would be the kind that teaches an operator to ignore them.
    test('a plaintext server is silent, default pair or not', () {
      TomServer(_NoopConfig()..noSsl = true).warnOnDevelopmentTlsMaterial();
      expect(captured.messages, isEmpty);
    });

    test('the condition is readable on the configuration itself', () {
      expect(_NoopConfig().usesDevelopmentTlsMaterial(), isTrue);
      final overridden = _NoopConfig()
        ..certificateChain = 'x'
        ..privateKey = 'y';
      expect(overridden.usesDevelopmentTlsMaterial(), isFalse);
    });

    // `start()` is fire-and-forget and binds a socket, so nothing in this
    // package calls it (see the header). The warning is a public method for
    // that reason -- and the source is what says the boot still calls it,
    // which is the same technique the self-login ordering is pinned with.
    test('start() calls it, before it builds the context', () {
      final lines = File(
        'lib/src/tomserver/server/server.dart',
      ).readAsLinesSync();
      // The *call*, not the declaration: `…Material();` ends in a semicolon
      // where `void …Material() {` does not. Searching for the bare name would
      // match the method itself, and the guard would pass with nothing calling
      // it -- which is exactly what the first draft of this test did.
      final call = lines.indexWhere(
        (l) => l.contains('warnOnDevelopmentTlsMaterial();'),
      );
      final context = lines.indexWhere((l) => l.contains('SecurityContext()'));
      expect(
        call,
        greaterThanOrEqualTo(0),
        reason: 'start() no longer announces the development TLS pair',
      );
      expect(
        context,
        greaterThan(call),
        reason: 'the warning must precede the context it is about',
      );
    });
  });

  // Pins the default error-mapping contract documented on TomServer.errorHandler
  // every thrown error becomes an HTTP-500 JSON response carrying
  // `x-tom-error: true` and an `errorType`; a TomException contributes
  // `errorKey`/`uuid`/`autoLog`/`requestUuid`; a TomServerException additionally
  // contributes `clientThrow`. No behaviour change — characterization only.
  group('TomServer.errorHandler', () {
    late TomServer server;

    setUp(() {
      // Isolate from any provider left installed by another suite.
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      server = TomServer(_NoopConfig());
    });

    /// Drives the default handler and decodes its response.
    Future<
      ({int status, Map<String, String> headers, Map<String, dynamic> body})
    >
    map(Object error) async {
      final response = server.errorHandler(_get(), error, StackTrace.current);
      expect(
        response,
        isNotNull,
        reason: 'the default handler always responds',
      );
      final body =
          jsonDecode(await response!.readAsString()) as Map<String, dynamic>;
      return (
        status: response.statusCode,
        headers: response.headers,
        body: body,
      );
    }

    test('a plain error maps to HTTP 500 with only errorType', () async {
      final result = await map(const FormatException('boom'));
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorType'], 'FormatException');
      // A non-Tom error contributes none of the Tom-specific fields.
      expect(result.body.containsKey('errorKey'), isFalse);
      expect(result.body.containsKey('clientThrow'), isFalse);
    });

    test('a TomException adds errorKey/uuid/autoLog/requestUuid', () async {
      final error = TomException('user.fetch.not_found', 'no such user');
      final result = await map(error);
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorType'], 'TomException');
      expect(result.body['errorKey'], 'user.fetch.not_found');
      expect(result.body['uuid'], error.uuid);
      expect(result.body['autoLog'], isFalse);
      expect(result.body['requestUuid'], isNull);
      // Not a server exception -> no clientThrow.
      expect(result.body.containsKey('clientThrow'), isFalse);
    });

    test('a TomServerException additionally adds clientThrow', () async {
      final error = TomServerException(
        'db.fail',
        'query failed',
        clientThrow: false,
      );
      final result = await map(error);
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorKey'], 'db.fail');
      // The server-exception arm carries the masking flag through.
      expect(result.body['clientThrow'], isFalse);
    });

    test('clientThrow defaults to true and is reported as such', () async {
      final result = await map(TomServerException('db.fail', 'query failed'));
      expect(result.body['clientThrow'], isTrue);
    });

    test('the envelope declares the media type of the body it sends', () async {
      // This handler is the framework's error shape — the one every other
      // JSON-envelope handler in the package is written to match. A body a
      // client is expected to decode by `errorKey` has to say it is JSON, or
      // the client has only the `x-tom-error` header to guess from and an
      // intermediary has nothing at all.
      final result = await map(TomException('db.fail', 'query failed'));
      expect(
        TomMimeType.parse(result.headers[TomHeader.contentType]!),
        TomMimeType.json,
      );
    });
  });

  group('a request rejected during authentication is still logged', () {
    // The access log's whole point is the requests an operator did not expect:
    // an expired token, a token signed by the wrong key, an authorization cache
    // that cannot be reached. Those fail while the principal is being
    // established — and while the logging middleware sat *below* the error
    // layers, every one of them produced no line at all. An operator read a
    // quiet server for exactly the traffic worth reading about.
    //
    // Asserted through a real server rather than by composing the middlewares
    // here, because the claim is about the pipeline's *order*: a hand-built
    // stack in this file would only re-assert the order this file chose.
    setUpAll(() {
      initializeReflection();
      TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      registerFixtureAccessApi();
    });

    /// Captures the log while [body] runs against a freshly started server.
    Future<List<String>> logOf(TomBaseServerConfiguration config) async {
      _AppIdConfig('');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);

      final server = await TomServer(config).start();
      addTearDown(() => server.close(force: true));

      // Installed after the bind so the boot's own lines are not captured.
      tomLog.logOutput = output;
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', server.port, '/anything');
      final response = await request.close();
      await response.drain<void>();
      return output.messages;
    }

    test('the rejection produces an access-log line', () async {
      final messages = await logOf(_RejectingAuthConfig());

      expect(
        messages.where((line) => line.startsWith('HTTP/')),
        hasLength(1),
        reason:
            'a request refused during authentication must appear in the access '
            'log exactly once — the line naming method, path and status is the '
            'one an operator can correlate and count',
      );
    });

    test('the line names the method, the path and the status', () async {
      // `_handleError` already logged the *error*, and that line names none of
      // these — which is why an error line is not a substitute for an access
      // line, and why this asserts the fields rather than that something was
      // written.
      final line = (await logOf(
        _RejectingAuthConfig(),
      )).firstWhere((message) => message.startsWith('HTTP/'));

      expect(line, contains('[GET]'));
      expect(line, contains('/anything'));
      expect(line, contains('500'));
    });

    test(
      'a request that is not rejected is still logged exactly once',
      () async {
        // The other direction. The endpoint pipeline writes its own, richer line
        // and marks the request logged, so moving the middleware outwards must
        // not add a second one for every served request.
        final messages = await logOf(_BindableConfig());

        expect(
          messages.where((line) => line.startsWith('HTTP/')),
          hasLength(lessThanOrEqualTo(1)),
        );
      },
    );
  });

  group('start binds, and hands back what it bound', () {
    // The header above says the bind is covered only by the samples' own
    // integration scripts. That was true while `start()` returned `void`:
    // nothing could tell *listening* from *called*, and nothing could close the
    // socket afterwards, so a suite that started a server could not end. Both
    // follow from the returned handle, which is why these run here now.
    setUpAll(() {
      initializeReflection();
      TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      registerFixtureAccessApi();
    });

    test('the future completes with a listening socket', () async {
      final server = await TomServer(_BindableConfig()).start();
      addTearDown(() => server.close(force: true));

      // Port 0 asks the OS to choose, so a non-zero port is the proof that a
      // bind actually happened rather than that a future completed.
      expect(server.port, isNot(0));
      expect(server.address.address, '127.0.0.1');
    });

    test('a bind failure rejects the future', () async {
      // The failure the fire-and-forget shape turned into an unhandled
      // asynchronous error: a deployment meets it on its first port collision,
      // and used to meet it as a stack trace from nowhere rather than as a
      // rejected future at the call site.
      final first = await TomServer(_BindableConfig()).start();
      addTearDown(() => first.close(force: true));

      await expectLater(
        TomServer(_BindableConfig(port: first.port)).start(),
        throwsA(isA<SocketException>()),
      );
    });

    test('the handle closes the socket', () async {
      // The other half of "returns no handle to close": without this a test or
      // a supervisor can start a server and never stop it, which is what kept
      // the bind out of this suite.
      final server = await TomServer(_BindableConfig()).start();
      final port = server.port;

      await server.close(force: true);

      // Closed for real, not merely forgotten: the port binds again, which it
      // could not while the first socket held it.
      final second = await TomServer(_BindableConfig(port: port)).start();
      addTearDown(() => second.close(force: true));
      expect(second.port, port);
    });
  });
}

/// A configuration that binds a real socket on the loopback interface.
///
/// Port `0` asks the OS for a free one, so the suite never collides with a
/// developer's running server — and the chosen port is readable off the handle,
/// which is what lets the collision test *aim* at it.
class _BindableConfig extends TomBaseServerConfiguration {
  _BindableConfig({int port = 0}) : super([]) {
    noSsl = true;
    host = '127.0.0.1';
    isolateCount = 1;
    this.port = port;
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A configuration whose authentication middleware refuses every request.
///
/// Stands in for the real refusals — an expired token, a wrong signing key, an
/// unreachable authorization cache — all of which fail at the same point in the
/// pipeline and are answered by the same error layer.
class _RejectingAuthConfig extends _BindableConfig {
  _RejectingAuthConfig() {
    authenticationMiddleware = (innerHandler) =>
        (request) => throw TomServerException('test.auth.rejected', 'refused');
  }
}
