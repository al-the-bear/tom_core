/// Reflection bootstrap fixture for the `tom_core_server` test suite.
///
/// `dart test` runs every test *file* in its own isolate, and the reflected
/// surfaces of the server (the endpoint pipeline, `TomArgs.fillFromArgs`, the
/// health route) all construct `ClassMirror`/`InstanceMirror` — which throws
/// "Reflection has not been initialized" until [initializeReflection] has been
/// called. This file is the reflection *root*: the generator
/// (`reflection_generation.sh` → `test/fixtures/reflection_fixture.reflection.dart`)
/// follows its import graph and emits an `initializeReflection()` that captures
/// these fixture types (and the transitively-reached server barrel). A test that
/// wants the reflected pipeline calls that generated function in `setUpAll`.
///
/// The fixture deliberately mirrors the codebase's endpoint convention: a
/// `@tomService` **interface** declares the endpoint contract (the annotations
/// the router reads via `getClassMethodMetadata`) and a `@tomComponent`
/// **implementation** carries the invoked bodies. A single self-referential
/// class does not work — `findServiceInstance` resolves an implementation only
/// by a component whose superclass/superinterface is the service type, so the
/// two roles must be separate types.
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Entry point required by the reflection generator: it only processes a root
/// that declares `main()`, and captures the types reachable from it. The body
/// is intentionally empty — the file exists to be the reflection root, never to
/// be run.
void main() {}

/// The fixture API contract the endpoint router reflects over.
///
/// The `@TomEndpoint` / `@TomPublicAccess` annotations live here, on the
/// abstract methods, because `getClassMethodMetadata` reads them from the
/// service *interface*; the implementation only supplies the method bodies the
/// pipeline invokes.
@tomReflector
@tomService
abstract class FixtureApiService {
  /// Public liveness probe — `@TomPublicAccess` makes `checkAccess(null)` grant
  /// access without a principal, so the route serves an anonymous request.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/health',
    produces: TomMimeType.json,
    logRequests: true,
  )
  Future<Map<String, Object>> health();

  /// An endpoint with **no** access annotation, so `metadata.access` is null and
  /// `checkAccess` falls back to the global protection default — the second
  /// `checkAccess` branch under test.
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/unguarded',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> unguarded();

  /// An endpoint that says **nothing** about request logging, so
  /// `TomEndpoint.logRequests` is null and the decision falls to
  /// `TomEndpointHandler.globalSettingLogRequestsDefault`.
  ///
  /// Every other fixture endpoint states the flag explicitly, which is why the
  /// global default had no coverage at all: the setting exists to govern
  /// precisely the endpoints that stay silent, and there were none.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/default_logging',
    produces: TomMimeType.json,
  )
  Future<Map<String, Object>> defaultLogging();

  /// The same silence about `logRequests`, but leaving by the *handler-supplied
  /// response* exit rather than the conversion one.
  ///
  /// The pipeline has one log statement per exit, and they are five copies of
  /// one decision — so each exit needs its own witness or a copy can drift back
  /// to reading the raw annotation unnoticed. This is the exit streaming
  /// endpoints take (see `TomFileService`), where the pipeline's line is the
  /// only per-request record there is.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/default_logging_response',
    produces: TomMimeType.json,
  )
  Future<Response> defaultLoggingResponse();

  /// The same silence about `logRequests`, leaving by the *error-handler* exit.
  ///
  /// Every endpoint has an error handler by default, so a throwing handler takes
  /// the branch that answers from `handleInvocationError` — a third copy of the
  /// same logging decision, and the only exit whose log line is the sole record
  /// that a request failed at all.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/default_logging_error',
    produces: TomMimeType.json,
  )
  Future<Map<String, Object>> defaultLoggingError();

  /// An endpoint whose *invocation* is itself the auditable act (CE-LG).
  ///
  /// Endpoint auditing is declared rather than automatic — most endpoint calls
  /// are reads, and which of them matter is a domain judgement — so this is the
  /// fixture that proves `@TomAudited` on a method reaches the trail. Its
  /// unannotated sibling [unguarded] proves the converse.
  @TomAudited()
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/audited',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> auditedAction();

  /// A `multipart/form-data` endpoint that takes both halves of a form: the
  /// text parts as a typed request DTO, and a file part as a parameter.
  ///
  /// This is the shape the raw-body file endpoint cannot express — "create a
  /// document *with* its attachment", where the metadata and the bytes arrive
  /// together and there is no row yet to attach to.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post],
    uri: '/fixture/upload',
    consumes: TomMimeType.multipartFormData,
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> upload(
    FixtureUploadRequest request,
    TomFormFile attachment,
  );

  /// A form endpoint that declares [TomEndpoint.formFields] as an allow-list,
  /// so a part the sender added on its own does not reach the DTO.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post],
    uri: '/fixture/upload_declared',
    consumes: TomMimeType.multipartFormData,
    produces: TomMimeType.json,
    formFields: ['title'],
    logRequests: false,
  )
  Future<Map<String, Object>> uploadDeclared(FixtureUploadRequest request);

  /// A JSON endpoint whose request DTO can refuse the body it is handed.
  ///
  /// [FixtureParseRequest.when] is a `DateTime`, so `{"when": "not-a-date"}` is
  /// a body the DTO genuinely cannot be built from — the reflector raises
  /// `reflection.set.date_parse_failed`. That is the failure the pipeline is
  /// supposed to report as a named endpoint exception, and it needs an endpoint
  /// that consumes JSON to reach: every other fixture endpoint is either a GET
  /// or a multipart form.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post],
    uri: '/fixture/parse',
    consumes: TomMimeType.json,
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> parse(FixtureParseRequest request);

  /// Two parameters of which the **first** cannot be bound by any strategy.
  ///
  /// [first] is a request DTO on a `GET` with no body, no path capture and no
  /// query mapping, so nothing can fill it; [second] binds from `?second=`.
  /// The order is the point: a binder that simply skips what it cannot fill
  /// produces a one-element list, and that element — the value of `second` —
  /// arrives in the slot of `first`. Everything after an unbindable parameter
  /// moves one place left, which is a wrong *value* in a right-looking call,
  /// not merely a wrong count.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/pair',
    logRequests: false,
  )
  Future<Map<String, Object>> pair(FixtureParseRequest first, String second);

  /// A trailing **optional** parameter that nothing binds.
  ///
  /// The counter-case to [pair], and the reason "unbound" cannot simply mean
  /// "error": a default value is the declaration saying this parameter may be
  /// absent, and omitting a trailing optional from the positional list is
  /// exactly how Dart applies that default. Positions are preserved, so this
  /// must keep working.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/optional_tail',
    logRequests: false,
  )
  Future<Map<String, Object>> optionalTail(
    String first, [
    String second = 'fallback',
  ]);

  /// Two trailing optionals of which only the **later** one can be bound.
  ///
  /// Requested as `?first=1&third=3`, so `second` is a *hole*: omitting it from
  /// the positional list does not apply its default, it slides `third`'s value
  /// into `second`'s slot. This is why "a trailing optional may be omitted" is
  /// the whole rule and not half of it — an optional may be dropped only when
  /// everything after it is dropped too.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/optional_gap',
    logRequests: false,
  )
  Future<Map<String, Object>> optionalGap(
    String first, [
    String second = 'two',
    String third = 'three',
  ]);

  /// A **named** parameter that a binding strategy can fill from `?tag=`.
  ///
  /// The pipeline invokes with positional arguments only, so a bound named
  /// parameter has nowhere legitimate to go: appending it positionally puts it
  /// in the slot of whichever positional parameter comes next. That is the same
  /// corruption as [pair] arriving from the opposite direction, which is why
  /// binding has to refuse it rather than quietly mis-place it.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/named_tail',
    logRequests: false,
  )
  Future<Map<String, Object>> namedTail(String first, {String tag = 'none'});

  /// An endpoint that answers with a redirect directive rather than a value.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/moved',
    logRequests: false,
  )
  Future<Object> moved();

  /// A `@TomTransactional` endpoint that reports the transaction it ran in.
  ///
  /// It parks on [FixtureApiServer.transactionalRelease] in the middle of its
  /// transactional block, so a test can hold two calls open *simultaneously* and
  /// assert they are in different transactions rather than inferring it from
  /// timing. Read-only, because the flag was declarable and discarded before the
  /// pipeline was fixed to pass it on.
  @TomPublicAccess()
  @TomTransactional(isReadOnly: true)
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/transactional',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> transactionalWork();

  /// One endpoint answering **three** HTTP methods on a single route.
  ///
  /// Every other fixture endpoint declares exactly one method, so the routing
  /// table's per-method loop had nothing to iterate and the collapse it caused
  /// could not be seen. Three methods make the table's shape observable: the
  /// route is mounted three times and must be retrievable three times.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get, TomHttpMethod.put, TomHttpMethod.delete],
    uri: '/fixture/multi_method',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> multiMethod();

  /// The `GET` half of a route whose methods are split across **two** endpoints.
  ///
  /// Splitting one URI between handlers is legal — the router keys on method as
  /// well as path — and it is the case that distinguishes a real fix from a
  /// cosmetic one. A multi-method endpoint writes the *same* handler once per
  /// method, so a table keyed by URI alone still holds the right value; here the
  /// two entries differ, and keying by URI alone loses one of them outright.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/split_route',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> splitRouteRead();

  /// The `POST` half of [splitRouteRead]'s route, on a different handler.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post],
    uri: '/fixture/split_route',
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Map<String, Object>> splitRouteWrite();

  /// An **inline** endpoint declaring fixed response headers.
  ///
  /// `TomEndpoint.headers` is copied onto every response the pipeline builds,
  /// and no fixture declared any, so the whole field went unserved: nothing
  /// established what the inline declaration style *does* with headers, which
  /// is the baseline the registry style has to agree with. Its registry
  /// counterpart is `FixtureAccessApiService.headerDeclaring`.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture/inline_headers',
    produces: TomMimeType.json,
    headers: {'x-fixture-inline': 'from-inline-declaration'},
    logRequests: false,
  )
  Future<Map<String, Object>> inlineHeaders();

  /// A WebSocket endpoint: invoked once per accepted connection, with the live
  /// socket among its parameters.
  ///
  /// It reports what it can see of the request zone, which is the property that
  /// makes a socket endpoint an *endpoint* rather than a second server (bug
  /// D22): the callback fires after the handshake response is finished, so
  /// without the pipeline's zone capture the principal, the execution context
  /// and the request id would all be gone by the time this body runs.
  @TomPublicAccess()
  @TomWebSocketEndpoint(uri: '/fixture/socket')
  Future<void> socket(TomWebSocketConnection connection);
}

