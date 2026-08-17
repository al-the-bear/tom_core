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

Use appropriate timeouts for your use case to prevent hanging requests.

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
