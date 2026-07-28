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

The annotation surface anticipates features the pipeline does not yet
implement; these are tracked in the quest completion steps:

- `TomEndpoint.formFields`, multipart form binding, and redirect directives —
  note that single-file upload and download *are* shipped, by the
  [file endpoint](file_storage.md#serving-a-file-over-http) over a raw body;
  what is missing is binding a file that arrives as one part of a form;
- WebSocket transport;
- richer role/group/entitlement authorization beyond resource-key protection.

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
  `TomFileEndpoint`, and the `TomFileSlots` registry; documented in
  [File Storage](file_storage.md#serving-a-file-over-http).

## Dependencies

- `shelf` / `shelf_router` — the HTTP `Request` / `Response` / `Router` types.
- `tom_core_kernel` — `tomReflector` and the mirror types (annotation
  discovery, parameter binding, result conversion), `TomHttpMethod`,
  `TomMimeType`, `TomHeader`, `TomPrincipal`, `TomClientJwtToken`,
  `TomAccessControl`, `TomResourceKeyProtection`, `TomComponent`, `TomBean`,
  `tomRemoteApis` / `TomApi` / `TomApiEndpoint`, `TomExecutionContext`, `tomLog`.
- The server module — `TomRequestLogInfo`, `TomRequestId`.
- The transactions module — `TomTransactionManager` / `TomTransaction`.
