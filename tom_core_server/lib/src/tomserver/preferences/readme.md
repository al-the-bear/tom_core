# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Server-stored per-principal preferences: a `tom_user_preference` table, a typed
service over it, the six `/preferences/*` endpoints that let a device reach it,
and a `tom_preference_default` table of deployment and role defaults beneath
every principal's own values. The keys, the wire DTOs and the value codec are the kernel's
(`tom_core_kernel` `preferences` module); this module is the *store*.

Authorization is the entity's row scope, not a handler check.
`@TomDbScope(field: 'principal_id', scope: 'owner')` makes the repository AND
the caller's own id into every read and reject every write that would touch
another principal's row — so one principal reading another's preferences is not
rejected, the query simply never selects the row. That is why no URI carries a
principal: there is nothing to address but your own.

Under a key a principal has not written, the list and the read answer a
**default**: the default of a role the principal holds (the highest
`precedence`, then the role name in code-unit order), else the deployment's.
`TomUserPreferenceDto.origin` says which. Defaults are written by the server
(`TomPreferenceDefaults`, an administrative service with no endpoint) and never
copied into a principal's rows, so deleting a principal's own value brings the
default back.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomUserPreference` | The persisted row — `@TomDbTable('tom_user_preference')` with the `owner` row scope on `principal_id`; `toDto()` renders it for the wire in UTC. |
| `TomUserPreferenceRepository` | The CRUD repository for that entity. |
| `TomUserPreferences` | The service: typed `get` / `set` / `getOr` / `read` / `all` / `remove` / `clear` for *the caller*, `setAllEncoded` for the bulk write (all or none, in one transaction), plus `getFor` for the login path. `all` and `read` include the defaults beneath the caller's own values; `all` takes an optional `TomPageRequest` for a server-internal caller, cut from the key-ordered merged list; the wire returns the list whole, because the store is bounded. Writes go through `TomSqlDatasourceRepository.saveByKey` on `(principalId, preferenceKey)`, one statement. Installed as a bean; reads its defaults from the `defaults` argument or the `TomPreferenceDefaults` bean. |
| `TomPreferenceDefault` | The persisted default — `@TomDbTable('tom_preference_default')`, no row scope; `scopeKind` / `scopeName` / `preferenceKey` are its identity, `precedence` orders role defaults; `toDto()` renders it with `origin` `role` or `deployment`. |
| `TomPreferenceDefaultScope` | `deployment` or `role` — whom a default applies to. |
| `TomPreferenceDefaultRepository` | The CRUD repository for that entity. |
| `TomPreferenceDefaults` | The administrative service over the defaults: `setForDeployment` / `setForRole` (with `precedence`) / `removeForDeployment` / `removeForRole` / `all`, and `effectiveFor(roles)` / `effectiveValue(key, roles)`, which `TomUserPreferences` reads. Refuses an empty or over-long role (`preferences.default.invalid_role`). Installed as a bean; no endpoint ships for it. |
| `TomUserPreferenceException` | Raised when an operation cannot identify the caller, or when a write would add a preference beyond the principal's ceiling of 256 (`preferences.limit.exceeded`). |
| `TomUserPreferencesServer` | The `@TomApiImplementation` behind `tomUserPreferencesApi`. |
| `TomUserPreferencesErrorHandler` | Maps `preferences.not_found` to a `404`, `preferences.key.invalid`, every `preferences.encoded.*` refusal and `preferences.bulk.malformed` to a `400`, and `preferences.limit.exceeded` to a `409` — and no other key to anything. Everything else stays opaque, so a client can tell "you have no such preference", "you sent a key or value that cannot be stored" and "you hold as many preferences as you may" from "the server is broken", instead of papering an outage over with a default or retrying its own bad request. |

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
  TomBean.withType<TomUserPreferences>(
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

> **This is the deployment sequence, and it opens a real socket.**
> `main.reflection.dart` is written by `dart run build_runner build` in *your*
> package, the datasource in step 2 connects, and `principal` stands for the
> `TomPrincipal` a server would have authenticated — so it is a sequence to
> build into an application rather than a program to paste and run. The three
> preconditions are what make it worth showing whole: each fails at bootstrap
> with a message that does not obviously point at the missing step.
>
> To *run* the same sequence, see the example below — it substitutes the table
> and nothing else.

The tables the second step connects to are created by the framework migrations
`example/preferences/migrations/tenant/default/main/[1]-create_tom_user_preference.sql`
and `[2]-create_tom_preference_default.sql` (PostgreSQL forms under
`migrations_postgresql/`), which are untagged so they apply in every
environment. A deployment with defaults also installs the defaults bean:

```dart
TomBean.withType<TomPreferenceDefaults>(
  TomPreferenceDefaults(TomPreferenceDefaultRepository()),
);
```

```bash
dart run example/preferences/preferences_example.dart
```

`example/preferences/preferences_example.dart` runs the sequence above in
fourteen checked steps — the bean's deliberate `null` before it is installed,
the refusals outside a request zone, a scalar and a `@tomReflector` object
written and read back, a type mismatch, a second principal seeing none of the
first's, the per-caller list ordered by key, the endpoint's encoded write path,
a deployment and a role default beneath the caller's own values together with a
bulk write refused whole and then written whole, and the migrations on disk.
**One thing is substituted**: the tables, by in-memory stand-ins behind the
repository interface, so the program needs no database. It says so where it
matters rather than implying otherwise — the entity's
`@TomDbScope(field: 'principal_id', scope: 'owner')` is enforced by the
*repository*, and so are the single-statement upsert and the bulk write's
transaction, so none of them is something a map can demonstrate and none is
claimed.

They belong to `test/preferences_db_test.dart`, which runs the deployment
sequence against a live MariaDB or PostgreSQL — its `asSession` helper is the `runZoned`
above and its `setUpAll` is steps 1 and 2 — and to
`test/preferences_defaults_db_test.dart`, which covers the defaults and the bulk
write against a live database.
`test/preferences_service_test.dart`, `test/preferences_key_test.dart` and
`test/preferences_dto_test.dart` cover the module without a database,
`test/preferences_endpoints_test.dart` the HTTP surface, and
`test/preferences_roundtrip_db_test.dart` the store-and-read-back path.

See [`doc/preferences.md`](../../../../doc/preferences.md) for the key registry,
the principal scoping and the endpoint surface.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
