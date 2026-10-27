# endpoints

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The endpoint annotation + request pipeline. A class annotated `@tomService` (or
`@TomApiImplementation(apiId: …)`) declares endpoints: its methods are marked
with the `@TomEndpoint` annotation (HTTP methods, URI, form fields, MIME types,
CORS, error handler). `TomEndpointRouting`
scans those annotations and builds the router; `TomEndpointHandler` runs each
request through the pipeline (decode → authorize → invoke → encode), routing
errors through a `TomErrorHandler`. `@TomTransactional` wraps a call in a
transaction. A `GET` or `HEAD` request runs as read-only work
(`TomReplicaRouting.readOnly`, while `TomReplicaRouting.routeSafeRequests`
holds), so its repository reads may be served by a data source's read
replicas.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomEndpoint` | The method annotation: `methods`, `uri`, `formFields`, `consumes`/`produces`, `headers` (response direction only), CORS, `errorHandler`. |
| `tomService` (`TomService`) · `TomApiImplementation` | Class **annotations**, not base classes — nothing is subclassed. `@tomService` marks a class whose `@TomEndpoint` methods *are* the declaration; `@TomApiImplementation(apiId: …)` marks a class serving an API declared in the `tomRemoteApis` registry. The scan reads a class's own metadata and never its supertypes, so an annotation is the only thing that puts a class on the route table. `@TomService(version: 2)` serves the service's inline endpoints under a `/v2` segment ahead of their URIs, so two versions of an API are two services mounted side by side (a registry API is versioned by `TomApi.version` instead); `problemJson: true` answers the errors of its endpoints as RFC 9457 problem documents whatever the request asks for. |
| `TomEndpointRouting` | Scans annotations and assembles the request router; `TomEndpointRoutingInfo` (keyed by `TomEndpointRouteKey` — route *and* method) / `TomClassScanResult` / `TomMethodMetadata` hold the scan results. |
| `TomEndpointHandler` | Runs one request through the decode/authorize/invoke/encode pipeline. |
| `TomErrorHandler` · `TomDefaultErrorHandler` | Map a thrown error to a response — through `tomErrorResponse` (little_things), so the body is the error envelope, or a problem document for a request whose `Accept` names `application/problem+json`. |
| `TomTransactional` | Annotation that runs the call inside a `TomTransaction`. |
| `TomRedirect` | Returned from an endpoint to answer with a 3xx and a `Location` rather than a body — the one result type that is not the endpoint's own return value encoded. |
| `TomMultipartForm` · `TomFormFile` · `tomConsumesForm` | HTML form bodies, both `multipart/form-data` and URL-encoded, decoded into the parameters an endpoint declares. A `TomFormFile` streams: `openRead()`, never a whole buffer. |
| `TomWebSocketEndpoint` · `TomWebSocketConnection` | The socket transport over the same router: an annotation that mounts a socket route beside the HTTP ones, and the connection an endpoint is handed; its `serve` runs each message under a request id of its own (`<trace id>-<span id>`, in the connection's trace). |
| `TomFileEndpoint` · `TomFileSlot` · `TomFileSlots` · `TomFileServer` | The HTTP face of a `@TomFileReference` column — upload, download and describe for a named slot, gated by the same authorization as the row it hangs off. A download honours `Range`, so a resumed transfer or a seek costs the slice rather than the file, and serves the blob's digest as an `ETag` so a client that already holds the bytes is answered `304`. |
| `TomIdempotent` · `TomIdempotency` | Idempotency keys. `@TomIdempotent()` on an endpoint lets a client send an `Idempotency-Key`: the first request runs and its response is stored, a retry with the same key gets that response (`Idempotent-Replayed: true`) without running again, the same key for a different request answers `422`, and one still running `409`. A key is scoped to the tenant, the authenticated principal and the operation. |
| `TomIdempotencyStore` · `TomMemoryIdempotencyStore` · `TomSqlIdempotencyStore` | Where the records are kept: in memory by default (one process), or in `tom_idempotency_key` (`idempotencyTable`) for a cluster — installed by `TomServer.start` when the `idempotency` configuration names a data source, which is resolved per request, so under tenancy a tenant's keys live in its own data source. |
| `TomCors` · `TomCorsException` | The CORS allow-list of browser origins, **empty by default**: no cross-origin page may read a response until its origin is listed — exactly, with any port (`http://localhost:*`), or `*`. The preflight is answered `204` and every response carries the admitted origin; an endpoint's `corsAllowedOrigins` replaces the list for it. `TomCors.current` is set by `configure` from the `cors` key; a malformed value throws `endpoint.cors.config.invalid`. |
| `TomOpenApiService` · `TomOpenApiServer` | A framework endpoint: `GET /openapi.json`, public, serving the OpenAPI document the build generated with `tom_core_openapi`. The file comes from the `openApiDocument` setting; with none configured, or none on disk, the route answers `404` with the error envelope. |

