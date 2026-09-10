# http_connection

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Platform-neutral HTTP client primitives used by the remote-call layer: typed
methods, headers, MIME types, endpoint/API descriptors, the server-call
machinery that the server and Flutter layers build their transports on, and the
streaming file-transfer client that moves large payloads without buffering them.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomHttpMethod` | Typed HTTP verbs — `TomHttpMethod.get`, `.post`, `.put`, `.delete`, … |
| `TomHeader` | A typed HTTP header. |
| `TomMimeType` / `StaticFileMimetypeMapping` | MIME type values and extension→type mapping. |
| `TomRemoteApis` / `TomApi` / `TomApiEndpoint` | Declarative API + endpoint descriptors. `TomApiEndpoint.resolveUri` builds a call's address from the declaration, so a client names no URI of its own. |
| `TomServerCall` / `TomServerCallSpecs` / `TomServerCallLoad` / `TomServerCallError` | A remote call, its spec, payload, and error. `TomServerCallSpecs.timeout` (also declarable per `TomApiEndpoint`) bounds the exchange; without one a call waits indefinitely. |
| `TomRequestAbortedException` / `TomRequestTimeoutException` | Why a call ended early — cancelled by this application, or unanswered past its deadline. Kept as siblings rather than as a subtype, because only the second is worth retrying. |
| `TomServerChannel` / `TomServerEndpoint` | Channel and endpoint abstractions. `TomServerEndpoint.createApiServerEndpoint` turns a declaration into a callable endpoint, resolving its address through `resolveUri` — so the declarative half of the contract is reachable through the factory, not only by hand. |
| `TomHttpClientAbstractFactory` / `TomDefaultHttpClientFactory` / `TomHttpClientFactory` | Pluggable HTTP-client construction: the contract a custom factory implements, the shipped implementation, and the resolver that answers from a per-instance override or the process-wide registration. |
| `TomAuthRefresher` / `TomAuthRetryPolicy` / `TomAuthExpiredException` | Refresh-and-retry on an expired token. A client implements `TomAuthRefresher` over whatever auth mechanism it has; `tomDefaultAuthRetryPolicy` treats a single `401` as an expiry and retries exactly once, and is replaceable by registering another `TomAuthRetryPolicy` as a bean. |
| `TomContentDisposition` | The `Content-Disposition` header values — how a client should treat the body, inline or as an attachment. |
| `TomServerConnectionException` / `TomEndpointException` / `TomClientRemoteContextException` | Raised by the connection, the endpoint declaration, and the remote-context configuration respectively. |
| `TomFileTransferException` / `TomMimeTypeException` | Raised by the file-transfer stack and by MIME-type parsing. |
| `TomClientRemoteContext` | Which remote a client addresses. Installed once at startup by `setCurrent`; `runWithContext` shadows it on the `Zone` to reach a second server from part of a program. |
| `TomFileTransferClient` / `TomHttpFileTransferClient` / `TomMemoryFileTransferClient` | Streaming file transfer — upload, download, describe, remove — addressed by application-owned *slot* rather than by storage key. Neither direction buffers a whole file; the in-memory client honours the same contract for tests and offline modes. |
| `TomFileSource` / `TomFileMetadata` / `TomTransferProgress` / `TomTransferCancellation` | The transfer value types: the bytes to send (re-openable, so a retry sees them again), what the server stored, how far a transfer has got, and the shared cancel signal. |

## Quick start

```dart complete
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
