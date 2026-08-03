# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Server-stored per-principal preferences: a `tom_user_preference` table, a typed
service over it, and the four `/preferences/*` endpoints that let a device reach
it. The keys, the wire DTOs and the value codec are the kernel's
(`tom_core_kernel` `preferences` module); this module is the *store*.

Authorization is the entity's row scope, not a handler check.
`@TomDbScope(field: 'principal_id', scope: 'owner')` makes the repository AND
the caller's own id into every read and reject every write that would touch
another principal's row — so one principal reading another's preferences is not
rejected, the query simply never selects the row. That is why no URI carries a
principal: there is nothing to address but your own.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomUserPreference` | The persisted row — `@TomDbTable('tom_user_preference')` with the `owner` row scope on `principal_id`; `toDto()` renders it for the wire in UTC. |
| `TomUserPreferenceRepository` | The CRUD repository for that entity. |
| `TomUserPreferences` | The service: typed `get` / `set` / `getOr` / `read` / `all` / `remove` for *the caller*, plus `getFor` for the login path. Installed as a bean. |
| `TomUserPreferenceException` | Raised when an operation cannot identify the caller. |
| `TomUserPreferencesServer` | The `@TomApiImplementation` behind `tomUserPreferencesApi`. |
| `TomUserPreferencesErrorHandler` | Maps `preferences.not_found` — and only that key — to a `404`. Everything else stays opaque, so a client can tell "you have no such preference" from "the server is broken" instead of papering an outage over with a default. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // Install the store once, at bootstrap.
  TomBean.withType(TomUserPreferences, TomUserPreferences(TomUserPreferenceRepository()));

  // Inside a request, the caller is the zone's principal — never an argument.
  final preferences = TomUserPreferences.resolve()!;
  await preferences.set(TomUserPreferenceKeys.timezone, 'Europe/Berlin');

  final timezone = await preferences.getOr(TomUserPreferenceKeys.timezone, 'UTC');
  print(timezone); // Europe/Berlin
}
```

The table is created by the framework migration
`[1]-create_tom_user_preference.sql`, which is untagged so it applies in every
environment.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
