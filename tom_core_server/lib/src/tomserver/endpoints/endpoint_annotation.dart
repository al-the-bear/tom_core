import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Turns an error raised while serving an endpoint into a shelf [Response].
///
/// The endpoint pipeline calls a hook depending on *where* the failure
/// occurred: [handleInvocationError] when the service method itself threw, and
/// [handleConversionError] when serialising the (successful) result failed.
/// [handleUnknowResultTypeError] is declared for a result whose type cannot be
/// mapped to a body and is not reached by the pipeline today — that case leaves
/// as a conversion error. All three default to [handleErrorDefault], which is
/// the single method a concrete handler must implement; override the individual
/// hooks only when a stage needs a different response.
///
/// The stack trace is a [StackTrace] on every hook. Every call site binds one
/// from a `catch (error, stacktrace)` clause, so a looser `Object` bought
/// nothing and cost every implementer a cast before they could call anything a
/// trace offers.
abstract class TomErrorHandler {
  /// Const base constructor so handlers can be used as `const` annotations.
  const TomErrorHandler();

  /// Builds the response for an error thrown by the service method.
  Response handleInvocationError(
    Object error,
    StackTrace stacktrace,
    Request r,
  ) {
    return handleErrorDefault(error, stacktrace, r, null);
  }

  /// Builds the response for an error thrown while converting [result] into the
  /// response body.
  Response handleConversionError(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) {
    return handleErrorDefault(error, stacktrace, r, result);
  }

  /// Builds the response for a [result] whose type the pipeline cannot map to a
  /// body.
  Response handleUnknowResultTypeError(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) {
    return handleErrorDefault(error, stacktrace, r, result);
  }

  /// The fallback every hook delegates to; the one method a concrete handler
  /// must implement. [result] is the value being processed when the error
  /// occurred (`null` for invocation errors).
  Response handleErrorDefault(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  );
}

/// A [TomErrorHandler] that answers with the framework's error envelope, and
/// with the status an error key is declared to mean.
///
/// Two things every handler in this framework was writing for itself. The
/// **body** is [tomErrorEnvelope] — the package's single definition of the wire
/// error shape — under `x-tom-error: true` and declared `application/json`, so
/// a client decodes one shape whichever endpoint answered and branches on
/// `errorKey`. The **status** comes from [statusByErrorKey], which a subclass
/// overrides with its own keys; anything it does not name is a `500`.
///
/// The envelope is what makes this safe to use as a default. It reports
/// `errorKey` for a client to resolve against its own resources and never
/// `defaultUserMessage`, so no exception's text escapes through it — the
/// property the plain-text `"Internal server error"` body used to buy by saying
/// nothing at all, at the price of saying nothing at all.
///
/// A deployment that wants a miss to read as a miss therefore writes a map
/// rather than a handler:
///
/// ```dart
/// class OrdersErrorHandler extends TomStatusMappingErrorHandler {
///   const OrdersErrorHandler();
///
///   @override
///   Map<String, int> get statusByErrorKey => const {
///     'orders.fetch.not_found': 404,
///     'orders.submit.no_positions': 400,
///   };
/// }
/// ```
///
/// **It maps no status of its own**, and that is deliberate rather than
/// unfinished. The framework cannot know an application's keys, and the two
/// classifications it *does* make are already made elsewhere and differently:
/// an access denial answers `404` from
/// [TomEndpointHandler.accessDeniedResponse], deliberately indistinguishable
/// from a route that is not there, and a login failure is the authentication
/// pipeline's to report. A status invented here would contradict one of them.
abstract class TomStatusMappingErrorHandler extends TomErrorHandler {
  /// Const base constructor so handlers stay usable as `const` annotations.
  const TomStatusMappingErrorHandler();

  /// The status each error key answers with; every other key is a `500`.
  ///
  /// Keyed by the error key rather than by exception type because the key is
  /// what crosses the wire and what a client branches on — two modules may
  /// raise the same type for conditions a caller must tell apart, and one type
  /// may be raised for conditions with different statuses.
  Map<String, int> get statusByErrorKey => const {};

  /// The status [error] answers with: [statusByErrorKey]'s entry for a
  /// [TomException]'s key, else `500`.
  ///
  /// `protected`-by-convention rather than private, so a subclass with a rule
  /// a map cannot express — a whole key family, say — extends it by calling
  /// `super.statusFor(error)` for everything else.
  int statusFor(Object error) =>
      (error is TomException ? statusByErrorKey[error.key] : null) ?? 500;