/// The request DTO of the fixture's form endpoints.
///
/// Reflected and default-constructible, because that is how the pipeline builds
/// a request DTO — text form parts are folded into a map and the instance is
/// created from it, exactly as for a JSON body.
@tomReflector
class FixtureUploadRequest {
  /// The document title, from the `title` form field.
  String title = '';

  /// Free-text tags, from the `tags` form field.
  String tags = '';

  /// Creates an empty request; the pipeline fills the fields by reflection.
  FixtureUploadRequest();
}

/// The request DTO of [FixtureApiService.parse], built from a JSON body.
///
/// The `DateTime` field is the point of it: it is the cheapest way to write a
/// body that is *valid JSON* and still cannot become this DTO, which is the
/// case that separates "the client sent nonsense" from "the client sent
/// nothing". A `String` field would accept anything and a missing field is
/// tolerated by the converter, so neither could fail.
@tomReflector
class FixtureParseRequest {
  /// Free-text label; accepts whatever arrives.
  String label = '';

  /// The field a malformed body fails on — see the class doc.
  DateTime when = DateTime.utc(2026);

  /// Creates an empty request; the pipeline fills the fields by reflection.
  FixtureParseRequest();
}

/// Live implementation of [FixtureApiService]; the pipeline invokes these
/// bodies on the instance registered with the bean locator.
@tomReflector
@tomComponent
class FixtureApiServer implements FixtureApiService {
  /// Every transaction [transactionalWork] observed, in arrival order.
  ///
  /// The identities are what the concurrency assertion is made on, so the test
  /// needs the objects rather than a rendering of them.
  static final List<TomTransaction?> transactionalArrivals = [];

  /// Held by a test to keep [transactionalWork] parked inside its transaction.
  ///
  /// Null (the default) makes the endpoint run straight through, so every other
  /// test that happens to hit it is unaffected.
  static Completer<void>? transactionalRelease;

