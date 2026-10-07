# HTTP Connection Module

The HTTP Connection module provides a comprehensive infrastructure for making HTTP requests from client applications to remote servers. It offers type-safe API definitions, configurable HTTP clients, automatic serialization/deserialization, transparent refresh-and-retry for expired tokens, and a streaming file-transfer client for payloads too large to hold in memory.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [1. Configure the Remote Context](#1-configure-the-remote-context)
  - [2. Define Your API](#2-define-your-api)
  - [3. Execute Requests](#3-execute-requests)
- [Core Components](#core-components)
  - [TomRemoteApis](#tomremoteapis)
  - [TomApi](#tomapi)
  - [TomApiEndpoint](#tomapiendpoint)
  - [TomHttpMethod](#tomhttpmethod)
  - [TomMimeType](#tommimetype)
  - [TomServerChannel](#tomserverchannel)
  - [TomServerCall](#tomservercall)
  - [Authentication Retry](#authentication-retry)
  - [File Transfer](#file-transfer)
- [Usage Examples](#usage-examples)
  - [Making a GET Request](#making-a-get-request)
  - [Making a POST Request with JSON Body](#making-a-post-request-with-json-body)
  - [Using Form Data](#using-form-data)
  - [Handling Errors](#handling-errors)
  - [Which Status Codes Count as a Success](#which-status-codes-count-as-a-success)
  - [When No Response Arrives At All](#when-no-response-arrives-at-all)
  - [Custom HTTP Client Factory](#custom-http-client-factory)
  - [Separate Authentication Server](#separate-authentication-server)
  - [Addressing a Second Server](#addressing-a-second-server)
- [Best Practices](#best-practices)
  - [1. Initialize Early](#1-initialize-early)
  - [2. Register APIs Once](#2-register-apis-once)
  - [3. Handle All Error Cases](#3-handle-all-error-cases)
  - [4. Close Channels When Done](#4-close-channels-when-done)
  - [5. Use Type-Safe Endpoints](#5-use-type-safe-endpoints)
  - [6. Configure Timeouts](#6-configure-timeouts)
  - [7. Secure Authentication](#7-secure-authentication)
- [Architecture](#architecture)
- [Dependencies](#dependencies)
  - [The list above is the import list](#the-list-above-is-the-import-list)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomServerCall` | class | A single server call (request/response envelope). |
| `TomServerCallSpecs` | class | Static specification of a server call. |
| `TomServerCallLoad` | class | Request payload of a server call. |
| `TomServerCallError` | class | Error payload of a server call. |
| `TomServerChannel` | class | Channel abstraction over a server connection. |
| `TomServerEndpoint` | class | Typed server-side endpoint. |
| `TomServerConnectionException` | class | Connection failure (extends `TomException`). |
| `TomRequestAbortedException` | class | Aborted-request failure (extends `TomException`). |
| `TomHttpClientFactory` | class | Resolves a client through a per-instance override or the global registration. |
| `TomHttpClientAbstractFactory` | abstract interface class | The client-factory contract a custom factory implements. |
| `TomDefaultHttpClientFactory` | class | The shipped factory, over the platform's client. |
| `TomRemoteApis` | class | Registry of remote API groups. |
| `TomApi` | class | A remote API group. |
| `TomApiEndpoint` | class | A typed remote API endpoint. |
| `TomEndpointException` | class | Endpoint failure (extends `TomException`). |
| `TomContentDisposition` | class | Content-Disposition parsing/model. |
| `TomHeader` | class | HTTP header name constants/model. |
| `TomHttpMethod` | class | HTTP method constants/model. |
| `TomMimeType` | class | MIME-type model. |
| `TomMimeTypeException` | class | MIME-type failure (extends `TomException`). |
| `StaticFileMimetypeMapping` | class | Extension→MIME-type map for static files. |
| `TomAuthRefresher` | abstract class | Contract for refreshing an expired auth token. |
| `TomAuthRetryPolicy` | class | Policy for retrying on auth expiry. |
| `TomAuthExpiredException` | class | Auth-expired failure (extends `TomException`). |
| `TomClientRemoteContext` | class | Client-side remote context. |
| `TomClientRemoteContextException` | class | Remote-context failure (extends `TomException`). |
| `TomFileMetadata` | class | What the server knows about a stored file. |
| `TomFileSource` | class | The bytes to upload, together with what the server needs to know about them. |
| `TomFileTransferClient` | abstract class | Moves file bytes between an application and a file store. |
| `TomFileTransferException` | class | Exception thrown when a file transfer fails. |
| `TomHttpFileTransferClient` | class | A `TomFileTransferClient` over HTTP. |
| `TomMemoryFileTransferClient` | class | A `TomFileTransferClient` that keeps everything in a map. |
| `TomRequestTimeoutException` | class | Exception thrown when a request outlives its `TomServerCallSpecs.timeout`. |
| `TomTransferCancellation` | class | A cancel signal shared with an in-flight transfer. |
| `TomTransferProgress` | class | How far a transfer has got. |

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

```dart complete
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

A lookup that finds nothing throws `TomEndpointException` rather than answering
`null`: an unregistered API id is `apis.api.not_found`, and an endpoint id the
API does not carry is `apis.endpoint.not_found`. An endpoint knows its API only
once it has been added to one, and reading `api` before that is
`apis.endpoint.api_not_set`.

### TomApi

Represents a collection of related endpoints under a common base URI.

```dart
final api = TomApi(
  id: 'orders',
  name: 'Order API',
  uri: '/api/v1/orders',
  requestEncoding: utf8,
  responseEncoding: utf8,
  endpoints: [/* TomApiEndpoint entries — see below */],
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

The two type parameters are the response and request DTOs, and they are
**reflection-first**: annotate each with `@tomReflectable` and declare **plain
non-`final` fields**, with no hand-written `toJson`/`fromJson`. This module does
not serialize them itself — it hands them to `tomReflectionInfo`, the same pair
of entry points the server pipeline uses, so a type that round-trips here
round-trips identically there. A `final` member cannot be assigned after
construction, so reflection can never restore it, and the framework says so in
both directions rather than degrading quietly: a response payload naming a
`final` member fails to decode with
`reflection.set.unexpected_condition_final_static_private`, and a request DTO
whose members are *all* `final` fails to encode with
`reflector.type.all_final`. See the
[Reflection Module](../reflection/reflection.md) for the full precedence.

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

#### Do not capture a field the request already carries

A path capture also wins over a **body** field of the same name, by the same
mechanism — the server folds the JSON body in first and lets the URL overwrite
it. Do not lean on that. Precedence answers a question a contract is better off
not asking: a request that states its subject twice can state it two different
ways, and a caller that reads the body as authoritative is wrong without ever
being told.

So declare a capture for a field the request DTO **does not otherwise carry** —
the by-id request whose only field is the id — or, when the DTO must carry it,
declare no capture and let the body be the single statement. The preferences
API is the worked example both ways round: `readPreference` and
`deletePreference` take a `TomUserPreferenceKeyRequest` whose one field is bound
from `/{key}`, while `writePreference` — whose request carries a key, a type and
a value together — is a `PUT` at the bare collection.

`TomServerEndpoint.createApiServerEndpoint` resolves the same way, so a caller
that goes from a declaration straight to a callable endpoint gets the same
address without naming a URI:

```dart
final endpoint = TomServerEndpoint.createApiServerEndpoint<
  UserRequest,
  UserResponse
>(
  userApi['getById'],
  parameters: {'userId': 42, 'includeDeleted': true},
);
// endpoint.specs.url
//   https://api.example.com/api/v1/users/42?include_deleted=true
```

The template both sides resolve, `(api.uri ?? '') + (uri ?? '')`, is the same
expression the server pipeline mounts the route from — so client and server
addresses are two readings of one declaration rather than two spellings that
have to be kept in step.

`example/samples/http_connection/07_endpoint_call_example.dart` carries one
declaration the whole way: it resolves the address, calls it against a loopback
`HttpServer`, and asserts that the path the server *received* is the resolved
one rather than the template. It also shows the failing half, where a status
declared in `statusCodeResponseTypes` arrives as its own type instead of as
raw text.

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
TomMimeType.json;        // application/json
TomMimeType.html;        // text/html
TomMimeType.plainText;   // text/plain
TomMimeType.xml;         // application/xml
TomMimeType.pdf;         // application/pdf
TomMimeType.urlEncoded;  // application/x-www-form-urlencoded
TomMimeType.multipartFormData;  // multipart/form-data
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
`TomMimeTypeException`: `mime_type.parse.invalid_number_of_parts` when the
slash is missing or doubled, `mime_type.parse.invalid_mime_type.empty_parts`
when one side of it is empty.

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

Both comparisons fold **case** in the media type and the charset, because
RFC 2045 §5.1 makes them case-insensitive. A peer that writes `TEXT/HTML` or
`charset=utf-8` names the same thing as the constant, and neither comparison may
answer otherwise — `isEqualType` least of all, since it is the one a server runs
against a header it did not write:

```dart
TomMimeType.parse('TEXT/HTML;charset=utf-8') == TomMimeType.html;  // true
```

Codecs are the exception: they compare verbatim, because an RFC 6381 codec
string encodes profile and level as hex, so `avc1.42E01E` and `avc1.42e01e` are
not interchangeable.

The **fields** keep the spelling they were given — only the comparisons fold
case — so a value read from a header renders that header back:

```dart
TomMimeType.parse('TEXT/HTML').subType;        // 'HTML'
TomMimeType.parse('TEXT/HTML').toHeaderValue(); // 'TEXT/HTML'
```

`isText` follows the same rule: `TEXT/HTML` is text.

`hashCode` covers exactly the fields `==` compares, under exactly the same
case rule, so equal values collapse in a `Set` and answer a `Map` lookup.

#### Typing a Static File

`StaticFileMimetypeMapping` maps a file extension to the media type the IANA
registry assigns it, for setting `Content-Type` when serving a file from disk:

```dart
StaticFileMimetypeMapping.getMimeType('.woff2');  // font/woff2
StaticFileMimetypeMapping.getMimeType('.MP4');    // video/mp4 — case-insensitive
StaticFileMimetypeMapping.getMimeType('.xyz');    // null
```

It is a partial function on purpose: an extension it does not know returns
`null` so the caller decides, rather than guessing a type a browser might act
on. `TomFileSource.guessMediaType` is the total version, falling back to
`application/octet-stream` — a download rather than a render.

The table is curated, not a registry mirror. It covers what an application
serves over HTTP: the web assets (`.html`, `.css`, `.js`, `.json`, `.wasm`,
`.ico`), the four RFC 8081 font types (`.ttf`, `.otf`, `.woff`, `.woff2`), the
text and document types (`.txt`, `.csv`, `.xml`, `.ics`, `.pdf`), the images,
the media containers, and `.zip` / `.rar`. Everything else is somebody else's
decision.

Three entries are worth knowing about because the obvious guess is wrong.
`.ogg` is `audio/ogg`, Ogg *video* is `.ogv` and the generic multiplex is
`.ogx`, per RFC 5334, which split the container by content because
implementations predating the split read a `.ogg` file as Vorbis audio. `.ico`
is `image/vnd.microsoft.icon` — the widely-seen `image/x-icon` was never
registered. And `.avi` is the one extension in the table with no IANA
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

`TomServerChannel.forUri` builds the same channel from an address that is already
a `Uri`, taking the port the URI names or, failing that, its scheme's — `443` for
`https`, `80` for anything else:

```dart
final channel = TomServerChannel.forUri(Uri.parse('https://api.example.com'));
// channel.port == 443
```

This is the derivation `TomServerEndpoint.createApiServerEndpoint` and
`TomHttpFileTransferClient` use for the channels they build, so a channel
addresses the same port as the URI written into the call's specs.

### TomServerCall

Low-level HTTP request handling with abort support:

```dart
final call = TomServerCall(client, specs);

// Send the request
call.send(TomServerCallLoad(
  stringBody: jsonEncode(data),
  contentType: 'application/json',
));

// Read the response — one of these, not both
final bytes = await call.read();
// ...or, equivalently, decoded:
// final text = await call.readAsString(utf8);

// Or abort if needed
call.abort();
```

A call sends **once**. A second `send` throws
`server.send.illegal_state_only_send_once`, a load that sets more than one body
throws `server.connect.only_one_type_of_body_possible`, and a form body labelled
as anything but a form throws
`server.connect.form_body_needs_form_content_type` — every refusal
happens before the load is applied, so the request still describes what was
actually sent rather than what was refused. Use `reset()` to send the same call
again.

The load's `contentType` is applied ahead of its body, which is what lets
`package:http` attach the `encoding`'s charset to the type the caller named
instead of to the `text/plain` it would otherwise assume. There is no
`contentLength` to go with it: a non-streaming request measures its own body and
refuses to be told a length, so streaming uploads — the case where a length must
be declared — go through `TomHttpFileTransferClient` rather than through a load.

A call is also read **once**: the body is a stream, and draining it leaves
nothing behind. `readAsString` *is* `read` with a decode on the end, so the two
are not alternatives you can take in turn — either one consumes the body, and
whichever comes second is refused under the same key,
`server.send.illegal_state_only_read_once`.

Reading before the call has been sent is refused the same way. There are eight
members that read something off the response — `read`, `readAsString` and the six
`getResponse*` accessors — and all eight raise the one key
`server.send.illegal_state_read_must_be_after_send`, because an error key's last
segment names the *condition* and "nothing has been sent" is one condition. Which
value was being asked for is a detail, so it travels as a detail: the message
names it and the `read` parameter carries it.

```dart
try {
  await call.getResponseStatusCode();
} on TomServerConnectionException catch (e) {
  // One key covers every reader, so this branch cannot be defeated by
  // calling a different accessor.
  if (e.key == 'server.send.illegal_state_read_must_be_after_send') {
    print('not sent yet; wanted ${e.parameters?['read']}');
  }
}
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
`invoices/4711/scan` — and never a storage key. An empty slot, or one with a
`.` or `..` segment, is refused before a request is made, with
`file_transfer.invalid_slot`. Keys are generated by the server
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

`example/samples/http_connection/08_file_transfer_example.dart` runs all four
operations twice over: once against `TomMemoryFileTransferClient`, which needs
no server, and once against a loopback `HttpServer` that speaks the wire
contract — writing its descriptor with `tomFileDescriptorHeaders`, which is
public for exactly that reason.

`TomTransferCancellation` is the shared cancel signal. It aborts the socket
rather than merely stopping the caller from waiting, and `cancel()` is idempotent
so it can be wired straight to a button. A cancelled transfer fails with
`file_transfer.cancelled`.

Two answers from the server are failures of their own. Any status outside the
success range other than `404` — which is `file_transfer.not_found` — is
`file_transfer.rejected`, carrying the slot, the status and the body. A success
whose descriptor lacks the key, the media type or the byte count is
`file_transfer.invalid_descriptor`: a file the server cannot describe is not one
the client can report as stored.

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

Form fields are sent as `application/x-www-form-urlencoded`, and nothing else
may claim otherwise — so this spec carries no `Content-Type` of its own. Naming
one that is not a form, on either the spec or the load, throws
`TomServerConnectionException` with
`server.connect.form_body_needs_form_content_type` before anything is written
to the request.

```dart
final formSpecs = TomServerCallSpecs(
  'POST',
  Uri.parse('https://api.example.com/login'),
);

final call = TomServerCall(client, formSpecs);
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

### Which Status Codes Count as a Success

`hasError` is false for the whole **2xx** range, so `201 Created` and
`204 No Content` are successes — the ordinary answers of the POST and DELETE
endpoints this layer exists to call — and their bodies are deserialized into the
endpoint's response type just as a `200` is.

`statusCodeResponseTypes` describes **failure** bodies only. It maps a failing
status to the type that status carries, and it is consulted only once the
response is known not to be a success, so declaring entries never changes what
happens to a 2xx:

```dart
final endpoint = TomServerEndpoint<CreateUserRequest, UserResponse>(
  channel,
  specs,
  // Failure codes only. A 201 is still deserialized into UserResponse.
  statusCodeResponseTypes: {409: ConflictDetails, 422: ValidationErrors},
);

final (user, error) = await endpoint.send(CreateUserRequest(name: 'John'));
if (error?.hasError ?? false) {
  final details = error!.statusCodeResponse; // ConflictDetails on a 409
} else {
  print(user.id); // populated from the 201 body
}
```

`204` and `205` carry no body by definition, so nothing is deserialized for them
and the response object keeps its default values. Any other status that promised
a body and sent none is still a parse failure, reported through
`internalError == TomServerCallError.serverError`.

### When No Response Arrives At All

A refused connection, an expired deadline and an aborted request all mean the
same thing to the caller: there is no response to inspect. `TomServerEndpoint`
reports each of them through the same `(response, error)` tuple as every other
failure, so the `if (error?.hasError ?? false)` shape above covers a dropped
network as well as it covers a `500`:

```dart
final (user, error) = await endpoint.send(CreateUserRequest(name: 'John'));
if (error?.hasError ?? false) {
  if (error!.internalError == TomServerCallError.noResponseError) {
    // No response: no status, no body, no headers. Which way the connection
    // failed is in error.exception — a TomRequestTimeoutException for an
    // expired deadline, a ClientException for a refused connection.
    print('unreachable: ${error.exception}');
  }
}
```

Such an error carries `statusCode` `0` — there is no status to report, and
leaving it at the `200` default would describe a success that never happened.

`TomServerCall`, the layer beneath, still signals these by throwing
`TomRequestTimeoutException` and `TomRequestAbortedException`; a caller working
at that level catches them directly. The translation to `noResponseError`
belongs to the endpoint, because the tuple is the endpoint's contract.

### Custom HTTP Client Factory

```dart
class MyCustomClientFactory implements TomHttpClientAbstractFactory {
  @override
  Client getClient() {
    // Return your custom client (e.g., with interceptors)
    return MyCustomClient();
  }
}

// Set globally
TomHttpClientFactory.setGlobalHttpClientFactory(MyCustomClientFactory());

// Or for one channel only
TomServerChannel('api.example.com', 443,
    clientFactory: MyCustomClientFactory());
```

`TomHttpClientAbstractFactory` is the whole contract: one method returning a
client. Implement it rather than extending `TomHttpClientFactory`, which is the
*resolver* — it creates no clients itself, forwarding to its instance factory
or to the global one when it has none. A subclass of the resolver that does not
override `getClient` can only pass the request on; register such a factory as
the global and it forwards to itself, which is refused with
`server.connect.client_factory_delegation_cycle` rather than recursing until the
stack runs out.

A running version of this, asserting that the registered factory answers for a
channel with none of its own and that a per-channel factory wins over it, is
`example/samples/http_connection/01_http_client_example.dart`.

Tests that install a global factory should undo it with
`TomHttpClientFactory.resetGlobalHttpClientFactory()`. The global is
process-wide and `initialize` is one-shot, so without a reset the first test to
configure it decides what every later test resolves to.

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

`setCurrent` refuses a second call, with
`tomclient.remote_context_state_error.already_initialized` — the process-wide context is deliberately
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

Prefer `TomServerEndpoint.createApiServerEndpoint` over manual HTTP calls for type safety and automatic serialization. The type arguments are checked against the endpoint's own: an endpoint declared for other request or response types is refused with `apis.endpoint.invalid_type_parameters` instead of failing at the first decode.

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

When the deadline passes, `read` throws `TomRequestTimeoutException`
(`server.send.request_timeout`) and the request is aborted so its connection is released. The budget covers the whole
exchange — waiting for the response *and* draining its body — because a server
that answers promptly and then stalls mid-body blocks the caller just as
effectively as one that never answers at all.

Pick the value per endpoint rather than globally: the deadline that protects a
lookup would truncate a report that legitimately takes a minute. Leave it unset
where waiting is genuinely correct — file transfers use their own client and
are not governed by this setting.

`TomRequestTimeoutException` is deliberately **not** a `TomRequestAbortedException`,
whose key is `server.send.request_aborted`.
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

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `file_transfer.dart`, `http_file_transfer.dart`, `remote_context.dart`, `server_connection.dart` | `Completer`, `Future`, `Stream`, `unawaited` |
| `dart:convert` | dart | `endpoints_apis.dart`, `file_transfer.dart`, `http_file_transfer.dart`, `server_connection.dart` | `Encoding`, `json`, `jsonDecode`, `jsonEncode` |
| `dart:typed_data` | dart | `file_transfer.dart`, `server_connection.dart` | `Uint8List` |
| `http` | package | `http_file_transfer.dart`, `server_connection.dart` | `Client`, `Request`, `Response`, `StreamedResponse` — the transport every call and file transfer goes over |
| `meta` | package | `remote_context.dart` | `@visibleForTesting` only; no runtime behaviour |
| `tom_basics` | package | `remote_context.dart`, `server_connection.dart` | `TomPlatformUtils.current.httpClient()`, which is how a channel obtains a platform-appropriate client |
| [beanlocator](../beanlocator/beanlocator.md) | module | `auth_retry.dart` | `TomBean` for resolving the active `TomAuthRetryPolicy` |
| [little_things](../little_things/little_things.md) | module | `auth_retry.dart`, `endpoints_apis.dart`, `file_transfer.dart`, `mimetypes.dart`, `remote_context.dart`, `server_connection.dart` | `TomException`, the base class for error handling |
| [reflection](../reflection/reflection.md) | module | `server_connection.dart` | `createInstance`, `convertToJsonString` and `convertFromJsonString`, which *are* the send path. A DTO sent through this module needs generated reflection data; without it the send fails loudly — `reflector.reflect.not_reflectable` for a class with no generated data at all, `reflector.type.not_annotated` for one that reflects but carries no `@tomReflector` — rather than sending something empty |
| [security](../security/security.md) | module | `endpoints_apis.dart`, `http_file_transfer.dart`, `server_connection.dart` | `TomBearerAuthentication`, for the token attached when `includeBearerAuthentication` is set, and `TomAccessControl` / `TomPublicAccess` / `TomAuthenticatedAccess` for the endpoint access policies |

### The list above is the import list

Every source file here names the siblings it uses by relative path, so the
dependencies of any one file are readable from its first few lines and the list
above is derivable from them rather than compiled by hand from the symbols.
`prefer_relative_imports` is enabled for this package, so a `package:` URI back
into `lib/` — including one naming the package's own barrel — is reported. The
rule is raised to `warning` in `tom_ai/core/analysis_options.yaml`, because at
its default `info` severity `dart analyze` prints the finding and still exits
zero: the shape would be reported and not refused. `test/import_convention_test.dart`
asserts both the absence of such an import and the severity that lets the
analyzer fail on one.

That matters more here than in most modules, because `http_connection` sits in
two import cycles, and a cycle is only visible while the edges that make it are
visible:

- **`http_connection` ↔ `little_things`.** Seven files here import
  `little_things/exception_base.dart` for `TomException`, and
  `exception_base.dart` imports `http_connection/server_connection.dart` in
  return, because `TomException` carries a `TomServerCallError? serverCallError`
  — the framework's base exception type holds a transport-specific payload.
- **`http_connection` ↔ `security`.** `server_connection.dart` and
  `http_file_transfer.dart` need `bearer_authentication.dart` to attach a token,
  and `endpoints_apis.dart` needs `access_controls.dart` for the endpoint access
  policies; `security/oauth_contract.dart` imports `endpoints_apis.dart` and
  `httpmethods.dart` back, to declare the OAuth endpoints it specifies.

Neither cycle is an error — Dart resolves cyclic library imports — and neither
is accidental: each is one type reaching across the seam in each direction. They
are recorded because a new edge from this module can close a *third* cycle
without anything complaining, and an import line is the only place that shows up.
