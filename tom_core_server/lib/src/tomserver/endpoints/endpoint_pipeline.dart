import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../little_things/request_id.dart';
import '../little_things/server_exception.dart';
import '../server/server.dart';
import '../transactions/transaction_manager.dart';

import 'endpoint_annotation.dart';
import 'endpoint_results.dart';
import 'form_binding.dart';
import 'web_socket_endpoint.dart';

/// The error key a pre-invocation access denial is raised under.
///
/// Exported because it is a *wire* string in every sense that matters: the
/// audit trail records it, the framework's own suites assert it, and a
/// deployment writing its own refusal policy needs to name the one the pipeline
/// raises. It was hand-copied into two sample servers before it had a name
/// here, which is the shape of a constant the framework declined to own.
///
/// It does not reach the caller. A denied request answers a bare `404` — see
/// [TomEndpointHandler.accessDeniedResponse] — so this key names the event on
/// the *server* side, in the audit record and the log, and nowhere else.
const String tomEndpointAccessDeniedErrorKey =
    'endpoint_handler.handle_method_call.access_denied';

/// Thrown while *serving* a request: access denied, parameter instantiation
/// failure, a failing error handler, or a result that cannot be converted.
class TomEndpointHandlerException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomEndpointHandlerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Thrown while *building* the router from reflected metadata: conflicting
/// annotations, an invalid component reference, an unknown HTTP method, etc.
class TomEndpointPipelineException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomEndpointPipelineException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Occupies the slot of a parameter no binding strategy could fill.
///
/// A positional argument list cannot express "absent" — leaving a parameter out
/// does not leave it unset, it shortens the list and moves everything after it
/// one place to the left. So binding fills one slot per declared parameter and
/// marks the ones it could not resolve, and the shape of the call is decided
/// afterwards, when the whole picture is visible. Only then is it knowable
/// whether an unfilled slot is a trailing optional (droppable) or a hole
/// (not).
class _UnboundParameter {
  const _UnboundParameter();
  @override
  String toString() => '<unbound>';
}

/// The single marker instance; compared by [identical], so no real bound value
/// can be mistaken for it.
const _UnboundParameter _unbound = _UnboundParameter();

/// The [Type] object for [T].
///
/// The detour through a type parameter exists for one member of
/// [_noResultReturnTypes]: `void` is not writable in a value position, so
/// `void` alone is a syntax error while `_typeOf<void>()` is not.
Type _typeOf<T>() => T;

/// The declared return types that say an endpoint answers with no body.
///
/// Both spellings of the same promise: `Future<void>` for the asynchronous
/// endpoints that are nearly all of them, `void` for a synchronous one. Neither
/// erases a value at runtime, which is exactly why the declaration has to be
/// consulted rather than the result inspected — see
/// [TomEndpointHandler.declaresNoResult].
final Set<Type> _noResultReturnTypes = {
  _typeOf<Future<void>>(),
  _typeOf<void>(),
};

/// Serves one endpoint: binds a reflected service [method] to a route and runs
/// the per-request pipeline.
///
/// For each request [handleMethodCall] answers CORS preflight, enforces access
/// ([checkAccess] / [checkAutomaticAccess]), materialises the method's
/// parameters from the request (principal/token from the zone, the request
/// object, path/query params, JSON body, request or execution context),
/// optionally wraps the call in a transaction, invokes the method by reflection,
/// and converts the result (or any error, via the endpoint's [TomErrorHandler])
/// into a shelf `Response`.
class TomEndpointHandler {
  /// A human-readable identifier for the route (used in logs).
  String name;

  /// The reflected service instance the method is invoked on.
  InstanceMirror instance;

  /// The reflected endpoint method.
  MethodMirror method;

  /// The service interface/annotation type, when routed via an interface.
  ///
  /// `null` for a registry-backed method, which is identified by its contract
  /// instead — see [automaticProtectionKeys], the one thing this is read for.
  ClassMirror? interface;

  /// The concrete implementation class mirror.
  ClassMirror implementation;

  /// The method's own name, unqualified, as it appears in a resource key
  /// (`<Interface>.<methodName>`).
  String methodName;

  /// The collected annotation metadata (endpoint, access, transaction, API).
  TomMethodMetadata metadata;

  /// Creates a handler from the resolved instance, method, and metadata.
  TomEndpointHandler({
    required this.name,
    required this.instance,
    required this.method,
    this.interface,
    required this.implementation,
    required this.methodName,
    required this.metadata,
  });

  /// Whether this endpoint's declaration promises the caller no result, so that
  /// the response body is empty whatever the invocation completes with.
  ///
  /// `Future<void>` does not erase the value it completes with, and Dart lets an
  /// implementation narrow the return type: a method declared `Future<void>`
  /// whose body tail-calls one returning `Future<int>` — every delete endpoint
  /// forwarding to [TomRepository.deleteById] does — hands the pipeline an `int`
  /// while every static type between the two says there is nothing there. The
  /// value cannot be recognised once it arrives, so the declaration is asked
  /// instead.
  ///
  /// Read off [TomMethodMetadata.methodMirror] — the declaration the
  /// `@TomEndpoint` annotation sits on — rather than off [method], the
  /// implementation's. They differ exactly when the implementation narrows, and
  /// the annotated one is both the wider of the two and the contract: the
  /// client's typed proxy is generated from it and has nowhere to put a body.
  ///
  /// A reflector without `reflectedTypeCapability` cannot answer, and then the
  /// endpoint keeps the ordinary treatment — an unrenderable result is a failure
  /// there, which is the right answer for a *genuinely* unrenderable one.
  late final bool declaresNoResult =
      metadata.methodMirror.hasReflectedReturnType &&
      _noResultReturnTypes.contains(metadata.methodMirror.reflectedReturnType);

  /// Coerces a raw URL string (a matched path variable *or* a query-string
  /// value) into the method parameter's primitive [type], or returns `null`
  /// when [type] is not a bindable primitive (so the caller falls through to
  /// the other binding strategies).
  ///
  /// Such values always arrive as strings, so the numeric/bool forms are
  /// parsed; an unparsable numeric value yields `null` (treated as "could not
  /// bind"). `bool` follows the URL convention where only the literal `true` is
  /// truthy.
  static Object? coercePrimitiveParameter(Type type, String raw) {
    if (type == String) return raw;
    if (type == int) return int.tryParse(raw);
    if (type == double) return double.tryParse(raw);
    if (type == num) return num.tryParse(raw);
    if (type == bool) return raw == 'true';
    return null;
  }

  /// Folds the request's URL path parameters into [jsonBodyData] under the
  /// request-DTO field names declared by [endpoint].`urlParameterMapping`.
  ///
  /// Each captured path parameter (shelf route capture, e.g. `id` from
  /// `/items/{id}`) is written under its mapped field name — or, when the
  /// mapping has no entry for it, under its own capture name (identity). This
  /// is what lets a typed request DTO receive `/items/{id}` as `request.id`
  /// (or `request.itemId` with a `{'id': 'itemId'}` mapping) without a
  /// bare-`String` handler parameter (G-API-2). Called immediately before the
  /// DTO is instantiated from the folded map.
  ///
  /// Pure and side-effect-free apart from mutating [jsonBodyData], so it is
  /// unit-testable without a live router (like [coercePrimitiveParameter]).
  static void injectPathParameters(
    Map<String, dynamic> jsonBodyData,
    Request req,
    TomEndpoint endpoint,
  ) {
    final mapping = endpoint.urlParameterMapping;
    req.params.forEach((captureName, value) {
      jsonBodyData[mapping[captureName] ?? captureName] = value;
    });
  }

  /// Folds the request's *query-string* parameters into [jsonBodyData] under
  /// the request-DTO field names declared by [endpoint].`urlParameterMapping`.
  ///
  /// Only query parameters that the mapping **names explicitly** are folded —
  /// unlike [injectPathParameters], there is no identity fallback. A path
  /// capture is part of the route and therefore part of the endpoint's own
  /// declaration, so binding it by its own name is safe; a query string is
  /// whatever a caller chose to append, so an identity fallback would let any
  /// caller write any field of the request DTO of any endpoint. Requiring the
  /// mapping makes query binding opt-in per contract and per parameter, and
  /// leaves every existing endpoint's behaviour unchanged.
  ///
  /// This is what lets a redirect target — `GET /oauth/callback?code=…&state=…`,
  /// which a browser navigates to with no body at all — arrive as a typed DTO
  /// rather than a handful of bare `String` parameters (G-API-2). It is also
  /// where a provider's snake_cased spelling (`error_description`) is translated
  /// into the Dart field name, so the wire convention stops at the contract.
  ///
  /// Called *before* [injectPathParameters], so a path capture of the same
  /// mapped name still wins: the route is the stronger statement.
  ///
  /// Pure and side-effect-free apart from mutating [jsonBodyData], so it is
  /// unit-testable without a live router (like [coercePrimitiveParameter]).
  static void injectQueryParameters(
    Map<String, dynamic> jsonBodyData,
    Request req,
    TomEndpoint endpoint,
  ) {
    final mapping = endpoint.urlParameterMapping;
    if (mapping.isEmpty) return;
    final queryParameters = req.requestedUri.queryParameters;
    if (queryParameters.isEmpty) return;
    mapping.forEach((queryName, fieldName) {
      final value = queryParameters[queryName];
      if (value != null) jsonBodyData[fieldName] = value;
    });
  }

