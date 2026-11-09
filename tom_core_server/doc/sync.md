# Sync Module

The server side of the offline sync protocol that `tom_core_kernel`'s
`offline` module defines. A device keeps a copy of server entities, queues each
change with the version it was based on, pushes the queue and pulls what
changed. This module answers both operations over the entities' own
repositories and a change log in their database, with the semantics of the
kernel's `TomMemorySyncServer`. The kernel's sync contract runs against both.

An application exposes an entity under a collection name with `TomSync.expose`.
From then on every write of the entity is numbered in its collection's change
log, a push is applied through the repository, and a pull reads through the
repository as the caller. The server's pipeline serves the protocol as
`POST /sync/push` and `POST /sync/pull`.

## Table of Contents

- [Overview](#overview)
  - [The contract half](#the-contract-half)
- [Exposing an Entity](#exposing-an-entity)
- [The Push](#the-push)
  - [Applied, conflict, rejected](#applied-conflict-rejected)
  - [Rejection reasons](#rejection-reasons)
  - [Refusing a change from the application](#refusing-a-change-from-the-application)
  - [A failure that is not an answer](#a-failure-that-is-not-an-answer)
- [The Change Log](#the-change-log)
  - [Every write is numbered](#every-write-is-numbered)
  - [A change is numbered when it is pulled](#a-change-is-numbered-when-it-is-pulled)
  - [The log holds no values](#the-log-holds-no-values)
- [The Pull](#the-pull)
  - [The row scope on a pull](#the-row-scope-on-a-pull)
  - [Deletions](#deletions)
  - [The cursor](#the-cursor)
- [Tables and the Reference Migration](#tables-and-the-reference-migration)
- [The Endpoints](#the-endpoints)
  - [Why the pull is a POST](#why-the-pull-is-a-post)
  - [Refusals on the wire](#refusals-on-the-wire)
- [Wiring a Server](#wiring-a-server)
- [Error Keys](#error-keys)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSync` | abstract final class | The synced entities and the protocol's two operations: `expose`, `push`, `pull`, `collections`, `log`, `maxPullLimit`, `reset`. Statics only |
| `TomSqlSyncLog` | class | The change log in each synced entity's data source: `prepare`, `append`, `number`, `after` |
| `TomSyncChangeRow` | class | One row of the change log, as `TomSqlSyncLog` reads it |
| `TomSyncChangeIdRow` | class | The id of an unnumbered change, as `TomSqlSyncLog.number` reads it |
| `TomSyncSequenceRow` | class | A collection's counter value, as `TomSqlSyncLog` reads it |
| `TomSyncServer` | class | The `POST /sync/push` and `POST /sync/pull` handlers, the kernel's `TomSyncApiService` over `TomSync` |
| `TomSyncErrorHandler` | class | Answers a pull of an unknown collection, or with a bad cursor or limit, with a `400` |
| `TomSyncException` | class | The module's failures, keyed `sync.*` |
| `TomSyncRejection` | class | Thrown by the application to refuse a pushed change with a reason |
| `syncChangeTable` / `syncSequenceTable` | function | The two framework tables, declared once |
| `defaultSyncChangeTable` / `defaultSyncSequenceTable` | const String | `tom_sync_change` and `tom_sync_sequence`, the tables' default names |

### The contract half

The protocol's shapes are in `tom_core_kernel`, so a device and a server share
them: `TomPendingChange`, `TomPushResult`, `TomPulledChange` and `TomPullBatch`
with their JSON forms, and `tomSyncApi`, the API declaration with the request
and response bodies (`TomSyncPushRequest`, `TomSyncPushResponse`,
`TomSyncPullRequest`, `TomSyncPullResponse`) and the service interface
`TomSyncApiService`. The device calls the API with the kernel's
`TomHttpSyncTransport`. See the kernel's
[offline guide](../../tom_core_kernel/doc/offline/offline.md).

## Exposing an Entity

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'note', primaryKeyFields: ['id'])
class Note {
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  String? id;

  @TomVersion()
  @TomDbColumn(columnName: 'version')
  int? version;

  @TomDbColumn(columnName: 'text')
  String? text;
}

class NoteRepository extends TomSqlDatasourceRepository<Note, String> {}

Future<void> exposeNotes() => TomSync.expose(
  'notes',
  NoteRepository(),
  validate: (data) =>
      ((data['text'] as String?) ?? '').isEmpty ? 'text.required' : null,
);
```

`TomSync.expose(collection, repository, validate:)` registers the entity under
`collection`, the name a device pushes and pulls it under. It needs:

- **A `@TomVersion` field.** Pushes are applied by version. Without one the
  call is refused with `sync.expose.unversioned`.
- **A single `String` or `int` key.** The protocol carries ids as strings. A
  composite key or a key of another type is refused with `sync.expose.key`. A
  device creates entities under ids it chooses, so a `String` key is the usual
  one.
- **A collection and an entity not exposed already.** Either one exposed twice
  is refused with `sync.expose.duplicate`.

`validate` is optional. It receives a pushed save's data and answers `null` to
accept it or a reason to refuse it.

`expose` prepares the change log in the repository's data source (see
[Tables and the Reference Migration](#tables-and-the-reference-migration)) and
registers a change listener for the entity with `TomEntityLifecycle.onChange`.
`TomSync.collections` lists the exposed collections. `TomSync.reset` forgets
them and their listeners and restores the defaults; it is for tests.

## The Push

`TomSync.push(changes)` applies the changes in the order given and answers one
`TomPushResult` per change. Each change runs in a transaction of its own
(`TomTransactionManager.runInTransaction`), so one change failing leaves the
others as they are.

### Applied, conflict, rejected

The server reads the entity through the repository and compares its version
with the change's base version:

| The change | The server holds | Answer |
| ---------- | ---------------- | ------ |
| A save with a base version | The entity at that version | `applied`: the data is written over the stored entity with `repository.save`, and the answer carries the new version |
| A creation (no base version) | No entity under the id | `applied`: the entity is inserted with `repository.insert`, under the device's id |
| A deletion with a base version | The entity at that version | `applied`: the entity is deleted with `repository.delete`, and the answer carries the base version plus one |
| Any change | Another version, or an entity where a creation expected none | `conflict`, with the server's data and version |
| A save or deletion | No entity | `conflict`, with no server data |

A save's data is written over the stored entity, so a field the device does not
send keeps its stored value. The data's version and key fields are ignored: the
version travels beside the data, and the key is the change's id. A creation
uses the repository's `insert`, which writes the caller's key as given, where
`save` would update.

The comparison and the write happen in one transaction, and the repository's
optimistic lock checks the version again on the write. A writer that changes
or deletes the entity between the two makes the write fail with
`TomOptimisticLockException`, and the change is answered `conflict` with what
the server holds after it. Two devices creating the same id at once end the
same way: the second insert fails, the entity is found, and the change is
answered `conflict`.

### Rejection reasons

A `rejected` answer carries a reason and the entity as the server holds it, so
the device takes the server's value back. Pushing the change again would not
help.

| Reason | When |
| ------ | ---- |
| The reason `validate` answered | `validate` refused a save's data |
| `TomSyncRejection.reason` | The application threw `TomSyncRejection` during the write |
| A `data_scope.write.*` key | The row scope refused the write, for example `data_scope.write.out_of_scope` or `data_scope.write.insert_out_of_scope` |
| `column_authorization.write.field_forbidden` | A column grade refused the write |
| `sync.data.unreadable` | The data could not be read as the entity (a `TomReflectorException`) |
| `sync.id.taken` | A creation's id is held by an entity the caller cannot see |
| `sync.collection.unknown` | No entity is exposed under the change's collection |

A creation under an id another principal's entity holds is not answered
`conflict`, because that would hand the device the other entity's data. The
repository's read leaves the entity out under the caller's row scope, the
insert fails on the primary key, and an unscoped existence check
(`TomDataScope.runUnscoped`) tells the two cases apart: `sync.id.taken` reveals
that the id is in use, never what holds it.

### Refusing a change from the application

```dart
class NoteGuard extends TomEntityListener<Note> {
  @override
  Future<void> beforeSave(Note note, {required bool insert}) async {
    if (note.text!.length > 10000) throw TomSyncRejection('text.too_long');
  }
}

void guardNotes() => TomEntityLifecycle.register<Note>(NoteGuard());
```

A `TomSyncRejection` thrown anywhere in the change's transaction, typically
from a `TomEntityListener`, rolls the change back and answers `rejected` with
its `reason`. Its error key is `sync.rejected`; the device sees only the
reason.

### A failure that is not an answer

Any other failure fails the whole push: the endpoint answers it as an error and
the device keeps every change queued for the next sync. Changes applied before
the failing one stay applied. On the next push the device sends them again
with the same base versions, and the server answers `conflict` with the version
it holds, which the device's sync engine settles. Database outages and driver
errors take this path, so a transient failure never discards a change.

## The Change Log

### Every write is numbered

The change listener `expose` registers records every write of the entity in
the change log: a write through the sync endpoint, through an application's
own endpoint, or through any other code that uses the repository. A device
therefore pulls changes made on the web as well as by other devices.

The listener runs inside the write's transaction, which the entity lifecycle
opens when a change listener is registered. A change is in the log exactly
when it committed: a rolled-back write leaves no row, and a committed one
always has one.

Each row holds the tenant (`''` outside tenancy), the collection, the
entity's id, its version after the change, whether the change deleted it and
the time of the change, and — once a pull has numbered it — its number. A
deletion records the deleted entity's version plus one.

### A change is numbered when it is pulled

A cursor counts on one thing: a number it has passed is never given to a
change that commits later. A write records its change unnumbered (`seq` is
`NULL`); `TomSqlSyncLog.number`, which every pull runs first, gives the
committed unnumbered changes of the collection the next numbers, in the order
they were recorded, and moves the counter — a row of `tom_sync_sequence` per
tenant and collection — past them. A change still in an open transaction is
not visible to the numbering; a later pull numbers it, after every number
given before.

Numbering at the write instead would make every write of a collection update
the same counter row inside its transaction. On MariaDB, whose transactions
read from a snapshot, a write that has already read anything — a save reads
the stored row first — is refused (error 1020, record changed since last read)
when another write committed the counter in between. Recorded unnumbered, a
write inserts one row that nothing else touches, and writes never wait on each
other.

`number` runs in a transaction of locking statements only: it locks the
counter row first, so two numberings of one collection run one after the
other, and with no plain read in it the transaction holds no snapshot a later
write could contradict.

The counter row is created by `TomSqlSyncLog.prepare`, outside any write's
transaction, when `expose`, a push or a pull first meets the tenant and
collection.

### The log holds no values

A row records the entity's id and version, never its data. The values stay in
the entity's table, where field-level encryption, column grades and the row
scope apply to them. A pull reads them through the repository.

## The Pull

`TomSync.pull(collection, since, limit:)` answers a `TomPullBatch`: the
changes of `collection` after sequence number `since`, in sequence order. At
most `limit` changes are answered (default 500), and never more than
`TomSync.maxPullLimit` (default 1000), whatever the device asks for. A pull of
a collection nothing is exposed under is refused with `sync.collection.unknown`;
a negative `since` or a `limit` below one with `sync.pull.invalid`.

### The row scope on a pull

The pull reads the log, then reads each changed entity through the repository,
as the caller:

- An entity the caller's row scope does not reach is left out.
- Column grades mask the columns they mask.
- Encrypted columns arrive decrypted.

A pulled change carries the entity as the server holds it at the pull, with
its current version. An entity changed several times since the cursor is
therefore answered at its newest state under each of its numbers. An entity
deleted since its number was given is left out at that number; its deletion
has a number of its own.

### Deletions

A deletion is answered with the id and no data (`TomPulledChange.data` is
`null`). It is not read through the repository, since there is nothing left to
read, so it reaches every device pulling the collection, whatever its row
scope. A device that never held the entity removes nothing.

### The cursor

The batch's `cursor` is the number of the last change read, the left-out ones
included. A page full of entities the caller may not read still advances the
device, so it never pulls the same unreadable page again. `hasMore` is `true`
when the log holds changes after the page; the device's sync engine then pulls
again from the cursor.

## Tables and the Reference Migration

The log lives in two framework tables in the data source of each synced
entity's repository:

| Table | Key | Columns |
| ----- | --- | ------- |
| `tom_sync_change` | `id` (in the order recorded); unique `(tenant, collection, seq)` | `seq` (`NULL` until numbered), `entity_id`, `version`, `deleted`, `changed_at` |
| `tom_sync_sequence` | `(tenant, collection)` | `last_sequence` |

`syncChangeTable(table)` and `syncSequenceTable(table)` declare them once, as
`TomFrameworkTable`s. `frameworkOwnedTables()` lists both, so schema
convergence knows them as the framework's.

`TomSqlSyncLog` creates the tables the first time `prepare` meets a data source
(`createSchema`, default `true`). `prepare` runs at `expose` and before each
push and pull, never inside a write's transaction, where DDL would commit the
transaction on MariaDB.

A deployment whose database user may not run DDL, or whose tenants each have a
database of their own, applies the reference migration in each data source and
turns creation off:

```dart
TomSync.log = TomSqlSyncLog(createSchema: false);
```

The reference migration is
`example/sync/migrations/main/tomcore/[1]-create_tom_sync_change.sql`, with
its PostgreSQL translation under `example/sync/migrations_postgresql/`.
`test/framework_schema_test.dart` replays it and compares the schema it builds
with the two declarations, so the file and the code cannot drift apart.

`TomSqlSyncLog(changeTable:, sequenceTable:)` renames the tables. Replace
`TomSync.log` before the first `expose`.

## The Endpoints

The kernel's `tomSyncApi` declares the two endpoints, and `TomSyncServer`
implements them over `TomSync`:

```json
POST /sync/push   {"changes": [<TomPendingChange>, ...]}
  → {"results": [<TomPushResult>, ...]}
POST /sync/pull   {"collection": "notes", "since": 12, "limit": 500}
  → {"changes": [<TomPulledChange>, ...], "cursor": 14, "hasMore": false}
```

Both are `TomAuthenticatedAccess`: the pipeline refuses an anonymous caller
before the handler runs. What a signed-in caller may read and write beyond that
is the synced entities' row scope and column grades, applied by their
repositories. `TomEndpointRouting.registerFrameworkApis` registers the API, so
every server mounts both endpoints. `TomSyncServer` holds no state, and the
pipeline constructs it itself.

### Why the pull is a POST

A pull is a read, but it is the read a device makes right after its own push,
and it has to see that push. A `GET` is read-only work, which a server with
read replicas may answer from a replica that does not have the push yet. Both
endpoints are therefore `POST`s and run against the primary.

### Refusals on the wire

`TomSyncErrorHandler` answers `sync.collection.unknown` and `sync.pull.invalid`
on a pull with `400` and the error envelope carrying the key. Every other
failure stays opaque. A pushed change of an unknown collection is not an error:
it is answered `rejected` with `sync.collection.unknown`.

On the device, `TomHttpSyncTransport` turns any status other than `200` into a
`TomOfflineException` keyed `offline.http.failed`, carrying the status and the
envelope's error key. The sync engine reports it as a failed transport and
keeps every change.

## Wiring a Server

```dart
Future<void> configureSync() async {
  // Optional: the tables come from the reference migration.
  TomSync.log = TomSqlSyncLog(createSchema: false);
  TomSync.maxPullLimit = 500;

  // Each synced entity, once at start.
  await TomSync.expose('notes', NoteRepository());
}
```

Expose the entities after the data sources are registered and before the
server takes requests. Nothing else is wired: the pipeline mounts the
endpoints. A device syncs with the kernel's `TomSyncEngine` over
`TomHttpSyncTransport`:

```dart
final sync = TomSyncEngine(
  store: store,
  transport: TomHttpSyncTransport(baseUri: Uri.parse('https://api.example.com')),
  collections: ['notes'],
);
```

The transport sends the bearer token of `TomBearerAuthentication`, or the
headers its `headers` callback answers per request.

## Error Keys

Every failure is a `TomSyncException` (a `TomServerException`):

| Key | Raised when |
| --- | ----------- |
| `sync.collection.unknown` | A pull names a collection nothing is exposed under. Carries `collection`. A pushed change of one is answered `rejected` with this reason |
| `sync.pull.invalid` | A pull's `since` is negative or its `limit` below one. Carries `since` and `limit` |
| `sync.expose.unversioned` | `expose` is given an entity without a `@TomVersion` field. Carries `entity` |
| `sync.expose.key` | `expose` is given an entity with a composite key, or a key that is neither a `String` nor an `int`. Carries `entity` |
| `sync.expose.duplicate` | `expose` is given a collection or an entity exposed already. Carries `collection` and `entity` |
| `sync.rejected` | The application throws `TomSyncRejection` to refuse a pushed change; the device is told its `reason` |

The `expose` keys are raised with `clientThrow: false`: they describe the
deployment, not the caller's input.

## Core Components

- **`TomSync`** (`sync.dart`) — the exposed collections, `push` and `pull`,
  and the change listener each `expose` registers.
- **`TomSqlSyncLog`** (`sync.dart`) — recording a change unnumbered in the
  caller's transaction, numbering the committed changes before a pull, and
  reading a collection's changes after a cursor; **`TomSyncChangeRow`**,
  **`TomSyncChangeIdRow`** and **`TomSyncSequenceRow`** are the rows it reads.
- **`syncChangeTable`** / **`syncSequenceTable`** (`sync_sql.dart`) — the two
  tables' single declarations.
- **`TomSyncServer`** / **`TomSyncErrorHandler`** (`sync_endpoint.dart`) — the
  endpoints, bound to the kernel's `tomSyncApi`.
- **`TomSyncException`** / **`TomSyncRejection`** (`sync.dart`) — the
  module's errors, and the application's refusal of a change.

## Not Yet Implemented

- **The change log is never compacted.** It keeps one row per change for as
  long as the database does. A device that was away resumes from its cursor
  however old it is, and the table grows with every write of a synced entity.
  <!-- unpinned: absence — nothing deletes tom_sync_change rows -->
- **Only repository writes are numbered.** A statement run on the data source
  directly bypasses the entity lifecycle, so its change is not in the log and
  no device pulls it.
  <!-- unpinned: decision — the log is fed by TomEntityLifecycle change listeners -->
- **A pull reads entities one at a time.** Each changed entity of a page is a
  `findById` of its own, so a page of 500 changes is 500 reads.
  <!-- unpinned: absence — TomSync.pull reads each entity with findById -->
- **No change is pushed to a device.** A device learns of a server change when
  it pulls; the server sends no notification over a socket or a push channel.
  <!-- unpinned: absence — the protocol has push and pull only -->

## Verification

`test/sync_db_test.dart` runs the kernel's sync contract
(`tom_core_kernel/test/contracts/sync_protocol_contract.dart`) over HTTP
against a loopback server with the real pipeline and `TomSyncServer`, on a live
database. The device side is the kernel's `TomSyncEngine` over
`TomHttpSyncTransport`. The contract covers pushes and the versions answered,
every way a conflict is decided, a refused change, incremental and paged pulls,
deletions, an interrupted sync, a save made while a push is out, and two
overlapping syncs. Beyond the contract, the suite covers a device pulling only
the notes its principal may read while a deletion reaches every device; a
creation under an id another principal holds answered `sync.id.taken`; a change
of an unknown collection rejected and a pull of one refused with `400`; an
anonymous caller refused; and concurrent writes numbered one after another
with no gap. It is tagged `db` and skips without a server;
`tool/run_db_tests.sh` runs it on MariaDB and `tool/run_db_tests_postgres.sh`
on PostgreSQL.

`test/framework_schema_test.dart` converges the reference migration against
`syncChangeTable` and `syncSequenceTable`, and maps both tables to
`TomSyncChangeRow`, `TomSyncChangeIdRow` and `TomSyncSequenceRow`.

```bash
dart run example/sync/sync_example.dart
```

`example/sync/sync_example.dart` shows what needs no database, in four checked
steps: the routes from the contract, both `POST`s; the change log's tables,
holding a number and the entity's id but no values, and created in PostgreSQL types on
PostgreSQL; a change of a collection nothing is exposed under rejected and a
pull of one refused; and a push request read back as the endpoint reads it.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `sync.dart` | `Future` |
| `tom_core_kernel` | package | `sync.dart`, `sync_endpoint.dart` | The protocol's types (`TomPendingChange`, `TomPushResult`, `TomPulledChange`, `TomPullBatch`), the API (`tomSyncApi` and its ids, `TomSyncApiService` and its bodies, `tomSyncUnknownCollectionErrorKey`), `TomTenantContext` for the log's tenant, and the reflection the conversions between entities and data use |
| [datasources](datasources.md) | module | `sync.dart`, `sync_sql.dart` | `TomFrameworkTable`, the tables' single declarations; `TomDataSource` and `TomSchemaProvisioning`, to create the tables and run the log's statements; `sqlInstant` |
| [endpoints](endpoints.md) | module | `sync_endpoint.dart` | `@TomApiEndpointImplementation` and `TomStatusMappingErrorHandler`, by which the pipeline binds the handlers and maps the pull's refusals |
| [little_things](little_things.md) | module | `sync.dart` | `TomServerException`, the base of `TomSyncException` |
| [object_persistence](object_persistence.md) | module | `sync.dart` | `TomSqlDatasourceRepository`, through which every push and pull runs; `TomAnnotationAnalyzer` and `TomColumnInformation` for the version and key; `TomEntityLifecycle`, whose change listener feeds the log; `TomDataScope.runUnscoped` and the refusals the push turns into reasons (`TomDataScopeException`, `TomColumnAuthorizationException`, `TomOptimisticLockException`); `TomDbTable` / `TomDbColumn` on the row classes |
| [transactions](transactions.md) | module | `sync.dart` | `TomTransactionManager.runInTransaction`, one transaction per pushed change |

- The endpoints module — `TomEndpointRouting.registerFrameworkApis` registers
  `tomSyncApi`, so every server mounts the endpoints.
- The db_migration module — `frameworkOwnedTables` lists both tables.