  @override
  Future<Map<String, Object>> transactionalWork() async {
    final transaction = TomTransactionManager.getCurrentTransaction();
    transactionalArrivals.add(transaction);
    // The await that makes this interesting: while parked here a second request
    // runs the same block, which is precisely the interleaving a process-wide
    // current transaction cannot survive.
    await transactionalRelease?.future;
    return <String, Object>{
      'readOnly': transaction?.isReadOnly ?? false,
      'running': transaction?.isRunning ?? false,
      // Still the same transaction after the await — the zone carried it.
      'stable': identical(
        transaction,
        TomTransactionManager.getCurrentTransaction(),
      ),
    };
  }

  @override
  Future<Map<String, Object>> health() async => <String, Object>{
    'status': 'ok',
    'app': 'fixture',
  };

  @override
  Future<Map<String, Object>> unguarded() async => <String, Object>{
    'guarded': false,
  };

  @override
  Future<Map<String, Object>> defaultLogging() async => <String, Object>{
    'logging': 'default',
  };

  @override
  Future<Response> defaultLoggingResponse() async =>
      Response.ok('{"logging":"default-response"}');

  @override
  Future<Map<String, Object>> defaultLoggingError() async =>
      throw StateError('the handler failed');

  @override
  Future<Map<String, Object>> auditedAction() async => <String, Object>{
    'audited': true,
  };

  @override
  Future<Map<String, Object>> upload(
    FixtureUploadRequest request,
    TomFormFile attachment,
  ) async => <String, Object>{
    'title': request.title,
    'tags': request.tags,
    'field': attachment.field,
    'fileName': attachment.fileName ?? '',
    'mediaType': attachment.mediaType ?? '',
    'bytes': attachment.byteCount,
  };

  @override
  Future<Map<String, Object>> uploadDeclared(
    FixtureUploadRequest request,
  ) async => <String, Object>{'title': request.title, 'tags': request.tags};

  @override
  Future<Map<String, Object>> parse(FixtureParseRequest request) async =>
      <String, Object>{
        'label': request.label,
        'when': request.when.toIso8601String(),
      };

  @override
  Future<Map<String, Object>> pair(
    FixtureParseRequest first,
    String second,
  ) async => <String, Object>{'label': first.label, 'second': second};

  @override
  Future<Map<String, Object>> optionalTail(
    String first, [
    String second = 'fallback',
  ]) async => <String, Object>{'first': first, 'second': second};

  @override
  Future<Map<String, Object>> optionalGap(
    String first, [
    String second = 'two',
    String third = 'three',
  ]) async => <String, Object>{
    'first': first,
    'second': second,
    'third': third,
  };

  @override
  Future<Map<String, Object>> namedTail(
    String first, {
    String tag = 'none',
  }) async => <String, Object>{'first': first, 'tag': tag};

  @override
  Future<Object> moved() async => TomRedirect.seeOther('/fixture/health');

  @override
  Future<Map<String, Object>> multiMethod() async => <String, Object>{
    'route': 'multi',
  };

  @override
  Future<Map<String, Object>> splitRouteRead() async => <String, Object>{
    'half': 'read',
  };

  @override
  Future<Map<String, Object>> splitRouteWrite() async => <String, Object>{
    'half': 'write',
  };

  @override
  Future<Map<String, Object>> inlineHeaders() async => <String, Object>{
    'style': 'inline',
  };

  @override
  Future<void> socket(TomWebSocketConnection connection) async {
    // Read from the zone the pipeline captured at handshake time. If the zone
    // were not re-established for the callback, both of these would be null.
    final request = getFromCurrentZone<Request>();
    final requestId = getFromCurrentZone<TomRequestId>();
    connection.sendText(
      'zone:${request == null ? 'lost' : request.url.path};'
      'id:${requestId == null ? 'lost' : 'present'}',
    );
    await for (final message in connection.messages) {
      if (message == 'bye') return;
      connection.sendText('echo:$message');
    }
  }
}

// =============================================================================
// C-12 / G-API-3: contract-declared access vs. handler-side override
// =============================================================================

/// The API id of the fixture contract used by the access-resolution fixtures.
const fixtureAccessApiId = 'fixture_access';

/// The policy declared on the **contract** (`TomApiEndpoint.access`).
///
/// A top-level const so a test can assert `identical(metadata.access, ...)`:
/// `TomAccessControl` values are shared consts, so value-equality would not
/// distinguish a policy that came from the contract from an equal one that came
/// from the handler. Its roles are named for their *source*, not for a domain
/// role, because which of the two objects arrives is the entire assertion.
const fixtureContractAccess = TomRoleAccess(['fixture-contract-role']);

/// The policy declared on the **handler**, overriding [fixtureContractAccess].
const fixtureHandlerAccess = TomRoleAccess(['fixture-handler-role']);

/// The policy on a handler whose endpoint is declared inline (no registry
/// entry), so there is no contract policy that could shadow it.
const fixtureInlineAccess = TomRoleAccess(['fixture-inline-role']);

/// Registers the fixture API contract that [FixtureAccessApiService] implements.
///
/// Must run before anything reflects over that class: `getClassMethodMetadata`
/// resolves a `@TomApiEndpointImplementation` through `tomRemoteApis[apiId]`,
/// which **throws** `apis.api.not_found` for an unregistered API rather than
/// yielding null. Since the class is a `@TomApiImplementation`, `scanClasses`
/// finds it, so *every* test that boots a router needs this — call it in
/// `setUpAll` next to `initializeReflection`, and register a bean for the class.
///
/// Idempotent, so repeated calls across suites (and across `setUp`s within one)
/// are harmless.
void registerFixtureAccessApi() {
  if (tomRemoteApis.apis.containsKey(fixtureAccessApiId)) return;
  tomRemoteApis[fixtureAccessApiId] = TomApi(
    id: fixtureAccessApiId,
    uri: '/fixture-access',
    endpoints: [
      // Case (a): a contract-declared policy with no handler annotation.
      TomApiEndpoint<Object, Object>(
        id: 'contractGated',
        uri: '/contract-gated',
        method: TomHttpMethod.get,
        access: fixtureContractAccess,
      ),
      // Case (b): the same contract policy, which the handler overrides.
      TomApiEndpoint<Object, Object>(
        id: 'overridden',
        uri: '/overridden',
        method: TomHttpMethod.get,
        access: fixtureContractAccess,
      ),
      // A contract declaring **both** header directions, which is the only way
      // to tell them apart: an entry declaring one of them cannot show which
      // one the server picked up. `requestHeaders` is what a *client* is told
      // to send (`TomServerConnection` reads it); `responseHeaders` is what the
      // server is told to answer with. Nothing in the package declared either,
      // so the server's reading of the contract went unasserted.
      TomApiEndpoint<Object, Object>(
        id: 'headerDeclaring',
        uri: '/headers',
        method: TomHttpMethod.get,
        requestHeaders: fixtureContractRequestHeaders,
        responseHeaders: fixtureContractResponseHeaders,
      ),
    ],
  );
}