  /// Folds the *text* parts of a decoded `multipart/form-data` body into
  /// [jsonBodyData], so the request DTO is built from a form exactly as it is
  /// built from a JSON body.
  ///
  /// [TomEndpoint.formFields] decides which parts are folded, and its two
  /// states mean genuinely different things:
  ///
  /// * **empty** — fold every text part. A request body is the endpoint's own
  ///   contract, just as a JSON body is, and a JSON body is not filtered
  ///   field-by-field either. Nothing is gained by making the ordinary case
  ///   restate the DTO's field list.
  /// * **non-empty** — an allow-list: only the named parts are folded. This is
  ///   for the endpoint whose form is filled in by something it does not
  ///   control (a payment provider's callback, a third-party webhook posting a
  ///   form), where the sender may add fields at will and only the declared
  ///   ones should reach the DTO.
  ///
  /// Note the asymmetry with [injectQueryParameters], which binds *only* what
  /// the mapping names. It is the same reasoning read in the other direction: a
  /// query string is appended by whoever typed the URL, whereas a body is what
  /// the endpoint asked for. Where that stops being true, `formFields` is the
  /// way to say so.
  ///
  /// File parts are not folded — see [TomFormFile], which binds as a method
  /// parameter, because an arbitrary object cannot travel through a JSON map
  /// into a reflected DTO.
  ///
  /// Called *before* [injectQueryParameters] and [injectPathParameters], so a
  /// URL value of the same name still wins: the route is the stronger
  /// statement, and a form field cannot override the row it is posted to.
  ///
  /// Pure and side-effect-free apart from mutating [jsonBodyData], so it is
  /// unit-testable without a live router (like [coercePrimitiveParameter]).
  static void injectFormFields(
    Map<String, dynamic> jsonBodyData,
    TomMultipartForm form,
    TomEndpoint endpoint,
  ) {
    final declared = endpoint.formFields;
    if (declared.isEmpty) {
      jsonBodyData.addAll(form.fields);
      return;
    }
    for (final field in declared) {
      final value = form.fields[field];
      if (value != null) jsonBodyData[field] = value;
    }
  }

