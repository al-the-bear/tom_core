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
transaction.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomEndpoint` | The method annotation: `methods`, `uri`, `formFields`, `consumes`/`produces`, `headers` (response direction only), CORS, `errorHandler`. |
| `tomService` (`TomService`) · `TomApiImplementation` | Class **annotations**, not base classes — nothing is subclassed. `@tomService` marks a class whose `@TomEndpoint` methods *are* the declaration; `@TomApiImplementation(apiId: …)` marks a class serving an API declared in the `tomRemoteApis` registry. The scan reads a class's own metadata and never its supertypes, so an annotation is the only thing that puts a class on the route table. |
| `TomEndpointRouting` | Scans annotations and assembles the request router; `TomEndpointRoutingInfo` (keyed by `TomEndpointRouteKey` — route *and* method) / `TomClassScanResult` / `TomMethodMetadata` hold the scan results. |
| `TomEndpointHandler` | Runs one request through the decode/authorize/invoke/encode pipeline. |
| `TomErrorHandler` · `TomDefaultErrorHandler` | Map a thrown error to a response. |
| `TomTransactional` | Annotation that runs the call inside a `TomTransaction`. |

## Quick start

A service is **two** types: an annotated declaration and an annotated
implementation. It has to be — `findServiceInstance` matches an implementation
to its service by *supertype*, and a class is not its own supertype, so a single
self-referential `@tomService @tomComponent` class resolves to no instance and
the route mounts against nothing.

```dart
import 'package:tom_core_server/tom_core_server.dart';

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
  // 2. Register the implementation as a bean. The router would fall back to
  //    default-constructing the @tomComponent, but an implementation with a
  //    real constructor cannot rely on that.
  TomBean.withType(TodoApiServer, TodoApiServer());

  // 3. Build the router. TomEndpointRouting scans TodoApi's metadata, finds
  //    `GET /todos`, resolves TodoApiServer as its instance and mounts the
  //    route. TomServer.start() makes this call for you.
  TomEndpointRouting().initializeRouter();
}
```

`@tomReflector` is what makes the two classes visible to the scan: the declaring
library must be reachable from the reflection root so the generated
`initializeReflection()` captures them. Without it the annotations are present
in the source and absent from the route table.

This snippet is kept verbatim identical to the `TodoApi` / `TodoApiServer` pair
in `test/fixtures/reflection_fixture.dart`, which `test/endpoints_pipeline_test.dart`
compiles, mounts and serves — so "it works" here is a checked claim, not a
promise.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