/// Headers the contract tells a **client** to send to
/// [FixtureAccessApiService.headerDeclaring].
///
/// The value names its direction so a wrongly-wired mapping is legible in the
/// failure message rather than being a bare string mismatch.
const fixtureContractRequestHeaders = {
  'x-fixture-request': 'sent-by-the-client',
};

/// Headers the contract tells the **server** to answer
/// [FixtureAccessApiService.headerDeclaring] with.
const fixtureContractResponseHeaders = {
  'x-fixture-response': 'sent-by-the-server',
};

/// A registry-backed API implementation covering the three ways an endpoint can
/// acquire (or fail to acquire) an access policy (C-12 / G-API-3).
///
/// The three methods are the three branches of
/// `final resolvedAccess = tea ?? ae?.access`:
///
/// - [contractGated] declares **no** inline annotation, so the policy must be
///   extracted from the contract — the half the advanced sample already relies
///   on for every `/admin/*` route;
/// - [overridden] declares one that **differs** from the contract's, so the
///   handler must win — the half no test and no sample exercises, which is why
///   reversing the two operands would pass the whole workspace today;
/// - [inlineGated] is an inline `@TomEndpoint` with no registry entry, so there
///   is no `ae` at all and the handler's policy stands unopposed.
///
/// It is a concrete `@tomComponent` + `@TomApiImplementation` class rather than
/// the interface/implementation pair [FixtureApiService] uses, because that is
/// the shape the registry-backed path actually has in the advanced sample
/// (`AdvancedAdminApiService`) — and the suite had no fixture of that shape at
/// all before, so the registry-mounting path went unmounted in every test.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: fixtureAccessApiId)
class FixtureAccessApiService {
  /// Case (a): gated purely by the contract.
  @TomApiEndpointImplementation(
    apiId: fixtureAccessApiId,
    endpointId: 'contractGated',
  )
  Future<Map<String, Object>> contractGated() async => <String, Object>{
    'source': 'contract',
  };

  /// Case (b): the handler's policy overrides the contract's.
  @TomRoleAccess(['fixture-handler-role'])
  @TomApiEndpointImplementation(
    apiId: fixtureAccessApiId,
    endpointId: 'overridden',
  )
  Future<Map<String, Object>> overridden() async => <String, Object>{
    'source': 'handler',
  };

  /// Case (c): an inline endpoint, so no contract policy exists to shadow.
  @TomRoleAccess(['fixture-inline-role'])
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture-access/inline',
    produces: TomMimeType.json,
  )
  Future<Map<String, Object>> inlineGated() async => <String, Object>{
    'source': 'inline',
  };

  /// The registry counterpart of [FixtureApiService.inlineHeaders]: its headers
  /// come from the contract entry rather than from the annotation.
  ///
  /// The two declaration styles must agree about what a response carries, and
  /// the only way to catch them diverging is an endpoint whose contract states
  /// *both* directions — then a response either carries the one the contract
  /// meant for it or carries the one meant for the caller.
  @TomPublicAccess()
  @TomApiEndpointImplementation(
    apiId: fixtureAccessApiId,
    endpointId: 'headerDeclaring',
  )
  Future<Map<String, Object>> headerDeclaring() async => <String, Object>{
    'style': 'registry',
  };
}

/// A class whose endpoint method carries **two** `TomAccessControl` annotations
/// — the shape `getClassMethodMetadata` rejects with
/// `endpoint_pipeline.get_class_method_metadata.multiple_access_control`.
///
/// Deliberately annotated `@tomReflector` **only**: no `@tomService`,
/// `@tomComponent` or `@TomApiImplementation`. `scanClasses` partitions on
/// exactly those three annotations, so this class is invisible to
/// `initializeRouter` while still being reflectable by name. That matters — the
/// guard throws during metadata collection, so a router-visible fixture would
/// make *every* suite that boots a router fail instead of the one test that
/// asserts the throw.
///
/// The endpoint is declared inline so no API registry entry is needed: the
/// conflict is detected while the tag set is being collected, before any
/// contract is consulted.
@tomReflector
class FixtureConflictingAccessService {
  /// Two policies on one method: ambiguous by construction.
  @TomRoleAccess(['fixture-first-role'])
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: '/fixture-access/conflicting',
    produces: TomMimeType.json,
  )
  Future<Map<String, Object>> conflicting() async => <String, Object>{
    'unreachable': true,
  };
}

/// A reflected configuration object for exercising [TomArgs.fillFromArgs]: its
/// public fields are assigned by name from parsed `key=value` arguments.
///
/// One field per type the argument converter can produce (`String`, `int`,
/// `double`, `bool`), so the reflected binding can be exercised across the
/// whole conversion table rather than a sample of it.
@tomReflector
class FixtureServerConfig {
  /// Assigned from `name=<value>` (stays a String).
  String name = '';

  /// Assigned from `port=<value>` (coerced to int by the arg parser).
  int port = 0;

  /// Assigned from `rate=<value>` (a decimal value converts to double).
  double rate = 0.0;

  /// Assigned from a bare `verbose` flag (recorded as `"true"`, coerced to bool).
  bool verbose = false;
}

/// A reflected persistence entity for the DB-backed test surfaces (RCK13).
///
/// Mirrors the sample's `@TomDbTable` / `@TomEntityId` / `@TomDbColumn` record
/// shape (a nullable surrogate key that is `null` before the first insert, plus
/// typed nullable columns) so the CRUD/query paths of
/// [TomSqlDatasourceRepository] can be exercised against a real MariaDB. It maps
/// to the `fixture_task` table in the `tom_core_server_test` data source that
/// `test_database.dart` provisions and tears down per run. The type is
/// `@tomReflector` because the data source's row mapper and the annotation
/// analyzer resolve it by mirror.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_task',
  primaryKeyField: 'id',
)
class FixtureTaskRecord {
  /// Surrogate primary key — `null` until first persisted, then the
  /// database-assigned AUTO_INCREMENT value. `isReadOnly` keeps it out of the
  /// generated INSERT/UPDATE column lists.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A plain string column.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// An int column, to cover integer binding and row mapping.
  @TomDbColumn(columnName: 'priority')
  int? priority;