  /// Decodes a request body that is required to be a JSON **object**, or throws
  /// a named endpoint exception.
  ///
  /// Both failure modes are one answer to the client — *send a JSON object* —
  /// so both carry the same key rather than the bare `FormatException` /
  /// `TypeError` a raw `jsonDecode(...) as Map` produced. That key is worth
  /// distinguishing from the neighbouring `parameter_instantiation_failed`:
  /// this one says the bytes never were a field map, that one says they were
  /// and the DTO refused a value inside them. A client can act differently on
  /// each, which is the whole reason for naming them separately.
  static Map<String, dynamic> decodeJsonObjectBody(
    String body,
    ClassMirror parameterMirror,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (ex) {
      throw TomEndpointHandlerException(
        "endpoint_pipeline.handle_method_call.request_body_not_json",
        "Request body for ${parameterMirror.simpleName} is not valid JSON: $ex",
        autoLog: true,
        rootException: ex,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw TomEndpointHandlerException(
        "endpoint_pipeline.handle_method_call.request_body_not_json",
        "Request body for ${parameterMirror.simpleName} decoded to ${decoded.runtimeType}, but a JSON object is required to build the parameter.",
        autoLog: true,
      );
    }
    return decoded;
  }

  /// Whether requests are logged when an endpoint does not specify
  /// `logRequests`.
  static bool globalSettingLogRequestsDefault = true;

  /// Default `Access-Control-Allow-Origin` when an endpoint does not override it.
  static String globalSettingCorsAllowedOriginsDefault = "*";

  /// Default `Access-Control-Allow-Methods` when an endpoint does not override it.
  static String globalSettingCorsAllowedMethodsDefault =
      "GET, POST, PUT, DELETE, TRACE, PATCH, HEAD, CONNECT";

  /// Default `Access-Control-Allow-Headers` when an endpoint does not override it.
  static String globalSettingCorsAllowedHeadersDefault =
      "Origin, Content-Type, Accept, Authorization, Referer, User-Agent";

  /// When true, logs the request context for each call (debugging aid).
  static bool debugPrintContext = false;

  /// When true, logs the resolved principal/token for each call (debugging aid).
  static bool debugPrintAuthentication = false;

  /// Answers a CORS preflight (`OPTIONS`) request with the endpoint's (or the
  /// global default) allowed origins/methods/headers.
  Response handlePreflight(Request req) {
    return Response.ok(
      '',
      headers: {
        'Access-Control-Allow-Origin':
            metadata.endpoint.corsAllowedOrigins ??
            globalSettingCorsAllowedOriginsDefault,
        'Access-Control-Allow-Methods':
            metadata.endpoint.corsAllowedMethods ??
            globalSettingCorsAllowedMethodsDefault,
        'Access-Control-Allow-Headers':
            metadata.endpoint.corsAllowedHeaders ??
            globalSettingCorsAllowedHeadersDefault,
      },
    );
  }

  /// Records this endpoint's invocation in the audit trail, when the method
  /// declared `@TomAudited` (CE-LG).
  ///
  /// Endpoint invocation auditing is *declared*, not automatic: the pipeline
  /// cannot tell a read from a mutation, and auditing every call would bury the
  /// entries that matter under routine traffic. What is automatic here is the
  /// **denial** path — see [handleMethodCall] — and, at the other chokepoint,
  /// every repository mutation.
  Future<void> _recordInvocationAudit(
    TomAuditOutcome outcome, {
    String? detail,
  }) async {
    final audited = metadata.audited;
    if (audited == null || !audited.enabled) return;
    await TomAuditTrail.recordAction(
      action: TomAuditAction.execute,
      target: name,
      outcome: outcome,
      detail: detail,
    );
  }

  /// Enforces this endpoint's access rule for the principal in the current
  /// zone, auditing and throwing on a denial.
  ///
  /// Shared by every endpoint kind — the HTTP pipeline and the WebSocket
  /// handshake alike — because "may this caller reach this endpoint?" is the
  /// same question regardless of what happens after the answer is yes. A socket
  /// that authorized itself separately would be one place for the policy to
  /// drift out of step.
  Future<void> enforceAccess() async {
    final authentication = getFromCurrentZone<TomPrincipal>();
    bool accessCheck = checkAccess(authentication);

    if (accessCheck == false) {
      if (TomResourceKeyProtection
          .globalSettingUseAutomaticEndpointProtection) {
        accessCheck = checkAutomaticAccess(accessCheck);
      }
    }

    if (accessCheck) return;

    // CE-LG: a denial is audited unconditionally — no annotation, no opt-in.
    // It is the one auditable event the repository chokepoint cannot see,
    // because the request is refused before it reaches any data, and it is
    // the entry an auditor looks for first. Awaited, so a trail that cannot
    // store the denial fails the request rather than losing the record.
    await TomAuditTrail.recordAction(
      action: TomAuditAction.execute,
      target: name,
      outcome: TomAuditOutcome.denied,
      detail: "Access not granted and no resource key found for endpoint $name",
    );
    throw TomEndpointHandlerException(
      tomEndpointAccessDeniedErrorKey,
      "Access denied to endpoint, access not granted and resource key not found: $name",
    );
  }

  /// The response a denied caller receives: a bare `404`, indistinguishable
  /// from a route that does not exist.
  ///
  /// **A denial says nothing.** The alternative — `403`, which says "this
  /// exists and you may not have it" — hands an unauthorized caller a working
  /// oracle: walk the id space, read the statuses, and the ids that answer
  /// `403` are the rows that exist. That is a disclosure the caller was refused
  /// the data for, delivered by the refusal itself. The resource-key arm makes
  /// it concrete, because there the id *is* the thing being protected, but the
  /// contract arm leaks the same way at the level of the route: a `403` on
  /// `/admin/users` tells an anonymous prober that this deployment has an admin
  /// API and that the endpoint is spelled that way.
  ///
  /// So the body carries no [tomErrorEnvelope] and no error key either. An
  /// envelope naming `access_denied` on a `404` would undo the whole of it in
  /// one header — the status would say "nothing here" and the body would say
  /// "something here, and you may not have it".
  ///
  /// The diagnosis is not lost, it moves to where it belongs. The denial is
  /// audited unconditionally just above, with the principal, the endpoint and
  /// the outcome, and the exception's message reaches the server log. An
  /// operator asking "why did this caller get a 404" has a record; the caller
  /// does not.
  ///
  /// Not routed through [TomEndpoint.errorHandler], and that is deliberate.
  /// Those hooks exist for errors *of the invocation*, and a handler written
  /// for one — mapping a domain exception to a `409`, say — would be handed a
  /// security decision it was not written for. A deployment that genuinely
  /// wants `403` states it by returning one, not by inheriting a handler.
  static Response accessDeniedResponse() => Response.notFound(
    'Not found',
    headers: {TomHeader.contentType: TomMimeType.plainText.toHeaderValue()},
  );

  /// Materialises the endpoint method's positional arguments from [req].
  ///
  /// Each parameter is resolved by the first binding strategy that succeeds:
  /// a value supplied by the caller in [extraByType], the zone's
  /// [TomPrincipal] / [TomClientJwtToken], the request object itself, the
  /// request context (by type or by name), a primitive path or query value,
  /// the execution context, the decoded `multipart/form-data` body (whole form
  /// or a single file part), and finally the request DTO built from the JSON
  /// or form body folded together with the URL parameters.
  ///
  /// [extraByType] is how an endpoint *kind* contributes a value the generic
  /// strategies cannot know about — a WebSocket endpoint passes the
  /// [TomWebSocketConnection] this way. It is consulted first, so a kind-owned
  /// value is never shadowed.
  ///
  /// Shared by [handleMethodCall] and [handleWebSocketCall]: the two differ in
  /// what they do with the invocation, not in how the handler's parameters are
  /// found.
  Future<List<Object>> bindParameters(
    Request req, {
    Map<Type, Object> extraByType = const {},
  }) async {
    final List<Object> positionalArguments = [];

    final authentication = getFromCurrentZone<TomPrincipal>();
    final token = getFromCurrentZone<TomClientJwtToken>();
    final requestId = getFromCurrentZone<TomRequestId>();
    final reqId = requestId == null ? "" : requestId.uuid;

    // Read once, before the loop: a request body is a single-pass stream, so a
    // per-parameter decode would find it already drained. Decoding here also
    // means a malformed envelope fails before any argument is bound, rather
    // than half-way through.
    final TomMultipartForm? form = !tomConsumesForm(metadata.endpoint.consumes)
        ? null
        : tomConsumesMultipartForm(metadata.endpoint.consumes)
        ? await TomMultipartForm.readForm(req)
        : await TomMultipartForm.readUrlEncodedForm(req);

    if (debugPrintContext)
      tomLog.trace(
        "$reqId-${req.url}: Request context is ${req.context} TomPrincipal is $authentication",
      );
    if (debugPrintAuthentication)
      tomLog.trace(
        "$reqId-${req.url}: Found $authentication and $token for request",
      );
    for (var pm in method.parameters) {
      final supplied = extraByType[pm.type.reflectedType];
      if (supplied != null) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from the endpoint kind's supplied values",
        );
        positionalArguments.add(supplied);
        continue;
      }
      if (form != null && pm.type.reflectedType == TomMultipartForm) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} to the decoded multipart form",
        );
        positionalArguments.add(form);
        continue;
      }
      if (form != null && pm.type.reflectedType == TomFormFile) {
        // Bound by parameter *name*: the form field a file arrived under is
        // what identifies it, and the handler's parameter name is where the
        // endpoint states which one it wants.
        final file = form.file(pm.simpleName);
        if (file == null) {
          // Named rather than left to the arity mismatch this would otherwise
          // become: "the endpoint expects a file part called `attachment`" is
          // diagnosable, "wrong number of arguments" is not.
          throw TomFormBindingException(
            "endpoint_pipeline.bind_parameters.missing_file_part",
            "The form did not include the required file.",
            parameters: {"field": pm.simpleName, "endpoint": name},
          );
        }
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} to form file $file",
        );
        positionalArguments.add(file);
        continue;
      }
      if (pm.type.reflectedType == TomPrincipal && authentication != null) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} to TomPrincipal",
        );
        positionalArguments.add(authentication);
        continue;
      } else if (authentication == null) {
        tomLog.warn(
          "$reqId-${req.url}: Found parameter of type ${pm.type.reflectedType} but no TomPrincipal in zone.",
        );
      }
      if (pm.type.reflectedType == TomClientJwtToken && token != null) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} to TomClientJwtToken",
        );
        positionalArguments.add(token);
        continue;
      } else if (token == null) {
        tomLog.warn(
          "$reqId-${req.url}: Found parameter of type ${pm.type.reflectedType} but no TomClientJwtToken in zone.",
        );
      }
      if (req.runtimeType == pm.type.reflectedType) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} to request object",
        );
        positionalArguments.add(req);
        continue;
      }
      if (req.context.containsKey(pm.type.reflectedType.toString()) &&
          req.context[pm.type.reflectedType.toString()] != null &&
          req.context[pm.type.reflectedType.toString()].runtimeType ==
              pm.type.reflectedType) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from context using type ${pm.type.reflectedType.toString()}",
        );
        positionalArguments.add(req.context[pm.type.reflectedType.toString()]!);
        continue;
      }
      if (req.context.containsKey(pm.simpleName) &&
          req.context[pm.simpleName] != null &&
          req.context[pm.simpleName].runtimeType == pm.type.reflectedType) {
        tomLog.trace(
          "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from context using name.",
        );
        positionalArguments.add(req.context[pm.simpleName]!);
        continue;
      }
      // Primitive path variable (shelf_router capture, e.g. `/items/<id>`): bind
      // a bare String/num/bool method parameter directly from the matched route
      // value of the same name. A request DTO folds path variables in via
      // `jsonBodyData.addAll(req.params)` below, but a primitive parameter has
      // no DTO to carry it — without this branch it would never be bound and the
      // invocation would fail with the wrong argument count.
      final pathParam = req.params[pm.simpleName];
      if (pathParam != null) {
        final primitive = coercePrimitiveParameter(
          pm.type.reflectedType,
          pathParam,
        );
        if (primitive != null) {
          tomLog.trace(
            "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from path variable '$pathParam'.",
          );
          positionalArguments.add(primitive);
          continue;
        }
      }
      // Primitive query-string parameter (e.g. `GET /projects?workspaceId=`):
      // bind a bare String/num/bool method parameter from the query value of
      // the same name. Query parameters carry no shelf route capture (so they
      // are absent from req.params) and a GET has no JSON body to fold them into
      // — without this branch the parameter is never bound and the invocation
      // fails with the wrong argument count.
      final queryParam = req.requestedUri.queryParameters[pm.simpleName];
      if (queryParam != null) {
        final primitive = coercePrimitiveParameter(
          pm.type.reflectedType,
          queryParam,
        );
        if (primitive != null) {
          tomLog.trace(
            "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from query parameter '$queryParam'.",
          );
          positionalArguments.add(primitive);
          continue;
        }
      }
      var ctx = getFromCurrentZone<TomExecutionContext>();
      if (ctx != null) {
        var ctxValue = ctx.contextMap[pm.simpleName];
        if (ctxValue != null) {
          tomLog.trace(
            "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from execution context using name.",
          );
          positionalArguments.add(ctxValue.contextFunction());
          continue;
        }
      }
      try {
        ClassMirror parameterMirror =
            tomReflector.reflectType(pm.reflectedType) as ClassMirror;
        if ((metadata.endpoint.consumes == TomMimeType.json || form != null) &&
            req.method != TomHttpMethod.trace.name) {
          // A form and a JSON body are two spellings of the same thing here:
          // both end as a map of field names, and the DTO is built from that
          // map either way. Only the decoding differs — and the form has
          // already been decoded once, before the loop.
          //
          // Nothing here is wrapped in a catch of its own. Every failure below
          // is a statement about the *request* — bytes that are not a JSON
          // object, or a value the DTO refuses — and each leaves as a named
          // TomEndpointHandlerException that the caller is meant to receive.
          // Swallowing them left the parameter unbound and the request failing
          // much later inside `invoke` with a wrong-argument-count error that
          // named neither the parameter nor the body: the one diagnosis a
          // client cannot act on, produced from the one situation where the
          // client is the party who can fix it.
          String body = "";
          final Map<String, dynamic> jsonBodyData = {};
          if (form != null) {
            injectFormFields(jsonBodyData, form, metadata.endpoint);
            body = "$form";
          } else {
            body = await req.readAsString();
            // Fold the JSON body (when present) and the mapped URL parameters
            // into one map, then build the request DTO from it. URL parameters
            // must reach the DTO even for a body-less GET
            // (`GET /items/{id}` -> `request.id`), so the DTO is instantiated
            // whenever there is a body *or* at least one URL parameter.
            if (body.isNotEmpty) {
              jsonBodyData.addAll(decodeJsonObjectBody(body, parameterMirror));
            }
          }
          injectQueryParameters(jsonBodyData, req, metadata.endpoint);
          injectPathParameters(jsonBodyData, req, metadata.endpoint);
          if (jsonBodyData.isNotEmpty) {
            try {
              // Builds the parameter or throws — there is no null result to
              // test for.
              final parameterObject = tomReflectionInfo.createInstanceFromJson(
                parameterMirror,
                jsonBodyData,
              );
              positionalArguments.add(parameterObject);
              tomLog.trace(
                "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from jsonbody $body to $parameterObject ${req.params}",
              );
              continue;
            } on TomEndpointHandlerException {
              // Already named — re-wrapping would bury the specific key under
              // the generic one.
              rethrow;
            } catch (ex) {
              throw TomEndpointHandlerException(
                "endpoint_pipeline.handle_method_call.parameter_instantiation_failed",
                "Request body contains content for ${parameterMirror.simpleName} but instantiation from JSON $jsonBodyData failed: $ex",
                autoLog: true,
                rootException: ex,
              );
            }
          } else {
            // Not an error: "no body and no URL parameters" is how a body-less
            // request falls through to the context branch below, which is a
            // legitimate way to bind this parameter.
            tomLog.warn(
              "Was trying to set parameter ${pm.simpleName} ${pm.type.reflectedType} from json request to ${req.requestedUri} but body was empty and no URL parameters were present.",
            );
          }
        }
        if (req.context.isNotEmpty &&
            req.context.containsKey(parameterMirror.simpleName) &&
            req.context[parameterMirror.simpleName] != null) {
          try {
            if (req.context[parameterMirror.simpleName]
                is Map<String, Object?>) {
              // Builds the parameter or throws — there is no null result to
              // test for.
              final parameterObject = tomReflectionInfo.createInstanceFromJson(
                parameterMirror,
                req.context[parameterMirror.simpleName] as Map<String, Object?>,
              );
              positionalArguments.add(parameterObject);
              tomLog.trace(
                "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} value using map from context to $parameterObject ${req.context[parameterMirror.simpleName]}",
              );
              continue;
            } else {
              throw TomEndpointHandlerException(
                "endpoint_pipeline.handle_method_call.parameter_instantiation_invalid_type_in_context",
                "Request context contains an object for ${parameterMirror.simpleName} but it is neither of the type of the parameter nor Map<String, Object>.",
                autoLog: true,
              );
            }
          } on TomEndpointHandlerException {
            rethrow;
          } catch (ex) {
            throw TomEndpointHandlerException(
              "endpoint_pipeline.handle_method_call.parameter_instantiation_from_context_failed",
              "Request context contains content for ${parameterMirror.simpleName} but instantiation from JSON ${req.context[parameterMirror.simpleName]} failed: $ex",
              autoLog: true,
              rootException: ex,
            );
          }
        }
      } on TomEndpointHandlerException {
        rethrow;
      } catch (error) {
        throw TomEndpointHandlerException(
          "endpoint_pipeline.handle_method_call.parameter_instantiation_general_failure",
          "Could not instantiate parameter of type ${pm.reflectedType}: $error",
          autoLog: true,
          rootException: error,
        );
      }
      // No strategy matched. Mark the slot rather than skipping it: whether
      // this parameter may be left out at all is a question about the
      // parameters that come *after* it, which are not bound yet.
      tomLog.warn(
        "$reqId-${req.url}: Setting parameter ${pm.simpleName} of type ${pm.reflectedType} failed",
      );
      positionalArguments.add(_unbound);
    }
    return _toPositionalArguments(positionalArguments);
  }

  /// Turns the one-slot-per-parameter list built by [bindParameters] into the
  /// argument list [InstanceMirror.invoke] is called with, or throws naming the
  /// parameter that makes the call impossible.
  ///
  /// Exactly one shortening is legitimate: dropping *trailing* optionals, which
  /// is how Dart applies their defaults. Every other unfilled slot is refused,
  /// because there is no way to express it — an omission anywhere else silently
  /// moves later arguments into earlier parameters, and where the types happen
  /// to line up the method is invoked successfully with the wrong values in it.
  /// A named exception identifying the parameter is the alternative to that:
  /// "wrong number of arguments" points at the generated call site, this points
  /// at the declaration that cannot be satisfied.
  List<Object> _toPositionalArguments(List<Object> slots) {
    final parameters = method.parameters;
    final positional = <Object>[];
    final positionalParameters = <ParameterMirror>[];
    for (var i = 0; i < parameters.length; i++) {
      final parameter = parameters[i];
      if (parameter.isNamed) {
        // A named parameter holds no positional slot, so an unfilled one costs
        // nothing — its default applies. A *filled* one has nowhere to go: the
        // pipeline invokes with positional arguments only, so appending it
        // would put it in the slot of the next positional parameter.
        if (identical(slots[i], _unbound)) continue;
        throw TomEndpointHandlerException(
          "endpoint_pipeline.bind_parameters.named_parameter_not_supported",
          "Endpoint $name declares the named parameter '${parameter.simpleName}' of type ${parameter.type.reflectedType}, which request binding filled but cannot pass: endpoint methods are invoked with positional arguments only. Declare it positionally.",
          parameters: {"parameter": parameter.simpleName, "endpoint": name},
          autoLog: true,
        );
      }
      positional.add(slots[i]);
      positionalParameters.add(parameter);
    }

    var lastBound = -1;
    for (var i = 0; i < positional.length; i++) {
      if (!identical(positional[i], _unbound)) lastBound = i;
    }

    for (var i = 0; i < positional.length; i++) {
      if (!identical(positional[i], _unbound)) continue;
      final parameter = positionalParameters[i];
      if (!parameter.isOptional) {
        throw TomEndpointHandlerException(
          "endpoint_pipeline.bind_parameters.unbindable_parameter",
          "Endpoint $name requires the parameter '${parameter.simpleName}' of type ${parameter.type.reflectedType}, and no binding strategy could supply it from the request.",
          parameters: {"parameter": parameter.simpleName, "endpoint": name},
          autoLog: true,
        );
      }
      if (i < lastBound) {
        throw TomEndpointHandlerException(
          "endpoint_pipeline.bind_parameters.unbindable_optional_parameter",
          "Endpoint $name could not bind the optional parameter '${parameter.simpleName}' of type ${parameter.type.reflectedType}, but did bind '${positionalParameters[lastBound].simpleName}' after it. An optional parameter can only be omitted when every parameter following it is omitted too.",
          parameters: {"parameter": parameter.simpleName, "endpoint": name},
          autoLog: true,
        );
      }
    }

    return positional.sublist(0, lastBound + 1);
  }

  /// Runs the full request pipeline for this endpoint and returns the response.
  ///
  /// Handles preflight, access control ([enforceAccess]), reflection-based
  /// parameter binding ([bindParameters]), optional transaction wrapping,
  /// method invocation, and result/error conversion (see the class doc).
  ///
  /// A WebSocket endpoint takes the sibling path, [handleWebSocketCall], which
  /// shares the first two stages and replaces the rest with a socket lifetime.
  Future<Response> handleMethodCall(Request req) {
    // The current transaction is scoped to the flow that opened it, and the
    // server's authentication middleware normally establishes that scope for the
    // whole request. That middleware is replaceable
    // (`TomBaseServerConfiguration.authenticationMiddleware`), so this is a
    // guard rather than a second mechanism: a transactional endpoint makes sure
    // a scope exists instead of trusting the chain in front of it, because the
    // failure it prevents — one request committing another's work — is silent.
    if (metadata.transactionInfo == null ||
        TomTransactionManager.hasTransactionScope) {
      return _handleMethodCallInScope(req);
    }
    return TomTransactionManager.runInTransactionScope(
      () => _handleMethodCallInScope(req),
    );
  }

  Future<Response> _handleMethodCallInScope(Request req) async {
    if (req.method == TomHttpMethod.options.name) return handlePreflight(req);

    TomRequestLogInfo logInfo =
        req.context[TomRequestLogInfo.contextName] as TomRequestLogInfo;
    logInfo.shouldBeLogged = shouldLogRequests;

    final requestId = getFromCurrentZone<TomRequestId>();
    final reqId = requestId == null ? "" : requestId.uuid;

    try {
      await enforceAccess();
    } on TomEndpointHandlerException catch (denial) {
      if (denial.key != tomEndpointAccessDeniedErrorKey) rethrow;
      return accessDeniedResponse();
    }

    final List<Object> positionalArguments = await bindParameters(req);

    String callName = method.simpleName;

    Object? result;

    TomTransaction? transaction;

    try {
      if (metadata.transactionInfo != null) {
        tomLog.trace("$reqId-${req.url}: Starting transaction...");
        // `@TomTransactional(isReadOnly: true)` was declarable but discarded
        // here, so a read-only endpoint opened a read-write transaction and the
        // flag never reached the participants it is addressed to.
        (transaction, _) = TomTransactionManager.startTransaction(
          metadata.transactionInfo!.isReadOnly,
        );
      }
      tomLog.trace(
        "$reqId-${req.url}: Calling method $callName on ${instance.reflectee.runtimeType} with parameters $positionalArguments",
      );
      result = instance.invoke(callName, positionalArguments);
      if (result is Future) {
        result = await result;
      }
      if (transaction != null) {
        tomLog.trace("$reqId-${req.url}: Committing transaction...");
        await transaction.commitTransaction();
      }
    } catch (error, stacktrace) {
      // Always record the *cause* of an endpoint failure server-side. Without
      // this the only trace of a 500 was the response-summary line below, which
      // names neither the exception nor its stack — when an errorHandler turns
      // the throw into an opaque 500 the real cause was lost entirely, leaving
      // an undiagnosable failure. Log it once here, before the handler runs.
      tomLog.warn(
        "$reqId-${req.url}: $callName on ${instance.type.simpleName} threw $error\n$stacktrace",
      );
      if (transaction != null) {
        tomLog.warn(
          "$reqId-${req.url}: Rolling back transaction after exception $error",
        );
        await transaction.rollbackTransaction();
      }
      // CE-LG: an audited endpoint records its failures as well as its
      // successes. A trail that only shows what worked cannot answer "was this
      // attempted?", which is the question a failed privileged action raises.
      // Recorded after the rollback, so the outcome the entry states is final.
      await _recordInvocationAudit(TomAuditOutcome.failed, detail: "$error");
      if (metadata.endpoint.errorHandler != null) {
        Response? response;
        try {
          response = metadata.endpoint.errorHandler!.handleInvocationError(
            error,
            stacktrace,
            req,
          );
        } catch (error2, stacktrace2) {
          throw TomEndpointHandlerException(
            "endpoint_pipeline.handle_method_call.error_handler_failed",
            "Error handler for invocation error also failed on $callName on ${instance.type.simpleName} with parameters [$positionalArguments] context is ${req.context}: $error2",
            autoLog: true,
            rootException: error2,
            stack: stacktrace2,
            parameters: {
              "original_error": error,
              "original_stacktrace": stacktrace,
            },
          );
        }
        if (shouldLogRequests) {
          tomLog.info(
            "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name} /$reqId-${req.url} ${req.requestedUri} => ${response.statusCode} ${response.encoding} [handleInvocationError by error handler]",
          );
          logInfo.hasBeenLogged = true;
        }
        return response;
      } else {
        tomLog.warn(
          "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding} /$reqId-${req.url} ${req.requestedUri} Failed to call method $callName on ${instance.type.simpleName} with parameters [$positionalArguments] context is ${req.context}. No error handler. Rethrowing.",
        );
        logInfo.hasBeenLogged = true;
      }
      // will be converted to a structured error response in the pipeline
      rethrow;
    }
    // Recorded outside the try/catch above: inside it, an audit failure would
    // be caught as an invocation failure and trigger a rollback of a
    // transaction that has already committed.
    await _recordInvocationAudit(TomAuditOutcome.succeeded);
    try {
      // A redirect is fully described by a status and a URL, so the handler
      // states *what* it wants ([TomRedirect]) and the pipeline builds the
      // response. Turned into one here rather than recognised separately below,
      // so that a redirect and a handler-supplied Response share one exit and
      // one log line — the difference between them ends at this statement.
      if (result is TomRedirect) result = result.toResponse();
      // A handler that returns a shelf Response has already decided everything
      // this block would decide — status, headers, and a body that may be an
      // un-materialised stream. Answered first, before the conversion below,
      // because that conversion is `convertToJsonString(result)`: a Response is
      // neither a reflected DTO nor a JSON container, so converting it throws
      // and the handler's own answer is lost to a 500. This is the escape hatch
      // that makes streaming endpoints (see `TomFileService`) possible at all.
      if (result is Response) {
        if (shouldLogRequests) {
          tomLog.info(
            "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} => ${result.statusCode} [handler-supplied response]",
          );
          logInfo.hasBeenLogged = true;
        }
        return result;
      }
      // What the caller is owed, which is not always what arrived: an endpoint
      // declaring no result answers with no body however its implementation
      // completed (see [declaresNoResult]). `result` itself is left alone — the
      // error paths below report the value that really came back.
      final Object? body = declaresNoResult ? null : result;
      // A String is passed through rather than serialized: a handler that
      // returns one has already written the body, and encoding it again would
      // wrap it in quotes. Everything else is the kernel's outbound entry
      // point, which honours every rendering hook the framework recognises and
      // takes the JSON containers as well. So the chain a transport is tempted
      // to write here (TomClass, TomJsonSerializable, Map, List, then
      // reflection) is not shortened but *absent*: restating that policy in a
      // transport is how a server and a client come to disagree about which
      // hooks a type has.
      String? resultString = body == null
          ? null
          : body is String
          ? body
          : tomReflectionInfo.convertToJsonString(body);

      Response? response;
      if (resultString != null) {
        Map<String, Object> headers = {
          TomHeader.contentType: metadata.endpoint.produces.toHeaderValue(),
        };
        if (metadata.endpoint.headers.isNotEmpty) {
          for (var name in metadata.endpoint.headers.keys) {
            headers[name] = metadata.endpoint.headers[name]!;
          }
        }
        if (metadata.endpoint.contentDisposition != null) {
          headers[TomHeader.contentDisposition] =
              metadata.endpoint.contentDisposition!;
        }
        response = Response.ok(
          resultString,
          headers: headers,
          encoding: Encoding.getByName(metadata.endpoint.produces.charset),
        );
      }
      if (body == null) {
        response = Response.ok("");
      }
      response ??= Response.internalServerError(
        body: "Internal result processing failed.",
      );
      if (shouldLogRequests) {
        tomLog.info(
          "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} => ${response.statusCode} ${metadata.endpoint.produces} ${response.encoding?.name} [Normal processing]",
        );
        logInfo.hasBeenLogged = true;
      }
      return response;
    } catch (error, stacktrace) {
      if (metadata.endpoint.errorHandler != null) {
        try {
          Response response = metadata.endpoint.errorHandler!
              .handleConversionError(error, stacktrace, req, result);
          if (shouldLogRequests) {
            tomLog.info(
              "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} => ${response.statusCode} ${response.encoding} [handleConversionError]",
            );
            logInfo.hasBeenLogged = true;
          }
          return response;
        } catch (error2, stacktrace2) {
          throw TomEndpointHandlerException(
            "endpoint_pipeline.handle_method_call.conversion_error_handler_failed",
            "Error handler for conversion error also failed on $callName on ${instance.type.simpleName} with parameters [$positionalArguments] context is ${req.context}: $error2",
            autoLog: true,
            rootException: error2,
            stack: stacktrace2,
            parameters: {
              "original_error": error,
              "original_stacktrace": stacktrace,
            },
          );
        }
      } else {
        tomLog.warn(
          "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} Failed to convert result from $callName on ${instance.type.simpleName} with parameters [$positionalArguments] context is ${req.context}. Result was $result. No errorHandler.",
        );
        logInfo.hasBeenLogged = true;
        throw TomEndpointHandlerException(
          "endpoint_pipeline.handle_method_call.result_conversion_failed_no_error_handler",
          "Failed to convert result from $callName on ${instance.type.simpleName} with parameters [$positionalArguments] context is ${req.context}. Result was $result. No errorHandler.",
          rootException: error,
          stack: stacktrace,
        );
      }
    }
  }

  /// Serves a WebSocket handshake for this endpoint and runs the handler for
  /// the lifetime of the accepted connection.
  ///
  /// The first two stages are the HTTP pipeline's own — [enforceAccess] and
  /// [bindParameters] — and run *before* the upgrade, so an unauthorized or
  /// unbindable call is refused as an ordinary HTTP error rather than as a
  /// socket that opens and immediately dies. What replaces the rest of the
  /// pipeline is the socket's lifetime: the handler is invoked once, with the
  /// live [TomWebSocketConnection] among its arguments, and the socket is
  /// closed when it returns.
  ///
  /// A transaction is deliberately not offered here — see the mounting check in
  /// `createRoutesForEndpoint`.
  Future<Response> handleWebSocketCall(Request req) async {
    if (req.method == TomHttpMethod.options.name) return handlePreflight(req);

    final declaration = metadata.webSocket;
    if (declaration == null) {
      throw TomWebSocketException(
        "endpoint_pipeline.handle_web_socket_call.not_a_socket_endpoint",
        "This endpoint does not declare a WebSocket transport.",
        parameters: {"endpoint": name},
      );
    }

    // Read leniently: unlike the HTTP path, a socket endpoint is routinely
    // exercised without the logging middleware in front of it.
    final logInfo =
        req.context[TomRequestLogInfo.contextName] as TomRequestLogInfo?;
    logInfo?.shouldBeLogged = shouldLogRequests;

    final requestId = getFromCurrentZone<TomRequestId>();
    final reqId = requestId == null ? "" : requestId.uuid;

    try {
      await enforceAccess();
    } on TomEndpointHandlerException catch (denial) {
      if (denial.key != tomEndpointAccessDeniedErrorKey) rethrow;
      // The handshake is refused the same way a request is, and for the same
      // reason: a socket that answered `403` where a request answers `404`
      // would be the oracle the request path just closed, reachable by
      // upgrading instead of asking.
      return accessDeniedResponse();
    }

    final connection = TomWebSocketConnection();
    final positionalArguments = await bindParameters(
      req,
      extraByType: {TomWebSocketConnection: connection},
    );

    // The socket callback fires after the handshake response is finished, by
    // which time the request zone — and with it the TomPrincipal, the execution
    // context and the request id — is no longer current. Capture it here and
    // run the handler inside it: the same fix, for the same reason, as the
    // streamed file download (bug D22).
    final zone = Zone.current;
    final callName = method.simpleName;

    final handler = webSocketHandler(
      (WebSocketChannel channel, String? subprotocol) {
        connection.attachChannel(channel, subprotocol);
        unawaited(
          zone.run(
            () => _serveSocket(
              reqId,
              req,
              callName,
              connection,
              positionalArguments,
            ),
          ),
        );
      },
      protocols: declaration.protocols.isEmpty ? null : declaration.protocols,
      allowedOrigins: declaration.allowedOrigins.isEmpty
          ? null
          : declaration.allowedOrigins,
      pingInterval: declaration.pingInterval,
    );

    // Both outcomes are logged, and they leave the handler by different
    // routes — which is why the accepted one needs a `catch` rather than a
    // line after the `await`.
    //
    // An **accepted** upgrade ends in `Request.hijack`, which throws
    // `HijackException` by contract: shelf_io catches it and takes the socket
    // over. So `await handler(req)` never returns on the path that matters, and
    // a log line written after it records only the refusals. It recorded only
    // the refusals for as long as it stood there — an accepted connection, the
    // one event an operator actually wants in the access log, was the one the
    // pipeline never wrote a line for.
    //
    // The exception is rethrown, not swallowed. It *is* the protocol: catching
    // it and returning a response would leave shelf writing an ordinary reply
    // over a socket the handshake has already claimed.
    //
    // A **refused** upgrade — no `Upgrade` header, an unoffered subprotocol, a
    // cross-origin request — is an ordinary response from
    // `shelf_web_socket`, and is logged with the status it carries.
    try {
      final response = await handler(req);
      if (shouldLogRequests) {
        tomLog.info(
          "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] /$reqId-${req.url} ${req.requestedUri} => ${response.statusCode} [WebSocket handshake refused]",
        );
        logInfo?.hasBeenLogged = true;
      }
      return response;
    } on HijackException {
      if (shouldLogRequests) {
        // No status code: shelf has taken the socket and writes the 101 itself,
        // so this line reports the outcome it can vouch for rather than a
        // number it did not see.
        tomLog.info(
          "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] /$reqId-${req.url} ${req.requestedUri} => upgraded [WebSocket handshake]",
        );
        logInfo?.hasBeenLogged = true;
      }
      rethrow;
    }
  }

  /// Invokes the socket handler and closes the connection when it returns.
  ///
  /// Runs inside the captured request zone (see [handleWebSocketCall]), so the
  /// handler sees the same principal and execution context an HTTP handler
  /// would.
  Future<void> _serveSocket(
    String reqId,
    Request req,
    String callName,
    TomWebSocketConnection connection,
    List<Object> positionalArguments,
  ) async {
    // CE-LG: what is auditable about a socket is that it was *accepted* — the
    // point at which an authenticated principal gained an open channel. The
    // conversation that follows carries no further endpoint invocations, so
    // there is no later moment at which "this succeeded" would mean more.
    await _recordInvocationAudit(
      TomAuditOutcome.succeeded,
      detail: "WebSocket connection accepted",
    );
    try {
      var result = instance.invoke(callName, positionalArguments);
      if (result is Future) await result;
      await connection.close(1000, "Handler completed");
    } catch (error, stacktrace) {
      tomLog.warn(
        "$reqId-${req.url}: WebSocket handler $callName on ${instance.type.simpleName} threw $error\n$stacktrace",
      );
      await _recordInvocationAudit(TomAuditOutcome.failed, detail: "$error");
      // 1011 "internal error" is the WebSocket equivalent of a 500: the peer is
      // told the conversation ended because *this* side failed, without being
      // told how — the same discretion the default error handler applies.
      await connection.close(1011, "Handler failed");
    }
  }

  /// Whether requests to this endpoint are logged.
  ///
  /// `TomEndpoint.logRequests` is three-state: `true` logs, `false` does not,
  /// and `null` — the value for any endpoint that says nothing — defers to
  /// [globalSettingLogRequestsDefault]. Reading the annotation directly
  /// collapses the third state into the second, which silently makes the global
  /// setting govern nothing: it exists for exactly the endpoints that stay
  /// silent. Every logging decision in the pipeline goes through here so that
  /// the fallback cannot be bypassed by accident.
  bool get shouldLogRequests =>
      metadata.endpoint.logRequests ?? globalSettingLogRequestsDefault;

  /// Decides whether [principal] may call this endpoint from its resolved
  /// [TomAccessControl] — the handler-side override if present, otherwise the
  /// contract-declared policy (G-API-3) — falling back to the global protection
  /// default when neither declares an access rule.
  bool checkAccess(TomPrincipal? principal) {
    if (metadata.access != null) {
      return metadata.access!.checkAccessibility(principal);
    }
    return !TomResourceKeyProtection.globalSettingProtectionDefault;
  }

  /// The two resource keys this endpoint is automatically protected under: the
  /// `container` granting the whole interface/API, and the `member` granting
  /// this one method within it.
  ///
  /// A registry-backed endpoint is keyed on the identity its **contract**
  /// declares (`<apiId>` / `<apiId>.<endpointId>`); everything else on the Dart
  /// type it is routed through (`<Interface>` / `<Interface>.<method>`). The
  /// contract identity is preferred wherever one exists for two reasons: it is
  /// the name the operator granting keys actually has in front of them, and it
  /// survives a rename of the implementation class — which a key an operator
  /// has already issued must.
  ///
  /// The choice is made per *method*, not per class, because it is a method
  /// that does or does not have a contract entry: a `@TomApiImplementation`
  /// class may also carry plain `@TomEndpoint` methods, and those have no
  /// contract identity to be keyed on.
  ///
  /// Every endpoint has a pair — there is no "unprotectable" endpoint. When a
  /// method is routed neither through an interface nor through a contract it
  /// keys on [implementation], which is then the very type it was mounted from.
  /// The return is non-nullable so that this stays true by construction rather
  /// than by a guard nobody can reach: `interface` is null exactly when
  /// `metadata.apiEndpoint` is not.
  (String container, String member) get automaticProtectionKeys {
    final contractEndpoint = metadata.apiEndpoint;
    if (contractEndpoint != null) {
      final apiId = contractEndpoint.api.id;
      return (apiId, "$apiId.${contractEndpoint.id}");
    }
    final typeName = (interface ?? implementation).simpleName;
    return (typeName, "$typeName.$methodName");
  }

  /// Second-chance access check via resource-key protection, over the pair of
  /// keys [automaticProtectionKeys] names. Takes the prior [accessCheck] and
  /// returns the possibly-upgraded decision.
  ///
  /// The rule is: **holding the container key grants every member of it, unless
  /// the principal also holds the negated member key `-<member>`; otherwise
  /// only the member key itself grants.** A principal holding neither is left
  /// with the decision it arrived with — `enforceAccess` only consults this
  /// after the ordinary check has already refused, so this can raise a refusal
  /// to a grant but never invents one of its own.
  ///
  /// Note the polarity of [TomResourceKeyProtection.isProtected]: it answers
  /// "the principal *lacks* this key". Every key in the list, `-<member>`
  /// included, is something the principal **holds** — the minus is part of the
  /// name of a revocation, not a negation of the test. Which is why a `*` grant
  /// never covers a `-` key ([TomAccessControlInformation.holdsResourceKey]): a
  /// principal granted every container is not thereby issued every
  /// revocation.
  bool checkAutomaticAccess(bool accessCheck) {
    final (container, member) = automaticProtectionKeys;

    final holdsContainer = !TomResourceKeyProtection.isProtected(container);
    if (holdsContainer) {
      // The revocation is only consulted while protection is actually on.
      // `isProtected` answers "false" — *held* — for every key once protection
      // is switched off, and asking it about `-<member>` there would report
      // every conceivable revocation as issued and deny every endpoint. A
      // revocation exists only by having been granted to someone.
      final revoked =
          TomResourceKeyProtection.globalSettingProtectionDefault &&
          !TomResourceKeyProtection.isProtected("-$member");
      return !revoked;
    }
    final holdsMember = !TomResourceKeyProtection.isProtected(member);
    return holdsMember ? true : accessCheck;
  }
}

