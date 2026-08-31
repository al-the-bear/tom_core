# core_server_sample

A worked example of a **Tom Core backend**: a small todo-management API built on
`tom_core_server`. It persists the shared `todo_domain` model to MariaDB and
serves the framework's **four-state authorization** grade matrix — the per-role,
per-field access decision — over three public `GET` endpoints.

Authentication is deliberately **not** part of this sample: the endpoints are
`@TomPublicAccess`, so the grading you see is the stored `(role, field)` matrix
rather than a decision made about a logged-in principal. The secured successor
that adds JWT login and per-principal grading is the
[**Advanced Tom Core Full-Stack Sample**](../README_advanced_sample.md).

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
model, and the conversion between them is explicit and tested.

The two obvious alternatives were both rejected for the same reason. **Annotating
the domain entities** with `@TomDbColumn` would put the server's storage shape
into a package the Flutter client also depends on — every column rename would
reach the client, and `todo_domain` would stop building without the server's
persistence layer on its dependency path. **Teaching the persistence layer about
observables** would push the coupling one level down instead, making
`tom_core_server` responsible for a `tom_core_kernel` concern. Either way the
client's model and the server's storage become one thing. The price of the
boundary chosen here is a second class per entity and a mapping function to keep
in step; what it buys is that `todo_domain` depends on `tom_core_kernel` alone
and ships to a Flutter client unchanged.

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
authorizer.stateOf('todo.item.priority');   // -> TomAuthState
authorizer.canEdit('todo.item.title');      // full?
authorizer.canSee('todo.item.assigneeId');  // not none?
```

The variable is named `grantsForRole` because that is a precondition, not a
convention: `fromGrants` ignores `roleName` and unions every row it is handed,
so the caller must filter first. Hand it the whole grant table and every field
is graded by the most permissive role in the system.

A field self-addresses by its own resource key — there is no `*ResourceKeys`
catalogue class (G-RES-6). The four gradable item fields (`todo.item.title`,
`todo.item.done`, `todo.item.priority`, `todo.item.assigneeId`) are just the keys
the migration seeds; `gradableTodoItemKeys` enumerates them for the request-time
fold. An ungranted key resolves to `none` (hidden), the closed-safe default: a
field you forgot to grant is invisible, not editable.

The seeded demo roles in `[001]-todo_authz_grants.sql` exercise all four states:

| Field          | owner | member          | viewer            |
| -------------- | ----- | --------------- | ----------------- |
| `title`        | full  | full            | read              |
| `done`         | full  | full            | **disabled**      |
| `priority`     | full  | **none** (hidden) | read            |
| `assigneeId`   | full  | read            | read              |

`example/run_all_examples.dart` builds those exact grants in memory and prints
the resolved state for every role and field — a database-free way to see the
table above come out of the actual resolver. The table is not merely printed,
though: `test/todo_authorization_test.dart` parses the grades out of
`[001]-todo_authz_grants.sql` and requires the resolver to reproduce the matrix
in [§9](#9-the-live-server-boot) cell for cell, so re-grading a field here
without updating both documents fails `dart test`.

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
│   ├── config_assets.dart                  # shared: reads the config assets
│   ├── documented_authorization.dart       # shared: reads the seeds + matrix
│   ├── todo_persistence_mapping_test.dart  # DB-free mapping unit tests
│   ├── todo_health_config_test.dart        # DB-free: /health's configured title
│   ├── todo_authorization_test.dart        # DB-free: the four-state resolver
│   └── todo_endpoints_integration_test.dart # live endpoints (skips if down)
├── tool/
│   └── run_integration.sh                 # brings the stack up, verifies it
├── database_migrations/todo_db/todo_schema/
│   ├── [000]-todo_core_schema.sql       # tables + seed rows
│   └── [001]-todo_authz_grants.sql      # tom_resource_grant + seed grants
├── assets/
│   ├── datasources_default.yaml         # todo_db + main datasources
│   ├── config-resources_default.yaml
│   └── config-resources_dev.yaml
├── docker-compose.yaml                  # bundled MariaDB
├── .env.example                         # copy to .env; read by compose and the boot
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
resolution for the three demo roles. `dart test` runs the three database-free
suites — mapping, `/health`'s configured title, and the four-state authorizer —
and skips the live one. Both are green and `dart analyze` reports no issues.

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
7. Starts HTTP: `TomServer(config).start()`, then logs the port **and the
   resolved environment** — which overlay won is decided by a `.env` that is not
   visible in the process list, so it is worth naming where anyone will see it.

Underneath steps 2 and 4 sits one piece of wiring that is easy to miss and
breaks quietly when it is absent: the file-level

```dart
final Map<String, String> _environment = TomEnvFile.resolveEnvironment();
```

is the package-root `.env` layered over the OS environment, and it is passed to
every `TomYaml.loadYamlFile` call in the boot and read for the `env` overlay
selector. It has to be explicit because Dart's process environment is read-only
— see [§10](#10-datasources-and-configuration).

The JWT / auth-server / worker-pool machinery `tom_uam_server` also wires is
intentionally omitted — the endpoints are `@TomPublicAccess`, so none of it is
exercised. Authenticated, per-principal field grading is realized in full by the
[**Advanced Tom Core Full-Stack Sample**](../README_advanced_sample.md), which
wires a JWT auth server, bearer-validated app endpoints, and per-principal
four-state grading over the wire — on top of the same four-state resolver this
sample already builds and tests. This sample stays public and read-only for
teaching.

### The endpoints

`lib/src/endpoints/todo_endpoints.dart` declares `@tomService TodoApiService`
(the contract) and its `@tomComponent TodoApiServer` (the implementation). Each
method carries `@TomPublicAccess()` and a `@TomEndpoint(methods: [TomHttpMethod.get],
uri: …, produces: TomMimeType.json)`. Three no-parameter `GET`s, each proving one
layer of the stack:

| Endpoint              | Proves                                                        |
| --------------------- | ------------------------------------------------------------ |
| `/health`             | the server boots, routes, and resolved its configuration     |
| `/todos`              | the DB persistence round-trip (`todoItemRepository.findAll`) |
| `/todos/field-states` | four-state authorization resolved **from DB grants**         |

`/health` answers `{"status": "ok", "app": …}` without touching the database.
The `app` value is **not** a string in the source: it is the `app.title`
configuration key, read through `TomStringConfig` at request time, so the probe
reports the title the *active overlay* configured. Under `env=dev` that is
`Tom Core — Todo API (DEV)`. This is deliberate and is what makes the endpoint
worth more than a constant: it is the one place a client can see which
configuration the server actually resolved, and it is why the live suite can
assert that the `.env` selector reached the wire and not merely the log.

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

These three `curl`s are for reading the API by hand. The same three requests are
made and asserted automatically by `./tool/run_integration.sh` ([§12](#12-testing)),
which is what to run when the question is whether the live path still works.

`/todos/field-states` returns the four-state table from [§5](#5-four-state-authorization)
straight out of the database:

```json
{
  "states": {
    "owner":  {"todo.item.title":"full","todo.item.done":"full","todo.item.priority":"full","todo.item.assigneeId":"full"},
    "member": {"todo.item.title":"full","todo.item.done":"full","todo.item.priority":"none","todo.item.assigneeId":"read"},
    "viewer": {"todo.item.title":"read","todo.item.done":"disabled","todo.item.priority":"read","todo.item.assigneeId":"read"}
  }
}
```

The `states` wrapper is the reflected shape of `TodoFieldMatrixDto` — the wire
type declared in `todo_domain` — not a hand-written envelope; the endpoint
returns the DTO and the pipeline serializes it.

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

main:
  delegateTo: todo_db               # the framework's grant store, same DB
```

