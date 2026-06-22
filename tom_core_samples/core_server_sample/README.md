# core_server_sample

A worked example of a **Tom Core backend**: a small todo-management API built on
`tom_core_server`. It persists the shared `todo_domain` model to MariaDB,
authenticates users, and grades individual field access with the framework's
**four-state authorization** schema.

The sample is split deliberately into two halves:

- a **database-free core** — the domain ↔ record mapping and the four-state
  field authorizer — that is `analyze`-clean and unit-tested **without** a
  server or a database; and
- a **live boot** — the `tom_core_server` wiring that binds that core to HTTP
  endpoints and a real MariaDB, exercised against the bundled Docker compose
  stack.

This README is the guided tour of both. If you only want to read code, start
with `lib/src/persistence/todo_mapping.dart` and
`lib/src/auth/todo_authorization.dart` — everything else exists to put those two
files on the wire.

---

## Table of contents

1. [Why this sample exists](#1-why-this-sample-exists)
2. [The two models, and the boundary between them](#2-the-two-models-and-the-boundary-between-them)
3. [Persistence records](#3-persistence-records)
4. [The mapping layer](#4-the-mapping-layer)
5. [Four-state authorization](#5-four-state-authorization)
6. [Project layout](#6-project-layout)
7. [Running the database-free core](#7-running-the-database-free-core)
8. [The database and migrations](#8-the-database-and-migrations)
9. [The live server boot](#9-the-live-server-boot)
10. [Configuration and environment](#10-configuration-and-environment)
11. [Reflection generation](#11-reflection-generation)
12. [Testing](#12-testing)
13. [What is built vs. what is gated](#13-what-is-built-vs-what-is-gated)

---

## 1. Why this sample exists

`tom_core_kernel` gives you an **observable domain model** (the `TomClass`
value-holder objects that drive client forms). `tom_core_server` gives you an
**object-persistence layer**, an **endpoint pipeline**, **JWT authentication**,
and **graded authorization**. Each of those is documented in isolation. What is
not obvious from the per-feature docs is how they fit together in one running
service — in particular, how an observable form model becomes relational rows,
and how a four-state access decision made on the server reaches the client.

This sample answers exactly those two questions, against the same `todo_domain`
model that the Flutter client samples consume. It is intentionally small —
four entities, one resource graded across four fields — so the wiring is
visible rather than buried.

---

## 2. The two models, and the boundary between them

The single most important idea in this sample is that **there are two shapes of
the todo data, and they are not the same shape**.

### The domain model (`todo_domain`)

The shared entities — `User`, `Project`, `TodoList`, `TodoItem` — extend
`TomClass`. Their fields are **observable value holders** (`TomString`,
`TomBool`, `TomList`, `TomNDateTime`) and their ids are **display strings**.
This is a model built for **client-side form binding**: a text field binds to a
`TomString`, a checkbox to a `TomBool`, and the UI observes changes
automatically. Containment is modelled by nested collections — a `Project` holds
a `TomList` of `TodoList`, each `TodoList` holds a `TomList` of `TodoItem`.

That shape is wrong for a relational database. You cannot meaningfully put a
`TomList<TodoItem>` in a column, integer primary keys are not display strings,
and a row needs an explicit foreign key where the domain has containment.

### The persistence model (this package)

So the server keeps its **own** relational view of the same data:
`TodoUserRecord`, `TodoProjectRecord`, `TodoListRecord`, `TodoItemRecord`. These
are plain Dart classes with typed fields, an **integer primary key**,
**foreign-key columns**, and no nested collections — annotated with
`@TomDbColumn` for the object-persistence layer.

### The boundary

`lib/src/persistence/todo_mapping.dart` is the **one place** the two shapes
meet. It is a set of pure, total functions — no I/O, no database — so it can be
unit-tested directly. Keeping the database mapping here (rather than annotating
the domain entities) is a deliberate design decision: the domain model stays the
client's clean observable form model, the records stay the server's relational
model, and the conversion between them is explicit and tested. (This resolves
the design blueprint's open question about where the DB annotations live, in the
only direction the realised domain model allows — see
`core_server_sample_design.md`.)

```
  todo_domain (TomClass, observable, string ids, nested)
        │            ▲
   *ToRecord    *FromRecord          ← todo_mapping.dart (pure, tested)
        ▼            │
  *Record (plain fields, int PK, FK columns)   ← todo_records.dart (@TomDbColumn)
        │            ▲
   repository.save   repository.findById        ← TomSqlDatasourceRepository
        ▼            │
                  MariaDB
```

---

## 3. Persistence records

`lib/src/persistence/todo_records.dart` defines the four DB-mapped records. Each
is annotated for reflection and persistence:

```dart
@tomReflector
@TomDbTable(datasource: 'todo_db', table: 'todo_items', primaryKeyField: 'id')
class TodoItemRecord {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id; // null until first persisted -> INSERT, not UPDATE

  @TomDbColumn(columnName: 'title')       String? title;
  @TomDbColumn(columnName: 'done')        bool?   done;
  @TomDbColumn(columnName: 'priority')    String? priority; // enum name
  @TomDbColumn(columnName: 'assignee_id') int?    assigneeId; // FK, null = unassigned
  @TomDbColumn(columnName: 'list_id')     int?    listId;     // FK to owning list
  // …
}
```

Three things are worth calling out:

- **`@TomDbTable.datasource` is `'todo_db'`** — that string must match both the
  datasource key in `assets/datasources_default.yaml` *and* the migration folder
  name under `database_migrations/`. That is how `TomDbMigrations` matches a
  schema tree to a datasource.
- **The primary key is `int?`**, nullable. A `null` id means "not yet
  persisted", which the repository reads as INSERT; a non-null id means UPDATE.
- Each record has a `TomSqlDatasourceRepository<TRecord, int>` subclass and a
  process-wide singleton instance (e.g. `todoItemRepository`). The repository
  provides `save`, `findById`, `findAll`, `delete`, `count`, and query methods.

Column names use `snake_case` to match the SQL schema; the Dart fields use
`camelCase`. The `@TomDbColumn(columnName: …)` annotation is the bridge.

---

## 4. The mapping layer

`lib/src/persistence/todo_mapping.dart` provides a `*ToRecord` / `*FromRecord`
pair for each entity. They are pure and total:

```dart
// Domain -> row. The owning list id is supplied because the domain models
// membership by containment, but the row needs an explicit foreign key.
TodoItemRecord itemToRecord(TodoItem item, {required int listId});

// Row -> observable domain entity.
TodoItem itemFromRecord(TodoItemRecord record);
```

The interesting cases the tests pin down:

- **Unpersisted entities map to a `null` primary key.** An entity whose display
  id is the empty string has never been saved, so `userToRecord(user).id` is
  `null` — the repository will INSERT.
- **Unknown stored enum tokens degrade to the default.** A row whose `priority`
  column holds a bogus string rebuilds as `TodoPriority.medium`, because the
  domain's typed accessor (`priorityValue`) is lenient by design.
- **A `null` role defaults to `member`** on the way out of the database — the
  least-privileged sensible default.
- **Nested collections are not part of a row.** `projectToRecord` does not touch
  `Project.lists`; those persist as their own `TodoListRecord` rows and are
  reattached on load.

Because none of this needs a database, it is the bulk of what
`test/todo_persistence_mapping_test.dart` covers.

---

## 5. Four-state authorization

Classic authorization is binary: you may edit a field, or you may not. Tom Core
generalises that to **four states**, because real applications distinguish
"can't touch this" from "can't even see this":

| `TomAuthState` | UI rendering        | Meaning                                   |
| -------------- | ------------------- | ----------------------------------------- |
| `full`         | editable            | full read + write                         |
| `read`         | shown, read-only    | visible, not editable                     |
| `disabled`     | shown, greyed-out   | visible as a control, but inoperative     |
| `none`         | hidden              | not shown at all                          |

The server stores per-`(role, resourceKey)` grants as `TomResourceGrant` rows
in the canonical `tom_resource_grant` table (its DDL is reused verbatim from the
framework, so the sample and `tom_core_server` agree on the storage shape). At
request time the server folds the grants for the principal's role into a
`TomGradedAccessControlInformation` and resolves the effective state per field.

`lib/src/auth/todo_authorization.dart` is the sample's thin wrapper over that:

```dart
final authorizer = TodoFieldAuthorizer.fromGrants(grantsForRole);
authorizer.stateOf(TodoItemResourceKeys.priority); // -> TomAuthState
authorizer.canEdit(TodoItemResourceKeys.title);     // full?
authorizer.canSee(TodoItemResourceKeys.assigneeId); // not none?
```

`TodoItemResourceKeys` names the four gradable item fields (`todo.item.title`,
`todo.item.done`, `todo.item.priority`, `todo.item.assigneeId`) — the same keys
the migration seeds. An ungranted key resolves to `none` (hidden), the
closed-safe default: a field you forgot to grant is invisible, not editable.

The seeded demo roles in `[001]-todo_authz_grants.sql` exercise all four states:

| Field          | owner | member          | viewer            |
| -------------- | ----- | --------------- | ----------------- |
| `title`        | full  | full            | read              |
| `done`         | full  | full            | **disabled**      |
| `priority`     | full  | **none** (hidden) | read            |
| `assigneeId`   | full  | read            | read              |

`example/run_all_examples.dart` builds those exact grants in memory and prints
the resolved state for every role and field — a database-free way to see the
table above come out of the actual resolver.

---

## 6. Project layout

```
core_server_sample/
├── lib/
│   ├── core_server_sample.dart          # public barrel
│   └── src/
│       ├── persistence/
│       │   ├── todo_records.dart        # @TomDbColumn records + repositories
│       │   └── todo_mapping.dart        # domain <-> record (pure, tested)
│       ├── auth/
│       │   └── todo_authorization.dart  # four-state field authorizer
│       └── reflection_entry.dart        # reflection-generation root (not runtime)
├── example/
│   └── run_all_examples.dart            # DB-free mapping + authorization demo
├── test/
│   └── todo_persistence_mapping_test.dart
├── database_migrations/todo_db/todo_schema/
│   ├── [000]-todo_core_schema.sql       # tables + seed rows
│   └── [001]-todo_authz_grants.sql      # tom_resource_grant + seed grants
├── assets/
│   ├── datasources_default.yaml         # todo_db datasource (env-substituted)
│   ├── config-resources_default.yaml
│   └── config-resources_dev.yaml
├── docker-compose.yaml                  # bundled MariaDB
├── .env.example                         # copy to .env
├── build.yaml                           # reflection generate_for
└── reflection_generation.sh
```

The `bin/` server entrypoint that boots `TomServer` is described in
[§9](#9-the-live-server-boot); see [§13](#13-what-is-built-vs-what-is-gated) for
its status.

---

## 7. Running the database-free core

No database, no server, no setup beyond `pub get`:

```sh
dart pub get
dart run example/run_all_examples.dart
dart test
```

`run_all_examples.dart` prints the mapping round-trip and the full four-state
resolution for the three demo roles. `dart test` runs the mapping tests. Both
are green and `dart analyze` reports no issues.

---

## 8. The database and migrations

The schema lives under `database_migrations/todo_db/todo_schema/` and is
consumed **twice**:

1. **First-boot bootstrap** — `docker-compose.yaml` mounts the tree into
   MariaDB's `docker-entrypoint-initdb.d`, so a fresh container runs it on
   creation.
2. **Runtime migration** — `TomDbMigrations.migrateDatabases()` reads the same
   tree at server start and applies incremental migrations.

One SQL tree, two consumers — the `tom_uam_server` pattern. The folder name
(`todo_db`) **must** equal the datasource key so migrations resolve to the right
connection.

`[000]-todo_core_schema.sql` creates `todo_users`, `todo_projects`,
`todo_lists`, `todo_items` and seeds a demo user, project, list and two items,
so the first `curl` returns non-empty without a write.
`[001]-todo_authz_grants.sql` creates `tom_resource_grant` and seeds the grants
from the table in [§5](#5-four-state-authorization).

Bring the database up with:

```sh
cp .env.example .env
docker compose up -d db
```

---

## 9. The live server boot

The live server follows the established `tom_uam_server` boot sequence. In
order, the entrypoint:

1. Sets the standalone platform: `TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils)`.
2. Initialises the runtime: `initializeReflection()`, `initializeRuntime()`,
   `initializeServerResources()`.
3. Loads datasource config from `assets/datasources_default.yaml` and registers
   it via `TomDataSourceInfo.initializeDatasourceInfo(...)`. The `mariadb`
   driver is auto-discovered.
4. Configures JWT (`TomJwtConfiguration`) and the authentication server
   (`TomAuthenticationServer`).
5. Initialises the bean context (`initializeBeanContext`).
6. Runs migrations: `TomDbMigrations.migrateDatabases(...)`.
7. Starts HTTP: `TomServer(config).start()`.

Endpoints are declared with `@tomService` on a handler class and
`@TomEndpoint(methods: [TomHttpMethod.post], uri: …, consumes: TomMimeType.json,
produces: TomMimeType.json)` on each method, with access annotated by
`@TomPublicAccess` / `@TomAuthenticatedAccess` / `@TomGuestAccess`. A handler
receives the authenticated `TomPrincipal`, loads the item via
`todoItemRepository`, builds a `TodoFieldAuthorizer` from the principal's role
grants, and returns the item together with its per-field states — so the client
knows which fields to render editable, read-only, greyed, or hidden.

Once the database is up (§8) the live server is started with:

```sh
dart run bin/server_start.dart
```

---

## 10. Configuration and environment

Configuration is environment-overlaid. `assets/config-resources_default.yaml`
holds the base; `assets/config-resources_<env>.yaml` is merged on top, selected
by the `env` variable (`prod` | `int` | `dev`).

`assets/datasources_default.yaml` uses `${VAR:default}` substitution so the same
file works in Docker and on the host:

```yaml
todo_db:
  type: mariadb
  username: ${TODO_DB_USER:app}
  password: ${TODO_DB_PASSWORD:app}
  host: ${TODO_DB_HOST:localhost}   # `db` inside the compose network
  port: ${TODO_DB_PORT:3306}
  databaseName: ${TODO_DB_NAME:todo_db}
```

Copy `.env.example` to `.env` and adjust. It feeds both `docker-compose.yaml`
and the runtime datasource loader.

---

## 11. Reflection generation

The persistence records are reflected so the persistence layer can map them to
SQL. `lib/src/reflection_entry.dart` exposes a `main()` that touches each record
— the reflection generator follows the import graph from a file with a `main()`
to discover every `@tomReflector` type. It is **not** used at runtime.

Regenerate the reflection code after changing a record's fields:

```sh
./reflection_generation.sh   # dart run tom_reflection_generator --nested
```

The generated `reflection_entry.reflection.dart` is what the live server imports
at boot. The annotations are plain const metadata, so the package is
`analyze`-clean **without** running the generator — you only need it for the
live boot.

---

## 12. Testing

```sh
dart test
```

`test/todo_persistence_mapping_test.dart` covers the mapping boundary without a
database:

- user round-trip; unpersisted → null PK; null role → `member`
- item round-trip with the owning list id; unknown priority → `medium`;
  unassigned → null assignee key
- project and list foreign-key round-trips

The domain entities are observable `TomClass`es, so the suite calls
`initializeReflection()` in `setUpAll` before constructing any of them; the
records themselves are plain DTOs and need no setup.

The live endpoint + persistence round-trip against Docker MariaDB is the
integration gate (see below).

---

## 13. What is built vs. what is gated

**Built, `analyze`-clean, and unit-tested now (no database required):**

- the relational persistence records and their repositories
  (`todo_records.dart`);
- the pure domain ↔ record mapping (`todo_mapping.dart`) with full unit tests;
- the four-state field authorizer (`todo_authorization.dart`);
- the runnable database-free example (`run_all_examples.dart`);
- the full infrastructure: Docker compose, migrations (schema + grants),
  datasource/config assets, `.env.example`, reflection wiring.

**Documented here and gated on the workspace Docker integration step** (the live
MariaDB round-trip, `readme_and_example_plan` item 28):

- the `bin/` `TomServer` boot entrypoint;
- the HTTP endpoint handlers and their JSON request/response wiring;
- the end-to-end persistence + authorization round-trip against the bundled
  MariaDB.

The split is deliberate: everything that can be verified without a live database
is built and proven, and the live boot is wired against the same documented
`tom_uam_server` pattern, to be exercised when the Docker integration gate runs.
