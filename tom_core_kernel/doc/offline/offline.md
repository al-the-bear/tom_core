# Offline Module

The Offline module keeps a copy of server entities on the device, so a client
reads and changes its data while it has no connection. Every change waits in a
queue with the server version it was based on; a sync pushes the queue, settles
conflicts with the application's rules, and pulls what changed on the server.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [Runnable examples](#runnable-examples)
- [Concepts](#concepts)
  - [The server is authoritative](#the-server-is-authoritative)
  - [Versions and the base version](#versions-and-the-base-version)
  - [Collections](#collections)
- [The Engine Contract](#the-engine-contract)
  - [The in-memory engine](#the-in-memory-engine)
- [The Repository](#the-repository)
- [The Queue of Pending Changes](#the-queue-of-pending-changes)
- [The Sync Flow](#the-sync-flow)
  - [Pushing](#pushing)
  - [A save made while a push is out](#a-save-made-while-a-push-is-out)
  - [When the network fails](#when-the-network-fails)
- [Conflicts](#conflicts)
  - [The default: the server wins](#the-default-the-server-wins)
  - [Keeping the device's value](#keeping-the-devices-value)
  - [Merging](#merging)
  - [Refusals](#refusals)
- [Pulls](#pulls)
- [The Protocol's Server Side](#the-protocols-server-side)
- [The Protocol over HTTP](#the-protocol-over-http)
  - [The API contract](#the-api-contract)
  - [The HTTP transport](#the-http-transport)
- [Writing an Engine Adapter](#writing-an-engine-adapter)
- [Error Keys](#error-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomLocalStoreEngine` | abstract class | The device database: JSON documents in named collections, transactions, `close`. The application implements it. |
| `TomMemoryLocalStoreEngine` | class | The engine in memory, for tests and session caches. |
| `TomOfflineStore` | class | Entities with their server versions, the queue of pending changes, and the framework's own values over an engine. |
| `TomLocalEntityCodec<T>` | class | An entity to JSON and back, and its id. |
| `TomLocalRepository<T>` | class | The server `TomRepository`'s reads and writes against the device's copy; every write queued. |
| `TomChangeOperation` | enum | `save`, `delete`. |
| `TomPendingChange` | class | One queued change, with the version it was based on. |
| `TomPushOutcome` | enum | `applied`, `conflict`, `rejected`. |
| `TomPushResult` | class | The server's answer to one pushed change. |
| `TomPulledChange` | class | One server change, as pulled. |
| `TomPullBatch` | class | A page of pulled changes, the next cursor, whether more follow. |
| `TomSyncTransport` | abstract class | `push` and `pull` — the way to the server. |
| `TomSyncConflict` | class | A change the server did not apply, with what the server holds. |
| `TomConflictResolution` | sealed class | `keepServer`, `keepLocal`, `merge(data)`. |
| `TomConflictResolver` | typedef | The application's decision for a conflict. |
| `TomSyncReport` | class | What one sync did. |
| `TomSyncEngine` | class | Push, resolve, pull. |
| `TomMemorySyncServer` | class | The protocol's server side in memory: the reference semantics, and a transport for tests. |
| `TomHttpSyncTransport` | class | The transport to a Tom server: `push` and `pull` as `POST`s to the sync API. |
| `tomSyncApi` | final TomApi | The sync API's declaration: `POST /sync/push` and `POST /sync/pull`, for an authenticated caller. |
| `TomSyncApiService` | abstract class | The typed service interface behind `tomSyncApi`; a server implements it. |
| `TomSyncPushRequest` / `TomSyncPushResponse` | class | A push's body and its answer: the changes, and one result per change. |
| `TomSyncPullRequest` / `TomSyncPullResponse` | class | A pull's body (collection, cursor, limit) and its answer, a `TomPullBatch`. |
| `registerTomSyncApi` | function | Registers `tomSyncApi` in the remote-API registry; idempotent. |
| `tomSyncApiId` / `tomSyncPushEndpointId` / `tomSyncPullEndpointId` / `tomSyncUnknownCollectionErrorKey` | const String | The API's id, its endpoints' ids, and `sync.collection.unknown`. |
| `TomOfflineException` | class | The module's failures, with `offline.*` keys. |

Tom defines how cached entities are read and synced, and never picks the device
database. An application implements `TomLocalStoreEngine` over SQLite, Isar,
Hive, IndexedDB or a file; everything above the engine is the same whichever it
chose. The module has no `dart:io` import and compiles for the web.

`tom_core_server` serves the protocol through its `sync` module, and
`TomHttpSyncTransport` is the device's way to it.

## Quick Start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

class Task {
  final String id;
  final String title;
  final bool done;
  Task(this.id, this.title, {this.done = false});
}

Future<void> main() async {
  final taskCodec = TomLocalEntityCodec<Task>(
    toJson: (t) => {'id': t.id, 'title': t.title, 'done': t.done},
    fromJson: (j) => Task(
      j['id']! as String,
      j['title']! as String,
      done: j['done']! as bool,
    ),
    idOf: (t) => t.id,
  );
  final server = TomMemorySyncServer();
  final store = TomOfflineStore(TomMemoryLocalStoreEngine());
  final tasks = TomLocalRepository<Task>(
    store: store,
    collection: 'tasks',
    codec: taskCodec,
  );
  final sync = TomSyncEngine(
    store: store,
    transport: server,
    collections: ['tasks'],
  );

  // Offline: written and readable at once, queued for the server.
  await tasks.save(Task('t1', 'Write the report'));
  print((await store.pending()).length); // 1

  // Online: the queue goes out, the server's changes come in.
  server.put('tasks', 't2', {'id': 't2', 'title': 'Review', 'done': false});
  final report = await sync.sync();
  print(report.applied.length); // 1
  print(report.pulled['tasks']); // 1
  print(await tasks.count()); // 2
}
```

In an application the engine is the adapter over its database, and the
transport is `TomHttpSyncTransport` to its server (see
[The Protocol over HTTP](#the-protocol-over-http)).

### Runnable examples

[`example/samples/offline/`](../../example/samples/offline/) runs and asserts
everything this guide describes.

| File | What it shows |
| ---- | ------------- |
| [`01_offline_sync_example.dart`](../../example/samples/offline/01_offline_sync_example.dart) | A save offline, read back and queued; the push and the version the server answers; another client's change pulled; a deletion; a conflict settled by the application's merge |

```bash
dart run --enable-asserts example/samples/offline/00_run_all_examples.dart
```

## Concepts

### The server is authoritative

The device holds a copy. When the device and the server disagree about an
entity, the server's state stands unless the application decides otherwise for
that conflict. A change the device makes is a request to the server, queued
until it can be sent; the server applies it, or answers why not.

### Versions and the base version

The server numbers each entity's state: version 1 when it is created, one more
on every change, a deletion included. The device stores each entity with the
version it last received from the server, and a change made on the device
carries that version as its **base version**. An entity created on the device
has no version, and its first change has no base.

The server applies a change only when its own version is still the base. That
is optimistic locking: nothing is reserved while the device is offline, and a
change made against a state the server has since moved past is not applied
blindly over it — it comes back as a conflict.

### Collections

An engine stores documents in named collections. A collection is an entity kind
and carries the server's name for it, because pushes and pulls name it too.
Collections whose name starts with `_tom` belong to the framework:

| Collection | Holds |
| ---------- | ----- |
| `_tom_pending` (`TomOfflineStore.pendingCollection`) | The queue of pending changes. |
| `_tom_meta` (`TomOfflineStore.metaCollection`) | The framework's values: the pending-change counter, and one pull cursor per collection (`cursor:<collection>`). |

`TomLocalRepository` and `TomSyncEngine` refuse a collection name that is empty
or starts with `_tom` (`offline.collection.reserved`).

## The Engine Contract

`TomLocalStoreEngine` is everything the module asks of the device database:

| Method | Contract |
| ------ | -------- |
| `read(collection, id)` | The document, or `null`. |
| `readAll(collection)` | Every document of the collection, by id; an empty map for an unknown collection. |
| `write(collection, id, document)` | Store the document, replacing what was there. |
| `delete(collection, id)` | Remove it; answer whether it was there. |
| `transaction(body)` | Run `body` so that its writes happen all or not at all. No other transaction of the engine interleaves with it. A transaction started inside `body` joins it rather than waiting for it — otherwise it would wait for itself. |
| `close()` | Release the database. |

Documents are JSON maps: strings, numbers, booleans, `null`, lists and maps.
Each entity is stored as `{"data": <the entity's JSON>, "version": <int>}`, the
version left out for an entity the server has not seen.

The module relies on the transaction for its consistency. A save writes the
entity and its queue entry in one transaction, and a sync writes each server
answer — the new version, the queue change — in one. An engine that cannot
roll back leaves a half-written save behind when a write fails.

### The in-memory engine

`TomMemoryLocalStoreEngine` keeps everything in memory and nothing across a
restart. It is the engine for tests, and for an application that wants a
session cache. It keeps the contract exactly:

- A transaction works on a copy of the data, which replaces the data only when
  the body completes; a failing body leaves nothing behind.
- Transactions run one at a time; a nested one joins the outer one.
- Documents are stored as JSON text, so a value a real engine could not store —
  a `DateTime`, an object — is refused (`offline.document.not_json`) here too.
- After `close`, every call throws `offline.store.closed`.

## The Repository

`TomLocalRepository<T>` offers the reads and writes of the server's
`TomRepository`, against the device's copy:

| Method | Answers |
| ------ | ------- |
| `findById(id)` | The entity, or `null`. |
| `findAll()` | Every entity, ordered by id. |
| `findAllById(ids)` | The entities the device holds among `ids`, in the order asked. |
| `existsById(ids)` | Whether the device holds every one. |
| `count()` | How many the device holds. |
| `save(entity)` | Stores and queues it; answers it. |
| `saveAll(entities)` | All of them, in one transaction. |
| `delete(entity)` / `deleteById(id)` | Removes and queues the deletion; `deleteById` answers 0 or 1. |
| `deleteAllById(ids)` | All of them, in one transaction; answers how many went. |
| `versionOf(id)` | The server version the entity is based on; `null` for one the server has not seen. |
| `hasPendingChange(id)` | Whether the entity has a change the server has not taken. |

Reads answer what the device holds, its own unsynced changes included: a task
saved offline is found at once. Ids are strings — the entity's server key in
its string form. A `TomLocalEntityCodec<T>` turns the entity into the JSON the
engine stores and back, and names its id:

```dart
final noteCodec = TomLocalEntityCodec<Note>(
  toJson: (n) => {'id': n.id, 'text': n.text},
  fromJson: (j) => Note(j['id']! as String, j['text']! as String),
  idOf: (n) => n.id,
);
```

The JSON a codec writes is the JSON the server receives in a push and sends in
a pull, so it is the entity's wire form.

## The Queue of Pending Changes

Every write on the device queues a `TomPendingChange`. Four rules keep the queue
small and correct:

1. **One change per entity.** A second save of an entity that already has a
   queued change replaces that change. It keeps its place in the queue, its
   `changeId` and its base version, and takes the newest data. The server sees
   the entity's latest state once, based on what it last gave the device.
2. **A deletion replaces a queued save.** Deleting an entity with a queued save
   queues the deletion in its place, with the same base version.
3. **An entity the server never saw is forgotten.** Deleting an entity without
   a version removes it and its queued creation, and nothing is sent.
4. **Oldest first.** Queue entries are numbered by a counter kept in
   `_tom_meta`; a sync pushes them in that order.

The queue lives in the engine, so it survives a restart with whatever database
the application supplied. `TomOfflineStore.pending()` lists it.

## The Sync Flow

`TomSyncEngine.sync()` pushes, then pulls, and answers a `TomSyncReport`:

| Field | Holds |
| ----- | ----- |
| `applied` | The changes the server applied. |
| `conflicts` | Every conflict met, whatever was decided. |
| `discarded` | The device's changes dropped for the server's state: conflicts resolved as `keepServer`, and refusals. |
| `rejected` | The changes the server refused, with its reason. |
| `pulled` | How many server changes were written into the device's copy, per collection. |
| `stillPending` | How many changes are still queued afterwards. |

A `sync()` called while one runs joins it and answers the same report.

### Pushing

The engine sends the whole queue, oldest first, in one `push`, and handles each
answer by its `changeId`:

- **applied** — the device's entity takes the version the server answered, and
  the change leaves the queue.
- **conflict** — the resolver decides; see [Conflicts](#conflicts).
- **rejected** — the device takes the server's value back, and the change is
  reported in `rejected` and `discarded`; see [Refusals](#refusals).

A change the server did not answer stays queued for the next sync. A change
decided for the device's state (`keepLocal` or `merge`) is pushed again in the
same sync, based on the server's version. The engine makes at most
`maxPushRounds` push rounds (three by default); a change still in conflict after
the last round stays queued, and `stillPending` counts it.

### A save made while a push is out

A push takes time, and the application may save the same entity again before
the answer arrives. When the server answers `applied`, the engine compares the
queued change with the one it pushed. If the queued change is newer, it stays
queued, rebased on the version the server just answered, so the next push is
not a conflict with the device's own previous change.

### When the network fails

A transport that throws makes the sync throw `TomOfflineException` with the key
`offline.sync.transport_failed`, the transport's error as its root exception.
A failed push changes nothing: every change stays queued for the next sync. A
failed pull keeps every page already written and the cursor after it; the next
sync carries on from there. A `TomOfflineException` a transport's `push`
raises itself reaches the caller unchanged; anything a `pull` raises is wrapped.

```dart
try {
  await sync.sync();
} on TomOfflineException catch (e) {
  if (e.key != 'offline.sync.transport_failed') rethrow;
  // Offline. The queue is intact; try again when the connection returns.
}
```

## Conflicts

A conflict is a pushed change the server did not apply because its version is
not the change's base: another client changed or deleted the entity, or created
one under the same id. The engine builds a `TomSyncConflict` — the device's
`change`, the server's `serverData` and `serverVersion`, both `null` when the
server does not have the entity — and asks the `TomConflictResolver` given to
the `TomSyncEngine` constructor:

```dart
typedef TomConflictResolver =
    FutureOr<TomConflictResolution> Function(TomSyncConflict conflict);
```

The resolver may be asynchronous — it may ask the user. Each decision, and
what follows from it, is written in one transaction.

### The default: the server wins

Without a resolver every conflict is resolved as
`TomConflictResolution.keepServer`: the device takes the server's entity and
version (or removes its copy when the server deleted it), and the device's
change is dropped. Nothing is lost silently — the dropped change is in the
report's `discarded`, with its data, for the application to show or log.

### Keeping the device's value

`TomConflictResolution.keepLocal` keeps the device's change and pushes it again,
based on the server's version. The device's state overwrites the server's.

### Merging

`TomConflictResolution.merge(data)` stores `data` on the device and pushes it,
based on the server's version. The merge is the application's: the framework
does not merge fields. The sample keeps the server's title and keeps a task done
when either side marked it done:

```dart
final sync = TomSyncEngine(
  store: store,
  transport: transport,
  collections: ['tasks'],
  resolver: (conflict) => TomConflictResolution.merge({
    ...conflict.serverData ?? conflict.change.data!,
    'done':
        (conflict.serverData?['done'] == true) ||
        (conflict.change.data?['done'] == true),
  }),
);
```

### Refusals

The server may refuse a change outright — its data fails validation, the user
may not change the entity. The push answers `rejected` with a `reason` and the
entity as the server holds it. Pushing again would not help, so the resolver is
not asked: the device takes the server's value back and the change is reported.

## Pulls

After pushing, the engine pulls each collection named in `collections`. The
server numbers every change it applies with the next number of the collection's
**change sequence**. The engine keeps one cursor per collection — the last
sequence number it received — and asks for the changes after it, `pullLimit`
(500 by default) at a time, until a batch says `hasMore: false`. Each batch is
written in one transaction together with the new cursor.

A pulled change writes the server's entity and version into the device's copy,
or removes the device's copy for a deletion. An entity with a change still
queued is left as it is: the next push settles it, and if the server moved
past its base, that push comes back as a conflict carrying the server's state.

Pushes cover every queued change, whatever its collection. Pulls cover only the
collections the engine names.

## The Protocol's Server Side

`TomMemorySyncServer` implements `TomSyncTransport` in memory. It is the
reference a server endpoint follows, and the transport tests sync against:

- **Versions.** `put` and an applied save store the entity at its version plus
  one (1 for a new entity); `remove` and an applied deletion record the version
  plus one.
- **Optimistic locking.** A pushed change is applied only when the entity's
  version equals the change's base: a creation (no base) only when the server
  does not have the entity. Otherwise it answers `conflict` with the server's
  data and version.
- **Refusal.** The `validate` hook may refuse a save's data with a reason; the
  push then answers `rejected` with the server's data.
- **The change sequence.** Every applied change — pushed, or made through `put`
  and `remove` as another client's would be — takes the next number of its
  collection's sequence. `pull` answers the changes after a number, in order,
  at most `limit`, with `cursor` the last number included and `hasMore`.
  Deletions are in the sequence with `data: null`, so a device learns of them.
- **Testing aids.** `pushes` counts the pushes received; setting `offline` to
  an error makes every push and pull throw it.

`tom_core_server`'s `sync` module serves the protocol with the same semantics
over the entities' repositories (see its `doc/sync.md`). The sync contract,
`test/contracts/sync_protocol_contract.dart` (`runTomSyncContract`), holds
both to them: `test/offline_test.dart` runs it against `TomMemorySyncServer`
directly and over HTTP, and `tom_core_server`'s `test/sync_db_test.dart`
against a Tom server on MariaDB and PostgreSQL.

## The Protocol over HTTP

### The API contract

`tomSyncApi` declares the protocol as a remote API, so the route a server
serves and the URI a device calls are one declaration:

```json
POST /sync/push   {"changes": [<TomPendingChange.toJson>, ...]}
  → {"results": [<TomPushResult.toJson>, ...]}
POST /sync/pull   {"collection": "notes", "since": 12, "limit": 500}
  → {"changes": [<TomPulledChange.toJson>, ...], "cursor": 14,
     "hasMore": false}
```

Both endpoints are `TomAuthenticatedAccess`. `TomSyncPushRequest`,
`TomSyncPushResponse`, `TomSyncPullRequest` and `TomSyncPullResponse` are the
bodies; `TomPendingChange`, `TomPushResult`, `TomPulledChange` and
`TomPullBatch` carry their own `toJson` and `fromJson`. A pulled deletion
travels with `"data": null`. `TomSyncApiService` is the typed interface a server
implements; `tom_core_server`'s `TomSyncServer` is that implementation.

**Both endpoints are `POST`s, the pull included.** A pull is a read, but it is
the read a device makes right after its own push and has to see that push. A
`GET` is read-only work, which a server with read replicas answers from a
replica that may not have the push yet.

A pull of a collection the server does not sync is refused with `400` and the
error key `sync.collection.unknown` (`tomSyncUnknownCollectionErrorKey`). A
pushed change of such a collection is answered `rejected` with that reason.

### The HTTP transport

```dart
final sync = TomSyncEngine(
  store: store,
  transport: TomHttpSyncTransport(baseUri: Uri.parse('https://api.example.com')),
  collections: ['notes'],
);
```

`TomHttpSyncTransport({baseUri, client, headers})` calls the API at `baseUri`,
the server root; the API's own path is appended from the contract. Every
request carries the headers the `headers` callback answers, computed per
request so a rotating credential is current. Without an `Authorization` among
them, the bearer token of `TomBearerAuthentication` is sent.

Requests go through `client`, by default a `TomResilientClient`. A push is not
idempotent at the HTTP level, so the client does not retry it. A failed push
leaves the changes queued for the next sync, which the server answers by their
base versions.

A status other than `200` throws `TomOfflineException` with the key
`offline.http.failed`, carrying the endpoint, the status and the error key of
the server's error envelope when it has one. The sync engine reports a failed
pull as `offline.sync.transport_failed` and a failed push unchanged, and keeps
every change. `close()` closes the HTTP client.

## Writing an Engine Adapter

An adapter keeps the [engine contract](#the-engine-contract): JSON documents in
collections, transactions that are all or nothing, serialised, and joined when
nested. A sketch over SQLite with `package:sqlite3`, one table for every
collection:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

class SqliteStoreEngine extends TomLocalStoreEngine {
  static final Object _inTransaction = Object();
  final Database db;
  Future<void> _last = Future.value();

  SqliteStoreEngine(this.db) {
    db.execute('CREATE TABLE IF NOT EXISTS docs '
        '(coll TEXT, id TEXT, body TEXT, PRIMARY KEY (coll, id))');
  }

  @override
  Future<Map<String, Object?>?> read(String collection, String id) async {
    final rows = db.select(
        'SELECT body FROM docs WHERE coll = ? AND id = ?', [collection, id]);
    return rows.isEmpty
        ? null
        : (jsonDecode(rows.first['body'] as String) as Map)
            .cast<String, Object?>();
  }

  @override
  Future<Map<String, Map<String, Object?>>> readAll(String collection) async => {
        for (final row in db.select(
            'SELECT id, body FROM docs WHERE coll = ?', [collection]))
          row['id'] as String:
              (jsonDecode(row['body'] as String) as Map).cast<String, Object?>(),
      };

  @override
  Future<void> write(
          String collection, String id, Map<String, Object?> document) async =>
      db.execute('INSERT OR REPLACE INTO docs VALUES (?, ?, ?)',
          [collection, id, jsonEncode(document)]);

  @override
  Future<bool> delete(String collection, String id) async {
    db.execute('DELETE FROM docs WHERE coll = ? AND id = ?', [collection, id]);
    return db.updatedRows > 0;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() body) {
    if (Zone.current[_inTransaction] == this) return body(); // nested: join
    final result = Completer<T>();
    _last = _last.then((_) async {
      db.execute('BEGIN IMMEDIATE');
      try {
        final value =
            await runZoned(body, zoneValues: {_inTransaction: this});
        db.execute('COMMIT');
        result.complete(value);
      } catch (error, stack) {
        db.execute('ROLLBACK');
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  Future<void> close() async => db.dispose();
}
```

The zone value is how a nested transaction recognises that it runs inside one;
the future chain is what serialises them. A database with its own transaction
API — Isar's `writeTxn`, IndexedDB's transactions — keeps the same two rules
around it. Run the module's tests against the adapter by swapping it for
`TomMemoryLocalStoreEngine` in `test/offline_test.dart`'s set-ups.

## Error Keys

Every failure is a `TomOfflineException` (extends `TomException`).

| Key | When | Parameters |
| --- | ---- | ---------- |
| `offline.store.closed` | A `TomMemoryLocalStoreEngine` was used after `close`. | — |
| `offline.document.not_json` | A document holds a value JSON cannot encode. | `collection`, `id` |
| `offline.collection.reserved` | A repository or sync engine was given an empty collection name or one starting with `_tom`. | `collection` |
| `offline.sync.transport_failed` | The transport threw during a sync's push or pull. The queue is intact. | `changes` (push); `collection`, `since` (pull) |
| `offline.http.failed` | `TomHttpSyncTransport`'s request was answered with a status other than `200`. | `endpoint`, `status`, `errorKey` (when the answer carried one) |

## Not Yet Implemented

- **No live updates.** A device learns of a server change when it pulls; the
  protocol has no channel on which the server announces one.
  <!-- unpinned: absence — the protocol has push and pull only -->
- **No queries beyond ids.** `TomLocalRepository` reads by id and reads
  everything; it has no criteria, sorting or paging of the server
  `TomRepository`. An application filters `findAll()`, or queries its engine's
  database directly.
  <!-- unpinned: absence — TomLocalRepository has no query API -->
- **Conflicts are per entity.** The framework does not compare fields; a field
  merge is what the application's resolver writes.
  <!-- pinned: test/offline_test.dart › pushes the application's merge -->
- **The queue is read whole.** Finding an entity's queued change reads the
  entire queue, so a save costs more as the queue grows. The queue holds one
  change per entity, which bounds it by the number of entities changed offline.
  <!-- unpinned: absence — no index over the queue exists -->

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `local_repository.dart`, `local_store.dart`, `memory_sync_server.dart`, `sync_engine.dart`, `sync_protocol.dart` | `Completer`, `Zone` and `runZoned` for the in-memory engine's serialised, joinable transactions; `FutureOr` in `TomConflictResolver` |
| `dart:convert` | dart | `http_sync_transport.dart`, `local_store.dart`, `sync_engine.dart` | `jsonEncode` / `jsonDecode`, how the in-memory engine stores documents, how the sync engine compares a queued change with the one it pushed, and the HTTP transport's bodies; `utf8` to read an answer |
| `http` | package | `http_sync_transport.dart` | `Client` and `Response`, the HTTP transport's requests |
| [http_connection](../http_connection/http_connection.md) | module | `http_sync_transport.dart`, `sync_contract.dart` | `TomApi`, `TomApiEndpoint` and `tomRemoteApis`, the sync API's declaration and registration; `TomHttpMethod`; `TomResilientClient`, the transport's default client |
| [json](../json/json.md) | module | `sync_contract.dart` | `TomJsonSerializable`, which the API's bodies implement |
| [little_things](../little_things/little_things.md) | module | `local_store.dart` | `TomException`, the base of `TomOfflineException` |
| [reflection](../reflection/reflection.md) | module | `sync_contract.dart` | `tomReflector` on the API's bodies, so the server's pipeline binds them |
| [security](../security/security.md) | module | `http_sync_transport.dart`, `sync_contract.dart` | `TomAuthenticatedAccess` on both endpoints; `TomBearerAuthentication.token`, the transport's default credential |

The module imports nothing from `dart:io`, so it compiles for the web. It does not import `tom_core_server`: `TomLocalRepository` mirrors
the server's `TomRepository` by its operations, not by a shared type.