  @override
  Response handleErrorDefault(
    Object error,
    StackTrace stacktrace,
    Request r,
    Object? result,
  ) => Response(
    statusFor(error),
    body: jsonEncode(tomErrorEnvelope(error)),
    headers: {
      'x-tom-error': 'true',
      TomHeader.contentType: TomMimeType.json.toHeaderValue(),
    },
  );
}

/// The default [TomErrorHandler]: the framework envelope with a `500`.
///
/// What every endpoint gets when it declares no handler of its own. It maps no
/// key to any other status — see [TomStatusMappingErrorHandler] for why the
/// framework declines to guess one, and for the three lines a deployment writes
/// to declare its own.
class TomDefaultErrorHandler extends TomStatusMappingErrorHandler {
  /// Const constructor so the default handler can be shared as a `const` value.
  const TomDefaultErrorHandler();
}

/// The shared default error handler instance used when an endpoint does not
/// declare its own.
const _tomDefaultErrorHandler = TomDefaultErrorHandler();

/// Class-level annotation marking a class as a service whose endpoint-annotated
/// methods should be scanned and routed by the pipeline.
///
/// Use the [tomService] constant to annotate a class. A class may be a
/// `@tomService` *or* a [TomApiImplementation], never both.
class TomService {
  /// Const constructor so the annotation can be applied as `@tomService`.
  const TomService();
}

/// The annotation instance to mark a class with [TomService].
const tomService = TomService();

/// Class-level annotation marking a class as the implementation of a remote API
/// (an API defined in the `tomRemoteApis` registry, keyed by [apiId]).
///
/// Its endpoint methods are bound with [TomApiEndpointImplementation]. Supplies
/// the API-wide [errorHandler] and [logRequestsDefault] used when an endpoint
/// does not override them.
class TomApiImplementation extends TomService {
  /// The id of the API (in the remote-API registry) this class implements.
  final String apiId;

  /// API-wide error handler used by endpoints that don't declare their own.
  final TomErrorHandler? errorHandler;

  /// Whether requests to this API's endpoints are logged unless an endpoint
  /// overrides it.
  final bool logRequestsDefault;

  /// Binds this implementation to the API [apiId].
  const TomApiImplementation({
    required this.apiId,
    this.errorHandler,
    this.logRequestsDefault = true,
  });
}

/// The common contract for the endpoint-defining annotations: each can produce
/// the concrete [TomEndpoint] the pipeline routes.
///
/// Implemented by [TomEndpoint] itself (returns `this`) and by
/// [TomApiEndpointImplementation] (resolves the endpoint from the remote-API
/// registry).
abstract class TomEndpointBase<
  requestType extends Object,
  resultType extends Object
> {
  /// Resolves this annotation to the concrete [TomEndpoint] to route.
  ///
  /// [apiImplementation] is the class-level `@TomApiImplementation` of the
  /// service the annotated method belongs to (when there is one); registry-based
  /// endpoints fall back to its API-wide `errorHandler` / `logRequestsDefault`
  /// for any value the endpoint itself does not override.
  TomEndpoint<requestType, resultType> convertToTomEndpoint([
    TomApiImplementation? apiImplementation,
  ]);
}

/// Method-level annotation binding a method to an endpoint declared in the
/// remote-API registry (`tomRemoteApis[apiId][endpointId]`).
///
/// Unlike [TomEndpoint], the routing details (URI, methods, mime types, …) come
/// from the registered [TomApiEndpoint]; this annotation only adds
/// implementation-side overrides ([errorHandler], [logRequests], the CORS
/// settings). [convertToTomEndpoint] merges the two.
class TomApiEndpointImplementation<
  requestType extends Object,
  resultType extends Object
