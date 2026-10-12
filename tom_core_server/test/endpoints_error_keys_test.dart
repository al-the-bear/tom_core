/// Pins every error key the endpoints module raises to the input that raises
/// it.
///
/// The keys are the pipeline's contract with whoever catches its exceptions:
/// an error handler maps them to statuses, a client branches on them, an
/// operator greps a boot log for them. A key that no test names is a failure
/// mode nobody checks — it can be renamed, misspelled or swallowed by a broader
/// catch without a single test noticing, and the first to find out is the
/// caller whose branch silently stopped matching.
///
/// So each case below drives the real pipeline with the smallest input that
/// reaches one raise site, and asserts the **exact** key rather than the
/// exception type. A type-only assertion would pass just as well if the guard
/// had been replaced by its neighbour — several of these sites sit a few lines
/// apart and throw the same type — which is the change this file exists to
/// catch.
///
/// The inputs come in three kinds, and the kind says where the failure is
/// found in a running server:
///
/// - **Boot-time declarations** (`get_class_method_metadata.*`,
///   `initialize_router.*`, `create_routes_for_endpoint.*`): reflected fixture
///   classes carrying the malformed annotation set. They are invisible to
///   `scanClasses`, so no other suite's router trips over them, and are handed
///   to the guard directly. The duplicate-`@TomApiImplementation` guard needs
///   that annotation on the class, which would make the fixture
///   router-visible; there it is added on the mirror (see
///   [_WithClassMetadata]).
/// - **Request-time bindings** (`bind_parameters.*`,
///   `handle_method_call.parameter_*`): a request that a mounted fixture
///   endpoint cannot bind.
/// - **Invocation outcomes** (`handle_method_call.*`): a mounted fixture
///   endpoint re-declared with the error handler the case needs — none, or one
///   that itself fails — since the handler is the variable those sites test.
library;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAccessApiService,
        FixtureApiServer,
        FixtureApiService,
        FixtureDoubleAuditedService,
        FixtureDoubleComponentReference,
        FixtureDoubleEndpointService,
        FixtureDoubleTransactionalService,
        FixtureEmptyComponentReference,
        FixtureOverspecifiedComponentReference,
        FixtureUnimplementedApiService,
        fixtureAccessApiId,
        registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// An error handler that fails on every hook.
///
/// The two `*_handler_failed` keys exist for exactly this: the endpoint's own
/// error handler throwing while it handles an error. A handler that answered
/// would end the request normally and reach neither site.
class _FailingErrorHandler extends TomErrorHandler {
  const _FailingErrorHandler();

  @override
  Response handleErrorDefault(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) => throw StateError('the error handler failed as well');
}

/// An error handler that records which hook the pipeline called and with
/// what, and answers every hook with a plain `500`.
class _RecordingErrorHandler extends TomErrorHandler {
  _RecordingErrorHandler();

  final List<String> hooks = [];
  final List<Object> errors = [];

  Response _record(String hook, Object error) {
    hooks.add(hook);
    errors.add(error);
    return Response.internalServerError(body: hook);
  }

  @override
  Response handleInvocationError(
    Object error,
    StackTrace stacktrace,
    Request r,
  ) => _record('invocation', error);

  @override
  Response handleConversionError(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) => _record('conversion', error);

  @override
  Response handleUnknownResultTypeError(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) => _record('unknownResultType', error);

  @override
  Response handleErrorDefault(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) => _record('default', error);
}

/// A transaction participant that refuses at prepare, so the transaction it is
/// enlisted in concludes without committing.
class _VetoingParticipant implements TomTransactionParticipant {
  @override
  String getParticipantId() => 'vetoing-participant';

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async => false;

  @override
  Future<bool> commit(TomTransaction transaction) async => true;

  @override
  Future<bool> rollback(TomTransaction transaction) async => true;

  @override
  Future<bool> endTransaction(TomTransaction transaction) async => true;
}

