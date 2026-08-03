import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../little_things/server_exception.dart';
import '../server/server.dart';
import '../transactions/transaction_manager.dart';

import 'endpoint_annotation.dart';

/// Serializes one element of a `List` endpoint result to a JSON-encodable value.
///
/// Used as the `toEncodable` for `jsonEncode` when a handler returns a
/// `List<Object>`: `jsonEncode` handles primitives, maps and nested lists
/// natively and only calls this for the remaining complex elements. An element
/// that owns its wire shape ([TomClass]/[TomJsonSerializable]) is serialized
/// through its `toJson`; every other object — notably the reflection-first wire
/// DTOs, which carry no hand-written serializer — goes through the kernel
/// reflection path, matching how a *single* such result is serialized below.
Object? _encodeResultElement(Object? element) {
  if (element is TomClass) return element.toJson();
  if (element is TomJsonSerializable) return element.toJson();
  return tomReflectionInfo.getValues(element!);
}

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
  ClassMirror? interface;

  /// The concrete implementation class mirror.
  ClassMirror implementation;

  /// The qualified name of the method to invoke.
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

  /// Runs the full request pipeline for this endpoint and returns the response.
  ///
  /// Handles preflight, access control, reflection-based parameter binding,
  /// optional transaction wrapping, method invocation, and result/error
  /// conversion (see the class doc). WebSocket transport, richer
  /// role/group/entitlement authorization, and stream/file upload binding are
  /// tracked follow-ups (see the quest completion steps).
  Future<Response> handleMethodCall(Request req) async {
    if (req.method == TomHttpMethod.options.name) return handlePreflight(req);

    List<Object> positionalArguments = [];

    TomRequestLogInfo logInfo =
        req.context[TomRequestLogInfo.contextName] as TomRequestLogInfo;
    logInfo.shouldBeLogged =
        metadata.endpoint.logRequests ?? globalSettingLogRequestsDefault;

    var authentication = getFromCurrentZone<TomPrincipal>();
    var token = getFromCurrentZone<TomClientJwtToken>();
    var requestId = getFromCurrentZone<TomRequestId>();
    var reqId = requestId == null ? "" : requestId.uuid;

    bool accessCheck = checkAccess(authentication);

    if (accessCheck == false) {
      if (TomResourceKeyProtection
          .globalSettingUseAutomaticEndpointProtection) {
        accessCheck = checkAutomaticAccess(accessCheck);
      }
    }

    if (accessCheck == false) {
      // CE-LG: a denial is audited unconditionally — no annotation, no opt-in.
      // It is the one auditable event the repository chokepoint cannot see,
      // because the request is refused before it reaches any data, and it is
      // the entry an auditor looks for first. Awaited, so a trail that cannot
      // store the denial fails the request rather than losing the record.
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: name,
        outcome: TomAuditOutcome.denied,
        detail:
            "Access not granted and no resource key found for endpoint $name",
      );
      throw TomEndpointHandlerException(
        "endpoint_handler.handle_method_call.access_denied",
        "Access denied to endpoint, access not granted and resource key not found: $name",
      );
    }

    if (debugPrintContext)
      tomLog.trace(
        "$reqId-${req.url}: Request context is ${req.context} TomPrincipal is $authentication",
      );
    if (debugPrintAuthentication)
      tomLog.trace(
        "$reqId-${req.url}: Found $authentication and $token for request",
      );
    for (var pm in method.parameters) {
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
        if (metadata.endpoint.consumes == TomMimeType.json &&
            req.method != TomHttpMethod.trace.name) {
          try {
            String body = await req.readAsString();
            // Fold the JSON body (when present) and the mapped URL parameters
            // into one map, then build the request DTO from it. URL parameters
            // must reach the DTO even for a body-less GET
            // (`GET /items/{id}` -> `request.id`), so the DTO is instantiated
            // whenever there is a body *or* at least one URL parameter.
            final Map<String, dynamic> jsonBodyData = body.isNotEmpty
                ? jsonDecode(body) as Map<String, dynamic>
                : {};
            injectQueryParameters(jsonBodyData, req, metadata.endpoint);
            injectPathParameters(jsonBodyData, req, metadata.endpoint);
            if (jsonBodyData.isNotEmpty) {
              try {
                Object? parameterObject = tomReflectionInfo
                    .createInstanceFromJson(parameterMirror, jsonBodyData);
                if (parameterObject != null) {
                  positionalArguments.add(parameterObject);
                  tomLog.trace(
                    "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} from jsonbody $body to $parameterObject ${req.params}",
                  );
                  continue;
                } else {
                  throw TomEndpointHandlerException(
                    "endpoint_pipeline.handle_method_call.parameter_instantiation_returned_null",
                    "Request body contains content for ${parameterMirror.simpleName} but instantiation from JSON $jsonBodyData failed (null-result).",
                  );
                }
              } on TomEndpointHandlerException {
                rethrow;
              } catch (ex) {
                throw TomEndpointHandlerException(
                  "endpoint_pipeline.handle_method_call.parameter_instantiation_failed",
                  "Request body contains content for ${parameterMirror.simpleName} but instantiation from JSON $jsonBodyData failed: $ex",
                );
              }
            } else {
              tomLog.warn(
                "Was trying to set parameter ${pm.simpleName} ${pm.type.reflectedType} from json request to ${req.requestedUri} but body was empty and no URL parameters were present.",
              );
            }
          } catch (ex) {
            tomLog.error(
              "$reqId-${req.url}: Failed to parse json/set values $ex",
            );
          }
        }
        if (req.context.isNotEmpty &&
            req.context.containsKey(parameterMirror.simpleName) &&
            req.context[parameterMirror.simpleName] != null) {
          try {
            if (req.context[parameterMirror.simpleName]
                is Map<String, Object?>) {
              Object? parameterObject = tomReflectionInfo
                  .createInstanceFromJson(
                    parameterMirror,
                    req.context[parameterMirror.simpleName]
                        as Map<String, Object?>,
                  );
              if (parameterObject != null) {
                positionalArguments.add(parameterObject);
                tomLog.trace(
                  "$reqId-${req.url}: Setting parameter ${pm.simpleName} ${pm.type.reflectedType} value using map from context to $parameterObject ${req.context[parameterMirror.simpleName]}",
                );
                continue;
              } else {
                throw TomEndpointHandlerException(
                  "endpoint_pipeline.handle_method_call.parameter_instantiation_returned_null_from_context",
                  "Request context contains an object for ${parameterMirror.simpleName} but instantiation from JSON ${req.context[parameterMirror.simpleName]} failed (null-result).",
                  autoLog: true,
                );
              }
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
      tomLog.warn(
        "$reqId-${req.url}: Setting parameter ${pm.simpleName} of type ${pm.reflectedType} failed",
      );
    }

    String callName = method.simpleName;

    Object? result;

    TomTransaction? transaction;

    try {
      if (metadata.transactionInfo != null) {
        tomLog.trace("$reqId-${req.url}: Starting transaction...");
        (transaction, _) = TomTransactionManager.startTransaction();
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
        if (metadata.endpoint.logRequests == true) {
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
      // A handler that returns a shelf Response has already decided everything
      // this block would decide — status, headers, and a body that may be an
      // un-materialised stream. Answered first, before the conversion chain,
      // because that chain's fall-through is `convertToJsonString(result)`: a
      // Response is not a reflected DTO, so converting it throws and the
      // handler's own answer is lost to a 500. This is the escape hatch that
      // makes streaming endpoints (see `TomFileService`) possible at all.
      if (result is Response) {
        if (metadata.endpoint.logRequests == true) {
          tomLog.info(
            "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} => ${result.statusCode} [handler-supplied response]",
          );
          logInfo.hasBeenLogged = true;
        }
        return result;
      }
      String? resultString = result == null
          ? null
          : result is String
          ? result
          : result is TomClass
          ? jsonEncode(result.toJson())
          : result is TomJsonSerializable
          ? jsonEncode(result.toJson())
          : result is Map<String, Object>
          ? jsonEncode(result)
          : result is List<Object>
          ? jsonEncode(result, toEncodable: _encodeResultElement)
          : tomReflectionInfo.convertToJsonString(result);

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
      if (result == null) {
        response = Response.ok("");
      }
      response ??= Response.internalServerError(
        body: "Internal result processing failed.",
      );
      if (metadata.endpoint.logRequests == true) {
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
          if (metadata.endpoint.logRequests == true) {
            tomLog.info(
              "$reqId-${req.url}: HTTP/${req.protocolVersion} [${req.method}] ${req.encoding?.name ?? "no encoding"} /$reqId-${req.url} ${req.requestedUri} => ${response.statusCode} ${response.encoding} [handleConversionError]",
            );
          }
          logInfo.hasBeenLogged = true;
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

  /// Second-chance access check via resource-key protection: grants access when
  /// the interface/API (and not the specific method/endpoint) is unprotected,
  /// honouring per-method `-Interface.method` exceptions. Takes the prior
  /// [accessCheck] and returns the possibly-upgraded decision.
  bool checkAutomaticAccess(bool accessCheck) {
    if (interface != null) {
      if (!TomResourceKeyProtection.isProtected(interface!.simpleName)) {
        // if interface is accessible check if method was specified as an exception
        if (TomResourceKeyProtection.isProtected(
          "-${interface!.simpleName}.$methodName",
        )) {
          accessCheck = false;
        } else {
          accessCheck = true;
        }
      } else {
        // if interface is not accessible, check access to method
        if (!TomResourceKeyProtection.isProtected(
          "${interface!.simpleName}.$methodName",
        )) {
          accessCheck = true;
        }
      }
    } else if (metadata.apiEndpoint != null) {
      if (!TomResourceKeyProtection.isProtected(metadata.apiEndpoint!.api.id)) {
        // if endpoint is accessible check if method was specified as an exception
        if (TomResourceKeyProtection.isProtected(
          "-${metadata.apiEndpoint!.api.id}.${metadata.apiEndpoint!.id}",
        )) {
          accessCheck = false;
        } else {
          accessCheck = true;
        }
      } else {
        // if endpoint is not accessible, check access to method
        if (!TomResourceKeyProtection.isProtected(
          "${metadata.apiEndpoint!.api.id}.${metadata.apiEndpoint!.id}",
        )) {
          accessCheck = true;
        }
      }
    }
    return accessCheck;
  }
}

/// Pairs a mounted route's [handler] with the [endpoint] it was built from.
class TomEndpointRoutingInfo {
  /// The handler invoked for the route.
  TomEndpointHandler handler;

  /// The endpoint definition the route was built from.
  TomEndpoint endpoint;

  /// Pairs [handler] with its [endpoint].
  TomEndpointRoutingInfo(this.handler, this.endpoint);
}

/// Builds the shelf [Router] for the application by reflecting over annotated
/// service/API classes and mounting one route per endpoint method.
///
/// [scanClasses] partitions the reflected classes into service interfaces, API
/// implementations, and components; [initializeRouter] resolves each service's
/// instance (via [TomComponentReference], bean lookup, or a matching component
/// class) and mounts its endpoint methods. The mounted handlers and a
/// uri→[TomEndpointRoutingInfo] map are exposed statically for diagnostics.
class TomEndpointRouting {
  /// Every endpoint handler mounted during the last [initializeRouter] run.
  static List<TomEndpointHandler> handlers = [];

  /// Mounted routes keyed by URI, for diagnostics.
  static Map<String, TomEndpointRoutingInfo> routingInfo = {};

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
          interface: serviceType,
          implementation: instanceClassMirror,
          methodName: mmd.methodMirror.qualifiedName,
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
      router.options(route, teph.handleMethodCall);
      routingInfo[tep.uri] = TomEndpointRoutingInfo(teph, tep);
    }
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
            // errorHandler / logRequestsDefault for anything it does not override
            // (bug §69). For an inline TomEndpoint, `ai` is null and the class
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