`port` substitutes like every other field. The substitution always yields a
string, and the MariaDB datasource parses a string port to the `int` it binds
(G-DB-3) — so both an int literal and a substituted `"3306"` work. The other
keys are strings and substitute cleanly.

The `main` datasource is where the framework binds its graded-authorization
store (`TomResourceGrant`). Rather than duplicate the connection block it
`delegateTo`s `todo_db`, so one physical database backs both the application
tables and the `tom_resource_grant` grants.

Copy `.env.example` to `.env` and adjust. It feeds both `docker-compose.yaml`
and the running server — but by two different routes, and the second one is
wiring the boot has to do explicitly.

Compose reads a `.env` beside it natively. The server cannot: Dart's
`Platform.environment` is read-only, so nothing a program reads out of a `.env`
can be put where `TomYaml`'s default `${VAR:default}` expansion looks. The boot
therefore resolves the file itself, once:

```dart
final Map<String, String> _environment = TomEnvFile.resolveEnvironment();
```

and hands that map to every `TomYaml.loadYamlFile(..., environment: …)` call, as
well as reading the `env` overlay selector out of it. Without that argument the
substitution would silently fall back to the process environment: the database
would move with the `.env` (Compose having read it) while the server kept
dialling `${TODO_DB_PORT:3306}`, and `env=dev` would select the prod overlay.

