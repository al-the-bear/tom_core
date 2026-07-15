# Tom Core Kernel API Reference: HTTP Connection Module

The transport-agnostic HTTP layer shared by client and server: declarative API /
endpoint definitions (`TomApi`, `TomApiEndpoint`, `TomRemoteApis`), the value
types HTTP endpoints are described with (`TomHttpMethod`, `TomMimeType`,
`TomHeader`, `TomContentDisposition`), the client-side request/response
machinery (`TomServerCall`, `TomServerChannel`, `TomServerEndpoint`, the HTTP
client factories), client remote-server configuration
(`TomClientRemoteContext`), and a pluggable expired-token refresh-and-retry
policy (`TomAuthRefresher`, `TomAuthRetryPolicy`, `tomRunWithAuthRetry`).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [Auth Refresh & Retry](#auth-refresh--retry)
    - [TomAuthRefresher](#tomauthrefresher)
    - [TomAuthRetryPolicy](#tomauthretrypolicy)
    - [TomAuthExpiredException](#tomauthexpiredexception)
  - [API & Endpoint Definitions](#api--endpoint-definitions)
    - [TomRemoteApis](#tomremoteapis)
    - [TomApi](#tomapi)
    - [TomApiEndpoint&lt;ReturnType, RequestType&gt;](#tomapiendpointreturntype-requesttype)
    - [TomContentDisposition](#tomcontentdisposition)
    - [TomEndpointException](#tomendpointexception)
  - [HTTP Methods](#http-methods)
    - [TomHttpMethod](#tomhttpmethod)
  - [MIME Types](#mime-types)
    - [TomMimeType](#tommimetype)
    - [StaticFileMimetypeMapping](#staticfilemimetypemapping)
    - [TomMimeTypeException](#tommimetypeexception)
  - [HTTP Headers](#http-headers)
    - [TomHeader](#tomheader)
  - [Remote Context](#remote-context)
    - [TomClientRemoteContext](#tomclientremotecontext)
    - [TomClientRemoteContextException](#tomclientremotecontextexception)
  - [Server Connection](#server-connection)
    - [TomServerCallSpecs](#tomservercallspecs)
    - [TomServerCallLoad](#tomservercallload)
    - [TomServerCallError](#tomservercallerror)
    - [TomServerCall](#tomservercall)
    - [TomServerChannel](#tomserverchannel)
    - [TomHttpClientFactory](#tomhttpclientfactory)
    - [TomHttpClientAbstractFactory](#tomhttpclientabstractfactory)
    - [TomDefaultHttpClientFactory](#tomdefaulthttpclientfactory)
    - [TomServerEndpoint&lt;T, R&gt;](#tomserverendpointt-r)
    - [TomServerConnectionException](#tomserverconnectionexception)
    - [TomRequestAbortedException](#tomrequestabortedexception)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/http_connection/auth_retry.dart`,
`lib/src/tombase/http_connection/endpoints_apis.dart`,
`lib/src/tombase/http_connection/headers.dart`,
`lib/src/tombase/http_connection/httpmethods.dart`,
`lib/src/tombase/http_connection/mimetypes.dart`,
`lib/src/tombase/http_connection/remote_context.dart`,
`lib/src/tombase/http_connection/server_connection.dart`.

An API is described declaratively: a `TomApi` groups typed `TomApiEndpoint`s
under a base URI, and `TomRemoteApis` is the process-wide registry of those
APIs. Endpoints are configured with the module's HTTP value types —
`TomHttpMethod` (the verb plus whether it accepts a body), `TomMimeType` (media
type with charset/codecs, plus `StaticFileMimetypeMapping` for static-file
serving), `TomHeader` and `TomContentDisposition` (header-name / value
constants). The client side runs requests through `TomServerCall` (one
send/read cycle with abort support) obtained from a `TomServerChannel` (client
pooling per host), while `TomServerEndpoint` layers type-safe JSON
serialization on top and maps status codes to typed error responses. HTTP
clients are created through the pluggable `TomHttpClientFactory` chain, the
client's target servers come from `TomClientRemoteContext`, and
`tomRunWithAuthRetry` wraps any transport in the transport-agnostic
expired-token refresh-and-retry policy (`TomAuthRefresher` /
`TomAuthRetryPolicy`).

## Class Hierarchy

```
Object
    ├── TomAuthRefresher  (abstract)
    ├── TomAuthRetryPolicy
    ├── TomRemoteApis
    ├── TomApi
    ├── TomApiEndpoint<ReturnType, RequestType>
    ├── TomContentDisposition
    ├── TomHttpMethod
    ├── TomMimeType
    ├── StaticFileMimetypeMapping
    ├── TomHeader
    ├── TomClientRemoteContext
    ├── TomServerCallSpecs
    ├── TomServerCallLoad
    ├── TomServerCallError
    ├── TomServerCall
    ├── TomServerChannel
    ├── TomHttpClientAbstractFactory
    ├── TomHttpClientFactory  (implements TomHttpClientAbstractFactory)
    │       └── TomDefaultHttpClientFactory
    └── TomServerEndpoint<T, R>

TomException  (kernel)
    ├── TomAuthExpiredException
    ├── TomEndpointException
    ├── TomMimeTypeException
    ├── TomClientRemoteContextException
    ├── TomServerConnectionException
    └── TomRequestAbortedException
```

## Classes

### Auth Refresh & Retry

#### TomAuthRefresher

How to re-mint the authentication token pair when the current one expired. A
client implements this over whatever auth mechanism it uses (typically a call to
its auth server's `/refresh` endpoint that stores a fresh token pair);
`tomRunWithAuthRetry` invokes it at most once per request.

- **Extends:** none (abstract base)

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `refresh` | `Future<bool> refresh()` | Attempts to obtain a fresh token; returns `true` when a new token was stored and the request is worth retrying, `false` when no refresh was possible. May throw its own typed error, which propagates unchanged. |

#### TomAuthRetryPolicy

The decision knobs for `tomRunWithAuthRetry`: which HTTP statuses mean "token
expired" and how many refresh-and-retry attempts to make. Register a different
instance as a `TomAuthRetryPolicy` bean to tune it per environment.

##### Constructors

```dart
const TomAuthRetryPolicy({
  Set<int> expiryStatusCodes = const {401},
  int maxRefreshRetries = 1,
})
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `active` | `TomAuthRetryPolicy` | The policy in force: a registered `TomAuthRetryPolicy` bean if present, else `tomDefaultAuthRetryPolicy`. Resolved fresh on each access. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `expiryStatusCodes` | `Set<int>` | The HTTP status codes that mean "the bearer token has expired" and should trigger a refresh (defaults to `{401}`). |
| `maxRefreshRetries` | `int` | How many times to refresh-and-retry before surfacing the failure (defaults to `1`). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isAuthExpiry` | `bool isAuthExpiry(int statusCode)` | Whether `statusCode` should trigger a token refresh under this policy. |

#### TomAuthExpiredException

Raised when an authenticated request cannot be recovered: the server still
answered an expiry status *after* a successful refresh and retry, so the session
is genuinely dead and the user must re-authenticate.

- **Extends:** `TomException`

##### Constructors

```dart
TomAuthExpiredException(
  String key,
  String defaultUserMessage, {
  required int statusCode,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status that persisted after the refresh+retry (an expiry status). |

### API & Endpoint Definitions

#### TomRemoteApis

A singleton registry for managing remote API definitions, providing centralized
storage and retrieval of `TomApi` instances throughout the application.

##### Constructors

```dart
TomRemoteApis()
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomRemoteApis` | The singleton instance of the API registry. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerApi` | `static void registerApi(TomApi api)` | Registers `api` with the global registry, keyed by its `TomApi.id`. |
| `getApiById` | `static TomApi getApiById(String id)` | Retrieves an API by its unique identifier; throws if not found. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `apis` | `Map<String, TomApi>` | Map of registered APIs, keyed by their unique ID. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomApi api)` | Registers `api` with this registry (keyed by `api.id`). |

##### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator []` | `TomApi operator [](String apiId)` | Gets an API by ID; throws `TomEndpointException` if not found. |
| `operator []=` | `void operator []=(String apiId, TomApi api)` | Registers an API under `apiId` using bracket notation. |

#### TomApi

Represents a remote API with a collection of endpoints, grouping related
endpoints under a common base URI and shared settings like encoding and status
code response types.

##### Constructors

```dart
TomApi({
  required String id,
  String? name,
  String? description,
  String? uri,
  required List<TomApiEndpoint> endpoints,
  Encoding? requestEncoding,
  Encoding? responseEncoding,
  Map<int, Type>? statusCodeResponseTypes,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Unique identifier for this API. |
| `name` | `String?` | Human-readable name for this API. |
| `description` | `String?` | Description of what this API does. |
| `uri` | `String?` | Base URI path for all endpoints in this API. |
| `requestEncoding` | `Encoding?` | Default encoding for request bodies. |
| `responseEncoding` | `Encoding?` | Default encoding for response bodies. |
| `statusCodeResponseTypes` | `Map<int, Type>?` | Maps HTTP status codes to response types for error handling. |
| `endpoints` | `Map<String, TomApiEndpoint>` | Map of endpoints, keyed by their unique ID. |

##### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator []` | `TomApiEndpoint operator [](String endpointId)` | Gets an endpoint by ID; throws `TomEndpointException` if not found. |
| `operator []=` | `void operator []=(String endpointId, TomApiEndpoint endpoint)` | Registers an endpoint under `endpointId`, linking it to this API. |

#### TomApiEndpoint&lt;ReturnType, RequestType&gt;

Represents a single API endpoint with type-safe request/response handling. The
type parameters describe the expected server response and the request body type.

- **Type Parameters:** `ReturnType` — the expected response type; `RequestType` — the request body type.

##### Constructors

```dart
TomApiEndpoint({
  required String id,
  String? uri,
  String? description,
  List<TomHttpMethod>? methods,
  required TomHttpMethod method,
  TomMimeType consumes = TomMimeType.json,
  TomMimeType produces = TomMimeType.json,
  String? contentDisposition,
  List<String> formFields = const [],
  Map<String, String> responseHeaders = const {},
  Map<String, String> requestHeaders = const {},
  List<Type>? requestTypes,
  bool followRedirects = false,
  bool? persistentConnection,
  bool includeBearerAuthentication = true,
  int? maxRedirects,
  Encoding? requestEncoding,
  Encoding? responseEncoding,
  Map<int, Type>? statusCodeResponseTypes,
  Map<String, String> urlParameterMapping = const {},
  TomAccessControl? access,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Unique identifier for this endpoint within its parent API. |
| `uri` | `String?` | Relative URI path for this endpoint (appended to the API's base URI). |
| `description` | `String?` | Human-readable description of what this endpoint does. |
| `methods` | `List<TomHttpMethod>?` | List of allowed HTTP methods (for multi-method endpoints). |
| `method` | `TomHttpMethod` | Primary HTTP method for this endpoint. |
| `consumes` | `TomMimeType` | MIME type this endpoint accepts for request bodies (defaults to JSON). |
| `produces` | `TomMimeType` | MIME type this endpoint produces in responses (defaults to JSON). |
| `contentDisposition` | `String?` | `Content-Disposition` header value (e.g. for file downloads). |
| `requestTypes` | `List<Type>` | Types that can be used as request bodies. |
| `responseType` | `Type` | The response type for successful requests (defaults to `ReturnType`). |
| `formFields` | `List<String>` | Field names for form-encoded requests. |
| `responseHeaders` | `Map<String, String>` | Headers to include in responses (server-side). |
| `requestHeaders` | `Map<String, String>` | Headers to include in requests (client-side). |
| `followRedirects` | `bool` | Whether to automatically follow HTTP redirects. |
| `maxRedirects` | `int?` | Maximum number of redirects to follow. |
| `persistentConnection` | `bool?` | Whether to use persistent HTTP connections. |
| `includeBearerAuthentication` | `bool` | Whether to include a Bearer token in the `Authorization` header. |
| `requestEncoding` | `Encoding?` | Encoding for request bodies (overrides the API-level setting). |
| `responseEncoding` | `Encoding?` | Encoding for response bodies (overrides the API-level setting). |
| `statusCodeResponseTypes` | `Map<int, Type>?` | Maps HTTP status codes to response types for error handling. |
| `urlParameterMapping` | `Map<String, String>` | Binds URL path parameters to typed request-DTO field names. |
| `access` | `TomAccessControl?` | The contract-side access policy the endpoint is served under (`null` = fall back to the server default or a handler annotation). |
| `api` | `TomApi` | The parent API; throws `TomEndpointException` if the endpoint has not been added to an API. |

#### TomContentDisposition

Constants for HTTP `Content-Disposition` header values, used to specify how
content should be handled by the client (particularly for file downloads).

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `attachment` | `String` | Indicates the content should be downloaded as an attachment (`"attachment"`). |

#### TomEndpointException

Exception thrown when an endpoint-related error occurs (API not found, endpoint
not found within an API, or API not set for an endpoint).

- **Extends:** `TomException`

##### Constructors

```dart
TomEndpointException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? uuid,
  bool? serverCallError,
})
```

### HTTP Methods

#### TomHttpMethod

Represents an HTTP method with its characteristics: a name and whether it
typically accepts a request body. Provides predefined constants for every
standard method plus a wildcard.

##### Constructors

```dart
const TomHttpMethod(String name, [bool acceptsBody = true])
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `methods` | `Map<String, TomHttpMethod>` | Map of all HTTP methods keyed by their uppercase name. |
| `head` | `TomHttpMethod` | HTTP `HEAD` method — retrieves headers only. |
| `get` | `TomHttpMethod` | HTTP `GET` method — retrieves a resource. |
| `post` | `TomHttpMethod` | HTTP `POST` method — creates a new resource. |
| `put` | `TomHttpMethod` | HTTP `PUT` method — replaces a resource entirely. |
| `patch` | `TomHttpMethod` | HTTP `PATCH` method — partially updates a resource. |
| `delete` | `TomHttpMethod` | HTTP `DELETE` method — removes a resource. |
| `connect` | `TomHttpMethod` | HTTP `CONNECT` method — establishes a tunnel. |
| `trace` | `TomHttpMethod` | HTTP `TRACE` method — echoes the request for debugging (does not accept a body). |
| `options` | `TomHttpMethod` | HTTP `OPTIONS` method — describes communication options. |
| `all` | `TomHttpMethod` | Wildcard method matching all HTTP methods. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The uppercase name of the HTTP method (e.g. `"GET"`, `"POST"`). |
| `acceptsBody` | `bool` | Whether this HTTP method typically accepts a request body. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `"<name>/<acceptsBody>"`. |

### MIME Types

#### TomMimeType

Represents a MIME type (media type) with primary type, subtype, and optional
charset and codecs. Provides predefined constants for common media types plus
parsing and header-value generation.

##### Constructors

```dart
const TomMimeType(
  String primaryType,
  String subType, {
  String? charset = "UTF-8",
  List<String> codecs = const [],
})
```

##### Factory Constructors

```dart
factory TomMimeType.parse(String type)
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `none` | `TomMimeType` | Placeholder for endpoints that don't consume a request body (`none/none`). |
| `plainText` | `TomMimeType` | Plain text (`text/plain`). |
| `ics` | `TomMimeType` | iCalendar (`text/calendar`). |
| `html` | `TomMimeType` | HTML (`text/html`). |
| `css` | `TomMimeType` | CSS (`text/css`). |
| `csv` | `TomMimeType` | CSV (`text/csv`). |
| `javascript` | `TomMimeType` | JavaScript (`text/javascript`). |
| `json` | `TomMimeType` | JSON (`application/json`). |
| `xml` | `TomMimeType` | XML (`application/xml`). |
| `octetStream` | `TomMimeType` | Binary / octet-stream (`application/octet-stream`). |
| `pdf` | `TomMimeType` | PDF (`application/pdf`). |
| `rtf` | `TomMimeType` | RTF (`application/rtf`). |
| `pkcs8` | `TomMimeType` | PKCS8 (`application/pkcs8`). |
| `zip` | `TomMimeType` | ZIP archive (`application/zip`). |
| `multipartFormData` | `TomMimeType` | Multipart form data (`multipart/form-data`). |
| `multipartByteranges` | `TomMimeType` | Multipart byteranges (`multipart/byteranges`). |
| `urlEncoded` | `TomMimeType` | URL-encoded form (`application/x-www-form-urlencoded`). |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `primaryType` | `String` | The primary type (e.g. `"application"`, `"text"`, `"image"`). |
| `subType` | `String` | The subtype (e.g. `"json"`, `"html"`, `"png"`). |
| `charset` | `String?` | Optional charset for text-based types (e.g. `"UTF-8"`). |
| `codecs` | `List<String>` | Optional codecs for media types (e.g. for video). |
| `isText` | `bool` | Whether this MIME type represents text-based content (all `text/*`, `application/json` / `xml` / `javascript`, and `+json` / `+xml` suffixes). |
| `hashCode` | `int` | *(override)* Hash over primary type, subtype, charset, and codecs. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toHeaderValue` | `String toHeaderValue()` | The value to use for the `Content-Type` header (including charset and codecs when set). |
| `isEqualType` | `bool isEqualType(TomMimeType other)` | Whether this MIME type has the same primary and sub type as `other` (ignores charset/codecs). |
| `toString` | `String toString()` | *(override)* Human-readable rendering including charset and codecs. |

##### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Equal when primary/sub type and all codecs match. |

#### StaticFileMimetypeMapping

Maps file extensions to their corresponding MIME types, for serving static files
with correct `Content-Type` headers.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getMimeType` | `static TomMimeType? getMimeType(String extension)` | Gets the MIME type for a file `extension` (including the dot), or `null` if unrecognized. |

#### TomMimeTypeException

Exception thrown when MIME type parsing or validation fails.

- **Extends:** `TomException`

##### Constructors

```dart
TomMimeTypeException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
})
```

### HTTP Headers

#### TomHeader

Constants for commonly used HTTP header names, providing standardized access to
header field names to avoid typos and ensure consistency.

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `contentType` | `String` | The `Content-Type` header field name. |
| `contentDisposition` | `String` | The `Content-Disposition` header field name. |

### Remote Context

#### TomClientRemoteContext

Configures the remote server connection for client applications: the base URI
for the primary API server and optionally a separate authentication server. Only
one context can be active at a time.

##### Constructors

```dart
TomClientRemoteContext(Uri baseUri, [Uri? authenticationUri])
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomClientRemoteContext?` | The currently active remote context (`null` if none has been set). |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setCurrent` | `static void setCurrent(TomClientRemoteContext context)` | Sets the current remote context; may be called only once — a second call throws `TomClientRemoteContextException`. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `baseUri` | `Uri` | The base URI for all API requests. |
| `authenticationUri` | `Uri` | The URI for authentication requests (defaults to `baseUri`). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `"TomClientRemoteContext <baseUri>"`. |

#### TomClientRemoteContextException

Exception thrown when remote context initialization fails (typically when
attempting to initialize the context twice).

- **Extends:** `TomException`

##### Constructors

```dart
TomClientRemoteContextException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? uuid,
  bool? serverCallError,
})
```

### Server Connection

#### TomServerCallSpecs

Specification for an HTTP server call: the method, URL, headers, and connection
settings needed to make a request.

##### Constructors

```dart
TomServerCallSpecs(
  String method,
  Uri url, {
  int? contentLength,
  bool? followRedirects,
  Map<String, String>? headers = const {},
  int? maxRedirects,
  bool? persistentConnection,
  bool includeBearerAuthentication = true,
  Encoding? requestEncoding,
  Encoding? fallbackResponseEncoding,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `method` | `String` | The HTTP method (`GET`, `POST`, `PUT`, `DELETE`, etc.). |
| `url` | `Uri` | The full URL for the request. |
| `followRedirects` | `bool?` | Whether to automatically follow HTTP redirects. |
| `headers` | `Map<String, String>?` | HTTP headers to include in the request. |
| `maxRedirects` | `int?` | Maximum number of redirects to follow. |
| `persistentConnection` | `bool?` | Whether to keep the connection alive for reuse. |
| `includeBearerAuthentication` | `bool` | Whether to include a Bearer authentication token. |
| `requestEncoding` | `Encoding?` | Encoding for the request body. |
| `fallbackResponseEncoding` | `Encoding?` | Fallback encoding for parsing the response body. |

#### TomServerCallLoad

Payload data for an HTTP request. Supports three mutually exclusive body kinds:
`stringBody` (text), `byteBody` (binary), or `bodyFields` (URL-encoded form).

##### Constructors

```dart
TomServerCallLoad({
  String? stringBody,
  Uint8List? byteBody,
  Map<String, String>? bodyFields,
  String? contentType,
  Encoding? encoding,
  int? contentLength,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `contentType` | `String?` | The `Content-Type` header value. |
| `encoding` | `Encoding?` | Character encoding for the body. |
| `contentLength` | `int?` | `Content-Length` header value. |
| `stringBody` | `String?` | String body content (mutually exclusive with `byteBody` / `bodyFields`). |
| `byteBody` | `Uint8List?` | Binary body content (mutually exclusive with `stringBody` / `bodyFields`). |
| `bodyFields` | `Map<String, String>?` | Form-field body (mutually exclusive with `stringBody` / `byteBody`). |

#### TomServerCallError

Represents an error or response status from a server call: the HTTP status code,
response body, headers, and error details extracted from Tom server errors.

##### Constructors

```dart
TomServerCallError({
  int statusCode = 200,
  String? response,
  int internalError = 0,
  Map<String, Object> headers = const {},
  bool isRedirect = false,
  String? reasonPhrase,
  Object? exception,
  StackTrace? stackTrace,
  Object? statusCodeResponse,
})
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `jsonDecodingError` | `int` | Internal error code for JSON decoding failures (`1`). |
| `noResponseError` | `int` | Internal error code when no response was received (`2`). |
| `serverError` | `int` | Internal error code for general server errors (`2`). |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status code from the server. |
| `response` | `String?` | The raw response body as a string. |
| `statusCodeResponse` | `Object?` | Deserialized response object for non-200 status codes. |
| `internalError` | `int` | Internal error code (`0` = no internal error). |
| `headers` | `Map<String, Object>` | Response headers from the server. |
| `isRedirect` | `bool` | Whether the response was a redirect. |
| `reasonPhrase` | `String?` | The reason phrase from the HTTP response (e.g. `"OK"`, `"Not Found"`). |
| `autoLog` | `bool?` | Whether to automatically log this error. |
| `clientRethrow` | `bool?` | Whether the client should rethrow this as an exception. |
| `errorKey` | `String?` | Error key from a Tom server error response. |
| `uuid` | `String?` | Unique identifier for this error. |
| `exception` | `Object?` | The exception that caused this error (if any). |
| `requestUuid` | `String?` | Request UUID for tracing. |
| `stackTrace` | `StackTrace?` | Stack trace from the error. |
| `hasError` | `bool` | Whether this represents an error condition (status outside 2xx, or a non-zero internal error). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Debug description of the error/response. |

#### TomServerCall

Handles a single HTTP request/response cycle with send, read, and abort support.
Each instance can be used once; call `reset` to reuse.

##### Constructors

```dart
TomServerCall(Client client, TomServerCallSpecs specs)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `client` | `Client` | The HTTP client used for the request. |
| `specs` | `TomServerCallSpecs` | The specification for this call. |
| `abortTrigger` | `Completer<void>` | Completer used to trigger request abort. |
| `abortableRequest` | `AbortableRequest` | The underlying abortable HTTP request. |
| `response` | `Future<StreamedResponse>?` | The pending response future. |
| `serverResponse` | `StreamedResponse?` | The received server response. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `applySpecValues` | `void applySpecValues()` | Applies the specification values to the request. |
| `applyLoadValues` | `void applyLoadValues(TomServerCallLoad load)` | Applies the payload values to the request. |
| `reset` | `void reset({String? stringBody, Uint8List? byteBody, Map<String, String>? bodyFields})` | Resets the call for reuse, optionally with new body content. |
| `send` | `TomServerCall send(TomServerCallLoad load)` | Sends the request with `load`; may be called once. Throws `TomServerConnectionException` if called more than once. |
| `read` | `Future<Uint8List> read()` | Reads the response body as bytes (once, after `send`). Throws `TomRequestAbortedException` if aborted. |
| `readAsString` | `Future<String> readAsString(Encoding ec)` | Reads the response body as a string with encoding `ec`. |
| `getResponseHeaders` | `Future<Map<String, String>> getResponseHeaders()` | Gets the response headers after sending. |
| `getResponseStatusCode` | `Future<int> getResponseStatusCode()` | Gets the HTTP status code after sending. |
| `getResponseContentLength` | `Future<int?> getResponseContentLength()` | Gets the response content length after sending. |
| `getResponseIsRedirect` | `Future<bool> getResponseIsRedirect()` | Checks whether the response is a redirect after sending. |
| `getResponseReasonPhrase` | `Future<String?> getResponseReasonPhrase()` | Gets the reason phrase after sending. |
| `getResponseRequest` | `Future<BaseRequest?> getResponseRequest()` | Gets the original request from the response after sending. |
| `abort` | `void abort()` | Aborts the pending request, causing `read` to throw `TomRequestAbortedException`. |

#### TomServerChannel

Manages HTTP client connections to a server, providing client pooling and call
preparation for a specific host.

##### Constructors

```dart
TomServerChannel(
  String host,
  int port, {
  TomHttpClientFactory? clientFactory,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `client` | `Client?` | The cached HTTP client. |
| `host` | `String` | The server hostname. |
| `port` | `int` | The server port. |
| `clientFactory` | `TomHttpClientFactory` | Factory for creating HTTP clients. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepareCall` | `TomServerCall prepareCall(TomServerCallSpecs spec)` | Prepares a new server call with the given specification. |
| `getClient` | `Client getClient()` | Gets or creates the HTTP client. |
| `close` | `void close()` | Closes the HTTP client connection. |

#### TomHttpClientFactory

Factory for creating HTTP clients, supporting a global configuration and
per-instance overrides. Falls back to `TomDefaultHttpClientFactory` when no
custom factory is set.

- **Implements:** `TomHttpClientAbstractFactory`

##### Constructors

```dart
TomHttpClientFactory()
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setGlobalHttpClientFactory` | `static void setGlobalHttpClientFactory(TomHttpClientFactory factory)` | Sets the global HTTP client factory used by instances without their own factory. |
| `initialize` | `static void initialize([TomHttpClientFactory? defaultFactory])` | Initializes the factory system, setting the global factory to `defaultFactory` or the default. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `instanceClientFactory` | `TomHttpClientFactory?` | Instance-specific client factory override. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getClient` | `Client getClient()` | *(override)* Creates and returns an HTTP client, resolving the instance/global factory. |

#### TomHttpClientAbstractFactory

Abstract base class for HTTP client factories.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getClient` | `Client getClient()` | Creates and returns an HTTP client (throws `UnimplementedError` in the base). |

#### TomDefaultHttpClientFactory

Default HTTP client factory using platform-specific clients.

- **Extends:** `TomHttpClientFactory`

##### Constructors

```dart
TomDefaultHttpClientFactory()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getClient` | `Client getClient()` | *(override)* Returns a platform-specific HTTP client from `TomPlatformUtils`. |

#### TomServerEndpoint&lt;T, R&gt;

Type-safe API endpoint executor with automatic serialization: serializes request
objects to JSON, sends the HTTP request, deserializes response objects, and
handles error responses.

- **Type Parameters:** `T extends Object` — the request object type; `R extends Object` — the response object type.

##### Constructors

```dart
TomServerEndpoint(
  TomServerChannel channel,
  TomServerCallSpecs specs, {
  Map<int, Type>? statusCodeResponseTypes,
})
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `createApiServerEndpoint` | `static TomServerEndpoint<requestType, responseType> createApiServerEndpoint<requestType extends Object, responseType extends Object>(TomApiEndpoint apiEndpoint, {TomServerCallSpecs? specs, TomServerChannel? channel, Uri? baseUri})` | Creates a server endpoint from a `TomApiEndpoint` definition, configuring channel, specs, and error handling; throws `TomEndpointException` on a type-parameter mismatch. |
| `removeLeadingSlash` | `static String removeLeadingSlash(String s)` | Removes a leading slash from `s` if present. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channel` | `TomServerChannel` | The server channel for HTTP communication. |
| `specs` | `TomServerCallSpecs` | The call specification. |
| `statusCodeResponseTypes` | `Map<int, Type>?` | Maps status codes to response types for error handling. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<(R result, TomServerCallError? ts)> send(T load, [R? responseObject])` | Sends `load` and returns a `(response, error)` tuple; check `TomServerCallError.hasError` to determine success. May throw `TomServerConnectionException` when the server requests a client rethrow. |

#### TomServerConnectionException

Exception thrown when a server connection error occurs (invalid request state,
reading before sending, network errors).

- **Extends:** `TomException`

##### Constructors

```dart
TomServerConnectionException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? requestUuid,
  String? uuid,
  bool? serverCallError,
})
```

#### TomRequestAbortedException

Exception thrown when a request is aborted, e.g. when `TomServerCall.abort` is
called during a pending request.

- **Extends:** `TomException`

##### Constructors

```dart
TomRequestAbortedException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? requestUuid,
})
```

## Enums

None — this module exposes no public enums.

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomDefaultAuthRetryPolicy` | `TomAuthRetryPolicy` | The zero-config default policy: a single `401` refreshes once and retries once. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `tomRemoteApis` | `TomRemoteApis get tomRemoteApis` | Global accessor (getter) for the `TomRemoteApis` singleton. |
| `tomRunWithAuthRetry` | `Future<R> tomRunWithAuthRetry<R>({required Future<R> Function() send, required int Function(R response) statusOf, required TomAuthRefresher refresher, TomAuthRetryPolicy? policy, String? Function(R response)? errorKeyOf})` | Runs `send` under the active refresh/retry policy: replays the request after refreshing the token on an expiry status, and throws `TomAuthExpiredException` when the status persists after the retries. |
