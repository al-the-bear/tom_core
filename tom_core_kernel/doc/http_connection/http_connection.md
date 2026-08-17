# HTTP Connection Module

The HTTP Connection module provides a comprehensive infrastructure for making HTTP requests from client applications to remote servers. It offers type-safe API definitions, configurable HTTP clients, automatic serialization/deserialization, transparent refresh-and-retry for expired tokens, and a streaming file-transfer client for payloads too large to hold in memory.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Architecture](#architecture)
- [Dependencies](#dependencies)

---

## Overview

The module is made up of nine files:

| File | Description |
|------|-------------|
| `auth_retry.dart` | The pluggable "expired token → refresh → retry once" policy for authenticated clients |
| `endpoints_apis.dart` | API and endpoint definitions with type-safe configuration |
| `file_transfer.dart` | The streaming file-transfer contract: sources, metadata, progress, cancellation, the client interface, and an in-memory implementation |
| `headers.dart` | Common HTTP header name constants |
| `http_file_transfer.dart` | The HTTP implementation of that contract, plus the descriptor/`Content-Disposition` helpers both ends of the wire share |
| `httpmethods.dart` | HTTP method definitions (GET, POST, PUT, etc.) |
| `mimetypes.dart` | MIME type definitions and file extension mapping |
| `remote_context.dart` | Client-side configuration of the target API and authentication server URIs |
| `server_connection.dart` | HTTP client infrastructure and request execution |

## Quick Start

### 1. Configure the Remote Context

First, set up where your application should send requests:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Set the remote server context (do this once at app startup)
  TomClientRemoteContext.setCurrent(
    TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
    ),
  );
}
```

### 2. Define Your API

Create type-safe API definitions:

```dart
final userApi = TomApi(
  id: 'users',
  name: 'User Management API',
  uri: '/api/v1/users',
  endpoints: [
    TomApiEndpoint<UserResponse, CreateUserRequest>(
      id: 'create',
      uri: '/create',
      method: TomHttpMethod.post,
      consumes: TomMimeType.json,
      produces: TomMimeType.json,
    ),
    TomApiEndpoint<UserResponse, void>(
      id: 'getById',
      uri: '/{id}',
      method: TomHttpMethod.get,
    ),
  ],
);

// Register the API globally
TomRemoteApis.registerApi(userApi);
```

### 3. Execute Requests

Use `TomServerEndpoint` for type-safe request execution:

```dart
// Create the endpoint executor
final endpoint = TomServerEndpoint.createApiServerEndpoint<
  CreateUserRequest,
  UserResponse
>(userApi['create']);

// Execute the request
final request = CreateUserRequest(name: 'John Doe', email: 'john@example.com');
final (response, error) = await endpoint.send(request);

if (error?.hasError ?? false) {
  print('Error: ${error!.statusCode} - ${error.reasonPhrase}');
} else {
  print('Created user: ${response.id}');
}
```

## Core Components

### TomRemoteApis

A singleton registry for managing all API definitions in your application.

```dart
// Register an API
TomRemoteApis.registerApi(myApi);

// Retrieve by ID
final api = TomRemoteApis.getApiById('myApi');

