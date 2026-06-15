import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the reflection-free surface of the endpoints module.
///
/// The router builder ([TomEndpointRouting]) and per-request handler
/// ([TomEndpointHandler]) reflect over annotated service classes and serve live
/// HTTP requests, so they need a running server and generated reflection — they
/// are covered by `doc/endpoints.md` and integration tests, not here. This suite
/// pins the annotation surface a developer touches at declaration time and the
/// default error handler's response.
Request _req() => Request('POST', Uri.parse('http://localhost/greet'));

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
