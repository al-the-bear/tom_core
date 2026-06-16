# server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

The HTTP server entry point. `TomServer` is constructed from a
`TomBaseServerConfiguration`, builds its endpoint router during `start`, and
binds the listener. Each request gets a `TomRequestId` (a UUID placed in the
request's zone so logs and exceptions correlate) and a `TomRequestLogInfo`
record.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | The server: `TomServer(configuration)`; builds the `TomEndpointRouting` and starts listening. |
| `TomRequestId` | Per-request UUID, stored in the request zone for log/exception correlation. |
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
