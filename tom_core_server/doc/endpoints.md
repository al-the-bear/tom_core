# Endpoints Module

Annotation-driven HTTP endpoints. You annotate service methods; at startup the
pipeline reflects over the annotated classes, mounts one `shelf` route per
endpoint, and — per request — enforces access, binds the method's parameters
from the request, optionally wraps the call in a transaction, invokes the
method, and converts the result (or any error) into a `Response`.

## Table of Contents

- [Overview](#overview)
- [Declaring an Endpoint](#declaring-an-endpoint)
  - [Which Methods May Be Declared](#which-methods-may-be-declared)
  - [Declared Response Headers](#declared-response-headers)
- [Resolving the Implementation Instance](#resolving-the-implementation-instance)
- [The Request Pipeline](#the-request-pipeline)
- [Parameter Binding](#parameter-binding)
  - [Parameters that cannot be filled](#parameters-that-cannot-be-filled)
- [Access Control](#access-control)
  - [A Denial Answers 404, and Says Nothing Else](#a-denial-answers-404-and-says-nothing-else)
  - [Which control to annotate with](#which-control-to-annotate-with)
  - [Automatic endpoint protection](#automatic-endpoint-protection)
- [Transactions](#transactions)
- [What a Handler May Return](#what-a-handler-may-return)
  - [An endpoint declaring `Future<void>` answers with no body](#an-endpoint-declaring-futurevoid-answers-with-no-body)
- [Taking Over the Request and the Response](#taking-over-the-request-and-the-response)
- [Multipart Forms](#multipart-forms)
- [Redirects](#redirects)
- [WebSocket Endpoints](#websocket-endpoints)
- [Request Logging](#request-logging)
  - [Who writes the line](#who-writes-the-line)
- [Error Handling](#error-handling)
- [Building the Router](#building-the-router)
  - [The Routing Table](#the-routing-table)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomEndpoint` | class | Declares an HTTP endpoint inline on a method (route, methods, mime types, CORS, …) |
| `TomApiEndpointImplementation` | class | Binds a method to an endpoint defined in the remote-API registry |
| `TomEndpointBase` | abstract class | What the two annotations above share: each can produce the concrete `TomEndpoint` the pipeline routes |
| `TomService` / `tomService` | annotation | Marks a class as an interface-based service to scan |
| `TomApiImplementation` | class | Marks a class as the implementation of a registry-defined API |
| `TomComponentReference` | class | Points a service at its implementation bean (by name or type) |
| `TomTransactional` | class | Requests transaction wrapping for an endpoint method |
| `TomErrorHandler` / `TomDefaultErrorHandler` | class | Turns an error into a `Response` (default: opaque `500`) |
| `TomEndpointRouting` | class | Scans the annotated classes and builds the `Router` |
| `TomEndpointHandler` | class | Serves one endpoint (the per-request pipeline) |
| `TomMethodMetadata` / `TomClassScanResult` | class | Collected metadata / scan partitions |
| `TomEndpointRouteKey` | typedef | `(uri, method)` — how `TomEndpointRouting` keys a mounted route, because one path may be divided between two endpoints |
| `TomEndpointRoutingInfo` | class | What is mounted at one such key: the handler, the endpoint it was built from, and the method this mount answers |
| `TomRedirect` | class | An endpoint result that answers `307` or `308`; `301`/`302` are omitted because their method-rewriting is ambiguous across clients |
| `TomEndpointHandlerException` / `TomEndpointPipelineException` | class | Serving-time / build-time failures |

Three concerns live in this module because each is a way of *serving a request*
rather than a subject of its own.

**Uploads over a raw body** — the whole request is the file and nothing is
buffered:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomFileSlots` / `TomFileSlot` | class | The reflection-derived `<table>/<column>` slot registry, and one registered slot; the interface is where the entity's `<T, K>` generics stop |
| `TomFileEndpoint` | class | The HTTP handler: POST / GET / HEAD / DELETE over a slot. Stateless — everything it needs is in the request and the registry |
| `TomFileService` / `TomFileServer` | service / component | Mounts that handler at `/files/{entity}/{id}/{column}`; one method for all four verbs, because the wire contract addresses one resource and varies only the method |
| `TomFileSlotException` | class | Slot registration and resolution errors. Registration failures are *scan-time*, which is the point of deriving slots from reflection |

**Uploads over a form** — for the request that carries a file *and* the fields
describing it, which a raw body cannot express:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomMultipartForm` | class | One decoded envelope: text parts for the request DTO, file parts for the handler's parameters |
| `TomFormFile` | class | One file part — field, client file name, media type. All three are the caller's word and none is trusted |
| `TomFormFileStorage` | extension | `TomFormFile.storeIn` — the join to the raw-body shape, through the *same* `TomFileSlot`, so exposure, row scope and column grade all apply unchanged |
| `tomConsumesForm` / `tomConsumesMultipartForm` | function | Whether an endpoint declares a form body, and whether specifically the multipart one — the pipeline needs to know which reader to call |
| `TomFormBindingException` | class | Always caused by what the caller sent, so it surfaces as a client error rather than an opaque `500` |

**WebSockets** — a handshake the same annotations can declare:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomWebSocketEndpoint` | class | Declares a socket endpoint; it answers `GET` and nothing else, because that is what a handshake is |
| `TomWebSocketConnection` | class | The live socket, attached at the moment the connection is accepted — so from inside a handler it is always live |
| `TomWebSocketException` | class | A socket endpoint declared or used in a way the pipeline cannot serve |

## Declaring an Endpoint

A service is **two** types: an annotated declaration carrying the
`@TomEndpoint` methods, and an annotated implementation carrying their bodies.

```dart
@tomReflector
@tomService
abstract class GreetingService {
  @TomPublicAccess()
  @TomEndpoint(uri: '/greet', methods: [TomHttpMethod.post])
  GreetingResponse greet(GreetingRequest request);
}

@tomReflector
@tomComponent
class GreetingServer implements GreetingService {
  @override
  GreetingResponse greet(GreetingRequest request) =>
      GreetingResponse('Hello, ${request.name}');
}
```

**Two types, not one, and the reason is mechanical.**
`findServiceInstance` matches an implementation to its service by *supertype* —
`superclass` or one of `superinterfaces` — and a class is not its own supertype.
So a single self-referential `@tomService @tomComponent` class is well-formed
Dart that resolves to no instance, and `initializeRouter` refuses it at start-up
with `endpoint_pipeline.initialize_router.no_service_instance`. The compiler
cannot warn about it: it checks neither the annotation set nor the instance
resolution.

`GreetingRequest` and `GreetingResponse` are ordinary `@tomReflector` classes
with a default constructor — that is all a DTO has to be, because the body is
bound and the result encoded by the same reflective field walk.

Every `TomEndpoint` field has a default (`GET`, JSON in/out, the default error
handler), so only the differing ones need to be supplied. `@TomPublicAccess()`
is shown because the pipeline's default is to *protect* a route; see
[Access Control](#access-control) for what an endpoint may declare instead.

Alternatively, an endpoint declared centrally in the remote-API registry is
bound with `@TomApiEndpointImplementation(apiId: ..., endpointId: ...)` on a
class annotated `@TomApiImplementation(apiId: ...)`; the route details come from
the registry and the annotation only carries implementation-side overrides
(`errorHandler`, `logRequests`, CORS).

> The pair above is compiled, mounted and served by the test suite — it is
> `GreetingService` / `GreetingServer` in `test/fixtures/reflection_fixture.dart`,
> kept verbatim identical to this snippet, and
> `test/endpoints_pipeline_test.dart` posts a body to `/greet` and reads the
> greeting back. For a scanned pipeline "it compiles" is only half the claim.

### Which Methods May Be Declared

`methods:` takes `TomHttpMethod` constants, and **nine of the ten are
declarable**:

| Constant | Mounted as |
| -------- | ---------- |
| `get` `post` `put` `patch` `delete` | the ordinary verbs |
| `head` `connect` `trace` | the same way, with no special handling |
| `all` | one registration answering every verb |

**`TomHttpMethod.options` is the exception, and cannot be declared.** Preflight
is not an endpoint's to serve: the pipeline registers `OPTIONS` on every route
itself — ordinary routes and WebSocket handshakes alike — and answers it in
`handleMethodCall` *before* access control, because a browser sends a preflight
unauthenticated and reads a `401` as "this request is not allowed". A declared
`OPTIONS` would be a second registration on a path that already has one, and
`shelf_router` dispatches to the first match, so it could never be reached.
Rather than mount something unreachable, the pipeline refuses at build time:

```text
endpoint_pipeline.initialize_router.invalid_http_method
Endpoint method OPTIONS/true invalid for <method>-<class>
```

That is a `TomEndpointPipelineException` from `initializeRouter()`, so it aborts
**startup** rather than one request — the whole route table is absent, not one
route. To vary what a preflight answers, use the three CORS fields on the
endpoint (`corsAllowedOrigins`, `corsAllowedMethods`, `corsAllowedHeaders`); to
change it globally, the `globalSettingCors…Default` statics. Declaring an
`OPTIONS` handler is not the way in.

Two consequences that are easy to meet by accident:

- **The constant is matched by identity, not by name.** `TomHttpMethod` has a
  public constructor and defines no value equality, so a `TomHttpMethod('GET')`
  built at runtime is a *different object* from `TomHttpMethod.get` and is
  refused with the same `invalid_http_method` error — reporting `GET` as
  invalid, which is not a sentence whose cause is easy to guess. Always name the
  constant.
- **A registry-declared endpoint obeys the same rule.** `TomApiEndpoint.method` /
  `.methods` become `TomEndpoint.methods` in `convertToTomEndpoint`, so the
  contract is not a way around the switch; an `OPTIONS` entry in the registry
  fails the same build.

`TomHttpMethod.all` needs no exemption. It mounts one registration matching
every verb, `OPTIONS` included, and the automatic preflight registration that
follows it is simply unreachable — both name the same handler, which answers a
preflight before it does anything else.

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

The body strategy is why a request DTO is **reflection-first**: it is filled by
`tomReflectionInfo.setValues`, so the type needs `@tomReflectable` and **plain
non-`final` members** — nothing else. A `final` member cannot be assigned after
construction, so a payload key naming one does not quietly land elsewhere, it
fails the request with
`reflection.set.unexpected_condition_final_static_private`. `final` members in
request and response classes are discouraged throughout Tom Core for that
reason; the pipeline inherits the rule rather than restating it, because
binding is the reflection module's contract and not a policy of its own.

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
protection on.

### A Denial Answers 404, and Says Nothing Else

A still-denied request is answered with a bare `404` — no body beyond
`Not found`, no `tomErrorEnvelope`, no error key, and the same response a route
that does not exist would give. The WebSocket handshake is refused the same way.

**Why not `403`.** `403` says "this exists and you may not have it", which is a
working oracle for a caller who was refused the data precisely so they could not
learn that. Walk the id space against a resource-key-protected endpoint and the
ids answering `403` are the rows that exist. The contract arm leaks the same way
one level up: a `403` on `/admin/users` tells an anonymous prober that this
deployment has an admin API and how it is spelled.

The body carries no error key for the same reason. An envelope naming
`access_denied` on a `404` undoes the whole of it in one field — the status
would say "nothing here" and the body would say "something here, and you may not
have it".

**Where the diagnosis goes.** Not away: the denial is audited unconditionally
(`TomAuditOutcome.denied`, with the principal, the endpoint and the reason) and
the exception's message reaches the server log. An operator asking "why did this
caller get a 404" has a record. The caller does not, which is the point.

The key the denial is raised and audited under is
`tomEndpointAccessDeniedErrorKey`
(`endpoint_handler.handle_method_call.access_denied`), exported so a deployment
writing its own refusal policy can name the one the pipeline raises.

This is **not** routed through the endpoint's `errorHandler`. Those hooks handle
errors *of the invocation* — a domain exception mapped to a `409`, a conversion
failure — and a handler written for one would be handed a security decision it
was not written for. A deployment that genuinely wants `403` returns one from
its own service code, deliberately, rather than inheriting it.

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
on — its default; `tom.protection.endpoint=false` switches it off — a denial
gets a second chance from `checkAutomaticAccess`, which grants access if the
principal holds the right resource key. It is only ever a second chance:
`enforceAccess` calls it after the ordinary check has already refused, so it can
raise a refusal to a grant, but a request the ordinary check allowed never
reaches it and a principal holding no relevant key keeps the decision it arrived
with.

It grants only while resource keys are enforced
(`TomResourceKeyProtection.globalSettingProtectionDefault`, off by default).
Without that, every key reads as held, and a second chance taken from them
would overturn every refusal the ordinary check made — a role requirement
included. So the switch being on by default opens nothing: it takes effect in a
deployment that has switched resource keys on and issued them.

A key is held as `TomAccessControlInformation.holdsResourceKey` defines it, so
`*` and `<api>.*` grants work here — and a `*` never covers a `-` revocation.

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

## What a Handler May Return

Whatever `tomReflectionInfo.convertToJsonString` accepts — which is the same
thing the framework's HTTP client sends, deliberately. A DTO of any shape the
reflection hooks recognise (`tom_core_kernel/doc/reflection/reflection.md`,
§ Serialization Hooks), a `List` of them, a `Map` with them inside, to any
depth. The
pipeline holds **no** serialization policy of its own: it hands the result to
that one entry point and encodes nothing itself.

That matters more than it sounds. When a transport restates the framework's
hook precedence, it becomes a second, quietly divergent copy of it — honouring
a set of hooks the client does not, so that a DTO round-trips over the client
and fails over an endpoint. Anything the pipeline cannot serialize is a gap in
the entry point, to be fixed there.

A `String` is the one thing passed through rather than serialized: a handler
returning one has already written the body, and encoding it again would wrap it
in quotes. `null` produces an empty body.

### An endpoint declaring `Future<void>` answers with no body

A method whose declared return type is `Future<void>` (or `void`) is answered
with an empty body whatever its implementation completes with. The declaration
decides, not the value that arrives — and it has to, because at runtime there is
no difference between the two cases.

`Future<void>` does not *erase* the value the future completes with, and Dart
permits an implementation to narrow the return type it overrides. So a method
declared

```dart
Future<void> deleteWorkspace(int id) => workspaceRepository.deleteById(id);
```

completes with the `int` that `TomRepository.deleteById` returns, invisible in
every static type between the two. Rendering it would be wrong twice over: the
client's typed proxy is generated from the same declaration and has nowhere to
put a body, and `int` carries no `@tomReflector`, so the attempt fails and a
successful delete is reported as an HTTP 500.

The declaration consulted is the one the `@TomEndpoint` annotation sits on — the
service interface's, where the endpoint is routed through one. That is the
contract the client is generated from, and it is the wider of the two
declarations whenever they differ, since narrowing is the only divergence Dart
allows.

This is a rule about *declared* absence only. An endpoint that declares a result
and returns something the converter cannot render still fails, loudly, because
there the failure is the whole story.

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
`[handleInvocationError by error handler]`, `[handleConversionError]`,
`[WebSocket handshake]` or `[WebSocket handshake refused]` — together with the
produced mime type and the encoding.

The socket exit is two exits because an upgrade leaves the pipeline two ways. A
**refused** one — no `Upgrade` header, an unoffered subprotocol, a cross-origin
request — is an ordinary response, and its line carries the status.
An **accepted** one ends in `Request.hijack`, which throws `HijackException` by
contract so that shelf can take the socket over, so it never returns a response
at all: its line is written from the `catch`, reports `upgraded` rather than a
status code shelf writes itself, and the exception is rethrown, because catching
it would leave shelf writing an ordinary reply over a socket the handshake has
already claimed.

The middleware adds nothing for an accepted upgrade even without the
`hasBeenLogged` flag, and for the same reason: it reads the response through a
`then`, and a hijack arrives as an error.

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
`@TomApiImplementation` for a registry endpoint, or an
[undeclarable HTTP method](#which-methods-may-be-declared)) abort the build with
`TomEndpointPipelineException`.

"Scans the reflected classes" is a precondition, not a description: the scan
resolves annotations through class mirrors, so your package's generated
`initializeReflection()` has to have run first. Miss it and the build does not
mount a route table with some routes absent — it throws
`Reflection has not been initialized` before mounting any of them.

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
no outward effect are out of scope for this list, so a limitation's absence from
it means "nothing a caller can see", not "nothing at all".

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

## Verification

Four suites cover this module, split by what each needs.

`test/endpoints_test.dart` covers the annotations and the pure functions:
`TomEndpoint`, `TomApiEndpointImplementation` and its merge, the class-level
annotations, `TomTransactional`, `TomDefaultErrorHandler`, the routing metadata
types, `shelfRoutePath`, and the four parameter injectors with
`coercePrimitiveParameter` beneath them.

`test/endpoints_pipeline_test.dart` runs the reflected pipeline for real:
scanning annotated classes, resolving access through `getClassMethodMetadata`
(C-12 / G-API-3), a contract-declared policy gating a live request, CORS
preflight, the HTTP methods an endpoint may declare, declared response headers,
the readme's own Quick start, the resource-key socket endpoint, and the
healthcheck module's `GET /health` route — which is mounted here rather than by
that module, and so is asserted here.

`test/endpoints_transport_test.dart` covers the three transports over the
pipeline: both form decoders (`TomMultipartForm.readForm` and
`readUrlEncodedForm`, plus `tomConsumesForm` and `injectFormFields`),
`TomRedirect`, and WebSockets — including a socket endpoint mounted alongside
the HTTP ones and served over a loopback server.

`test/endpoints_serialization_roundtrip_test.dart` asserts the one property a
DTO has to have: it crosses both directions identically.

```bash
dart run example/endpoints/endpoints_example.dart
```

`example/endpoints/endpoints_example.dart` runs everything that needs neither a
server nor a socket — the annotations, the default error handler's `Response`,
both form decoders on requests built in-process, and the file-slot registry. The
file-slot step needs generated reflection, which comes from
`example/example_reflection.dart`, the example suite's single reflection root
(regenerate with `./reflection_generation.sh`); its entities are declared in
`example/endpoints/endpoints_entities.dart`. Every step checks its own result,
and `test/examples_test.dart` runs it.

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

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `endpoint_pipeline.dart`, `file_endpoint.dart`, `web_socket_endpoint.dart` | `Future`, `Stream`, `StreamController`, `StreamSubscription`, `Zone`, `unawaited` |
| `dart:convert` | dart | `endpoint_annotation.dart`, `endpoint_pipeline.dart`, `file_endpoint.dart` | `Encoding`, `json`, `jsonDecode`, `jsonEncode` |
| `dart:typed_data` | dart | `form_binding.dart` | `Uint8List` |
| `shelf` | package | `endpoint_annotation.dart`, `endpoint_pipeline.dart`, `endpoint_results.dart`, `file_endpoint.dart`, `form_binding.dart` | the HTTP `Request` / `Response` / `Router` types |
| `shelf_multipart` | package | `form_binding.dart` | decoding a `multipart/form-data` body into its parts |
| `shelf_router` | package | `endpoint_pipeline.dart`, `file_endpoint.dart` | the HTTP `Request` / `Response` / `Router` types |
| `shelf_web_socket` | package | `endpoint_pipeline.dart` | the handshake upgrade and the channel a socket handler talks through |
| `tom_core_kernel` | package | every file | `tomReflector` and the mirror types (annotation discovery, parameter binding, result conversion), `TomHttpMethod`, `TomMimeType`, `TomHeader`, `TomPrincipal`, `TomClientJwtToken`, `TomAccessControl`, `TomResourceKeyProtection`, `TomComponent`, `TomBean`, `tomRemoteApis` / `TomApi` / `TomApiEndpoint`, `TomExecutionContext`, `tomLog` |
| `web_socket_channel` | package | `endpoint_pipeline.dart`, `web_socket_endpoint.dart` | the handshake upgrade and the channel a socket handler talks through |
| [audit](audit.md) | module | `endpoint_pipeline.dart` | `TomAuditAction`, `TomAuditOutcome`, `TomAuditTrail`, `TomAudited` |
| [file_storage](file_storage.md) | module | `file_endpoint.dart` | `TomStorageException`, `TomStoredBlob` |
| [little_things](little_things.md) | module | `endpoint_pipeline.dart`, `file_endpoint.dart`, `form_binding.dart`, `web_socket_endpoint.dart` | `TomServerException`, `TomRequestId` |
| [object_persistence](object_persistence.md) | module | `file_endpoint.dart` | `TomAnnotationAnalyzer`, `TomColumnAuthorizationException`, `TomColumnInformation`, `TomDataScopeAuthorizationException`, `TomDbTable`, `TomFileReference` |
| [server](server.md) | module | `endpoint_pipeline.dart` | `TomRequestLogInfo` |
| [transactions](transactions.md) | module | `endpoint_pipeline.dart` | `TomTransactionManager` / `TomTransaction` |
