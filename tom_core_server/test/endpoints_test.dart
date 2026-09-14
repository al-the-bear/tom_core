import 'dart:io';

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

/// Builds a request for [uri], whose *query string* is what
/// [TomEndpointHandler.injectQueryParameters] reads, optionally carrying
/// [params] as shelf_router path captures so the two URL folds can be observed
/// against one request.
Request _reqWithQuery(String uri, {Map<String, String> params = const {}}) =>
    Request('GET', Uri.parse(uri), context: {'shelf_router/params': params});

/// Tests for the reflection-free surface of the endpoints module: the
/// annotation surface a developer touches at declaration time, and the default
/// error handler's response.
///
/// The router builder ([TomEndpointRouting]) and the per-request handler
/// ([TomEndpointHandler]) are asserted in `test/endpoints_pipeline_test.dart`,
/// which builds a router over a reflected fixture and serves requests through
/// it — among others by the groups `TomEndpointRouting.scanClasses`,
/// `initializeRouter + live requests`, `TomEndpointHandler access checks`,
/// `routingInfo is keyed by route and method` and
/// `binding preserves argument positions`.
///
/// The split is generated reflection, not a socket. That suite calls
/// `initializeReflection()` in its setup, which is what makes a `ClassMirror`
/// constructible and so what makes a router buildable at all; it binds no port
/// and needs no database. Keeping the reflection-free surface here means this
/// file stays runnable when the generated fixture is mid-regeneration.
///
/// Named by group rather than by line number on purpose: this pointer has to
/// survive the file it points into being edited.
Request _req() => Request('POST', Uri.parse('http://localhost/greet'));

/// Collects what the framework logged, so a test can assert on a diagnostic
/// that has no other observable effect — which is exactly what the unmapped
/// query parameter's debug line is.
///
/// Every level is kept: [TomLogger] hands the output its own configured level
/// and leaves the filtering to it, so filtering here would silently drop the
/// message whenever the suite ran at a quieter level.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> lines = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => lines.add(convertToString(message));
}