  /// A bool column, to cover the Dart `bool` → MariaDB `TINYINT(1)` (`1`/`0`)
  /// bind translation end-to-end.
  @TomDbColumn(columnName: 'done')
  bool? done;
}

/// The MariaDB-backed repository for [FixtureTaskRecord].
///
/// Extends [TomSqlDatasourceRepository] directly (no `@tomReflector`): it is
/// constructed with `new`, never through a mirror, and inherits every
/// CRUD/query method. Its constructor resolves the entity's persistence
/// metadata and looks up the `tom_core_server_test` data source, so it must be
/// created only *after* `test_database.dart` has registered that data source.
class FixtureTaskRepository
    extends TomSqlDatasourceRepository<FixtureTaskRecord, int> {}

/// A reflected entity carrying a **redacted** column, for the CE-LG audit
/// surface.
///
/// `@TomAudited(redact: ...)` is the declaration that keeps a value out of the
/// audit trail entirely. The trail is privileged storage — a C-4 column grade
/// hides a value from the caller, not from the auditor — so redaction exists
/// for values that must not exist in a *second* place at all: password hashes,
/// access tokens, keys. The record still shows that `secret` changed; only its
/// values are withheld.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_secret',
  primaryKeyField: 'id',
)
class FixtureSecretRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, recorded in the clear.
  @TomDbColumn(columnName: 'label')
  String? label;

  /// The redacted column: audited as *changed*, never as a value.
  @TomDbColumn(columnName: 'secret')
  String? secret;
}

/// The MariaDB-backed repository for [FixtureSecretRecord].
class FixtureSecretRepository
    extends TomSqlDatasourceRepository<FixtureSecretRecord, int> {}

/// A reflected entity with two **file-reference** columns (CSFS1).
///
/// A `@TomFileReference` column holds a storage *key*; the bytes live in a blob
/// store. Two columns rather than one, because the interesting behaviour is in
/// how they differ:
///
/// - `attachment` is an ordinary file column that **cascades** — replacing or
///   deleting the row must take its blob with it;
/// - `secretAttachment` carries an `authKey`, so the C-4 grade governs it. It
///   is the column that proves a masked file column refuses a download by name
///   instead of reporting "no file", and that a masked round-trip cannot orphan
///   a live blob. It also sets `cascadeDelete: false`, so the "leave the bytes
///   alone" opt-out is exercised rather than merely declared.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_document',
  primaryKeyField: 'id',
)
class FixtureDocumentRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, so a save that touches no file still has work to do.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The cascading file column: holds the storage key of the attached file.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/attachment')
  String? attachment;

  /// A C-4 graded, non-cascading file column.
  @TomDbColumn(
    columnName: 'secret_attachment',
    authKey: 'fixture.document.secret_attachment',
  )
  @TomFileReference(keyPrefix: 'fixture/secret', cascadeDelete: false)
  String? secretAttachment;
}

/// The MariaDB-backed repository for [FixtureDocumentRecord].
class FixtureDocumentRepository
    extends TomSqlDatasourceRepository<FixtureDocumentRecord, int> {}

/// A reflected entity with a file-reference column on a **row-scoped** table
/// (CSEXD2).
///
/// [FixtureDocumentRecord] declares no `@TomDbScope`, so every file test written
/// against it exercises C-4 (may this principal see this *column*) with C-3 (may
/// this principal see this *row*) switched off. This entity is the other half.
/// It is separate rather than an added annotation on the document fixture,
/// because an unscoped entity is the case the existing suite needs: adding a
/// scope there would make every one of those tests depend on a principal being
/// in the zone, and would delete the coverage that a file column works when no
/// scope is declared at all.
///
/// The scope is `owner` on [ownerId], the simplest resolver that discriminates:
/// `principal.id` must equal the row's `owner_id`. A file slot is addressed as
/// `<table>/<id>/<column>` with the id supplied by the caller, so this scope is
/// the only thing between a guessed id and another principal's document.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_scoped_document',
  primaryKeyField: 'id',
)
@TomDbScope(field: 'owner_id', scope: 'owner')
class FixtureScopedDocumentRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The scope field: the principal id that may see this row.
  @TomDbColumn(columnName: 'owner_id')
  int? ownerId;

  /// An ordinary column, so a scoped row is more than its file.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The file column under scope. Exposed, so the same row is reachable through
  /// the HTTP file endpoint and the endpoint's status mapping can be asserted
  /// against it.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/scoped', exposed: true)
  String? attachment;
}

/// The MariaDB-backed repository for [FixtureScopedDocumentRecord].
class FixtureScopedDocumentRepository
    extends TomSqlDatasourceRepository<FixtureScopedDocumentRecord, int> {}

/// A reflected entity carrying a **resource key** and *no* `@TomDbScope`
/// (RCC5).
///
/// The missing annotation is the point. An entity whose rows are identified by
/// a resource key is scoped by the principal's grants automatically — the
/// analyzer synthesizes the annotation — so this fixture is what proves the
/// automatic path: if the scope had to be declared, every query below would
/// return every row.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_resource_document',
  primaryKeyField: 'id',
)
class FixtureResourceRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The resource this row belongs to — the key the C-5 grants and C-6
  /// delegations are written against, and so the value the row scope binds.
  @TomDbColumn(columnName: 'resource_key')
  String? resourceKey;

  /// An ordinary column, so a scoped row is more than its key.
  @TomDbColumn(columnName: 'title')
  String? title;
}

/// The MariaDB-backed repository for [FixtureResourceRecord].
class FixtureResourceRepository
    extends TomSqlDatasourceRepository<FixtureResourceRecord, int> {}

