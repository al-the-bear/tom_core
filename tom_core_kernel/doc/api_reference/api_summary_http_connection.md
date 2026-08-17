# Tom Core Kernel API Reference: HTTP Connection Module

The transport-agnostic HTTP layer shared by client and server: declarative API /
endpoint definitions (`TomApi`, `TomApiEndpoint`, `TomRemoteApis`), the value
types HTTP endpoints are described with (`TomHttpMethod`, `TomMimeType`,
`TomHeader`, `TomContentDisposition`), the client-side request/response
machinery (`TomServerCall`, `TomServerChannel`, `TomServerEndpoint`, the HTTP
client factories), client remote-server configuration
(`TomClientRemoteContext`), a pluggable expired-token refresh-and-retry policy
(`TomAuthRefresher`, `TomAuthRetryPolicy`, `tomRunWithAuthRetry`), and the
streaming file-transfer client (`TomFileTransferClient`,
`TomHttpFileTransferClient`, `TomFileSource`, `TomFileMetadata`).

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
    - [TomRequestTimeoutException](#tomrequesttimeoutexception)
  - [File Transfer](#file-transfer)
    - [TomFileSource](#tomfilesource)
    - [TomFileMetadata](#tomfilemetadata)
    - [TomTransferProgress](#tomtransferprogress)
    - [TomTransferCancellation](#tomtransfercancellation)
    - [TomFileTransferClient](#tomfiletransferclient)
    - [TomHttpFileTransferClient](#tomhttpfiletransferclient)
    - [TomMemoryFileTransferClient](#tommemoryfiletransferclient)
    - [TomFileTransferException](#tomfiletransferexception)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/http_connection/auth_retry.dart`,
`lib/src/tombase/http_connection/endpoints_apis.dart`,
`lib/src/tombase/http_connection/file_transfer.dart`,
`lib/src/tombase/http_connection/headers.dart`,
`lib/src/tombase/http_connection/http_file_transfer.dart`,
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

Payloads too large to hold in memory take a second path: `TomFileTransferClient`
moves bytes to and from an application-owned *slot* without materializing the
file, reporting `TomTransferProgress` and honouring a `TomTransferCancellation`.
`TomHttpFileTransferClient` implements it over the module's own wire contract
(`POST`/`GET`/`HEAD`/`DELETE` against `<baseUri>/<slot>`, with a JSON descriptor
answering the first and the `x-tom-file` header answering the third), and
`TomMemoryFileTransferClient` implements the same contract over a map for tests
and offline modes.

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
    ├── TomServerEndpoint<T, R>
    ├── TomFileSource
    ├── TomFileMetadata
    ├── TomTransferProgress
    ├── TomTransferCancellation
    └── TomFileTransferClient  (abstract)
            ├── TomHttpFileTransferClient
            └── TomMemoryFileTransferClient

TomException  (kernel)
    ├── TomAuthExpiredException
    ├── TomEndpointException
    ├── TomMimeTypeException
    ├── TomClientRemoteContextException
    ├── TomServerConnectionException
    ├── TomRequestAbortedException
    ├── TomRequestTimeoutException
    └── TomFileTransferException
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
  Duration? timeout,
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
| `timeout` | `Duration?` | How long a client call to this endpoint may take before it gives up, or `null` to wait indefinitely. Declared per endpoint because the right deadline follows the work behind the URL, not the service as a whole. |
| `includeBearerAuthentication` | `bool` | Whether to include a Bearer token in the `Authorization` header. |
| `requestEncoding` | `Encoding?` | Encoding for request bodies (overrides the API-level setting). |
| `responseEncoding` | `Encoding?` | Encoding for response bodies (overrides the API-level setting). |
| `statusCodeResponseTypes` | `Map<int, Type>?` | Maps HTTP status codes to response types for error handling. |
| `urlParameterMapping` | `Map<String, String>` | Binds URL parameters — path captures *and* query-string parameters — to request-DTO field names. Keys are the name as it appears on the URL, values the field it is injected under. **The key decides which kind an entry is:** a key that appears as a `{capture}` in the endpoint's `uri` substitutes into the path; every other key is emitted as a query parameter, unless the path already carried its field — a path capture wins over a query parameter mapped to the same field, so two keys pointing at one field put the value in the path only. The two bind asymmetrically on purpose — a path capture that is *not* listed still binds under its own name, so an empty map suffices for an endpoint whose captures already match its field names, whereas a query parameter binds *only* when named here. There is no identity fallback for query parameters: a query string is whatever a caller chose to append, so an identity fallback would let any caller write any field of the request DTO. |
| `access` | `TomAccessControl?` | The contract-side access policy the endpoint is served under (`null` = fall back to the server default or a handler annotation). |
| `api` | `TomApi` | The parent API; throws `TomEndpointException` if the endpoint has not been added to an API. |

##### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolveUri(Uri baseUri, {Map<String, Object?> parameters = const {}})` | `Uri` | The address this endpoint is called at, built from its own declaration. |

`resolveUri` is the **client-side inverse** of the binding the server pipeline
performs: the same `uri` template and the same `urlParameterMapping` that tell
the server how to read a request tell a client how to write one. A framework
client therefore names no URI of its own, and the address called and the route
served cannot drift apart.

```dart
read.resolveUri(
  Uri.parse('https://api.example.com'),
  parameters: {'key': TomUserPreferenceKeys.theme},
); // https://api.example.com/preferences/tom.theme
```

The template is the API's `uri` followed by the endpoint's. `parameters` are
keyed by **request-DTO field name**, the right-hand side of
`urlParameterMapping` — so one map answers both halves of the address:

- a `{name}` path capture binds to `urlParameterMapping[name] ?? name`, and a
  capture with no answering parameter throws
  `apis.endpoint.missing_url_parameter` rather than producing a URL with a hole
  in it;
- every *other* `urlParameterMapping` entry becomes a query parameter, omitted
  when its value is `null` — and omitted too when the path already carried its
  field, since a capture wins over a query parameter for the same field.

Path segments already carried by `baseUri` are kept, so a base pointing at an
API-gateway prefix still resolves correctly.

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

Parses a `Content-Type` value: a media type optionally followed by parameters,
with optional whitespace after each `;`, quoted values allowed, and parameter
names matched case-insensitively. `charset` and `codecs` are read; **any other
parameter is ignored** rather than rejected, because a real request carries
parameters this class has no field for — a multipart boundary always does. A
charset the header does not state stays `null` rather than defaulting to
`UTF-8`, which makes the factory the exact inverse of `toHeaderValue`:
`TomMimeType.parse(x.toHeaderValue()) == x` for every value. Throws
`TomMimeTypeException` when the media type is not `primary/sub` with both parts
present.

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
| `hashCode` | `int` | *(override)* Hash over primary type, subtype, charset and codec *contents* — exactly the fields `operator ==` compares, so equal values share a hash bucket. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toHeaderValue` | `String toHeaderValue()` | The value to use for the `Content-Type` header (including charset and codecs when set). |
| `isEqualType` | `bool isEqualType(TomMimeType other)` | Whether this MIME type has the same primary and sub type as `other` (ignores charset/codecs). |
| `toString` | `String toString()` | *(override)* Human-readable rendering including charset and codecs. |

##### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Whole-value equality: equal when primary type, subtype, charset **and** codecs all match. Parameters are part of identity because they change how the bytes are read. Use `isEqualType` to match a declared constant against a real `content-type`, which carries parameters the declaration never named. |

#### StaticFileMimetypeMapping

Maps file extensions to their corresponding MIME types, for serving static files
with correct `Content-Type` headers.

Every entry is the media type the IANA registry assigns to that extension; `.avi`
is the sole exception, because IANA registers no type for AVI at all. The table
is deliberately short — it covers what a Tom application serves, and
`getMimeType` returns `null` for anything else so the caller decides. For a total
function, use `TomFileSource.guessMediaType`, which falls back to
`application/octet-stream`.

##### Recognized Extensions

| Extension | Media type | Extension | Media type |
| --------- | ---------- | --------- | ---------- |
| `.js` | `text/javascript` | `.avif` | `image/avif` |
| `.json` | `application/json` | `.avi` | `video/x-msvideo` (unregistered) |
| `.wasm` | `application/wasm` | `.gif` | `image/gif` |
| `.css` | `text/css` | `.webp` | `image/webp` |
| `.png` | `image/png` | `.rar` | `application/vnd.rar` |
| `.jpg`, `.jpeg` | `image/jpeg` | `.mp4` | `video/mp4` |
| `.svg` | `image/svg+xml` | `.mpeg` | `video/mpeg` |
| `.ttf` | `font/ttf` | `.ogg` | `audio/ogg` |
| `.woff` | `font/woff` | `.ogv` | `video/ogg` |
| `.mp3` | `audio/mpeg` | `.qt` | `video/quicktime` |
| `.pdf` | `application/pdf` | `.zip` | `application/zip` |
| `.apng` | `image/apng` | | |

`.ogg` is audio and `.ogv` is video per RFC 5334, which split the Ogg container
by content because implementations predating the split read a `.ogg` file as
Vorbis audio. The `font/*` types are RFC 8081; the older `application/x-font-*`
spellings were never registered.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getMimeType` | `static TomMimeType? getMimeType(String extension)` | Gets the MIME type for a file `extension` (including the dot), or `null` if unrecognized. Matching is case-insensitive. |

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
| `location` | `String` | The `Location` header field name — the target of a redirect (3xx) response. |

### Remote Context

#### TomClientRemoteContext

Configures the remote server connection for client applications: the base URI
for the primary API server and optionally a separate authentication server.
Exactly one context is current at any moment — a process-wide one installed
once by `setCurrent`, which `runWithContext` may shadow for the duration of a
body.

##### Constructors

```dart
TomClientRemoteContext(Uri baseUri, [Uri? authenticationUri])
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomClientRemoteContext?` | The context installed by the nearest enclosing `runWithContext`, falling back to the one set by `setCurrent`, or `null` if neither has run. Read-only — it decides which remote every subsequent call addresses, so it is written only through those two entry points. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setCurrent` | `static void setCurrent(TomClientRemoteContext context)` | Installs the process-wide context; may be called only once — a second call throws `TomClientRemoteContextException`. |
| `runWithContext` | `static T runWithContext<T>(TomClientRemoteContext context, T Function() body)` | Runs `body` with `context` as `current`, restoring the previous one afterwards. The context rides on the `Zone`, so it follows `body` across `await` boundaries and cannot leak past it. The supported way to address a second remote — a tool talking to two servers, or a test exercising one. |
| `resetCurrent` | `@visibleForTesting static void resetCurrent()` | Clears the context installed by `setCurrent`, so it may be called again. Test-only — tests need a clean process context per case; application code sets it once at startup and uses `runWithContext` for anything narrower. |

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
  Duration? timeout,
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
| `timeout` | `Duration?` | How long `read` may wait before throwing `TomRequestTimeoutException`, or `null` (the default) for no deadline. Covers the whole exchange — awaiting the response *and* draining its body — rather than restarting per stage. |

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
| `noResponseError` | `int` | Internal error code when no response was received (`2`). Raised by `TomServerEndpoint.send` when the request never produced a response — a refused connection, an expired deadline, an aborted request. Such an error carries `statusCode` `0` and no body; the underlying failure is in `exception`. |
| `serverError` | `int` | Internal error code for general server errors (`2`). |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isSuccessStatusCode` | `static bool isSuccessStatusCode(int statusCode)` | Whether the status is in the 2xx range. The module's single definition of "the server accepted this" — `hasError` and `TomServerEndpoint.send` both read it rather than spelling the range again. |
| `isNoContentStatusCode` | `static bool isNoContentStatusCode(int statusCode)` | Whether the status is defined to carry no body (`204`, `205`), so an empty response is the expected shape and there is nothing to deserialize. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status code from the server. |
| `response` | `String?` | The raw response body as a string. |
| `statusCodeResponse` | `Object?` | The deserialized body. On a success, the same object `send` returns as its result; on a failure whose status has a `statusCodeResponseTypes` entry, an instance of that type; on a failure with no entry, `null`. |
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
| `send` | `TomServerCall send(TomServerCallLoad load)` | Sends the request with `load`; may be called once. Throws `TomServerConnectionException` if called more than once, or if `load` sets more than one body. Both rejections happen before anything is applied, so a refused `send` leaves the request describing what was actually sent. |
| `read` | `Future<Uint8List> read()` | Reads the response body as bytes (once, after `send`). Throws `TomRequestAbortedException` if aborted — whether the abort lands while awaiting the response or mid-body — and `TomRequestTimeoutException` if `specs.timeout` elapses first. |
| `readAsString` | `Future<String> readAsString(Encoding ec)` | Reads the response body as a string with encoding `ec`. Delegates to `read`, so it is the same single read and refuses a second one identically. |
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

This class creates no clients of its own — it only forwards, to
`instanceClientFactory` or, failing that, to the global factory. A subclass
overriding `getClient` is what eventually produces one, so the factory
registered as the global must be such a subclass. A chain that leads back to a
factory already in it is refused with
`server.connect.client_factory_delegation_cycle`.

- **Implements:** `TomHttpClientAbstractFactory`

##### Constructors

```dart
TomHttpClientFactory()
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setGlobalHttpClientFactory` | `static void setGlobalHttpClientFactory(TomHttpClientFactory factory)` | Sets the global HTTP client factory used by instances without their own factory. The factory must override `getClient`; a plain `TomHttpClientFactory` only forwards, and forwards to itself. |
| `initialize` | `static void initialize([TomHttpClientFactory? defaultFactory])` | Initializes the factory system, setting the global factory to `defaultFactory` or the default. One-shot: `defaultFactory` is ignored once anything has initialized, until `resetGlobalHttpClientFactory`. |
| `resetGlobalHttpClientFactory` | `static void resetGlobalHttpClientFactory()` | Returns the factory system to its unconfigured state so a later `initialize` or `setGlobalHttpClientFactory` takes effect again. Restores the statics only — instances that already resolved keep their cached `instanceClientFactory`. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `instanceClientFactory` | `TomHttpClientFactory?` | Instance-specific client factory override. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getClient` | `Client getClient()` | *(override)* Resolves an HTTP client by delegating to the instance factory, or to the global one when none is set. Throws `TomServerConnectionException` (`server.connect.client_factory_delegation_cycle`) if the delegation leads back to a factory already resolving. |

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
| `statusCodeResponseTypes` | `Map<int, Type>?` | Maps *failing* status codes to the types their bodies carry. Consulted only when the response is not a 2xx, so declaring entries never diverts a success away from the endpoint's own response type. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `send` | `Future<(R result, TomServerCallError? ts)> send(T load, [R? responseObject])` | Sends `load` and returns a `(response, error)` tuple; check `TomServerCallError.hasError` to determine success. Any 2xx is a success and its body is deserialized into `R` — except `204`/`205`, which have no body, so `R` keeps its defaults. A request that never yields a response (refused connection, expired deadline, abort) comes back through the same tuple as `internalError == noResponseError` with the underlying failure in `exception`, not as a throw past it. May throw `TomServerConnectionException` when the server requests a client rethrow. |

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

#### TomRequestTimeoutException

Exception thrown when a request outlives its `TomServerCallSpecs.timeout`.
Raised with the key `server.send.request_timeout`, carrying `url` and
`timeoutMs` in `parameters`; the request is aborted on the way out so its
connection is released.

Deliberately **not** a subtype of `TomRequestAbortedException`, though a timeout
aborts the request: an abort is the application's own decision and repeating it
is pointless, whereas a timeout is the server failing to answer in time — the
case worth retrying. Code that wants to treat both alike can catch
`TomException`; code that wants to retry only timeouts could not tell them apart
again if this were a subclass.

- **Extends:** `TomException`

##### Constructors

```dart
TomRequestTimeoutException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? requestUuid,
})
```

### File Transfer

#### TomFileSource

The bytes to upload together with what the server needs to know about them.
`open` is a *factory* rather than a stream because a Dart stream can be listened
to once, and retry-after-failure needs the same bytes a second time.

##### Constructors

```dart
TomFileSource.stream({
  required String fileName,
  required Stream<List<int>> Function() open,
  int? byteCount,
  String? mediaType,
})
```

##### Factory Constructors

```dart
factory TomFileSource.bytes(String fileName, List<int> bytes, {String? mediaType})
```

The buffer is copied into a `Uint8List`, so a caller mutating its own list
afterwards cannot change what a retry uploads.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `guessMediaType` | `static String guessMediaType(String fileName)` | The media type for `fileName` via `StaticFileMimetypeMapping`, falling back to `application/octet-stream` — deliberately conservative, so an unknown extension becomes a binary blob rather than something a browser might render. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fileName` | `String` | The *display* name; the server derives the storage key itself and keeps this only for `Content-Disposition` when serving the file back. |
| `byteCount` | `int?` | Total size, or `null` when not known in advance — the upload is then sent chunked and progress is indeterminate. |
| `mediaType` | `String` | The media type sent as `Content-Type` (defaults to `guessMediaType(fileName)`). |
| `hasKnownSize` | `bool` | Whether `byteCount` is known, which decides whether a transfer over this source can report a determinate fraction. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Stream<List<int>> open()` | Starts a fresh read of the file's bytes; every call returns an independent stream. |
| `toString` | `String toString()` | *(override)* Renders name, media type and byte count. |

#### TomFileMetadata

What the server knows about a stored file, returned by
`TomFileTransferClient.upload` and `TomFileTransferClient.describe`. The `key` is
the server-generated storage key — opaque to the client, but worth carrying
because it identifies this exact stored revision.

##### Constructors

```dart
const TomFileMetadata({
  required String key,
  required String mediaType,
  required int byteCount,
  String? fileName,
  DateTime? storedAt,
})
```

##### Factory Constructors

```dart
factory TomFileMetadata.fromJson(Map<String, dynamic> json)
```

Tolerant of missing optional members so a server can grow the descriptor without
breaking older clients; a missing or mistyped `key`, `mediaType` or `byteCount`
is a protocol error and throws `TomFileTransferException` keyed
`file_transfer.invalid_descriptor`.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The server-generated storage key. |
| `mediaType` | `String` | The media type the file was stored with. |
| `byteCount` | `int` | The stored size in bytes. |
| `fileName` | `String?` | The original file name, when the server kept one. |
| `storedAt` | `DateTime?` | When the file was stored, when the server reports it. |
| `hashCode` | `int` | *(override)* Hash over key, media type, byte count, file name and `storedAt`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, dynamic> toJson()` | The JSON descriptor; optional members are omitted rather than written as `null`, so a round trip through `fromJson` produces an equal object. |
| `toString` | `String toString()` | *(override)* Renders key, media type, byte count and file name. |

##### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Equal when every field matches. |

#### TomTransferProgress

How far a transfer has got. `total` is `null` whenever the size is not known
ahead of time — an upload from an unmeasurable source, or a download whose
response carries no `Content-Length`.

##### Constructors

```dart
const TomTransferProgress(int transferred, int? total)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `transferred` | `int` | Bytes moved so far. |
| `total` | `int?` | Total bytes, or `null` when unknown. |
| `isDeterminate` | `bool` | Whether a meaningful percentage can be shown; a UI should read this rather than guess, and fall back to a spinner when it is `false`. |
| `fraction` | `double?` | The completed fraction in `0.0 .. 1.0`, or `null` when indeterminate. Clamped, because a server may report a `Content-Length` that a chunked re-encoding then exceeds. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `"TomTransferProgress(<transferred>/<total>)"`. |

#### TomTransferCancellation

A cancel signal shared with an in-flight transfer, wrapping the `Future`-based
abort trigger `package:http` expects. One instance covers one transfer, and
`cancel` is idempotent so a UI can wire it to a button without tracking whether
it already fired.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `trigger` | `Future<void>` | The future that completes when `cancel` is called. |
| `isCancelled` | `bool` | Whether cancellation has been requested. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `cancel` | `void cancel()` | Requests cancellation; does nothing if already cancelled. |
| `throwIfCancelled` | `void throwIfCancelled()` | Throws `file_transfer.cancelled` when cancellation was already requested — used at the start of a transfer so a cancellation that arrived early produces the same error as one arriving mid-flight. |

#### TomFileTransferClient

Moves file bytes between an application and a file store. Four operations,
matching the server-side blob-store contract one for one, addressed by
application-owned **slot** (`invoices/4711/scan`) rather than by storage key:
keys are server-generated, and a client that could name its own would turn any
upload endpoint into an open write surface. Implementations must stream —
neither `upload` nor `download` may buffer a whole file.

- **Extends:** none (abstract base)

##### Constructors

```dart
const TomFileTransferClient()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `upload` | `Future<TomFileMetadata> upload({required String slot, required TomFileSource source, void Function(TomTransferProgress progress)? onProgress, TomTransferCancellation? cancellation})` | Uploads `source` into `slot` and returns what the server stored. `onProgress` is called as bytes leave the client; `cancellation` aborts the request, completing the future with `file_transfer.cancelled`. |
| `download` | `Stream<List<int>> download(String slot, {void Function(TomTransferProgress progress)? onProgress, TomTransferCancellation? cancellation})` | Streams the file stored in `slot`. Lazy — nothing is requested until the stream is listened to — and errors with `file_transfer.not_found` when the slot is empty. |
| `describe` | `Future<TomFileMetadata?> describe(String slot)` | Describes the file in `slot`, or `null` when the slot is empty. Must not transfer the file's bytes, so a UI can show name, type and size without downloading anything. |
| `remove` | `Future<bool> remove(String slot)` | Deletes the file in `slot`, returning whether anything was deleted. An empty slot returns `false` rather than throwing — the caller's intent is already satisfied. |
| `close` | `void close()` | Releases any connections held by this client. |

#### TomHttpFileTransferClient

The HTTP implementation. Uploads use `AbortableStreamedRequest`, so bytes reach
the socket as the source produces them; downloads read the streamed response
directly. Connections are pooled by a `TomServerChannel`.

- **Extends:** `TomFileTransferClient`

The wire contract — every operation addresses `<baseUri>/<slot>`:

| Method | Request | Response |
|--------|---------|----------|
| `POST` | the file's bytes, `Content-Type`, optional `Content-Length`, `Content-Disposition` | `200`/`201` + JSON descriptor |
| `GET` | — | `200` + the file's bytes, `404` when empty |
| `HEAD` | — | `200` + descriptor headers, `404` when empty |
| `DELETE` | — | `200`/`204` when deleted, `404` when empty |

`HEAD` answers `describe` from headers alone, because a describe that
transferred the file would defeat its purpose.

##### Constructors

```dart
TomHttpFileTransferClient({
  required Uri baseUri,
  TomServerChannel? channel,
  bool includeBearerAuthentication = true,
  Map<String, String> headers = const {},
  Map<String, String> Function()? headerProvider,
})
```

`channel` is optional; when omitted one is created for `baseUri`'s host and port.
Pass an existing channel to share a connection pool — only a channel this client
created is closed by `close`. `headerProvider` supplies headers that must be
computed *per request*, which `headers` cannot: a credential rotates, and a
client built once at startup would otherwise keep presenting the value it
captured. Returning an `Authorization` header from it suppresses the built-in
bearer, so there is one credential on the request rather than two spellings of
one.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `baseUri` | `Uri` | The root slot paths are resolved against (trailing slash removed). |
| `channel` | `TomServerChannel` | The channel providing the pooled HTTP client. |
| `includeBearerAuthentication` | `bool` | Whether to send the bearer token from `TomBearerAuthentication`. Leave it on unless the endpoints are genuinely public — a file store is exactly the kind of endpoint that should not be. |
| `headers` | `Map<String, String>` | Extra headers sent with every request (unmodifiable). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `uriForSlot` | `Uri uriForSlot(String slot)` | The URL for `slot`, with each path segment escaped individually so a slot cannot smuggle a `..` or a query string past the base URI. Throws `file_transfer.invalid_slot` for an empty slot or one containing `.` / `..` segments. |
| `upload` | `Future<TomFileMetadata> upload({required String slot, required TomFileSource source, void Function(TomTransferProgress progress)? onProgress, TomTransferCancellation? cancellation})` | *(override)* `POST`s the streamed body and decodes the JSON descriptor from the response. |
| `download` | `Stream<List<int>> download(String slot, {void Function(TomTransferProgress progress)? onProgress, TomTransferCancellation? cancellation})` | *(override)* `GET`s the slot and yields the response stream, translating an abort into `file_transfer.cancelled`. |
| `describe` | `Future<TomFileMetadata?> describe(String slot)` | *(override)* `HEAD`s the slot and builds metadata from the `x-tom-file` descriptor header, or from `content-length` / `content-type` / `content-disposition` when it is absent. |
| `remove` | `Future<bool> remove(String slot)` | *(override)* `DELETE`s the slot; `404` returns `false`. |
| `close` | `void close()` | *(override)* Closes the channel only when this client created it — a shared one belongs to whoever passed it in. |

#### TomMemoryFileTransferClient

A `TomFileTransferClient` that keeps everything in a map. For tests, previews and
offline modes: it honours the same progress and cancellation contract as the HTTP
client (cancellation is checked per chunk in both directions), so a widget wired
to it exercises the real code paths without a server.

- **Extends:** `TomFileTransferClient`

##### Constructors

```dart
TomMemoryFileTransferClient({int chunkSize = 64 * 1024})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `chunkSize` | `int` | How large the pieces handed to `onProgress` are; the default is small enough that a test observes several progress events for a modest payload. |
| `slots` | `Iterable<String>` | The slots currently holding a file. |

##### Methods

The five `TomFileTransferClient` operations, all overridden. Storage keys are
minted as `memory/<counter>/<fileName>`; `close` clears the stored bytes and
metadata.

#### TomFileTransferException

Exception thrown when a file transfer fails.

- **Extends:** `TomException`

##### Constructors

```dart
TomFileTransferException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? requestUuid,
  String? uuid,
})
```

##### Error keys

| Key | Meaning |
| --- | ------- |
| `file_transfer.not_found` | No file is stored in the requested slot. |
| `file_transfer.cancelled` | The caller cancelled the transfer. |
| `file_transfer.rejected` | The server refused the transfer (status code in `parameters['statusCode']`). |
| `file_transfer.source_exhausted` | A `TomFileSource` was re-opened but its stream could only be listened to once. |
| `file_transfer.invalid_descriptor` | The server's file descriptor was not valid JSON, not a JSON object, or lacked `key` / `mediaType` / `byteCount`. |
| `file_transfer.invalid_slot` | A slot was empty or contained `.` / `..` segments. |

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
| `decodeFileDescriptor` | `TomFileMetadata decodeFileDescriptor(String body)` | Decodes the JSON descriptor body shared by the upload and describe responses; throws `file_transfer.invalid_descriptor` when the body is not valid JSON or not a JSON object. Extracted so both the HTTP client and any server implementing the wire contract read the same shape. |
| `tomFileDescriptorHeaders` | `Map<String, String> tomFileDescriptorHeaders(TomFileMetadata metadata)` | Writes the `x-tom-file` descriptor header (plus `Content-Type` / `Content-Length` / `Content-Disposition`) that a `HEAD` response needs so `describe` can answer without a body. Lives beside the client because it is the *contract*, not an implementation. |
| `tomEscapeFileNameForDisposition` | `String tomEscapeFileNameForDisposition(String fileName)` | Escapes a file name for a quoted `Content-Disposition` parameter. Only the two characters that can terminate or escape the quoted string are touched; anything more aggressive would mangle legitimate names. |
| `tomFileNameFromDisposition` | `String? tomFileNameFromDisposition(String? disposition)` | Extracts `filename="…"` (including the RFC 5987 `filename*=` form) from a `Content-Disposition` header, or `null` when the header is absent or names no file. Public, beside its writing counterpart, so the two halves cannot drift. |