/// Identifies one mounted route: a path template *and* the HTTP method it was
/// mounted for.
///
/// The method belongs in the key because a path alone does not identify a
/// route. One endpoint may answer several methods, and — legally — two
/// endpoints may divide the methods of a single path between them, so a table
/// keyed by path holds one entry where several routes are mounted and silently
/// reports whichever was written last.
///
/// [uri] is the route as *declared* (`/items/{id}`), not the `shelf_router`
/// translation of it, so a caller can look an entry up with the string it wrote
/// in the annotation. [method] is the HTTP method's uppercase wire name
/// (`TomHttpMethod.name`) rather than the [TomHttpMethod] instance, because
/// `TomHttpMethod` does not define value equality — two instances naming the
/// same method are only interchangeable as map keys while both are the
/// canonical constants, which is a precondition a diagnostic API should not
/// impose on its callers.
typedef TomEndpointRouteKey = ({String uri, String method});

/// Pairs a mounted route's [handler] with the [endpoint] it was built from and
/// the HTTP [method] this particular mount answers.
///
/// [endpoint] lists every method the endpoint *declares*; [method] is the one
/// this entry stands for. Both are needed: enumerating `routingInfo.values`
/// then yields a complete picture without having to consult the keys.
class TomEndpointRoutingInfo {
  /// The handler invoked for the route.
  TomEndpointHandler handler;

