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
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/endpoints/endpoint_annotation.dart`,
`lib/src/tomserver/endpoints/endpoint_pipeline.dart`,
`lib/src/tomserver/endpoints/form_binding.dart`,
`lib/src/tomserver/endpoints/endpoint_results.dart`,
`lib/src/tomserver/endpoints/web_socket_endpoint.dart`.

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

## Class Hierarchy

```
TomErrorHandler  (abstract)
    └── TomDefaultErrorHandler

TomService
    └── TomApiImplementation

TomEndpointBase<requestType, resultType>  (abstract)
    ├── TomApiEndpointImplementation<requestType, resultType>  (implements)
    ├── TomEndpoint<requestType, resultType>                   (implements)
    └── TomWebSocketEndpoint<requestType, resultType>          (implements)

TomComponentReference
TomTransactional

TomServerException  (server module)
    ├── TomEndpointHandlerException
    ├── TomEndpointPipelineException
    ├── TomFormBindingException
    └── TomWebSocketException

TomEndpointHandler
TomEndpointRoutingInfo
TomEndpointRouting
TomMethodMetadata
TomClassScanResult
TomFormFile
TomMultipartForm
TomRedirect
TomWebSocketConnection
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
| `handleInvocationError` | `Response handleInvocationError(Object error, Object stacktrace, Request r)` | Builds the response for an error thrown by the service method (delegates to `handleErrorDefault`). |
| `handleConversionError` | `Response handleConversionError(Object error, Object stacktrace, Request r, Object? result)` | Builds the response for an error thrown while converting `result` into the body (delegates to `handleErrorDefault`). |
| `handleUnknowResultTypeError` | `Response handleUnknowResultTypeError(Object error, Object stacktrace, Request r, Object? result)` | Builds the response for a `result` whose type cannot be mapped to a body (delegates to `handleErrorDefault`). |
| `handleErrorDefault` | `Response handleErrorDefault(Object error, Object stacktrace, Request r, Object? result)` | The fallback every hook delegates to; the one method a concrete handler must implement. |

### TomDefaultErrorHandler

The default `TomErrorHandler`: hides the error and returns a plain-text
`500 Internal Server Error`, so error details never leak to the client.

- **Extends:** `TomErrorHandler`

#### Constructors

```dart
const TomDefaultErrorHandler()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `handleErrorDefault` | `Response handleErrorDefault(Object error, Object stacktrace, Request r, Object? result)` | *(override)* Returns a plain-text `500 Internal Server Error` with no leaked detail. |

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
| `convertToTomEndpoint` | `TomEndpoint<requestType, resultType> convertToTomEndpoint([TomApiImplementation? apiImplementation])` | *(override)* Reads the registry entry and merges it with this annotation's overrides and the API-wide defaults into a `TomEndpoint`. |

### TomEndpoint&lt;requestType, resultType&gt;

Method-level annotation that declares an HTTP endpoint inline (without a
registry entry). It fully describes the route: HTTP `methods` and `uri`, what
the body `consumes` / `produces`, fixed `headers` / `contentDisposition`, the
per-endpoint `errorHandler` and `logRequests`, and CORS overrides.

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
| `consumes` | `TomMimeType` | The request body media type the endpoint accepts (defaults to JSON). |
| `produces` | `TomMimeType` | The response body media type the endpoint produces (defaults to JSON). |
| `contentDisposition` | `String?` | Optional `Content-Disposition` header for the response. |
| `errorHandler` | `TomErrorHandler?` | Per-endpoint error handler (defaults to `TomDefaultErrorHandler`). |
| `logRequests` | `bool?` | Whether to log requests (`null` = use the global default). |
| `headers` | `Map<String, String>` | Fixed headers added to every response from this endpoint. |
| `corsAllowedOrigins` | `String?` | `Access-Control-Allow-Origin` override for this endpoint. |
| `corsAllowedMethods` | `String?` | `Access-Control-Allow-Methods` override for this endpoint. |
| `corsAllowedHeaders` | `String?` | `Access-Control-Allow-Headers` override for this endpoint. |
| `urlParameterMapping` | `Map<String, String>` | Binds URL path parameters to typed request-DTO field names. |

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
  Object? stack,
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
  Object? stack,
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
| `coercePrimitiveParameter` | `static Object? coercePrimitiveParameter(Type type, String raw)` | Coerces a raw URL string into the parameter's primitive `type`, or `null` when `type` is not a bindable primitive. |
| `injectPathParameters` | `static void injectPathParameters(Map<String, dynamic> jsonBodyData, Request req, TomEndpoint endpoint)` | Folds the request's URL path parameters into `jsonBodyData` under the DTO field names declared by `endpoint.urlParameterMapping`. |
| `injectQueryParameters` | `static void injectQueryParameters(Map<String, dynamic> jsonBodyData, Request req, TomEndpoint endpoint)` | Folds query-string values into `jsonBodyData`, but only those the endpoint explicitly maps. |
| `injectFormFields` | `static void injectFormFields(Map<String, dynamic> jsonBodyData, TomMultipartForm form, TomEndpoint endpoint)` | Folds a form body's text fields into `jsonBodyData`, narrowed by `endpoint.formFields` when it is non-empty. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | A human-readable identifier for the route (used in logs). |
| `instance` | `InstanceMirror` | The reflected service instance the method is invoked on. |
| `method` | `MethodMirror` | The reflected endpoint method. |
| `interface` | `ClassMirror?` | The service interface/annotation type, when routed via an interface. |
| `implementation` | `ClassMirror` | The concrete implementation class mirror. |
| `methodName` | `String` | The qualified name of the method to invoke. |
| `metadata` | `TomMethodMetadata` | The collected annotation metadata (endpoint, access, transaction, API). |
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
| `handleWebSocketCall` | `Future<Response> handleWebSocketCall(Request req)` | Serves a WebSocket handshake: enforces access, binds parameters *before* the upgrade, and runs the handler inside the captured request zone. |
| `enforceAccess` | `Future<void> enforceAccess()` | Runs the access check and its denial audit; shared by the HTTP and WebSocket paths. |
| `bindParameters` | `Future<List<Object>> bindParameters(Request req, {Map<Type, Object> extraByType = const {}})` | Builds the method's positional arguments from the request; `extraByType` supplies values only the endpoint kind knows (the socket connection). |
| `checkAccess` | `bool checkAccess(TomPrincipal? principal)` | Decides whether `principal` may call this endpoint from its resolved access control, falling back to the global protection default. |
| `checkAutomaticAccess` | `bool checkAutomaticAccess(bool accessCheck)` | Second-chance access check via resource-key protection; returns the possibly-upgraded decision. |

### TomEndpointRoutingInfo

Pairs a mounted route's handler with the endpoint it was built from.

#### Constructors

```dart
TomEndpointRoutingInfo(TomEndpointHandler handler, TomEndpoint endpoint)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `handler` | `TomEndpointHandler` | The handler invoked for the route. |
| `endpoint` | `TomEndpoint` | The endpoint definition the route was built from. |

