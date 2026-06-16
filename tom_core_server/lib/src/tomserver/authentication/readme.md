# authentication

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Server-side login. A `TomAuthenticationService` verifies credentials and returns
a `TomAuthenticationInfo` pairing the authenticated `TomPrincipal` with its
access-control definition. `TomAuthenticationServer` drives the flow (including
the optional second factor via `Tom2FAService`); `TomDummyAuthenticationService`
is a no-op implementation for tests and bring-up that accepts any non-`"GUEST"`
user.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthenticationService` | Abstract contract: `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData)`. |
| `TomAuthenticationInfo` | Successful outcome: the authenticated `principal` plus its `acd` (access-control definition). |
| `TomAuthenticationData` | The login attempt: `username` + `key` (credential) plus the org/app/process/locale/client context. |
| `TomAuthenticationServer` | Orchestrates pass-1 / pass-2 authentication and the 2FA handshake. |
| `Tom2FAService` · `Tom2FAAdaptor` | Optional second-factor contract and adaptor. |
| `TomDummyAuthenticationService` | No-op service that authenticates any non-`"GUEST"` user (tests / bring-up). |
| `LoginException` | A `TomServerException` raised on failed authentication. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // One login attempt carries the user plus its org/app/locale context.
  final data = TomAuthenticationData(
    username: 'alice',
    key: 'secret',
    organization: 'acme',
    application: 'todo',
    process: 'login',
    language: 'en',
    country: 'US',
    timezone: 'UTC',
    client: 'web',
  );

  // The dummy service authenticates any non-"GUEST" user — handy for tests.
  final TomAuthenticationService service = TomDummyAuthenticationService();
  final info = await service.authenticateUser(data);

  print(data.username);                 // alice
  print(info.principal.runtimeType);    // the authenticated TomPrincipal
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
