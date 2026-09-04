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
| `TomUserPreferencesErrorHandler` | Maps `preferences.not_found` to a `404` and `preferences.key.invalid` to a `400` — and no other key to anything. Everything else stays opaque, so a client can tell "you have no such preference" and "you sent a key that is not a key" from "the server is broken", instead of papering an outage over with a default or retrying its own bad request. |

## Quick start

Three things have to be in place before the store will answer, and all three
fail at the *bootstrap* line rather than at the call you were trying to make —
so they are shown here rather than left to the reader to rediscover.

```dart
import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

// Your own package's generated registration — the one whose build covers
// `TomUserPreference`.
import 'main.reflection.dart';

Future<void> main() async {
  // 1. Reflection first. TomUserPreferenceRepository reads the entity's
  //    annotations through its class mirror *in its constructor*, so without
  //    this the bean line below throws
  //    `annotation_analyzer.analyse_persistent_type.mirror_not_found`.
  initializeReflection();

  // 2. A datasource under the name the entity declares, `main`. The repository
  //    resolves it in its constructor too — not on first query — so an
  //    unregistered name throws
  //    `crud_repository.constructor.datasource_not_registered` at construction,
  //    long before any preference is read.
  await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
    'main': <String, dynamic>{
      'type': 'mariadb',
      'host': 'localhost',
      'port': 3306,
      'username': 'todo',
      'password': 'secret',
      'databaseName': 'todo',
    },
  });

  // Install the store once, at bootstrap.
  TomBean.withType(
    TomUserPreferences,
    TomUserPreferences(TomUserPreferenceRepository()),
  );

  // 3. A principal. The caller is the zone's principal — never an argument —
  //    and outside a zone that carries one, `set` and `getOr` both throw
  //    `preferences.no_principal`. A server establishes this zone per request
  //    from the authenticated principal; `principal` here is that same
  //    TomPrincipal, which a script has to supply itself.
  await runZoned(() async {
    final preferences = TomUserPreferences.resolve()!;
    await preferences.set(TomUserPreferenceKeys.timezone, 'Europe/Berlin');

    final timezone = await preferences.getOr(
      TomUserPreferenceKeys.timezone,
      'UTC',
    );
    print(timezone); // Europe/Berlin
  }, zoneValues: <Object, Object?>{TomPrincipal: principal});
}
```

> **Needs your package's generated reflection, a live database and a
> principal.** `main.reflection.dart` is written by `dart run build_runner
> build` in *your* package, the datasource in step 2 opens a real socket, and
> `principal` stands for the `TomPrincipal` a server would have authenticated —
> so this is a sequence to build into an application rather than a program to
> paste and run. The three preconditions are exactly what makes it worth showing
> whole: each one fails at bootstrap with a message that does not obviously
> point at the missing step.

The table the second step connects to is created by the framework migration
`[1]-create_tom_user_preference.sql`, which is untagged so it applies in every
environment. `test/user_preferences_db_test.dart` runs this same sequence
against a live MariaDB — its `asSession` helper is the `runZoned` above, and
its `setUpAll` is steps 1 and 2.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