  /// The endpoint definition the route was built from.
  TomEndpoint endpoint;

  /// The single HTTP method this entry was mounted for.
  ///
  /// A WebSocket endpoint records [TomHttpMethod.get]: a handshake is a GET,
  /// and that is the method its route is registered under.
  TomHttpMethod method;

  /// Pairs [handler] with its [endpoint] for one mounted [method].
  TomEndpointRoutingInfo(this.handler, this.endpoint, this.method);
}

/// Builds the shelf [Router] for the application by reflecting over annotated
/// service/API classes and mounting one route per endpoint method.
///
/// [scanClasses] partitions the reflected classes into service interfaces, API
/// implementations, and components; [initializeRouter] resolves each service's
/// instance (via [TomComponentReference], bean lookup, or a matching component
/// class) and mounts its endpoint methods. The mounted handlers and a
/// [TomEndpointRouteKey]→[TomEndpointRoutingInfo] map are exposed statically for
/// diagnostics.
class TomEndpointRouting {
  /// Every endpoint handler mounted during the last [initializeRouter] run.
  static List<TomEndpointHandler> handlers = [];

  /// Mounted routes for diagnostics, one entry per route *and* HTTP method.
  ///
  /// See [TomEndpointRouteKey] for why the method is part of the key. An
  /// endpoint declaring three methods contributes three entries sharing one
  /// handler; two endpoints splitting a path between them contribute one entry
  /// each, and remain distinguishable.
  ///
  /// Only the methods an endpoint *declares* are listed. Every route also gets
  /// an automatic `OPTIONS` registration for CORS preflight, which is framework
  /// plumbing rather than part of the endpoint's surface: recording it would
  /// double the table with entries that say nothing an operator does not
  /// already know holds for every route.
  static Map<TomEndpointRouteKey, TomEndpointRoutingInfo> routingInfo = {};

