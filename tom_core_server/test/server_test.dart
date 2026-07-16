import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the socket-free surface of the server module: the per-request
/// value objects ([TomRequestId], [TomRequestLogInfo]), the credential reader
/// ([extractAuthentication]), the pipeline middlewares that can run without
/// binding a port ([contextSetupMiddleware], [tomLoggingMiddleware],
/// [tomDefaultAuthenticationMiddleware], [noopHandler]), and the default
/// [TomServer.errorHandler] mapping closure.
///
/// [TomServer.start] binds a real socket and needs a reflected `TomConfiguration`
/// plus TLS material, so the listen/pipeline path is covered by `doc/server.md`
/// and integration tests, not here. The default [TomServer.errorHandler] is a
/// self-contained closure that maps a thrown error to a JSON HTTP-500 response;
/// it touches no socket, so it *is* pinned here (constructing a [TomServer] from
/// a no-op configuration subclass, without bootstrapping codegen reflection).

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

void main() {
  group('TomRequestId', () {
    test('generates a non-empty v4 uuid', () {
      expect(TomRequestId().uuid, isNotEmpty);
    });

    test('generates distinct ids per instance', () {
      expect(TomRequestId().uuid, isNot(TomRequestId().uuid));
    });

    test('toString carries the uuid', () {
      final id = TomRequestId();
      expect(id.toString(), 'TomRequestId: ${id.uuid}');
    });
  });

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
      final (principal, token) =
          extractAuthentication(_get({'authorization': 'Basic dXNlcjpwYXNz'}));
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('returns (null, null) for a malformed bearer token', () {
      final (principal, token) =
          extractAuthentication(_get({'authorization': 'Bearer not-a-jwt'}));
      expect(principal, isNull);
      expect(token, isNull);
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

    test('passes the request through unchanged when no context is given',
        () async {
      final handler =
          contextSetupMiddleware('noop')((req) => Response.ok('ok'));
      expect((await handler(_get())).statusCode, 200);
    });
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
  });

  group('tomDefaultAuthenticationMiddleware', () {
    test('publishes a TomRequestId into the request zone', () async {
      TomRequestId? zoneId;
      final handler =
          tomDefaultAuthenticationMiddleware('auth')((req) {
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
      final handler =
          tomDefaultAuthenticationMiddleware('auth')((req) {
        zonePrincipal = getFromCurrentZone<TomPrincipal>();
        sawPrincipalKey = true;
        return Response.ok('ok');
      });
      await handler(_get());
      expect(sawPrincipalKey, isTrue);
      expect(zonePrincipal, isNull);
    });

    test('merges the optional context into the request seen by the handler',
        () async {
      Object? seen;
      final handler =
          tomDefaultAuthenticationMiddleware('auth', {'k': 'v'})((req) {
        seen = req.context['k'];
        return Response.ok('ok');
      });
      await handler(_get());
      expect(seen, 'v');
    });

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
      final jwt = TomServerJwtToken({'userId': 'u'},
              expiresIn: const Duration(hours: 2))
          .getJWT('tom');
      TomClientJwtToken? zoneToken;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneToken = getFromCurrentZone<TomClientJwtToken>();
        return Response.ok('ok');
      });
      await handler(_get({'authorization': 'Bearer $jwt'}));
      expect(zoneToken, isNotNull);
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
      expect(identical(server.authenticationErrorHandler, server.errorHandler),
          isTrue);
    });

    test('honours a configuration-supplied loggingMiddleware', () {
      final custom = tomLoggingMiddleware();
      final config = _NoopConfig()..loggingMiddleware = custom;
      final server = TomServer(config);
      expect(identical(server.loggingMiddleware, custom), isTrue);
    });
  });

  // Pins the default error-mapping contract documented on TomServer.errorHandler
  // (tests §44): every thrown error becomes an HTTP-500 JSON response carrying
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
    Future<({int status, Map<String, String> headers, Map<String, dynamic> body})>
        map(Object error) async {
      final response = server.errorHandler(_get(), error, StackTrace.current);
      expect(response, isNotNull, reason: 'the default handler always responds');
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
      final error = TomException('USER_NOT_FOUND', 'no such user');
      final result = await map(error);
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorType'], 'TomException');
      expect(result.body['errorKey'], 'USER_NOT_FOUND');
      expect(result.body['uuid'], error.uuid);
      expect(result.body['autoLog'], isFalse);
      expect(result.body['requestUuid'], isNull);
      // Not a server exception -> no clientThrow.
      expect(result.body.containsKey('clientThrow'), isFalse);
    });

    test('a TomServerException additionally adds clientThrow', () async {
      final error =
          TomServerException('db.fail', 'query failed', clientThrow: false);
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
  });
}
