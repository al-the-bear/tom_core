# offline

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Server entities kept on the device. A client reads and changes its copy while
it is offline; every change is queued with the server version it was based on,
and a sync pushes the queue, resolves conflicts and pulls what changed on the
server.

The server is authoritative. It applies each pushed change under optimistic
locking — only when its stored version is still the change's base — and a
conflict goes to a resolver the application supplies: keep the server's value,
keep the device's, or merge the two. Without a resolver the server's value wins
and the dropped change is reported. Pulls are incremental: the server numbers
every change it applies, per collection, and the device asks for the changes
after the last number it saw.

Tom defines how cached entities are read and synced and never picks the device
database. The application implements `TomLocalStoreEngine` over SQLite, Isar,
Hive, IndexedDB or a file; `TomMemoryLocalStoreEngine` is the in-memory one.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomLocalStoreEngine` | The device database contract: JSON documents in named collections (`read`, `readAll`, `write`, `delete`), an all-or-nothing `transaction` that a nested one joins, and `close`. Collections starting with `_tom` are the framework's. |
| `TomMemoryLocalStoreEngine` | The engine in memory, for tests and for session caches. Stores documents as JSON text, so it refuses what a real engine could not store. |
| `TomOfflineStore` | The device's copy over an engine: each entity with its server version, the queue of pending changes (`_tom_pending`), the framework's values and pull cursors (`_tom_meta`). Coalesces the queue to one change per entity, which keeps its base version. |
| `TomLocalRepository<T>` | The device-side counterpart of the server's `TomRepository`: `findById`, `findAll`, `findAllById`, `existsById`, `count`, `save`, `saveAll`, `delete`, `deleteById`, `deleteAllById`, plus `versionOf` and `hasPendingChange`. Ids are strings. |
| `TomLocalEntityCodec<T>` | How a repository turns an entity into JSON and back (`toJson`, `fromJson`), and which id it has (`idOf`). |
| `TomSyncEngine` | `sync()`: pushes the queue oldest first, hands each conflict to the resolver, pulls each collection after its cursor in pages. Concurrent calls join one sync. |
| `TomSyncTransport` | The way to the server: `push` a list of changes, `pull` a collection after a sequence number. |
| `TomPendingChange` | A queued change: `changeId`, `collection`, `id`, `operation`, `data`, `baseVersion`, `queuedAt`; `toJson`, `fromJson`, `rebased`. |
| `TomChangeOperation` | `save` or `delete`. |
| `TomPushResult` | The server's answer to one change: its `outcome`, the `version`, and on a conflict or refusal the `serverData` and `reason`. |
| `TomPushOutcome` | `applied`, `conflict`, `rejected`. |
| `TomPulledChange` | One server change as pulled: `id`, `data` (`null` for a deletion), `version`, `sequence`, `deleted`. |
| `TomPullBatch` | A pull's answer: `changes`, the next `cursor`, `hasMore`. |
| `TomSyncConflict` | A change the server did not apply: the `change`, `serverData`, `serverVersion`. |
| `TomConflictResolution` | The decision: `keepServer`, `keepLocal`, or `merge(data)`. |
| `TomConflictResolver` | The application's function from a `TomSyncConflict` to a `TomConflictResolution`. |
| `TomSyncReport` | What a sync did: `applied`, `conflicts`, `discarded`, `rejected`, `pulled` per collection, `stillPending`. |
| `TomMemorySyncServer` | The protocol's server side in memory: optimistic locking on the base version, a `validate` hook that rejects, `put` and `remove` as another client, a change sequence per collection, and an `offline` switch. The reference a server endpoint follows. |
| `TomHttpSyncTransport` | The transport to a Tom server: `push` and `pull` as `POST`s to `tomSyncApi` at a `baseUri`, with the bearer token or the headers a callback answers, through a `TomResilientClient`; a status other than `200` throws `offline.http.failed`. |
| `tomSyncApi` / `registerTomSyncApi` | The protocol as a remote API: `POST /sync/push` and `POST /sync/pull` for an authenticated caller (`tomSyncApiId`, `tomSyncPushEndpointId`, `tomSyncPullEndpointId`; `tomSyncUnknownCollectionErrorKey` for a pull of an unknown collection). Both are `POST`s so a pull right after a push is answered by the primary, not a read replica. |
| `TomSyncPushRequest` / `TomSyncPushResponse` / `TomSyncPullRequest` / `TomSyncPullResponse` | The API's bodies; `TomPendingChange`, `TomPushResult`, `TomPulledChange` and `TomPullBatch` carry their JSON forms. |
| `TomSyncApiService` | The typed service interface behind `tomSyncApi`; `tom_core_server`'s `TomSyncServer` implements it. |
| `TomOfflineException` | The module's failures: `offline.store.closed`, `offline.document.not_json`, `offline.collection.reserved`, `offline.sync.transport_failed`, `offline.http.failed`. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

class Task {
  final String id;
  final String title;
  Task(this.id, this.title);
}

Future<void> main() async {
  final server = TomMemorySyncServer();
  final store = TomOfflineStore(TomMemoryLocalStoreEngine());
  final tasks = TomLocalRepository<Task>(
    store: store,
    collection: 'tasks',
    codec: TomLocalEntityCodec<Task>(
      toJson: (t) => {'id': t.id, 'title': t.title},
      fromJson: (j) => Task(j['id']! as String, j['title']! as String),
      idOf: (t) => t.id,
    ),
  );
  final sync = TomSyncEngine(
    store: store,
    transport: server,
    collections: ['tasks'],
  );

  await tasks.save(Task('t1', 'Write the report'));
  print(await tasks.hasPendingChange('t1')); // true

  final report = await sync.sync();
  print(report.applied.length); // 1
  print(await tasks.versionOf('t1')); // 1
}
```

The save is readable at once and waits in the queue. The sync pushes it, the
server answers version 1, and the device's entity takes that version. A real
application passes its own engine and a transport to its server in place of
`TomMemoryLocalStoreEngine` and `TomMemorySyncServer`; nothing else changes.

A Tom server serves the protocol through `tom_core_server`'s `sync` module,
and a device reaches it with `TomHttpSyncTransport` in place of the in-memory
server — see
[The Protocol over HTTP](../../../../doc/offline/offline.md#the-protocol-over-http).

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