>
    implements TomEndpointBase<requestType, resultType> {
  /// The id of the API this endpoint belongs to.
  final String apiId;

  /// The id of the endpoint within the API.
  final String endpointId;

  /// Implementation-side error handler override.
  final TomErrorHandler? errorHandler;

  /// Implementation-side request-logging override (`null` = use the default).
  final bool? logRequests;

  /// `Access-Control-Allow-Origin` override for this endpoint.
  final String? corsAllowedOrigins;

  /// `Access-Control-Allow-Methods` override for this endpoint.
  final String? corsAllowedMethods;

  /// `Access-Control-Allow-Headers` override for this endpoint.
  final String? corsAllowedHeaders;

  /// Binds the method to endpoint [endpointId] of API [apiId].
  const TomApiEndpointImplementation({
    required this.apiId,
    required this.endpointId,
    this.errorHandler,
    this.logRequests,
    this.corsAllowedOrigins,
    this.corsAllowedMethods,
    this.corsAllowedHeaders,
  });

  @override
  TomEndpoint<requestType, resultType> convertToTomEndpoint([
    TomApiImplementation? apiImplementation,
  ]) {
    // The registry entry is declared with its own precise `<ReturnType,
    // RequestType>` (e.g. `TomApiEndpoint<Map<String, Object>, Object?>`), which
    // need not match this implementation annotation's inferred `<requestType,
    // resultType>` bounds (both default to `Object`). Dart generics are
    // invariant, so an `as TomApiEndpoint<requestType, resultType>` downcast
    // would fail at runtime for every endpoint whose registry types are more
    // specific than `Object`. Read the entry through the raw base type instead —
    // every field used below (methods, uri, consumes/produces, headers, …) is
    // non-generic, so the entry's reified type arguments are irrelevant here.
    final TomApiEndpoint endpoint = tomRemoteApis[apiId][endpointId];
    return TomEndpoint<requestType, resultType>(
      methods: endpoint.methods ?? [endpoint.method],
      formFields: endpoint.formFields,
      uri: (endpoint.api.uri ?? "") + (endpoint.uri ?? ""),
      consumes: endpoint.consumes,
      produces: endpoint.produces,
      contentDisposition: endpoint.contentDisposition,
      errorHandler:
          errorHandler ??
          apiImplementation?.errorHandler ??
          _tomDefaultErrorHandler,
      logRequests: logRequests ?? apiImplementation?.logRequestsDefault,
      // The contract states both directions; only the response one belongs
      // here. `endpoint.requestHeaders` is an instruction to the *client*
      // (`TomServerConnection` reads it when calling this endpoint) and has no
      // server-side counterpart — a header the caller was told to send is not
      // one to send back.
      headers: endpoint.responseHeaders,
      corsAllowedOrigins: corsAllowedOrigins,
      corsAllowedMethods: corsAllowedMethods,
      corsAllowedHeaders: corsAllowedHeaders,
      urlParameterMapping: endpoint.urlParameterMapping,
    );
  }
}

