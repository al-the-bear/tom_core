# Tom Core Server API Reference: Endpoints Module

Annotation-driven HTTP endpoint framework: class- and method-level annotations
that describe services, routes, error handling, and transactions, plus the
reflection-based pipeline that scans them, mounts one shelf route per endpoint
method, and runs the per-request handling.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomErrorHandler](#tomerrorhandler)
  - [TomStatusMappingErrorHandler](#tomstatusmappingerrorhandler)
  - [TomDefaultErrorHandler](#tomdefaulterrorhandler)
  - [TomService](#tomservice)
  - [TomApiImplementation](#tomapiimplementation)
  - [TomEndpointBase&lt;requestType, resultType&gt;](#tomendpointbaserequesttype-resulttype)
  - [TomApiEndpointImplementation&lt;requestType, resultType&gt;](#tomapiendpointimplementationrequesttype-resulttype)
  - [TomEndpoint&lt;requestType, resultType&gt;](#tomendpointrequesttype-resulttype)
  - [TomComponentReference](#tomcomponentreference)
  - [TomTransactional](#tomtransactional)
  - [TomEndpointHandlerException](#tomendpointhandlerexception)
  - [TomEndpointPipelineException](#tomendpointpipelineexception)
  - [TomEndpointHandler](#tomendpointhandler)
  - [TomEndpointRouteKey](#tomendpointroutekey)
  - [TomEndpointRoutingInfo](#tomendpointroutinginfo)
  - [TomEndpointRouting](#tomendpointrouting)
  - [TomMethodMetadata](#tommethodmetadata)
  - [TomClassScanResult](#tomclassscanresult)
  - [TomFormBindingException](#tomformbindingexception)
  - [TomFormFile](#tomformfile)
  - [TomMultipartForm](#tommultipartform)
  - [TomRedirect](#tomredirect)
  - [TomWebSocketException](#tomwebsocketexception)
  - [TomWebSocketEndpoint&lt;requestType, resultType&gt;](#tomwebsocketendpointrequesttype-resulttype)
  - [TomWebSocketConnection](#tomwebsocketconnection)
  - [TomFileSlotException](#tomfileslotexception)
  - [TomFileSlot](#tomfileslot)
  - [TomFileSlots](#tomfileslots)
  - [TomFormFileStorage](#tomformfilestorage)
  - [TomFileEndpoint](#tomfileendpoint)
  - [TomFileService](#tomfileservice)
  - [TomFileServer](#tomfileserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/endpoints/endpoint_annotation.dart`,
`lib/src/tomserver/endpoints/endpoint_pipeline.dart`,
`lib/src/tomserver/endpoints/form_binding.dart`,
`lib/src/tomserver/endpoints/endpoint_results.dart`,
`lib/src/tomserver/endpoints/web_socket_endpoint.dart`,
`lib/src/tomserver/endpoints/file_endpoint.dart`.

`endpoint_annotation.dart` defines the declarative surface: `@tomService` /
`@TomApiImplementation` mark a class as a routable service, `@TomEndpoint`
(inline) or `@TomApiEndpointImplementation` (registry-backed) declare a
method's route, `@TomComponentReference` points a service at its implementation
bean, and `@TomTransactional` requests transaction wrapping. Errors are mapped
to responses via `TomErrorHandler` (default: `TomDefaultErrorHandler`).

`endpoint_pipeline.dart` is the runtime: `TomEndpointRouting` reflects over the
annotated classes, partitions them (`TomClassScanResult`), and mounts one
`TomEndpointHandler` per endpoint method onto a shelf `Router`. Each handler
answers CORS preflight, enforces access, binds the method's parameters from the
request, optionally opens a transaction, invokes the method by reflection, and
converts the result (or error) into a `Response`. `TomMethodMetadata` bundles
the collected annotations per method.

`form_binding.dart` decodes an HTML form body — `multipart/form-data` or
`application/x-www-form-urlencoded` — into a `TomMultipartForm` whose text
fields fold into the request DTO and whose `TomFormFile` parts bind to method
parameters. `endpoint_results.dart` adds `TomRedirect`, the directive a handler
returns to answer with a `3xx`. `web_socket_endpoint.dart` adds the socket
endpoint kind: `TomWebSocketEndpoint` is a `TomEndpointBase`, so it is scanned,
authorized and parameter-bound by the same pipeline, and the handler talks
through a `TomWebSocketConnection`.

`file_endpoint.dart` is the framework's own endpoint rather than a way to
declare one: a single service, `TomFileService` (default implementation
`TomFileServer`), serving `POST`/`PUT`/`GET`/`HEAD`/`DELETE` on
`/files/{entity}/{id}/{column}` through `TomFileEndpoint.handle`. The three path
segments name a **slot** — an addressable file column — and slots are derived
from reflection rather than declared: `TomFileSlots.register` walks an entity's
`@TomFileReference` columns and exposes the ones marked `exposed: true`, so
there is no second copy of a table or column name to drift. `TomFileSlot` is
what a registration produces, the interface where the entity and key generics
stop, and `TomFileSlotException` reports a registration or slot-resolution
failure. The `TomFormFileStorage` extension is the same registry reached from
the other upload shape: a `TomFormFile` from a multipart request stores through
the identical slot, so exposure, row scope and column grade apply to both.

This module owns the *HTTP* half of file transfer. The bytes themselves live in
a `TomBlobStore` — see the
[File Storage](api_summary_file_storage.md) summary for the backends, the key
grammar and the store registry — and the row-side contract
(`TomFileRepository`, `@TomFileReference`) belongs to
[Object Persistence](api_summary_object_persistence.md).

## Class Hierarchy

```
TomErrorHandler  (abstract)
    └── TomStatusMappingErrorHandler  (abstract)
            └── TomDefaultErrorHandler

TomService
    └── TomApiImplementation

TomEndpointBase<requestType, resultType>  (abstract)
    ├── TomApiEndpointImplementation<requestType, resultType>  (implements)
    ├── TomEndpoint<requestType, resultType>                   (implements)
    └── TomWebSocketEndpoint<requestType, resultType>          (implements)

TomComponentReference
TomTransactional

TomServerException  (little_things)
    ├── TomEndpointHandlerException
    ├── TomEndpointPipelineException
    ├── TomFormBindingException
    ├── TomWebSocketException
    └── TomFileSlotException

TomFileSlot  (abstract)

TomFileService  (abstract)
    └── TomFileServer  (implements)

TomEndpointHandler
TomEndpointRoutingInfo
TomEndpointRouting
TomMethodMetadata
TomClassScanResult
TomFormFile
TomMultipartForm
TomRedirect
TomWebSocketConnection
TomFileSlots
TomFileEndpoint

extension TomFormFileStorage on TomFormFile
```

## Classes

### TomErrorHandler

Turns an error raised while serving an endpoint into a shelf `Response`. The
pipeline calls one of three hooks depending on where the failure occurred; all
default to `handleErrorDefault`, the single method a concrete handler must
implement.

- **Extends:** none (abstract base)

#### Constructors

```dart
const TomErrorHandler()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `handleInvocationError` | `Response handleInvocationError(Object error, StackTrace stacktrace, Request r)` | Builds the response for an error thrown by the service method (delegates to `handleErrorDefault`). |
| `handleConversionError` | `Response handleConversionError(Object error, StackTrace stacktrace, Request r, Object? result)` | Builds the response for an error thrown while converting `result` into the body (delegates to `handleErrorDefault`). |
| `handleUnknowResultTypeError` | `Response handleUnknowResultTypeError(Object error, StackTrace stacktrace, Request r, Object? result)` | Builds the response for a `result` whose type cannot be mapped to a body (delegates to `handleErrorDefault`). Declared, and not reached by the pipeline today — that case leaves as a conversion error. |
| `handleErrorDefault` | `Response handleErrorDefault(Object error, StackTrace stacktrace, Request r, Object? result)` | The fallback every hook delegates to; the one method a concrete handler must implement. |

### TomStatusMappingErrorHandler

A `TomErrorHandler` that answers with the framework's error envelope
(`tomErrorEnvelope` under `x-tom-error: true`, declared `application/json`) and
with the status an error key is declared to mean. A subclass overrides
`statusByErrorKey`; every key it does not name is a `500`. It maps no status of
its own — the framework cannot know an application's keys, and the two
classifications it does make are made elsewhere and differently (an access
denial answers `404` from `TomEndpointHandler.accessDeniedResponse`, a login
failure is the authentication pipeline's).

- **Extends:** `TomErrorHandler`

#### Constructors

```dart
const TomStatusMappingErrorHandler()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusByErrorKey` | `Map<String, int>` | *(getter)* The status each error key answers with; every other key is a `500`. Keyed by the error key rather than by exception type, because the key is what crosses the wire and what a client branches on. Empty by default. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `statusFor` | `int statusFor(Object error)` | The status `error` answers with: `statusByErrorKey`'s entry for a `TomException`'s key, else `500`. Overridable for a rule a map cannot express — a whole key family, say — calling `super.statusFor(error)` for the rest. |
| `handleErrorDefault` | `Response handleErrorDefault(Object error, StackTrace stacktrace, Request r, Object? result)` | *(override)* The envelope at `statusFor(error)`. |

### TomDefaultErrorHandler

The default `TomErrorHandler`: the framework envelope with a `500`. What every
endpoint gets when it declares no handler of its own. It maps no key to any
other status.

- **Extends:** `TomStatusMappingErrorHandler`

#### Constructors

```dart
const TomDefaultErrorHandler()
```

### TomService

Class-level annotation marking a class as a service whose endpoint-annotated
methods should be scanned and routed. Applied via the `tomService` constant. A
class may be a `@tomService` *or* a `TomApiImplementation`, never both.

#### Constructors

```dart
const TomService()
```

### TomApiImplementation

Class-level annotation marking a class as the implementation of a remote API (an
API defined in the `tomRemoteApis` registry, keyed by `apiId`). Supplies the
API-wide `errorHandler` and `logRequestsDefault` used when an endpoint does not
override them.

- **Extends:** `TomService`

#### Constructors

```dart
const TomApiImplementation({
  required String apiId,
  TomErrorHandler? errorHandler,
  bool logRequestsDefault = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `apiId` | `String` | The id of the API (in the remote-API registry) this class implements. |
| `errorHandler` | `TomErrorHandler?` | API-wide error handler used by endpoints that don't declare their own. |
| `logRequestsDefault` | `bool` | Whether requests to this API's endpoints are logged unless overridden. |

### TomEndpointBase&lt;requestType, resultType&gt;

The common contract for the endpoint-defining annotations: each can produce the
concrete `TomEndpoint` the pipeline routes. Implemented by `TomEndpoint` itself
(returns `this`) and by `TomApiEndpointImplementation`.

- **Extends:** none (abstract)
- **Type Parameters:** `requestType extends Object`, `resultType extends Object`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `convertToTomEndpoint` | `TomEndpoint<requestType, resultType> convertToTomEndpoint([TomApiImplementation? apiImplementation])` | Resolves this annotation to the concrete `TomEndpoint` to route, inheriting API-wide defaults from `apiImplementation`. |

### TomApiEndpointImplementation&lt;requestType, resultType&gt;

Method-level annotation binding a method to an endpoint declared in the
remote-API registry (`tomRemoteApis[apiId][endpointId]`). The routing details
come from the registry; this annotation only adds implementation-side overrides.

- **Implements:** `TomEndpointBase<requestType, resultType>`
- **Type Parameters:** `requestType extends Object`, `resultType extends Object`.

#### Constructors

```dart
const TomApiEndpointImplementation({
  required String apiId,
  required String endpointId,
  TomErrorHandler? errorHandler,
  bool? logRequests,
  String? corsAllowedOrigins,
  String? corsAllowedMethods,
  String? corsAllowedHeaders,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `apiId` | `String` | The id of the API this endpoint belongs to. |
| `endpointId` | `String` | The id of the endpoint within the API. |
| `errorHandler` | `TomErrorHandler?` | Implementation-side error handler override. |
| `logRequests` | `bool?` | Implementation-side request-logging override (`null` = use the default). |
| `corsAllowedOrigins` | `String?` | `Access-Control-Allow-Origin` override for this endpoint. |
| `corsAllowedMethods` | `String?` | `Access-Control-Allow-Methods` override for this endpoint. |
| `corsAllowedHeaders` | `String?` | `Access-Control-Allow-Headers` override for this endpoint. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `convertToTomEndpoint` | `TomEndpoint<requestType, resultType> convertToTomEndpoint([TomApiImplementation? apiImplementation])` | *(override)* Reads the registry entry and merges it with this annotation's overrides and the API-wide defaults into a `TomEndpoint`. The entry's `responseHeaders` become `TomEndpoint.headers`; its `requestHeaders` are a client-side instruction and are not read here. |

### TomEndpoint&lt;requestType, resultType&gt;

Method-level annotation that declares an HTTP endpoint inline (without a
registry entry). It fully describes the route: HTTP `methods` and `uri`, what
the body `consumes` / `produces` and which of its `formFields` are folded into
the request DTO, how `urlParameterMapping` binds the URL onto that DTO, fixed
`headers` / `contentDisposition`, the per-endpoint `errorHandler` and
`logRequests`, and CORS overrides.

- **Implements:** `TomEndpointBase<requestType, resultType>`
- **Type Parameters:** `requestType extends Object`, `resultType extends Object`.

#### Constructors

```dart
const TomEndpoint({
  List<TomHttpMethod> methods = const [TomHttpMethod.get],
  List<String> formFields = const [],
  String uri = "",
  TomMimeType consumes = TomMimeType.json,
  TomMimeType produces = TomMimeType.json,
  String? contentDisposition,
  TomErrorHandler? errorHandler = const TomDefaultErrorHandler(),
  bool? logRequests,
  Map<String, String> headers = const {},
  String? corsAllowedOrigins,
  String? corsAllowedMethods,
  String? corsAllowedHeaders,
  Map<String, String> urlParameterMapping = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `methods` | `List<TomHttpMethod>` | The HTTP methods this endpoint answers (defaults to `GET`). |
| `formFields` | `List<String>` | Allow-list of text form fields folded into the request DTO from a form body; empty means "every field that arrives". |
| `uri` | `String` | The route path the endpoint is mounted at. |
| `consumes` | `TomMimeType` | The request body media type the endpoint accepts (defaults to JSON). `multipart/form-data` and `application/x-www-form-urlencoded` both select the form path; which of the two a browser sends is decided by the form's markup. A form is the shape for a form, not for bulk transfer — every file part is buffered and bounded by `TomMultipartForm.globalSettingMaxFilePartBytes`, and a larger upload belongs on the raw-body file endpoint. |
| `produces` | `TomMimeType` | The response body media type the endpoint produces (defaults to JSON). |
| `contentDisposition` | `String?` | Optional `Content-Disposition` header for the response. |
| `errorHandler` | `TomErrorHandler?` | Per-endpoint error handler (defaults to `TomDefaultErrorHandler`). |
| `logRequests` | `bool?` | Whether to log requests (`null` = use the global default). |
| `headers` | `Map<String, String>` | Fixed headers the server adds to every **response** this endpoint produces. Outbound only — an endpoint cannot declare headers it requires of a request. A registry-backed endpoint fills this from `TomApiEndpoint.responseHeaders`; that entry's `requestHeaders` instruct a *client* and reach nothing on the server. |
| `corsAllowedOrigins` | `String?` | `Access-Control-Allow-Origin` override for this endpoint. |
| `corsAllowedMethods` | `String?` | `Access-Control-Allow-Methods` override for this endpoint. |
| `corsAllowedHeaders` | `String?` | `Access-Control-Allow-Headers` override for this endpoint. |
| `urlParameterMapping` | `Map<String, String>` | Binds URL parameters — path captures **and** query-string parameters — to typed request-DTO field names. The two are not symmetric. A path capture the map does not name binds under its own name, so an **empty map still binds every path parameter** and the map is needed only to rename one. A query parameter binds **only** when the map names it, with no identity fallback, so this map is the per-parameter opt-in to query binding and an endpoint that leaves it empty receives nothing at all from the query string. See `TomEndpointHandler.injectPathParameters` and `injectQueryParameters`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `convertToTomEndpoint` | `TomEndpoint<requestType, resultType> convertToTomEndpoint([TomApiImplementation? apiImplementation])` | *(override)* Returns `this`. |
| `toString` | `String toString()` | *(override)* Compact description of the endpoint's route/mime/handler fields. |

### TomComponentReference

Class-level annotation telling the pipeline which bean provides a service's
implementation instance. Exactly one of `componentName` or `referencedType` must
be set; the pipeline resolves the instance from the bean registry by name or by
type.

#### Constructors

```dart
const TomComponentReference({
  String? componentName,
  Type? referencedType,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `componentName` | `String?` | The registered bean name to resolve the implementation from. |
| `referencedType` | `Type?` | The registered bean type to resolve the implementation from. |

### TomTransactional

Method-level annotation requesting that an endpoint method run inside a database
transaction. When present, the pipeline starts a transaction before invoking the
method and commits on success / rolls back on a thrown error.

#### Constructors

```dart
const TomTransactional({
  bool isReadOnly = false,
  bool isTransactional = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isTransactional` | `bool` | Whether the method should be wrapped in a transaction at all. |
| `isReadOnly` | `bool` | Whether the transaction is read-only. |

### TomEndpointHandlerException

Thrown while *serving* a request: access denied, parameter instantiation
failure, a failing error handler, or a result that cannot be converted.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomEndpointHandlerException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomEndpointPipelineException

Thrown while *building* the router from reflected metadata: conflicting
annotations, an invalid component reference, an unknown HTTP method, etc.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomEndpointPipelineException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomEndpointHandler

Serves one endpoint: binds a reflected service method to a route and runs the
per-request pipeline (preflight, access control, parameter binding, optional
transaction, invocation, result/error conversion).

#### Constructors

```dart
TomEndpointHandler({
  required String name,
  required InstanceMirror instance,
  required MethodMirror method,
  ClassMirror? interface,
  required ClassMirror implementation,
  required String methodName,
  required TomMethodMetadata metadata,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isBindablePrimitive` | `static bool isBindablePrimitive(Type type)` | Whether `type` is one this module binds from a raw URL string (`String`, `int`, `double`, `num`, `bool`). The question `coercePrimitiveParameter`'s answer cannot carry: that method returns `null` both for a type it does not handle and for a value that would not parse, and the two are different answers. Asked first by the binding loop, so past it a `null` means the value did not parse — which is what makes a malformed number a named refusal rather than a parameter that quietly goes unbound. |
| `coercePrimitiveParameter` | `static Object? coercePrimitiveParameter(Type type, String raw)` | Coerces a raw URL string into the parameter's primitive `type`, or `null` when `type` is not a bindable primitive **or** the value will not parse. Tell the two apart with `isBindablePrimitive`. A `bool` accepts `true`/`false`, `1`/`0`, `yes`/`no` and `on`/`off`, case-insensitively, and answers `null` for anything else — it was `raw == 'true'`, which is total, so every unrecognised spelling produced `false` and `?active=TRUE` meant the opposite of what the caller wrote. |
| `injectPathParameters` | `static void injectPathParameters(Map<String, dynamic> jsonBodyData, Request req, TomEndpoint endpoint)` | Folds the request's URL path parameters into `jsonBodyData` under the DTO field names declared by `endpoint.urlParameterMapping`. |
| `injectQueryParameters` | `static void injectQueryParameters(Map<String, dynamic> jsonBodyData, Request req, TomEndpoint endpoint, {Set<String> declaredParameterNames = const {}})` | Folds query-string values into `jsonBodyData`, but only those the endpoint explicitly maps. A parameter that neither the mapping nor `declaredParameterNames` names is dropped and reported at **debug**, naming the endpoint and the parameter names — never their values, since a query string is where an OAuth `code` arrives. `declaredParameterNames` are the handler method's own parameter names, excluded because a bare primitive parameter binds from the query string by its own name several strategies earlier; reporting those would cry wolf on the documented case. |
| `injectFormFields` | `static void injectFormFields(Map<String, dynamic> jsonBodyData, TomMultipartForm form, TomEndpoint endpoint)` | Folds a form body's text fields into `jsonBodyData`, narrowed by `endpoint.formFields` when it is non-empty. |
| `decodeJsonObjectBody` | `static Map<String, dynamic> decodeJsonObjectBody(String body, ClassMirror parameterMirror)` | Decodes a request body that must be a JSON object, raising `request_body_not_json` both for bytes that are not valid JSON and for JSON that is not an object. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | A human-readable identifier for the route (used in logs). |
| `instance` | `InstanceMirror` | The reflected service instance the method is invoked on. |
| `method` | `MethodMirror` | The reflected endpoint method. |
| `interface` | `ClassMirror?` | The service interface/annotation type, when routed via an interface; `null` for a registry-backed method, which is identified by its contract instead. |
| `implementation` | `ClassMirror` | The concrete implementation class mirror. |
| `methodName` | `String` | The method's own name, unqualified, as it appears in a resource key (`<Interface>.<methodName>`). |
| `metadata` | `TomMethodMetadata` | The collected annotation metadata (endpoint, access, transaction, API). |
| `declaresNoResult` | `late final bool` | Whether the endpoint's declaration promises the caller no result, so that the response body is empty whatever the invocation completes with. Read off the annotated declaration (`metadata.methodMirror`) rather than the implementation's mirror, which may narrow `Future<void>` to something that carries a value. |
| `shouldLogRequests` | `bool` | *(getter)* Whether this route logs. `TomEndpoint.logRequests` is three-state and `null` — the value for an endpoint that says nothing — defers to `globalSettingLogRequestsDefault`. Every logging decision in the pipeline reads this rather than the annotation, because reading the annotation collapses the third state into `false` and leaves the global setting governing nothing. |
| `automaticProtectionKeys` | `(String container, String member)` | *(getter)* The resource-key pair an endpoint without an explicit key is protected under. Keyed on `interface` when the method is routed through one and on the contract's `implementation` when it is not; non-nullable, because there is no unprotectable endpoint. |
| `globalSettingLogRequestsDefault` | `static bool` | Whether requests are logged when an endpoint does not specify `logRequests`. |
| `globalSettingCorsAllowedOriginsDefault` | `static String` | Default `Access-Control-Allow-Origin` when an endpoint does not override it. |
| `globalSettingCorsAllowedMethodsDefault` | `static String` | Default `Access-Control-Allow-Methods` when an endpoint does not override it. |
| `globalSettingCorsAllowedHeadersDefault` | `static String` | Default `Access-Control-Allow-Headers` when an endpoint does not override it. |
| `debugPrintContext` | `static bool` | When true, logs the request context for each call (debugging aid). |
| `debugPrintAuthentication` | `static bool` | When true, logs the resolved principal/token for each call (debugging aid). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `handlePreflight` | `Response handlePreflight(Request req)` | Answers a CORS preflight (`OPTIONS`) request with the endpoint's (or global default) allowed origins/methods/headers. |
| `handleMethodCall` | `Future<Response> handleMethodCall(Request req)` | Runs the full request pipeline for this endpoint and returns the response. |
| `handleWebSocketCall` | `Future<Response> handleWebSocketCall(Request req)` | Serves a WebSocket handshake: enforces access, binds parameters *before* the upgrade, and runs the handler inside the captured request zone. Logs both outcomes and does so from two places, because they leave by two routes: a refused upgrade returns a response and is logged with its status, while an accepted one ends in `Request.hijack` — which throws `HijackException` by contract — so its line is written from the `catch` and the exception is rethrown. Catching it would leave shelf writing an ordinary reply over a socket the handshake has already claimed. |
| `enforceAccess` | `Future<void> enforceAccess()` | Runs the access check and its denial audit; shared by the HTTP and WebSocket paths. Throws `tomEndpointAccessDeniedErrorKey` on a denial — an exception that does not leave the pipeline, since both callers turn it into `accessDeniedResponse`. |
| `accessDeniedResponse` | `static Response accessDeniedResponse()` | The response a denied caller receives: a bare `404`, indistinguishable from a route that does not exist, with no error envelope and no error key. A `403` would hand an unauthorized caller a working oracle — walk the id space, and the ids answering `403` are the rows that exist — and the contract arm leaks the same way at the level of the route. The diagnosis moves to the audit record and the server log, where the operator has it and the caller does not. Deliberately not routed through `TomEndpoint.errorHandler`: those hooks are for errors *of the invocation*, and one written to map a domain exception would be handed a security decision it was not written for. |
| `bindParameters` | `Future<List<Object>> bindParameters(Request req, {Map<Type, Object> extraByType = const {}})` | Builds the method's positional arguments from the request; `extraByType` supplies values only the endpoint kind knows (the socket connection). |
| `shouldLogRequests` | `bool get shouldLogRequests` | Whether this endpoint's requests are logged: the `logRequests` annotation when it states one, otherwise `globalSettingLogRequestsDefault`. Every log statement in the pipeline reads this rather than the annotation, so a `null` annotation reaches the global default. |
| `checkAccess` | `bool checkAccess(TomPrincipal? principal)` | Decides whether `principal` may call this endpoint from its resolved access control, falling back to the global protection default. |
| `automaticProtectionKeys` | `(String container, String member) get automaticProtectionKeys` | The pair of resource keys this endpoint is automatically protected under: the API id/interface name granting all of it, and the `<container>.<member>` key granting this one endpoint. |
| `checkAutomaticAccess` | `bool checkAutomaticAccess(bool accessCheck)` | Second-chance access check over `automaticProtectionKeys`; returns the possibly-upgraded decision. Returns `accessCheck` unchanged while resource keys are not enforced (`TomResourceKeyProtection.globalSettingProtectionDefault` off), since every key would read as held. |

### TomEndpointRouteKey

Identifies one mounted route: a path template *and* the HTTP method it was
mounted for. `uri` is the route as declared (`/items/{id}`), not its
`shelf_router` translation; `method` is the uppercase wire name
(`TomHttpMethod.name`) rather than the instance, because `TomHttpMethod` does
not define value equality.

```dart
typedef TomEndpointRouteKey = ({String uri, String method})
```

### TomEndpointRoutingInfo

Pairs a mounted route's handler with the endpoint it was built from and the HTTP
method this particular mount answers.

#### Constructors

```dart
TomEndpointRoutingInfo(TomEndpointHandler handler, TomEndpoint endpoint, TomHttpMethod method)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `handler` | `TomEndpointHandler` | The handler invoked for the route. |
| `endpoint` | `TomEndpoint` | The endpoint definition the route was built from. |
| `method` | `TomHttpMethod` | The single HTTP method this entry was mounted for; a WebSocket endpoint records `GET`. |

### TomEndpointRouting

Builds the shelf `Router` for the application by reflecting over annotated
service/API classes and mounting one route per endpoint method. The mounted
handlers and a `TomEndpointRouteKey`→`TomEndpointRoutingInfo` map are exposed
statically, read-only, for diagnostics.

#### Constructors

```dart
TomEndpointRouting()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `shelfRoutePath` | `static String shelfRoutePath(String uri)` | Translates a Tom route template (`{name}`) into the `shelf_router` path syntax (`<name>`). |
| `resetRoutes` | `static void resetRoutes()` | Forgets every mounted route, so the next mount starts from an empty table. `initializeRouter` calls it, which is what makes `handlers` answer for the *last* run rather than every run since the process started. Public for a test that mounts routes directly, without a router; there is no other caller. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `handlers` | `static List<TomEndpointHandler>` | Every endpoint handler mounted during the last `initializeRouter` run. An unmodifiable *view* of the live list: reading it shows a later mount and costs nothing, while `add` / `clear` / assignment throw `UnsupportedError`. Appending would describe a route nothing serves and removing would hide one still served — neither changes what the server answers, so neither is visible except as a reader being wrong about the process. |
| `routingInfo` | `static Map<TomEndpointRouteKey, TomEndpointRoutingInfo>` | Mounted routes for diagnostics, one entry per route *and* HTTP method. Only declared methods are listed; the automatic `OPTIONS` preflight is not. An unmodifiable view, for the reason `handlers` is one. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `scanClasses` | `TomClassScanResult scanClasses()` | Reflects over the annotated classes and partitions them into service interfaces, API implementations, and components. |
| `initializeRouter` | `Router initializeRouter()` | Scans the annotated classes and mounts every endpoint method onto a fresh `Router`, returning it. Calls `resetRoutes` first, so the diagnostics tables describe this run and not the union of every run since the process started. |
| `registerFrameworkApis` | `void registerFrameworkApis()` | Registers the APIs the framework ships (preferences, OAuth) before the scan, so a deployment does not have to name an endpoint it never asked for. Idempotent — the registry is keyed by API id, so repeated router initialisations cannot double-mount. |
| `instantiateComponent` | `Object? instantiateComponent(ClassMirror componentType)` | Last-resort resolution: constructs `componentType` through its no-argument constructor, registers the instance as the bean for its type, and returns it — or `null` when it cannot be built that way. A `@tomComponent` that needs no arguments is fully described by its own declaration, so building it is not a guess; anything with a real constructor still belongs to the application. An application that registered its own bean is never overridden, because this only runs when the lookup came back empty. |
| `createRoutesForClassMirror` | `void createRoutesForClassMirror(ClassMirror serviceType, Object? serviceInstance, Router router)` | Mounts every endpoint method of `serviceType` onto `router`, building a handler per method. |
| `getReferencedComponent` | `Object? getReferencedComponent(ClassMirror serviceType)` | Resolves the implementation instance named by a `TomComponentReference` on `serviceType`, or `null`. |
| `createRoutesForEndpoint` | `void createRoutesForEndpoint(TomEndpoint<Object, Object> tep, Router router, TomEndpointHandler teph, TomMethodMetadata mmd, ClassMirror instanceClassMirror)` | Registers `teph` on `router` for each HTTP method of `tep` (plus `OPTIONS`) and records it. |
| `getClassMethodMetadata` | `List<TomMethodMetadata> getClassMethodMetadata(ClassMirror classMirror)` | Collects the merged `TomMethodMetadata` for each endpoint-annotated method of `classMirror`. |
| `findServiceInstance` | `Object? findServiceInstance(List<ClassMirror> componentClasses, ClassMirror serviceType, Object? serviceInstance)` | Fallback resolution: finds a component class implementing `serviceType` and returns its bean. |

### TomMethodMetadata

All annotation metadata collected for one endpoint method: the reflected method
plus its endpoint, optional access control and transaction info, and (for
registry-based endpoints) the resolved remote-API tags.

#### Constructors

```dart
TomMethodMetadata({
  required TomEndpoint endpoint,
  required MethodMirror methodMirror,
  TomAccessControl? access,
  TomTransactional? transactionInfo,
  TomAudited? audited,
  TomApiEndpointImplementation? apiEndpointImplementation,
  TomApiImplementation? apiImplementation,
  TomApi? api,
  TomApiEndpoint? apiEndpoint,
  TomWebSocketEndpoint? webSocket,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `methodMirror` | `MethodMirror` | The reflected endpoint method. |
| `endpoint` | `TomEndpoint` | The endpoint definition (route, mime types, error handler, …). |
| `access` | `TomAccessControl?` | The access-control rule, if the method declared one. |
| `transactionInfo` | `TomTransactional?` | The transaction directive, if the method declared one. |
| `audited` | `TomAudited?` | The `@TomAudited` declaration, if the method opted its invocation into the audit trail. `null` for the great majority of endpoints, and that is the intended state: endpoint auditing is *declared*, because most endpoint calls are reads whose auditing would drown the trail. Mutation auditing needs no declaration — it happens at the repository. |
| `webSocket` | `TomWebSocketEndpoint?` | The socket declaration, when the method is a WebSocket endpoint (kept alongside the `endpoint` it converts to). |
| `apiEndpointImplementation` | `TomApiEndpointImplementation?` | The `@TomApiEndpointImplementation` tag, for registry-based endpoints. |
| `apiImplementation` | `TomApiImplementation?` | The class's `@TomApiImplementation` tag, for registry-based endpoints. |
| `api` | `TomApi?` | The resolved remote API, for registry-based endpoints. |
| `apiEndpoint` | `TomApiEndpoint?` | The resolved remote-API endpoint, for registry-based endpoints. |

### TomClassScanResult

The partitioned result of scanning the annotated classes: interface-based
services, remote-API implementations, and component classes.

#### Constructors

```dart
TomClassScanResult({
  List<ClassMirror> serviceInterfaces = const [],
  List<ClassMirror> apiImplementations = const [],
  List<ClassMirror> componentClasses = const [],
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `serviceInterfaces` | `List<ClassMirror>` | Classes annotated with `@tomService` (interface-based services). |
| `apiImplementations` | `List<ClassMirror>` | Classes annotated with `@TomApiImplementation`. |
| `componentClasses` | `List<ClassMirror>` | Classes annotated with `@TomComponent` (candidate implementations). |

### TomFormBindingException

Thrown while decoding or binding an HTML form body. Always caused by what the
caller sent — a malformed envelope, a part over the size ceiling, a declared
file part that never arrived — so it surfaces as a client error.

#### Constructors

```dart
TomFormBindingException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomFormFile

One uploaded file part of a `multipart/form-data` request: the bytes plus what
the envelope said about them. The file name is a display hint, never a path,
and the media type is a claim the store records rather than a fact it verifies.

#### Constructors

```dart
TomFormFile({
  required String field,
  required Uint8List bytes,
  String? fileName,
  String? mediaType,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The form field name the part arrived under. |
| `fileName` | `String?` | The file name the client supplied, if any (a hint, not a path). |
| `mediaType` | `String?` | The media type the part declared, if any. |
| `bytes` | `Uint8List` | The part's bytes. |
| `byteCount` | `int` | The size of the part, in bytes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `openRead` | `Stream<List<int>> openRead()` | The part's bytes as a stream, for handing to a store. |

See also [TomFormFileStorage](#tomformfilestorage) below, the extension that
uploads a part through the file-slot registry.

### TomMultipartForm

The decoded body of a form request: its text `fields` and its uploaded `files`.
Produced once per request and handed to the pipeline, which folds the fields
into the request DTO and binds the files to the handler's parameters.

#### Constructors

```dart
TomMultipartForm({
  required Map<String, String> fields,
  required List<TomFormFile> files,
})
```

#### Static Members

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `globalSettingMaxFilePartBytes` | `static int` | The largest a single file part may be before it is refused (default 8 MiB). A part must be materialised to be read — part N+1 is unreachable until part N is drained — so the ceiling bounds an allocation the caller would otherwise choose. There is no streaming form path, including for the single-file form: "the file is the last part" is a property of the page's markup, not of the protocol. A transfer that outgrows this changes route to the raw-body file endpoint, not shape. |
| `readForm` | `static Future<TomMultipartForm?> readForm(Request req)` | Decodes `req` as `multipart/form-data`, or returns `null` when it is not one. Reads the body, so it may be called once per request. |
| `readUrlEncodedForm` | `static Future<TomMultipartForm> readUrlEncodedForm(Request req)` | Decodes `req` as `application/x-www-form-urlencoded`; the result never carries files. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fields` | `Map<String, String>` | The text parts, keyed by field name; a repeated name keeps the last value. |
| `files` | `List<TomFormFile>` | The uploaded file parts, in arrival order. |
| `isEmpty` | `bool` | Whether the request carried no parts at all. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `file` | `TomFormFile? file(String field)` | The single file part named `field`, or `null`; when repeated, the **first** wins. |
| `filesNamed` | `List<TomFormFile> filesNamed(String field)` | Every file part named `field`, in arrival order. |

### TomRedirect

The directive a handler returns to answer with a `3xx`. A redirect is fully
described by a status and a URL, so the handler states what it wants and the
pipeline builds the response.

#### Constructors

```dart
TomRedirect(String location, {int status = 303})
TomRedirect.seeOther(String location)    // 303
TomRedirect.temporary(String location)   // 307
TomRedirect.permanent(String location)   // 308
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `location` | `String` | The URL to redirect to. |
| `status` | `int` | The `3xx` status to answer with. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toResponse` | `Response toResponse()` | Builds the bodiless response carrying the `Location` header. |

### TomWebSocketException

Thrown when a WebSocket endpoint is declared or used in a way the pipeline
cannot serve (a non-socket endpoint routed to the socket handler, a connection
used before it is attached, a second attach).

#### Constructors

```dart
TomWebSocketException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomWebSocketEndpoint&lt;requestType, resultType&gt;

Method-level annotation declaring a WebSocket endpoint. The method is invoked
once per accepted connection and its returned future ends the conversation.
Implements `TomEndpointBase`, which is what the pipeline's scan keys on.

#### Constructors

```dart
const TomWebSocketEndpoint({
  required String uri,
  List<String> protocols = const [],
  List<String> allowedOrigins = const [],
  Duration? pingInterval,
  Map<String, String> urlParameterMapping = const {},
  bool? logRequests,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `uri` | `String` | The route path the socket is mounted at. |
| `protocols` | `List<String>` | Subprotocols the endpoint will speak, in preference order; empty = none. |
| `allowedOrigins` | `List<String>` | Browser origins allowed to open the socket; empty = any. |
| `pingInterval` | `Duration?` | How often to ping an idle connection, or `null` to never ping. |
| `urlParameterMapping` | `Map<String, String>` | Binds URL parameters to typed request-DTO fields, forwarded verbatim to the `TomEndpoint` the handshake routes with, and read with the same asymmetry described under `TomEndpoint.urlParameterMapping`: path captures bind with or without an entry, query-string parameters **only** with one. A handshake is a `GET` with no body, so the URL is the only place a socket endpoint's request DTO can come from — an empty map leaves a `?token=…` unbound. |
| `logRequests` | `bool?` | Whether handshake requests are logged (`null` = default). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `convertToTomEndpoint` | `TomEndpoint<requestType, resultType> convertToTomEndpoint([TomApiImplementation? apiImplementation])` | *(override)* Produces the `GET`-only `TomEndpoint` the pipeline routes with. |

### TomWebSocketConnection

A live WebSocket connection as a handler sees it. Created before the upgrade —
so a binding failure is an ordinary HTTP error — and attached to the channel at
the moment the connection is accepted, which is when the handler is invoked.

#### Constructors

```dart
TomWebSocketConnection()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subprotocol` | `String?` | The subprotocol agreed during the handshake, or `null`. |
| `isOpen` | `bool` | Whether the socket has been attached and not yet closed from this side. |
| `messages` | `Stream<dynamic>` | Messages from the peer: `String` for a text frame, `List<int>` for a binary one. Counted as they pass, for `messagesReceived`; the stream is cached so reading the getter twice yields the one stream the channel has. |
| `messagesReceived` | `int` | How many frames the peer has sent, counted as the handler reads them. A frame the handler never read is not counted — the count rides on the single-subscription stream, so this is what the conversation consumed. |
| `messagesSent` | `int` | How many frames this side has sent. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `attachChannel` | `void attachChannel(WebSocketChannel channel, [String? subprotocol])` | Attaches the accepted channel; called by the pipeline, not by application code. |
| `sendText` | `void sendText(String message)` | Sends a text frame. |
| `sendBytes` | `void sendBytes(List<int> bytes)` | Sends a binary frame. |
| `close` | `Future<void> close([int? code, String? reason])` | Closes the socket; idempotent. |

### TomFileSlotException

Thrown while registering or resolving a file slot. Registration failures are
**scan-time** errors — they surface when the application wires itself up rather
than when a user uploads a file, which is the point of deriving slots from
reflection instead of from a hand-written mapping table.

#### Constructors

```dart
TomFileSlotException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomFileSlot

One addressable file column: everything the endpoint needs to serve
`<table>/<id>/<column>`, with the entity and key types already bound.

This is where the generics stop. The endpoint is not generic and cannot be — a
URL carries strings, and the entity type behind a slot is known only once the
application registers its repository — so `TomFileSlots` stores slots as
`TomFileSlot` and each one closes over the `<T, K>` it was registered with.
Implementations are produced by `TomFileSlots.register`; applications hold the
interface, not a class of their own.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `table` | `String` | The table name the slot is addressed by (`@TomDbTable.table`). |
| `column` | `String` | The column name the slot is addressed by (the mapped column name). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `upload` | `Future<TomFileMetadata> upload(String rawId, Stream<List<int>> bytes, {String? mediaType, String? fileName})` | Stores `bytes` against row `rawId` and returns the descriptor. The storage key is minted by the store, never named by the caller — a client that could choose a key could choose someone else's. |
| `describe` | `Future<TomFileMetadata?> describe(String rawId)` | The descriptor of the file on row `rawId`, or `null` when the row holds none. |
| `open` | `Stream<List<int>> open(String rawId, {TomBlobRange? range})` | Streams the file on row `rawId`, or `range` of it. `TomFileEndpoint` passes the range it read from an HTTP `Range` header, already resolved and clamped against the descriptor's size. |
| `clear` | `Future<bool> clear(String rawId)` | Removes the file on row `rawId`; `false` when there was none to remove. |

### TomFileSlots

The registry of HTTP-reachable file columns, keyed by table and column name.

Registration is per **repository**, not per column: the repository already
carries the entity type, the key type and — through the entity's annotations —
the table name, the column names and the blob store. Anything an application had
to restate is something that could drift.

Exposure is default-closed. Reflection can see every `@TomFileReference` column;
it publishes only those declaring `exposed: true`. What exposure decides is
*which* column a slot names, never *whether* a caller may have it — that stays
with the row scope (C-3) and column grade (C-4) the repository enforces, and the
endpoint access check the pipeline runs first.

The registry is a process-wide **static**, and Dart isolates do not share
statics, so it is really one registry per isolate: an application serving from
several must run its `register` calls in each, which is what a start-up path
already does. An isolate that did not is the one failure that would otherwise be
silent, and `resolve` refuses it by name rather than answering the 404 a closed
column gets.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register<T extends Object, K>(TomFileRepository<T, K> repository)` | Registers every exposed `@TomFileReference` column of `T`. Throws `TomFileSlotException` at wire-up time when the entity declares no `@TomDbTable` (`entity_not_mapped`), exposes no file column (`no_exposed_column`), would produce an ambiguous slot (`ambiguous_slot`), or collides with one already registered (`duplicate_slot`). Call it in the start-up path **every isolate runs**: the registry is a static, statics are per isolate, and registering twice in one isolate is refused — so once per isolate is both the requirement and the only thing that works. |
| `resolve` | `static TomFileSlot? resolve(String table, String column)` | The slot serving `<table>/<column>`, or `null` when none is exposed. A non-exposed column is deliberately indistinguishable from a non-existent one. An **empty** registry is the exception: it means no slot was registered in this isolate at all, and a file request arriving says somebody expected one — so it throws `TomFileSlotException` (`file_endpoint.no_slots_registered`, logged) rather than letting a bootstrap that did not run read as a closed column. |
| `reset` | `static void reset()` | Forgets every registration. For tests, which build a fresh registry per case; an application registers once per isolate at startup and never calls it. A test that resets while another test's slots are live deregisters those too — they share the isolate, and the registry is the isolate's. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `slots` | `List<String>` | Every registered slot as `<table>/<column>` — for diagnostics and tests. |

### TomFormFileStorage

An extension on `TomFormFile`: stores a file that arrived as one part of a
`multipart/form-data` request.

The join between the two upload shapes, and deliberately thin — a form part
reaches the blob store through the *same* `TomFileSlot` the raw-body endpoint
uses, so exposure, the row scope (C-3) and the column grade (C-4) all apply to
it unchanged. Multipart changes only how the bytes reach the handler.

The call is the handler's rather than the pipeline's, and that ordering is
load-bearing: on a create the row does not exist while the body is being read,
so the id the slot is addressed by is known only once the handler has saved the
entity.

```dart
final saved = await documents.save(request.toDocument());
await attachment.storeIn('document', 'attachment', '${saved.id}');
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `storeIn` | `Future<TomFileMetadata> storeIn(String table, String column, String rowId)` | Stores this part in the file slot `<table>/<column>` of row `rowId`. Throws `TomFileSlotException` (`unknown_slot`) when no such slot is exposed — the same answer the HTTP endpoint gives, because it is the same registry and the same default-closed rule. |

### TomFileEndpoint

Serves the file-transfer wire contract over the registered `TomFileSlots`. Not
constructible: the whole surface is static, because everything a request needs
is in the request and the registry.

`handle` takes a shelf `Request` and returns a shelf `Response` rather than a
reflected DTO because both directions must stream — a file large enough to be
worth storing is large enough not to want in memory twice.

The status codes are a deliberate set rather than a default mapping. A column
refusal (C-4) is **403**: the caller is addressing a slot that exists and may
not have it. A row refusal (C-3) is **404**, because the id in the slot is
supplied by the caller and a 403 would confirm that a guessed id names a real
row belonging to someone else. An unknown or unexposed slot is 404, an
unparseable id is 400, and an unsupported method is 405.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `basePath` | `String` | The path the endpoint is mounted at (`/files`); a client's `baseUri` ends here. |
| `routeUri` | `String` | The route pattern, with the three slot segments as path variables (`/files/{entity}/{id}/{column}`). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `handle` | `static Future<Response> handle(Request request)` | Serves one file request, dispatching on the HTTP method. |

### TomFileService

The file-transfer service interface, mounted by the endpoints pipeline like any
other `@tomService`.

One method for all five verbs: the wire contract addresses a single resource and
varies only the method, and splitting it would mean four copies of a slot
resolution that has to be identical across them. Its `consumes` is deliberately
**not** JSON — the pipeline reads a body into a string only for a JSON endpoint,
so declaring octet-stream is what leaves the upload stream intact all the way to
the blob store.

The endpoint carries `@TomAuthenticatedAccess()` because its other protections
cannot stand in for it: the row scope and the column grade are both
principal-*relative*, so an exposed column on an unscoped, ungraded entity would
otherwise be world-readable. An application wanting anonymous file access
declares its own `TomFileService` component with a different access control — a
handler-side annotation is a local override (G-API-3).

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `file` | `Future<Response> file(Request request)` | `POST`/`PUT`/`GET`/`HEAD`/`DELETE` on `/files/{entity}/{id}/{column}`. |

### TomFileServer

The default `TomFileService` implementation, and the bean an application
registers to mount the endpoint:

```dart
TomFileSlots.register(documentRepository); // TomFileRepository<Document, int>
TomBean.withType<TomFileServer>(TomFileServer());
```

Holds no state — the registry is `TomFileSlots` and the request is the argument
— so the pipeline may construct it itself when an application has registered no
bean of its own.

#### Constructors

```dart
TomFileServer()
```

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomService` | `const TomService tomService` | The annotation instance to mark a class with `TomService` (applied as `@tomService`). |
| `tomConsumesForm` | `bool tomConsumesForm(TomMimeType consumes)` | Whether `consumes` declares an HTML form body (multipart **or** url-encoded), comparing type and subtype only. |
| `tomEndpointAccessDeniedErrorKey` | `const String tomEndpointAccessDeniedErrorKey` | The error key a pre-invocation access denial is raised under, `endpoint_handler.handle_method_call.access_denied`. Named here because the audit trail records it, the suites assert it, and a deployment writing its own refusal policy needs to name the one the pipeline raises — it was hand-copied into two sample servers before it had a name. It does not reach the caller: a denied request answers a bare 404. |
| `tomConsumesMultipartForm` | `bool tomConsumesMultipartForm(TomMimeType consumes)` | Whether `consumes` declares specifically `multipart/form-data` — which reader the pipeline calls. |