// Or use bracket notation with global accessor
final endpoint = tomRemoteApis['myApi']['endpoint'];
```

### TomApi

Represents a collection of related endpoints under a common base URI.

```dart
final api = TomApi(
  id: 'orders',
  name: 'Order API',
  uri: '/api/v1/orders',
  requestEncoding: utf8,
  responseEncoding: utf8,
  endpoints: [...],
);
```

### TomApiEndpoint

Defines a single API endpoint with full configuration:

```dart
TomApiEndpoint<OrderResponse, CreateOrderRequest>(
  id: 'createOrder',
  uri: '/create',
  method: TomHttpMethod.post,
  consumes: TomMimeType.json,
  produces: TomMimeType.json,
  includeBearerAuthentication: true,
  followRedirects: false,
  requestHeaders: {'X-Custom-Header': 'value'},
)
```

#### Path and Query Parameters

`urlParameterMapping` binds both halves of a URL to fields of the request DTO.
Keys are the name as it appears on the URL; values are the DTO field the value
travels in. **The key decides which half an entry belongs to:** a key that
appears as a `{capture}` in `uri` fills that path segment, and every other key
is appended to the query string — unless the path already carried its field
(see capture-wins below).

```dart
TomApiEndpoint<UserResponse, void>(
  id: 'getById',
  uri: '/{id}',
  method: TomHttpMethod.get,
  urlParameterMapping: {
    'id': 'userId',                       // {id} in the path
    'include_deleted': 'includeDeleted',  // ?include_deleted=…
  },
)
```

Build the address with `resolveUri`. Its `parameters` are keyed by **DTO field
name** — the right-hand side of the mapping — because a client holds a DTO, not
a URL:

```dart
userApi['getById'].resolveUri(
  Uri.parse('https://api.example.com'),
  parameters: {'userId': 42, 'includeDeleted': true},
); // https://api.example.com/api/v1/users/42?include_deleted=true
```

This is also what lets a snake_cased provider spelling stay out of the Dart
shape: `error_description` is named once, in the mapping, and the DTO field
beside it is `errorDescription`.

The two kinds bind asymmetrically, deliberately:

- **A path capture that is not listed still binds under its own name.** The
  `getById` endpoint above needs no mapping at all if its field is called `id`
  — `parameters: {'id': 7}` resolves to `…/users/7`. A capture is part of the
  route, and the route is part of the endpoint's own declaration.
- **A query parameter binds only when named here.** There is no identity
  fallback: a query string is whatever a caller chose to append, so an identity
  fallback would let any caller write any field of the request DTO. Naming them
  makes query binding opt-in per endpoint and per parameter.
- **A path capture wins over a query parameter mapped to the same field.** The
  rule is about the *field*, not the URL name spelling it: with
  `{'id': 'itemId', 'item_id': 'itemId'}` on `uri: '/{id}'`, `{'itemId': 42}`
  resolves to `…/items/42` and no `?item_id=42` follows it. The server reads a
  request the same way round — it folds query values into the request DTO first
  and lets the path overwrite them under the same field — so the value is
  stated once, by the route, in both directions.

A capture with no answering parameter raises `TomEndpointException`
(`apis.endpoint.missing_url_parameter`) rather than leaving an empty segment —
a URL with a hole in it addresses a different route. An unset query parameter
is simply omitted, since an optional query parameter is ordinary.

### TomHttpMethod

Predefined HTTP methods. `acceptsBody` records whether the verb typically
carries a request body; it is descriptive metadata the constants publish for
callers to consult — the module itself does not branch on it — and `trace` is
the only method for which it is `false`:

| Method | Description | `acceptsBody` |
|--------|-------------|---------------|
| `TomHttpMethod.get` | Retrieve a resource | `true` |
| `TomHttpMethod.post` | Create a new resource | `true` |
| `TomHttpMethod.put` | Replace a resource | `true` |
| `TomHttpMethod.patch` | Partially update a resource | `true` |
| `TomHttpMethod.delete` | Delete a resource | `true` |
| `TomHttpMethod.head` | Retrieve headers only | `true` |
| `TomHttpMethod.options` | Describe the communication options for a resource | `true` |
| `TomHttpMethod.connect` | Establish a tunnel to the server | `true` |
| `TomHttpMethod.trace` | Echo the request back for debugging | `false` |
| `TomHttpMethod.all` | Wildcard — matches any method, for routes that answer all of them | `true` |

To go from a verb string to the constant, look it up in
`TomHttpMethod.methods`, an unmodifiable map keyed by the uppercase name:

```dart
final method = TomHttpMethod.methods['GET'];  // TomHttpMethod.get
```

### TomMimeType

Common MIME types for request/response content:

```dart
TomMimeType.json        // application/json
TomMimeType.html        // text/html
TomMimeType.plainText   // text/plain
TomMimeType.xml         // application/xml
TomMimeType.pdf         // application/pdf
TomMimeType.urlEncoded  // application/x-www-form-urlencoded
TomMimeType.multipartFormData  // multipart/form-data
```

#### Reading a Content-Type Header

`TomMimeType.parse` reads the shape a real header has — a media type followed by
whatever parameters the sender chose to append:

```dart
TomMimeType.parse('application/json;charset=UTF-8');
TomMimeType.parse('text/html; charset="utf-8"');
TomMimeType.parse('multipart/form-data; boundary=----abc');
```

`charset` and `codecs` are read into the value; every other parameter is
ignored rather than rejected, because a multipart request always carries a
boundary this class has no field for. A charset the header does not state stays
`null` — a header states what it states — which makes `parse` the exact inverse
of `toHeaderValue`:

```dart
TomMimeType.parse(TomMimeType.pdf.toHeaderValue()) == TomMimeType.pdf; // true
```

A media type that is not `primary/sub` with both parts present throws
`TomMimeTypeException`.

#### Comparing Two Media Types

There are two comparisons, and which one to use depends on where the value came
from:

- **`==` is whole-value** — primary type, subtype, charset *and* codecs must all
  match. Parameters belong to identity because they change how the bytes are
  read: `text/html;charset=UTF-8` and the same type in Latin-1 decode to
  different characters. This is the comparison for two values you declared
  yourself.
- **`isEqualType` compares the media type only**, ignoring charset and codecs.
  This is the comparison for an incoming `content-type`, because a real request
  carries parameters the declaration never named — a `multipart/form-data` body
  always arrives with a boundary. Comparing whole values there would never
  match, and every form endpoint would silently decode as JSON.

```dart
const declared = TomMimeType.multipartFormData;
const arrived = TomMimeType('multipart', 'form-data', charset: 'UTF-8');