  /// Translates a Tom route template into the `shelf_router` path syntax.
  ///
  /// Tom (and OpenAPI) write path variables as `{name}`; `shelf_router` matches
  /// them as `<name>` and treats `{name}` as a *literal* path segment. So a
  /// route mounted with the raw template (`/items/{id}/field-states`) silently
  /// never matches a real request (`/items/1/field-states`) — the only symptom
  /// is a 404 "Route not found". Every `{name}` is rewritten to `<name>`; a
  /// route with no variables is returned unchanged. The captured variable keeps
  /// its name, so the pipeline binds it from `Request.params` by that name.
  static String shelfRoutePath(String uri) =>
      uri.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) => '<${m[1]}>');

  /// Reflects over the annotated classes and partitions them into service
  /// interfaces, API implementations, and components. Throws if a class carries
  /// both `@TomApiImplementation` and `@tomService`.
  TomClassScanResult scanClasses() {
    List<ClassMirror> serviceInterfaces = [];
    List<ClassMirror> apiImplementations = [];
    List<ClassMirror> componentClasses = [];

    for (var type in tomReflector.annotatedClasses) {
      TomApiImplementation? apiImplAnno;
      TomService? serviceAnno;
      TomComponent? componentAnno;
      for (var anno in type.metadata) {
        if (anno is TomApiImplementation) {
          apiImplAnno = anno;
        } else if (anno is TomService) {
          serviceAnno = anno;
        } else if (anno is TomComponent) {
          componentAnno = anno;
        }
      }
      if (apiImplAnno != null && serviceAnno != null) {
        throw TomEndpointPipelineException(
          "endpoint_pipeline.initialize_router.api_implementation_and_service_on_same_class",
          "Class ${type.qualifiedName} cannot be annotated with both @TomApiImplementation and @TomService.",
        );
      }
      if (apiImplAnno != null) {
        apiImplementations.add(type);
      } else if (serviceAnno != null) {
        serviceInterfaces.add(type);
      }
      if (componentAnno != null) {
        componentClasses.add(type);
      }
    }

    return TomClassScanResult(
      serviceInterfaces: serviceInterfaces,
      apiImplementations: apiImplementations,
      componentClasses: componentClasses,
    );
  }

  /// Registers the API contracts the framework itself ships an implementation
  /// of, so the router can resolve them without the application registering
  /// anything.
  ///
  /// A registry-based handler is mounted by looking its contract up in
  /// [tomRemoteApis], and the lookup throws when the contract is absent. For an
  /// *application's* API that is right: the contract and the handler are both
  /// the application's, and a handler whose contract was never registered is a
  /// bootstrap the application got wrong. For the framework's own it would not
  /// be: [TomUserPreferencesServer] is exported from the barrel, so it is
  /// reflected — and therefore scanned — in every deployment, whether or not
  /// that deployment has any interest in preferences. Leaving the registration
  /// to the application would mean every server that forgot one line failed to
  /// start, for an endpoint it never asked for.
  ///
  /// Registering is idempotent (the registry is keyed by API id), so repeated
  /// router initialisations — which the test suite does per case — cost nothing
  /// and cannot double-mount.
  void registerFrameworkApis() {
    registerTomUserPreferencesApi();
    registerTomOAuthApi();
  }

  /// Scans the annotated classes and mounts every endpoint method onto a fresh
  /// [Router], resolving each service's implementation instance, and returns the
  /// router.
  Router initializeRouter() {
    final Router router = Router();
    registerFrameworkApis();
    var scanResult = scanClasses();
    // old style, for services based on interfaces
    for (var serviceType in scanResult.serviceInterfaces) {
      Object? serviceInstance = getReferencedComponent(serviceType);
      serviceInstance ??= findServiceInstance(
        scanResult.componentClasses,
        serviceType,
        serviceInstance,
      );
      createRoutesForClassMirror(serviceType, serviceInstance, router);
    }
    // using API definitions from the remote api registry
    for (var serviceType in scanResult.apiImplementations) {
      Object? serviceInstance = getReferencedComponent(serviceType);
      serviceInstance ??= TomBean.getBeanByType(
        serviceType.dynamicReflectedType,
      );
      // Same last resort as the interface branch above: an API implementation
      // with a no-argument constructor is fully described by its declaration,
      // so it need not be registered by hand. Without this the framework's own
      // registry-based handlers (TomUserPreferencesServer) would make every
      // application register a bean for an endpoint it never asked for — which
      // is the case `instantiateComponent` was written for.
      serviceInstance ??= instantiateComponent(serviceType);
      createRoutesForClassMirror(serviceType, serviceInstance, router);
    }
    return router;
  }

  /// Mounts every endpoint method of [serviceType] (invoked on
  /// [serviceInstance]) onto [router], building a [TomEndpointHandler] per
  /// method from its collected metadata.
  void createRoutesForClassMirror(
    ClassMirror serviceType,
    Object? serviceInstance,
    Router router,
  ) {
    tomLog.trace(
      "tomService interface $serviceType, ${serviceType.metadata}, $serviceInstance",
    );
    var methodMetadata = getClassMethodMetadata(serviceType);
    if (methodMetadata.isNotEmpty) {
      if (serviceInstance == null) {
        throw TomEndpointPipelineException(
          "endpoint_pipeline.initialize_router.no_service_instance",
          "No implementation instance could be resolved for service ${serviceType.qualifiedName}: register a bean for its @tomComponent implementation.",
          parameters: {'service': serviceType.qualifiedName},
        );
      }
      var instanceMirror = tomReflector.reflect(serviceInstance);
      var instanceClassMirror =
          tomReflector.reflectType(serviceInstance.runtimeType) as ClassMirror;
      for (var mmd in methodMetadata) {
        tomLog.trace("Found endpoint ${mmd.methodMirror.simpleName}");
        var instanceMethodMirror =
            instanceClassMirror.declarations[mmd.methodMirror.simpleName]
                as MethodMirror;
        var tep = mmd.endpoint;
        TomEndpointHandler teph = TomEndpointHandler(
          name:
              "${tep.uri}-${tep.methods} to ${mmd.methodMirror.qualifiedName} in ${instanceClassMirror.qualifiedName}",
          instance: instanceMirror,
          method: instanceMethodMirror,
          // Only when the method really is routed via an interface. A
          // registry-backed method carries its own contract identity, and
          // `serviceType` there is the *implementation* class — setting it
          // would key the endpoint's automatic protection on a Dart class name
          // instead of on the API id its contract declares.
          interface: mmd.apiEndpoint == null ? serviceType : null,
          implementation: instanceClassMirror,
          methodName: mmd.methodMirror.simpleName,
          metadata: mmd,
        );
        createRoutesForEndpoint(tep, router, teph, mmd, instanceClassMirror);
      }
    }
  }

  /// Resolves the implementation instance named by a [TomComponentReference] on
  /// [serviceType] (by name or by type), or `null` when none is present. Throws
  /// if the reference is malformed (neither/both set) or duplicated.
  Object? getReferencedComponent(ClassMirror serviceType) {
    Object? serviceInstance;
    for (var anno in serviceType.metadata) {
      if (anno is TomComponentReference) {
        if (anno.componentName == null && anno.referencedType == null) {
          throw TomEndpointPipelineException(
            "endpoint_pipeline.initialize_router.component_reference_invalid",
            "TomComponentReference must have either componentName or referencedType set in ${serviceType.qualifiedName}",
          );
        }
        if (anno.componentName != null && anno.referencedType != null) {
          throw TomEndpointPipelineException(
            "endpoint_pipeline.initialize_router.component_reference_invalid_both_set",
            "TomComponentReference must have either componentName or referencedType set in ${serviceType.qualifiedName}, not both.",
          );
        }
        if (serviceInstance != null) {
          throw TomEndpointPipelineException(
            "endpoint_pipeline.initialize_router.multiple_component_references",
            "There must be only a single TomComponentReference in ${serviceType.qualifiedName}, not both.",
          );
        }
        if (anno.referencedType != null) {
          serviceInstance = TomBean.getBeanByType(anno.referencedType!);
        } else if (anno.componentName != null) {
          serviceInstance = TomBean.getBeanByName(anno.componentName!);
        }
      }
    }
    return serviceInstance;
  }

  /// Registers [teph] on [router] for each HTTP method of [tep] (plus an
  /// `OPTIONS` route for CORS preflight) and records it in [routingInfo] /
  /// [handlers]. Throws on an unsupported HTTP method.
  void createRoutesForEndpoint(
    TomEndpoint<Object, Object> tep,
    Router router,
    TomEndpointHandler teph,
    TomMethodMetadata mmd,
    ClassMirror instanceClassMirror,
  ) {
    // Tom (and OpenAPI) write path variables as `{name}`; shelf_router matches
    // `<name>` and escapes `{name}` to a literal segment, so a route registered
    // with the raw template silently never matches a real value. Translate once
    // and register the shelf form.
    final route = shelfRoutePath(tep.uri);
    if (mmd.webSocket != null) {
      if (mmd.transactionInfo != null) {
        // A transaction is scoped to a request; a socket outlives every
        // individual message on it. Wrapping the handler would mean one
        // transaction held open for the whole conversation — a lock held for
        // as long as a client cares to stay connected. Refused at mount time,
        // because the alternative is discovering it under load.
        throw TomEndpointPipelineException(
          "endpoint_pipeline.create_routes_for_endpoint.transactional_web_socket",
          "WebSocket endpoint ${mmd.methodMirror.simpleName}-${instanceClassMirror.simpleName} cannot be @TomTransactional: a transaction cannot span a connection.",
        );
      }
      // A handshake is a GET, and OPTIONS still answers preflight so that a
      // browser can discover the route the same way it discovers any other.
      router.get(route, teph.handleWebSocketCall);
      router.options(route, teph.handleMethodCall);
      routingInfo[(uri: tep.uri, method: TomHttpMethod.get.name)] =
          TomEndpointRoutingInfo(teph, tep, TomHttpMethod.get);
      tomLog.info("mounted websocket endpoint ${teph.name} $tep");
      handlers.add(teph);
      return;
    }
    for (var method in tep.methods) {
      switch (method) {
        case TomHttpMethod.get:
          router.get(route, teph.handleMethodCall);
        case TomHttpMethod.post:
          router.post(route, teph.handleMethodCall);
        case TomHttpMethod.put:
          router.put(route, teph.handleMethodCall);
        case TomHttpMethod.patch:
          router.patch(route, teph.handleMethodCall);
        case TomHttpMethod.head:
          router.head(route, teph.handleMethodCall);
        case TomHttpMethod.connect:
          router.connect(route, teph.handleMethodCall);
        case TomHttpMethod.delete:
          router.delete(route, teph.handleMethodCall);
        case TomHttpMethod.trace:
          router.trace(route, teph.handleMethodCall);
        case TomHttpMethod.all:
          router.all(route, teph.handleMethodCall);
        default:
          throw TomEndpointPipelineException(
            "endpoint_pipeline.initialize_router.invalid_http_method",
            "Endpoint method $method invalid for ${mmd.methodMirror.simpleName}-${instanceClassMirror.simpleName}",
          );
      }
      routingInfo[(uri: tep.uri, method: method.name)] = TomEndpointRoutingInfo(
        teph,
        tep,
        method,
      );
    }
    // Preflight is a property of the *route*, not of each method mounted on it.
    // Registering it inside the loop above mounted one copy per declared method,
    // and shelf dispatches to the first match, so every copy after the first was
    // unreachable.
    router.options(route, teph.handleMethodCall);
    tomLog.info("mounted endpoint ${teph.name} $tep");
    handlers.add(teph);
  }

  /// Collects, for each endpoint-annotated method of [classMirror], the merged
  /// [TomMethodMetadata] (endpoint, access control, transaction, and remote-API
  /// tags). Throws on conflicting/duplicate tags or a missing
  /// `@TomApiImplementation` for an API-endpoint method.
  ///
  /// Access control follows G-API-3 (C-12): a handler-side `TomAccessControl`
  /// annotation is a local override and wins; when the handler declares none,
  /// the endpoint's **contract-declared** policy (`TomApiEndpoint.access` from
  /// the registry) is extracted, so a registry-based handler is gated without
  /// restating the policy inline.
  List<TomMethodMetadata> getClassMethodMetadata(ClassMirror classMirror) {
    List<TomMethodMetadata> methodMetadata = [];
    nextDeclaration:
    for (var decl in classMirror.declarations.values) {
      if (decl is MethodMirror) {
        for (var mde in decl.metadata) {
          if (mde is TomEndpointBase) {
            TomEndpointBase? tepTag;
            TomAccessControl? tea;
            TomTransactional? ti;
            TomApiEndpointImplementation? aei;
            TomApiImplementation? ai;
            TomApi? a;
            TomApiEndpoint? ae;
            TomAudited? aud;
            for (var tag in decl.metadata) {
              if (tag is TomAudited) {
                if (aud != null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.multiple_audited_tags",
                    "More than one TomAudited specified for $decl",
                  );
                }
                aud = tag;
              }
              if (tag is TomAccessControl) {
                if (tea != null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.multiple_access_control",
                    "More than one TomEndpointAccess specified for $decl",
                  );
                }
                tea = tag;
              }
              if (tag is TomTransactional) {
                if (ti != null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.multiple_transactional_tags",
                    "More than one TomTransactional specified for $decl",
                  );
                }
                ti = tag;
              }
              if (tag is TomEndpointBase) {
                if (tepTag != null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.multiple_endpoint_base_tags",
                    "More than one tag of type TomEndpointBase specified for $decl",
                  );
                }
                tepTag = tag;
              }
              if (tag is TomApiEndpointImplementation) {
                if (aei != null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.multiple_api_endpoint_implementation_tags",
                    "More than one tag of type TomApiEndpointImplementation specified for $decl",
                  );
                }
                aei = tag;
                ae = tomRemoteApis[aei.apiId][aei.endpointId];
                a = tomRemoteApis[aei.apiId];
                for (var classAnno in classMirror.metadata) {
                  if (classAnno is TomApiImplementation) {
                    if (ai != null) {
                      throw TomEndpointPipelineException(
                        "endpoint_pipeline.get_class_method_metadata.multiple_tom_api_implementation_tags",
                        "More than one tag of type TomApiImplementation specified for ${classMirror.simpleName}",
                      );
                    }
                    ai = classAnno;
                  }
                }
                if (ai == null) {
                  throw TomEndpointPipelineException(
                    "endpoint_pipeline.get_class_method_metadata.no_tom_api_implementation_found",
                    "No tag of type TomApiImplementation specified for ${classMirror.simpleName}",
                  );
                }
              }
            }
            // Convert only after the whole tag set is known, so a registry
            // endpoint inherits the class-level @TomApiImplementation's API-wide
            // errorHandler / logRequestsDefault for anything it does not
            // override. For an inline TomEndpoint, `ai` is null and the class
            // annotation is ignored.
            final TomEndpoint tep = tepTag!.convertToTomEndpoint(ai);
            // C-12 / G-API-3: a handler-side `TomAccessControl` annotation (`tea`)
            // is a local override and wins; otherwise the endpoint's
            // contract-declared policy (`ae.access`, from the registry entry) is
            // extracted here — so a registry-based handler needs no inline
            // annotation to be gated. An inline TomEndpoint has no `ae`, so it
            // keeps whatever the handler declared (or nothing).
            final TomAccessControl? resolvedAccess = tea ?? ae?.access;
            methodMetadata.add(
              TomMethodMetadata(
                methodMirror: decl,
                endpoint: tep,
                access: resolvedAccess,
                transactionInfo: ti,
                audited: aud,
                // A socket endpoint is discovered by the very same `tag is
                // TomEndpointBase` test as every other kind; all that is kept
                // here is *which* kind it was, for the mounting step.
                webSocket: tepTag is TomWebSocketEndpoint ? tepTag : null,
                apiEndpointImplementation: aei,
                apiEndpoint: ae,
                api: a,
                apiImplementation: ai,
              ),
            );
            continue nextDeclaration;
          }
        }
      }
    }
    return methodMetadata;
  }

  /// Fallback resolution for an interface-based service: finds a component
  /// class that extends or implements [serviceType] and returns its bean,
  /// otherwise returns the passed-in [serviceInstance].
  ///
  /// A component with no registered bean is constructed here (see
  /// [instantiateComponent]) rather than left unresolved, and a resolved
  /// instance is never overwritten by a later, unresolvable candidate.
  Object? findServiceInstance(
    List<ClassMirror> componentClasses,
    ClassMirror serviceType,
    Object? serviceInstance,
  ) {
    for (var instanceType in componentClasses) {
      if (serviceInstance != null) break;
      if (((instanceType.superclass != null &&
              instanceType.superclass!.qualifiedName ==
                  serviceType.qualifiedName) ||
          instanceType.superinterfaces.any(
            (cm) => cm.qualifiedName == serviceType.qualifiedName,
          ))) {
        tomLog.trace(
          "Found implementation class: $instanceType, ${instanceType.metadata}",
        );
        serviceInstance = TomBean.getBeanByType(
          instanceType.dynamicReflectedType,
        );
        serviceInstance ??= instantiateComponent(instanceType);
      }
    }
    return serviceInstance;
  }

  /// Constructs [componentType] through its no-argument constructor and
  /// registers it as the bean for its type, or returns `null` when it cannot be
  /// built that way.
  ///
  /// The framework ships services of its own — the health check, the file
  /// endpoint — and a library that adds one must not force every existing
  /// application to register a bean it has never heard of. A `@tomComponent`
  /// that needs no arguments is fully described by its own declaration, so
  /// building it is not a guess. Anything with a real constructor still belongs
  /// to the application, and stays unresolved here.
  ///
  /// The instance is registered so that the router and any later
  /// `TomBean.getBeanByType` see the same object; an application that registers
  /// its own bean first is never overridden, because this only runs when the
  /// lookup came back empty.
  Object? instantiateComponent(ClassMirror componentType) {
    try {
      final instance = componentType.newInstance('', const []);
      TomBean.withType(componentType.dynamicReflectedType, instance);
      tomLog.trace(
        "No bean registered for ${componentType.qualifiedName}; constructed the default instance.",
      );
      return instance;
    } on Object catch (error) {
      tomLog.trace(
        "Cannot construct a default instance of ${componentType.qualifiedName}: $error",
      );
      return null;
    }
  }
}