/// A reflected class mirror with extra class-level annotations.
///
/// Stands in for a declaration the shared fixture library cannot carry: a class
/// annotated `@TomApiImplementation` is mounted by every router any suite
/// boots, so a malformed one would fail all of them. Only what the tag guards
/// read is answered — the real mirror's declarations and names, and its
/// metadata with the extra annotations appended — and anything else fails loudly rather than
/// answering for a class that does not exist.
class _WithClassMetadata implements ClassMirror {
  _WithClassMetadata(this._inner, this._extra);

  final ClassMirror _inner;
  final List<Object> _extra;

  @override
  List<Object> get metadata => [..._inner.metadata, ..._extra];

  @override
  Map<String, DeclarationMirror> get declarations => _inner.declarations;

  @override
  String get simpleName => _inner.simpleName;

  @override
  String get qualifiedName => _inner.qualifiedName;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not answered by this stand-in mirror',
  );
}

/// A channel that is never spoken on: attaching one only stores it.
class _UnusedChannel implements WebSocketChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} on a channel no test speaks on',
  );
}

/// The handler mounted for [path] under [method].
TomEndpointHandler _handler(String path, [String method = 'GET']) =>
    TomEndpointRouting.routingInfo[(uri: path, method: method)]!.handler;

/// [base], re-declared with [errorHandler] in place of the one it was mounted
/// with, and invoking the declaration [declaration] describes.
///
/// Everything else — instance, method, route, access, transaction — is the
/// mounted endpoint's own, so the error handler is the only thing a case
/// varies.
TomEndpointHandler _redeclared(
  TomEndpointHandler base, {
  required TomErrorHandler? errorHandler,
  MethodMirror? declaration,
}) {
  final mounted = base.metadata.endpoint;
  return TomEndpointHandler(
    name: base.name,
    instance: base.instance,
    method: base.method,
    interface: base.interface,
    implementation: base.implementation,
    methodName: base.methodName,
    metadata: TomMethodMetadata(
      endpoint: TomEndpoint(
        methods: mounted.methods,
        uri: mounted.uri,
        consumes: mounted.consumes,
        produces: mounted.produces,
        logRequests: false,
        errorHandler: errorHandler,
      ),
      methodMirror: declaration ?? base.metadata.methodMirror,
      access: base.metadata.access,
      transactionInfo: base.metadata.transactionInfo,
    ),
  );
}

/// A request carrying the log info the pipeline reads from every request.
Request _request(
  String method,
  String path, {
  String? body,
  Map<String, String>? headers,
  Map<String, Object> context = const {},
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  body: body,
  headers: headers,
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo(), ...context},
);

/// Matches an exception of type [T] whose key is exactly [key].
Matcher _keyed<T extends TomException>(String key) =>
    throwsA(isA<T>().having((e) => e.key, 'key', key));

ClassMirror _mirror(Type type) => tomReflector.reflectType(type) as ClassMirror;

