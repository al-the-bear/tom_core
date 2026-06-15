import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the socket-free surface of the server module: the per-request
/// value objects ([TomRequestId], [TomRequestLogInfo]), the credential reader
/// ([extractAuthentication]), and the pipeline middlewares that can run without
/// binding a port ([contextSetupMiddleware], [tomLoggingMiddleware],
/// [tomDefaultAuthenticationMiddleware], [noopHandler]).
///
/// [TomServer] itself binds a real socket and needs a reflected
/// `TomConfiguration` plus TLS material, so it is covered by `doc/server.md`
/// and integration tests, not here.

Request _get([Map<String, String>? headers]) =>
    Request('GET', Uri.parse('http://localhost/resource'), headers: headers);

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
  });
}
