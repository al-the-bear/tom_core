/// Two versions of one API served side by side, and the error format a caller
/// receives: the framework envelope, or an RFC 9457 problem document when it
/// asks for one or the API always answers one.
///
/// The fixtures are `FixtureOrdersV1` (`@TomService(version: 1)`) and
/// `FixtureOrdersV2` (`@TomService(version: 2, problemJson: true)`), both
/// declaring `/fixture/orders`.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  setUpAll(() {
    initializeReflection();
    // The router mounts every scanned service, the fixture's registry-backed
    // one among them, whose API must be registered first.
    registerFixtureAccessApi();
  });

  late Handler handler;

  setUp(() {
    TomBean.resetBeanContext();
    final router = TomEndpointRouting().initializeRouter();
    handler = const Pipeline()
        .addMiddleware(
          contextSetupMiddleware('api versioning test', {
            TomRequestLogInfo.contextName: TomRequestLogInfo(),
          }),
        )
        .addMiddleware(tomDefaultAuthenticationMiddleware('api versioning'))
        .addHandler(router.call);
  });
  tearDown(TomBean.resetBeanContext);

  Future<(Response, Map<String, Object?>)> get(
    String path, {
    String? accept,
  }) async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: {'accept': ?accept},
      ),
    );
    final text = await response.readAsString();
    // The router's own 404 for an unmounted path is plain text.
    final json = (response.headers['content-type'] ?? '').contains('json');
    return (
      response,
      json ? jsonDecode(text) as Map<String, Object?> : <String, Object?>{},
    );
  }

  group('two versions of one endpoint', () {
    test('are served side by side under their version segments', () async {
      final (v1, one) = await get('/v1/fixture/orders');
      final (v2, two) = await get('/v2/fixture/orders');
      expect(v1.statusCode, 200);
      expect(one, {
        'version': 1,
        'orders': ['A-1'],
      });
      expect(v2.statusCode, 200);
      expect(two['version'], 2);
      expect(two['items'], [
        {'id': 'A-1'},
      ]);
    });

    test('and only there: the unversioned path is not mounted', () async {
      final (response, _) = await get('/fixture/orders');
      expect(response.statusCode, 404);
      final routes = TomEndpointRouting.routingInfo.keys
          // GET only: another fixture places orders by an unversioned POST.
          .where(
            (route) =>
                route.method == TomHttpMethod.get.name &&
                route.uri.endsWith('/fixture/orders'),
          )
          .map((route) => route.uri)
          .toSet();
      expect(routes, {'/v1/fixture/orders', '/v2/fixture/orders'});
    });
  });

  group('an endpoint error', () {
    test('is the envelope when the caller does not ask', () async {
      for (final accept in [null, 'application/json', '*/*', 'application/*']) {
        final (response, body) = await get(
          '/v1/fixture/orders/failing',
          accept: accept,
        );
        expect(response.statusCode, 500, reason: '$accept');
        expect(response.headers['content-type'], contains('application/json'));
        expect(response.headers['x-tom-error'], 'true');
        expect(body['errorKey'], 'fixture.orders.failed');
        expect(body.keys, isNot(contains('type')), reason: '$accept');
      }
    });

    test('is a problem document when the caller asks for one', () async {
      for (final accept in [
        'application/problem+json',
        'application/json;q=0.5, application/problem+json',
        'APPLICATION/PROBLEM+JSON; q=0.9',
      ]) {
        final (response, body) = await get(
          '/v1/fixture/orders/failing',
          accept: accept,
        );
        expect(response.statusCode, 500, reason: accept);
        expect(response.headers['content-type'], tomProblemJsonMediaType);
        expect(response.headers['x-tom-error'], 'true');
        expect(body['type'], 'urn:tom:error:fixture.orders.failed');
        expect(body['title'], 'Internal Server Error');
        expect(body['status'], 500);
        expect(body['instance'], startsWith('urn:tom:request:'));
        // The envelope's fields, as extension members.
        expect(body['errorKey'], 'fixture.orders.failed');
        expect(body['clientThrow'], isTrue);
        expect(body['errorType'], 'TomServerException');
        // No message, in either format.
        expect(body.keys, isNot(contains('detail')));
      }
    });

    test('is not a problem document when its quality is zero', () async {
      final (response, body) = await get(
        '/v1/fixture/orders/failing',
        accept: 'application/problem+json;q=0, application/json',
      );
      expect(response.headers['content-type'], contains('application/json'));
      expect(body.keys, isNot(contains('type')));
    });

    test(
      'of an API declared problemJson is always a problem document',
      () async {
        final (response, body) = await get('/v2/fixture/orders/failing');
        expect(response.statusCode, 500);
        expect(response.headers['content-type'], tomProblemJsonMediaType);
        expect(body['type'], 'urn:tom:error:fixture.orders.failed');
        // The successful answers of that API are unchanged.
        final (ok, _) = await get('/v2/fixture/orders');
        expect(ok.headers['content-type'], contains('application/json'));
      },
    );
  });

  group('tomProblemDetails', () {
    test('is about:blank for an error without a key, with no instance', () {
      final problem = tomProblemDetails(StateError('boom'), 503);
      expect(problem, {
        'type': 'about:blank',
        'title': 'Service Unavailable',
        'status': 503,
        'errorType': 'StateError',
      });
    });

    test('names an unregistered status Error', () {
      expect(tomReasonPhrase(599), 'Error');
      expect(tomReasonPhrase(404), 'Not Found');
    });

    test('tomErrorResponse keeps the headers it is given', () {
      final response = tomErrorResponse(
        TomServerException('k.e.y', 'm', clientThrow: true),
        status: 429,
        request: Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: {'accept': 'application/problem+json'},
        ),
        headers: {'Retry-After': '7'},
      );
      expect(response.statusCode, 429);
      expect(response.headers['retry-after'], '7');
      expect(response.headers['content-type'], tomProblemJsonMediaType);
    });
  });

  test(
    'a service version places inline routes under /v<n>, and must be 1+',
    () {
      expect(
        TomEndpointRouting.versionedUri('/orders', const TomService(), 'S'),
        '/orders',
      );
      expect(TomEndpointRouting.versionedUri('/orders', null, 'S'), '/orders');
      expect(
        TomEndpointRouting.versionedUri(
          '/orders',
          const TomService(version: 3),
          'S',
        ),
        '/v3/orders',
      );
      for (final bad in [0, -1]) {
        expect(
          () => TomEndpointRouting.versionedUri(
            '/orders',
            TomService(version: bad),
            'BadService',
          ),
          throwsA(
            isA<TomEndpointPipelineException>().having(
              (e) => e.key,
              'key',
              'endpoint_pipeline.get_class_method_metadata.invalid_api_version',
            ),
          ),
        );
      }
    },
  );

  test('TomEndpoint.withUri moves an endpoint and keeps the rest', () {
    const endpoint = TomEndpoint<Object, Object>(
      methods: [TomHttpMethod.post],
      uri: '/orders',
      produces: TomMimeType.json,
      headers: {'x-a': 'b'},
      urlParameterMapping: {'id': 'orderId'},
    );
    final moved = endpoint.withUri('/v3/orders');
    expect(moved.uri, '/v3/orders');
    expect(moved.methods, endpoint.methods);
    expect(moved.headers, endpoint.headers);
    expect(moved.urlParameterMapping, endpoint.urlParameterMapping);
    expect(moved.errorHandler, same(endpoint.errorHandler));
  });
}
