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
   interface (its bean).

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
request context keyed by type or by parameter name, a value from the
`TomExecutionContext`, the JSON request body (deserialised onto the parameter
type via reflection, merged with path/query params), and finally a
`Map`-typed context entry. A parameter that cannot be filled is logged and
left unset.

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

- `TomEndpoint.formFields`, file-upload binding, and redirect directives;
- streaming / file responses to the client;
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

## Dependencies

- `shelf` / `shelf_router` — the HTTP `Request` / `Response` / `Router` types.
- `tom_core_kernel` — `tomReflector` and the mirror types (annotation
  discovery, parameter binding, result conversion), `TomHttpMethod`,
  `TomMimeType`, `TomHeader`, `TomPrincipal`, `TomClientJwtToken`,
  `TomAccessControl`, `TomResourceKeyProtection`, `TomComponent`, `TomBean`,
  `tomRemoteApis` / `TomApi` / `TomApiEndpoint`, `TomExecutionContext`, `tomLog`.
- The server module — `TomRequestLogInfo`, `TomRequestId`.
- The transactions module — `TomTransactionManager` / `TomTransaction`.
