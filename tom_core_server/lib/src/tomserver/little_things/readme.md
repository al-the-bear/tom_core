# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The server-side base exception and the correlation id it reads.
`TomServerException` extends the kernel's `TomException` with the originating
isolate name, a `clientThrow` flag (whether the message may surface to the
caller or must be masked as an internal error), and automatic correlation with
the active `TomRequestId` when one is present in the current zone. Every other
server module raises a subclass of this type.

`TomRequestId` itself is declared here rather than beside the server middleware
that seeds it: it is consumed by the base exception's constructor, and this is
the module every other one depends on, so declaring it beside its producer would
have pointed the dependency arrow backwards.

One further subclass is declared here too: `TomLoginException`, which lives next
to the base rather than beside the authentication server that consumes it, so
the 2FA subsystem can throw it without importing that server.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomRequestId` | Per-request v4 UUID. Created once per request by `tomDefaultAuthenticationMiddleware` and published into the request zone; recovered with `getFromCurrentZone<TomRequestId>()` for log and exception correlation. |
| `TomServerException` | Base server error: carries `key` + `defaultUserMessage`, records `isolateName`, exposes `clientThrow` (both `final` — fixed where the error is raised), and copies the active request UUID into `requestUuid` for correlation. |
| `TomLoginException` | A login that cannot succeed. Adds no members to the base — it is a name the authentication services throw and `TomAuthenticationServer` catches. Its constructor omits `clientThrow`, so it is client-visible, unlike the rest of the authentication subsystem's exceptions. See `doc/authentication.md`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  final err = TomServerException(
    'error.order.not-found',
    'No order matched the supplied id.',
    clientThrow: true,
  );

  print(err.key);         // error.order.not-found
  print(err.clientThrow); // true  (safe to surface to the client)
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