/// All annotation metadata collected for one endpoint method: the reflected
/// method plus its [endpoint], optional [access] control and [transactionInfo],
/// and (for registry-based endpoints) the resolved remote-API tags.
class TomMethodMetadata {
  /// The reflected endpoint method.
  MethodMirror methodMirror;

  /// The endpoint definition (route, mime types, error handler, …).
  TomEndpoint endpoint;

  /// The access-control rule, if the method declared one.
  TomAccessControl? access;

  /// The transaction directive, if the method declared one.
  TomTransactional? transactionInfo;

  /// The `@TomAudited` declaration, if the method opted its invocation into the
  /// audit trail (CE-LG).
  ///
  /// Null for the great majority of endpoints, and that is the intended state:
  /// endpoint auditing is *declared*, because most endpoint calls are reads
  /// whose auditing would drown the trail. Mutation auditing needs no
  /// declaration — it happens at the repository.
  TomAudited? audited;

  /// The `@TomWebSocketEndpoint` declaration, when the method is a socket
  /// endpoint rather than a request/response one.
  ///
  /// Kept alongside the [endpoint] it converts to, not instead of it: the scan,
  /// the access resolution and the routing table all work on the [TomEndpoint],
  /// and this field is what tells the mounting step to give the route a socket
  /// handler rather than an HTTP one.
  TomWebSocketEndpoint? webSocket;