`resolveEnvironment` layers the `.env` **over** the OS environment, matching how
`TomBaseServerConfiguration` merges it into the configuration keys — so the two
halves of the boot agree about the file. Compose resolves the opposite way
(shell wins), so a variable set in both your shell and the `.env` is the one case
where the server and the container will disagree.

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
./reflection_generation.sh   # dart run tom_reflection_generator (flag-free)
```

The generated `bin/server_start.reflection.dart` is committed and imported by
the boot entrypoint. The annotations are plain const metadata, so the package is
`analyze`-clean **without** running the generator — you only need it for the
live boot.

---

## 12. Testing

The package is verified at two levels, and which one you run decides what you
learn:

```sh
dart test                    # the database-free half
./tool/run_integration.sh    # that half plus the live stack, end to end
```

### Without a database

`test/todo_persistence_mapping_test.dart` covers the mapping boundary without a
database:

- user round-trip; unpersisted → null PK; null role → `member`
- item round-trip with the owning list id; unknown priority → `medium`;
  unassigned → null assignee key
- project and list foreign-key round-trips

The domain entities are observable `TomClass`es, so the suite calls
`initializeReflection()` in `setUpAll` before constructing any of them; the
records themselves are plain DTOs and need no setup.

`test/todo_health_config_test.dart` covers the one *configured* value an
endpoint serves — `/health`'s `app.title` — with no database and no server: it
installs a `TomServerConfigResourceProvider` and calls `TodoApiServer().health()`
directly. Three cases: a title that appears in no file (so only the provider can
have supplied it), the base asset alone, and the base asset with the dev overlay
merged. The third is the one that matters. A hardcoded title would be a copy of
the *default*, so it agrees with the base asset and only ever diverges under an
overlay — the case that looks least worth testing is the only one that can fail.

`test/todo_authorization_test.dart` covers the other half of what the sample
teaches — the four-state grade resolver — also without a database, because
`TodoFieldAuthorizer` takes grants rather than a connection. It pins the four
grades resolving out of stored rows, the closed-safe `none` default for an
ungranted key, the most-permissive merge (order-independently, so a fold that
merely overwrote would fail), and `fieldStates` being *total* over
`gradableTodoItemKeys`. One test exists purely as a trap-marker: `fromGrants`
ignores `roleName` and unions everything handed to it, so the grouping loop in
`fieldStates()` is load-bearing — hand it the whole table and every field is
graded by the most permissive role in the system.

Its last group closes the loop the endpoint actually walks. The seeded
`(role, key, grade)` tuples are parsed out of `[001]-todo_authz_grants.sql`,
grouped by role, folded through the authorizer, and required to equal the
`states` map printed in [§9](#9-the-live-server-boot). Neither side is restated
in Dart — both are read from the artifacts that make the claim — so re-grading a
field in the migration fails here until this README is corrected, on any machine.
Previously that link was made only by the example (which checks three of the
twelve cells) and by the live suite (which needs Docker).

The three database-free suites read the artifacts through two shared helpers:
`test/config_assets.dart` loads the config assets, `test/documented_authorization.dart`
parses the seeded grants and the README's matrix. One loader each, because two
copies would be free to disagree about what the artifacts say — which is the
drift these suites exist to catch.

`config_assets.dart` merges with `TomYaml.mergeInYamlFile` — the loader and the
merge `bin/server_start.dart` itself uses — rather than with `Map.addAll`, which
replaces a whole branch where the real merge overwrites per leaf. The two agree
on today's assets only because `app` has a single key, and a test that merged
differently from the boot would be asserting about a configuration the server
never assembles.

`documented_authorization.dart` guards two ways its parsing could pass while
proving nothing: it requires the seed file to yield exactly twelve grant rows
(an unrecognised `INSERT` shape would yield none, and an empty grant list grades
every field `none` — green, and vacuous), and it rejects an unknown grade token
before handing it to `TomAuthStateCodec.fromStored`, which is deliberately
lenient and would otherwise turn a typo in the expectation into a silent `none`.

### Against the live stack

`test/todo_endpoints_integration_test.dart` asserts the three endpoints of §9
against a running server and the bundled MariaDB. It is the only check in the
package that touches the boot sequence, the datasource registration, the
migration tree or the DTO serialization — everything above verifies pure
functions, so all four could break with `dart test` still green.

- `/health` returns `{"status": "ok", "app": …}` (no database — so when it
  passes and the others fail, the fault is in persistence rather than in the
  boot). The `app` value is asserted against `assets/config-resources_dev.yaml`,
  read out of the asset rather than restated in the test, which makes this the
  end-to-end half of the configuration claim: the `.env` selector, the overlay
  merge and the provider install all have to survive a real boot for the `(DEV)`
  title to reach an HTTP client;
- `/todos` returns the two rows `[000]-todo_core_schema.sql` seeds, asserted by
  their seeded *values*. Those strings exist nowhere in Dart, so the only route
  they can take into the response is the database. It also names the reflected
  `TodoItemDto` fields, which nothing else covers: the mapping unit tests stop
  at record, and record → DTO → wire is only observable over a socket;
- `/todos/field-states` must equal **the JSON printed in [§9](#9-the-live-server-boot)**.
  The document is not consulted for flavour — the test parses that fenced block
  and uses it as the expectation, so re-grading a field in
  `[001]-todo_authz_grants.sql` fails here until the README is corrected.

**Run it through `tool/run_integration.sh`, not directly.** The suite *skips*
when nothing is listening on `:8080`, so that `dart test` stays green on a
machine without Docker — which also means a skip is indistinguishable from a
pass in the exit code. The runner closes that gap: it recreates the database
from the migration tree, waits for the container to report healthy, boots the
server, waits for `/health`, and only then runs the suite — so a skip at that
point means the stack died mid-run, and the runner reports it as a failure. It
finishes by running the database-free suites and the example, so one command and
one exit code cover the whole package.

### The runner writes its own `.env`, deliberately not the default one

Every value in `.env.example` equals its own `${VAR:default}`, which is
convenient and makes the file useless as a test: a server ignoring the `.env`
entirely would reach the same database and pass. So the runner writes a `.env`
with two **non-default** values — `TODO_DB_PORT=3307` and `env=dev` — and then
requires the run to depend on both:

- Compose publishes MariaDB on 3307 and nothing listens on 3306, so a server
  that expanded `${TODO_DB_PORT:3306}` from the process environment cannot reach
  a database at all; every persistence endpoint fails.
- The boot logs the environment it resolved, and the runner greps the log for
  `environment: dev`. That is the second route the `.env` travels — the overlay
  selector rather than a placeholder — and it fails independently, so reverting
  either half of the wiring is caught by name rather than by a puzzling
  connection error.
- The overlay is also visible **on the wire**: `env=dev` selects
  `config-resources_dev.yaml`, which sets `app.title`, which `/health` serves.
  The log check and the endpoint assertion are independent witnesses to the same
  fact and fail in different places — the log check fails before any test runs
  and names the environment, the endpoint fails inside the suite and names the
  title — so between them a break says both *that* the selector stopped working
  and *how far* it got.

The runner refuses to overwrite an existing `.env` and removes only a file it
wrote itself, so running it does not disturb a `.env` you are working with.

---

## 13. What is built

**Database-free, `analyze`-clean, and unit-tested (no database required):**

- the relational persistence records and their repositories
  (`todo_records.dart`);
- the pure domain ↔ record mapping (`todo_mapping.dart`) with full unit tests;
- the four-state field authorizer (`todo_authorization.dart`) with full unit
  tests, including the seeded grants folding to the documented matrix
  (`todo_authorization_test.dart`);
- `/health`'s resolution of the configured `app.title` through the
  config-resource provider, including the environment overlay
  (`todo_health_config_test.dart`);
- the runnable database-free example (`run_all_examples.dart`);
- the full infrastructure: Docker compose, migrations (schema + grants),
  datasource/config assets, `.env.example`, reflection wiring.

**Live, and asserted against the bundled Docker MariaDB by
`tool/run_integration.sh`:**

- the `bin/server_start.dart` `TomServer` boot entrypoint;
- the `@tomService` HTTP endpoints and their JSON responses
  (`todo_endpoints.dart`);
- the end-to-end persistence round-trip (`/todos`) and four-state authorization
  resolved from DB grants (`/todos/field-states`).

Everything in the first list is unit-tested; everything in the second is covered
by `test/todo_endpoints_integration_test.dart`, which
[`tool/run_integration.sh`](tool/run_integration.sh) runs against a stack it
brings up itself ([§12](#12-testing)). "Verified" here therefore means a command
anyone can re-run and CI can gate on — not a `curl` someone typed once. The
manual path in [§9](#9-the-live-server-boot) still works and is the better way
to *explore* the API; it is no longer what the claim rests on.

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
  suite that takes this read-only public server to a JWT-secured, three-server
  full stack with write endpoints and per-principal field grading
