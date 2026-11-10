# sync

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The server side of the offline sync protocol `tom_core_kernel`'s `offline`
module defines. A device keeps a copy of server entities, queues each change
with the version it was based on, pushes the queue and pulls what changed; this
module answers both, as `TomMemorySyncServer` does, over the entities'
repositories and a change log in their database.

An application exposes an entity under a collection name with
`TomSync.expose`. The entity needs a `@TomVersion` field and a single `String`
or `int` key — a device creates entities under ids it chooses, so a `String`
key is the usual one.

**Every write is numbered.** A change listener records each write of an
exposed entity — through the sync endpoint or anywhere else in the server — in
the change log, inside the write's transaction: a change is in the log exactly
when it committed. It is recorded unnumbered, so writes never wait on each
other; a pull first numbers the committed changes in the order they were
recorded, under the lock of the collection's counter row. A change still in an
open transaction gets its number from a later pull, after every number given
before, so a cursor never skips one.

**A push goes through the repository.** Each change is applied in a
transaction of its own: a save or a deletion only while the stored version is
the change's base, a creation only while no entity holds the id. The answer is
`applied` with the new version, `conflict` with what the server holds, or
`rejected` with a reason — the application's `validate` refused the data, the
row scope or a column grade refused the write, the data was not readable as
the entity, or an entity the caller cannot see holds the id. A listener refuses
with `TomSyncRejection`. Any other failure fails the push, and the device keeps
its changes.

**A pull reads as the caller.** The log holds ids and versions, never values;
each entity is read through its repository, so the row scope leaves out what
the caller may not read, column grades mask what they mask, and encrypted
columns arrive decrypted. A deletion carries the id alone and reaches every
device pulling the collection.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomSync` | `expose(collection, repository, validate:)` registers an entity and its change listener; `push` and `pull` are the protocol's two operations; `log` and `maxPullLimit` configure it; `reset` for tests. |
| `TomSqlSyncLog` | The change log in each synced entity's data source: `prepare` creates the tables (unless `createSchema` is off) and a collection's counter row, `append` records a change unnumbered in the caller's transaction, `number` numbers the committed ones, `after` reads a collection's changes after a cursor. |
| `TomSyncChangeRow` / `TomSyncChangeIdRow` / `TomSyncSequenceRow` | The rows the log reads. |
| `syncChangeTable` / `syncSequenceTable` | The two framework tables, `tom_sync_change` and `tom_sync_sequence`, declared once. |
| `TomSyncServer` | `POST /sync/push` and `POST /sync/pull`, the kernel's `tomSyncApi`, for an authenticated caller; constructed by the pipeline. |
| `TomSyncErrorHandler` | Answers a pull of an unknown collection or with a bad cursor or limit with a `400`. |
| `TomSyncException` | The module's failures: `sync.collection.unknown`, `sync.pull.invalid`, `sync.expose.unversioned`, `sync.expose.key`, `sync.expose.duplicate`. |
| `TomSyncRejection` | Thrown by the application to refuse a pushed change with a reason. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

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

> **A fragment, not a program.** The `main` data source and the device's
> `store` are the deployment's. `example/sync/sync_example.dart` shows the
> routes, the change log's tables and the answers given before an entity is
> reached, without a database; a push and a pull run in `test/sync_db_test.dart`.

The server's pipeline mounts `POST /sync/push` and `POST /sync/pull` itself. A
device syncs with the kernel's `TomSyncEngine` over `TomHttpSyncTransport`:

```dart
final sync = TomSyncEngine(
  store: store,
  transport: TomHttpSyncTransport(baseUri: Uri.parse('https://api.example.com')),
  collections: ['notes'],
);
```

```bash
dart run example/sync/sync_example.dart
```

`example/sync/sync_example.dart` shows what needs no database in four checked
steps: the routes from the contract, the change log's tables, a change and a
pull of a collection nothing is exposed under, and a push request on the wire.
`test/sync_db_test.dart` runs the kernel's sync contract over HTTP against this
module on MariaDB and PostgreSQL, and covers the row scope, ids another
principal holds, the endpoints' refusals and the numbering of concurrent
writes.

See [`doc/sync.md`](../../../../doc/sync.md) for the push rules, the change
log, the row scope on a pull, and wiring a server.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