/// Method-level annotation that declares an HTTP endpoint inline (without a
/// remote-API registry entry).
///
/// It fully describes the route: the HTTP [methods] and [uri], what the body
/// [consumes] / [produces], any fixed response [headers] / [contentDisposition],
/// the per-endpoint [errorHandler] and [logRequests] flag, and the CORS
/// overrides. The pipeline reflects over annotated methods, binds each to its
/// route, and supplies the method's parameters from the request (JSON body,
/// path/query params, principal/token, or execution context).
///
/// A body declared as `multipart/form-data` ([consumes]) is decoded by the
/// pipeline: text parts fold into the request DTO — narrowed by [formFields]
/// when it is non-empty — and file parts bind to `TomFormFile` /
/// `TomMultipartForm` method parameters. A handler may return a `TomRedirect`
/// to answer with a `3xx`, or a shelf `Response` to own the body itself (which
/// is how the file endpoint streams a download).
class TomEndpoint<requestType extends Object, resultType extends Object>
    implements TomEndpointBase<requestType, resultType> {
  // Samples:
  // consumes = "application/x-www-form-urlencoded",
  // produces = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"

  /// The HTTP methods this endpoint answers (defaults to `GET`).
  final List<TomHttpMethod> methods;

  /// The text form fields this endpoint accepts from a `multipart/form-data`
  /// body, or empty for "every one that arrives".
  ///
  /// An allow-list, not a requirement: a named field that the form omits is
  /// simply absent from the DTO. It exists for the case where the form is
  /// filled in by something the endpoint does not control — a browser adds
  /// hidden fields, a proxy adds its own — and the endpoint would rather ignore
  /// them than fold them into its request object. An endpoint whose form it
  /// owns leaves this empty, exactly as a JSON endpoint does.
  final List<String> formFields;

  /// The route path the endpoint is mounted at.
  final String uri;

  /// The request body media type the endpoint accepts (defaults to JSON).
  ///
  /// `multipart/form-data` and `application/x-www-form-urlencoded` both select
  /// the form path: text parts fold into the request DTO and file parts bind to
  /// `TomFormFile` parameters. Which of the two a browser sends is decided by
  /// the form's markup, not by the endpoint, so declaring either is declaring
  /// "this is a form".
  ///
  /// **A form is the shape for a form, not for bulk transfer.** A multipart
  /// body is a single sequential stream — part N+1 is unreachable until part N
  /// has been drained — so every file part is buffered as it goes past, and
  /// `TomMultipartForm.globalSettingMaxFilePartBytes` (8 MiB) bounds it. An
  /// upload larger than that belongs on the raw-body file endpoint
  /// (`TomFileSlot`), where the whole request *is* the file, the slot is the
  /// URL, and nothing is buffered. Declare the form for "create a document
  /// **with** its attachment", where the title, the tags and the bytes arrive
  /// together and a raw body could carry only one of them; declare the file
  /// route for "replace the attachment of row 42".
  final TomMimeType consumes;

  /// The response body media type the endpoint produces (defaults to JSON).
  final TomMimeType produces;

  /// Optional `Content-Disposition` header for the response (e.g. downloads).
  final String? contentDisposition;

  /// Per-endpoint error handler (defaults to [TomDefaultErrorHandler]).
  final TomErrorHandler? errorHandler;

  /// Whether to log requests to this endpoint (`null` = use the global default).
  final bool? logRequests;

  /// Fixed headers the server adds to every response this endpoint produces.
  ///
  /// **Outbound only.** The name is bare `headers` because an endpoint
  /// declaration only ever speaks for the response: the pipeline copies these
  /// onto the response it builds (alongside the `Content-Type` derived from
  /// [produces] and any [contentDisposition]) and reads nothing from them. An
  /// endpoint cannot declare headers it *requires* of a request here — there is
  /// no field for that, and no request is rejected for lacking one.
  ///
  /// The registry-backed declaration style states the two directions
  /// separately, as `TomApiEndpoint.responseHeaders` and
  /// `TomApiEndpoint.requestHeaders`; only the former maps onto this field.
  /// `requestHeaders` instructs a *client* (`TomServerConnection` sends them
  /// when it calls the endpoint) and reaches nothing on the server.
  final Map<String, String> headers;

  /// `Access-Control-Allow-Origin` override for this endpoint.
  final String? corsAllowedOrigins;

  /// `Access-Control-Allow-Methods` override for this endpoint.
  final String? corsAllowedMethods;

  /// `Access-Control-Allow-Headers` override for this endpoint.
  final String? corsAllowedHeaders;

  /// Binds URL parameters — path captures *and* query-string parameters — to
  /// typed request-DTO fields.
  ///
  /// Keys are the parameter names on the URL: a route capture in [uri] (e.g.
  /// `id` in `/items/{id}`) or a query-string parameter name; values are the
  /// request-DTO field names the value is injected under before the DTO is
  /// instantiated. Path parameters not listed bind by their capture name
  /// (identity), so an empty map binds every path parameter by its own name;
  /// query parameters bind **only** when named here, so an endpoint opts into
  /// query binding per parameter. See `TomApiEndpoint.urlParameterMapping`.
  final Map<String, String> urlParameterMapping;

  /// Declares an endpoint; every field has a sensible default so only the
  /// differing ones need to be supplied.
  const TomEndpoint({
    this.methods = const [TomHttpMethod.get],
    this.formFields = const [],
    this.uri = "",
    this.consumes = TomMimeType.json,
    this.produces = TomMimeType.json,
    this.contentDisposition,
    this.errorHandler = _tomDefaultErrorHandler,
    this.logRequests,
    this.headers = const {},
    this.corsAllowedOrigins,
    this.corsAllowedMethods,
    this.corsAllowedHeaders,
    this.urlParameterMapping = const {},
  });

  @override
  TomEndpoint<requestType, resultType> convertToTomEndpoint([
    TomApiImplementation? apiImplementation,
  ]) {
    return this;
  }

  @override
  String toString() =>
      "$uri $methods $consumes $produces $contentDisposition $errorHandler $logRequests $formFields";
}

/// Class-level annotation telling the pipeline which bean provides a service's
/// implementation instance.
///
/// Exactly one of [componentName] or [referencedType] must be set (not both,
/// not neither); the pipeline resolves the instance from the bean registry by
/// name or by type.
class TomComponentReference {
  /// The registered bean name to resolve the implementation from.
  final String? componentName;

  /// The registered bean type to resolve the implementation from.
  final Type? referencedType;

  /// Points a service at its implementation bean by name or by type.
  const TomComponentReference({this.componentName, this.referencedType});
}

/// Method-level annotation requesting that an endpoint method run inside a
/// database transaction.
///
/// When present, the pipeline starts a transaction before invoking the method
/// and commits on success / rolls back on a thrown error. [isReadOnly] marks
/// the transaction as read-only; [isTransactional] can disable wrapping while
/// keeping the annotation in place.
class TomTransactional {
  /// Whether the method should be wrapped in a transaction at all.
  final bool isTransactional;

  /// Whether the transaction is read-only.
  final bool isReadOnly;

  /// Declares the transactional behaviour for an endpoint method.
  const TomTransactional({
    this.isReadOnly = false,
    this.isTransactional = true,
  });
}
