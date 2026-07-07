# endpoints

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The endpoint annotation + request pipeline. Methods on a `TomService` /
`TomApiImplementation` are marked with the `@TomEndpoint` annotation (HTTP
methods, URI, form fields, MIME types, CORS, error handler). `TomEndpointRouting`
scans those annotations and builds the router; `TomEndpointHandler` runs each
request through the pipeline (decode → authorize → invoke → encode), routing
errors through a `TomErrorHandler`. `@TomTransactional` wraps a call in a
transaction.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomEndpoint` | The method annotation: `methods`, `uri`, `formFields`, `consumes`/`produces`, CORS, `errorHandler`. |
| `TomService` · `TomApiImplementation` | Base classes whose annotated methods become endpoints. |
| `TomEndpointRouting` | Scans annotations and assembles the request router; `TomEndpointRoutingInfo` / `TomClassScanResult` / `TomMethodMetadata` hold the scan results. |
| `TomEndpointHandler` | Runs one request through the decode/authorize/invoke/encode pipeline. |
| `TomErrorHandler` · `TomDefaultErrorHandler` | Map a thrown error to a response. |
| `TomTransactional` | Annotation that runs the call inside a `TomTransaction`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

class TodoApi extends TomApiImplementation {
  @TomEndpoint(methods: [TomHttpMethod.get], uri: '/todos')
  Future<List<String>> listTodos() async => ['buy milk', 'write readme'];
}

void main() {
  // TomEndpointRouting scans TodoApi for @TomEndpoint methods and wires
  // `GET /todos` into the router built during TomServer.start().
  final api = TodoApi();
  print(api.runtimeType); // TodoApi
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