/// A reflected entity whose file columns cover the three exposure cases the
/// HTTP file endpoint has to tell apart (CSFSB1).
///
/// Separate from [FixtureDocumentRecord] rather than folded into it, for two
/// reasons. It has no table in `test_database.dart` and needs none — the
/// endpoint suite drives an in-memory repository, so only the *annotations* are
/// read — and leaving the older entity untouched is itself the assertion that
/// `exposed:` defaults closed: an entity written before HTTP exposure existed
/// must not have become reachable when the field was added.
///
/// - [poster] is plainly exposed: the slot `fixture_file_slot/<id>/poster`;
/// - [gradedPoster] is exposed *and* carries an `authKey`, so it is the column
///   that proves exposure decides only *which* column a slot names — the C-4
///   grade still decides whether the caller may have it;
/// - [internalNotes] is exposed to nobody, and is unreachable by name.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_file_slot',
  primaryKeyField: 'id',
)
class FixtureFileSlotRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, so the entity is more than its files.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The plainly exposed file column.
  @TomDbColumn(columnName: 'poster')
  @TomFileReference(keyPrefix: 'fixture/poster', exposed: true)
  String? poster;

  /// An exposed file column that is also C-4 graded.
  @TomDbColumn(
    columnName: 'graded_poster',
    authKey: 'fixture.file_slot.graded_poster',
  )
  @TomFileReference(keyPrefix: 'fixture/graded', exposed: true)
  String? gradedPoster;

  /// A file column that is *not* exposed, and so has no slot at all.
  @TomDbColumn(columnName: 'internal_notes')
  @TomFileReference(keyPrefix: 'fixture/internal')
  String? internalNotes;
}

/// A reflected entity whose two file columns collide on a name (CSEXD3).
///
/// This is the shape `TomFileSlots._assertUnambiguous` exists to reject, built
/// so that the *consequence* of not rejecting it is visible and not merely
/// asserted about. A slot serves its column by handing the column's **declared**
/// name to the repository, and the repository resolves a file field by declared
/// name **or** mapped column name, first match wins in declaration order. So:
///
/// - [notes] is closed (`exposed:` defaults to `false`) and is *mapped* to the
///   column name `dossier`;
/// - [dossier] is exposed, and its *declared* name is `dossier`.
///
/// The exposed column would therefore publish the slot
/// `fixture_ambiguous_slot/<id>/public_dossier` and ask the repository for the
/// field `dossier` — which [notes], declared first, answers to. The published
/// column would serve the closed column's bytes: an exposure by accident, which
/// is precisely what the `exposed: false` default is supposed to make
/// impossible.
///
/// It maps to no table in `test_database.dart` and needs none — registration
/// fails before any row is ever read.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_ambiguous_slot',
  primaryKeyField: 'id',
)
class FixtureAmbiguousSlotRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The closed column — declared *first*, so it is the one a lookup by the
  /// colliding name finds.
  @TomDbColumn(columnName: 'dossier')
  @TomFileReference(keyPrefix: 'fixture/ambiguous/closed')
  String? notes;

  /// The exposed column, whose declared name is the closed column's mapped one.
  @TomDbColumn(columnName: 'public_dossier')
  @TomFileReference(keyPrefix: 'fixture/ambiguous/open', exposed: true)
  String? dossier;
}

/// A reflected entity that holds an exposed file column but declares no
/// `@TomDbTable` (CSEXD3).
///
/// A slot is addressed as `<table>/<id>/<column>` and the table name comes from
/// the mapping, so an unmapped entity has no name to be addressed by. The
/// endpoint says so at wire-up time rather than resolving to something arbitrary
/// — the entity has no persistent identity at all, so `exposed: true` on it is a
/// declaration that cannot be honoured, not one to be honoured approximately.
///
/// Deliberately carries no `@TomDbColumn`: an entity with no table has no
/// persistent columns by definition, and annotating them would only assert that
/// two annotations disagree rather than that one is missing.
@tomReflector
class FixtureUnmappedFileRecord {
  /// Would-be identity, mapped by nothing.
  int? id;

  /// An exposed file column on an entity that has nowhere to live.
  @TomFileReference(keyPrefix: 'fixture/unmapped', exposed: true)
  String? attachment;
}

/// A reflected entity covering every case the reflected export projection has
/// to decide (CSEXC5).
///
/// One entity rather than several, because the interesting property is that a
/// *single* declaration answers all of them at once:
///
/// - [id], [title], [amount], [done] and [createdAt] cover all five
///   `TomColumnType`s, so the derived types can be asserted without a second
///   fixture per type;
/// - [secret] is named in `@TomAudited(redact:)` — the value that must not
///   exist in a second place, and an export is a second place;
/// - [attachment] is a `@TomFileReference`, holding an internal storage key
///   rather than content;
/// - [tag] is a `TomZonedDate`, whose *storage* family is `date` but whose Dart
///   value is not a `DateTime` — the case that proves the derivation falls back
///   to text when the declared Dart type cannot inhabit the candidate type.
///
/// It maps to no table in `test_database.dart` and needs none: only the
/// annotations are read.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_export',
  primaryKeyField: 'id',
)
class FixtureExportRecord {
  /// Surrogate primary key — derives `TomColumnType.integer`.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A text column — derives `TomColumnType.text`.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// A fractional column — derives `TomColumnType.decimal`.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// A truth column — derives `TomColumnType.boolean`.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// A point in time — derives `TomColumnType.timestamp`.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;

  /// A date whose Dart value is not a `DateTime` — derives text.
  @TomDbColumn(columnName: 'tag_day')
  TomZonedDate? tagDay;

  /// The redacted column: never exported.
  @TomDbColumn(columnName: 'secret')
  String? secret;

  /// The file-reference column: holds a storage key, not content.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/export')
  String? attachment;
}

/// [FixtureExportRecord] **after a column was added** — the second half of the
/// drift assertion (CSEXC5).
///
/// The point of deriving export columns from reflection is that adding a column
/// to an entity adds it to the export with no other edit. That claim needs two
/// entity versions to be testable at all, and an entity cannot grow a field at
/// run time — so this is that version: identical to [FixtureExportRecord] but
/// for [owner]. A test asserting the derived column sets differ by exactly
/// `owner`, with no export-side change between them, is what makes the claim an
/// assertion rather than a comment.
@tomReflector
@TomAudited(redact: ['secret'])
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_export_v2',
  primaryKeyField: 'id',
)
class FixtureExportRecordV2 {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A text column.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// A fractional column.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// A truth column.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// A point in time.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;

  /// A date whose Dart value is not a `DateTime`.
  @TomDbColumn(columnName: 'tag_day')
  TomZonedDate? tagDay;

  /// The redacted column.
  @TomDbColumn(columnName: 'secret')
  String? secret;

  /// The file-reference column.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'fixture/export')
  String? attachment;

  /// **The added column** — the whole point of this second version.
  @TomDbColumn(columnName: 'owner')
  String? owner;
}

