# Tom Core Kernel API Reference: Offline Module

Server entities kept on the device: the storage-engine contract an application
implements over the database it chose, the device-side repository whose every
write is queued for the server, the sync protocol, the sync engine that pushes,
resolves conflicts and pulls, the protocol's server side in memory, and the
protocol as a remote API with its HTTP transport.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomOfflineException](#tomofflineexception)
  - [TomLocalStoreEngine](#tomlocalstoreengine)
  - [TomMemoryLocalStoreEngine](#tommemorylocalstoreengine)
  - [TomOfflineStore](#tomofflinestore)
  - [TomLocalEntityCodec](#tomlocalentitycodec)
  - [TomLocalRepository](#tomlocalrepository)
  - [TomPendingChange](#tompendingchange)
  - [TomPushResult](#tompushresult)
  - [TomPulledChange](#tompulledchange)
  - [TomPullBatch](#tompullbatch)
  - [TomSyncTransport](#tomsynctransport)
  - [TomSyncConflict](#tomsyncconflict)
  - [TomConflictResolution](#tomconflictresolution)
  - [TomConflictResolver](#tomconflictresolver)
  - [TomSyncReport](#tomsyncreport)
  - [TomSyncEngine](#tomsyncengine)
  - [TomMemorySyncServer](#tommemorysyncserver)
  - [TomHttpSyncTransport](#tomhttpsynctransport)
  - [TomSyncPushRequest](#tomsyncpushrequest)
  - [TomSyncPushResponse](#tomsyncpushresponse)
  - [TomSyncPullRequest](#tomsyncpullrequest)
  - [TomSyncPullResponse](#tomsyncpullresponse)
  - [TomSyncApiService](#tomsyncapiservice)
- [Enums](#enums)
  - [TomChangeOperation](#tomchangeoperation)
  - [TomPushOutcome](#tompushoutcome)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tombase/offline/local_store.dart`,
`lib/src/tombase/offline/sync_protocol.dart`,
`lib/src/tombase/offline/local_repository.dart`,
`lib/src/tombase/offline/sync_engine.dart`,
`lib/src/tombase/offline/memory_sync_server.dart`,
`lib/src/tombase/offline/sync_contract.dart`,
`lib/src/tombase/offline/http_sync_transport.dart`.

The server is authoritative. A device keeps a copy of the entities it works
with, each with the server version it is based on, in a `TomLocalStoreEngine`
the application supplies. `TomLocalRepository` reads and writes that copy with
the same operations as the server's `TomRepository`; every write is also queued
as a `TomPendingChange` that carries its base version. `TomSyncEngine.sync`
pushes the queue through a `TomSyncTransport`; the server applies each change
under optimistic locking and answers `applied`, `conflict` or `rejected`. A
conflict goes to the application's `TomConflictResolver`. The engine then pulls
each collection's changes after the cursor it saved, by the server's change
sequence. `TomMemorySyncServer` is the protocol's server side in memory.

`tomSyncApi` declares the protocol as a remote API, `POST /sync/push` and
`POST /sync/pull` for an authenticated caller, with its bodies
(`TomSyncPushRequest`, `TomSyncPushResponse`, `TomSyncPullRequest`,
`TomSyncPullResponse`) and the service interface a server implements
(`TomSyncApiService`). `tom_core_server`'s `sync` module implements it, and
`TomHttpSyncTransport` calls it from the device.

The framework never picks the device database. Collections whose name starts
with `_tom` are the framework's own (`_tom_pending`, `_tom_meta`). Failures are
`TomOfflineException`s with an `offline.*` key. See
[`doc/offline/offline.md`](../offline/offline.md) for the narrative guide.

## Class Hierarchy

```
TomException  (kernel)
    └── TomOfflineException

TomLocalStoreEngine  (abstract — the application's database)
    └── TomMemoryLocalStoreEngine

TomOfflineStore  (entities, queue, cursors over an engine)
TomLocalEntityCodec<T>
TomLocalRepository<T>  (reads and writes through a TomOfflineStore)

TomPendingChange · TomPushResult · TomPulledChange · TomPullBatch  (protocol data)

TomSyncTransport  (abstract — the way to the server)
    ├── TomMemorySyncServer
    └── TomHttpSyncTransport

TomJsonSerializable  (json)
    ├── TomSyncPushRequest · TomSyncPushResponse  (implements)
    └── TomSyncPullRequest · TomSyncPullResponse  (implements)

TomSyncApiService  (abstract — implemented by tom_core_server's TomSyncServer)

TomSyncConflict
TomConflictResolution  (sealed: keepServer, keepLocal, merge)
TomSyncReport
TomSyncEngine
```

## Classes

### TomOfflineException

Raised by the offline store; `key` names why.

- **Extends:** `TomException`

```dart
TomOfflineException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? rootException, StackTrace? stack})
```

| Key | Thrown by | When | Parameters |
| --- | --------- | ---- | ---------- |
| `offline.store.closed` | `TomMemoryLocalStoreEngine` | Any call after `close`. | — |
| `offline.document.not_json` | `TomMemoryLocalStoreEngine.write` | The document holds a value JSON cannot encode. | `collection`, `id` |
| `offline.collection.reserved` | `TomOfflineStore.checkCollection`, the `TomLocalRepository` and `TomSyncEngine` constructors | The collection name is empty or starts with `_tom`. | `collection` |
| `offline.sync.transport_failed` | `TomSyncEngine.sync` | The transport threw on a push or a pull. The queue is unchanged. | `changes` (push) or `collection`, `since` (pull) |
| `offline.http.failed` | `TomHttpSyncTransport.push`, `.pull` | The server answered with a status other than `200`. | `endpoint`, `status`, `errorKey` (when the answer carried one) |

### TomLocalStoreEngine

A device-side document store: JSON documents in named collections, keyed by id.
The application implements it over the database it chose.

- **Kind:** abstract class

#### Constructors

```dart
const TomLocalStoreEngine()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `Future<Map<String, Object?>?> read(String collection, String id)` | The document `id` of `collection`, or `null`. |
| `readAll` | `Future<Map<String, Map<String, Object?>>> readAll(String collection)` | Every document of `collection`, by id. |
| `write` | `Future<void> write(String collection, String id, Map<String, Object?> document)` | Stores `document` as `id` of `collection`, replacing what was there. |
| `delete` | `Future<bool> delete(String collection, String id)` | Removes `id` from `collection`; answers whether it was there. |
| `transaction` | `Future<T> transaction<T>(Future<T> Function() body)` | Runs `body` so that its writes happen all or not at all, and no other transaction of this engine interleaves with it. A transaction started inside `body` joins it. |
| `close` | `Future<void> close()` | Releases the engine. |

### TomMemoryLocalStoreEngine

`TomLocalStoreEngine` in memory: for tests, and for a session cache that does
not outlive the process. A transaction works on a copy that replaces the data
only when the body completes, so a failing body leaves nothing behind.
Documents are stored as JSON text, so a value a real engine could not store is
refused (`offline.document.not_json`).

- **Extends:** `TomLocalStoreEngine`

#### Constructors

```dart
TomMemoryLocalStoreEngine()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `Future<Map<String, Object?>?> read(String collection, String id)` | As `TomLocalStoreEngine.read`. |
| `readAll` | `Future<Map<String, Map<String, Object?>>> readAll(String collection)` | As `TomLocalStoreEngine.readAll`. |
| `write` | `Future<void> write(String collection, String id, Map<String, Object?> document)` | Encodes `document` as JSON; throws `offline.document.not_json` when it cannot. |
| `delete` | `Future<bool> delete(String collection, String id)` | As `TomLocalStoreEngine.delete`. |
| `transaction` | `Future<T> transaction<T>(Future<T> Function() body)` | Runs transactions one at a time on a copy of the data; a nested one joins the outer one. |
| `close` | `Future<void> close()` | Marks the engine closed; every later call throws `offline.store.closed`. |

### TomOfflineStore

The device's copy of server entities over a `TomLocalStoreEngine`: each entity
with the server version it is based on, the queue of pending changes, and the
framework's own values (the pending-change counter, the pull cursors).
`TomLocalRepository` writes through it and `TomSyncEngine` reconciles it; an
application normally uses those two.

An entity is stored as `{"data": …, "version": …}` in its collection.

#### Constructors

```dart
TomOfflineStore(TomLocalStoreEngine engine, {DateTime Function()? clock})
```

`clock` stamps `TomPendingChange.queuedAt`; it defaults to `DateTime.now`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `engine` | `final TomLocalStoreEngine` | The engine the data lives in. |
| `pendingCollection` | `static const String` | `_tom_pending` — the queue of pending changes. |
| `metaCollection` | `static const String` | `_tom_meta` — the framework's own values. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `checkCollection` | `static void checkCollection(String collection)` | Throws `offline.collection.reserved` for an empty name or one starting with `_tom`. |
| `entity` | `Future<({Map<String, Object?> data, int? version})?> entity(String collection, String id)` | The entity with its server version, or `null`. |
| `entities` | `Future<Map<String, ({Map<String, Object?> data, int? version})>> entities(String collection)` | Every entity of `collection` with its version, by id. |
| `putEntity` | `Future<void> putEntity(String collection, String id, Map<String, Object?> data, int? version)` | Stores the entity without queueing anything — what the sync engine writes when the server spoke. |
| `pending` | `Future<List<({String key, TomPendingChange change})>> pending()` | The queued changes, oldest first. |
| `pendingFor` | `Future<({String key, TomPendingChange change})?> pendingFor(String collection, String id)` | The queued change of one entity, or `null`. |
| `replacePending` | `Future<void> replacePending(String key, TomPendingChange change)` | Replaces the queued change under `key`. |
| `dropPending` | `Future<void> dropPending(String key)` | Removes the queued change under `key`. |
| `meta` | `Future<Object?> meta(String name)` | A framework value, or `null`. |
| `setMeta` | `Future<void> setMeta(String name, Object? value)` | Sets a framework value. |
| `save` | `Future<void> save(String collection, String id, Map<String, Object?> data)` | Stores the entity and queues the change, in one transaction. A change still queued for the entity is replaced and keeps its place, its id and its base version. |
| `delete` | `Future<bool> delete(String collection, String id)` | Removes the entity and queues the deletion, in one transaction. An entity without a version (never seen by the server) is forgotten: its queued creation goes and nothing is queued. Answers whether the device had it. |

### TomLocalEntityCodec

`TomLocalEntityCodec<T>` — how a repository turns its entities into the JSON
it stores, and back, and which id an entity has.

#### Constructors

```dart
const TomLocalEntityCodec({required Map<String, Object?> Function(T entity) toJson, required T Function(Map<String, Object?> json) fromJson, required String Function(T entity) idOf})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `toJson` | `final Map<String, Object?> Function(T entity)` | The entity as JSON. |
| `fromJson` | `final T Function(Map<String, Object?> json)` | The entity from JSON. |
| `idOf` | `final String Function(T entity)` | The entity's id. |

### TomLocalRepository

`TomLocalRepository<T extends Object>` — the device-side counterpart of the
server's `TomRepository`: the same reads and writes, against the device's copy,
every write queued for the server. Reads answer what the device holds, its own
unsynced changes included. Ids are strings.

#### Constructors

```dart
TomLocalRepository({required TomOfflineStore store, required String collection, required TomLocalEntityCodec<T> codec})
```

Throws `offline.collection.reserved` for a reserved `collection`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `final TomOfflineStore` | The device's store. |
| `collection` | `final String` | The collection the entities live in — the server's name for the entity kind, which pushes and pulls use too. |
| `codec` | `final TomLocalEntityCodec<T>` | How entities become JSON. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `findById` | `Future<T?> findById(String id)` | The entity, or `null`. |
| `findAll` | `Future<List<T>> findAll()` | Every entity, ordered by id. |
| `findAllById` | `Future<List<T>> findAllById(Iterable<String> ids)` | The entities the device holds among `ids`, in the order asked. |
| `existsById` | `Future<bool> existsById(Iterable<String> ids)` | Whether the device holds every one of `ids`. |
| `count` | `Future<int> count()` | How many entities the device holds. |
| `save` | `Future<T> save(T entity)` | Saves on the device and queues the change; answers `entity`. |
| `saveAll` | `Future<List<T>> saveAll(Iterable<T> entities)` | Saves every one, in one transaction. |
| `delete` | `Future<void> delete(T entity)` | Deletes `entity`. |
| `deleteById` | `Future<int> deleteById(String id)` | Deletes the entity; answers 0 or 1. |
| `deleteAllById` | `Future<int> deleteAllById(Iterable<String> ids)` | Deletes every one, in one transaction; answers how many went. |
| `versionOf` | `Future<int?> versionOf(String id)` | The server version the entity is based on; `null` for one the server has not seen. |
| `hasPendingChange` | `Future<bool> hasPendingChange(String id)` | Whether the entity has a change the server has not taken. |

### TomPendingChange

A local change waiting to reach the server. It is how a change is queued and
how it travels.

#### Constructors

```dart
TomPendingChange({required String changeId, required String collection, required String id, required TomChangeOperation operation, Map<String, Object?>? data, int? baseVersion, required DateTime queuedAt})
factory TomPendingChange.fromJson(Map<String, Object?> json)
```

`data` is copied into an unmodifiable map.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changeId` | `final String` | Identifies the change; the server answers by it. |
| `collection` | `final String` | The collection (entity kind) changed. |
| `id` | `final String` | The entity's id. |
| `operation` | `final TomChangeOperation` | What the change does. |
| `data` | `final Map<String, Object?>?` | The entity as the device holds it, for `save`. |
| `baseVersion` | `final int?` | The server's version when the device last had the entity; `null` for an entity the server has never seen. |
| `queuedAt` | `final DateTime` | When the change was made. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The change as JSON; `queuedAt` as UTC ISO-8601, `data` and `baseVersion` left out when `null`. |
| `rebased` | `TomPendingChange rebased(int? baseVersion, {Map<String, Object?>? data})` | The same change based on `baseVersion`, carrying `data` when given. |

### TomPushResult

The server's answer to one pushed change.

#### Constructors

```dart
const TomPushResult({required String changeId, required TomPushOutcome outcome, int? version, Map<String, Object?>? serverData, String? reason})
factory TomPushResult.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changeId` | `final String` | The change answered. |
| `outcome` | `final TomPushOutcome` | How the server took it. |
| `version` | `final int?` | For `applied`, the new version; otherwise the server's current version, `null` when it does not have the entity. |
| `serverData` | `final Map<String, Object?>?` | For a conflict or a refusal, the entity as the server holds it; `null` when it does not have it. |
| `reason` | `final String?` | For `rejected`, why. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The result as JSON: `changeId`, `outcome` by name, and `version`, `serverData`, `reason` left out when `null`. |

### TomPulledChange

One change the server applied, as a device pulls it.

#### Constructors

```dart
const TomPulledChange({required String id, required Map<String, Object?>? data, required int version, required int sequence})
factory TomPulledChange.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `final String` | The entity's id. |
| `data` | `final Map<String, Object?>?` | The entity now, or `null` when the change deleted it. |
| `version` | `final int` | The entity's version after the change. |
| `sequence` | `final int` | The change's number in the collection's change sequence. |
| `deleted` | `bool` *(getter)* | Whether the change deleted the entity. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The change as JSON: `id`, `data` (`null` for a deletion), `version`, `sequence`. |

### TomPullBatch

The answer to a pull: the changes after the cursor asked for, in sequence
order.

#### Constructors

```dart
TomPullBatch({required List<TomPulledChange> changes, required int cursor, bool hasMore = false})
factory TomPullBatch.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changes` | `final List<TomPulledChange>` | The changes, unmodifiable. |
| `cursor` | `final int` | The cursor to ask from next time: the last sequence number included. |
| `hasMore` | `final bool` | Whether more changes follow this batch. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The batch as JSON: `changes`, `cursor`, `hasMore`. |

### TomSyncTransport

How a device reaches the server's sync endpoint. The framework defines the
exchange; the transport is the wire.

- **Kind:** abstract class
- **Implemented by:** `TomMemorySyncServer`, `TomHttpSyncTransport`

#### Constructors

```dart
const TomSyncTransport()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `push` | `Future<List<TomPushResult>> push(List<TomPendingChange> changes)` | Pushes `changes` in order; answers one result per change. |
| `pull` | `Future<TomPullBatch> pull(String collection, int since, {int limit = 500})` | The changes of `collection` after sequence number `since`, at most `limit`. |

### TomSyncConflict

A pushed change the server did not apply because its version is not the
change's base.

#### Constructors

```dart
const TomSyncConflict({required TomPendingChange change, required Map<String, Object?>? serverData, required int? serverVersion})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `change` | `final TomPendingChange` | The device's change. |
| `serverData` | `final Map<String, Object?>?` | The entity as the server holds it; `null` when the server deleted it. |
| `serverVersion` | `final int?` | The server's version; `null` when it does not have the entity. |

### TomConflictResolution

What to do about a conflict. Sealed: the three values below are the only ones.

- **Kind:** sealed class

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `keepServer` | `static const TomConflictResolution keepServer` | Take the server's entity and drop the device's change. |
| `keepLocal` | `static const TomConflictResolution keepLocal` | Keep the device's change and push it again, based on the server's version. |
| `merge` | `const factory TomConflictResolution.merge(Map<String, Object?> data)` | Store `data` on the device and push it, based on the server's version. |

### TomConflictResolver

```dart
typedef TomConflictResolver = FutureOr<TomConflictResolution> Function(TomSyncConflict conflict);
```

Decides a conflict; the application supplies it to `TomSyncEngine`.

### TomSyncReport

What one `TomSyncEngine.sync` did.

#### Constructors

```dart
TomSyncReport({required List<TomPendingChange> applied, required List<TomSyncConflict> conflicts, required List<TomPendingChange> discarded, required List<({TomPendingChange change, String? reason})> rejected, required Map<String, int> pulled, required int stillPending})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `applied` | `final List<TomPendingChange>` | The changes the server applied. |
| `conflicts` | `final List<TomSyncConflict>` | The conflicts met, whatever was decided about them. |
| `discarded` | `final List<TomPendingChange>` | The device's changes dropped for the server's state: conflicts resolved as `keepServer`, and refusals. |
| `rejected` | `final List<({TomPendingChange change, String? reason})>` | The changes the server refused, with its reason. |
| `pulled` | `final Map<String, int>` | How many server changes were written into the device's copy, by collection. |
| `stillPending` | `final int` | Changes still queued after the sync. |

### TomSyncEngine

Brings a device's `TomOfflineStore` and the server into line: pushes the
queued changes, resolves conflicts, pulls the server's changes.

#### Constructors

```dart
TomSyncEngine({required TomOfflineStore store, required TomSyncTransport transport, required List<String> collections, TomConflictResolver? resolver, int maxPushRounds = 3, int pullLimit = 500})
```

Throws `offline.collection.reserved` for a reserved name in `collections`.
Without `resolver`, every conflict is resolved as `keepServer`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `final TomOfflineStore` | The device's store. |
| `transport` | `final TomSyncTransport` | The way to the server. |
| `collections` | `final List<String>` | The collections pulled, unmodifiable. |
| `resolver` | `final TomConflictResolver` | Decides conflicts. |
| `maxPushRounds` | `final int` | How many push rounds one sync makes; a change decided for the device's state is pushed again in the next round. |
| `pullLimit` | `final int` | How many changes one pull asks for. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sync` | `Future<TomSyncReport> sync()` | Pushes, then pulls. A sync asked for while one runs joins it. Throws `offline.sync.transport_failed` when the transport fails. |

### TomMemorySyncServer

The sync protocol's server side, in memory: entities with versions, a change
sequence per collection. It is the reference a server endpoint follows, and the
transport tests sync against.

- **Extends:** `TomSyncTransport`

#### Constructors

```dart
TomMemorySyncServer({String? Function(String collection, Map<String, Object?> data)? validate})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `validate` | `final String? Function(String collection, Map<String, Object?> data)?` | Refuses a save's data with a reason (the push answers `rejected`), or answers `null` to accept it. |
| `pushes` | `int` | How many pushes were received. |
| `offline` | `Object?` | When set, every push and pull throws it — the network is down. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `entity` | `({Map<String, Object?> data, int version})? entity(String collection, String id)` | The entity as the server holds it, or `null`. |
| `put` | `int put(String collection, String id, Map<String, Object?> data)` | Saves the entity as another client would; answers the new version. |
| `remove` | `void remove(String collection, String id)` | Deletes the entity as another client would. |
| `push` | `Future<List<TomPushResult>> push(List<TomPendingChange> changes)` | Applies each change only when the entity's version is its base; otherwise answers a conflict with what the server holds. |
| `pull` | `Future<TomPullBatch> pull(String collection, int since, {int limit = 500})` | The changes after `since`, at most `limit`. |

### TomHttpSyncTransport

A `TomSyncTransport` calling a Tom server's sync API (`tomSyncApi`) at
`baseUri`, the server root; the API's path is appended from the contract. Every
request carries the headers `headers` answers, computed per request; without an
`Authorization` among them the bearer token of `TomBearerAuthentication` is
sent. Requests go through `client`, by default a `TomResilientClient`, which
does not retry a push. A status other than `200` throws `TomOfflineException`
`offline.http.failed`. Constructing it registers `tomSyncApi`.

- **Extends:** `TomSyncTransport`

#### Constructors

```dart
TomHttpSyncTransport({required Uri baseUri, http.Client? client, Map<String, String> Function()? headers})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `baseUri` | `final Uri` | The server root. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `push` | `Future<List<TomPushResult>> push(List<TomPendingChange> changes)` | *(override)* `POST /sync/push` with the changes; answers the server's results. |
| `pull` | `Future<TomPullBatch> pull(String collection, int since, {int limit = 500})` | *(override)* `POST /sync/pull` with the collection, cursor and limit; answers the server's batch. |
| `close` | `void close()` | Closes the HTTP client. |

### TomSyncPushRequest

The body of a push: the pending changes, in the order they are applied.

- **Implements:** `TomJsonSerializable`
- **Annotations:** `@tomReflector`

#### Constructors

```dart
TomSyncPushRequest({List<TomPendingChange>? changes})
factory TomSyncPushRequest.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changes` | `List<TomPendingChange>` | The changes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* `{"changes": [...]}`. |

### TomSyncPushResponse

The answer to a push: one result per change, in the order pushed.

- **Implements:** `TomJsonSerializable`
- **Annotations:** `@tomReflector`

#### Constructors

```dart
TomSyncPushResponse({List<TomPushResult>? results})
factory TomSyncPushResponse.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `results` | `List<TomPushResult>` | The results. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* `{"results": [...]}`. |

### TomSyncPullRequest

The body of a pull: the changes of `collection` after sequence number `since`,
at most `limit`.

- **Implements:** `TomJsonSerializable`
- **Annotations:** `@tomReflector`

#### Constructors

```dart
TomSyncPullRequest({String collection = '', int since = 0, int limit = 500})
factory TomSyncPullRequest.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `collection` | `String` | The collection. |
| `since` | `int` | The last sequence number the device has. |
| `limit` | `int` | The most changes to answer. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* `{"collection": ..., "since": ..., "limit": ...}`. |

### TomSyncPullResponse

The answer to a pull: a `TomPullBatch`, in the batch's own JSON form.

- **Implements:** `TomJsonSerializable`
- **Annotations:** `@tomReflector`

#### Constructors

```dart
TomSyncPullResponse(TomPullBatch batch)
factory TomSyncPullResponse.fromJson(Map<String, Object?> json)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `batch` | `TomPullBatch` | The batch. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | *(override)* The batch's `toJson`. |

### TomSyncApiService

The typed service interface behind `tomSyncApi`. A server implements it;
`tom_core_server`'s `TomSyncServer` is the shipped implementation.

- **Kind:** abstract class

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `push` | `Future<TomSyncPushResponse> push(TomSyncPushRequest request)` | `tomSyncPushEndpointId`: applies the request's changes in order. |
| `pull` | `Future<TomSyncPullResponse> pull(TomSyncPullRequest request)` | `tomSyncPullEndpointId`: the changes the request asks for. |

## Enums

### TomChangeOperation

What a pending change does.

| Value | Description |
| ----- | ----------- |
| `save` | Create or replace the entity with the change's data. |
| `delete` | Remove the entity. |

### TomPushOutcome

How the server took a pushed change.

| Value | Description |
| ----- | ----------- |
| `applied` | Applied; `TomPushResult.version` is the entity's version now. |
| `conflict` | Not applied: the server's version is not the change's base. The result carries what the server holds. |
| `rejected` | Not applied, and pushing it again will not help: the server refused the data. The result carries what the server holds. |

## Global Functions and Constants

| Name | Type | Description |
| ---- | ---- | ----------- |
| `tomSyncApi` | `TomApi` | The sync API: `POST /sync/push` and `POST /sync/pull` under `/sync`, both `TomAuthenticatedAccess`. Both are `POST`s so a pull right after a push is answered by the primary, not a read replica. |
| `registerTomSyncApi` | `void registerTomSyncApi()` | Registers `tomSyncApi` in the remote-API registry; idempotent. |
| `tomSyncApiId` | `String` | `'tomSync'`, the API's id in the registry. |
| `tomSyncPushEndpointId` | `String` | `'push'`, the push endpoint's id. |
| `tomSyncPullEndpointId` | `String` | `'pull'`, the pull endpoint's id. |
| `tomSyncUnknownCollectionErrorKey` | `String` | `'sync.collection.unknown'`, the error key of a pull of a collection the server does not sync. |
