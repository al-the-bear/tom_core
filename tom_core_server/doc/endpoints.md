# Endpoints Module

Annotation-driven HTTP endpoints. You annotate service methods; at startup the
pipeline reflects over the annotated classes, mounts one [shelf] route per
endpoint, and — per request — enforces access, binds the method's parameters
from the request, optionally wraps the call in a transaction, invokes the
method, and converts the result (or any error) into a `Response`.

## Table of Contents

- [Overview](#overview)
- [Declaring an Endpoint](#declaring-an-endpoint)
- [Resolving the Implementation Instance](#resolving-the-implementation-instance)
- [The Request Pipeline](#the-request-pipeline)
- [Parameter Binding](#parameter-binding)
- [Access Control](#access-control)
- [Transactions](#transactions)
- [Taking Over the Request and the Response](#taking-over-the-request-and-the-response)
- [Multipart Forms](#multipart-forms)
- [Redirects](#redirects)
- [WebSocket Endpoints](#websocket-endpoints)
- [Error Handling](#error-handling)
- [Building the Router](#building-the-router)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomEndpoint` | annotation | Declares an HTTP endpoint inline on a method (route, methods, mime types, CORS, …) |
| `TomApiEndpointImplementation` | annotation | Binds a method to an endpoint defined in the remote-API registry |
| `TomService` / `tomService` | annotation | Marks a class as an interface-based service to scan |
| `TomApiImplementation` | annotation | Marks a class as the implementation of a registry-defined API |
| `TomComponentReference` | annotation | Points a service at its implementation bean (by name or type) |
| `TomTransactional` | annotation | Requests transaction wrapping for an endpoint method |
| `TomErrorHandler` / `TomDefaultErrorHandler` | class | Turns an error into a `Response` (default: opaque `500`) |
| `TomEndpointRouting` | class | Scans the annotated classes and builds the `Router` |
| `TomEndpointHandler` | class | Serves one endpoint (the per-request pipeline) |
| `TomMethodMetadata` / `TomClassScanResult` | class | Collected metadata / scan partitions |
| `TomEndpointHandlerException` / `TomEndpointPipelineException` | class | Serving-time / build-time failures |

## Declaring an Endpoint

Annotate a method on a `@tomService` class with `@TomEndpoint`:

```dart
@tomService
class GreetingService {
  @TomEndpoint(uri: '/greet', methods: [TomHttpMethod.post])
  GreetingResponse greet(GreetingRequest request) =>
      GreetingResponse('Hello, ${request.name}');
}
```

Every `TomEndpoint` field has a default (`GET`, JSON in/out, the default error
handler), so only the differing ones need to be supplied. Alternatively, an
endpoint declared centrally in the remote-API registry is bound with
`@TomApiEndpointImplementation(apiId: ..., endpointId: ...)` on a class
annotated `@TomApiImplementation(apiId: ...)`; the route details come from the
registry and the annotation only carries implementation-side overrides
(`errorHandler`, `logRequests`, CORS).

## Resolving the Implementation Instance

For each scanned service class, `initializeRouter` finds the instance to invoke:

1. a `@TomComponentReference` on the class (resolve the named/typed bean);
2. for API implementations, the bean for the class's own type;
3. for interface services, a component class that extends/implements the
   interface (its bean);
4. failing that, the component class's **default constructor**, with the result
   registered as its bean.

Step 4 is what lets the framework ship a service of its own. An endpoint that
arrives in the library barrel — the [file endpoint](file_storage.md#serving-a-file-over-http)
is the first — would otherwise break every existing `initializeRouter()` call
until each application registered a bean for a component it did not write. A
component with a no-argument constructor needs no application involvement, and
one that genuinely needs construction arguments still gets a bean the ordinary
way. A service that resolves to nothing at all now raises
`endpoint_pipeline.initialize_router.no_service_instance` naming the service,
rather than failing a null check.

## The Request Pipeline

`TomEndpointHandler.handleMethodCall` runs, in order:

1. answer CORS preflight (`OPTIONS`) early;
2. resolve principal/token/request-id from the current zone and run
   [access control](#access-control);
3. [bind the method parameters](#parameter-binding) by reflection;
4. optionally [start a transaction](#transactions);
5. invoke the method (awaiting a `Future` result);
6. commit (or roll back on error) and convert the result to a `Response`.

## Parameter Binding

For each declared parameter the handler tries, in order: a `TomPrincipal` or
`TomClientJwtToken` from the zone, the `Request` object itself, a value in the
request context keyed by type or by parameter name, a **primitive path
variable** (a shelf-matched `<name>` capture from `Request.params`, coerced to
the parameter's `String`/`num`/`bool` type by `coercePrimitiveParameter`), a
**primitive query-string value** (`?name=` from `Request.requestedUri`, coerced
the same way — this is how `GET /projects?workspaceId=` binds a bare
`String workspaceId`), a value from the `TomExecutionContext`, the JSON request
body (deserialised onto the parameter type via reflection, merged with path
params), and finally a `Map`-typed context entry. A parameter that cannot be
filled is logged and left unset.

## Access Control

`checkAccess` consults the method's `@TomAccessControl` (if any), otherwise the
global protection default. When access is denied and automatic endpoint
protection is enabled, `checkAutomaticAccess` gives a second chance based on
resource-key protection of the interface/API — honouring per-method
`-Interface.method` exceptions. A still-denied request throws
`TomEndpointHandlerException`.

## Transactions

When a method carries `@TomTransactional`, the handler starts a transaction
through `TomTransactionManager` before invoking it, commits on success, and
rolls back if the method throws.

## Taking Over the Request and the Response

Most endpoint methods take bound parameters and return a value the pipeline
serialises. Two escape hatches exist for the cases where that is the wrong
shape — a method that declares a shelf `Request` parameter receives the request
itself, and a method that returns a shelf `Response` has it used verbatim
instead of being serialised.

Together they are what makes streaming possible without a second pipeline: the
body is never read, so it is still a stream to pipe into storage, and the
response body is a stream the framework does not buffer. Declaring
`consumes: TomMimeType.octetStream` is the part that matters for the request
direction — the JSON body read only happens for a JSON `consumes`, so anything
else leaves the request stream intact for the method to consume.

```dart
@TomEndpoint(
  methods: [TomHttpMethod.post, TomHttpMethod.get],
  uri: '/files/{entity}/{id}/{column}',
  consumes: TomMimeType.octetStream,
  produces: TomMimeType.json,
)
Future<Response> file(Request request);
```

This is exactly how the [file endpoint](file_storage.md#serving-a-file-over-http)
is built; it is not a private arrangement.

## Multipart Forms

An endpoint that declares `consumes: TomMimeType.multipartFormData` has its
body decoded by the pipeline into a `TomMultipartForm` before any parameter is
bound — once per request, because a body is a single-pass stream.

The two halves of a form then reach two different places:

- **text parts** fold into the request DTO, beside the query and path values
  `injectQueryParameters` / `injectPathParameters` already fold in (form first,
  so an explicitly routed value always wins);
- **file parts** bind to method parameters: a `TomFormFile` parameter receives
  the part whose field name matches the *parameter* name, and a
  `TomMultipartForm` parameter receives the whole decoded form.

The split is not a style choice — a DTO is built through
`createInstanceFromJson`, which carries primitives and maps and cannot carry an
arbitrary object, so a file has nowhere to land inside one.

```dart
@TomEndpoint(
  methods: [TomHttpMethod.post],
  uri: '/documents',
  consumes: TomMimeType.multipartFormData,
  formFields: ['title', 'tags'],       // optional allow-list; see below
)
Future<DocumentResponse> create(
  DocumentRequest request,             // title, tags — from the text parts
  TomFormFile attachment,              // the part named "attachment"
);
```

`formFields` is an **allow-list, not a requirement**. Left empty (the default)
every text part folds into the DTO — a body is the endpoint's own contract,
just as a JSON body is. Non-empty, only the named fields are folded, which is
what an endpoint wants when the form is filled in by something it does not
control and would rather ignore the extra fields than absorb them.

The bytes reach the blob store through the very same `TomFileSlot` the raw-body
[file endpoint](file_storage.md#serving-a-file-over-http) uses — there is one
route from bytes to storage, and multipart takes it:

```dart
final stored = await attachment.storeIn('document', 'attachment', saved.id);
```

A multipart part must be **materialised** to be read (part N+1 is unreachable
until part N is drained), so each file part is buffered, and
`TomMultipartForm.globalSettingMaxFilePartBytes` (8 MiB) states the ceiling out
loud rather than letting a large upload discover it as an out-of-memory crash.
Bulk transfer belongs on the raw-body file endpoint, which streams and needs no
ceiling at all.

An endpoint that declares `consumes: TomMimeType.urlEncoded` gets the *other*
shape an HTML form takes — the one a browser sends when the form has no file
input. It decodes into the same `TomMultipartForm` (with no files), folds
through the same `formFields` allow-list, and binds identically; only the
reading differs. Which of the two a browser sends is decided by the form's
markup, not by anything the endpoint chooses, so the endpoint declares the one
its clients send.

## Redirects

A handler answers with a `3xx` by returning a `TomRedirect`; the pipeline turns
it into the `Response`:

```dart
@TomEndpoint(uri: '/documents/{id}/print')
Future<Object> print(String id) async =>
    TomRedirect.seeOther('/render/$id.pdf');
```

`TomRedirect.seeOther` (303), `.temporary` (307) and `.permanent` (308) name
the three that differ observably; 301/302 are omitted because they express the
same two intentions with method-rewriting behaviour left ambiguous across
clients.

This is a *directive*, not a hand-built `Response`, precisely because a
redirect is fully described by a status and a URL: a handler building its own
would re-derive those three facts and be free to get them wrong. The escape
hatch above stays for the case that genuinely needs it — a streamed body, which
only the handler can produce.

## WebSocket Endpoints

A socket is declared as a *kind of endpoint*, not served by a second server:

```dart
@tomService
class TickerService {
  @TomWebSocketEndpoint(uri: '/ws/ticker')
  @TomAccessControl(resourceKey: 'ticker')
  Future<void> ticker(TomWebSocketConnection socket, TomPrincipal who) async {
    socket.sendText('hello ${who.userName}');
    await for (final message in socket.messages) {
      socket.sendText('echo: $message');
    }
  }
}
```

`TomWebSocketEndpoint` implements the same `TomEndpointBase` the HTTP
annotations implement, which is what the scan already keys on — so a socket
endpoint is *discovered*, *authorized*, *parameter-bound* and *audited* by
exactly the code that does so for every other endpoint (`enforceAccess` and
`bindParameters`, shared with `handleMethodCall`). Only its mounting and its
lifecycle are its own.

What differs:

- the method is invoked **once per accepted connection**, not once per message,
  and the future it returns ends the conversation — the pipeline closes the
  socket when it completes (`1000` normally, `1011` after a throw);
- parameters are bound **before** the upgrade, so a binding failure is an
  ordinary HTTP error rather than a socket that opens and immediately dies;
- the request zone is captured at handshake time and the handler runs inside it
  (`Zone.run`), because the socket callback fires after the handshake response
  is finished and the zone carrying the `TomPrincipal`, the execution context
  and the request id would otherwise be gone — the same fix the streamed file
  download needed (bug D22);
- `@TomTransactional` is refused at mount time: a transaction cannot span a
  connection.

`protocols`, `allowedOrigins` and `pingInterval` are passed through to the
handshake. `allowedOrigins` is the handshake-time counterpart of CORS — the
`Origin` header is set by browsers and only by browsers, so it is what stops a
page on another site from opening an authenticated socket in a visitor's
session.

## Error Handling

Each endpoint has a `TomErrorHandler`. The pipeline calls
`handleInvocationError` when the method throws and `handleConversionError` when
serialising the result fails; both default to `handleErrorDefault`. The default
handler, `TomDefaultErrorHandler`, returns an opaque plain-text `500` so error
detail never leaks. If a handler itself throws, the pipeline raises a
`TomEndpointHandlerException` wrapping both errors.

## Building the Router

`TomEndpointRouting().initializeRouter()` (called by `TomServer`) scans the
reflected classes, mounts every endpoint method, and returns the shelf
`Router`. The mounted handlers and a uri→`TomEndpointRoutingInfo` map are kept
statically for diagnostics. Conflicting annotations (a class with both
`@tomService` and `@TomApiImplementation`, duplicate tags, a missing
`@TomApiImplementation` for a registry endpoint, or an unsupported HTTP method)
abort the build with `TomEndpointPipelineException`.

## Not Yet Implemented

- **A repeated text field cannot become a list.** Both form shapes keep the
  last value of a repeated field, the way a query string does, because a DTO
  field is one value. An endpoint that needs a repeated *text* field declares a
  JSON body, where a list is expressible. Changing this would mean deciding —
  per field, not per endpoint — when two values are one list and when they are a
  correction, which the envelope does not say.
- **Multipart parts are materialised.** A part must be buffered to be read, so
  `globalSettingMaxFilePartBytes` bounds it. Streaming a part lazily is not
  expressible over a sequential envelope; bulk transfer belongs on the raw-body
  [file endpoint](file_storage.md#serving-a-file-over-http), which streams.
- **A socket has no server-side push registry.** A handler owns its own
  connection and can write to it at any time, but there is no shared registry to
  broadcast to every connection of a user or a topic. That is a feature of
  whatever wants to broadcast, and inventing its addressing model before a
  caller has one would be guessing.

## Core Components

- **Annotations** (`endpoint_annotation.dart`) — `TomEndpoint`,
  `TomApiEndpointImplementation`, `TomService` / `tomService`,
  `TomApiImplementation`, `TomComponentReference`, `TomTransactional`,
  `TomErrorHandler` / `TomDefaultErrorHandler`, and the `TomEndpointBase`
  contract.
- **Pipeline** (`endpoint_pipeline.dart`) — `TomEndpointRouting` (scan + build),
  `TomEndpointHandler` (per-request serving), `TomMethodMetadata`,
  `TomClassScanResult`, `TomEndpointRoutingInfo`, and the two exception types.
- **File endpoint** (`file_endpoint.dart`) — `TomFileService` / `TomFileServer`,
  `TomFileEndpoint`, the `TomFileSlots` registry, and the `TomFormFile.storeIn`
  extension that joins an uploaded form part to a file slot; documented in
  [File Storage](file_storage.md#serving-a-file-over-http).
- **Form binding** (`form_binding.dart`) — `TomMultipartForm`, `TomFormFile`,
  `TomFormBindingException`, and the `tomConsumesForm` /
  `tomConsumesMultipartForm` predicates.
- **Results** (`endpoint_results.dart`) — `TomRedirect`.
- **WebSocket** (`web_socket_endpoint.dart`) — `TomWebSocketEndpoint`,
  `TomWebSocketConnection`, `TomWebSocketException`.

## Dependencies

- `shelf` / `shelf_router` — the HTTP `Request` / `Response` / `Router` types.
- `shelf_multipart` — decoding a `multipart/form-data` body into its parts.
- `shelf_web_socket` / `web_socket_channel` — the handshake upgrade and the
  channel a socket handler talks through.
- `tom_core_kernel` — `tomReflector` and the mirror types (annotation
  discovery, parameter binding, result conversion), `TomHttpMethod`,
  `TomMimeType`, `TomHeader`, `TomPrincipal`, `TomClientJwtToken`,
  `TomAccessControl`, `TomResourceKeyProtection`, `TomComponent`, `TomBean`,
  `tomRemoteApis` / `TomApi` / `TomApiEndpoint`, `TomExecutionContext`, `tomLog`.
- The server module — `TomRequestLogInfo`, `TomRequestId`.
- The transactions module — `TomTransactionManager` / `TomTransaction`.
