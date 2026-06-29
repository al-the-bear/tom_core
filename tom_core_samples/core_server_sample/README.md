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
13. [What is built](#13-what-is-built)

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
├── bin/
│   ├── server_start.dart                # TomServer boot + reflection root
│   └── server_start.reflection.dart     # generated (committed)
├── lib/
│   ├── core_server_sample.dart          # public barrel
│   └── src/
│       ├── persistence/
│       │   ├── todo_records.dart        # @TomDbColumn records + repositories
│       │   └── todo_mapping.dart        # domain <-> record (pure, tested)
│       ├── auth/
│       │   └── todo_authorization.dart  # four-state field authorizer
│       └── endpoints/
│           └── todo_endpoints.dart      # @tomService HTTP API (3 public GETs)
├── example/
│   └── run_all_examples.dart            # DB-free mapping + authorization demo
├── test/
│   └── todo_persistence_mapping_test.dart
├── database_migrations/todo_db/todo_schema/
│   ├── [000]-todo_core_schema.sql       # tables + seed rows
│   └── [001]-todo_authz_grants.sql      # tom_resource_grant + seed grants
├── assets/
│   ├── datasources_default.yaml         # todo_db + main datasources
│   ├── config-resources_default.yaml
│   └── config-resources_dev.yaml
├── docker-compose.yaml                  # bundled MariaDB
├── .env.example                         # copy to .env
├── build.yaml                           # reflection generate_for: bin/server_start.dart
└── reflection_generation.sh
```

The `bin/server_start.dart` entrypoint boots `TomServer` and doubles as the
reflection-generation root; it is described in [§9](#9-the-live-server-boot).

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

`bin/server_start.dart` is the smallest single-isolate `TomServer` boot that
serves the API against the bundled Docker MariaDB. It follows the
`tom_uam_server` boot sequence, trimmed to what public (unauthenticated) JSON
endpoints need. In order, `main()`:

1. Sets the standalone platform: `TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils)`.
2. Initialises reflection (`initializeReflection()`), the environment runtime
   (`initializeRuntime()`), and the config-resource provider
   (`initializeServerResources()`).
3. Builds the `ServerConfiguration` (plain HTTP, single isolate, bind any IP).
4. Loads datasource config from `assets/datasources_default.yaml` and registers
   it via `TomDataSourceInfo.initializeDatasourceInfo(...)`. The `mariadb`
   driver is auto-discovered through the `tom_core_server` barrel.
5. Initialises the bean context (`initializeBeanContext`), which instantiates
   the `@tomComponent` endpoint server.
6. Runs migrations: `TomDbMigrations.migrateDatabases(...)`.
7. Starts HTTP: `TomServer(config).start()`.

The JWT / auth-server / worker-pool machinery `tom_uam_server` also wires is
intentionally omitted — the endpoints are `@TomPublicAccess`, so none of it is
exercised. (Authenticated, per-principal field grading is the natural next step;
the four-state resolver it would use is already built and tested.) That next
step is realized in full by the
[**Advanced Tom Core Full-Stack Sample**](../README_advanced_sample.md), which
wires a JWT auth server, bearer-validated app endpoints, and per-principal
four-state grading over the wire — this sample stays public and read-only for
teaching.

### The endpoints

`lib/src/endpoints/todo_endpoints.dart` declares `@tomService TodoApiService`
(the contract) and its `@tomComponent TodoApiServer` (the implementation). Each
method carries `@TomPublicAccess()` and a `@TomEndpoint(methods: [TomHttpMethod.get],
uri: …, produces: TomMimeType.json)`. Three no-parameter `GET`s, each proving one
layer of the stack:

| Endpoint              | Proves                                                        |
| --------------------- | ------------------------------------------------------------ |
| `/health`             | the server boots and routes                                  |
| `/todos`              | the DB persistence round-trip (`todoItemRepository.findAll`) |
| `/todos/field-states` | four-state authorization resolved **from DB grants**         |

`/todos/field-states` loads every `TomResourceGrant` (via a
`TomSqlDatasourceRepository<TomResourceGrant, int>`), folds the grants per role
through `TodoFieldAuthorizer.fromGrants`, and returns each role's resolved
per-field `TomAuthState` — so a client knows which fields to render editable,
read-only, greyed, or hidden.

### Running it

Once the database is up (§8):

```sh
dart run bin/server_start.dart
# in another shell:
curl -s localhost:8080/health
curl -s localhost:8080/todos
curl -s localhost:8080/todos/field-states
```

`/todos/field-states` returns the four-state table from [§5](#5-four-state-authorization)
straight out of the database:

```json
{
  "owner":  {"todo.item.title":"full","todo.item.done":"full","todo.item.priority":"full","todo.item.assigneeId":"full"},
  "member": {"todo.item.title":"full","todo.item.done":"full","todo.item.priority":"none","todo.item.assigneeId":"read"},
  "viewer": {"todo.item.title":"read","todo.item.done":"disabled","todo.item.priority":"read","todo.item.assigneeId":"read"}
}
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
  port: 3306                        # literal int, not ${...} — see below
  databaseName: ${TODO_DB_NAME:todo_db}

