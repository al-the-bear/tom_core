# Endpoints Module

Annotation-driven HTTP endpoints. You annotate service methods; at startup the
pipeline reflects over the annotated classes, mounts one [shelf] route per
endpoint, and — per request — enforces access, binds the method's parameters
from the request, optionally wraps the call in a transaction, invokes the
method, and converts the result (or any error) into a `Response`.

## Table of Contents

- [Overview](#overview)
- [Declaring an Endpoint](#declaring-an-endpoint)
  - [Declared Response Headers](#declared-response-headers)
- [Resolving the Implementation Instance](#resolving-the-implementation-instance)
- [The Request Pipeline](#the-request-pipeline)
- [Parameter Binding](#parameter-binding)
- [Access Control](#access-control)
- [Transactions](#transactions)
- [Taking Over the Request and the Response](#taking-over-the-request-and-the-response)
- [Multipart Forms](#multipart-forms)
- [Redirects](#redirects)
- [WebSocket Endpoints](#websocket-endpoints)
- [Request Logging](#request-logging)
- [Error Handling](#error-handling)
- [Building the Router](#building-the-router)
  - [The Routing Table](#the-routing-table)
- [Not Yet Implemented](#not-yet-implemented)
- [Core Components](#core-components)
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

### Declared Response Headers

An endpoint can declare headers the server adds to every response it produces —
alongside the `Content-Type` derived from `produces` and any
`contentDisposition`:

```dart
@TomEndpoint(uri: '/report', headers: {'x-report-version': '2'})
Future<Report> report() async => …;
```

`TomEndpoint.headers` is **outbound only**. The name is bare `headers` because
an endpoint declaration only ever speaks for the response: the pipeline copies
these onto the response and reads nothing from them. There is no field for
headers an endpoint *requires* of a request, and no request is rejected for
lacking one.

The registry-backed style states the two directions separately, and only one of
them is the server's business:

| Contract field | Direction | Where it goes |
| -------------- | --------- | ------------- |
| `TomApiEndpoint.responseHeaders` | server → client | becomes `TomEndpoint.headers`, so the response carries it |
| `TomApiEndpoint.requestHeaders` | client → server | read by `TomServerConnection` when a *client* calls the endpoint; the server reads it nowhere |

The distinction is easy to lose because getting it wrong stays well-formed: a
response that echoes the caller's own obligations back at it looks like a
deliberate acknowledgement rather than a mistake. So the two declaration styles
are held to the same statement — whichever way an endpoint is declared, its
response carries what was declared *for the response*, and nothing else.

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
params), and finally a `Map`-typed context entry.

### Parameters that cannot be filled

The result is a *positional* argument list, and a positional list has no way to
say "this one is absent" — leaving a parameter out does not leave it unset, it
shortens the list and moves every later argument one place to the left. Where
the shifted value happens to fit the earlier parameter's type, the method is
invoked successfully with the wrong argument in it and nothing reports that a
value was misplaced.

So the list is positionally faithful: entry *i* is the value of parameter *i*.
Exactly one shortening is legitimate — dropping **trailing optional**
parameters, which is how Dart applies their defaults. Everything else fails the
request with a `TomEndpointHandlerException` naming the parameter at fault:

| Key (under `endpoint_pipeline.bind_parameters.`) | Raised when |
| ------------------------------------------------ | ----------- |
| `unbindable_parameter` | A **required** parameter that no strategy could supply. |
| `unbindable_optional_parameter` | An **optional** parameter was not bound, but one *after* it was — omitting it would slide the later value into its slot. |
| `named_parameter_not_supported` | A **named** parameter was bound. Endpoint methods are invoked with positional arguments only, so declare it positionally instead. |

A named parameter that is *not* bound is simply absent and its default applies;
it holds no positional slot, so it can shift nothing.

## Access Control

An endpoint's policy can come from **two** places, and `getClassMethodMetadata`
resolves them in this order:

| Source | Written as | Applies |
| ------ | ---------- | ------- |
| The **handler** | a `TomAccessControl` annotation on the method | whenever present — the more local statement wins |
| The **contract** | `TomApiEndpoint.access` on the registry entry | when the handler declares none |

For a registry-backed endpoint that is the main path: the policy belongs on the
contract, and the inline annotation is an **override**, not the only way to
protect a method. Declare it once and every implementation of that contract is
checked against it without restating anything:

```dart
// The contract — registered before anything reflects over the implementation.
tomRemoteApis['reports'] = TomApi(
  id: 'reports',
  uri: '/reports',
  endpoints: [
    TomApiEndpoint<Object, Object>(
      id: 'listReports',
      uri: '/list',
      method: TomHttpMethod.get,
      access: TomRoleAccess(['analyst']),
    ),
  ],
);

// The implementation — no access annotation of its own.
@tomComponent
@TomApiImplementation(apiId: 'reports')
class ReportsApiService {
  @TomApiEndpointImplementation(apiId: 'reports', endpointId: 'listReports')
  Future<List<Report>> listReports() async => _store.recent();
}
```

`GET /reports/list` is gated by `TomRoleAccess(['analyst'])` although
`listReports` says nothing about access. Annotating the method — with the same
control or a different one — replaces the contract's policy for that endpoint
only; it never merges with it, so an override *widens* access as readily as it
narrows it.

An **inline** `@TomEndpoint` has no registry entry and therefore no contract
policy to inherit. It is governed by its own annotation, or by nothing.

`checkAccess` applies whichever control was resolved. When neither source
declares one it falls back to
`TomResourceKeyProtection.globalSettingProtectionDefault` — which is `false` by
default, so an undeclared endpoint is **open** until the deployment turns
protection on. A still-denied request throws `TomEndpointHandlerException` with
key `endpoint_handler.handle_method_call.access_denied`.

### Which control to annotate with

The scan matches on the abstract base — `tag is TomAccessControl` — so an
endpoint accepts *any* control in the family. `TomAccessControl` itself is
abstract and takes no arguments: it is what the pipeline tests for, never what
you write. Reach for the concrete subclass that names the intent:

| Intent | Annotation |
| ------ | ---------- |
| Anyone, including anonymous callers | `@TomPublicAccess()` |
| Any authenticated principal | `@TomAuthenticatedAccess()` |
| Guests (unauthenticated but admitted) | `@TomGuestAccess()` |
| Nobody — closed outright | `@TomNoAccess()` |
| **Protected by resource key** | `@TomResourceKeyAccess('<key>')` |
| A named role | `@TomRoleAccess(['<role>'])` |
| A named group | `@TomGroupAccess([...])` |
| A licensed feature | `@TomEntitlementAccess(['<pattern>'])` |
| A rule of your own | `@TomCustomAccess(handler: '<name>', resourceId: '<id>')` |

`TomCustomAccess.handler` is the **name** of a handler registered with
`TomCustomAccess.registerHandler(name, fn)`, not the function itself — an
annotation is a constant, so it can carry the name but not the closure.

`TomGradedAccess` is deliberately absent: its constructor is not `const`, so it
cannot be written as an annotation at all. It composes other controls into
read/disabled grades for field-level authorization, and is built in code.

Two wrinkles are worth knowing before you pick a control. The resource **key is
positional** — `@TomResourceKeyAccess('ticker')`, not a named argument — and
resource keys are not enforced at all while
`TomResourceKeyProtection.globalSettingProtectionDefault` is `false`, so a
resource-key endpoint serves everyone until the deployment turns protection on
and then starts refusing. That is the intended second operand, not a bug, but it
does mean the annotation looks inert in a permissive development setup.

Only one access annotation per method: a second one throws
`endpoint_pipeline.get_class_method_metadata.multiple_access_control`.

> Writing the abstract base by mistake is unusually easy to miss, because Dart
> reports `instantiate_abstract_class` for a `const` variable or an expression
> but **not** for metadata — `@TomAccessControl()` analyzes clean and gates
> nothing.

### Automatic endpoint protection

When `TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection` is
on — it is **off by default** — a denial gets a second chance from
`checkAutomaticAccess`, which grants access if the principal holds the right
resource key. It is only ever a second chance: `enforceAccess` calls it after
the ordinary check has already refused, so it can raise a refusal to a grant,
but a request the ordinary check allowed never reaches it and a principal
holding no relevant key keeps the decision it arrived with.

Every endpoint has **two** keys:

| Key | Grants |
| --- | ------ |
| `<container>` | every endpoint of the interface/API |
| `<container>.<member>` | that one endpoint |
| `-<container>.<member>` | *revokes* that one endpoint from a granted container |

The container/member **names** depend on how the endpoint is identified:

| Endpoint | Container | Member |
| -------- | --------- | ------ |
| Method with `@TomApiEndpointImplementation` | the API id (`<apiId>`) | `<apiId>.<endpointId>` |
| Any other endpoint | the Dart type it is routed through | `<Type>.<methodName>` |

Registry-backed endpoints key on the identity their **contract** declares, not
on the implementation class. That is the name the operator issuing keys has in
front of them, it is the name the client calls, and it survives a rename of the
implementation class — which a key already issued to a principal must.

The choice is made per **method**, not per class: a `@TomApiImplementation`
class may also carry plain `@TomEndpoint` methods, and those have no contract
entry, so they key on the class like any other endpoint. So a single class can
have some endpoints keyed on its API id and others on its type name.

Note the polarity of the revocation. Every key a principal holds is a *grant*,
`-<container>.<member>` included: the minus is part of the name of a revocation
the principal has been issued, not a negation of a test. Holding the container
key grants every member of it **unless** the matching `-<container>.<member>` is
also held.

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
abstract class TickerService {
  @TomWebSocketEndpoint(uri: '/ws/ticker')
  @TomResourceKeyAccess('ticker')
  Future<void> ticker(TomWebSocketConnection socket, TomPrincipal who);
}

@tomComponent
class TickerServer implements TickerService {
  @override
  Future<void> ticker(TomWebSocketConnection socket, TomPrincipal who) async {
    socket.sendText('hello ${who.username}');
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

## Request Logging

`TomEndpoint.logRequests` is **three-state**, and the third state is the point
of it:

| Value | Meaning |
| ----- | ------- |
| `true` | This endpoint's requests are logged. |
| `false` | They are not — however the global setting is configured. |
| `null` (the default) | Defer to `TomEndpointHandler.globalSettingLogRequestsDefault` (itself `true`). |

An endpoint that states nothing is the case the global setting exists to
govern, so the decision is computed once, per request, as
`logRequests ?? globalSettingLogRequestsDefault` and read through
`TomEndpointHandler.shouldLogRequests`. Every log statement in the pipeline
consults that getter — reading the annotation directly would collapse `null`
into `false` and make the setting inert for exactly the endpoints it is for.

A `@TomApiImplementation` sets the flag for its whole contract through
`logRequestsDefault`, which `convertToTomEndpoint` folds into each endpoint that
does not state its own. Registry-backed endpoints therefore arrive with a
non-null value; the `null` case is a plain `@TomEndpoint` method that omits the
argument.

### Who writes the line

The pipeline logs **once per exit**, and the line names the exit it came from —
`[Normal processing]`, `[handler-supplied response]`,
`[handleInvocationError by error handler]`, `[handleConversionError]`, or
`[WebSocket handshake]` — together with the produced mime type and the encoding.

`tomLoggingMiddleware` is the backstop. The pipeline publishes its decision on
the request's `TomRequestLogInfo` (`shouldBeLogged`) and records that it wrote
the line (`hasBeenLogged`); the middleware emits a single generic access-log
line only when the request *was* meant to be logged and nothing logged it — a
request that never reached an endpoint, for instance.

The two flags must therefore agree with what actually happened. Telling the
middleware `shouldBeLogged` while declining to log does not produce silence: it
produces the middleware's generic line instead of the pipeline's detailed one,
at the same line count. That is a degradation no request counter can see.

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
`Router`. The mounted handlers and a `TomEndpointRouteKey`→`TomEndpointRoutingInfo`
map are kept statically for diagnostics. Conflicting annotations (a class with
both `@tomService` and `@TomApiImplementation`, duplicate tags, a missing
`@TomApiImplementation` for a registry endpoint, or an unsupported HTTP method)
abort the build with `TomEndpointPipelineException`.

### The Routing Table

`TomEndpointRouting.routingInfo` is the diagnostic answer to "what is mounted
here?". It is keyed by **route and HTTP method** together — a
`TomEndpointRouteKey`, which is a record `({String uri, String method})`:

```dart
final entry = TomEndpointRouting.routingInfo[(uri: '/items', method: 'GET')];
```

`uri` is the route as *declared* (`/items/{id}`), not its `shelf_router`
translation, so an entry is looked up with the string that was written in the
annotation. `method` is the uppercase wire name (`TomHttpMethod.name`) rather
than the `TomHttpMethod` instance, because `TomHttpMethod` does not define value
equality.

A path alone does not identify a route, which is why the method is part of the
key:

| Declaration | Entries |
| ----------- | ------- |
| `methods: [get, put, delete]` on one endpoint | three, sharing one handler |
| `get` on one endpoint and `post` on another, same `uri` | two, with different handlers |
| `@TomWebSocketEndpoint` | one, under `GET` — a handshake is a GET |

Each `TomEndpointRoutingInfo` names the single `method` it stands for alongside
the `endpoint` that declares them all, so enumerating `routingInfo.values` is a
complete picture without consulting the keys.

Only **declared** methods are listed. Every route also gets an automatic
`OPTIONS` registration for CORS preflight; that is framework plumbing rather
than part of an endpoint's surface, and recording it would add one entry per
route saying something that holds for every route.

The table is a diagnostic, not the router — the router is authoritative about
what is served, and it is keyed by method already.

## Not Yet Implemented

Every limitation below has a consequence a caller can observe — a value that
never arrives, a request that is not rejected, an audit trail thinner than it
looks. It is not a survey of everything unfinished inside the module: edges with
no outward effect are tracked with the quest rather than here, so a limitation's
absence from this list means "nothing a caller can see", not "nothing at all".

- **An unmapped query parameter is dropped in silence.** A path capture binds
  under its own name whether or not `urlParameterMapping` names it; a query
  parameter binds **only** when the map names it, and nothing warns about one it
  does not. An endpoint expecting `?token=…` with an empty mapping therefore
  receives a request DTO without it — or, when the route captures nothing at
  all, no DTO and an argument-count failure that names neither the parameter nor
  the query string.
- **A URL value that will not parse falls through rather than failing.**
  `coercePrimitiveParameter` answers `null` both for "this type is not a
  primitive" and for "this primitive would not parse", and its caller cannot
  tell the two apart. So `?count=abc` on an `int` parameter is not a 400: it
  reads as "not bindable this way", the next binding strategy is tried, and
  whatever fails last is what the client is told about.
- **`bool` accepts exactly one spelling.** Coercion is `raw == 'true'`, so
  `?flag=1`, `?flag=yes` and `?flag=TRUE` all arrive as `false` rather than as
  an error. An endpoint that must tell "false" from "not a boolean" takes the
  value as a `String` and parses it itself.
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
- **`TomFileSlots` is a process-wide registry.** The map of exposed file columns
  is static, so it is scoped to the *process* rather than to a repository or a
  server: two isolates serving the same entity each register their own copy, and
  `TomFileSlots.reset()` exists for tests that want a fresh registry, not for
  re-registration at runtime.
- **A socket has no server-side push registry.** A handler owns its own
  connection and can write to it at any time, but there is no shared registry to
  broadcast to every connection of a user or a topic. That is a feature of
  whatever wants to broadcast, and inventing its addressing model before a
  caller has one would be guessing.
- **A socket is audited at its ends only.** `handleWebSocketCall` records one
  entry when the connection is accepted and — only if the handler throws — one
  when it fails; nothing during the conversation and nothing on a clean close.
  An hour-long session is therefore one audit entry, and what was said inside it
  is the handler's own to record.
- **`TomErrorHandler` receives the stack trace as `Object`.**
  `handleErrorDefault` — the one method a concrete handler must implement — and
  the three hooks that delegate to it all declare `Object stacktrace`, so an
  implementation that wants to walk the trace casts it to `StackTrace` first.
  The value the pipeline passes always is one.

## Core Components

- **Annotations** (`endpoint_annotation.dart`) — `TomEndpoint`,
  `TomApiEndpointImplementation`, `TomService` / `tomService`,
  `TomApiImplementation`, `TomComponentReference`, `TomTransactional`,
  `TomErrorHandler` / `TomDefaultErrorHandler`, and the `TomEndpointBase`
  contract.
- **Pipeline** (`endpoint_pipeline.dart`) — `TomEndpointRouting` (scan + build),
  `TomEndpointHandler` (per-request serving), `TomMethodMetadata`,
  `TomClassScanResult`, `TomEndpointRouteKey` / `TomEndpointRoutingInfo`, and the
  two exception types.
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
