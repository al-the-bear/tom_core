# server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The HTTP server entry point. `TomServer` is constructed from a
`TomBaseServerConfiguration`, builds its endpoint router during `start`, and
binds the listener. Each request gets a `TomRequestLogInfo` record and a
`TomRequestId` — a UUID this module's authentication middleware places in the
request's zone so logs and exceptions correlate. The id type is declared in
[`little_things`](../little_things/readme.md), beside the exception base that
consumes it.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | The server: `TomServer(configuration)`; builds the `TomEndpointRouting` and starts listening. |
| `TomRequestLogInfo` | Captured per-request log metadata. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // `configuration` is your TomBaseServerConfiguration subclass (it supplies
  // the bind address/port, TLS, datasources, and endpoint registrations).
  final server = TomServer(configuration);
  server.start();

  // The server is now listening; each request carries a TomRequestId UUID.
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
