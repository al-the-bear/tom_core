# http_connection

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Platform-neutral HTTP client primitives used by the remote-call layer: typed
methods, headers, MIME types, endpoint/API descriptors, and the server-call
machinery that the server and Flutter layers build their transports on.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHttpMethod` | Typed HTTP verbs — `TomHttpMethod.get`, `.post`, `.put`, `.delete`, … |
| `TomHeader` | A typed HTTP header. |
| `TomMimeType` / `StaticFileMimetypeMapping` | MIME type values and extension→type mapping. |
| `TomRemoteApis` / `TomApi` / `TomApiEndpoint` | Declarative API + endpoint descriptors. |
| `TomServerCall` / `TomServerCallSpecs` / `TomServerCallLoad` / `TomServerCallError` | A remote call, its spec, payload, and error. |
| `TomServerChannel` / `TomServerEndpoint` | Channel and endpoint abstractions. |
| `TomHttpClientFactory` / `TomDefaultHttpClientFactory` | Pluggable HTTP-client construction. |
| `TomClientRemoteContext` | Carries client-side remote-call context. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Typed HTTP verbs instead of raw strings.
  const method = TomHttpMethod.post;
  print(method.name); // POST
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