main:
  delegateTo: todo_db               # the framework's grant store, same DB
```

`port` is a **literal int**, not a `${...}` substitution: the substitution
always yields a string, and the MariaDB datasource binds `port` to an `int`
field, so a substituted `"3306"` fails reflection. The other keys are strings
and substitute cleanly.

The `main` datasource is where the framework binds its graded-authorization
store (`TomResourceGrant`). Rather than duplicate the connection block it
`delegateTo`s `todo_db`, so one physical database backs both the application
tables and the `tom_resource_grant` grants.

Copy `.env.example` to `.env` and adjust. It feeds both `docker-compose.yaml`
and the runtime datasource loader.

---

## 11. Reflection generation

The reflected types must be discovered so the persistence layer can map records
to SQL and the endpoint pipeline can instantiate the service. The
reflection-generation root is the live-boot entrypoint itself,
`bin/server_start.dart` (configured in `build.yaml`): the generator follows its
import graph to capture the config class, the endpoint service, the persistence
records, and — transitively through the `tom_core_server` barrel — the MariaDB
driver, the migration adaptor, and `TomResourceGrant`.

Regenerate the reflection code after changing any reflected shape (a record's
fields, the config class, an endpoint signature):

```sh
./reflection_generation.sh   # dart run tom_reflection_generator --nested
```

The generated `bin/server_start.reflection.dart` is committed and imported by
the boot entrypoint. The annotations are plain const metadata, so the package is
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

The live endpoint + persistence round-trip against Docker MariaDB is verified by
booting the server and curling the three endpoints (§9) — it is built, not
gated.

---

## 13. What is built

**Database-free, `analyze`-clean, and unit-tested (no database required):**

- the relational persistence records and their repositories
  (`todo_records.dart`);
- the pure domain ↔ record mapping (`todo_mapping.dart`) with full unit tests;
- the four-state field authorizer (`todo_authorization.dart`);
- the runnable database-free example (`run_all_examples.dart`);
- the full infrastructure: Docker compose, migrations (schema + grants),
  datasource/config assets, `.env.example`, reflection wiring.

**Live, verified against the bundled Docker MariaDB:**

- the `bin/server_start.dart` `TomServer` boot entrypoint;
- the `@tomService` HTTP endpoints and their JSON responses
  (`todo_endpoints.dart`);
- the end-to-end persistence round-trip (`/todos`) and four-state authorization
  resolved from DB grants (`/todos/field-states`).

Everything that can be verified without a live database is unit-tested; the live
boot is exercised by `docker compose up -d db && dart run bin/server_start.dart`
and the three `curl`s in [§9](#9-the-live-server-boot).

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kits on display:** [`tom_core_server`](../../tom_core_server/README.md)
  (the server stack) on top of [`tom_core_kernel`](../../tom_core_kernel/README.md)
  (security, persistence, reflection)
- **Shared model:** [`todo_domain`](../todo_domain/readme.md) — the reflected
  entities this server persists and serves
- **Sibling sample:** [`core_client_sample`](../core_client_sample/README.md) —
  the Flutter client whose live read path consumes this server's three public
  `GET` endpoints
- **Secured, full-stack successor:**
  [`README_advanced_sample.md`](../README_advanced_sample.md) — the advanced
  suite that takes this read-only public server to a JWT-secured, two-server
  full stack with write endpoints and per-principal field grading