/// A reflected entity that has **declared itself out** of the audit trail.
///
/// The escape hatch for high-volume machine-written tables (sessions, job runs)
/// whose mutations are noise rather than history. It is a declaration rather
/// than a call-site flag precisely so that its absence is auditable too — this
/// fixture exists to prove the reflector resolves it.
@tomReflector
@TomAudited(enabled: false)
class FixtureUnauditedRecord {
  /// An ordinary field; the type is never persisted, only reflected.
  String? note;
}

/// A reflected entity whose columns are `DECIMAL` (CSEXE1).
///
/// `DECIMAL` is the correct SQL type for money — it is exact where `DOUBLE` is
/// approximate — so this is the shape an ordinary business entity has, not an
/// exotic one. It is nonetheless the shape no fixture had: every other entity
/// here stores fractional values in a column the driver already converts, which
/// is why the driver's `NEWDECIMAL` gap stayed invisible on the entity-mapping
/// paths long after it was found and fixed for grouped rows.
///
/// The two numeric columns are deliberately different declarations over the
/// same SQL family:
///
/// - [amount] is `DECIMAL(10,2)` read into a Dart `double` — the money case;
/// - [quantity] is `DECIMAL(10,0)` read into a Dart `int` — the exact-integer
///   case, which is legitimate (`DECIMAL(n,0)` *is* an integer type, and wide
///   identifiers are often declared that way) and must therefore not be
///   rejected merely for being `DECIMAL`.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_amount',
  primaryKeyField: 'id',
)
class FixtureAmountRecord {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// A plain string column, so the entity has a non-numeric field to assert
  /// against and the failure can be localised to the numeric ones.
  @TomDbColumn(columnName: 'label')
  String? label;

  /// The money column: `DECIMAL(10,2)` bound to a Dart `double`.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// The exact-integer column: `DECIMAL(10,0)` bound to a Dart `int`.
  @TomDbColumn(columnName: 'quantity')
  int? quantity;
}

/// The MariaDB-backed repository for [FixtureAmountRecord].
class FixtureAmountRepository
    extends TomSqlDatasourceRepository<FixtureAmountRecord, int> {}

/// A **table-less reflected result holder** with a `double` field (CSEXE1).
///
/// Carries no `@TomDbTable` and no `@TomDbColumn`, so the row mapper populates
/// it by matching *declared field names* against result-column names — the
/// third of the four entity-mapping variants, and the one an aggregate query
/// naturally lands on. `SUM(amount)` over a `DECIMAL` column is itself
/// `NEWDECIMAL`, so this type reaches the same driver gap by a different route
/// than [FixtureAmountRecord] does.
@tomReflector
class FixtureAmountSummary {
  /// The aggregate, projected as `total`.
  double? total;

  /// A row count projected as `entries`, so the holder covers an `int` field
  /// on the same path.
  int? entries;
}

/// A [TomClass]-shaped result holder with a `double` member (CSEXE1).
///
/// The first two entity-mapping variants map a [TomClass] by its *observable
/// members* rather than by reflected fields, and they are reached only by a
/// [TomClass] result type — which no fixture previously provided. Without this
/// type those two `typedColByName<double>` call sites are unreachable from any
/// test, and a fix to them would be unverifiable.
///
/// The members are the **non-nullable** observables deliberately, and stay that
/// way. `TomObject<T>` reports its element type as declared, so a `TomNDouble`
/// answers `double?` while a `TomDouble` answers `double`; the row mapper
/// normalises the former onto the latter before dispatching (CSEXF1). This
/// fixture is therefore the one that covers the *un-normalised* half of that
/// dispatch — the path where the declared type already matches and the
/// normaliser passes it through untouched. Its nullable counterparts,
/// [FixtureNullableObservable] and [FixtureNullableRecord], cover the other
/// half. Switching this one to `TomNDouble`/`TomNInt` would leave the
/// pass-through branch with no coverage at all, and would also blur the driver
/// gap this fixture exists to expose with the type-matching concern that is not
/// its subject.
@tomReflector
class FixtureAmountObservable extends TomClass {
  /// The fractional member, matched to a result column named `amount`.
  final amount = TomDouble(0);

  /// An integer member, matched to a result column named `quantity`.
  final quantity = TomInt(0);
}

/// A **table-less** [TomClass] whose members are all *nullable* observables
/// (CSEXF1).
///
/// `TomObject<T>.getType()` answers `T` as declared, so a [TomNString] reports
/// `String?`. The row mapper switched on that answer with `case String:`, which
/// a `String?` never matches — so every member of a holder like this one fell
/// to the `default:` branch and was refused by name. The nullable observables
/// are the ordinary choice for a column that can be `NULL`, which is most
/// columns, so this is the shape an everyday result holder has.
///
/// It carries one member per supported element type, because the defect was in
/// the *dispatch* rather than in any one conversion: a fix that handled
/// `String?` and stopped there would leave the other four still refused.
///
/// Member names match the result-column names exactly — that is how the
/// table-less variant binds. `occurredAt` is reached through a `SELECT
/// occurred_at AS occurredAt`, keeping the Dart name lowerCamelCase without
/// renaming the column.
@tomReflector
class FixtureNullableObservable extends TomClass {
  /// Nullable text, over `VARCHAR(255)`.
  final name = TomNString(null);

  /// Nullable fractional value, over `DOUBLE`.
  final ratio = TomNDouble(null);

  /// Nullable integer, over `INT`.
  final quantity = TomNInt(null);

  /// Nullable boolean, over `TINYINT(1)`.
  final active = TomNBool(null);

  /// Nullable timestamp, over `DATETIME`.
  final occurredAt = TomNDateTime(null);
}

/// The `@TomDbTable`-annotated counterpart of [FixtureNullableObservable]
/// (CSEXF1).
///
/// The two [TomClass] mapping variants are near-duplicates that differ only in
/// how they find the column for a member: the table-less one matches member
/// name against result-column name, this one walks
/// `TomAnnotationAnalyzer.getPersistentColumns` and looks the member up by
/// `declaredName`. They carried the *same* defective switch, so a fix verified
/// on only one of them would be half a fix — hence a fixture for each.
///
/// Being annotated also lets the member names differ from the column names
/// ([occurredAt] over `occurred_at`), which is the normal case for an entity
/// and the reason the annotated variant exists at all.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_nullable',
  primaryKeyField: 'id',
)
class FixtureNullableRecord extends TomClass {
  /// Surrogate primary key, assigned by the database on insert.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  final id = TomNInt(null);

  /// Nullable text, over `VARCHAR(255)`.
  @TomDbColumn(columnName: 'name')
  final name = TomNString(null);