### TomEndpointRouting

Builds the shelf `Router` for the application by reflecting over annotated
service/API classes and mounting one route per endpoint method. The mounted
handlers and a uri→`TomEndpointRoutingInfo` map are exposed statically for
diagnostics.

#### Constructors

```dart
TomEndpointRouting()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `shelfRoutePath` | `static String shelfRoutePath(String uri)` | Translates a Tom route template (`{name}`) into the `shelf_router` path syntax (`<name>`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `handlers` | `static List<TomEndpointHandler>` | Every endpoint handler mounted during the last `initializeRouter` run. |
| `routingInfo` | `static Map<String, TomEndpointRoutingInfo>` | Mounted routes keyed by URI, for diagnostics. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `scanClasses` | `TomClassScanResult scanClasses()` | Reflects over the annotated classes and partitions them into service interfaces, API implementations, and components. |
| `initializeRouter` | `Router initializeRouter()` | Scans the annotated classes and mounts every endpoint method onto a fresh `Router`, returning it. |
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
| `apiEndpointImplementation` | `TomApiEndpointImplementation?` | The `@TomApiEndpointImplementation` tag, for registry-based endpoints. |
| `apiImplementation` | `TomApiImplementation?` | The class's `@TomApiImplementation` tag, for registry-based endpoints. |
| `api` | `TomApi?` | The resolved remote API, for registry-based endpoints. |
| `apiEndpoint` | `TomApiEndpoint?` | The resolved remote-API endpoint, for registry-based endpoints. |
| `webSocket` | `TomWebSocketEndpoint?` | The socket declaration, when the method is a WebSocket endpoint (kept alongside the `endpoint` it converts to). |

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
  bool autoLog = true,
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

See also `TomFormFile.storeIn` in the
[File Storage](api_summary_file_storage.md) summary, which uploads the part
through the file-slot registry.

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
| `globalSettingMaxFilePartBytes` | `static int` | The largest a single file part may be before it is refused (default 8 MiB). |
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
  bool autoLog = true,
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
| `urlParameterMapping` | `Map<String, String>` | Binds URL parameters to typed request-DTO fields. |
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
| `messages` | `Stream<dynamic>` | Messages from the peer: `String` for a text frame, `List<int>` for a binary one. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `attachChannel` | `void attachChannel(WebSocketChannel channel, [String? subprotocol])` | Attaches the accepted channel; called by the pipeline, not by application code. |
| `sendText` | `void sendText(String message)` | Sends a text frame. |
| `sendBytes` | `void sendBytes(List<int> bytes)` | Sends a binary frame. |
| `close` | `Future<void> close([int? code, String? reason])` | Closes the socket; idempotent. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomService` | `const TomService tomService` | The annotation instance to mark a class with `TomService` (applied as `@tomService`). |
| `tomConsumesForm` | `bool tomConsumesForm(TomMimeType consumes)` | Whether `consumes` declares an HTML form body (multipart **or** url-encoded), comparing type and subtype only. |
| `tomConsumesMultipartForm` | `bool tomConsumesMultipartForm(TomMimeType consumes)` | Whether `consumes` declares specifically `multipart/form-data` — which reader the pipeline calls. |