## Quick start

A service is **two** types: an annotated declaration and an annotated
implementation. It has to be — `findServiceInstance` matches an implementation
to its service by *supertype*, and a class is not its own supertype, so a single
self-referential `@tomService @tomComponent` class resolves to no instance and
the route mounts against nothing.

```dart
import 'package:tom_core_server/tom_core_server.dart';

// Your own package's generated registration — the one whose build covers the
// two classes below.
import 'main.reflection.dart';

@tomReflector
@tomService
abstract class TodoApi {
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: '/todos')
  Future<List<String>> listTodos();
}

@tomReflector
@tomComponent
class TodoApiServer implements TodoApi {
  @override
  Future<List<String>> listTodos() async => ['buy milk', 'write readme'];
}

void main() {
  // 1. Reflection first. Step 3 reads both classes' annotations through their
  //    class mirrors, so without this `initializeRouter` throws
  //    `Reflection has not been initialized` before it mounts anything.
  initializeReflection();

  // 2. Register the implementation as a bean. The router would fall back to
  //    default-constructing the @tomComponent, but an implementation with a
  //    real constructor cannot rely on that.
  TomBean.withType<TodoApiServer>(TodoApiServer());

  // 3. Build the router. TomEndpointRouting scans TodoApi's metadata, finds
  //    `GET /todos`, resolves TodoApiServer as its instance and mounts the
  //    route. TomServer.start() makes this call for you.
  TomEndpointRouting().initializeRouter();
}
```

> **Needs your package's generated reflection.** The `main.reflection.dart`
> import is a file `dart run build_runner build` writes in *your* package, so
> this is a program to build rather than one to paste into an empty file and
> run. Its first line is the one that is easy to leave out and impossible to
> work around: `initializeRouter` reads the annotations through class mirrors,
> so an uninitialized program does not mount a route table with something
> missing from it — it throws before mounting anything.

`@tomReflector` is what makes the two classes visible to the scan: the declaring
library must be reachable from the reflection root so the generated
`initializeReflection()` captures them. Without it the annotations are present
in the source and absent from the route table.

The `TodoApi` / `TodoApiServer` pair above is kept verbatim identical to the one
in `test/fixtures/reflection_fixture.dart`, which
`test/endpoints_pipeline_test.dart` compiles, mounts and serves — and
`test/readme_quick_start_test.dart` reads both files and requires the two copies
to still match, so "it works" here is a checked claim rather than a promise
about a snippet that could quietly drift away from the thing being tested.

See [`doc/endpoints.md`](../../../../doc/endpoints.md) for the annotation set,
the request pipeline and the serialization contract, and
`example/endpoints/endpoints_example.dart` for a walkthrough of the route table
and the pipeline stages — its entities live beside it in
`example/endpoints/endpoints_entities.dart`, which
`example/example_reflection.dart` imports so that the generator root reaches
them and the scan can see their annotations.
`test/endpoints_test.dart` covers the route table,
`test/endpoints_pipeline_test.dart` serves it over a real socket,
`test/endpoints_transport_test.dart` the transport and
`test/endpoints_serialization_roundtrip_test.dart` the wire shapes,
`test/api_versioning_test.dart` versioned services and the two error formats;
`test/examples_test.dart` runs the example. Idempotency keys are described in
[`doc/endpoints.md`](../../../../doc/endpoints.md#idempotency-keys), shown by
`example/endpoints/idempotency_example.dart` and covered by
`test/idempotency_test.dart` and, against a database,
`test/idempotency_db_test.dart`. CORS is described in
[`doc/endpoints.md`](../../../../doc/endpoints.md#cors) and covered by
`test/endpoints_pipeline_test.dart` and `test/web_security_test.dart`.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
