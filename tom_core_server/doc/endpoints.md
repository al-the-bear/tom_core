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
- [Versioned APIs](#versioned-apis)
- [Resolving the Implementation Instance](#resolving-the-implementation-instance)
- [The Request Pipeline](#the-request-pipeline)
- [Parameter Binding](#parameter-binding)
  - [Binding a Query Parameter](#binding-a-query-parameter)
  - [Parameters that cannot be filled](#parameters-that-cannot-be-filled)
- [Access Control](#access-control)
  - [A Denial Answers 404, and Says Nothing Else](#a-denial-answers-404-and-says-nothing-else)
  - [Which control to annotate with](#which-control-to-annotate-with)
  - [Automatic endpoint protection](#automatic-endpoint-protection)
- [CORS](#cors)
  - [Which origins may read a response](#which-origins-may-read-a-response)
  - [An endpoint's own origins](#an-endpoints-own-origins)
  - [The `cors` key](#the-cors-key)
- [Transactions](#transactions)
- [Idempotency Keys](#idempotency-keys)
  - [Opting in](#opting-in)
  - [Sending a key](#sending-a-key)
  - [What a request with a key gets](#what-a-request-with-a-key-gets)
  - [What is stored](#what-is-stored)
  - [Retention and abandoned claims](#retention-and-abandoned-claims)
  - [Stores, clusters and tenants](#stores-clusters-and-tenants)
  - [Configuration](#configuration)
- [What a Handler May Return](#what-a-handler-may-return)
  - [An endpoint declaring `Future<void>` answers with no body](#an-endpoint-declaring-futurevoid-answers-with-no-body)
  - ["No such thing" is an error key, not a `null`](#no-such-thing-is-an-error-key-not-a-null)
- [Taking Over the Request and the Response](#taking-over-the-request-and-the-response)
- [Multipart Forms](#multipart-forms)
- [Redirects](#redirects)
- [WebSocket Endpoints](#websocket-endpoints)
  - [One request id per message](#one-request-id-per-message)
  - [What the trail says about a socket](#what-the-trail-says-about-a-socket)
- [The OpenAPI Document](#the-openapi-document)
- [Request Logging](#request-logging)
  - [Who writes the line](#who-writes-the-line)
- [Error Handling](#error-handling)
  - [Error Formats and problem+json](#error-formats-and-problemjson)
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
| `TomService` / `tomService` | class / const TomService | Marks a class as an interface-based service to scan; `version:` serves its inline endpoints under a `/v<version>` segment, `problemJson:` answers their errors as problem documents |
| `TomApiImplementation` | class | Marks a class as the implementation of a registry-defined API |
| `TomComponentReference` | class | Points a service at its implementation bean (by name or type) |
| `TomTransactional` | class | Requests transaction wrapping for an endpoint method |
| `TomErrorHandler` / `TomStatusMappingErrorHandler` / `TomDefaultErrorHandler` | abstract classes / class | Turns an error into a `Response`: the framework envelope — or an RFC 9457 problem document when the request asks for one — at the status the error key is declared to mean (default: `500` for every key) |
| `TomEndpointRouting` | class | Scans the annotated classes and builds the `Router` |
| `TomEndpointHandler` | class | Serves one endpoint (the per-request pipeline) |
| `TomMethodMetadata` / `TomClassScanResult` | class | Collected metadata / scan partitions |
| `TomEndpointRouteKey` | typedef | `(uri, method)` — how `TomEndpointRouting` keys a mounted route, because one path may be divided between two endpoints |
| `TomEndpointRoutingInfo` | class | What is mounted at one such key: the handler, the endpoint it was built from, and the method this mount answers |
| `TomRedirect` | class | An endpoint result that answers `307` or `308`; `301`/`302` are omitted because their method-rewriting is ambiguous across clients |
| `TomEndpointHandlerException` / `TomEndpointPipelineException` | class | Serving-time / build-time failures |
| `TomCors` | final class | Which browser origins may read a response: an allow-list, empty by default. `current` is the one the pipeline applies, set by `configure` from the `cors` key |
| `TomCorsException` | class | The `cors` settings cannot be applied — `endpoint.cors.config.invalid` |

Five concerns live in this module because each is a way of *serving a request*
rather than a subject of its own.

**Uploads over a raw body** — the whole request is the file and nothing is
buffered:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomFileSlots` / `TomFileSlot` | class / abstract class | The reflection-derived `<table>/<column>` slot registry, and one registered slot; the interface is where the entity's `<T, K>` generics stop |
| `TomFileEndpoint` | class | The HTTP handler: POST / GET / HEAD / DELETE over a slot. Stateless — everything it needs is in the request and the registry |
| `TomFileService` / `TomFileServer` | abstract class / class | Mounts that handler at `/files/{entity}/{id}/{column}`; one method for all four verbs, because the wire contract addresses one resource and varies only the method |
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

**The OpenAPI document** — the server's own description, generated by the build
and served as a file:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomOpenApiService` | abstract class | The public route contract: `GET /openapi.json` |
| `TomOpenApiServer` | class | Serves the file `globalSettingDocumentPath` names, read on every request; `404` with the error envelope (or a problem document, when asked) when none is configured or the file is missing |

**Idempotency keys** — a retried request answered with the first one's stored
response instead of running again:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomIdempotent` | class | Method annotation: requests to the endpoint may carry an `Idempotency-Key`; optional `retention` |
| `TomIdempotency` | abstract final class | The isolate's settings — header names, store, retention, in-progress timeout, clock — and `handle`, which answers one request. Statics only |
| `TomIdempotencyStore` | abstract class | Where records are kept: `claim`, `complete`, `release`, `purgeExpired` |
| `TomMemoryIdempotencyStore` / `TomSqlIdempotencyStore` | class | The records of one process, in memory (the default); the records in a SQL table, shared by every instance |
| `TomIdempotencyScope` / `TomIdempotencyRecord` / `TomIdempotencyClaim` | class | Whose key it is and for which operation; a stored request and its response; the outcome of a claim |
| `TomIdempotencyRow` | class | One row of the table, as the SQL store reads it |
| `TomIdempotencyException` | class | A key that cannot be used, a store without its data source, or a configuration of the wrong shape |
| `idempotencyTable` / `idempotencyTableDdl` / `defaultIdempotencyTable` | function / function / const String | The table's single declaration, its DDL, and its default name `tom_idempotency_key` |

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
change it for every endpoint, the `cors` configuration key (see [CORS](#cors)).
Declaring an `OPTIONS` handler is not the way in.

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
Future<Report> report() async { ... }
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

## Versioned APIs

An API carries a **major version as a path segment**: version 2 of `/orders` is
served at `/v2/orders`. A path segment rather than a header or a media type,
because it is what a log line, a cache key and an OpenAPI document all show.
Two versions of one API are therefore two APIs, mounted side by side, each with
its own endpoints — a client that has not moved on keeps calling the old one.

For an inline service the version is on the class annotation:

```dart
@tomReflector
@TomService(version: 2, problemJson: true)
abstract class OrderApi {
  @TomPublicAccess()
  @TomEndpoint(uri: '/orders')
  Future<Map<String, Object>> orders();
}
```

It is paired with a `@tomComponent` implementation like any service.
`initializeRouter` mounts `GET /v2/orders`; a second service declared
`@TomService(version: 1)` with the same `@TomEndpoint(uri: '/orders')` mounts
`GET /v1/orders` beside it, and nothing is mounted at `/orders`. The declared `uri` stays unversioned, and the scan places
each endpoint under its segment (`TomEndpoint.withUri`), so the route table
(`TomEndpointRouting.routingInfo`) is keyed by the mounted route,
`/v2/orders`. A service without a version keeps its URIs as declared.

A registry-backed API is versioned where it is declared, by `TomApi.version`:
its `TomApi.path` is `/v<version>` followed by its `uri`, and every endpoint's
`TomApiEndpoint.path` — the route `convertToTomEndpoint` mounts and the address
`resolveUri` builds for a client — starts with it. The client and the server
read one declaration, so they cannot disagree about the segment. Such a class's
`@TomApiImplementation` therefore takes no version of its own.

Both mistakes abort the build with `TomEndpointPipelineException` under
`endpoint_pipeline.get_class_method_metadata.invalid_api_version` (parameters
`service` and `version`): a version below 1 on a `@TomService`, and any version
on a `TomApiImplementation` — which `@TomApiImplementation` cannot express, but a
subclass of it could. A registry `TomApi` with a version below 1 is refused when
it is constructed, with `apis.version.invalid`.

`problemJson: true` on either annotation answers the errors of the service's
endpoints as RFC 9457 problem documents whatever the request's `Accept` says —
see [Error Formats and problem+json](#error-formats-and-problemjson). It changes
nothing about a successful answer.

> The pair is `FixtureOrdersV1` / `FixtureOrdersV2` in
> `test/fixtures/reflection_fixture.dart`, which `test/api_versioning_test.dart`
> mounts side by side and serves.

## Resolving the Implementation Instance

For each scanned service class, `initializeRouter` finds the instance to invoke:

1. a `@TomComponentReference` on the class (resolve the named/typed bean). It
   names its bean by `componentName` or by `referencedType`, exactly one of
   them: neither is `endpoint_pipeline.initialize_router.component_reference_invalid`,
   both is `endpoint_pipeline.initialize_router.component_reference_invalid_both_set`,
   and a second reference on one class is
   `endpoint_pipeline.initialize_router.multiple_component_references`;
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

1. answer CORS preflight (`OPTIONS`) early — `204` with the headers
   [`TomCors`](#cors) grants the request's origin;
2. resolve principal/token/request-id from the current zone and run
   [access control](#access-control);
3. [bind the method parameters](#parameter-binding) by reflection;
4. optionally [start a transaction](#transactions);
5. invoke the method (awaiting a `Future` result);
6. commit (or roll back on error) and convert the result to a `Response`;
7. add the `Access-Control-Allow-Origin` `TomCors` grants the request's origin
   to that response, unless the handler set one itself — none for an origin it
   does not admit.

Step 7 is the half of CORS a preflight cannot do. A preflight tells the browser
it may *send* the request; the browser then hands the response to the page only
if that response names the allowed origin too. So every response an endpoint
returns carries the same origin its preflight announced — an error response
included, since a refusal the page cannot read reaches the user as a network
error rather than as the reason. See [CORS](#cors) for which origins are
admitted.

**A `GET` or `HEAD` request is read-only work.** Such a request runs through
the pipeline inside `TomReplicaRouting.readOnly`, so the repository reads it
makes may be served by a data source's read replicas (see
[Read Replicas](datasources.md#read-replicas)). A safe method is the client's
promise that the request changes nothing, and that is the promise a replica's
lag is safe under. The rest still holds: a transaction the endpoint starts
decides for itself — everything inside a write transaction reads the primary —
a principal who has just written reads the primary for the data source's
`replicaStickinessMs`, and an entity marked `@TomPrimaryReads` is always read
from the primary. A deployment whose `GET` endpoints write sets
`TomReplicaRouting.routeSafeRequests = false`; its requests then read the
primary unless a handler marks read-only work itself. An `@TomIdempotent`
endpoint is answered through `TomIdempotency.handle` and is not marked.

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

**A `bool` accepts eight spellings, and nothing else.** `true` / `false`,
`1` / `0`, `yes` / `no`, `on` / `off`, matched case-insensitively — four shapes
because four is what clients send: `true` from a JSON-shaped caller, `1` from a
form and from most hand-written query strings, `on` from an HTML checkbox, `yes`
from a human. Anything outside the set is *unparsable*, and refused like any
other unparsable value.

That last part is the point. The rule was `raw == 'true'`, which is **total**:
every other spelling produced `false`, so `?active=TRUE` meant the opposite of
what the caller wrote and no layer could notice. A number at least answers
"unparsable" for nonsense; a boolean always produced a usable value. So a `bool`
is the one primitive whose failure was invisible, and closing the set is what
makes `false` an answer rather than also the way the framework says "I did not
understand you". Note that an empty value (`?flag=`) is unparsable too: a
present-but-blank flag states nothing. An HTML checkbox that is *unchecked*
sends no field at all, which is absence rather than `false` — a handler that
needs a default declares the parameter optional.

A URL value that will not parse is a **client error, not a missed strategy**.
`coercePrimitiveParameter` answers `null` for two conditions that are different
answers — a `Request` parameter, which is no primitive at all and should fall
through to the next strategy, and `?count=abc` on an `int`, which no later
strategy can repair — and one `null` cannot carry both. `isBindablePrimitive` is
asked first, so past it a `null` means the value did not parse, and the request
is refused by `endpoint_pipeline.bind_parameters.unparsable_url_value` naming
the parameter, the type, the source (path variable or query parameter) and the
value. Falling through instead ended
with the parameter unbound and `unbindable_parameter`, which says only that
nothing could supply it — the one diagnosis that names neither the value nor the
fact that it was nearly right, produced from the one case where the client is
the party who can fix it.

The body strategy is why a request DTO is **reflection-first**: it is filled by
`tomReflectionInfo.setValues`, so the type needs `@tomReflectable` and **plain
non-`final` members** — nothing else. A `final` member cannot be assigned after
construction, so a payload key naming one does not quietly land elsewhere, it
fails the request — as
`endpoint_pipeline.handle_method_call.parameter_instantiation_failed`, with the
reflection module's `reflection.set.unexpected_condition_final_static_private`
as its root cause. `final` members in
request and response classes are discouraged throughout Tom Core for that
reason; the pipeline inherits the rule rather than restating it, because
binding is the reflection module's contract and not a policy of its own.

Every way the body and context routes can fail has a key of its own, so the
reflection error behind a failure travels as its root cause rather than being
the only name for it:

| Key | Raised when |
| --- | ----------- |
| `endpoint_pipeline.handle_method_call.request_body_not_json` | the body is not JSON, or decodes to something other than an object |
| `endpoint_pipeline.handle_method_call.parameter_instantiation_failed` | the body decoded, and building the parameter from it threw |
| `endpoint_pipeline.handle_method_call.parameter_instantiation_invalid_type_in_context` | the request context holds an entry under the parameter's name that is neither of its type nor a map |
| `endpoint_pipeline.handle_method_call.parameter_instantiation_from_context_failed` | building the parameter from that context map threw |
| `endpoint_pipeline.handle_method_call.parameter_instantiation_general_failure` | any other failure while binding the parameter |

### Binding a Query Parameter

A query value reaches a handler by one of two routes, and they are not
alternatives to each other:

| The handler declares | Bound by | Needs `urlParameterMapping`? |
| -------------------- | -------- | ---------------------------- |
| a bare `String` / `num` / `bool` parameter | the primitive query strategy, by the parameter's own name | no |
| a field of a request DTO | `injectQueryParameters`, under the mapped field name | **yes**, per parameter |

The DTO route is opt-in and the path route is not, which is the module's most
mistakable asymmetry. A path capture binds under its own name whether or not
`urlParameterMapping` names it, so an empty map still binds every path
parameter; a query parameter binds into a DTO **only** when the map names it.
The reason is whose statement the value is. A route is part of the endpoint's
own declaration, so binding a capture by its own name is safe; a query string is
whatever a caller chose to append, so an identity fallback would let any caller
write any field of any request DTO — `?isAdmin=true` reaching a field the
endpoint never meant to expose.

**The opt-in stays; the silence does not.** A parameter that no mapping names
and no handler parameter declares is dropped and reported at **debug**, naming
the endpoint and the parameter names. Debug rather than a `400`, because a
public URL collects `utm_source` and `gclid` whether the endpoint wants them or
not, and rejecting the request would break every caller that appends one; debug
rather than nothing, because the failure it replaces is expensive to find — a
client sends `?status=open`, gets a `200` computed as though it had not, and
nobody is told: the author sees a working request, the caller sees an ignored
filter, and no log connects them.

Two things the line deliberately does not do. It never logs **values** — a query
string is where `?code=…&state=…` arrives on an OAuth callback, and a log at a
level people leave on in development is the last place a credential should
reach; the name alone is the whole diagnosis. And it excludes the names the
handler declares as its own parameters, because those bind by the primitive
route above: a diagnostic that fires on the documented case teaches its reader
to skip the line that matters.

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

| Key | Raised when |
| --- | ----------- |
| `endpoint_pipeline.bind_parameters.unparsable_url_value` | A **path variable or query value** whose parameter is a primitive the value will not parse as — `/items/abc` or `?count=abc` on an `int`. Names the parameter, the type, the source and the offending value. |
| `endpoint_pipeline.bind_parameters.unbindable_parameter` | A **required** parameter that no strategy could supply. |
| `endpoint_pipeline.bind_parameters.unbindable_optional_parameter` | An **optional** parameter was not bound, but one *after* it was — omitting it would slide the later value into its slot. |
| `endpoint_pipeline.bind_parameters.named_parameter_not_supported` | A **named** parameter was bound. Endpoint methods are invoked with positional arguments only, so declare it positionally instead. |

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

## CORS

### Which origins may read a response

`TomCors` decides which browser origins may call the server. It is an
allow-list, and **empty by default**: until a deployment lists its client
origins, no cross-origin page may read a response. A request from the server's
own origin, or from a client that is not a browser — another server, a mobile
app, `curl` — is unaffected either way, because the restriction is the browser's
and only a browser enforces it.

A request whose `Origin` is on `TomCors.current`'s `allowedOrigins` is answered
with `Access-Control-Allow-Origin: <that origin>` and `Vary: Origin`; any other
origin gets no such header, and the browser withholds the response from the
page. The pipeline applies the policy in two places: `handlePreflight` answers
an `OPTIONS` preflight `204` with `Access-Control-Allow-Origin`, the
`Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` the policy
admits and `Access-Control-Max-Age`, and `withAllowedOrigin` puts the origin on
every response the endpoint returns, an error included (see
[The Request Pipeline](#the-request-pipeline)). Both read `TomCors.current` per
request, so a changed policy reaches routes that are already mounted.

An entry of `allowedOrigins` takes one of three forms:

| Entry | Admits |
| ----- | ------ |
| `https://app.example.com` | exactly that origin |
| `http://localhost:*` | that scheme and host on any port — what a development client on a port of its own needs |
| `*` | every origin, answered as `*` rather than as the caller's origin |

`*` cannot be combined with `allowCredentials`: browsers refuse credentials
with `*` anyway, so the combination is refused when it is configured rather than
when a browser meets it. With `allowCredentials` on, an admitted origin is
answered with `Access-Control-Allow-Credentials: true`, which a browser needs
before it sends cookies cross-origin — the session cookie among them (see
[authentication.md](authentication.md#browser-sessions-in-a-cookie)).

`TomCors.admits(origin)` answers the same question for other callers: the
session cookie's CSRF check accepts a cookie-authenticated request from an
origin the policy admits.

### An endpoint's own origins

An endpoint may state its own policy with the three fields every endpoint
annotation carries. `corsAllowedOrigins` is a comma-separated list in the same
three forms and **replaces** the configured list for that endpoint — the
configured origins are not admitted there; `corsAllowedMethods` and
`corsAllowedHeaders` replace what its preflight answers. A field left `null`
falls back to the policy:

```dart
@TomPublicAccess()
@TomEndpoint(
  methods: [TomHttpMethod.get],
  uri: '/fixture/cors_origin',
  produces: TomMimeType.json,
  corsAllowedOrigins: 'https://origin.example.com',
  logRequests: false,
)
Future<Map<String, Object>> corsOrigin();
```

The declaration is `corsOrigin` in `test/fixtures/reflection_fixture.dart`,
which `test/endpoints_pipeline_test.dart` serves: the origin it names is
admitted there, the policy's own origin is not, and its preflight still answers
the policy's methods and headers.

### The `cors` key

The policy is the `cors` key of the server configuration
(`TomCors.configurationKey`), applied at start by `TomServer.configureSecurity`:

```yaml
cors:
  allowedOrigins: [https://app.example.com, http://localhost:*]
  allowedMethods: GET, POST, PUT, PATCH, DELETE, HEAD
  allowedHeaders: Origin, Content-Type, Accept, Authorization
  allowCredentials: false
  maxAgeSeconds: 600
```

| Setting | Default | Effect |
| ------- | ------- | ------ |
| `allowedOrigins` | none | The origins admitted, in the forms above |
| `allowedMethods` | `GET, POST, PUT, PATCH, DELETE, HEAD` (`TomCors.defaultAllowedMethods`) | The methods a preflight admits |
| `allowedHeaders` | `Origin, Content-Type, Accept, Authorization, X-API-Key, X-CSRF-Token, X-Request-Id, Idempotency-Key, traceparent, tracestate` (`TomCors.defaultAllowedHeaders`) | The request headers a preflight admits — by default what the framework's own clients send |
| `allowCredentials` | `false` | Whether a browser may send cookies cross-origin |
| `maxAgeSeconds` | `600` | How long a browser may cache a preflight answer |

`TomCors.configure` checks the whole value before applying any of it:

| Key | Raised when |
| --- | ----------- |
| `endpoint.cors.config.invalid` | The value is not a map, has an unknown key, an origin that is neither `*` nor `scheme://host` (optionally with `:port` or `:*`), `*` together with `allowCredentials`, a negative or non-integer `maxAgeSeconds`, or methods or headers that are not a comma-separated string. Raised by `TomCors.configure` as a `TomCorsException`; it stops the start. |

The sample servers list `http://localhost:*` and `http://127.0.0.1:*` in their
development configuration, because their Flutter web clients run on a local port
of their own — a different origin. A deployment lists its real client origins
instead. A test or an embedding application sets `TomCors.current` directly.

## Transactions

When a method carries `@TomTransactional`, the handler starts a transaction
through `TomTransactionManager` before invoking it, commits on success, and
rolls back if the method throws. The handler does not enlist anything: every
data source the method uses enlists itself on its first statement (see
[transactions](transactions.md)), which is the only way the pipeline could know
what the method touched.

`@TomTransactional(isReadOnly: true)` opens a read-only transaction, which is
read-only work for read-replica routing: its repository reads may be served by
a replica, all of them by the same one so they read one snapshot. A write
transaction keeps every statement on the primary, in a `GET` request too.

A commit that does not commit fails the request, whatever the method returned.
When a participant vetoes, or commits only in part, the handler raises
`TomTransactionException` with the key
`endpoint_pipeline.handle_method_call.commit_failed`, carrying the `outcome`
and the `failed` participants as parameters. It goes to the endpoint's error
handler like any other failure; the coordinator has already concluded the
transaction, so nothing is rolled back a second time.

## Idempotency Keys

A client that sends a request and loses the answer — a timeout, a dropped
connection, a load balancer that gave up — cannot know whether the server
acted. Retrying a `GET` is harmless; retrying "place an order" places a second
order. An endpoint annotated `@TomIdempotent` makes that retry safe: the client
sends an `Idempotency-Key` header, the server stores the first request's
response under the key, and answers a retry with the stored response without
running the method again.

### Opting in

Idempotency is per endpoint and off unless declared. `@TomIdempotent()` goes on
the method beside `@TomEndpoint`:

```dart
@tomReflector
@tomService
abstract class OrderApi {
  @TomAuthenticatedAccess()
  @TomIdempotent()
  @TomEndpoint(methods: [TomHttpMethod.post], uri: '/orders')
  Future<OrderDto> placeOrder(PlaceOrderDto order);

  @TomAuthenticatedAccess()
  @TomIdempotent(retention: Duration(hours: 2))
  @TomEndpoint(methods: [TomHttpMethod.post], uri: '/payments')
  Future<PaymentDto> pay(PaymentDto payment);
}
```

`retention` overrides how long the stored response is replayed for this
endpoint; without it the deployment's default applies (24 hours). A method
carrying two `@TomIdempotent` annotations stops the router build with
`endpoint_pipeline.get_class_method_metadata.multiple_idempotent_tags`.

The annotation is collected into `TomMethodMetadata.idempotent`, and the
handler runs every request of the endpoint through `TomIdempotency.handle`,
which wraps everything the handler does for it: the access check, the parameter
binding, the transaction, the call and the error handler. A replay therefore
opens no transaction and runs no access check — it answers the principal that
received the response the first time, nobody else (see the scope below). The
`OPTIONS` preflight is not passed through it. An endpoint without the
annotation ignores the header.

### Sending a key

The key is the client's: any string of 1 to 191 characters that names *one*
logical request — a UUID generated when the user pressed "Order", kept for every
retry of that press and never reused for another.

```bash
KEY=$(uuidgen)
curl -i -X POST https://api.example.com/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $KEY" \
  -d '{"item": "book", "quantity": 1}'

# The answer was lost; the same request with the same key is safe.
curl -i -X POST https://api.example.com/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $KEY" \
  -d '{"item": "book", "quantity": 1}'
# HTTP/1.1 201 Created
# Idempotent-Replayed: true
```

The framework's own HTTP client already treats such a call as safe to repeat:
`TomResilientClient` retries a `POST` that carries an `Idempotency-Key` (see
[configuration.md](configuration.md#outgoing-http-calls)).

### What a request with a key gets

| The key is … | Answer |
| ------------ | ------ |
| new | the method runs; its response is stored and returned |
| stored, for the same request | the stored response, with `Idempotent-Replayed: true`; the method does not run |
| stored, for a different request | `422`, `endpoint.idempotency.key_reused` |
| claimed by a request still running | `409`, `endpoint.idempotency.in_progress`, with `Retry-After: 1` |
| empty, or longer than 191 characters | `400`, `endpoint.idempotency.key_invalid` |

The three refusals answer `application/json` with
`{"error": "<key>", "message": "<text>"}` and run nothing.

**The same request** means the same method, path, query and body, compared as
their SHA-256. A retry that changed the body — a quantity edited between two
attempts — is a different request, and the key refuses it rather than answering
it with the response to the first.

**A key is scoped** to the tenant, the authenticated principal and the
operation — the HTTP method and the route as declared, `POST /orders/{id}`. Two
callers sending the same key never meet, and one caller using one key on two
endpoints holds two keys.

**A request without a principal ignores the key**, and so does one without the
header: both run as they would without the annotation. A key with no principal
behind it would let anyone who learned the key read the response stored under
it. On a public endpoint the annotation therefore protects only the callers who
are signed in.

### What is stored

| Response | Stored |
| -------- | ------ |
| a status below 500 | yes — `2xx`, `3xx` and the `4xx` that describe the request, such as a `400` validation failure or a `404`, an [access denial](#a-denial-answers-404-and-says-nothing-else)'s included |
| `401`, `403`, `408`, `409`, `425`, `429` | no — each says the request did not run (refused, or to be tried later), so storing it would replay a refusal after its cause is gone; the key is released |
| a `5xx` | no — the key is released, and the retry runs |
| nothing: the handler threw | no — the key is released and the error propagates |

`TomIdempotency.notStoredStatuses` is the set of the second row. A method that
throws is answered by its [error handler](#error-handling), and the status that
handler chooses decides: the default `500` releases the key, while an error key
a `TomStatusMappingErrorHandler` maps to a `4xx` is stored and replayed like any
other answer. Only a failure that escapes the handler — an error handler that
itself throws — reaches the last row.

A stored response keeps its status, its body and its headers, except
`set-cookie` — a session cookie belongs to the first caller, not to whoever
replays — and the hop-by-hop and per-transmission ones (`date`, `connection`,
`keep-alive`, `transfer-encoding`, `content-length`, `trailer`, `upgrade`).
The replay adds `Idempotent-Replayed: true` (`TomIdempotency.replayedHeader`).

Both bodies are read into memory: the request's to fingerprint it, and the
response's to store it. An idempotent endpoint is an API call, not a file
transfer; an upload or a download belongs on an endpoint without the
annotation.

### Retention and abandoned claims

A record is replayed until its retention ends — `@TomIdempotent(retention:)`,
else `TomIdempotency.defaultRetention`, 24 hours. A key used after that runs as
new. The retention is the client's retry window: choose it longer than the
longest a client keeps retrying.

A request claims its key before the method runs. When the process serving it
dies, the claim is never completed; after `TomIdempotency.inProgressTimeout`
(five minutes) a retry takes it over and runs. Until then the retry is answered
`409`. Keep the timeout longer than the slowest request of an idempotent
endpoint, or a retry arriving while the first request still runs is let through.

Expired records stay in the store until `TomIdempotency.store.purgeExpired(now)`
removes them; a deployment calls it from a scheduled job.

### Stores, clusters and tenants

`TomIdempotency.store` decides where records are kept:

| Store | Holds for |
| ----- | --------- |
| `TomMemoryIdempotencyStore` (default) | one process — a retry that reaches another instance, or the same instance after a restart, runs again |
| `TomSqlIdempotencyStore` | every instance sharing the database: a claim is a single insert against the table's primary key, and taking over an expired or abandoned claim a single conditional update, so two instances cannot both win a key |

`TomServer.start` installs a `TomSqlIdempotencyStore` when the `idempotency`
configuration names a data source (below). It keeps its records in
`tom_idempotency_key` (`idempotencyTable`, `idempotencyTableDdl`,
`defaultIdempotencyTable`), creating the table on first use unless
`createSchema` is off; the reference migration is
`example/endpoints/migrations/main/tomcore/[1]-create_tom_idempotency_key.sql`,
with its PostgreSQL form under `migrations_postgresql`. The table is one of the
`frameworkOwnedTables` the schema check covers (see
[db_migration.md](db_migration.md#the-frameworks-own-tables)).

The store resolves its data source **by name, on every call**, through the same
routing a repository uses. Under tenancy, when that data source is one of
`TomTenancy.datasources`, a tenant on its own schema or database keeps its keys
there — see
[tenancy.md](tenancy.md#what-stays-deployment-wide). Under shared tenancy one
table serves every tenant, and the `tenant` column keeps their keys apart.
`TomSqlIdempotencyStore.over(datasource)` binds one data source instead, for a
deployment without per-tenant data sources and for tests. A name that resolves
to no registered data source fails the request with
`endpoint.idempotency.no_datasource`, raised by the store rather than answered
as a refusal, so it reaches the server's error mapping as a `500`.

A deployment can also install a store of its own — `TomIdempotencyStore` is the
contract: `claim`, `complete`, `release`, `purgeExpired`.

### Configuration

The `idempotency` key of the configuration resources
(`TomServer.idempotencyConfigurationKey`) is read by
`TomServer.configureIdempotency`, which `start()` calls first, beside the
`httpClient` key:

```yaml
# assets/config-resources_default.yaml
idempotency:
  datasource: main
  retentionMinutes: 1440
  inProgressTimeoutSeconds: 300
```

The keys are described in
[configuration.md](configuration.md#idempotency-keys). Without the key the
in-memory store and the defaults stand; a value of the wrong shape stops the
start with `endpoint.idempotency.config.invalid`.

`example/endpoints/idempotency_example.dart` runs a first request, its replay, a
reused key, another caller's key, requests without a key and an expired record
through `TomIdempotency.handle` over the in-memory store.

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

### "No such thing" is an error key, not a `null`

An endpoint whose honest answer is sometimes "there is none" — a record never
written, an id that names nothing — does **not** declare a nullable result and
return `null`. The pipeline answers a `null` result with a `200` and an empty
body, the same as a `void` one, so on the wire it is indistinguishable from a
success that carries nothing, and a client generated from the endpoint's types
would read it as one. No endpoint in the framework declares a nullable result.

The rule instead, for every API with such an answer:

1. **Declare the result non-nullable**, and raise a keyed exception for the
   absence. The key belongs to the API's contract — a public constant beside the
   endpoint declarations, because the client has to recognise it — and is part
   of the API's error vocabulary like any other.
2. **Map that key to a status** with a `TomStatusMappingErrorHandler` on the
   endpoints, normally `404`. The base class renders the framework envelope, so
   the body carries the key under `errorKey`.
3. **Recognise absence on the client by the key, never by the status alone.**
   The pipeline answers a denied call with a *bare* `404`
   ([A Denial Answers 404, and Says Nothing Else](#a-denial-answers-404-and-says-nothing-else)),
   so "there is none" and "you may not ask" share a status and differ only in
   the envelope. A client that reads every `404` as absence turns a refusal into
   a convincing "not set".

The preferences API is the worked example: `readPreference` raises
`tomUserPreferencesNotFoundErrorKey` (`preferences.not_found`, declared in the
kernel contract), `TomUserPreferencesErrorHandler` maps it to `404`, and
`TomUserPreferencesClient` answers `null` only for a `404` whose envelope
carries that key.

This is a convention rather than pipeline machinery on purpose. A nullable
result type with a pipeline-level answer would need a status of its own — `404`
collides with the deliberate bare refusal, and `204 No Content` is treated
specially by some intermediaries — plus nullability exposed through
`TomApiEndpoint` for every client. A per-API key costs one constant and one row
in a status map, keeps the absence named in the API's own vocabulary, and asks
nothing of the pipeline.

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

A table and column pair that names no registered slot is refused before any
byte moves, with `file_endpoint.unknown_slot`.

A multipart part must be **materialised** to be read (part N+1 is unreachable
until part N is drained), so each file part is buffered, and
`TomMultipartForm.globalSettingMaxFilePartBytes` (8 MiB) states the ceiling out
loud rather than letting a large upload discover it as an out-of-memory crash.
Bulk transfer belongs on the raw-body file endpoint, which streams and needs no
ceiling at all.

Decoding fails the request as a `TomFormBindingException`, each cause with its
key:

| Key | Raised when |
| --- | ----------- |
| `form_binding.malformed_multipart_body` | the multipart body cannot be decoded |
| `form_binding.malformed_url_encoded_body` | the URL-encoded body cannot be decoded |
| `form_binding.file_part_too_large` | a file part exceeds the ceiling; names the field and the limit |
| `endpoint_pipeline.bind_parameters.missing_file_part` | a `TomFormFile` parameter has no part of its name |

**The one-file form does not get a streaming path either**, and that is a
decision rather than an omission. A form with a single file part could in
principle be handed to the handler as a live stream, because there is nothing
after it to reach — but "the file is the last part" is a property of the *page*,
not of the protocol. HTML submits a form's entries in the document's own tree
order, so whether the file arrives last depends on where the `<input
type="file">` happens to sit among the other inputs, in markup the endpoint does
not own and cannot see. An endpoint accepting a streamed part would work for one
page and silently buffer, or fail, for another submitting the same fields in a
different order. A contract that holds or not depending on how a caller's form
was authored is worse than a ceiling, which at least refuses in one place and
says why. So a transfer that outgrows the ceiling changes **route**, not shape —
and the guidance is repeated on `TomEndpoint.consumes`, where an endpoint
declares itself a form.

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
- `@TomTransactional` is refused at mount time, with
  `endpoint_pipeline.create_routes_for_endpoint.transactional_web_socket`: a
  transaction cannot span a connection.

A `TomWebSocketConnection` is attached to its channel by the pipeline at upgrade
time, exactly once: attaching a second channel is
`web_socket_endpoint.already_attached`, and sending or reading on a connection
nothing has attached is `web_socket_endpoint.not_attached`. A handler always
receives an attached connection, so either one means the connection was built
or reused outside the pipeline. The pipeline's own socket entry point refuses an
endpoint that declares no WebSocket transport with
`endpoint_pipeline.handle_web_socket_call.not_a_socket_endpoint`.

`protocols`, `allowedOrigins` and `pingInterval` are passed through to the
handshake. `allowedOrigins` is the handshake-time counterpart of CORS — the
`Origin` header is set by browsers and only by browsers, so it is what stops a
page on another site from opening an authenticated socket in a visitor's
session.

### One request id per message

A handler reading `socket.messages` runs, and logs, under the **upgrade
request's** id for as long as the conversation lasts. `serve` reads the same
messages one at a time and runs the callback for each as work of its own:

```dart
@override
Future<void> ticker(TomWebSocketConnection socket, TomPrincipal who) =>
    socket.serve((message) async {
      tomLog.info('received $message'); // logged under this message's id
      socket.sendText('echo: $message');
    });
```

Each call runs in a new span of the connection's trace with the request id
`<trace id>-<span id>` (the kernel's `TomRequestId.runChild`), so the log
lines, exceptions and audit entries of one message name that message and still
name the upgrade request's trace. The next message is read only once the
callback has completed, so messages are handled in the order the peer sent
them; an error from the callback ends the loop and reaches the caller, and the
returned future completes when the peer ends the conversation. `serve` and
`messages` read one single-subscription stream: a handler uses one or the
other.

### What the trail says about a socket

An endpoint that declares `@TomAudited` contributes **two** records per
conversation, and they are the two moments an auditor can act on:

| Record | Written | Detail |
| ------ | ------- | ------ |
| acceptance | before the handler runs | `WebSocket connection accepted` |
| close | when the handler returns | `WebSocket connection closed after 3.4s, 12 received, 5 sent` |
| close (failed) | when the handler throws | the error, followed by the same shape |

Both carry the **handshake's request id** — `serve` gives each message an id of
its own, but these two records are written outside it — so the pair is one conversation
rather than two unrelated records, and the closing outcome is `succeeded` for a
normal return and `failed` for a throw.

The closing entry exists because the first does not describe what happened. "A
connection was accepted" says the same thing about a channel that carried
nothing and one that carried two hundred messages over an hour — access to the
channel, not use of it. The shape closes that: how long it was open, how many
frames the handler read, how many it sent. Frames the handler never read are not
counted, and that is the true answer about a handler that never listened.

**What the trail does not say is what was said.** There is no record per
message, deliberately: that is the trail an auditor cannot read, with the
entries that matter buried under routine traffic, which is the failure the
declared-auditing design exists to prevent. A socket whose *messages* are
themselves auditable events — commands rather than a data feed — records them
from the handler, where their meaning is known.

## The OpenAPI Document

A server publishes its OpenAPI 3.1 document at `GET /openapi.json`. The document
is **generated at build time, not here**: `tom_core_openapi` writes it from the
endpoint annotations and the reflected DTOs, and this module serves the file it
is pointed at. A file written by the build is diffable, is the same on every
node of one deployment, and is what a client generator reads anyway; a document
generated per request would be an artefact nobody reviewed, and every server
would carry the generator.

`TomOpenApiService` declares the route and `TomOpenApiServer` implements it.
Both are framework classes the router mounts like any other `@tomService`, so
the route exists on every server, and so it appears in every generated document
too. Serving is switched on per deployment by the `openApiDocument`
configuration setting, which `TomServer.start` copies into
`TomOpenApiServer.globalSettingDocumentPath` (see
[Publishing the OpenAPI Document](configuration.md#publishing-the-openapi-document)):

```yaml
# assets/config-resources_default.yaml
openApiDocument: "openapi/openapi.json"
```

The route is `@TomPublicAccess()`: the document describes how to call the
server and is read before a caller holds any credential, the way a well-known
JWKS is. It describes routes, never data. Its requests are not logged
(`logRequests: false`).

The file is read on every request rather than cached. It is small, a deployment
replaces it rather than the running server, and a cached copy would go on
serving a document the deployment had already replaced. A relative path
resolves against the working directory.

Both refusals are a `404` carrying the framework error envelope as JSON:

| Key | When |
| --- | ---- |
| `openapi.document.not_served` | `globalSettingDocumentPath` is `null` or empty — this server publishes no document |
| `openapi.document.missing` | the configured path names no file; a warning naming the path is logged as well |

The advanced sample's two HTTP servers publish theirs, and
`advanced_openapi_client/test/generated_client_integration_test.dart` requires
each served document to equal the committed file its client was generated
from.

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
`[handleInvocationError by error handler]`, `[handleUnknownResultTypeError]`,
`[handleConversionError]`,
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

Each endpoint has a `TomErrorHandler`. The pipeline calls a hook for each
place a call can fail, and all three default to `handleErrorDefault`:

| Hook | When |
| ---- | ---- |
| `handleInvocationError` | the method threw |
| `handleUnknownResultTypeError` | the method succeeded, but its result holds a type the converter has no rendering for — the reflection layer refused it with `reflector.type.not_annotated` (a class without `@tomReflector`, or a bare scalar where an object was expected) |
| `handleConversionError` | rendering a result of a shape the converter knows failed for any other reason — a value JSON cannot encode, a rendering hook that threw |

The middle row is separate because its cause is the endpoint's *declaration* —
a result type nobody annotated — rather than a value that happened to be
unencodable, and an application may want to answer the two apart.

If a handler itself throws, the pipeline raises a `TomEndpointHandlerException`
wrapping both errors — `endpoint_pipeline.handle_method_call.error_handler_failed`
for the invocation hook, `endpoint_pipeline.handle_method_call.conversion_error_handler_failed`
for either result hook (the message names which), the handler's error as the
root and the original under `original_error`. An endpoint with no error handler at all whose result fails to
serialise raises `endpoint_pipeline.handle_method_call.result_conversion_failed_no_error_handler`.

The default handler, `TomDefaultErrorHandler`, answers **the framework
envelope** at a `500` — `tomErrorEnvelope(error)` under `x-tom-error: true` and
declared `application/json`, the same shape `TomServer.errorHandler` answers one
layer out and the same shape every module handler answers — or, when the request
asks for one, the same fields as a problem document (see
[Error Formats and problem+json](#error-formats-and-problemjson)). No detail leaks: the
envelope reports `errorKey` for a client to resolve against its own resources
and never `defaultUserMessage`. What it does carry is the `uuid`, which is what
makes an otherwise unexplainable `500` traceable to a log line.

**A status other than `500` is declared, not guessed.** Subclass
`TomStatusMappingErrorHandler` and give it a map:

```dart
class OrdersErrorHandler extends TomStatusMappingErrorHandler {
  const OrdersErrorHandler();

  @override
  Map<String, int> get statusByErrorKey => const {
    'orders.fetch.not_found': 404,
    'orders.submit.no_positions': 400,
  };
}
```

Keyed by the **error key** rather than by exception type, because the key is
what crosses the wire and what a client branches on: two modules may raise one
type for conditions a caller must tell apart, and one type may be raised for
conditions with different statuses. A key the map does not name stays a `500`,
and the body is the same envelope either way — only the status is the
subclass's contribution. For a rule a map cannot express, such as a whole key
family, override `statusFor` and call `super.statusFor(error)` for the rest;
`TomUserPreferencesErrorHandler` does exactly that for `preferences.encoded.*`.

The framework declares no status of its own here, and that is a decision rather
than an omission: it cannot know an application's keys, and the two
classifications it *does* make are made elsewhere and differently — an access
denial answers `404` from `TomEndpointHandler.accessDeniedResponse`,
deliberately indistinguishable from a route that is not there, and a login
failure is the authentication pipeline's to report. A status invented here would
contradict one of them.

Every hook takes the trace as a **`StackTrace`**. Each call site binds one from
a `catch (error, stacktrace)`, so a looser `Object` bought nothing and cost each
implementation a cast before it could call anything a trace offers — a cost paid
once per implementation and then forever.

### Error Formats and problem+json

Every framework error response is built by `tomErrorResponse` (in
[little_things](little_things.md#the-problem-document)), which answers in one of
two formats carrying the same fields:

| Request | Body | `Content-Type` |
| ------- | ---- | -------------- |
| `Accept` lists `application/problem+json` (with a `q` above 0) | `tomProblemDetails` — an RFC 9457 problem document | `application/problem+json` |
| served by an endpoint of a service declared with `problemJson: true` | `tomProblemDetails` | `application/problem+json` |
| anything else | `tomErrorEnvelope` | `application/json` |

A wildcard (`*/*`, `application/*`) does not select problem+json: a client that
has not named the format is one written against the envelope.

```http
GET /v1/fixture/orders/failing HTTP/1.1
Accept: application/problem+json

HTTP/1.1 500 Internal Server Error
Content-Type: application/problem+json
x-tom-error: true

{"type": "urn:tom:error:fixture.orders.failed", "title": "Internal Server Error",
 "status": 500, "instance": "urn:tom:request:…",
 "errorType": "TomServerException", "errorKey": "fixture.orders.failed", ...}
```

`type` is `urn:tom:error:<errorKey>` (or `about:blank` for an error without a
key), so the key stays the thing a client branches on; `title` is the status's
reason phrase; `instance` names the request when the error does. Every envelope
field follows as an extension member, and there is no `detail` — neither format
carries a message.

For an endpoint of a `problemJson` service, `handleMethodCall` puts
`tomProblemJsonContextKey: true` on the request context before anything else
runs, so every error handler the endpoint reaches — the default, a
`TomStatusMappingErrorHandler` subclass, or a deployment's own handler that
calls `tomErrorResponse` — answers a problem document. A handler that builds its
own `Response` decides its own format; the flag is for handlers that delegate.
`TomServer.errorHandler`, one layer out, follows the request's `Accept` only: it
runs outside the endpoint, for a request that may have reached none.

## Building the Router

`TomEndpointRouting().initializeRouter()` (called by `TomServer`) scans the
reflected classes, mounts every endpoint method, and returns the shelf
`Router`. The mounted handlers and a `TomEndpointRouteKey`→`TomEndpointRoutingInfo`
map are kept statically for diagnostics. Conflicting annotations abort the build
with `TomEndpointPipelineException`:

| Key | Raised when |
| --- | ----------- |
| `endpoint_pipeline.initialize_router.api_implementation_and_service_on_same_class` | a class carries both `@tomService` and `@TomApiImplementation` |
| `endpoint_pipeline.get_class_method_metadata.multiple_endpoint_base_tags` | a method carries two endpoint annotations |
| `endpoint_pipeline.get_class_method_metadata.multiple_transactional_tags` | a method carries two `@TomTransactional` |
| `endpoint_pipeline.get_class_method_metadata.multiple_audited_tags` | a method carries two `@TomAudited` |
| `endpoint_pipeline.get_class_method_metadata.multiple_idempotent_tags` | a method carries two `@TomIdempotent` |
| `endpoint_pipeline.get_class_method_metadata.multiple_tom_api_implementation_tags` | a class carries two `@TomApiImplementation` |
| `endpoint_pipeline.get_class_method_metadata.no_tom_api_implementation_found` | a registry endpoint's class has no `@TomApiImplementation` |
| `endpoint_pipeline.get_class_method_metadata.invalid_api_version` | a `@TomService` declares a version below 1, or a `TomApiImplementation` declares one at all (see [Versioned APIs](#versioned-apis)) |

An [undeclarable HTTP method](#which-methods-may-be-declared) and two access
controls on one method are refused the same way, under the keys their sections
give.

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

**It is read-only, and it describes the last `initializeRouter` run.** Both
`routingInfo` and `handlers` are unmodifiable *views* of the tables the mount
writes: reading one costs nothing and shows a later mount, and `add`, `remove`,
`clear` and assignment throw `UnsupportedError`. That is the whole of the public
access. Writing was never a capability worth having — a caller that appended
would be describing a route nothing serves, and one that removed would be hiding
a route that is still served. Neither changes what the server answers, so
neither is visible from the outside; what changes is that every reader of the
table is now wrong about the process it is reporting on.

`initializeRouter` empties both before it mounts, which is what makes "the last
run" true: it builds a fresh `Router`, so the table describing that router is
fresh too. A process that initialises twice sees the second router's routes and
not the union of both. `TomEndpointRouting.resetRoutes()` is the same reset,
public for a test that mounts routes directly without building a router.

The tables are **static**, so they are process-wide rather than per-router. That
is what lets a diagnostics endpoint report on a server it does not hold, and it
is the reason two routers in one process would share one table — a shape nothing
in this framework builds.

## Not Yet Implemented

Every limitation below has a consequence a caller can observe — a value that
never arrives, a request that is not rejected, an audit trail thinner than it
looks. It is not a survey of everything unfinished inside the module: edges with
no outward effect are out of scope for this list, so a limitation's absence from
it means "nothing a caller can see", not "nothing at all".

- **An unmapped query parameter is dropped, and only a debug line says so.** A
  path capture binds under its own name whether or not `urlParameterMapping`
  names it; a query parameter binds **only** when the map names it. An endpoint
  expecting `?token=…` with an empty mapping therefore receives a request DTO
  without it — or, when the route captures nothing at all, no DTO and an
  argument-count failure that names neither the parameter nor the query string.
  The drop is announced at **debug**, naming the endpoint and the parameter
  names (never their values), which makes it findable by someone who goes
  looking and no more than that: a caller gets a `200` computed as though the
  parameter had not been sent. The opt-in itself is deliberate — see
  [Binding a Query Parameter](#binding-a-query-parameter).
  <!-- pinned: test/endpoints_test.dart › a query parameter the mapping does not name is dropped -->
- **A repeated text field cannot become a list.** Both form shapes keep the
  last value of a repeated field, the way a query string does, because a DTO
  field is one value. An endpoint that needs a repeated *text* field declares a
  JSON body, where a list is expressible. Changing this would mean deciding —
  per field, not per endpoint — when two values are one list and when they are a
  correction, which the envelope does not say.
  <!-- pinned: test/endpoints_transport_test.dart › a repeated text field keeps the last value -->
- **Multipart parts are materialised.** A part must be buffered to be read, so
  `globalSettingMaxFilePartBytes` bounds it. Streaming a part lazily is not
  expressible over a sequential envelope; bulk transfer belongs on the raw-body
  [file endpoint](file_storage.md#serving-a-file-over-http), which streams. The
  single-file form, where there is nothing after the part to reach, is the one
  case that could have been streamed and deliberately is not — the file is last
  only if the page's markup puts it last, which the endpoint cannot require. See
  [Multipart Forms](#multipart-forms).
  <!-- pinned: test/endpoints_transport_test.dart › a file part over the ceiling is refused while it is being read -->
- **`TomFileSlots` is a per-isolate registry, and registering is a bootstrap
  requirement.** The map of exposed file columns is static, and Dart isolates do
  not share statics, so an application serving from several isolates must run
  its `TomFileSlots.register` calls in each — which a start-up path does, and a
  `main()` that one isolate reaches does not. An isolate that registered nothing
  no longer answers a file request with "no such slot": `resolve` refuses an
  empty registry by name (`file_endpoint.no_slots_registered`, logged), because
  a bootstrap that did not run and a column deliberately left closed are
  otherwise the same 404. `TomFileSlots.reset()` exists for tests that want a
  fresh registry, not for re-registration at runtime.
  <!-- pinned: test/file_endpoint_test.dart › resolve refuses an empty registry by name -->
- **Nothing purges expired idempotency records on its own.** An expired record
  is no longer replayed and is overwritten when its key is used again, but it
  stays in the store until `TomIdempotency.store.purgeExpired(now)` is called.
  A deployment that keeps keys in the SQL store calls it from a scheduled job of
  its own, or the table grows by one row per key ever sent. See
  [Retention and abandoned claims](#retention-and-abandoned-claims).
  <!-- unpinned: absence — nothing in the framework calls purgeExpired -->
- **The default idempotency store holds on one process.**
  `TomMemoryIdempotencyStore` is per isolate: a retry that reaches another
  instance, another isolate or a restarted process runs again. A deployment of
  more than one runs the SQL store, by naming a data source in the
  `idempotency` configuration. See
  [Stores, clusters and tenants](#stores-clusters-and-tenants).
  <!-- unpinned: decision — the in-process default store is deliberate; a cluster names a data source -->
- **A socket has no server-side push registry.** A handler owns its own
  connection and can write to it at any time, but there is no shared registry to
  broadcast to every connection of a user or a topic. That is a feature of
  whatever wants to broadcast, and inventing its addressing model before a
  caller has one would be guessing.
  <!-- unpinned: absence — no broadcast registry exists -->
- **A socket's messages are not individually audited.** An audited socket
  contributes two records — the acceptance and the close, the latter carrying
  the duration and the frame counts in each direction — but nothing per message.
  What was *said* inside a conversation is the handler's own to record, where
  its meaning is known. See
  [What the trail says about a socket](#what-the-trail-says-about-a-socket).
  <!-- pinned: test/endpoints_transport_test.dart › an audited socket records its acceptance and its close -->

## Verification

Eight suites cover this module, split by what each needs.

`test/endpoints_error_keys_test.dart` pins the module's error vocabulary: each case reaches a raise with a real input and asserts the exact key, so a key the module stops raising, or raises for a different condition, fails by name. None needs a database.

`test/endpoints_test.dart` covers the annotations and the pure functions:
`TomEndpoint`, `TomApiEndpointImplementation` and its merge, the class-level
annotations, `TomTransactional`, `TomDefaultErrorHandler`, the routing metadata
types, `shelfRoutePath`, and the four parameter injectors with
`coercePrimitiveParameter` beneath them.

`test/endpoints_pipeline_test.dart` runs the reflected pipeline for real:
scanning annotated classes, resolving access through `getClassMethodMetadata`
(C-12 / G-API-3), a contract-declared policy gating a live request, CORS —
in the groups `CORS preflight` (an admitted origin given the policy's three
headers, an unlisted one none, the shipped default admitting no origin, an
endpoint override replacing only what it states, a changed policy reaching a
mounted route) and `CORS on the response itself` (the admitted origin on a
successful call and on a refused one, none without an `Origin` or from an
unlisted one) — the HTTP methods an endpoint may declare, declared response headers,
the readme's own Quick start, the resource-key socket endpoint, a `GET`
request run as read-only work for read-replica routing while a `POST` — and a
`GET` with `TomReplicaRouting.routeSafeRequests` off — is not, and the
healthcheck module's `GET /health` route — which is mounted here rather than by
that module, and so is asserted here.

`test/endpoints_transport_test.dart` covers the three transports over the
pipeline: both form decoders (`TomMultipartForm.readForm` and
`readUrlEncodedForm`, plus `tomConsumesForm` and `injectFormFields`),
`TomRedirect`, and WebSockets — including a socket endpoint mounted alongside
the HTTP ones and served over a loopback server.

`test/endpoints_serialization_roundtrip_test.dart` asserts the one property a
DTO has to have: it crosses both directions identically.

`test/api_versioning_test.dart` mounts two versions of one service side by side
(`FixtureOrdersV1` at `/v1`, `FixtureOrdersV2` at `/v2`) and serves both,
asserting that the unversioned path is not mounted, and covers the error
formats: the envelope for a request that does not ask, a problem document for
one that does, the envelope for `q=0`, and a problem document whatever the
request asks for from the `problemJson` service — plus `TomEndpoint.withUri`.

`test/idempotency_test.dart` covers idempotency keys: `TomIdempotency.handle`
over the memory store — a retry run once and answered with the first response,
a reused key refused with `422`, a claimed key with `409` and `Retry-After`, a
`5xx` and a thrown handler releasing the key, the refusals that are not stored,
the scope per principal and operation, a request without a key or a principal
passing through, an over-long key, an expired record and an abandoned claim
taken over — then the `idempotency` configuration map, and the fixture endpoint
`POST /fixture/orders` (`@TomIdempotent`) served through the pipeline.
`test/idempotency_db_test.dart` (tagged `db`) runs `TomSqlIdempotencyStore`
against MariaDB: the first claim winning, a completed record, a release, an
expired record and an abandoned claim replaced, the purge, and a retried request
through the SQL store. The table's declaration is held to its migration and its
row type by `test/framework_schema_test.dart`.

```bash
dart run example/endpoints/endpoints_example.dart
dart run example/endpoints/idempotency_example.dart
```

`example/endpoints/endpoints_example.dart` runs everything that needs neither a
server nor a socket — the annotations, the default error handler's `Response`,
both form decoders on requests built in-process, and the file-slot registry. The
file-slot step needs generated reflection, which comes from
`example/example_reflection.dart`, the example suite's single reflection root
(regenerate with `./reflection_generation.sh`); its entities are declared in
`example/endpoints/endpoints_entities.dart`. Every step checks its own result,
and `test/examples_test.dart` runs it.

`example/endpoints/idempotency_example.dart` sends requests through
`TomIdempotency.handle` over the in-memory store — a first request, its replay,
a reused key, another caller's key, requests without a key and an expired
record — checking each answer; `test/examples_test.dart` runs it too.

## Core Components

- **Annotations** (`endpoint_annotation.dart`) — `TomEndpoint`,
  `TomApiEndpointImplementation`, `TomService` / `tomService` (with its
  `version` and `problemJson`),
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
  [File Storage](file_storage.md#serving-a-file-over-http). A download honours
  HTTP `Range` — `206` with `Content-Range`, or `416` carrying
  `file_endpoint.range_not_satisfiable` and `Content-Range: bytes */<size>` when
  the range starts at or past the end — and both `GET` and `HEAD` advertise
  `Accept-Ranges: bytes`, without which a browser never asks for one.
  Every other refusal is a `{"key", "message"}` body as well:

  | Status | Key | When |
  | ------ | --- | ---- |
  | `404` | `file_endpoint.unknown_slot` | the path names no registered table and column |
  | `405` | `file_endpoint.method_not_allowed` | a method other than `POST`, `PUT`, `GET`, `HEAD` or `DELETE` |
  | `400` | `file_endpoint.invalid_id` | the record id does not parse as the entity's key type |
  | `404` | `file_endpoint.no_file` | `GET` or `HEAD` on a slot holding no file |
  | `404` | `storage.file_reference.row_not_found`, `storage.file_reference.no_file`, `storage.file_reference.unknown_column` | the repository's own answers, passed through under their keys — a row the caller cannot see answers exactly as a row that is not there |

  An upload whose row then cannot describe the file it took is
  `file_endpoint.stored_file_not_readable`: the row and the store disagree, and
  that is a fault, not an answer. Registering a slot is refused at bootstrap
  when the entity declares no `@TomDbTable` (`file_endpoint.entity_not_mapped`),
  marks no file column `exposed: true` (`file_endpoint.no_exposed_column`), was
  registered already (`file_endpoint.duplicate_slot`), or has two file columns
  answering to one name, which would let an exposed slot address a closed one
  (`file_endpoint.ambiguous_slot`).
- **Form binding** (`form_binding.dart`) — `TomMultipartForm`, `TomFormFile`,
  `TomFormBindingException`, and the `tomConsumesForm` /
  `tomConsumesMultipartForm` predicates.
- **Results** (`endpoint_results.dart`) — `TomRedirect`.
- **WebSocket** (`web_socket_endpoint.dart`) — `TomWebSocketEndpoint`,
  `TomWebSocketConnection`, `TomWebSocketException`.
- **Idempotency keys** (`idempotency.dart`, `idempotency_sql.dart`) —
  `TomIdempotent`, `TomIdempotency`, `TomIdempotencyStore` with
  `TomMemoryIdempotencyStore` and `TomSqlIdempotencyStore`,
  `TomIdempotencyScope`, `TomIdempotencyRecord`, `TomIdempotencyClaim`,
  `TomIdempotencyRow`, `TomIdempotencyException`; and the table's declaration,
  `idempotencyTable`, `idempotencyTableDdl` and `defaultIdempotencyTable`. See
  [Idempotency Keys](#idempotency-keys).
- **CORS** (`cors.dart`) — `TomCors`, the allow-list of browser origins the
  pipeline answers preflights and responses from, and `TomCorsException`; see
  [CORS](#cors).
- **OpenAPI document** (`openapi_document_endpoint.dart`) — `TomOpenApiService`
  and `TomOpenApiServer`, serving the build-generated document at
  `GET /openapi.json`; see [The OpenAPI Document](#the-openapi-document).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `endpoint_pipeline.dart`, `file_endpoint.dart`, `idempotency.dart`, `web_socket_endpoint.dart` | `Future`, `Stream`, `StreamController`, `StreamSubscription`, `Zone`, `unawaited` |
| `dart:collection` | dart | `endpoint_pipeline.dart` | `UnmodifiableListView`, `UnmodifiableMapView` — the read-only views of the routing tables |
| `dart:convert` | dart | `endpoint_pipeline.dart`, `file_endpoint.dart`, `idempotency.dart` | `Encoding`, `json`, `jsonDecode`, `jsonEncode`, `utf8`, `base64Encode` / `base64Decode` (a stored response body) |
| `dart:io` | dart | `openapi_document_endpoint.dart` | `File` — the generated document is read from disk |
| `dart:typed_data` | dart | `form_binding.dart` | `Uint8List` |
| `crypto` | package | `idempotency.dart` | `sha256`, the fingerprint telling a retry from a different request under the same key |
| `shelf` | package | 8 of 10 files | the HTTP `Request` / `Response` / `Router` types |
| `shelf_multipart` | package | `form_binding.dart` | decoding a `multipart/form-data` body into its parts |
| `shelf_router` | package | `endpoint_pipeline.dart`, `file_endpoint.dart` | the HTTP `Request` / `Response` / `Router` types |
| `shelf_web_socket` | package | `endpoint_pipeline.dart` | the handshake upgrade and the channel a socket handler talks through |
| `tom_core_kernel` | package | 8 of 10 files | `tomReflector` and the mirror types (annotation discovery, parameter binding, result conversion), `TomHttpMethod`, `TomMimeType`, `TomHeader`, `TomPrincipal`, `TomClientJwtToken`, `TomAccessControl`, `TomResourceKeyProtection`, `TomComponent`, `TomBean`, `tomRemoteApis` / `TomApi` / `TomApiEndpoint`, `TomExecutionContext`, `TomTenantContext` (the tenant an idempotency key is scoped to), `TomRequestId` (the request id the pipeline logs; `TomRequestId.runChild` for each message `serve` reads), `tomLog` |
| `web_socket_channel` | package | `endpoint_pipeline.dart`, `web_socket_endpoint.dart` | the handshake upgrade and the channel a socket handler talks through |
| [audit](audit.md) | module | `endpoint_pipeline.dart` | `TomAuditAction`, `TomAuditOutcome`, `TomAuditTrail`, `TomAudited` |
| [datasources](datasources.md) | module | `endpoint_pipeline.dart`, `idempotency.dart`, `idempotency_sql.dart` | `TomReplicaRouting` (a `GET` or `HEAD` request runs as read-only work), `TomFrameworkTable` / `TomFrameworkColumn` / `TomFrameworkKey` (the table's declaration), `TomDataSourceInfo` (the store's data source, resolved by name per call), `TomSchemaProvisioning`, `sqlInstant` / `parseSqlInstant` |
| [file_storage](file_storage.md) | module | `file_endpoint.dart` | `TomBlobRange`, `TomStorageException`, `TomStoredBlob` |
| [little_things](little_things.md) | module | 8 of 10 files | `TomServerException`, `tomErrorEnvelope`, and `tomErrorResponse` / `tomProblemJsonContextKey` — the error response in the format the request asks for |
| [object_persistence](object_persistence.md) | module | `file_endpoint.dart`, `idempotency.dart` | `TomAnnotationAnalyzer`, `TomColumnAuthorizationException`, `TomColumnInformation`, `TomDataScopeAuthorizationException`, `TomDbTable`, `TomDbColumn` (on `TomIdempotencyRow`), `TomFileReference` |
| [server](server.md) | module | `endpoint_pipeline.dart` | `TomRequestLogInfo` |
| [transactions](transactions.md) | module | `endpoint_pipeline.dart` | `TomTransactionManager` / `TomTransaction` |