declared == arrived;              // false — the charsets differ
declared.isEqualType(arrived);    // true  — the same media type
```

`hashCode` covers exactly the fields `==` compares, so equal values collapse in
a `Set` and answer a `Map` lookup.

#### Typing a Static File

`StaticFileMimetypeMapping` maps a file extension to the media type the IANA
registry assigns it, for setting `Content-Type` when serving a file from disk:

```dart
StaticFileMimetypeMapping.getMimeType('.woff');   // font/woff
StaticFileMimetypeMapping.getMimeType('.MP4');    // video/mp4 — case-insensitive
StaticFileMimetypeMapping.getMimeType('.xyz');    // null
```

It is a partial function on purpose: an extension it does not know returns
`null` so the caller decides, rather than guessing a type a browser might act
on. `TomFileSource.guessMediaType` is the total version, falling back to
`application/octet-stream` — a download rather than a render.

Two entries are worth knowing about because the obvious guess is wrong. `.ogg`
is `audio/ogg` and Ogg *video* is `.ogv`, per RFC 5334, which split the
container by content because implementations predating the split read a `.ogg`
file as Vorbis audio. And `.avi` is the one extension in the table with no IANA
registration at all, so it maps to `video/x-msvideo`, the type servers and
browsers agree on in the registry's absence.

### TomServerChannel

Manages HTTP client connections with pooling:

```dart
final channel = TomServerChannel('api.example.com', 443);

// Prepare and execute a call
final call = channel.prepareCall(specs);
call.send(load);
final response = await call.readAsString(utf8);

// Close when done
channel.close();
```

### TomServerCall

Low-level HTTP request handling with abort support:

```dart
final call = TomServerCall(client, specs);

// Send the request
call.send(TomServerCallLoad(
  stringBody: jsonEncode(data),
  contentType: 'application/json',
));

// Read the response
final bytes = await call.read();
final text = await call.readAsString(utf8);

// Or abort if needed
call.abort();
```

A call sends **once**. A second `send` throws, and so does a load that sets more
than one body — but both refusals happen before the load is applied, so the
request still describes what was actually sent rather than what was refused.
Use `reset()` to send the same call again.

### Authentication Retry

When a bearer token goes stale the server answers `401`, and the client should
refresh the token **once** and replay the request — but a *second* consecutive
rejection is a genuinely dead session that must surface as an error rather than
loop. `tomRunWithAuthRetry` is the framework home of that sequence, so no
application writes it by hand.

The caller supplies only the two things it actually knows: how to re-mint a token
(`TomAuthRefresher`) and how to read a status code out of its own response type.
The decision logic — which status counts as an expiry, how many retries, when to
give up — lives in `TomAuthRetryPolicy`.

```dart
class MyRefresher extends TomAuthRefresher {
  @override
  Future<bool> refresh() async {
    // Call the auth server, store the new token pair, return whether it worked.
  }
}

final (response, error) = await tomRunWithAuthRetry(
  send: () => endpoint.send(request),
  statusOf: (result) => result.$2?.statusCode ?? 200,
  refresher: MyRefresher(),
);
```

`send` must re-read the current bearer on each call, so the replay picks up the
refreshed token. A non-expiry error status (`403`, `404`, …) is returned
unchanged for the caller to interpret; a refresher returning `false` means there
was no session to refresh, so the original response stands; and an expiry status
that persists after the retries throws `TomAuthExpiredException`.

The coordinator is transport-agnostic on purpose — it works over any
`send()`-shaped callback returning any response type — so a Flutter client and a
Flutter-free client core inherit the same mechanism despite using different HTTP
seams.

`TomAuthRetryPolicy.active` resolves a registered `TomAuthRetryPolicy` bean if
there is one and `tomDefaultAuthRetryPolicy` (a single `401`, one retry)
otherwise, resolved fresh on each call so a test or a late environment
registration is honoured:

```dart
TomBean.withType(
  TomAuthRetryPolicy,
  const TomAuthRetryPolicy(expiryStatusCodes: {401, 419}, maxRefreshRetries: 2),
);
```

See `example/samples/http_connection/06_auth_retry_example.dart` for a runnable
walkthrough.

### File Transfer

`TomServerCall` reads a whole response into memory, which is right for JSON and
wrong for a 400 MB video. The file-transfer family reuses the same connection
machinery — `TomServerChannel`, the bearer token, the client factory — but never
materializes the payload: bytes are handed to the socket as the source produces
them, and a download is a `Stream<List<int>>` the caller consumes as it arrives.

A transfer addresses a **slot** — an application-owned path such as
`invoices/4711/scan` — and never a storage key. Keys are generated by the server
and returned in `TomFileMetadata.key`; a client that could name its own key would
turn any upload endpoint into an open write surface on the file store.

```dart
final client = TomHttpFileTransferClient(
  baseUri: Uri.parse('https://api.example.com/files'),
);
final cancellation = TomTransferCancellation();