  /// Nullable fractional value, over `DOUBLE`.
  @TomDbColumn(columnName: 'ratio')
  final ratio = TomNDouble(null);

  /// Nullable integer, over `INT`.
  @TomDbColumn(columnName: 'quantity')
  final quantity = TomNInt(null);

  /// Nullable boolean, over `TINYINT(1)`.
  @TomDbColumn(columnName: 'active')
  final active = TomNBool(null);

  /// Nullable timestamp, over `DATETIME` — declared under a name that differs
  /// from its column, which only the annotated variant can express.
  @TomDbColumn(columnName: 'occurred_at')
  final occurredAt = TomNDateTime(null);
}

/// The repository over [FixtureNullableRecord] — the *observable-membered*
/// entity — which exists to show that this shape does not survive the **write**
/// path (`qrc1`).
///
/// [FixtureNullableRecord] maps fine on the way *in*: the row mapper normalises
/// a `String?` onto `String` before dispatching, which is what CSEXF1 fixed. The
/// way *out* is a different mechanism entirely. [TomSqlDatasourceRepository.save]
/// binds each column from `TomColumnInformation.getVariableValue`, which is
/// `invokeGetter(declaredName)` — the *field*, not the observable's value. On a
/// `TomNString` member that yields the `TomNString` object itself, so the
/// statement would bind an observable where the driver expects a scalar.
///
/// That asymmetry is the evidence behind the `@CsColumn` emission rule: an
/// optional CE-DB column emits a plain nullable Dart field (`String?`), not a
/// `TomN*` observable. [FixtureOptionalColumnRecord] is the arm that does
/// round-trip, and the two repositories are declared side by side so the
/// comparison is a test rather than a claim.
class FixtureNullableRepository
    extends TomSqlDatasourceRepository<FixtureNullableRecord, int> {}

/// The **plain-field** counterpart of [FixtureNullableRecord], carrying one
/// optional column of each of the five persistable value types (`qrc1`).
///
/// This is the shape a CE-DB entity actually has — the shipped
/// [TomUserPreference] declares its own optional column as a bare
/// `DateTime? updatedAt`, and the CodeSpecs derivation contract's worked example
/// emits `late final String name;`. A CE-DB entity is a plain annotated model
/// class, so its optional arm is a plain nullable field.
///
/// It maps to the same `fixture_nullable` table as [FixtureNullableRecord] on
/// purpose: the two entities differ in exactly one respect — whether a member is
/// an observable or a plain field — and holding the storage constant is what
/// makes the difference in outcome attributable to that one respect. Suites run
/// serialized (`dart_test.yaml` `concurrency: 1`), so sharing the table costs
/// nothing.
///
/// All five types, because the rule is stated for all five and a round trip
/// verified on `String?` alone would say nothing about `DateTime?` — which is
/// the one with a genuinely separate conversion on both the read and the write
/// side.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_nullable',
  primaryKeyField: 'id',
)
class FixtureOptionalColumnRecord {
  /// Surrogate primary key — `null` until first persisted.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Optional text, over `VARCHAR(255)`.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Optional fractional value, over `DOUBLE`.
  @TomDbColumn(columnName: 'ratio')
  double? ratio;

  /// Optional integer, over `INT`.
  @TomDbColumn(columnName: 'quantity')
  int? quantity;

  /// Optional boolean, over `TINYINT(1)`.
  @TomDbColumn(columnName: 'active')
  bool? active;

  /// Optional timestamp, over `DATETIME`, under a name that differs from its
  /// column.
  @TomDbColumn(columnName: 'occurred_at')
  DateTime? occurredAt;
}

/// The MariaDB-backed repository for [FixtureOptionalColumnRecord].
class FixtureOptionalColumnRepository
    extends TomSqlDatasourceRepository<FixtureOptionalColumnRecord, int> {}

/// A **third** projection of `fixture_nullable` that keys it differently — the
/// entity model contradicting itself (CSEX6).
///
/// [FixtureNullableRecord] and [FixtureOptionalColumnRecord] are two honest
/// projections of one table: they disagree about member *shape* but agree that
/// `id` is the key, and merging them is correct. This one disagrees about the
/// key itself, and a table has exactly one primary key, so the two cannot both
/// be right. It exists so [TomEntitySchemaReader] can be shown *reporting* that
/// contradiction rather than silently letting whichever entity is read last
/// decide.
///
/// The key is declared through [TomDbTable.primaryKeyField] with no
/// `@TomEntityId` on any field, which is deliberate on two counts: it is the
/// weakest of the three key signals — the one a real entity is most likely to
/// key a projection by accident — and it exercises the field-to-column
/// resolution branch of `TomEntitySchemaReader.primaryKeyOf`.
///
/// It maps only the two columns it needs. Merging a subset changes nothing
/// about the table's column set, which keeps the difference in outcome
/// attributable to the key alone. No repository: nothing ever reads or writes
/// through it, so it needs no storage beyond the table that already exists.
@tomReflector
@TomDbTable(
  datasource: 'tom_core_server_test',
  table: 'fixture_nullable',
  primaryKeyField: 'name',
)
class FixtureRekeyedNullableRecord {
  /// The column this projection considers the key.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// An ordinary column, so the projection maps more than its key.
  @TomDbColumn(columnName: 'quantity')
  int? quantity;
}

/// A reflected **preference value** — the object shape a user preference is
/// stored as when it is not a scalar (TCCA10).
///
/// The point of [TomUserPreferences] taking `@tomReflector` values is that a
/// preference can be a structured choice rather than a stringly-typed blob, and
/// nothing proves that except a value that is genuinely reconstructed: the codec
/// resolves `T` through `tomReflector.reflectType`, so a class the generator has
/// not captured fails at the *decode*, not at the write. Declaring it here is
/// therefore what makes the round-trip assertion meaningful.
///
/// The fields are plain and non-`final` because that is what
/// `createInstanceFromJson` fills — it constructs a blank instance and assigns
/// members, so a `final` field would come back at its default no matter what was
/// stored. They cover the three JSON shapes a preference object realistically
/// mixes (text, number, flag), so a decode that dropped one type would be
/// visible.
@tomReflector
class FixtureDisplayPreference {
  /// A text member — the theme the user picked.
  String theme = '';

  /// A numeric member, exercising the `int` branch inside an object rather than
  /// as a top-level scalar.
  int fontSize = 0;

  /// A boolean member.
  bool compact = false;
}
