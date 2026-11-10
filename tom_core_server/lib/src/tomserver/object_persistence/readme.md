# object_persistence

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Annotation-driven object/relational persistence. A reflected entity is mapped to
a table with `@TomDbTable` / `@TomDbColumn` / `@TomEntityId` / `@TomReference`;
the `TomAnnotationAnalyzer` reads that mapping. `TomRepository<T, K>` is the CRUD
contract (`save`, `findById`, `findAll`, `delete`, `count`, plus the
`*ByQuery` variants); `TomSqlDatasourceRepository` implements it over a
`datasources` `TomDataSource`. A typed query DSL (`TomQueryBuilder` mixin +
column/operator expressions) builds `WHERE` clauses without raw SQL, and a
`TomSubquery` tested by `TomExists` or `TomInSubquery` builds a predicate about
another result set. A query sentence filters on what an association reaches —
`find by roles.name = :n`, `find by roles is empty` — through a correlated
`EXISTS`, so an owning row is answered once however many associated rows match.

The four finders take an optional `TomPageRequest`, so a caller asks for page N
of size M with a multi-column, mixed-direction sort instead of loading the table.
A window is applied *before* the row scope, so the page is cut out of the rows
the principal may see and `count()` reports that same scoped total — page
metadata cannot leak a row count the principal is not allowed to read.

Entities can also carry a **row scope**: `@TomDbScope` narrows every query to the
rows the current principal may see, and the repository rejects writes that fall
outside it. An entity with a `resource_key` column is scoped by the principal's
resource grants automatically, without an annotation — `@TomDbScope.unscoped()`
is the explicit opt-out.

A `@TomVersion` field turns on **optimistic locking**: every update and
`delete(entity)` matches the row only at the version the caller loaded, so of
two saves of one loaded row the second raises `TomOptimisticLockException`
instead of silently overwriting the first.

A `String` field annotated `@TomEncrypted` is **encrypted at rest**: the
repository stores AES-256-GCM ciphertext and the data source decrypts it on
read, so the database, its backups and its replicas never hold the plaintext.
The data keys live in `tom_encryption_key` wrapped under a key-encryption key
that never touches the database, and rotate without downtime; a
`@TomBlindIndex` column makes an encrypted field findable by value.

Around every repository write sits the **entity lifecycle**
(`entity_lifecycle.dart`). `@TomSoftDelete` turns every repository delete into
setting a deletion time and leaves the rows that carry one out of every read
(`TomSoftDelete.includingDeleted` shows them; `restoreById` and `purgeById`
undo and finish a delete). `@TomHistory` copies the row as it was into a history
table before every update, delete and restore (`historyOf` reads it back). A
`TomEntityListener` registered with `TomEntityLifecycle` runs before and after
every save and delete of its entity, and a change listener is told of every
change as a `TomEntityChange` — the feed of a transactional outbox, because an
observed entity's write, its history and its listeners' writes run in one
transaction.