void main() {
  setUpAll(() {
    initializeReflection();
    // The registry-tag guards resolve their endpoint through the contract
    // registry before they look at the class, and the lookup throws for an
    // unregistered API.
    registerFixtureAccessApi();
  });

  // ===========================================================================
  // Boot time: malformed declarations
  // ===========================================================================

  group('getClassMethodMetadata refuses an ambiguous tag set', () {
    final cases = <({String key, String input, ClassMirror Function() mirror})>[
      (
        key:
            'endpoint_pipeline.get_class_method_metadata.multiple_audited_tags',
        input: 'two @TomAudited on one endpoint',
        mirror: () => _mirror(FixtureDoubleAuditedService),
      ),
      (
        key:
            'endpoint_pipeline.get_class_method_metadata.multiple_transactional_tags',
        input: 'two @TomTransactional on one endpoint',
        mirror: () => _mirror(FixtureDoubleTransactionalService),
      ),
      (
        key:
            'endpoint_pipeline.get_class_method_metadata.multiple_endpoint_base_tags',
        input: 'two endpoint annotations on one method',
        mirror: () => _mirror(FixtureDoubleEndpointService),
      ),
      (
        key:
            'endpoint_pipeline.get_class_method_metadata.no_tom_api_implementation_found',
        input: 'a registry endpoint on a class with no @TomApiImplementation',
        mirror: () => _mirror(FixtureUnimplementedApiService),
      ),
      (
        key:
            'endpoint_pipeline.get_class_method_metadata.multiple_tom_api_implementation_tags',
        input: 'two @TomApiImplementation on one class',
        mirror: () => _WithClassMetadata(
          _mirror(FixtureAccessApiService),
          const [TomApiImplementation(apiId: fixtureAccessApiId)],
        ),
      ),
    ];

    for (final c in cases) {
      test('${c.input} raises ${c.key}', () {
        expect(
          () => TomEndpointRouting().getClassMethodMetadata(c.mirror()),
          _keyed<TomEndpointPipelineException>(c.key),
        );
      });
    }
  });

  group('scanClasses refuses a class annotated both ways', () {
    test(
      'an API implementation that is also a service raises '
      'endpoint_pipeline.initialize_router.api_implementation_and_service_on_same_class',
      () {
        // A reflection root carrying such a class would make every router
        // built from it throw, so the class set is handed to the scan
        // directly: the real API implementation, with @tomService added.
        expect(
          () => TomEndpointRouting().scanClasses([
            _WithClassMetadata(_mirror(FixtureAccessApiService), const [
              tomService,
            ]),
          ]),
          _keyed<TomEndpointPipelineException>(
            'endpoint_pipeline.initialize_router.api_implementation_and_service_on_same_class',
          ),
        );
      },
    );
  });

  group('getReferencedComponent refuses a malformed reference', () {
    setUp(() {
      TomBean.resetBeanContext();
      // The duplicate-reference guard fires on the second reference only once
      // the first has resolved, so the bean it names has to exist.
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
    });

    tearDown(TomBean.resetBeanContext);

    final cases = <({String key, String input, Type type})>[
      (
        key: 'endpoint_pipeline.initialize_router.component_reference_invalid',
        input: 'a reference naming neither a component nor a type',
        type: FixtureEmptyComponentReference,
      ),
      (
        key:
            'endpoint_pipeline.initialize_router.component_reference_invalid_both_set',
        input: 'a reference naming both a component and a type',
        type: FixtureOverspecifiedComponentReference,
      ),
      (
        key:
            'endpoint_pipeline.initialize_router.multiple_component_references',
        input: 'two references on one class',
        type: FixtureDoubleComponentReference,
      ),
    ];

    for (final c in cases) {
      test('${c.input} raises ${c.key}', () {
        expect(
          () => TomEndpointRouting().getReferencedComponent(_mirror(c.type)),
          _keyed<TomEndpointPipelineException>(c.key),
        );
      });
    }
  });

  group('mounting', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<TomHealthServer>(TomHealthServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
    });

    tearDown(() {
      TomEndpointRouting.resetRoutes();
      TomBean.resetBeanContext();
    });

    test(
      'a service with endpoints and no instance raises initialize_router.no_service_instance',
      () {
        expect(
          () => TomEndpointRouting().createRoutesForClassMirror(
            _mirror(FixtureApiService),
            null,
            Router(),
          ),
          _keyed<TomEndpointPipelineException>(
            'endpoint_pipeline.initialize_router.no_service_instance',
          ),
        );
      },
    );

    test(
      'a transactional socket endpoint raises create_routes_for_endpoint.transactional_web_socket',
      () {
        // The mounted socket endpoint, with a transaction added to what it
        // declares — the one combination the mounting step refuses.
        final socket = _handler('/fixture/socket');
        final declared = socket.metadata;
        final transactional = TomMethodMetadata(
          endpoint: declared.endpoint,
          methodMirror: declared.methodMirror,
          access: declared.access,
          webSocket: declared.webSocket,
          transactionInfo: const TomTransactional(),
        );
        expect(
          () => TomEndpointRouting().createRoutesForEndpoint(
            declared.endpoint,
            Router(),
            socket,
            transactional,
            _mirror(FixtureApiServer),
          ),
          _keyed<TomEndpointPipelineException>(
            'endpoint_pipeline.create_routes_for_endpoint.transactional_web_socket',
          ),
        );
      },
    );
  });

  // ===========================================================================
  // Request time: bindings and invocation outcomes
  // ===========================================================================

  group('a request the endpoint cannot serve', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<TomHealthServer>(TomHealthServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
    });

    tearDown(() {
      FixtureApiServer.transactionalParticipant = null;
      TomEndpointRouting.resetRoutes();
      TomBean.resetBeanContext();
    });

    test(
      'a form without the declared file part raises bind_parameters.missing_file_part',
      () {
        const boundary = 'tomtestboundary';
        final body =
            '--$boundary\r\n'
            'content-disposition: form-data; name="title"\r\n\r\nreport\r\n'
            '--$boundary--\r\n';
        expect(
          () => _handler('/fixture/upload', 'POST').bindParameters(
            _request(
              'POST',
              '/fixture/upload',
              body: body,
              headers: {
                'content-type': 'multipart/form-data; boundary=$boundary',
              },
            ),
          ),
          _keyed<TomFormBindingException>(
            'endpoint_pipeline.bind_parameters.missing_file_part',
          ),
        );
      },
    );

    // The context branch of binding: a value placed in the request context
    // under the parameter type's name. Each case keeps the body empty, so the
    // JSON branch declines and the context value is what is consulted.
    final contextCases = <({String key, String input, Object value})>[
      (
        key:
            'endpoint_pipeline.handle_method_call.parameter_instantiation_invalid_type_in_context',
        input: 'a context value that is neither the type nor a map',
        value: 42,
      ),
      (
        key:
            'endpoint_pipeline.handle_method_call.parameter_instantiation_from_context_failed',
        input: 'a context map the DTO refuses',
        value: <String, Object?>{'label': 'x', 'when': 'not-a-date'},
      ),
    ];

    for (final c in contextCases) {
      test('${c.input} raises ${c.key}', () {
        expect(
          () => _handler('/fixture/parse', 'POST').bindParameters(
            _request(
              'POST',
              '/fixture/parse',
              body: '',
              context: {'FixtureParseRequest': c.value},
            ),
          ),
          _keyed<TomEndpointHandlerException>(c.key),
        );
      });
    }

    test(
      'a body already consumed upstream raises handle_method_call.parameter_instantiation_general_failure',
      () async {
        // A middleware that reads the body without handing on a fresh request
        // leaves a stream that cannot be read twice. The failure is neither a
        // body nor a DTO problem, so it lands on the general key.
        final request = _request(
          'POST',
          '/fixture/parse',
          body: '{"label":"x"}',
        );
        await request.readAsString();
        await expectLater(
          _handler('/fixture/parse', 'POST').bindParameters(request),
          _keyed<TomEndpointHandlerException>(
            'endpoint_pipeline.handle_method_call.parameter_instantiation_general_failure',
          ),
        );
      },
    );

    test(
      'a vetoed transaction raises handle_method_call.commit_failed',
      () async {
        // No error handler, so the failure leaves the pipeline as thrown
        // rather than being turned into a response.
        FixtureApiServer.transactionalParticipant = _VetoingParticipant();
        final handler = _redeclared(
          _handler('/fixture/transactional'),
          errorHandler: null,
        );
        await expectLater(
          handler.handleMethodCall(_request('GET', '/fixture/transactional')),
          _keyed<TomTransactionException>(
            'endpoint_pipeline.handle_method_call.commit_failed',
          ),
        );
      },
    );

    test(
      'an error handler failing on an invocation error raises handle_method_call.error_handler_failed',
      () async {
        final handler = _redeclared(
          _handler('/fixture/default_logging_error'),
          errorHandler: const _FailingErrorHandler(),
        );
        await expectLater(
          handler.handleMethodCall(
            _request('GET', '/fixture/default_logging_error'),
          ),
          _keyed<TomEndpointHandlerException>(
            'endpoint_pipeline.handle_method_call.error_handler_failed',
          ),
        );
      },
    );

    // A result the pipeline cannot render. `silent` completes with an `int`;
    // its contract declares `Future<void>`, which is why it is normally
    // answered with no body. Declared through the implementation's signature,
    // `Future<int>`, the int is a body — and a bare int is not a reflected
    // object, so rendering it fails.
    final conversionCases = <({String key, TomErrorHandler? errorHandler})>[
      (
        key:
            'endpoint_pipeline.handle_method_call.conversion_error_handler_failed',
        errorHandler: const _FailingErrorHandler(),
      ),
      (
        key:
            'endpoint_pipeline.handle_method_call.result_conversion_failed_no_error_handler',
        errorHandler: null,
      ),
    ];

    for (final c in conversionCases) {
      test('an unrenderable result raises ${c.key}', () async {
        final base = _handler('/fixture/silent', 'DELETE');
        final handler = _redeclared(
          base,
          errorHandler: c.errorHandler,
          declaration: base.method,
        );
        await expectLater(
          handler.handleMethodCall(_request('DELETE', '/fixture/silent')),
          _keyed<TomEndpointHandlerException>(c.key),
        );
      });
    }

    group('a result that cannot be rendered reaches the hook for its cause', () {
      test('a type the converter has no rendering for is an unknown result '
          'type', () async {
        // `silent`'s implementation answers a bare int, which carries no
        // @tomReflector: the converter refuses the type itself.
        final recorder = _RecordingErrorHandler();
        final base = _handler('/fixture/silent', 'DELETE');
        final handler = _redeclared(
          base,
          errorHandler: recorder,
          declaration: base.method,
        );

        final response = await handler.handleMethodCall(
          _request('DELETE', '/fixture/silent'),
        );

        expect(recorder.hooks, ['unknownResultType']);
        expect(
          recorder.errors.single,
          isA<TomReflectorException>().having(
            (e) => e.key,
            'key',
            'reflector.type.not_annotated',
          ),
        );
        expect(response.statusCode, 500);
      });

      test('a known shape that fails to encode is a conversion error', () async {
        // A map of scalars is a shape the converter renders; the NaN inside it
        // is what JSON refuses — a rendering failure, not a type refusal.
        final recorder = _RecordingErrorHandler();
        final handler = _redeclared(
          _handler('/fixture/unencodable'),
          errorHandler: recorder,
        );

        await handler.handleMethodCall(_request('GET', '/fixture/unencodable'));

        expect(recorder.hooks, ['conversion']);
        expect(recorder.errors.single, isNot(isA<TomReflectorException>()));
      });
    });

    test(
      'a socket handshake on an HTTP endpoint raises handle_web_socket_call.not_a_socket_endpoint',
      () async {
        await expectLater(
          _handler(
            '/fixture/health',
          ).handleWebSocketCall(_request('GET', '/fixture/health')),
          _keyed<TomWebSocketException>(
            'endpoint_pipeline.handle_web_socket_call.not_a_socket_endpoint',
          ),
        );
      },
    );
  });

  group('TomWebSocketConnection', () {
    test(
      'attaching a second channel raises web_socket_endpoint.already_attached',
      () {
        final connection = TomWebSocketConnection()
          ..attachChannel(_UnusedChannel());
        expect(
          () => connection.attachChannel(_UnusedChannel()),
          _keyed<TomWebSocketException>('web_socket_endpoint.already_attached'),
        );
      },
    );
  });
}