final stored = await client.upload(
  slot: 'invoices/4711/scan',
  source: TomFileSource.bytes('scan.pdf', pdfBytes),
  onProgress: (p) => print('${(p.fraction ?? 0) * 100}%'),
  cancellation: cancellation,
);

await for (final chunk in client.download('invoices/4711/scan')) {
  sink.add(chunk);
}

client.close();
```

Four operations make up the contract, matching the server-side blob store one
for one:

| Operation | Purpose |
|-----------|---------|
| `upload` | Streams a `TomFileSource` into a slot and returns the stored `TomFileMetadata`. |
| `download` | Streams the file back; errors with `file_transfer.not_found` when the slot is empty. |
| `describe` | Returns metadata without transferring bytes (answered from a `HEAD` response). |
| `remove` | Deletes the file; an empty slot returns `false` rather than throwing. |

`TomFileSource` hands out a *factory* rather than a stream, because a Dart stream
can be listened to once and a retry needs the same bytes again: use
`TomFileSource.bytes` for an in-memory buffer or `TomFileSource.stream` with an
`open:` callback that re-opens a file. `byteCount` is optional — when it is
absent the upload is sent chunked and progress is indeterminate, which
`TomTransferProgress.isDeterminate` reports so a UI can fall back to a spinner.

`TomTransferCancellation` is the shared cancel signal. It aborts the socket
rather than merely stopping the caller from waiting, and `cancel()` is idempotent
so it can be wired straight to a button.

`TomMemoryFileTransferClient` implements the same contract over a map, honouring
the same progress and cancellation behaviour — so tests, widget previews, and
offline modes exercise the real code paths without a server.

## Usage Examples

### Making a GET Request

```dart
final channel = TomServerChannel('api.example.com', 443);
final specs = TomServerCallSpecs(
  'GET',
  Uri.parse('https://api.example.com/users/123'),
  headers: {'Accept': 'application/json'},
);

final call = channel.prepareCall(specs);
call.send(TomServerCallLoad());
final response = await call.readAsString(utf8);
channel.close();
```

### Making a POST Request with JSON Body

```dart
final specs = TomServerCallSpecs(
  'POST',
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
);

final call = TomServerCall(client, specs);
call.send(TomServerCallLoad(
  stringBody: '{"name": "John", "email": "john@example.com"}',
  contentType: 'application/json',
  encoding: utf8,
));

final statusCode = await call.getResponseStatusCode();
final body = await call.readAsString(utf8);
```

### Using Form Data

```dart
final call = TomServerCall(client, specs);
call.send(TomServerCallLoad(
  bodyFields: {
    'username': 'john',
    'password': 'secret',
  },
));
```

### Handling Errors

```dart
final (response, error) = await endpoint.send(request);

if (error != null && error.hasError) {
  switch (error.statusCode) {
    case 400:
      print('Bad request: ${error.response}');
      break;
    case 401:
      print('Unauthorized - token expired?');
      break;
    case 404:
      print('Resource not found');
      break;
    case 500:
      print('Server error: ${error.reasonPhrase}');
      break;
    default:
      print('Error ${error.statusCode}: ${error.response}');
  }
}
```

### Custom HTTP Client Factory

```dart
class MyCustomClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() {
    // Return your custom client (e.g., with interceptors)
    return MyCustomClient();
  }
}