  /// The `@TomApiEndpointImplementation` tag, for registry-based endpoints.
  TomApiEndpointImplementation? apiEndpointImplementation;

  /// The class's `@TomApiImplementation` tag, for registry-based endpoints.
  TomApiImplementation? apiImplementation;

  /// The resolved remote API, for registry-based endpoints.
  TomApi? api;

  /// The resolved remote-API endpoint, for registry-based endpoints.
  TomApiEndpoint? apiEndpoint;

  /// Bundles the metadata for one endpoint method.
  TomMethodMetadata({
    required this.endpoint,
    required this.methodMirror,
    this.access,
    this.transactionInfo,
    this.audited,
    this.webSocket,
    this.apiEndpointImplementation,
    this.apiImplementation,
    this.api,
    this.apiEndpoint,
  });
}

/// The partitioned result of scanning the annotated classes: interface-based
/// services, remote-API implementations, and component classes.
class TomClassScanResult {
  /// Classes annotated with `@tomService` (interface-based services).
  List<ClassMirror> serviceInterfaces = [];

  /// Classes annotated with `@TomApiImplementation`.
  List<ClassMirror> apiImplementations = [];

  /// Classes annotated with `@TomComponent` (candidate implementations).
  List<ClassMirror> componentClasses = [];

  /// Creates a scan result from the three class lists.
  TomClassScanResult({
    this.serviceInterfaces = const [],
    this.apiImplementations = const [],
    this.componentClasses = const [],
  });
}
