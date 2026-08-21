import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds a request carrying [params] as shelf_router path captures, the way a
/// matched route exposes them via `Request.params`.
Request _reqWithParams(Map<String, String> params) => Request(
  'GET',
  Uri.parse('http://localhost/items/42'),
  context: {'shelf_router/params': params},
);

/// Tests for the reflection-free surface of the endpoints module.
///
/// The router builder ([TomEndpointRouting]) and per-request handler
/// ([TomEndpointHandler]) reflect over annotated service classes and serve live
/// HTTP requests, so they need a running server and generated reflection — they
/// are covered by `doc/endpoints.md` and integration tests, not here. This suite
/// pins the annotation surface a developer touches at declaration time and the
/// default error handler's response.
Request _req() => Request('POST', Uri.parse('http://localhost/greet'));

/// A distinguishable [TomErrorHandler] so tests can assert *which* handler an
/// endpoint resolved to (by identity) rather than just its response.
class _StubErrorHandler extends TomErrorHandler {
  _StubErrorHandler();

  @override
  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) => Response.internalServerError(body: 'stub');
}

void main() {
  group('TomEndpoint', () {
    test('uses JSON GET defaults', () {
      const endpoint = TomEndpoint();
      expect(endpoint.uri, '');
      expect(endpoint.methods, [TomHttpMethod.get]);
      expect(endpoint.consumes, TomMimeType.json);
      expect(endpoint.produces, TomMimeType.json);
      expect(endpoint.formFields, isEmpty);
      expect(endpoint.headers, isEmpty);
    });

    test('carries the declared route and methods', () {
      const endpoint = TomEndpoint(
        uri: '/greet',
        methods: [TomHttpMethod.post, TomHttpMethod.put],
      );
      expect(endpoint.uri, '/greet');
      expect(endpoint.methods, hasLength(2));
    });

    test('convertToTomEndpoint returns itself', () {
      const endpoint = TomEndpoint(uri: '/x');
      expect(identical(endpoint.convertToTomEndpoint(), endpoint), isTrue);
    });
  });

  group('TomApiEndpointImplementation', () {
    test('binds an api/endpoint id with overrides', () {
      const impl = TomApiEndpointImplementation(
        apiId: 'orders',
        endpointId: 'create',
        logRequests: true,
        corsAllowedOrigins: 'https://example.com',
      );
      expect(impl.apiId, 'orders');
      expect(impl.endpointId, 'create');
      expect(impl.logRequests, isTrue);
      expect(impl.corsAllowedOrigins, 'https://example.com');
    });
  });

  // A registry endpoint must inherit the class-level
  // @TomApiImplementation's API-wide errorHandler / logRequestsDefault for any
  // value it does not itself override. convertToTomEndpoint resolves the route
  // from tomRemoteApis (no reflection needed), so the merge is unit-testable.
  group('TomApiEndpointImplementation.convertToTomEndpoint merge', () {
    late TomErrorHandler apiHandler;
    late TomErrorHandler endpointHandler;

    setUp(() {
      apiHandler = _StubErrorHandler();
      endpointHandler = _StubErrorHandler();
      tomRemoteApis['orders'] = TomApi(
        id: 'orders',
        uri: '/api/orders',
        endpoints: [
          TomApiEndpoint<Object, Object>(
            id: 'create',
            uri: '/create',
            method: TomHttpMethod.post,
          ),
        ],
      );
    });

    tearDown(() => tomRemoteApis.apis.remove('orders'));

    test('inherits the API-wide errorHandler and logRequestsDefault when the '
        'endpoint overrides neither', () {
      const impl = TomApiEndpointImplementation(
        apiId: 'orders',
        endpointId: 'create',
      );
      final api = TomApiImplementation(
        apiId: 'orders',
        errorHandler: apiHandler,
        logRequestsDefault: false,
      );
      final endpoint = impl.convertToTomEndpoint(api);
      // Without the merge the class-level values are inert: errorHandler falls
      // straight through to TomDefaultErrorHandler and logRequests stays null.
      expect(identical(endpoint.errorHandler, apiHandler), isTrue);
      expect(endpoint.logRequests, isFalse);
    });

    test('the endpoint-level override wins over the API-wide handler', () {
      final impl = TomApiEndpointImplementation(
        apiId: 'orders',
        endpointId: 'create',
        errorHandler: endpointHandler,
        logRequests: true,
      );
      final api = TomApiImplementation(
        apiId: 'orders',
        errorHandler: apiHandler,
        logRequestsDefault: false,
      );
      final endpoint = impl.convertToTomEndpoint(api);
      expect(identical(endpoint.errorHandler, endpointHandler), isTrue);
      expect(endpoint.logRequests, isTrue);
    });

    test(
      'falls back to the default handler when neither level provides one',
      () {
        const impl = TomApiEndpointImplementation(
          apiId: 'orders',
          endpointId: 'create',
        );
        final endpoint = impl.convertToTomEndpoint(null);
        expect(endpoint.errorHandler, isA<TomDefaultErrorHandler>());
        expect(endpoint.logRequests, isNull);
      },
    );

    test('without an apiImplementation, logRequests stays null so the global '
        'default applies', () {
      const impl = TomApiEndpointImplementation(
        apiId: 'orders',
        endpointId: 'create',
      );
      final endpoint = impl.convertToTomEndpoint();
      expect(endpoint.logRequests, isNull);
    });
  });

  // The per-request pipeline (TomEndpointHandler.handleMethodCall: parameter
  // binding, access-control gating, transaction wrap/commit/rollback,
  // invocation/conversion error routing) and router assembly
  // (TomEndpointRouting.initializeRouter / scanClasses / createRoutesForEndpoint
  // and their TomEndpointPipelineException paths) are deferred: every entry
  // point needs a TomEndpointHandler, which requires real InstanceMirror /
  // MethodMirror / ClassMirror for an annotated fixture service. This suite does
  // not bootstrap generated reflection (constructing those mirrors throws
  // "Reflection has not been initialized"), so those paths belong to an
  // integration test with a reflected fixture — as the suite header already
  // documents.

  group('class-level annotations', () {
    test('TomApiImplementation defaults to logging requests', () {
      const impl = TomApiImplementation(apiId: 'orders');
      expect(impl.apiId, 'orders');
      expect(impl.logRequestsDefault, isTrue);
      expect(impl.errorHandler, isNull);
    });

    test('TomApiImplementation is a TomService', () {
      const impl = TomApiImplementation(apiId: 'orders');
      expect(impl, isA<TomService>());
    });

    test('TomComponentReference holds a name or a type', () {
      const byName = TomComponentReference(componentName: 'orderService');
      const byType = TomComponentReference(referencedType: int);
      expect(byName.componentName, 'orderService');
      expect(byName.referencedType, isNull);
      expect(byType.referencedType, int);
      expect(byType.componentName, isNull);
    });
  });

  group('TomTransactional', () {
    test('defaults to a read-write transaction', () {
      const tx = TomTransactional();
      expect(tx.isTransactional, isTrue);
      expect(tx.isReadOnly, isFalse);
    });

    test('can be marked read-only', () {
      const tx = TomTransactional(isReadOnly: true);
      expect(tx.isReadOnly, isTrue);
    });
  });

  group('TomDefaultErrorHandler', () {
    const handler = TomDefaultErrorHandler();
    final st = StackTrace.current;

    test('handleInvocationError returns an opaque 500', () {
      final r = handler.handleInvocationError(StateError('boom'), st, _req());
      expect(r.statusCode, 500);
    });

    test('handleConversionError returns an opaque 500', () {
      final r = handler.handleConversionError(
        StateError('boom'),
        st,
        _req(),
        'result',
      );
      expect(r.statusCode, 500);
    });

    test('handleUnknowResultTypeError returns an opaque 500', () {
      final r = handler.handleUnknowResultTypeError(
        StateError('boom'),
        st,
        _req(),
        42,
      );
      expect(r.statusCode, 500);
    });
  });

  group('routing metadata types', () {
    test('TomClassScanResult defaults to empty partitions', () {
      final scan = TomClassScanResult();
      expect(scan.serviceInterfaces, isEmpty);
      expect(scan.apiImplementations, isEmpty);
      expect(scan.componentClasses, isEmpty);
    });
  });

  // Cross-tier routing: shelf_router's RouterEntry parser recognises
  // only `<param>` placeholders; a `{param}` template is RegExp.escaped to a
  // literal path segment and never matches a real id, so the route 404s. The
  // registry declares URIs with `{name}`, so the router builder translates them
  // to `<name>` before handing them to shelf. `shelfRoutePath` owns that
  // translation and is pure, so it is unit-testable without a live router.
  group('TomEndpointRouting.shelfRoutePath', () {
    test('translates a single {name} placeholder to <name>', () {
      expect(
        TomEndpointRouting.shelfRoutePath('/items/{id}/field-states'),
        '/items/<id>/field-states',
      );
    });

    test('translates every placeholder in a multi-variable route', () {
      expect(
        TomEndpointRouting.shelfRoutePath('/users/{userId}/items/{itemId}'),
        '/users/<userId>/items/<itemId>',
      );
    });

    test('passes a route with no placeholders through unchanged', () {
      expect(TomEndpointRouting.shelfRoutePath('/health'), '/health');
    });

    test('leaves an already-shelf-style <name> route unchanged', () {
      expect(TomEndpointRouting.shelfRoutePath('/items/<id>'), '/items/<id>');
    });
  });

  // Cross-tier routing: a method whose parameter is a bare primitive
  // (e.g. `String id` / `int id`) is bound from the URL — either a shelf-matched
  // `<name>` path capture (exposed as a String in Request.params) or, for a
  // route like `GET /projects?workspaceId=`, a query-string value of the same
  // name. coercePrimitiveParameter owns that String→primitive coercion and
  // returns null for anything it cannot bind (so the pipeline falls through to
  // its other binding strategies).
  group('TomEndpointHandler.coercePrimitiveParameter', () {
    test('returns the raw value for a String parameter', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(String, '42'), '42');
    });

    test('parses an int parameter', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(int, '42'), 42);
    });

    test('parses a double parameter', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(double, '3.5'), 3.5);
    });

    test('parses a num parameter', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(num, '7'), 7);
    });

    test('maps a bool parameter ("true" only)', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(bool, 'true'), isTrue);
      expect(
        TomEndpointHandler.coercePrimitiveParameter(bool, 'false'),
        isFalse,
      );
    });

    test('returns null for an unparsable numeric value', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(int, 'abc'), isNull);
    });

    test('returns null for a non-primitive parameter type', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(Request, '1'), isNull);
    });
  });

  // G-API-2 / rework step 1: URL path parameters (`/items/{id}`) are bound to
  // typed request-DTO fields via `urlParameterMapping` on the endpoint. This
  // group covers the annotation surface only — that the mapping is declarable
  // and survives the conversion into a TomEndpoint. The group below covers the
  // pipeline side, where the mapping is actually applied.
  group('urlParameterMapping', () {
    test('TomEndpoint defaults to an empty mapping', () {
      const endpoint = TomEndpoint();
      expect(endpoint.urlParameterMapping, isEmpty);
    });

    test('TomApiEndpoint defaults to an empty mapping', () {
      final endpoint = TomApiEndpoint<Object, Object>(
        id: 'get',
        uri: '/items/{id}',
        method: TomHttpMethod.get,
      );
      expect(endpoint.urlParameterMapping, isEmpty);
    });

    test('TomApiEndpoint carries the declared mapping', () {
      final endpoint = TomApiEndpoint<Object, Object>(
        id: 'get',
        uri: '/items/{id}',
        method: TomHttpMethod.get,
        urlParameterMapping: const {'id': 'itemId'},
      );
      expect(endpoint.urlParameterMapping, {'id': 'itemId'});
    });

    test(
      'convertToTomEndpoint carries the mapping from the registry entry',
      () {
        tomRemoteApis['catalog'] = TomApi(
          id: 'catalog',
          uri: '/api/catalog',
          endpoints: [
            TomApiEndpoint<Object, Object>(
              id: 'getItem',
              uri: '/items/{id}',
              method: TomHttpMethod.get,
              urlParameterMapping: const {'id': 'itemId'},
            ),
          ],
        );
        addTearDown(() => tomRemoteApis.apis.remove('catalog'));

        const impl = TomApiEndpointImplementation(
          apiId: 'catalog',
          endpointId: 'getItem',
        );
        final endpoint = impl.convertToTomEndpoint();
        expect(endpoint.urlParameterMapping, {'id': 'itemId'});
      },
    );
  });

  // The other half of G-API-2: the group above pins that the annotation
  // *carries* the mapping; this one pins that the pipeline *applies* it. The
  // two behaviours that carry real risk are the rename (capture name ≠ field
  // name) and the identity fallback (capture absent from the mapping) — a
  // regression in either surfaces as a confusing DTO-instantiation failure
  // several layers away, and only against a live database.
  group('TomEndpointHandler.injectPathParameters', () {
    test('binds a path capture to the same-named DTO field (identity)', () {
      // `/items/{id}` with no mapping → `request.id`, no bare-String param.
      const endpoint = TomEndpoint(uri: '/items/{id}');
      final json = <String, dynamic>{};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({'id': '42'}),
        endpoint,
      );
      expect(json, {'id': '42'});
    });

    test('renames a path capture to the mapped DTO field name', () {
      // `/items/{id}` with `{'id': 'itemId'}` → `request.itemId`.
      const endpoint = TomEndpoint(
        uri: '/items/{id}',
        urlParameterMapping: {'id': 'itemId'},
      );
      final json = <String, dynamic>{};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({'id': '42'}),
        endpoint,
      );
      expect(json, {'itemId': '42'});
    });

    test('folds path captures alongside an existing JSON body', () {
      const endpoint = TomEndpoint(
        uri: '/users/{userId}/items/{itemId}',
        urlParameterMapping: {'itemId': 'id'},
      );
      final json = <String, dynamic>{'title': 'Buy milk'};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({'userId': '7', 'itemId': '42'}),
        endpoint,
      );
      // Mapped capture renamed, unmapped capture keeps its name, body preserved.
      expect(json, {'title': 'Buy milk', 'userId': '7', 'id': '42'});
    });

    test('a path capture overrides a same-named body field', () {
      const endpoint = TomEndpoint(uri: '/items/{id}');
      final json = <String, dynamic>{'id': 'from-body'};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({'id': 'from-path'}),
        endpoint,
      );
      // Precedence pinned deliberately: the URL is the addressed resource, so a
      // body that disagrees with it does not get to redirect the call to a
      // different row. The fold writes unconditionally, and that is the
      // contract — not an accident of ordering.
      expect(json['id'], 'from-path');
    });

    test('a mapped capture overrides the body value under the mapped name', () {
      const endpoint = TomEndpoint(
        uri: '/items/{key}',
        urlParameterMapping: {'key': 'id'},
      );
      final json = <String, dynamic>{'id': 'from-body'};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({'key': 'from-path'}),
        endpoint,
      );
      // Same precedence, reached through the rename — the collision is with the
      // *mapped* name, which is the one a body could plausibly also carry.
      expect(json, {'id': 'from-path'});
    });

    test('leaves the map unchanged when there are no path captures', () {
      const endpoint = TomEndpoint(uri: '/items');
      final json = <String, dynamic>{'title': 'x'};
      TomEndpointHandler.injectPathParameters(
        json,
        _reqWithParams({}),
        endpoint,
      );
      expect(json, {'title': 'x'});
    });

    test('leaves the map unchanged when the request carries no params key', () {
      const endpoint = TomEndpoint(
        uri: '/items',
        urlParameterMapping: {'key': 'id'},
      );
      final json = <String, dynamic>{'title': 'x'};
      TomEndpointHandler.injectPathParameters(
        json,
        // No `shelf_router/params` context entry at all — a distinct branch of
        // shelf_router's `Request.params` from the empty-map case above, and
        // the shape a request has when it never passed through a Router.
        Request('POST', Uri.parse('http://localhost/items')),
        endpoint,
      );
      // A declared mapping must not manufacture a null field the DTO would then
      // have to tolerate.
      expect(json, {'title': 'x'});
    });
  });

  group('exception types', () {
    test('TomEndpointHandlerException is a TomServerException', () {
      final ex = TomEndpointHandlerException('key', 'message');
      expect(ex, isA<TomServerException>());
      expect(ex.key, 'key');
    });

    test('TomEndpointPipelineException is a TomServerException', () {
      final ex = TomEndpointPipelineException('key', 'message');
      expect(ex, isA<TomServerException>());
      expect(ex.key, 'key');
    });
  });
}