/// Captures log output for the duration of the calling test.
List<String> _captureLog() {
  final previousOutput = tomLog.logOutput;
  final captured = _CapturingLogOutput();
  tomLog.logOutput = captured;
  addTearDown(() => tomLog.logOutput = previousOutput);
  return captured.lines;
}

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
            // Both directions, distinguishable by value: an entry declaring one
            // of them cannot show which one the conversion picked up.
            requestHeaders: const {'x-client-sends': 'request'},
            responseHeaders: const {'x-server-answers': 'response'},
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

    // TomEndpoint.headers is the *response* direction — the pipeline copies it
    // onto every response it builds — and the contract states both directions
    // separately. Taking the wrong one does not fail loudly: it re-emits a
    // caller's obligations back at the caller, which reads like a deliberate
    // echo rather than a bug.
    test(
      'the contract responseHeaders become the endpoint response headers',
      () {
        const impl = TomApiEndpointImplementation(
          apiId: 'orders',
          endpointId: 'create',
        );
        final endpoint = impl.convertToTomEndpoint();
        expect(endpoint.headers, {'x-server-answers': 'response'});
      },
    );

    test('the contract requestHeaders reach nothing on the server', () {
      const impl = TomApiEndpointImplementation(
        apiId: 'orders',
        endpointId: 'create',
      );
      final endpoint = impl.convertToTomEndpoint();
      // requestHeaders instruct a *client* (TomServerConnection reads them when
      // it calls the endpoint); the served endpoint has no field for them, and
      // the header the client was told to send is not one to send back.
      expect(endpoint.headers.keys, isNot(contains('x-client-sends')));
      expect(endpoint.headers.values, isNot(contains('request')));
    });
  });

  // The per-request pipeline (TomEndpointHandler.handleMethodCall: parameter
  // binding, access-control gating, transaction wrap/commit/rollback,
  // invocation/conversion error routing) and router assembly
  // (TomEndpointRouting.initializeRouter / scanClasses / createRoutesForEndpoint
  // and their TomEndpointPipelineException paths) are not here, because every
  // entry point needs a TomEndpointHandler and that needs real InstanceMirror /
  // MethodMirror / ClassMirror for an annotated fixture service. This suite does
  // not bootstrap generated reflection — constructing those mirrors throws
  // "Reflection has not been initialized" — so they are asserted in
  // endpoints_pipeline_test.dart, which does, over the reflected fixture. The
  // header names the groups.

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

    // A bool was `raw == 'true'`, which is total: every other spelling produced
    // `false`, so `?active=TRUE` meant the opposite of what the caller wrote and
    // nothing could notice. It is the one primitive whose failure was invisible
    // — a number at least answers `null` for nonsense — so the accepted
    // spellings are a closed set and everything else is a refusal.
    test('accepts four spellings of true, in any case', () {
      for (final raw in const [
        'true',
        'TRUE',
        'True',
        '1',
        'yes',
        'YES',
        'on',
        'On',
      ]) {
        expect(
          TomEndpointHandler.coercePrimitiveParameter(bool, raw),
          isTrue,
          reason: '"$raw" is a spelling of true',
        );
      }
    });

    test('accepts four spellings of false, in any case', () {
      for (final raw in const [
        'false',
        'FALSE',
        'False',
        '0',
        'no',
        'NO',
        'off',
        'Off',
      ]) {
        expect(
          TomEndpointHandler.coercePrimitiveParameter(bool, raw),
          isFalse,
          reason: '"$raw" is a spelling of false',
        );
      }
    });

    test('an unrecognised spelling is null, not false', () {
      // The whole point of the change. `false` is an answer and `null` is a
      // refusal, and the two must not be the same value — under the old rule
      // every one of these bound as `false`.
      for (final raw in const ['maybe', 'y', 'n', 't', 'f', '2', '-1', '']) {
        expect(
          TomEndpointHandler.coercePrimitiveParameter(bool, raw),
          isNull,
          reason: '"$raw" is no spelling of either, so it cannot bind',
        );
      }
    });

    test('the true and false spellings do not overlap', () {
      // A spelling in both sets would resolve by whichever is tested first,
      // which is an ordering nothing else in this file depends on.
      const trues = ['true', '1', 'yes', 'on'];
      const falses = ['false', '0', 'no', 'off'];
      for (final raw in trues) {
        expect(falses, isNot(contains(raw)));
      }
      expect(trues.toSet(), hasLength(trues.length));
      expect(falses.toSet(), hasLength(falses.length));
    });

    test('returns null for an unparsable numeric value', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(int, 'abc'), isNull);
      expect(
        TomEndpointHandler.coercePrimitiveParameter(double, 'abc'),
        isNull,
      );
      expect(TomEndpointHandler.coercePrimitiveParameter(num, 'abc'), isNull);
    });

    test('returns null for a non-primitive parameter type', () {
      expect(TomEndpointHandler.coercePrimitiveParameter(Request, '1'), isNull);
    });
  });

  // The two `null`s above are different answers, and the method's return type
  // cannot say which: a `Request` parameter is not a primitive at all and the
  // binding loop should try the next strategy, while `?count=abc` on an `int`
  // is a client error that no later strategy can repair. Asked first, this
  // predicate separates them — past it, a `null` means the value did not parse.
  group('TomEndpointHandler.isBindablePrimitive', () {
    test('every type the coercion handles is bindable', () {
      for (final type in const [String, int, double, num, bool]) {
        expect(
          TomEndpointHandler.isBindablePrimitive(type),
          isTrue,
          reason: '$type is coerced, so it must be recognised',
        );
      }
    });

    test('anything else is not', () {
      for (final type in const [Request, Object, DateTime, Uri, List, Map]) {
        expect(
          TomEndpointHandler.isBindablePrimitive(type),
          isFalse,
          reason: '$type has no URL coercion, so the loop must fall through',
        );
      }
    });

    test('the predicate and the coercion agree on every type', () {
      // The pair is only honest while they cover the same set: a type the
      // predicate accepts and the coercion does not would make every request
      // carrying it a 400, and a type the coercion handles and the predicate
      // rejects would go on falling through silently.
      for (final type in const [String, int, double, num, bool]) {
        // '1' parses as every one of them, so a null here would mean the
        // coercion does not know the type at all.
        expect(
          TomEndpointHandler.coercePrimitiveParameter(type, '1'),
          isNotNull,
          reason: '$type is bindable but the coercion returned null',
        );
      }
      for (final type in const [Request, Object, DateTime, Uri]) {
        expect(
          TomEndpointHandler.coercePrimitiveParameter(type, '1'),
          isNull,
          reason: '$type is not bindable but the coercion answered',
        );
      }
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

  // The query half of the same mapping, and the asymmetry that makes it a
  // separate helper rather than a second call to the one above: a path capture
  // binds with or without an entry, a query parameter binds *only* with one.
  // What differs is whose statement the value is. A route is the endpoint's own
  // declaration, so binding a capture by its own name is safe; a query string is
  // whatever a caller chose to append, so an identity fallback here would let
  // any caller write any field of the request DTO of any endpoint.
  //
  // That asymmetry is also the module's most mistakable behaviour: an endpoint
  // that declares no mapping drops the whole query string, and the author sees
  // a DTO with a missing value — or, if nothing else binds, an argument-count
  // failure naming neither the parameter nor the query string. It is pinned
  // here as a decision rather than left to be rediscovered, and the drop is
  // announced at debug so it can be found rather than deduced.
  group('TomEndpointHandler.injectQueryParameters', () {
    test('binds a mapped query parameter under its DTO field name', () {
      const endpoint = TomEndpoint(
        uri: '/callback',
        urlParameterMapping: {
          'code': 'code',
          'error_description': 'errorDescription',
        },
      );
      final json = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery(
          'http://localhost/callback?code=abc&error_description=nope',
        ),
        endpoint,
      );
      // The rename is the point: a provider's snake_cased spelling stops at the
      // contract, and the DTO is written in Dart.
      expect(json, {'code': 'abc', 'errorDescription': 'nope'});
    });

    test('an endpoint that declares no mapping binds nothing', () {
      const endpoint = TomEndpoint(uri: '/callback');
      final json = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback?code=abc&state=xyz'),
        endpoint,
      );
      // The drop, stated outright. There is no identity fallback to fall back
      // to, so an unmapped endpoint is closed to the query string entirely. It
      // is no longer silent — see the `an unmapped parameter is reported at
      // debug` group below.
      expect(json, isEmpty);
    });

    test('a query parameter the mapping does not name is dropped', () {
      const endpoint = TomEndpoint(
        uri: '/callback',
        urlParameterMapping: {'code': 'code'},
      );
      final json = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback?code=abc&isAdmin=true'),
        endpoint,
      );
      // Per parameter, not per endpoint: naming one does not open the rest.
      // `isAdmin` is the shape of the risk — a field the DTO really has, which
      // no caller was invited to set.
      expect(json, {'code': 'abc'});
    });

    test('a declared mapping binds nothing when there is no query string', () {
      const endpoint = TomEndpoint(
        uri: '/callback',
        urlParameterMapping: {'code': 'code'},
      );
      final json = <String, dynamic>{'title': 'x'};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback'),
        endpoint,
      );
      // Same rule the path fold follows: a declared mapping must not
      // manufacture a null field the DTO would then have to tolerate.
      expect(json, {'title': 'x'});
    });

    test('a mapped parameter the caller omitted is not manufactured', () {
      const endpoint = TomEndpoint(
        uri: '/callback',
        urlParameterMapping: {
          'code': 'code',
          'error_description': 'errorDescription',
        },
      );
      final json = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback?code=abc'),
        endpoint,
      );
      // The same rule as the case above, but reached past both early returns —
      // the mapping is declared *and* the query string is non-empty, so the
      // per-parameter null guard is the only thing standing between the DTO and
      // an `errorDescription: null` it never asked for. This is the ordinary
      // shape of a successful callback: the error half of the contract is
      // mapped and simply did not arrive.
      expect(json, {'code': 'abc'});
    });

    test('a query parameter overrides a same-named body field', () {
      const endpoint = TomEndpoint(
        uri: '/callback',
        urlParameterMapping: {'code': 'code'},
      );
      final json = <String, dynamic>{'code': 'from-body'};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback?code=from-query'),
        endpoint,
      );
      // The fold writes unconditionally, and the pipeline runs it *after*
      // injectFormFields — so the URL wins over the body here for the same
      // reason it wins in injectPathParameters. Pinning the write, not just the
      // order: a `putIfAbsent` here would reverse the precedence with every
      // existing ordering test still green.
      expect(json, {'code': 'from-query'});
    });

    test('a path capture overrides a query parameter of the same name', () {
      const endpoint = TomEndpoint(
        uri: '/items/{id}',
        urlParameterMapping: {'id': 'id'},
      );
      final json = <String, dynamic>{};
      final req = _reqWithQuery(
        'http://localhost/items/7?id=99',
        params: {'id': '7'},
      );
      // Folded in the pipeline's order. Both helpers write unconditionally, so
      // the order is the whole of the precedence — the route is the addressed
      // resource, and a query parameter cannot redirect the call to another row.
      TomEndpointHandler.injectQueryParameters(json, req, endpoint);
      TomEndpointHandler.injectPathParameters(json, req, endpoint);
      expect(json, {'id': '7'});
    });
  });

  // The drop is the opt-in working as designed; the silence was a separate
  // choice, and the expensive one. A client sending `?status=open` to an
  // endpoint that never mapped `status` gets a 200 computed as though it had
  // not been sent — the author sees a working request and the caller sees an
  // ignored filter, and nothing anywhere connects the two. Debug is the level
  // the decision names: findable by someone who goes looking, without failing a
  // request or filling an ordinary log with the tracking parameters every
  // public URL collects.
  group('an unmapped query parameter is reported at debug', () {
    test('an endpoint that mapped nothing still reports what it dropped', () {
      // The commonest form of the mistake, and the one an early return on
      // `mapping.isEmpty` used to hide: there is nothing to fold, so the fold
      // had nothing to say.
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/tasks?status=open'),
        const TomEndpoint(uri: '/tasks'),
      );
      expect(lines, hasLength(1));
      expect(lines.single, contains('status'));
      expect(lines.single, contains('/tasks'));
      expect(lines.single, contains('urlParameterMapping'));
    });

    test('only the unmapped names are named', () {
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/callback?code=abc&status=open'),
        const TomEndpoint(
          uri: '/callback',
          urlParameterMapping: {'code': 'code'},
        ),
      );
      expect(lines.single, contains('status'));
      expect(lines.single, isNot(contains('code=')));
    });

    test('the values are never logged', () {
      // A query string is where `?code=…&state=…` arrives on an OAuth
      // callback. A log at a level people leave on in development is the last
      // place a credential should reach, and the name alone is the whole
      // diagnosis: what the author needs to know is that it was sent and not
      // bound.
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/callback?code=s3cret&state=t0ken'),
        const TomEndpoint(uri: '/callback'),
      );
      expect(lines.single, contains('code'));
      expect(lines.single, contains('state'));
      expect(lines.single, isNot(contains('s3cret')));
      expect(lines.single, isNot(contains('t0ken')));
    });

    test('several strays are one line, not one line each', () {
      // The set is the finding: an endpoint reached with three stray
      // parameters is reached with them together, and three lines would read
      // as three events.
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/t?utm_source=a&gclid=b&status=open'),
        const TomEndpoint(uri: '/t'),
      );
      expect(lines, hasLength(1));
      for (final name in const ['utm_source', 'gclid', 'status']) {
        expect(lines.single, contains(name));
      }
    });

    test('a fully mapped request says nothing', () {
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/callback?code=abc'),
        const TomEndpoint(
          uri: '/callback',
          urlParameterMapping: {'code': 'code'},
        ),
      );
      expect(lines, isEmpty);
    });

    test('a request with no query string says nothing', () {
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/tasks'),
        const TomEndpoint(uri: '/tasks'),
      );
      expect(lines, isEmpty);
    });

    test('a mapped name the caller omitted is not reported as unmapped', () {
      // The two states are different: `error_description` is part of the
      // contract and simply did not arrive, which is the ordinary shape of a
      // successful OAuth callback and says nothing about the endpoint.
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/callback?code=abc'),
        const TomEndpoint(
          uri: '/callback',
          urlParameterMapping: {
            'code': 'code',
            'error_description': 'errorDescription',
          },
        ),
      );
      expect(lines, isEmpty);
    });

    test('binding is unaffected by the log level', () {
      final lines = _captureLog();
      final previous = TomLogger.globalSettingDebugEnabled;
      addTearDown(() => TomLogger.globalSettingDebugEnabled = previous);
      TomLogger.globalSettingDebugEnabled = false;

      final json = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        json,
        _reqWithQuery('http://localhost/callback?code=abc&status=open'),
        const TomEndpoint(
          uri: '/callback',
          urlParameterMapping: {'code': 'code'},
        ),
      );

      expect(lines, isEmpty);
      expect(json, {'code': 'abc'});
    });

    test('a name the handler declares as a parameter is not reported', () {
      // The mapping is not the only way a query value reaches a handler: a bare
      // primitive parameter binds from the query string by its own name,
      // several strategies before the DTO is built. An endpoint that declares
      // one *and* takes a request DTO would otherwise have the bound parameter
      // reported as dropped on every request — a diagnostic that cries wolf on
      // the documented case teaches its reader to skip the line that matters.
      final lines = _captureLog();
      TomEndpointHandler.injectQueryParameters(
        <String, dynamic>{},
        _reqWithQuery('http://localhost/projects?workspaceId=7&status=open'),
        const TomEndpoint(uri: '/projects'),
        declaredParameterNames: const {'workspaceId'},
      );
      expect(lines.single, contains('status'));
      expect(lines.single, isNot(contains('workspaceId')));
    });

    test('the pipeline passes the handler\'s parameter names', () {
      // The exclusion is only correct if the caller supplies the names, and
      // the caller is the binding loop — reached only by a live request to an
      // endpoint that has *both* a primitive query parameter and a request
      // DTO, which no fixture declares. Asserted from the source rather than
      // by adding one: a default of `const {}` at the call site type-checks,
      // passes every test above, and silently restores the false alarm.
      final source = File(
        'lib/src/tomserver/endpoints/endpoint_pipeline.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(
          'for (final parameter in method.parameters) parameter.simpleName,',
        ),
        reason:
            'the binding loop no longer tells injectQueryParameters which '
            'names the handler declares, so a bound primitive query parameter '
            'is reported as dropped',
      );
    });

    test('the scan is behind the toggle, not merely the line', () {
      // Asserted from the source, because it cannot be observed: `tomLog.debug`
      // checks the same toggle itself, so dropping the guard would still print
      // nothing and pass every test above. What the guard buys is that an
      // endpoint reached with a query string does not build a list per request
      // on a server configured to discard the line — a cost, not an output.
      final source = File(
        'lib/src/tomserver/endpoints/endpoint_pipeline.dart',
      ).readAsStringSync();
      final body = source.substring(
        source.indexOf('static void injectQueryParameters('),
        source.indexOf('static void injectFormFields('),
      );
      final guard = body.indexOf('TomLogger.globalSettingDebugEnabled');
      final scan = body.indexOf('final unmapped = [');
      expect(guard, isNot(-1), reason: 'the toggle guard is gone');
      expect(scan, isNot(-1), reason: 'the unmapped scan was renamed');
      expect(
        guard,
        lessThan(scan),
        reason: 'the scan must not run when debug logging is off',
      );
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
