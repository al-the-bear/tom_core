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
the 2FA subsystem can throw it without importing that server — together with
`TomLoginFailure`, the closed set it classifies itself as.

The module also owns `tomErrorEnvelope`, the package's single definition of what
a Tom error looks like on the wire. It is declared here for the same reason
`TomRequestId` is: `TomServerException` decides the one field the envelope
reports conditionally, and this is the module every other one already depends
on, so both error handlers reach the builder without either reaching the other.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomRequestId` | Per-request v4 UUID. Created once per request by `tomDefaultAuthenticationMiddleware` and published into the request zone; recovered with `getFromCurrentZone<TomRequestId>()` for log and exception correlation. |
| `TomServerException` | Base server error: carries `key` + `defaultUserMessage`, records `isolateName`, exposes `clientThrow` (both `final` — fixed where the error is raised), and copies the active request UUID into `requestUuid` for correlation. |
| `TomLoginException` | A login that cannot succeed. Adds a required `TomLoginFailure` reason to the base; the authentication services throw it and `TomAuthenticationServer` catches it. Its constructor omits `clientThrow`, so it is client-visible, unlike the rest of the authentication subsystem's exceptions. See `doc/authentication.md`. |
| `TomLoginFailure` | The closed set a client switches on: `accountProblem`, `secondFactorRequired`, `secondFactorInvalid`, `rateLimited`, `providerError`. Coarser than the `key` on purpose — there is no `badCredentials`/`unknownUser`/`accountLocked`, because naming which of the three it was is a user-enumeration oracle. |
| `tomErrorEnvelope` | Renders any error into the wire error body. Reports `errorType` always, adds `errorKey`/`uuid`/`autoLog`/`requestUuid` for a `TomException`, `clientThrow` for a `TomServerException` and `loginFailure` for a `TomLoginException`. A field is **absent rather than null** when the error does not carry it, so its presence tells a client where the error came from. |

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

See [`doc/little_things.md`](../../../../doc/little_things.md) for the isolate
attribution, the zone-based request correlation and the shape of the error
envelope, and `example/little_things/little_things_example.dart` for a
connection-free walkthrough that checks its own results — including that one
`on TomServerException` clause reaches every server error, and that the login
subclass arrives carrying its reason.
`test/little_things_test.dart` covers the module; `test/examples_test.dart`
runs the example and `test/readme_quick_start_test.dart` runs the snippet above,
so neither can drift away from the code.
`test/server_exception_family_test.dart` holds the package to that "every": it
scans the class declarations under `lib/src/tomserver/` and fails on one that
reaches the kernel's `TomException` without passing through
`TomServerException`, so a new exception is covered the moment it is declared
rather than when someone remembers to list it.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