A repository's audit record carries, beside the before and after values, the
data subject each `@TomPersonal` value belongs to, so that with the privacy
module's subject keys installed the trail seals those values per person and an
erasure can make them unreadable (see
[`doc/privacy.md`](../../../../doc/privacy.md)).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDbTable` · `TomDbColumn` · `TomEntityId` · `TomReference` | Mapping annotations placed on a reflected entity. |
| `TomAnnotationAnalyzer` | Mixin that reads the mapping annotations off an entity. |
| `TomRepository<T, K>` | CRUD contract: `save`, `findById`, `findAll`, `delete`/`deleteById`, `count`, `existsById`, and `*ByQuery` / `*ByQuerySentence`. |
| `TomSqlDatasourceRepository<T, K>` | SQL implementation over a `TomDataSource`; subclass and override `sqlDialect`. `upsert(entity, conflictFields:)` writes by a unique business key in one statement (refused with `crud_repository.upsert.unsupported` where `upsertBlocker` names a feature that needs the stored row, and with `crud_repository.upsert.unscoped_conflict_key` when the key omits the scope or tenant field); `saveByKey` upserts where it may and otherwise finds the row by the key and saves it. `insert(entity)` inserts under the key the entity holds — a caller-chosen id, which `save` would update — through the same write path. |
| `TomVersion` · `TomOptimisticLockException` | The `int` field holding a row's version, which the repository writes and checks on every update and `delete(entity)`; and the refusal of a write whose version moved, carrying the version held and the one stored. |
| `TomCompositeKey` | The `K` of an entity whose `primaryKeyFields` lists several fields — a join table keyed by its two foreign keys — keyed by field name. |
| `TomPageRequest` · `TomSortField` · `TomSortDirection` | The optional row window (`offset` + `limit`) and per-field sort the finders accept; an unsorted window gets every primary-key field appended so consecutive pages partition the result. |
| `TomQueryBuilder` | Mixin offering `isNull` / `isNotNull` / `isIn` / `between` / `like` / `exists` / `notExists` / `isInSubquery` / `isNotInSubquery` plus the `Eq` / `Neq` / `And` / `Or` / `Not` operators and the typed column references (`IntCol`, `StringCol`, …). |
| `TomSubquery` · `TomExists` · `TomInSubquery` | A subquery over entity types — `SELECT <projection or 1> FROM … WHERE …`, a `@TomSoftDelete` type's live-row test included — and the `EXISTS` and `IN (SELECT …)` predicates over it (`subquery.dart`). Opaque to the walks over the enclosing tree; correlated by naming a column of the enclosing query's table. |
| `TomTenantTable` | Classifies an entity as a tenant table: the repository routes it to the current tenant's schema or database and binds the tenant into every statement; every other entity is a system table, never routed. A tenant table and a system table never meet in one statement, and one transaction over both on two data sources needs two-phase data sources. |
| `TomDbScope` | Annotation declaring an entity's row scope — its scope field and kind — or, as `TomDbScope.unscoped()`, the deliberate opt-out. |
| `TomDataScopeRegistry` | The named scope-kind resolvers (`owner`, `group`, `resource`, plus application kinds), sync or async, read and write. |
| `TomDataScope` | Renders a resolver's answer into a bound `IN` (or OR-union) predicate; `runUnscoped` is the recursion guard async resolvers run their own reads inside. |
| `TomResourceScopeSource` | The hook behind the `resource` kind, implemented and installed by the authorization module. |
| `TomColumnAuthorization` · `TomColumnWriteDecision` | The per-column half of the same idea: which columns of a row this principal may *write*, resolved through a `TomColumnAuthResolver` — or a `TomRowColumnAuthResolver` when the answer depends on the row. |
| `TomFileReference` · `TomFileReferenceKeys` | Marks a `String` column as holding a blob storage key rather than the bytes, and mints the keys for it. The bytes live in the file-storage module; the column holds the way back to them. |
| `TomEncrypted` · `TomBlindIndex` · `TomBlindIndexNormalization` | Mark a `String` field encrypted at rest, and a companion column its blind index — an HMAC of the normalised plaintext, which a lookup compares. |
| `TomFieldEncryption` | The cipher the repository and the data source call (`field_encryption.dart`): encrypt, decrypt, the blind-index lookup `blindIndexCondition`, raw reads and audit redaction, over the installed keyring. |
| `TomFieldKeyring` · `TomKeyEncryptionKey` · `TomAesKeyEncryptionKey` · `TomKeyEncryptionKeyFactory` | The data keys, unwrapped and cached, and the key-encryption key that wraps them; rotates data keys, index keys and key-encryption keys. A key held by a key-management service is a kind a package registers (`TomFieldEncryption.registerKeyKind`) and a `fieldEncryption.keys` entry names. |
| `TomAesGcm` | The AES-256-GCM cipher underneath field encryption and key wrapping, public because the privacy module seals audit values with it too. |
| `TomDataKeyStore` · `TomSqlDataKeyStore` · `TomMemoryDataKeyStore` · `TomDataKeyRecord` · `TomDataKeyRow` · `TomDataKeyPurpose` · `TomDataKeyState` | Where the wrapped data keys are kept — `tom_encryption_key`, declared once by `encryptionKeyTable` in `field_encryption_sql.dart` — and one key as stored. Keyed by tenant: a tenant table's values are encrypted under the tenant in context's keys, kept in its data source; a system table's under the system's (`TomFieldEncryption.forEntity`, `isSystemScope`). |
| `TomFieldReencryption` · `TomReencryptionReport` | The background pass, runnable as a scheduler job, that rewrites values under a previous key, encrypts plaintext and fills blind indexes. |
| `TomFieldEncryptionException` | Every refusal of field encryption, keyed `field_encryption.*`. |
| `TomSoftDelete` · `TomHistory` · `TomHistoryEntry` · `TomHistoryMeta` | Soft delete and history tables (`entity_lifecycle.dart`): the declarations, one past version as `historyOf` answers it, and the history table's own columns. |
| `TomEntityListener` · `TomEntityLifecycle` · `TomEntityChange` · `TomEntityChangeKind` · `TomEntityChangeListener` · `TomEntityLifecycleException` | The hooks of one entity's writes, the registry of hooks and change listeners, one change and its JSON form, and the refusal of a declaration the repository cannot carry out. |
| `TomBlobMigration` · `TomBlobMigrationReport` | Moves the blobs those columns name from one blob store to another. The key list comes from the rows because a blob store cannot enumerate itself — which makes a file column the index of what a deployment stored, and the sweep read-only on the database. |
| `TomBlobOrphanSweep` · `TomBlobOrphanSweepReport` · `TomBlobReferenceSource` · `TomRepositoryBlobReferences` | Deletes the keys of a `TomDeduplicatingBlobStore` no row refers to (`blob_orphan_sweep.dart`), once they are older than a grace period, then reclaims their content; also as the job `tom.storage.orphan_sweep`. The store's ledger supplies the keys, and a `TomRepositoryBlobReferences` asks an entity's `@TomFileReference` columns, soft-deleted rows included, which of them are referenced. Refused inside a request (`storage.sweep.scoped_run`), whose data scope would hide references. |
| `MariadbRepository<T, K>` | The MariaDB binding of `TomSqlDatasourceRepository` — constructed directly, and the only thing it adds is a pinned `MariadbSqlDialect`. A repository extending `TomSqlDatasourceRepository` directly renders through its data source's dialect, so it serves MariaDB and PostgreSQL alike. |
| `TomQuerySentenceCompiler` | Compiles a written sentence (`find by owner = :who order by created_at`) into the same operator tree the builder produces, so a query can be data. A term on a `@TomReference` field — `<association>.<field> <test>`, `<association> is empty` — compiles to a correlated `EXISTS`. |
| `TomGroupedSelect` · `TomGroupedRow` · `TomAggregate` | `GROUP BY` and its aggregates — `CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max` — projected under an alias and read back off the row by it. A `DateTime` alias reads back UTC, through the one instant convention the data source writes (`datasources/sql_instant.dart`). |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A reflected entity mapped to a table by annotations:
@tomReflector
@TomDbTable(datasource: 'todo', table: 'todo_item', primaryKeyFields: ['id'])
class TodoItem {
  // Nullable, and null until first persisted: `save` inserts when the key is
  // null or negative and updates otherwise. `0` is a legitimate key value, not
  // a sentinel, so an `int id = 0` would take the update arm on its very first
  // save and quietly write nothing. Declare `int? id;`, or `int id = -1;` if
  // the key must be non-nullable.
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  int? id;

  @TomDbColumn(columnName: 'title')
  String title = '';
}

void main() {
  final item = TodoItem()..title = 'write the readme';
  // A TomSqlDatasourceRepository<TodoItem, int> then persists it:
  //   await repository.save(item);
  print(item.title); // write the readme
}
```

