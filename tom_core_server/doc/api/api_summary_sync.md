# Tom Core Server API Reference: Sync Module

The server side of the offline sync protocol `tom_core_kernel`'s `offline`
module defines. An application exposes an entity under a collection name
([TomSync](#tomsync)); every write of it is then numbered in a change log
([TomSqlSyncLog](#tomsqlsynclog)), a device's push is applied through the
entity's repository, and a pull reads the changed entities through the
repository as the caller. [TomSyncServer](#tomsyncserver) serves both as
`POST /sync/push` and `POST /sync/pull`. See [doc/sync.md](../sync.md) for the
narrative guide.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomSyncException](#tomsyncexception)
  - [TomSyncRejection](#tomsyncrejection)
  - [TomSync](#tomsync)
  - [TomSqlSyncLog](#tomsqlsynclog)
  - [TomSyncChangeRow](#tomsyncchangerow)
  - [TomSyncChangeIdRow](#tomsyncchangeidrow)
  - [TomSyncSequenceRow](#tomsyncsequencerow)
  - [TomSyncServer](#tomsyncserver)
  - [TomSyncErrorHandler](#tomsyncerrorhandler)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/sync/sync.dart`,
`lib/src/tomserver/sync/sync_endpoint.dart`,
`lib/src/tomserver/sync/sync_sql.dart`.

`sync.dart` holds `TomSync`, the exposed collections and the protocol's two
operations, and `TomSqlSyncLog`, the change log in each synced entity's data
source with the rows it reads (`TomSyncChangeRow`, `TomSyncChangeIdRow`,
`TomSyncSequenceRow`). Its
failures are `TomSyncException`s; an application refuses a pushed change by
throwing `TomSyncRejection`.

`sync_sql.dart` declares the log's two tables once, as `TomFrameworkTable`s:
`syncChangeTable` and `syncSequenceTable`, by default `tom_sync_change` and
`tom_sync_sequence`.

`sync_endpoint.dart` holds `TomSyncServer`, the kernel's `TomSyncApiService`
over `TomSync`, bound to `tomSyncApi`, and `TomSyncErrorHandler`, which maps a
pull's refusals to `400`.

The protocol's types, the API declaration and its request and response bodies
are in `tom_core_kernel`'s `offline` module.

## Class Hierarchy

```text
TomServerException  (little_things)
    └── TomSyncException
            └── TomSyncRejection

TomSync  (abstract final, static-only)

TomSqlSyncLog

TomSyncChangeRow
TomSyncChangeIdRow
TomSyncSequenceRow

TomSyncApiService  (kernel)
    └── TomSyncServer  (implements)

TomStatusMappingErrorHandler  (endpoints)
    └── TomSyncErrorHandler
```

## Classes

### TomSyncException

A failure of the sync module. See [doc/sync.md](../sync.md#error-keys) for
every key.

| Key | Meaning |
| --- | ------- |
| `sync.collection.unknown` | A pull names a collection nothing is exposed under. |
| `sync.pull.invalid` | A pull's `since` is negative or its `limit` below one. |
| `sync.expose.unversioned` | The exposed entity has no `@TomVersion` field. |
| `sync.expose.key` | The exposed entity's key is composite, or neither a `String` nor an `int`. |
| `sync.expose.duplicate` | The collection or the entity is exposed already. |
| `sync.rejected` | The application refused a pushed change (`TomSyncRejection`). |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomSyncException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  bool clientThrow = true,
})
```

### TomSyncRejection

Thrown by an application, from a `TomEntityListener`'s `beforeSave` for
example, to refuse a pushed change. The device is told `rejected` with
`reason`, and gets the server's value back. The key is `sync.rejected`.

- **Extends:** `TomSyncException`

#### Constructors

```dart
TomSyncRejection(String reason, [String? message])
```

`message` defaults to `The change was refused: <reason>.`

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `reason` | `String` | The reason the device is told (final). |

### TomSync

The synced entities and the protocol's two operations over them. All members
are static.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `log` | `TomSqlSyncLog` | The change log. Replace it before the first `expose` to rename its tables or leave their creation to a migration. |
| `maxPullLimit` | `int` | The most changes one pull answers, whatever the device asks for. Default `1000`. |
| `collections` | `List<String>` | *(getter)* The exposed collections, unmodifiable. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `expose` | `static Future<void> expose<T extends Object, K>(String collection, TomSqlDatasourceRepository<T, K> repository, {String? Function(Map<String, Object?> data)? validate})` | Exposes `repository`'s entity as `collection`: a device may push and pull its changes, and every write of it is recorded in the change log by a `TomEntityLifecycle.onChange` listener. `validate` may refuse a pushed save's data with a reason (`null` accepts it). Prepares the log in the repository's data source. Throws `sync.expose.unversioned`, `sync.expose.key` or `sync.expose.duplicate`. |
| `push` | `static Future<List<TomPushResult>> push(List<TomPendingChange> changes)` | Applies `changes` in order, each in a transaction of its own, and answers one result per change: `applied` with the new version, `conflict` with the server's data and version, or `rejected` with a reason and the server's data. A change of an unknown collection is `rejected` with `sync.collection.unknown`. Any other failure is rethrown. |
| `pull` | `static Future<TomPullBatch> pull(String collection, int since, {int limit = 500})` | The changes of `collection` after `since` that the caller may read, at most `limit` and at most `maxPullLimit`, in sequence order. Each entity is read through the repository; a deletion carries the id alone. The cursor moves past every change read, the ones left out included. Throws `sync.collection.unknown` or `sync.pull.invalid`. |
| `reset` | `static void reset()` | Forgets the exposed collections and their listeners, and restores `log` and `maxPullLimit`. For tests. |

### TomSqlSyncLog

The change log in the data source of each synced entity: rows of
`syncChangeTable`, numbered through `syncSequenceTable`. A write records its
change unnumbered; `number`, which every pull runs first, numbers the
committed changes in the order they were recorded, so a number a cursor has
passed is never given to a change that commits later.

#### Constructors

```dart
TomSqlSyncLog({
  String changeTable = defaultSyncChangeTable,
  String sequenceTable = defaultSyncSequenceTable,
  bool createSchema = true,
})
```

With `createSchema` the tables are created in a data source the first time
`prepare` meets it, never inside a write's transaction. A deployment whose
database user may not run DDL, or whose tenants each have a database of their
own, applies the reference migration and passes `false`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changeTable` | `String` | The change-log table's name (final). |
| `sequenceTable` | `String` | The sequence-counter table's name (final). |
| `createSchema` | `bool` | Whether the tables are created on first use (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare(TomDataSource datasource, String collection)` | Creates the tables in `datasource` when `createSchema` is set, once per data source, and the counter row of `collection` for the current tenant, once per tenant and collection. Runs outside any write's transaction. |
| `append` | `Future<void> append(TomDataSource datasource, {required String collection, required String entityId, required int version, required bool deleted, required DateTime at})` | Records the change, unnumbered, in the caller's transaction: one insert that no other write waits on. |
| `number` | `Future<int> number(TomDataSource datasource, String collection)` | Numbers the current tenant's committed unnumbered changes of `collection` in the order they were recorded and moves the counter past them, in a transaction of locking statements only that locks the counter row first; answers the last number given out. |
| `after` | `Future<List<TomSyncChangeRow>> after(TomDataSource datasource, String collection, int since, int limit)` | The current tenant's numbered changes of `collection` after `since`, at most `limit`, in sequence order. |

### TomSyncChangeRow

One row of the change log, as `TomSqlSyncLog` reads it. Reflected
(`@tomReflector`) and annotated `@TomDbTable` with placeholder values, so the
driver can map it.

#### Constructors

```dart
TomSyncChangeRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sequence` | `int` | `seq` — the change's number in its collection's sequence. |
| `entityId` | `String` | `entity_id` — the entity's id. |
| `version` | `int` | `version` — the entity's version after the change. |
| `deleted` | `int` | `deleted` — `1` when the change deleted the entity. |

### TomSyncChangeIdRow

The id of an unnumbered change, as `TomSqlSyncLog.number` reads it. Reflected
and annotated like `TomSyncChangeRow`.

#### Constructors

```dart
TomSyncChangeIdRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | `id` — the change row's id, in the order changes were recorded. |

### TomSyncSequenceRow

A sequence counter's value, as `TomSqlSyncLog` reads it. Reflected and
annotated like `TomSyncChangeRow`.

#### Constructors

```dart
TomSyncSequenceRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `lastSequence` | `int` | `last_sequence` — the last number given out. |

### TomSyncServer

The default `TomSyncApiService` implementation, over `TomSync`: the handlers
of `POST /sync/push` and `POST /sync/pull`. Holds no state, so the pipeline
constructs it itself. Both endpoints are `TomAuthenticatedAccess`, declared by
the kernel's `tomSyncApi`; `TomEndpointRouting.registerFrameworkApis` registers
the API.

- **Annotations:** `@tomReflector`, `@tomComponent`; each method
  `@TomApiEndpointImplementation(apiId: tomSyncApiId, endpointId: ...,
  errorHandler: TomSyncErrorHandler())`
- **Implements:** `TomSyncApiService`

#### Constructors

```dart
const TomSyncServer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `push` | `Future<TomSyncPushResponse> push(TomSyncPushRequest request)` | *(override)* `TomSync.push` of the request's changes. |
| `pull` | `Future<TomSyncPullResponse> pull(TomSyncPullRequest request)` | *(override)* `TomSync.pull` of the request's collection, cursor and limit. |

### TomSyncErrorHandler

Answers a pull of a collection the server does not sync, and a pull with a
negative cursor or a limit below one, with a `400`. Every other failure stays
opaque.

- **Extends:** `TomStatusMappingErrorHandler`

#### Constructors

```dart
const TomSyncErrorHandler()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusByErrorKey` | `Map<String, int>` | *(getter, override)* `sync.collection.unknown` and `sync.pull.invalid` to `400`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultSyncChangeTable` | `String` | `'tom_sync_change'`, the change-log table's default name. |
| `defaultSyncSequenceTable` | `String` | `'tom_sync_sequence'`, the sequence-counter table's default name. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `syncChangeTable` | `TomFrameworkTable syncChangeTable(String table)` | The change-log table, declared once: primary key `id` (auto-increment, the order recorded), `seq` (`NULL` until numbered, unique per `(tenant, collection)`), `entity_id`, `version`, `deleted` and `changed_at`. Listed by `frameworkOwnedTables`. |
| `syncSequenceTable` | `TomFrameworkTable syncSequenceTable(String table)` | The sequence-counter table, declared once: primary key `(tenant, collection)` and `last_sequence`. Listed by `frameworkOwnedTables`. |