// Set globally
TomHttpClientFactory.setGlobalHttpClientFactory(MyCustomClientFactory());
```

### Separate Authentication Server

```dart
TomClientRemoteContext.setCurrent(
  TomClientRemoteContext(
    Uri.parse('https://api.example.com'),      // Main API
    Uri.parse('https://auth.example.com'),     // Auth server
  ),
);
```

### Addressing a Second Server

`setCurrent` refuses a second call — the process-wide context is deliberately
write-once, so nothing can silently redirect every call in the application
halfway through its life. To reach a different remote for *part* of a program,
scope it instead:

```dart
final report = await TomClientRemoteContext.runWithContext(
  TomClientRemoteContext(Uri.parse('https://reporting.example.com')),
  () => reportingApi.fetchSummary(),
);
```

The context rides on the `Zone`, so it follows the body across `await`
boundaries and is gone again once the body completes. This is the supported way
for a tool to talk to two servers, and for a test to point one case at a stub
without disturbing the next.

## Best Practices

### 1. Initialize Early

Set up `TomClientRemoteContext` as early as possible in your application lifecycle, typically in `main()`.

### 2. Register APIs Once

Register all your API definitions during app initialization:

```dart
void initializeApis() {
  TomRemoteApis.registerApi(userApi);
  TomRemoteApis.registerApi(orderApi);
  TomRemoteApis.registerApi(productApi);
}
```

### 3. Handle All Error Cases

Always check for errors after API calls:

```dart
final (response, error) = await endpoint.send(request);
if (error?.hasError ?? false) {
  // Handle error appropriately
  return;
}
// Process successful response
```

### 4. Close Channels When Done

If you create `TomServerChannel` instances manually, close them when finished:

```dart
final channel = TomServerChannel('api.example.com', 443);
try {
  // Use channel...
} finally {
  channel.close();
}
```

### 5. Use Type-Safe Endpoints

Prefer `TomServerEndpoint.createApiServerEndpoint` over manual HTTP calls for type safety and automatic serialization.

### 6. Configure Timeouts

A call waits indefinitely unless you give it a deadline, so declare one on any
endpoint whose caller cannot afford to block forever:

```dart
TomApiEndpoint<OrderResponse, CreateOrderRequest>(
  id: 'createOrder',
  method: TomHttpMethod.post,
  timeout: Duration(seconds: 10),
)
```

The same field exists on `TomServerCallSpecs` for calls built by hand:

```dart
final specs = TomServerCallSpecs(
  'GET',
  Uri.parse('https://api.example.com/data'),
  timeout: Duration(seconds: 10),
);
```

When the deadline passes, `read` throws `TomRequestTimeoutException` and the
request is aborted so its connection is released. The budget covers the whole
exchange — waiting for the response *and* draining its body — because a server
that answers promptly and then stalls mid-body blocks the caller just as
effectively as one that never answers at all.

Pick the value per endpoint rather than globally: the deadline that protects a
lookup would truncate a report that legitimately takes a minute. Leave it unset
where waiting is genuinely correct — file transfers use their own client and
are not governed by this setting.

`TomRequestTimeoutException` is deliberately **not** a `TomRequestAbortedException`.
An abort is your own application's decision; a timeout is the server failing to
answer, which is the case worth retrying. Catch them separately:

```dart
try {
  final body = await call.readAsString(utf8);
} on TomRequestTimeoutException {
  // The server was too slow — retrying may well succeed.
} on TomRequestAbortedException {
  // We cancelled this ourselves — do not retry.
}
```

### 7. Secure Authentication

Bearer tokens are automatically included by default. Disable with `includeBearerAuthentication: false` for public endpoints:

```dart
TomApiEndpoint<PublicData, void>(
  id: 'publicEndpoint',
  method: TomHttpMethod.get,
  includeBearerAuthentication: false,  // No auth needed
)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                             │
├─────────────────────────────────────────────────────────────┤
│  TomRemoteApis                                               │
│  ├── TomApi (users)                                          │
│  │   ├── TomApiEndpoint (create)                            │
│  │   └── TomApiEndpoint (getById)                           │
│  └── TomApi (orders)                                         │
│      └── TomApiEndpoint (list)                              │
├─────────────────────────────────────────────────────────────┤
│  TomServerEndpoint<Request, Response>                        │
│  └── Type-safe request/response handling                     │
├─────────────────────────────────────────────────────────────┤
│  TomServerChannel                                            │
│  └── TomHttpClientFactory                                    │
├─────────────────────────────────────────────────────────────┤
│  TomServerCall                                               │
│  └── Low-level HTTP operations                               │
├─────────────────────────────────────────────────────────────┤
│  TomClientRemoteContext                                      │
│  └── Server URI configuration                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Dependencies

This module depends on:

- **Little Things Module**: `TomException` base class for error handling
- **Security Module**: `TomBearerAuthentication` for authentication
- **Bean Locator Module**: `TomBean` for resolving the active `TomAuthRetryPolicy`
- **Reflection Module**: `TomReflectionInfo` for JSON serialization support
- **Runtime Module**: Platform utilities for HTTP client creation