See [`doc/object_persistence.md`](../../../../doc/object_persistence.md) for the
mapping annotations, the repository contract, the query builder, paging and the
entity lifecycle, and
`example/object_persistence/object_persistence_example.dart` for a seventeen-step
walkthrough that checks its own results, with its entities beside it in
`example/object_persistence/object_persistence_entities.dart`.
`example/object_persistence/optimistic_locking_example.dart` walks optimistic
locking the same way, and `test/optimistic_locking_test.dart` and
`test/optimistic_locking_db_test.dart` cover it without and with a server.
`example/object_persistence/field_encryption_example.dart` walks field-level
encryption, and `test/field_encryption_test.dart` and
`test/field_encryption_db_test.dart` cover it without and with a server.
`example/object_persistence/entity_lifecycle_example.dart` walks soft delete,
history, hooks and change events, and `test/entity_lifecycle_test.dart` and
`test/entity_lifecycle_db_test.dart` cover them without and with a server.
`example/object_persistence/subquery_example.dart` builds a correlated
`EXISTS`, a `NOT EXISTS` and an `IN (SELECT …)`, and
`test/query_associations_test.dart` and `test/query_associations_db_test.dart`
cover association filters and subqueries without and with a server.
`example/file_storage/deduplicating_store_example.dart` runs an orphan sweep,
and `test/deduplicating_blob_store_test.dart` and
`test/deduplicating_blob_store_db_test.dart` cover it without and with a server.
`test/object_persistence_test.dart` covers the module and
`test/object_persistence_db_test.dart` adds what only a live MariaDB or PostgreSQL can answer;
`test/examples_test.dart` runs the example and
`test/readme_quick_start_test.dart` runs the snippet above, so neither can drift
away from the code.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
