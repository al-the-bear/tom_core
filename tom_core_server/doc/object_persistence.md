# Object Persistence Module

A lightweight, annotation-driven ORM: map a reflected entity class to a database
table, then read and write it through a Spring-Data-style repository. Queries can
be expressed three ways — a parsed *query sentence*, a programmatically built
`TomQuery`, or raw SQL — and all of them render through a pluggable SQL dialect.

## Table of Contents

- [Overview](#overview)
- [Mapping an Entity](#mapping-an-entity)
  - [A key of several columns](#a-key-of-several-columns)
  - [Associations (`@TomReference`)](#associations-tomreference)
- [The Repository Contract](#the-repository-contract)
  - [What a delete returns](#what-a-delete-returns)
  - [How a repository fails](#how-a-repository-fails)
  - [Inserting under a key the caller chooses](#inserting-under-a-key-the-caller-chooses)
  - [Upserting by a unique key](#upserting-by-a-unique-key)
  - [Paging and Sorting](#paging-and-sorting)
  - [Lifecycle work](#lifecycle-work)
  - [Reads a replica may serve](#reads-a-replica-may-serve)
- [Optimistic Locking](#optimistic-locking)
  - [Declaring a version](#declaring-a-version)
  - [What a save and a delete check](#what-a-save-and-a-delete-check)
  - [Handling a conflict](#handling-a-conflict)
  - [Adding a version to an existing table](#adding-a-version-to-an-existing-table)
  - [What is not checked](#what-is-not-checked)
- [Entity Lifecycle](#entity-lifecycle)
  - [Soft delete](#soft-delete)
  - [History tables](#history-tables)
  - [Lifecycle hooks](#lifecycle-hooks)
  - [Change events](#change-events)
    - [Feeding an outbox](#feeding-an-outbox)
  - [One transaction](#one-transaction)
  - [What the lifecycle does not reach](#what-the-lifecycle-does-not-reach)
- [Query Sentences](#query-sentences)
  - [Which kind takes which option](#which-kind-takes-which-option)
  - [`IS IN` lists](#is-in-lists)
  - [Column types a predicate can address](#column-types-a-predicate-can-address)
  - [What a comparison compares](#what-a-comparison-compares)
  - [Writing a value inline](#writing-a-value-inline)
    - [Inside a text literal](#inside-a-text-literal)
  - [Matching literal text](#matching-literal-text)
  - [Filtering on an association](#filtering-on-an-association)
  - [Words this grammar does not have](#words-this-grammar-does-not-have)
- [The Query Builder DSL](#the-query-builder-dsl)
  - [Subqueries](#subqueries)
- [Row Scopes](#row-scopes)
  - [Declaring a scope](#declaring-a-scope)
  - [Automatic scoping, and opting out](#automatic-scoping-and-opting-out)
  - [How a scope renders](#how-a-scope-renders)
  - [Async resolvers must not recurse](#async-resolvers-must-not-recurse)
  - [Reads filter, writes reject](#reads-filter-writes-reject)
  - [Reading and writing can differ](#reading-and-writing-can-differ)
  - [The grant-driven `resource` kind](#the-grant-driven-resource-kind)
- [Tenant-Owned Rows](#tenant-owned-rows)
  - [What the repository does with it](#what-the-repository-does-with-it)
  - [One repository, every tenant](#one-repository-every-tenant)
- [Column Authorization](#column-authorization)
  - [Grading a column](#grading-a-column)
  - [Reads mask](#reads-mask)
  - [Writes reject, or silently preserve](#writes-reject-or-silently-preserve)
  - [Grades that depend on the row](#grades-that-depend-on-the-row)
- [File-Reference Columns](#file-reference-columns)
  - [Declaring one](#declaring-one)
  - [The key](#the-key)
  - [Moving the bytes](#moving-the-bytes)
  - [Authorization, by construction](#authorization-by-construction)
  - [Blobs that nothing references](#blobs-that-nothing-references)
  - [Sweeping files no row refers to](#sweeping-files-no-row-refers-to)
- [Field-Level Encryption](#field-level-encryption)
  - [Marking a field](#marking-a-field)
  - [What is stored](#what-is-stored)
  - [Writes and reads](#writes-and-reads)
  - [Finding a row by value](#finding-a-row-by-value)
  - [What cannot be queried](#what-cannot-be-queried)
  - [Keys: envelope encryption](#keys-envelope-encryption)
  - [Installing a keyring](#installing-a-keyring)
  - [Keys held by a key-management service](#keys-held-by-a-key-management-service)
  - [Rotating keys](#rotating-keys)
  - [The re-encryption pass](#the-re-encryption-pass)
  - [Encrypting a column that held plaintext](#encrypting-a-column-that-held-plaintext)
  - [Tenancy](#tenancy)
  - [Audit records](#audit-records)
  - [How field encryption fails](#how-field-encryption-fails)
- [Grouping and Aggregation](#grouping-and-aggregation)
  - [The aggregates](#the-aggregates)
  - [Building one](#building-one)
  - [Reading the result](#reading-the-result)
  - [`WHERE` filters rows, `HAVING` filters groups](#where-filters-rows-having-filters-groups)
  - [Authorization](#authorization)
  - [Value types across drivers](#value-types-across-drivers)
- [How Metadata Is Resolved](#how-metadata-is-resolved)
- [SQL Dialects](#sql-dialects)
- [Verification](#verification)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` | classes | The annotations that map an entity class and its fields to a table and columns |
| `TomVersion` | class | Marks the `int` field holding the row's version, turning on optimistic locking for the entity |
| `TomSoftDelete` | class | Marks an entity whose repository deletes set a deletion time, and whose deleted rows every repository read leaves out; `includingDeleted` shows them |
| `TomHistory` | class | Marks an entity whose rows are copied into a history table before every update, delete and restore |
| `TomHistoryEntry<T>` | class | One past version of a row, as `historyOf` answers it: the entity as it was, the action that replaced it, when and by whom |
| `TomHistoryMeta` | class | The history table's own four columns, read beside the entity's by reflection |
| `TomEntityListener<T>` | abstract class | The hooks of one entity type's repository writes: `beforeSave` / `afterSave`, `beforeDelete` / `afterDelete` |
| `TomEntityChange` / `TomEntityChangeKind` | class / enum | One change of one row — inserted, updated, deleted or restored — with the row before and after, its redacted values and `toJson()` |
| `TomEntityChangeListener` | typedef | What `onChange` registers: told of every change of its entity inside the change's transaction |
| `TomEntityLifecycle` | abstract final class | The registry of entity listeners and change listeners, and whether a write of an entity is observed. Statics only |
| `TomDartType` | class | Wraps a `Type` so it can be carried as a value, where a bare `Type` literal is awkward to pass |
| `TomRepository<T, K>` | abstract class | The CRUD + query contract for entity `T` keyed by `K` |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL implementation of the contract |
| `MariadbRepository<T, K>` | class | MariaDB binding — constructed directly, and the only thing it adds is a pinned `MariadbSqlDialect` |
| `TomCompositeKey` | final class | The `K` of an entity whose primary key spans several fields, keyed by field name |
| `TomPageRequest` | class | One page of a query. The repository appends the primary-key fields as final sort terms, because "page 2" of an unordered query is otherwise not the complement of "page 1" |
| `TomSortField` / `TomSortDirection` | class / enum | One sort term — a declared field name where the caller writes it, a rendered column expression by the time SQL is generated |
| `TomCountResult` | class | The row a `COUNT` projects into; the column alias *is* the binding, and nothing checks it |
| `TomQuerySentenceCompiler` | class | Parses a query sentence into a `TomQuery` |
| `TomQueryBuilder` | mixin | Fluent factory for the `TomOperator` expression tree |
| `TomSubquery` | class | `SELECT <projection or 1> FROM <the tables of its entity types> WHERE …` — the subquery an `EXISTS` or `IN (SELECT …)` node tests |
| `TomAggregate` | abstract class | An aggregate function node (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`) |
| `TomGroupedSelect` | class | A `SELECT … GROUP BY … HAVING` compiled from group keys and aggregates |
| `TomGroupedRow` | class | One group's result: the group keys plus the aggregate values, keyed by alias |
| `TomAnnotationAnalyzer` | mixin | Resolves an entity's persistence metadata by reflection |
| `TomColumnInformation` | class | The resolved metadata for one entity field |
| `TomDbScope` | class | Declares (or explicitly opts out of) an entity's row scope |
| `TomTenantOwned` | class | Marks an entity whose every row belongs to a tenant; the repository reads and writes only the current tenant's rows |
| `TomDataScopeRegistry` | class | The named scope-kind resolvers, read and write. Statics only |
| `TomDataScope` | class | Renders a resolver's answer into a bound `IN` / union predicate. Statics only |
| `TomDataScopeResolver` / `TomAsyncDataScopeResolver` | typedef | What a scope kind supplies: `null` opts out of scoping, an empty list denies every row — the secure default a `null` principal resolves to |
| `TomDataScopePredicate` | class | A resolved scope: the boolean to AND into the `WHERE`, plus the parameters it binds |
| `TomDataScopeBypass` | class | The marker `TomDataScope.runUnscoped` installs, so a resolver's own nested reads do not re-enter scope resolution and recurse |
| `TomResourceScopeSource` | abstract class | The seam `authorization` implements and installs, so this module needs no dependency on it |
| `TomColumnAuthorization` | class | Applies a column's `authKey` grade — read masking and the write partition. Statics only |
| `TomRowColumnAuthorization` | class | Per-row column grades, for grades derived from the row's owning aggregate. Statics only |
| `TomColumnAuthResolver` / `TomRowColumnAuthResolver` | typedef | The grade a principal holds on one authorized column, flat and per-row |
| `TomColumnWriteDecision<C>` | class | The write partition: which columns the caller may write, and which are preserved from the baseline |
| `TomFileReference` | class | Declares that a column holds a blob-storage key |
| `TomFileReferenceKeys` | class | Resolves a file column's store and mints its keys. Statics only |
| `TomBlobMigration` | class | Moves the blobs a repository's rows name from one blob store to another |
| `TomBlobMigrationReport` | class | What one migration did: rows read, blobs copied, keys claimed, references it could not satisfy |
| `TomBlobMigrationException` | class | Raised when a migration cannot proceed, or cannot be trusted |
| `TomFileRepository<T, K>` | abstract class | The five-method file surface the HTTP file endpoint depends on |
| `TomBlobOrphanSweep` | class | Deletes the keys of a deduplicating blob store that no row refers to, once older than a grace, then reclaims their content; also as a scheduler job |
| `TomBlobOrphanSweepReport` | class | What one sweep did: keys considered, keys deleted, contents reclaimed |
| `TomBlobReferenceSource` | abstract class | Something that knows which blob keys its rows refer to |
| `TomRepositoryBlobReferences<T, K>` | class | A repository's `@TomFileReference` columns as a reference source, soft-deleted rows included |
| `TomEncrypted` | class | Marks a `String` field encrypted at rest: stored as ciphertext, read as plaintext |
| `TomBlindIndex` / `TomBlindIndexNormalization` | class / enum | Makes a `String` column the blind index of an encrypted field — what a lookup by value compares — and how it normalises the value first |
| `TomFieldEncryption` | abstract final class | The isolate's field encryption: the installed keyring, the cipher, blind indexes and lookups, raw reads, audit redaction. Statics only |
| `TomFieldKeyring` | class | The data keys, unwrapped and cached; creates them, and rotates data keys, index keys and key-encryption keys |
| `TomKeyEncryptionKey` | abstract class | What wraps the data keys; never touches the database |
| `TomAesKeyEncryptionKey` | class | A key-encryption key held by the application: a 256-bit AES key, wrapping with AES-GCM |
| `TomKeyEncryptionKeyFactory` | typedef | Builds the key-encryption key a `fieldEncryption.keys` entry of a registered kind describes |
| `TomAesGcm` | abstract final class | AES-256-GCM with a random nonce: the one cipher of field encryption, data-key wrapping and the privacy module's sealing of audit values. Statics only |
| `TomDataKeyStore` | abstract class | Where the wrapped data keys are kept |
| `TomSqlDataKeyStore` / `TomMemoryDataKeyStore` | class | The data keys in `tom_encryption_key` of a data source resolved by name per call / in memory |
| `TomDataKeyRecord` | class | One data key as stored: wrapped, with its purpose, state and key-encryption key |
| `TomDataKeyRow` | class | One row of the data-key table as `TomSqlDataKeyStore` reads it |
| `TomDataKeyPurpose` / `TomDataKeyState` | enum | What a data key is for (`encryption`, `blindIndex`), and whether new values use it (`active`, `previous`) |
| `TomFieldReencryption` | class | The pass that rewrites values under a previous key, plaintext and stale blind indexes, and its scheduler job |
| `TomReencryptionReport` | class | What one pass did: rows examined, rewritten, in conflict, failed |
| `TomFieldEncryptionException` | class | Field encryption that cannot proceed, keyed `field_encryption.*` |
| `encryptionKeyTable` / `encryptionKeyTableDdl` | function | The data-key table's one declaration, and the DDL derived from it |
| `defaultEncryptionKeyTable` / `tomReencryptionJobName` | const String | `tom_encryption_key`, the data-key table's default name / `object_persistence.reencrypt`, the re-encryption job's default name |
| `TomRepositoryException` / `TomQuerySyntaxException` | class | A failed operation / a query sentence that will not parse |
| `TomOptimisticLockException` | class | A save or delete of a versioned entity refused because the row's version moved since it was loaded; carries the version held and the one stored |
| `TomEntityLifecycleException` | class | A lifecycle declaration the repository cannot carry out, or a soft-delete or history method called on an entity without the declaration |
| `TomAnnotationAnalyzerException` / `TomAnnotationAnalyzerSyntaxException` | class | An entity the analyzer cannot resolve / annotation arguments it cannot read |
| `TomDataScopeException` / `TomDataScopeAuthorizationException` / `TomColumnAuthorizationException` | class | A mis-wired scope or column grade / a read or write the scope refused / a write to a column the caller may not write |

The expression tree the builder and the sentence compiler both produce is public,
because a query built one way is inspected, extended and rendered exactly like a
query built the other:

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomUnaryOperator<T, R>` / `TomBinaryOperator<T1, T2, R>` | abstract class | The two node shapes every operator below extends |
| `And` / `Or` / `Not` / `Group` | class | Boolean composition, and explicit parenthesisation |
| `Eq` / `Neq` / `Gt` / `Gte` / `Lt` / `Lte` | class | The six comparisons |
| `Like` / `NotLike` / `Regexp` | class | Pattern matching |
| `Between` / `In` / `IsNull` / `IsNotNull` | class | Range, membership and nullity |
| `TomExists` / `TomInSubquery<T>` | class | `EXISTS (<subquery>)` and `<operand> IN (<subquery>)` over a `TomSubquery` |
| `DbCol<R>` | abstract class | A column reference, typed by what the column holds |
| `BoolCol` / `IntCol` / `DoubleCol` / `StringCol` / `DateCol` / `DateTimeCol` / `TimeCol` | class | The seven concrete column references |
| `BoolLiteral` / `IntegerLiteral` / `DoubleLiteral` / `StringLiteral` / `DateLiteral` / `DateTimeLiteral` / `TimeLiteral` | class | The seven inline literals |
| `TruthPredicate` | class | A constant predicate — one that admits every row or none — rendered through the dialect's `truthPredicate` rather than as a literal value |
| `Parameter<T>` | class | A bound placeholder — what a value becomes when it is not written inline |
| `CountAll` / `Count` / `Sum` / `Avg` / `Min` / `Max` | class | The six aggregates `TomGroupedSelect` projects |

## Mapping an Entity

Annotate a `@tomReflector` class with `@TomDbTable` and its fields with
`@TomDbColumn` (and `@TomEntityId` on the primary key):

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'users', primaryKeyFields: ['id'])
class User {
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  int? id;

  @TomDbColumn(columnName: 'name')
  String name = '';

  @TomDbColumn(columnName: 'age')
  int age = 0;
}
```

**Declare a surrogate key `int? id;`** — or `int id = -1;` when it must be
non-nullable. `save` chooses `INSERT` over `UPDATE` by asking
`isUnsavedKey`, which accepts a `null` key or a *negative* one and nothing else.
`0` is deliberately not a sentinel: it is a legitimate key in a table that
assigns its own ids, and treating it as "unsaved" would make the row with id `0`
unsavable. The consequence is worth stating plainly, because it fails silently —
an entity declared `int id = 0` takes the *update* arm on its very first save,
issuing an `UPDATE` that matches no row and persisting nothing.

The key the database assigns is read back from the insert's own result. The
insert asks for it through the dialect's `returningKey`, which leaves the
statement unchanged on MariaDB — whose last-insert id reports the key on its
own — and appends `RETURNING <key column>` on PostgreSQL, which has none. A
composite key is supplied by the caller and asked for nothing.

`@TomDbColumn` can mark a column `isReadOnly` (skipped on insert/update),
`noLoad` (skipped on select), or `isJson`, and can carry `fromDbConverter` /
`toDbConverter` functions to translate between the Dart value and the boxed
`TomDbType` stored in the column.

### A key of several columns

`primaryKeyFields` is a list because a table may be keyed by the combination of
several columns, with no surrogate. List every key field, in key order, and mark
each `@TomEntityId`:

```dart
@tomReflector
@TomDbTable(
  datasource: 'app',
  table: 'user_role',
  primaryKeyFields: ['userId', 'roleId'],
)
class UserRole {
  @TomEntityId()
  @TomDbColumn(columnName: 'user_id')
  int? userId;

  @TomEntityId()
  @TomDbColumn(columnName: 'role_id')
  int? roleId;
}

class UserRoleRepository
    extends MariadbRepository<UserRole, TomCompositeKey> {}
```

The repository's key type is `TomCompositeKey`, a value keyed by field name, and
every by-key method takes one —
`findById(TomCompositeKey({'userId': 7, 'roleId': 3}))`. Each method binds
every key column: `findById`, `deleteById` and `delete` match on all of them
ANDed; `existsById`, `findAllById` and `deleteAllById` OR one such term per key;
an update's `WHERE` names them all; and a window is ordered by every key column.

A key must carry **exactly** the entity's key fields. One with a field missing
would match every row agreeing on the rest, and one with an extra field names
something the table is not keyed by, so both are refused with
`crud_repository.key.shape_mismatch` rather than matched on the fields they
happen to have.

**`save` asks the table.** A single surrogate key says by itself whether the
entity is stored — the database has assigned it or it has not. A composite key
is supplied whole by the caller and says nothing of the kind, so `save` counts
the rows with that key and inserts when there are none, updating otherwise. The
count is not narrowed by the row scope: a stored row the principal may not write
takes the update path and is refused there, as `data_scope.write.out_of_scope`,
rather than colliding as a duplicate insert. A key with a field still `null`
addresses no row, and `save` refuses it with
`crud_repository.save.incomplete_key` before any statement runs.

### Associations (`@TomReference`)

A field annotated `@TomReference` is not a column. It names a *many-to-many*
association reached through a **join entity**, and it is filled by a second
query issued after the owning row has been mapped — the query binds values from
that row, so it cannot run while the row is still being read.

```dart
@TomReference(
  targetEntity: Role,
  keyType: int,
  repositoryType: RoleRepository,
  joinEntity: UserRole,
  leftSideColumns: ['UserRole.userId=User.id'],
  rightSideColumns: ['UserRole.roleId=Role.id'],
  contextColumns: ['UserRole.organizationId=:organization'],
)
List<Role> roles = [];
```

The three column lists are three different *kinds* of term, which is why they
are three lists rather than one:

| List | Written as | Becomes |
| ---- | ---------- | ------- |
| `leftSideColumns` | `Join.field=Owner.field` | `Join.field = :field`, bound from the mapped row |
| `rightSideColumns` | `Join.field=Target.field` | the term verbatim — both sides are columns |
| `contextColumns` | `Join.field=:name` | the term verbatim, with `:name` bound from the execution context |

`TomAnnotationAnalyzer.referenceQuery` assembles them into one `FIND BY`
sentence and the parameter map it binds. Two consequences are worth naming:

- **The owner's value never reaches the statement text.** A left-side term is
  the one place a *row value* enters the reference query, and it enters as a
  parameter. The parameter is named after the **owner** field, not the join
  field, so the two may be spelled differently without the binding drifting.
- **The context read is per context column.** A reference that declares none
  builds outside any `TomExecutionContext`; one that declares a context column
  requires a context that carries that entry, and says which entry is missing
  when it does not.

A malformed expression is an authoring error and raises
`TomAnnotationAnalyzerSyntaxException` — always ahead of any context lookup, so
a typo is reported as a typo rather than as a missing context value. A
well-formed expression that the running zone cannot supply raises
`TomAnnotationAnalyzerException`. A reference declaring no columns at all is
rejected outright, with `annotation_analyzer.reference_query.no_terms`: it
constrains nothing, so it would load every join row for every owner row.

| Refused | Key |
| ------- | --- |
| a left-side term with the owner's field on the left of `=` | `annotation_analyzer.reference_query.left_side_owner_on_left` |
| a left-side term whose right side names no field of the owner | `annotation_analyzer.reference_query.left_side_owner_missing` |
| a context term with the `:name` on the left of `=` | `annotation_analyzer.reference_query.context_value_on_left` |
| a context term whose right side is not a `:name` | `annotation_analyzer.reference_query.context_value_missing` |
| a context term read with no `TomExecutionContext` in the zone | `annotation_analyzer.reference_query.no_execution_context` |
| a context term whose entry the running context does not carry | `annotation_analyzer.reference_query.context_entry_not_found` |

The field must be **non-null and modifiable** — `List<Role> roles = []`, not
`List<Role>? roles`. The mapper fills the list the entity already holds instead
of assigning a fresh one, because reflection cannot construct a `List<Role>`
from a mirror that carries no type arguments. A `null` field is refused with
`error.result_processing.ref_reference_field_must_have_non-null_value`, naming
the field: leaving the association empty instead would be indistinguishable
from an owner that genuinely has none.

**The join table is an entity, always.** There is no form of `@TomReference`
over a bare join table: `joinEntity` is required. A join table nobody has mapped
yet is given one `@TomDbTable` class whose fields are its columns:

```dart
@tomReflector
@TomDbTable(datasource: 'app', table: 'user_role', primaryKeyFields: ['id'])
class UserRole {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomDbColumn(columnName: 'user_id')
  int? userId;

  @TomDbColumn(columnName: 'role_id')
  int? roleId;
}
```

That class is the whole cost, and it buys the join row what every other row
has: it is read, written and deleted through a repository like any entity,
filtered by a `@TomDbScope`, and graded column by column. A bare table would be
a row to which none of those guarantees applied, and the repository would need
a write path for a row with no entity — so the convenience is declined rather
than missing.

A join table keyed only by its two foreign keys maps unchanged too: list both
fields in `primaryKeyFields`, as
[A key of several columns](#a-key-of-several-columns) shows, and drop the
surrogate.

**One reference query per owning row.** The association cannot be resolved while
its row is being mapped, so the mapper stacks the row's pending references and
drains the stack at the end of *that row*. A stack shared across rows would
re-resolve every earlier row's associations for each row that follows, turning
an *n*-row read into *n(n+1)/2* reference queries. The answer would be the same
— each fill clears the list before adding, so resolving an owner twice
recomputes the same list — which is why the cost is the only observable, and why
`test/reference_association_db_test.dart` asserts it by counting statements
rather than by inspecting rows.

A query sentence can filter the owning rows on what an association reaches —
`find by roles.name = :n`, `find by roles is empty` — without loading it; see
[Filtering on an association](#filtering-on-an-association).

## The Repository Contract

`TomRepository<T, K>` mirrors Spring Data's `CrudRepository`:

```dart
final repo = MariadbRepository<User, int>([User]);

await repo.save(user);                 // INSERT (null key) or UPDATE (key set)
final u   = await repo.findById(42);   // by primary key
final all = await repo.findAll();
final n   = await repo.count();
final gone = await repo.deleteById(42);   // rows deleted: 1, or 0 if absent
```

Beyond id-based CRUD it exposes three query styles, each in find / delete / count
flavours: a parsed query sentence (`findByQuerySentence`), a built `TomQuery`
(`findByQuery`), and raw SQL (`executeQueryString`). A fourth entry point,
`findGroupedByQuery`, runs a grouped query — its result is not `T`, so it does
not fit the find/delete/count pattern (see
[Grouping and Aggregation](#grouping-and-aggregation)).

### What a delete returns

Every delete that addresses an *unknown* number of rows returns how many it
deleted, as the database reported it:

| Method | Returns |
| ------ | ------- |
| `deleteById(id)` | `1`, or `0` when no row matched |
| `deleteAllById(ids)` | The rows deleted — can be lower than `ids.length` |
| `deleteByQuerySentence(sentence, params)` | The rows deleted |
| `deleteByQuery(query, params)` | The rows deleted |
| `delete(entity)` | Nothing |

`delete(entity)` is the deliberate exception: it addresses one row the caller
already holds, so the count could only ever be `1` or `0`, and `0` — the row
having gone since it was read — is not a distinction any caller has asked to
act on.

The count is always the count *after* the principal's data scope has been ANDed
into the predicate (see [Row Scopes](#row-scopes)), so a delete never reports
rows the principal may not see, and `deleteAllById` can legitimately answer
lower than the number of ids it was given.

The number comes from the execution's own result
(`TomStatementOutcome.affectedRows`, which `TomPreparedStatement.run` returns).
It is not derived from a follow-up `SELECT`, so it is exactly what
the server did — including `0` for a predicate that matched nothing.

### How a repository fails

Every repository rejection is a keyed `TomServerException`, never a bare
`Exception`, so a handler can match on the key and a catalogue can localise it.

`TomRepositoryException` covers the repository's own preconditions, under
`crud_repository.<method>.<condition>` keys:

| Key | Raised when |
| --- | ----------- |
| `crud_repository.constructor.datasource_not_registered` | The entity's `@TomDbTable` names a datasource no `TomDataSourceInfo` was registered for. |
| `crud_repository.constructor.no_primary_key` | The entity's `@TomDbTable` lists no `primaryKeyFields`. |
| `crud_repository.find_by_id.duplicate_primary_key` | A primary-key lookup matched more than one row. |
| `crud_repository.count.illegal_count_result` | `count()`'s `COUNT(*)` returned other than exactly one row. |
| `crud_repository.count_by_query.illegal_count_result` | Ditto for `countByQuery`. |
| `crud_repository.count_by_query_sentence.illegal_count_result` | Ditto for `countByQuerySentence`. |
| `crud_repository.save.no_generated_key` | An `INSERT` (or an `upsert`) whose primary key was left for the database to assign reported no generated key — the table assigns none, or the driver does not report one from the insert's result. |
| `crud_repository.save.insert_not_readable` | An `INSERT` reported success but the new row could not be read back. |
| `crud_repository.save.update_not_readable` | An `UPDATE` ran but the row could not be re-read. |
| `crud_repository.upsert.unsupported` | `upsert` was called for an entity whose write needs the stored row — `upsertBlocker` names why (parameters `type`, `reason`). See [Upserting by a unique key](#upserting-by-a-unique-key). |
| `crud_repository.upsert.unscoped_conflict_key` | `upsert`'s `conflictFields` leave out the entity's `@TomDbScope` or tenant field (parameters `type`, `field`). |
| `crud_repository.delete.unsaved_entity` | `delete(entity)` was handed an entity that was never persisted. |
| `crud_repository.save.incomplete_key` | `save` was handed a composite-key entity with a key field still `null`. |
| `crud_repository.key.shape_mismatch` | A composite-key method was handed a key that is not a `TomCompositeKey` of exactly the entity's key fields. |
| `crud_repository.save.version_missing` | `save` was handed a stored `@TomVersion` entity whose version field is `null`. |
| `crud_repository.delete.version_missing` | `delete(entity)` was handed a `@TomVersion` entity whose version field is `null`. |
| `crud_repository.save.version_conflict` | A versioned update changed no row: the stored version is no longer the one the entity carries, or the row is gone. Raised as `TomOptimisticLockException`. |
| `crud_repository.delete.version_conflict` | A versioned `delete(entity)` changed no row, for the same reasons. Raised as `TomOptimisticLockException`. |

The first eleven are *server* faults — a broken deployment, a table contradicting
its own key, a driver that reported a write it then could not read, code that
asks `upsert` for a write it cannot do — so
`clientThrow` defaults to `false`: the key travels to the caller, the message
(which names internals) does not.

The last seven are the exceptions, and set `clientThrow: true`: each is a
statement about the caller's own argument, and the message says exactly that —
where masking it would leave the caller with a generic error for a failure it is
the only party able to fix. An entity whose primary key is still `null` (a
nullable surrogate key before its first save), negative (the `id >= 0` sentinel
convention) or a composite key with a field still `null` addresses no row, so
`delete` has nothing to delete and `save` has nothing to address; and a
composite key of the wrong fields addresses some other set of rows than the one
the method promises. A versioned entity that arrives without its version is the
caller's argument too, and a version conflict refuses the caller's own write —
see [Optimistic Locking](#optimistic-locking).

Before this check existed the two unsaved conventions failed differently and
neither failed usefully: a `null` key threw a raw `TypeError` naming `Null` and
`int`, and a negative key passed the cast, ran a `DELETE` that matched no row,
and reported success for a deletion that never happened.

The `*ByQuerySentence` methods add three keys of their own,
`crud_repository.<method>.sentence_verb_mismatch`, raised as
`TomQuerySyntaxException` because a sentence whose verb does not match the method
is the caller's mistake and the caller's to correct.

`TomEntityLifecycleException` covers [Entity Lifecycle](#entity-lifecycle),
under `crud_repository.soft_delete.*` and `crud_repository.history.*` keys:

| Key | Raised when |
| --- | ----------- |
| `crud_repository.soft_delete.invalid_field` | The entity's `@TomSoftDelete` names a field that is not a writable `DateTime` column. Raised the first time the repository needs the column, before any statement runs. |
| `crud_repository.soft_delete.not_soft_delete` | `restoreById` or `purgeById` was called on an entity whose deletes are hard. |
| `crud_repository.history.not_declared` | `historyOf` was called on an entity without `@TomHistory`. |

`TomBlobMigrationException` covers the row-driven blob migration
([Migrating Between Backends](file_storage.md#migrating-between-backends)),
under `storage.migration.*` keys:

| Key | Raised when |
| --- | ----------- |
| `storage.migration.scoped_run` | A request principal is in the zone. The sweep would migrate that principal's *view* of the table — row scope applied, protected columns masked to `null` — and report success. Raised before a single row is read. |
| `storage.migration.no_file_columns` | The entity declares no `@TomFileReference` column. Named rather than swept, because a migration reporting "0 blobs" for an entity that stores none looks exactly like one that worked. |
| `storage.migration.unknown_field` | `fields` names a column that is not a file column of the entity. |
| `storage.migration.verification_failed` | A copy did not match what was read. The one failure a later pass cannot detect — the next run finds the key present and moves on — so it stops the migration rather than being reported. |

### Inserting under a key the caller chooses

`save` decides between `INSERT` and `UPDATE` by the key. A single key the
database has not assigned yet inserts, and any other key updates. A key the
caller chooses for a new row — a client-generated id, as an offline device
creates entities with — is therefore never inserted by `save`: the update finds
no row. `insert` writes such an entity as a new row:

```dart
final note = Note()
  ..id = 'f3a1c2d4'
  ..text = 'Written on the device';
await notes.insert(note);
```

| Member | Returns | Description |
| ------ | ------- | ----------- |
| `insert(entity)` | `Future<T>` | Inserts `entity` as a new row, whatever its key holds, and returns the stored entity |

`insert` runs the same write path as `save`: the lifecycle hooks with
`insert: true`, the tenant and the
[insert-side scope check](#reads-filter-writes-reject), the column grades, the
version, encryption, audit, history and change listeners. The key is written
as given. A row already holding it is refused by the table's primary key. A
single key left unsaved is assigned by the database, as `save` would assign
it.

### Upserting by a unique key

`save` decides between `INSERT` and `UPDATE` by the entity's primary key, so a
caller that knows a row only by a *business* key — `(principal, key)`,
`(tenant, code)` — reads it first and saves it with the key it found. Two writers
doing that for one new business key can both read nothing and both insert, and
the table's unique key refuses the second with a driver error. `upsert` and
`saveByKey` write by the business key instead:

```dart
await repo.upsert(preference, conflictFields: ['principalId', 'preferenceKey']);
await repo.saveByKey(preference, conflictFields: ['principalId', 'preferenceKey']);
```

| Member | Returns | Description |
| ------ | ------- | ----------- |
| `upsertBlocker` | `String?` | Why `upsert` cannot write this entity type, or `null` when it can |
| `upsert(entity, {conflictFields})` | `Future<T>` | One statement: inserts the row, or — when a row holds the same values in `conflictFields`, which must be a unique key of the table — writes over it. Returns `entity` carrying the key of the row written |
| `saveByKey(entity, {conflictFields})` | `Future<T>` | `upsert` when `upsertBlocker` is `null`; otherwise finds the row by `conflictFields` and `save`s with its key |

**`upsert` is one statement with no read before it**, rendered by the dialect's
`upsert` fragment ([datasources.md](datasources.md#upserting-in-one-statement)):
MariaDB `INSERT … ON DUPLICATE KEY UPDATE`, PostgreSQL `INSERT … ON CONFLICT
(…) DO UPDATE`. Every writable column outside the conflict key is overwritten;
the row's key comes back through `LAST_INSERT_ID(<key>)` or `RETURNING`, so the
entity carries it whether the row was inserted or updated. Two writers racing
for one key cannot both insert, and neither has to retry on the duplicate.

**It is offered only where nothing about the write needs the stored row.**
`upsertBlocker` answers, in this order, `column access rights` (a
[graded column](#column-authorization)), `file-reference columns`, `encrypted
columns` (an encrypted or blind-indexed column), `a version column`,
`soft delete`, `entity listeners, change listeners or history`, and `an audit
policy` auditing a create or an update — each of those compares against,
records or replaces the row as it was. `upsert` refuses such an entity with
`crud_repository.upsert.unsupported`.

**The conflict key must hold the owner.** When the entity declares a
`@TomDbScope` or a tenant field, `conflictFields` must name it, or the call is
refused with `crud_repository.upsert.unscoped_conflict_key`: the update half
could otherwise overwrite a row of another owner or tenant that the scope would
never have let this caller touch. With it in the key, the row the update reaches
has the scope value the insert check admits. The tenant and the
[insert-side scope check](#reads-filter-writes-reject) run before the statement,
as they do for `save`.

**`saveByKey` is the call to reach for.** Where `upsert` is allowed it is
`upsert`; elsewhere it looks the row up by `conflictFields` and `save`s with the
key it found, so listeners, audit, history and every other write feature see the
stored row they need. On that path two writers racing for a new key can both
reach the insert, and the table's unique key refuses the second.

`MariaDB`'s `ON DUPLICATE KEY UPDATE` reacts to a collision on *any* unique key
of the table, where PostgreSQL's `ON CONFLICT` names the conflict key; a table
whose only unique keys are its primary key and `conflictFields` — the shape a
surrogate-keyed entity with one business key has — behaves the same on both.

### Paging and Sorting

Every read that can return more than one row takes an optional `TomPageRequest`:
an offset, a row limit, and an ordered list of `TomSortField` terms.

```dart
final page = TomPageRequest.page(2, 25, sort: const [
  TomSortField.desc('priority'),
  TomSortField.asc('dueDate'),
]);

final rows  = await repo.findAll(page);                       // the window
final total = await repo.count();                             // the total
final some  = await repo.findAllById(ids, page);
final found = await repo.findByQuerySentence(sentence, params, null, page);
final built = await repo.findByQuery(select, params, page);
```

The request is an optional argument on the existing finders rather than a
parallel `findAllPaged` family, so a caller that does not page writes exactly
what it wrote before.

**The result is the page, not a page object.** A finder returns the rows of the
window as a plain `List<T>`; the total comes from the matching `count` method,
which applies the same row scope. Two calls, both scoped, and a caller that does
not need the total does not pay for a second round trip to get it.

**A window is ordered.** Rows come back in whatever order the database found
convenient unless something says otherwise, so "page 2" of an unordered query is
not the complement of "page 1" — it may repeat rows or skip them. The repository
therefore appends every primary-key field the caller's sort does not already
name, ascending and in key order, as final sort terms whenever a window is
requested.

**Paging composes with the security layers.** The window is applied to the query
*before* the row scope narrows it, so the scope predicate still binds and
`@TomDbColumn(authKey:)` masking still runs over the returned rows. The total is
likewise the scoped total — a principal never learns the size of a row set it
may not read.

A `TomPageRequest` that SQL cannot express is rejected where it is built: a
negative offset (`paging.window.negative_offset`), a negative limit
(`paging.window.negative_limit`), or an offset with no limit
(`paging.window.offset_without_limit` — MariaDB's grammar is
`LIMIT n [OFFSET m]`, so there is no bare `OFFSET` and the skip would be
silently dropped).

### Lifecycle work

Work that has to happen around a write of an entity, wherever it is written
from, is a registered `TomEntityListener` (see
[Lifecycle hooks](#lifecycle-hooks)): it runs in the write's transaction and is
reached by every repository of the entity. Work that belongs to one repository
class — and work just after a row is *read*, which no listener sees — is an
**override of the repository method that performs it**:

```dart
class TaskRepository extends TomSqlDatasourceRepository<Task, int> {
  @override
  Future<Task> save(Task toSave) async {
    toSave.updatedAt = TomZonedDateTime.fromDateTime(DateTime.now()); // before
    final saved = await super.save(toSave);
    await _searchIndex.reindex(saved);           // after, with the stored row
    return saved;
  }

  @override
  Future<Task?> findById(int id) async {
    final loaded = await super.findById(id);
    if (loaded != null) loaded.displayTitle = _decorate(loaded);
    return loaded;
  }
}
```

This costs a deployment nothing to reach: a repository is *already* declared as a
subclass — every one in this framework and its samples is `class XRepository
extends TomSqlDatasourceRepository<E, K> {}` — so the hook is a method added to a
class that exists. It is `async`, so it can await the I/O such a step usually
needs; it closes over whatever the repository holds; and it is typed to the
entity rather than to `Object`.

Two properties are worth knowing before you write one.

**`save` calls `findById`, on `this`.** The row `save` returns is the *stored*
row, which it reads back through `findById` — so a `findById` override also runs
on the write path, once per save. That is right for a hook that decorates a
materialised row and wrong for one that counts reads; if you need to tell the
two apart, do the counting in a separate method the read callers use.

**Every read method is its own seam.** Six public methods materialise rows
independently — `findById`, `findAll`, `findAllById`, `findByQuerySentence`,
`findByQuery` and `executeQueryString` — and there is no shared post-load hook
to override instead, by design: the funnel they share applies column masking
and is private. A hook that must see *every* loaded row is therefore an override
of each of the six, and a read method added to a subclass later needs one too.
A `findById` override does not see rows read by `findAll`;
`test/object_persistence_test.dart` asserts exactly that.

The write side has one seam, because the other writers route through it:
`saveAll` calls `save` per entity, and `saveFile` and `clearFile` end in `save`.
`openFile` and `describeFile` read the row through `findById`, so they reach a
`findById` override as well.

### Reads a replica may serve

When the entity's data source is configured with read replicas, a repository
read may be answered by a replica rather than the primary (see
[Read Replicas](datasources.md#read-replicas)). Every read method of
`TomSqlDatasourceRepository` — `findById`, `findAll`, `findAllById`,
`existsById`, `count`, `findByQuerySentence`, `countByQuerySentence`,
`findByQuery`, `countByQuery`, `findGroupedByQuery` and `executeQueryString` —
runs inside `TomReplicaRouting.repositoryRead`, which marks it as a read a
replica may serve. The data source then sends it to a replica only in read-only
work — a read-only transaction, a `GET` or `HEAD` request, a
`TomReplicaRouting.readOnly` block — only when the statement is a plain read,
and not while the principal's own recent write is still within the data
source's `replicaStickinessMs`. The reads a write makes for itself — the
baseline a `save` loads, the check that the rows a delete names are writable —
run in the write's context and read the primary.

An entity whose reads must never lag marks itself `@TomPrimaryReads()`:

```dart
@tomReflector
@TomPrimaryReads()
@TomDbTable(
  datasource: 'main',
  table: 'account_limit',
  primaryKeyFields: ['id'],
)
class AccountLimit {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomDbColumn(columnName: 'limit_cents')
  int? limitCents;
}
```

Its repository's reads run unmarked and so always on the primary. The
framework marks the entities authorization and authentication decide on —
grants, delegations, second-factor enrolments, external identity links and
their tokens. Reading one entity from the primary in one place, without pinning
it everywhere, is `TomReplicaRouting.primary(() => repository.findById(id))`.

## Optimistic Locking

Two people who load the same row and both save it would otherwise overwrite each
other without either noticing — the second save simply wins. A field annotated
`@TomVersion` makes the repository refuse the second save instead, without
holding a database lock between the read and the write.

### Declaring a version

Mark one `int` field `@TomVersion`, beside its `@TomDbColumn`:

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'invoice', primaryKeyFields: ['id'])
class Invoice {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomVersion()
  @TomDbColumn(columnName: 'version')
  int? version;

  @TomDbColumn(columnName: 'amount')
  int? amount;
}
```

The repository maintains the field itself, so it must be one it can write.
`TomAnnotationAnalyzer` refuses anything else when it resolves the entity's
columns — before any statement runs:

| Refused | Key |
| ------- | --- |
| a field that is not an `int` | `annotation_analyzer.version.invalid_field` |
| the entity id, an association, or an `isReadOnly` column — a read-only column is left out of the `SET` clause, so its version would never move | `annotation_analyzer.version.invalid_field` |
| a second `@TomVersion` field — a row has one version | `annotation_analyzer.version.more_than_one` |

`TomAnnotationAnalyzer.findVersionColumn(type)` answers which column is the
version, or `null` for an entity that is not versioned. An entity without the
annotation is saved and deleted unchecked.

### What a save and a delete check

| Operation | What the repository does |
| --------- | ------------------------ |
| `save` of a new row | Writes version `1`, whatever the field held. |
| `save` of a stored row | Writes `version + 1` with `… WHERE id = :id AND version = :__tomversion_expected`, binding the version the entity carries. |
| `delete(entity)` | Deletes with the same `AND version = :__tomversion_expected` clause. |
| a `save` or `delete(entity)` whose version field is `null` | Refused with `crud_repository.save.version_missing` / `crud_repository.delete.version_missing` before any statement runs. |

The bind name is `TomSqlDatasourceRepository.versionParameter`, prefixed like the
scope and tenant parameters so it cannot collide with a column's declared name;
`TomSqlDatasourceRepository.buildUpdateStatement(..., version: column)` renders
the clause.

When another save has moved the version since the entity was loaded, the
statement matches no row. The repository reads that from the execution's own
affected-row count (`TomStatementOutcome.affectedRows`, see
[datasources](datasources.md#what-one-execution-reports)) and raises
`TomOptimisticLockException` — `crud_repository.save.version_conflict` or
`crud_repository.delete.version_conflict`. The refused write changes nothing
else: no blob is discarded, no file reference is cascaded and no audit record is
written. The same holds when the row has been deleted meanwhile, since that
statement matches no row either. On an entity with a row scope or a tenant,
the scope check that runs before every update and `delete(entity)` sees the
missing row first and refuses it as `data_scope.write.out_of_scope`.

A refused `null` version is deliberate. A client that round-tripped the entity
without the field would otherwise skip the check it exists for, so leaving the
version out cannot be a way to turn locking off.

The entity `save` returns is the stored row, so it carries the new version; a
caller that keeps editing saves the object it got back, not the one it passed
in. `saveAll` saves each entity through `save`, and `saveFile` and `clearFile`
end in `save`, so all of them are checked. On a refused `saveFile` the blob just
uploaded is discarded and the row keeps the file it referenced.

### Handling a conflict

`TomOptimisticLockException` extends `TomRepositoryException` and is always
client-visible (`clientThrow: true`): the refused write is the caller's own.
`heldVersion` is the version the caller presented and `storedVersion` the one the
row carries now — `null` when the row is gone or no longer visible to the
caller. Both travel in `parameters` beside `entity` and `id`.

The usual answer is to reload the row, show the user what changed, and let them
decide again. A caller that applies a change which does not depend on the old
values can reload and re-apply it itself:

```dart
Future<Invoice> raiseAmount(
  TomSqlDatasourceRepository<Invoice, int> invoices,
  int id,
  int by,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    final current = (await invoices.findById(id))!;
    try {
      return await invoices.save(current..amount = (current.amount ?? 0) + by);
    } on TomOptimisticLockException catch (conflict) {
      if (conflict.storedVersion == null) rethrow; // the row is gone
    }
  }
  throw StateError('invoice $id keeps changing under us');
}
```

Re-applying is right only where the edit is a function of the current row, as
an increment is. An edit the user made by looking at the old values — a new
title, a changed address — must not be re-applied blindly: that is the lost
update the version exists to prevent, moved one step later.

### Adding a version to an existing table

The column must be `NOT NULL`: a versioned update matches by `version = ?`, and
`NULL` equals nothing, so every save of a row whose version is `NULL` would be
refused as a conflict. A table that gains the column later adds it with a
default:

```sql
ALTER TABLE invoice ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
```

Existing rows then load at version `0`, and their first save moves them to `1`.
The schema-convergence check reports a version column the migration chain
leaves nullable as `nullableVersionColumn`, an error (see
[db_migration](db_migration.md#schema-convergence)).

### What is not checked

- **`deleteById(id)`** names a key and no version, so it deletes whatever the
  row holds. Use `delete(entity)` when the deletion should depend on what the
  caller saw.
- **`deleteAllById`, `deleteByQuery` and `deleteByQuerySentence`** address a set
  of rows, not entities the caller loaded, and run unchecked.
- **`executeQueryString`** and any statement a caller writes itself bypass the
  repository, so nothing moves the version for them; an `UPDATE` written by hand
  should set `version = version + 1` itself, or the next versioned save of that
  row will overwrite it unknowingly.

## Entity Lifecycle

Four things can happen around a repository write besides the write itself, each
declared or registered per entity and carried out by
`TomSqlDatasourceRepository` (`entity_lifecycle.dart`):

| Feature | Declared by | What it does |
| ------- | ----------- | ------------ |
| [Soft delete](#soft-delete) | `@TomSoftDelete` | A delete sets a timestamp instead of removing the row; every repository read leaves such rows out |
| [History tables](#history-tables) | `@TomHistory` | The row as it was is copied into a history table before every update, delete and restore |
| [Lifecycle hooks](#lifecycle-hooks) | `TomEntityLifecycle.register` | A `TomEntityListener` is called before and after every save and delete of its entity |
| [Change events](#change-events) | `TomEntityLifecycle.onChange` | A listener is told of every insert, update, delete and restore as a `TomEntityChange` |

No other code path writes any of them: a store that talks to its data source
directly, or a statement written by hand, has none (see
[What the lifecycle does not reach](#what-the-lifecycle-does-not-reach)).

### Soft delete

Mark the entity `@TomSoftDelete` and give it a nullable `DateTime` column for the
deletion time — `deletedAt` by default, any other field through
`@TomSoftDelete(field: '...')`:

```dart
@tomReflector
@TomSoftDelete()
@TomHistory(table: 'note_history')
@TomDbTable(datasource: 'main', table: 'note', primaryKeyFields: ['id'])
class Note {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomVersion()
  @TomDbColumn(columnName: 'version')
  int? version;

  @TomDbColumn(columnName: 'text')
  String? text;

  /// When the note was deleted; `null` while it lives.
  @TomDbColumn(columnName: 'deleted_at')
  DateTime? deletedAt;
}
```

Every delete path of the repository — `delete(entity)`, `deleteById`,
`deleteAllById`, `deleteByQuerySentence` and `deleteByQuery` — then issues an
`UPDATE` setting the column to the current UTC time
(`TomSqlDatasourceRepository.deletedAtParameter` is its bind name) instead of a
`DELETE`, and no referenced file is removed: the row still names it. The count a
delete returns is the rows it marked.

The filter `<deleted> IS NULL` is part of the repository's data scope, beside
the row scope and the tenant predicate, so it applies wherever they do: every
finder, the counts, `existsById`, the query methods, and the write guards. A
deleted row is therefore not found, not counted, not paged and not writable, and
deleting it again marks nothing and answers `0`.

| Method | What it does |
| ------ | ------------ |
| `TomSoftDelete.includingDeleted(body)` | Runs `body` with deleted rows visible to every repository read; `TomSoftDelete.isIncludingDeleted` says whether the current zone is inside one |
| `restoreById(id)` | Clears the deletion time; answers `1`, or `0` when the row is not deleted or not there |
| `purgeById(id)` | Deletes the row for good, deleted or not — a hard `DELETE` with the file cascade |
| `isSoftDelete` | Whether the repository's deletes are soft |

`restoreById` and `purgeById` are refused with
`crud_repository.soft_delete.not_soft_delete` on an entity whose deletes are
hard (`deleteById` is its purge). A `@TomSoftDelete` field that is not a
writable `DateTime` column — the wrong type, an association, an `isReadOnly`
column — is refused with `crud_repository.soft_delete.invalid_field` the first
time the repository needs it, before any statement runs.

A soft delete is a write like any other. On a `@TomVersion` entity,
`delete(entity)` is version-checked exactly as a hard delete is
(`crud_repository.delete.version_conflict`) and moves the version
(`TomSqlDatasourceRepository.nextVersionParameter` binds the next one), so an
editor still holding the row before the delete cannot save over it. `deleteById`,
like its hard form, names no version and checks none.

A delete cut to a window — a `TomDelete` with `top` and `sort`, as
`deleteByQuery` and `delete first 10 by … order by …` produce — is resolved to
the keys the window holds first; the hooks, the history and the soft `UPDATE` or
hard `DELETE` then reach exactly those rows.

Saving an entity writes its deletion time like any other column. An entity
loaded inside `includingDeleted` and saved there with the field cleared is
restored — recorded as an update, in the history and as a change event, where
`restoreById` records a restore.

### History tables

`@TomHistory(table: ...)` keeps a row's past. Before every update, every delete —
soft, hard, by id, by key list or by query — and every restore, the repository
reads the rows the statement is about to change and inserts each into the
history table, with four columns of its own:

| Column | Holds |
| ------ | ----- |
| `history_id` | The history row's own key, generated; versions read back in its order |
| `history_action` | What replaced the version: `update`, `delete` or `restore` |
| `history_at` | When (UTC) |
| `history_by` | The id of the `TomPrincipal` in the zone, or `NULL` |

Beside them the table carries every column of the entity's table under the same
name — the entity's key not unique, since a row has many versions — and no
other `NOT NULL` column without a default. For the `Note` entity above, on
MariaDB:

```sql
CREATE TABLE note_history (
  history_id     BIGINT       NOT NULL AUTO_INCREMENT,
  history_action VARCHAR(16)  NOT NULL,
  history_at     DATETIME(6)  NOT NULL,
  history_by     VARCHAR(255) NULL,
  id             BIGINT       NOT NULL,
  version        BIGINT       NOT NULL,
  text           VARCHAR(255) NULL,
  deleted_at     DATETIME(6)  NULL,
  PRIMARY KEY (history_id)
);
```

and on PostgreSQL:

```sql
CREATE TABLE note_history (
  history_id     BIGINT       GENERATED BY DEFAULT AS IDENTITY,
  history_action VARCHAR(16)  NOT NULL,
  history_at     TIMESTAMP(6) NOT NULL,
  history_by     VARCHAR(255) NULL,
  id             BIGINT       NOT NULL,
  version        BIGINT       NOT NULL,
  text           VARCHAR(255) NULL,
  deleted_at     TIMESTAMP(6) NULL,
  PRIMARY KEY (history_id)
);
```

The prior row is read raw: an encrypted column is copied as its ciphertext, so
the history table holds no plaintext the entity's table does not, and a
principal's column masks do not blank what is kept. An insert writes no history
row — there is no prior version.

`historyOf(id)` answers the row's past versions, oldest first, as
`TomHistoryEntry<T>`: the `entity` as it was, the `action` that replaced it, `at`
and `by`. It reads the four own columns through `TomHistoryMeta`, a reflected
framework type. It is refused with `crud_repository.history.not_declared` for an
entity without `@TomHistory`.

### Lifecycle hooks

A `TomEntityListener<T>` overrides the hooks it needs and is registered for its
entity; `register` answers the function that removes it:

```dart
class NoteStamp extends TomEntityListener<Note> {
  @override
  void beforeSave(Note note, {required bool insert}) {
    note.text = note.text?.trim();
    if (note.text?.isEmpty ?? true) throw StateError('a note says something');
  }

  @override
  Future<void> afterDelete(Object key, Note? note) =>
      searchIndex.remove('note', key);
}

final remove = TomEntityLifecycle.register(NoteStamp());
```

| Hook | Runs | Sees |
| ---- | ---- | ---- |
| `beforeSave(entity, insert:)` | First in `save`, before the scope checks, the column partition and the statement | The entity being saved, which it may change; a throw refuses the save and nothing is written |
| `afterSave(entity, insert:)` | After the row was written and read back | The row as stored, unmasked |
| `beforeDelete(key, entity)` | Before the delete statement, once per row it is about to remove | The row as stored |
| `afterDelete(key, entity)` | After the delete statement and the history row | The row as it was before the delete |

Listeners run in registration order. Because `beforeSave` runs first, the scope
checks, the values written and the audit record see the entity as the hooks
left it. A delete by key list or by query runs the delete hooks once per row
it reaches, which costs a read of those rows before the statement.

`saveAll` saves through `save`, and `saveFile` and `clearFile` end in `save`, so
all of them run the save hooks. `purgeById` runs the delete hooks; `restoreById`
runs none.

A repository subclass overriding `save` or a finder
([Lifecycle work](#lifecycle-work)) is the other way to do work around a write.
A registered listener runs inside the write's transaction and is reached by
every repository of the entity; an override is reached only through that
repository class.

### Change events

`TomEntityLifecycle.onChange(listener, {entity})` registers a
`TomEntityChangeListener` for one entity type, or for every entity when `entity`
is left out, and answers the function that removes it. The repository tells it
of each change after the statement, as a `TomEntityChange`:

| Field | Holds |
| ----- | ----- |
| `entityType` / `key` | The entity type and the row's key |
| `kind` | `TomEntityChangeKind.inserted`, `updated`, `deleted` or `restored` |
| `soft` | Whether a delete marked the row rather than removing it |
| `before` / `after` | The row as stored before and after the change, unmasked; `null` where the change has no such side (an insert has no `before`, a delete no `after`) |
| `beforeValues` / `afterValues` | Their field values, with every `@TomEncrypted` and `@TomBlindIndex` field redacted to `TomFieldEncryption.redacted` |
| `at` / `principalId` / `tenant` | When (UTC), the principal in the zone and the current tenant |

`toJson()` renders the change as JSON-ready values — the entity's name, the
kind, the key as a string, the instants in ISO 8601 UTC, and the redacted values
— the form an outbox row or a message carries. A delete by query reports one
change per row. Listeners run in registration order; `notify(change)` is the
call the repository makes, and `hasChangeListeners(type)` says whether a change
of `type` has anyone to tell.

#### Feeding an outbox

A change listener runs inside the change's transaction, so a listener that
inserts a row of its own is the transactional-outbox pattern: the outbox row
commits exactly when the change does and rolls back with it, and a relay
reading the outbox publishes exactly the committed changes.

```dart
TomEntityLifecycle.onChange(
  (change) => outbox.executeCommand(
    'INSERT INTO note_outbox (payload) VALUES (:payload)',
    {'payload': jsonEncode(change.toJson())},
  ),
  entity: Note,
);
```

The outbox table must live in the entity's data source, so the insert joins the
same transaction. The relay that reads the outbox and hands its rows to
[messaging](messaging.md) is the application's (see
[Not Yet Implemented](#not-yet-implemented)).

### One transaction

An entity is *observed* when it has a registered listener, a change listener
that hears it, or a `@TomHistory` — `TomEntityLifecycle.isObserved(type)`
answers which. Every write of an observed entity runs inside a transaction:
the caller's when there is one (see [transactions](transactions.md)), otherwise
one of its own around that write. The history rows, the listeners' own writes
and the change itself therefore commit or roll back together:

- a throwing `beforeSave` or `beforeDelete` refuses the write;
- a throwing `afterSave`, `afterDelete` or change listener rolls the write back,
  with its history row;
- a caller's transaction that rolls back takes the history rows and every
  listener write with it.

A soft delete of an entity with no listeners and no history runs its `UPDATE`
like any other statement, outside a transaction of its own.

### What the lifecycle does not reach

- **A statement written by hand.** `executeQueryString`, and `executeQuery` or
  `executeCommand` on the data source, bypass the repository: they see
  soft-deleted rows, set no deletion time, write no history and run no hook or
  change listener. A query written by hand on a soft-delete entity adds
  `deleted_at IS NULL` itself.
- **After the commit.** Every hook and change listener runs before the
  transaction commits. Work that must happen only once the change is durable —
  a message, a cache eviction on another node — is written to an outbox in the
  transaction and done by whoever reads it.
- **`restoreById`** runs no hooks; a change listener hears it as `restored`.
- **Several repositories of one entity** share the registry: listeners are
  registered per entity type, not per repository instance.

## Query Sentences

A *query sentence* is a Spring-Data-style phrase compiled by
`TomQuerySentenceCompiler.compileQuerySentence`:

```text
find by name = :name order by age desc
count by status IS IN ( :statuses )
delete by id = $id
group count ( * ) as total over status by age >= :min
```

- The first word picks the kind: `find` → `TomSelect`, `count` → `TomCount`,
  `delete` → `TomDelete`, `group` → `TomGroupedSelect`.
- The part before `by` carries options: `distinct`, the row cap `top N` /
  `first N` (mutually exclusive), and the skip `skip M` / `offset M` (likewise).
  A skip needs a cap, and only `find` and `group` accept one. For `group` this
  part also carries the aggregate projection and the optional `over <fields>`
  group key — see [Grouping and Aggregation](#grouping-and-aggregation).
  Each of these four keywords takes exactly one whole, non-negative number
  after it. An argument that is missing, non-numeric or negative is a syntax
  error, not a request for some other window: `find first x by …` and
  `find first by …` are refused rather than read as `first 1`. `0` is allowed
  and means *unpaged* — the same reading `TomPageRequest` gives `limit: 0`.
- The part after `by` is the predicate, optionally followed by a `having
  <predicate>` clause (`group` only) and
  `order by <field> [asc|desc] [, <field> [asc|desc]]…`. A direction keyword
  applies to every field back to the previous direction keyword, so
  `order by a b desc` sorts both descending while `order by a desc b asc` mixes
  them; a field with no direction of its own sorts ascending. An `order by`
  with no field after it is
  `query_sentence_compiler.analyse_order_by.order_clause_missing_fields`, a
  direction keyword with no field before it is
  `query_sentence_compiler.analyse_order_by.direction_without_field`.

### Which kind takes which option

The four options are parsed once for every sentence, and each kind then permits
or refuses each of them. **A kind that cannot express an option refuses it by
name** — it is never accepted and then dropped, because an option that is
silently ignored changes what the query returns while reading as though it had
not.

| Option | `find` | `group` | `count` | `delete` |
| ------ | :----: | :-----: | :-----: | :------: |
| `distinct` | yes | no | yes | no |
| `first N` / `top N` | yes | yes | no | yes |
| `skip M` / `offset M` | yes | yes | no | no |
| `order by …` | yes | yes | no | yes |

Each *no* is a refusal with a key of its own:

| Refused | Key | Why |
| ------- | --------------------------------------------- | --- |
| a cap on a `count` | `query_sentence_compiler.compile.top_unsupported_for_count` | `LIMIT` caps the rows *returned*, and a count returns one row whatever the cap — so a capped count would count the whole filtered set and then cap nothing |
| an ordering on a `count` | `query_sentence_compiler.compile.order_by_unsupported_for_count` | one row has nothing to order; use `group` to order aggregates |
| a skip on a `delete` | `query_sentence_compiler.compile.skip_unsupported_for_kind` | MariaDB's `DELETE` has no `OFFSET` |
| `distinct` on a `delete` or a `group` | `query_sentence_compiler.compile.distinct_unsupported_for_kind` | a single-table `DELETE` has no projection to deduplicate; a `group` deduplicates *inside* an aggregate — `count ( distinct amount )` — not over the sentence |

More rejections belong to the same step, because each is a way of writing a
sentence or an option that is not one:

| Refused | Key | Why |
| ------- | --- | --- |
| a first word other than `find`, `count`, `delete` or `group` | `query_sentence_compiler.compile.invalid_query_sentence_start` | the verb decides what the compiler builds, so there is nothing to build without one |
| both `first` and `top` | `query_sentence_compiler.compile.conflicting_top_first` | two caps would leave the compiler to pick one |
| both `skip` and `offset` | `query_sentence_compiler.compile.conflicting_skip_offset` | likewise for two skips |
| a skip with no cap | `query_sentence_compiler.compile.skip_without_top` | SQL skips with `LIMIT n OFFSET m` and has no form that skips without capping |
| a word before `by` that names no option | `query_sentence_compiler.compile.unknown_option` | the scan reports where it stopped rather than skipping the token. A skipped word takes its argument with it, so `find frist 5 by …` would return the whole set while reading as though it had capped |
| a sentence with no `by` at all | `query_sentence_compiler.compile.missing_by` | `by` is what separates the options from the predicate, so without it there is neither. Raised here rather than reaching the caller as a `RangeError` — a sentence can come from a request parameter |

A sentence refusing two options at once reports the first in the order above, so
the message does not depend on which order they were written in. One cell of the
matrix is therefore declared but unreachable: a `count` refuses a skip, but a
skip needs a cap and a `count` refuses caps, so `count top 2 skip 4 by …` is
answered by `top_unsupported_for_count` and no sentence reaches
`skip_unsupported_for_kind` through a count.

```text
find first 25 skip 50 by status = :status order by priority desc due_date asc
```

A malformed sentence raises `TomQuerySyntaxException`. So does a *well-formed*
sentence of the wrong kind: the verb decides what the compiler produces, so
`countByQuerySentence('find by …')` is refused under
`crud_repository.count_by_query_sentence.sentence_verb_mismatch` rather than
failing on the cast.

**The sentence is case-free.** Every keyword, both boolean literals and every
column name are matched without regard to case, so `FIND DISTINCT TOP 5 BY
DONE = true ORDER BY id DESC` compiles exactly as its lowercase form does. The
one exception is the inside of a `'…'` string literal, which is a value and is
taken as written.

### `IS IN` lists

`IS IN` / `IS NOT IN` take a bracketed, comma-separated list whose elements are
parsed as the column's own type, so a bind or literal in the list cannot be
typed differently from what it is compared against:

```text
find by status IS IN ( :a , :b ) and done = TRUE
delete by id IS NOT IN ( 1 , 2 , 3 )
```

The brackets are required and the list may not be empty — SQL has no `IN ()`,
so an empty list is refused at compile time rather than handed to the database,
with `query_sentence_compiler.get_in_options.empty_list`. A list that is never
closed (`by id is in ( 1 , 2`) is
`query_sentence_compiler.get_in_options.unterminated_list`. A boolean column is
refused outright, with
`query_sentence_compiler.get_in_options.boolean_column_in_not_allowed`: `IN`
over the two values a boolean can take is a predicate written the long way
round.

### Column types a predicate can address

A predicate addresses a column through three separate type dispatches — the
column node, the bind parameter, and the comparison that joins them — and all
three cover the same seven families: `String`, `int`, `double`, `bool`,
`DateTime`, `TomZonedDate` and `TomZonedTime`, each with its `Tom…` and nullable
`TomN…` spellings, plus the `TomDb…` names when an entity gives `columnType:`
explicitly. A column outside them raises
`query_sentence_compiler.create_column.failed`, and a name that matches no
`@TomDbColumn` field of the entity at all raises
`annotation_analyzer.determine_column.no_column_match`.

The last three are distinct families rather than one, because a `DATETIME`, a
`DATE` and a `TIME` hold different things: a moment, a day with no time, and a
position within a day with no day. Comparing a clock reading against a calendar
one is a question with no answer, so the compiler keeps them apart even though
`TomZonedDate` and `TomZonedTime` are both Dart `DateTime`s by inheritance.

Which family a column belongs to is resolved **once** per mention, and the
column node and its bind parameter then dispatch on that one answer. The
precedence is:

1. the entity's explicit `@TomDbColumn(columnType: ...)`, if it declares one;
2. otherwise the field's declared Dart type.

`columnType:` is the escape hatch for a column whose storage type is not the one
its Dart declaration implies — a flag held as `0`/`1` in an `int`, a rank carried
as text and stored as a number — and it decides everything downstream: which
literals the column admits, how its bind parameter is typed, and what an
aggregate over it returns. It accepts both spellings, a `TomDb…` box and a plain
Dart type.

A `columnType:` naming something outside the seven families is **refused** with
`create_column.failed`, not quietly replaced by the inferred type. Falling back
would make the hatch fail open: the entity states one storage type, the compiler
builds another, and the first symptom is a value written to a column of the wrong
kind rather than a rejection naming the annotation.

### What a comparison compares

The six comparison operators — `=`, `<>`, `<`, `<=`, `>`, `>=` — each take a
column on the left and **exactly one operand** on the right: a literal, a bound
parameter, or another column. The operand ends there. Whatever follows is part
of the surrounding predicate, not part of the comparison:

```text
find by done = TRUE and priority > 3
find by not ( done = :flag ) and priority > 3
```

Brackets group *predicates*, never operands. `find by amount > ( 1.5 )` is a
syntax error (`…build_expression.separator_in_operand_position`) — there is no
form in which a comparison is written against a parenthesised expression.

This is uniform: it holds for all six operators over all seven column families.
**A boolean column is not special.** The tempting exception — letting `=` and
`<>` swallow a boolean right-hand side as a whole predicate — would change what
ordinary queries mean: `done = TRUE and priority > 3` would be refused, and
`not ( done = TRUE ) and priority > 3` would compile to
`NOT ( done = true AND priority > 3 )`, a different question from the one
written. Both behave as the table above says instead.

`and`, `or` and `not` combine predicates, and brackets set their scope. `not`
binds to the single predicate or bracketed group that follows it, so
`not a = 1 and b = 2` negates only the first conjunct; write
`not ( a = 1 and b = 2 )` for the other reading.

Every test word needs a column on its left, and each says so under its own key
when it has none. A test is a predicate, so one written where the compiler needs
a value of another type — an operand position — is refused too; the `LIKE`
family also refuses a column that is not text:

| Test | No column before it | Written where a value is needed | Over a column that is not text |
| ---- | ------------------- | ------------------------------- | ------------------------------ |
| `=` | `query_sentence_compiler.build_expression.eq_without_column` | `query_sentence_compiler.build_expression.eq_invalid_type_expected` | — |
| `<>` | `query_sentence_compiler.build_expression.neq_without_column` | — | — |
| `<` | `query_sentence_compiler.build_expression.lt_without_column` | — | — |
| `<=` | `query_sentence_compiler.build_expression.lte_without_column` | — | — |
| `>` | `query_sentence_compiler.build_expression.gt_without_column` | — | — |
| `>=` | `query_sentence_compiler.build_expression.gte_without_column` | — | — |
| `IS NULL` | `query_sentence_compiler.build_expression.is_null_test_without_column` | `query_sentence_compiler.build_expression.is_null_invalid_type_expected` | — |
| `IS NOT NULL` | `query_sentence_compiler.build_expression.is_not_null_test_without_column` | `query_sentence_compiler.build_expression.is_not_null_invalid_type_expected` | — |
| `IS IN` | `query_sentence_compiler.build_expression.is_in_test_without_column` | `query_sentence_compiler.build_expression.is_in_invalid_type_expected` | — |
| `IS NOT IN` | `query_sentence_compiler.build_expression.is_not_in_test_without_column` | `query_sentence_compiler.build_expression.is_not_in_invalid_type_expected` | — |
| `LIKE` | `query_sentence_compiler.build_expression.like_test_without_column` | `query_sentence_compiler.build_expression.like_invalid_type_expected` | `query_sentence_compiler.build_expression.like_invalid_column_type` |
| `NOT LIKE` | `query_sentence_compiler.build_expression.not_like_test_without_column` | `query_sentence_compiler.build_expression.not_like_invalid_type_expected` | `query_sentence_compiler.build_expression.not_like_invalid_column_type` |
| `REGEXP` | `query_sentence_compiler.build_expression.regexp_test_without_column` | `query_sentence_compiler.build_expression.regexp_invalid_type_expected` | `query_sentence_compiler.build_expression.regexp_invalid_column_type` |

A bind parameter reached before any column is
`query_sentence_compiler.build_expression.parameter_without_column`, since the
column is what types it. A column compared against another column of a
different type is
`query_sentence_compiler.build_expression.column-type-mismatch_after_creation_second_column`,
and a column opening a predicate where a value of another type is required is
`query_sentence_compiler.build_expression.column-type-mismatch_after_creation_new_column`.

The combinators fail on structure:

| Refused | Key |
| ------- | --- |
| `and` with no predicate before it | `query_sentence_compiler.build_query.and_without_current_operation` |
| `or` with no predicate before it | `query_sentence_compiler.build_query.or_without_current_operation` |
| a `)` with no group open to close | `query_sentence_compiler.build_query.unenclosing_closing_bracket` |
| `not not` — between predicates, or inside one | `query_sentence_compiler.build_query.double_not_usage`, `query_sentence_compiler.build_expression.double_not_usage` |
| `not` where a value of another type is needed | `query_sentence_compiler.build_expression.not_invalid_type_expected` |
| a sentence that ends inside a predicate, or straight after `not` | `query_sentence_compiler.build_expression.sentence_ended_early` |
| a predicate from which nothing was built | `query_sentence_compiler.build_query.empty_invalid_query_nothing_built` |

### Writing a value inline

A value in a predicate is normally *bound* (`find by amount > :floor`), but it
can also be written out. Seven literal forms are recognised, by shape:

| Form | Example | SQL type |
| ---- | ------- | -------- |
| Text | `find by title = 'draft'` | `String` |
| Boolean | `find by done = true` | `bool` |
| Integer | `find by priority > 3`, `find by delta > -5` | `int` |
| Decimal | `find by amount > 1.5`, `find by amount > -0.25` | `double` |
| Date | `find by tag_day = 2026-07-05` | `TomZonedDate` |
| Time of day | `find by remind_at >= 09:30:00` | `TomZonedTime` |
| Timestamp | `find by created_at >= 2026-07-05T10:00:00Z` | `DateTime` |

A literal stands for exactly one type, so comparing one against a column of
another raises `…build_expression.<kind>_literal_invalid_type_expected`, and
negating one raises `…_literal_negation_attempt`. Text is
`query_sentence_compiler.build_expression.string_literal_invalid_type_expected`;
the two boolean literals each have their own key,
`query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_true`
and `query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_false`.

`true` and `false` are therefore **reserved in operand position**: a field whose
sentence name is one of them is read as the literal and never resolves as a
column. Reaching that clash takes deliberate effort — a sentence names a field
by its `@TomDbColumn(name: ...)` when it has one and by its Dart declaration
otherwise, and Dart will not let a field be *declared* `true` or `false` — so the
only way in is to write that name explicitly, and the way out is to write a
different one.

**The grammar's own words are reserved there too** — `is`, `not`, `null`,
`like`, `regexp`, `in`, `and`, `or`. Each of them becomes an operator only in
company: `IS NULL`, `IS NOT IN`, `NOT LIKE`. One whose partner is missing or
wrong is claimed by no operator branch and arrives where an operand belongs,
and the reading left over there — "column name" — is always wrong. So it is
refused as `…build_expression.keyword_in_operand_position`, which names the
keyword and quotes the sentence; when the keyword is the last token the message
says the sentence stops before its expression is complete.

The alternative is worse than it sounds. Left to fall through, `find by title
is` was answered by the *annotation analyzer* — "No column match field [is]
found. Must be a variable and must have `@TomDbColumn` annotation" — which sends
the author to look for a field they never wrote, about a sentence that merely
stops one token early. The sentence was refused either way; it was refused with
the wrong reason, by a component that does not know it is parsing. The cost of
reserving is the same as for the boolean literals: a column named `is` or `and`
no longer resolves, and `@TomDbColumn(name: ...)` is how such a field is
renamed.

Three shapes worth knowing. A **decimal is written with a point**, never a
comma: a comma separates an `IS IN` list, so a value spelled `1,5` is read as
two values rather than one. A **timestamp is converted to UTC** as it compiles,
whether written with `Z` or with an offset — `2026-07-05T12:00:00+02:00` and
`2026-07-05T10:00:00Z` produce the same literal. And a **time of day needs all
three fields, each two digits** — `09:30:00`, not `9:30` — because a bound
parameter is recognised by its leading `:`, and requiring a leading digit is
what keeps the two apart with no lookahead. A date and a time are *not*
normalised to UTC: they name a day and a clock position in the calendar they
were written in, and shifting them by an offset would move them to a different
day, or past midnight, for half the world's zones.

#### Inside a text literal

A pair of `'…'` is one token whatever it contains. Spaces, commas, brackets and
comparison signs are all data inside the quotes, and a word that would otherwise
be a keyword or a column name is data too:

```text
find by title = 'in progress, phase (2)'
find by title = 'group by phase'
find by title IS IN ( 'a b' , 'c,d' )
```

An **apostrophe is written by doubling it**, as in SQL:

```text
find by title = 'O''Brien, Ltd'
```

A literal that is opened and never closed is refused with
`query_sentence_compiler.split_query_sentence.unterminated_string_literal`. Note
that this makes a lone `'` unwritable except as `''''` — there is no
backslash escape, only the doubling.

Binding is still the better habit: a bound value is typed by the parameter
rather than by its spelling, it leaves the sentence reusable, and it keeps
untrusted text out of the statement text altogether.

### Matching literal text

`LIKE` is the one predicate whose right-hand operand is a small language rather
than a value. `%` matches any run of characters and `_` any single one —
wherever they appear, including inside a value the caller bound. So a search box
wired straight through binds the user's typing as a *pattern*:
`note like :p` with `p` bound to `%50%%` finds every note containing `50`
followed by anything, not the notes that mention `50%`.

Binding does not prevent this and is not meant to: it makes the value safe, and
a wildcard in a pattern is not unsafe — it is the pattern working as specified.
The wildcards stay the caller's to place, and `escapeLikePattern` escapes what
goes between them:

```dart
final repo = MariadbRepository<Note, int>([Note]);
final rows = await repo.findByQuerySentence(
  'find by text like :p',
  {'p': '%${repo.sqlDialect.escapeLikePattern(searchBox.text)}%'},
);
```

It escapes `%`, `_` and the escape character itself, and the rendered predicate
carries an explicit `ESCAPE` clause naming that character — standard SQL defines
no default one, so without the clause whether the escaping worked would be a
property of the driver rather than of the query. See
[datasources](datasources.md) for the dialect member.

### Filtering on an association

A predicate may name a field of what an association reaches. The association is
a `@TomReference` field of the queried entity, and the term is written
`<association>.<field>` followed by any test a column of that field's type
takes:

```text
find by roles.name = :role
count by roles.name like 'admin%' and active = true
delete by not roles.name = :role
find by roles is empty
find by roles is not empty
```

A term about an association compiles to a **correlated `EXISTS`** over the join
entity and the target. The association's own `leftSideColumns` and
`rightSideColumns` become column comparisons — the left side correlates the
subquery with the owning row — and the test applies to the target's column.
With `User` mapped to `app_user`, `UserRole` to `user_role` and `Role` to
`role`, and a `roles` association declared without `contextColumns`, the first
sentence's predicate renders as:

```text
EXISTS (SELECT 1 FROM user_role, role WHERE (user_role.user_id = app_user.id
  AND user_role.role_id = role.id AND role.name = :role))
```

It is a semi-join, not a join: an owning row is answered **once**, however many
of its associated rows match, so a `find` returns no duplicates and a `count`
counts owners rather than pairs. The term combines with the owner's own columns
through `and`, `or`, `not` and brackets like any other predicate, its parameters
take their place in sentence order, and it is accepted in `find`, `count` and
`delete` sentences alike.

`<association> is empty` and `<association> is not empty` test whether the
association reaches any row at all — `NOT EXISTS` and `EXISTS` over the same
join, with no test on a target column.

**Negation reads as the subquery does.** `roles.name <> :role` asks for owners
with *a* role whose name is not `role` — an owner holding only that role does
not match, and an owner holding it and another one does. "Has no role named
`role`" is the negation of the whole term: `not roles.name = :role`, which
renders `NOT EXISTS (…)`.

A join entity or target that is `@TomSoftDelete` contributes its
`<deleted> IS NULL` inside the subquery, so a soft-deleted link or target is not
reached — unless the query runs inside `TomSoftDelete.includingDeleted`, as for
every other read. A row scope or tenant predicate of the join entity or the
target is not applied inside the subquery: it narrows the owning rows, whose
own scope the repository applies as for any read.

What the compiler refuses, each with `TomQuerySyntaxException`:

| Refused | Key | Why |
| ------- | --- | --- |
| the association named without a field, other than as `is empty` / `is not empty` | `query_sentence_compiler.association.no_field` | an association is a set of rows, and a set has no value to compare |
| a field the target entity does not map | `query_sentence_compiler.association.unknown_field` | the term names the target's column, so it has to be one |
| an association declaring `contextColumns` | `query_sentence_compiler.association.context_columns` | a context column is bound from the execution context when the association is *loaded*; a query sentence has no place to bind it |
| an association whose join entity or target maps the queried table itself | `query_sentence_compiler.association.self_reference` | the subquery would name the table it correlates with, and the tree has no table aliases to tell the two apart |

A dotted name whose first part is no association of the entity is not an
association path; it is read as a column name and refused as one, with
`annotation_analyzer.determine_column.no_column_match`. The same key refuses an
association whose join term has no `=` or names no column of the join entity,
the owner or the target — the refusal loading that association would meet.

### Words this grammar does not have

A query sentence is a *string*, so every operator is directly writable — `>`,
`<`, `%`. That is the difference from Spring Data, where the query is encoded in
a **method name**: an identifier cannot contain an operator character, so
`findByDueAfter` has to spell `>` as a word. Nothing here has that constraint,
and a word-for-operator vocabulary would be a second way to write predicates the
grammar already takes, each with its own branch in a parser whose dartdoc
records three separate lookahead defects. So the words are not keywords, and
this is how each is written instead:

The left column is set in italics because none of those words is code here.

| Spring Data | Here |
| ----------- | ---- |
| *After*, *Before* | `>`, `<` — on a temporal column like any other |
| *StartsWith*, *EndsWith*, *Containing* | `like` with the wildcard placed where you mean it: `'a%'`, `'%a'`, `'%a%'` |
| *Between*, *Within* | `>= :lo and <= :hi`; the single `BETWEEN` node is reachable from the [builder DSL](#the-query-builder-dsl) |
| *Exists* | a term on an association, `roles.name = :n`, which compiles to a correlated `EXISTS`; any other subquery through the builder's `exists` / `isInSubquery` ([Subqueries](#subqueries)) |
| *isEmpty*, *isNotEmpty* | `<association> is empty`, `<association> is not empty` |

The last two apply to associations only, because only an association is a
collection: a mapped column is one of eight scalar Dart types. They are written
as two words after the association's name, like `is null` after a column's —
see [Filtering on an association](#filtering-on-an-association).

## The Query Builder DSL

`TomQueryBuilder` builds a type-safe `TomOperator` tree without naming the
operator classes. Predicate factories return `TomOperator<TomDbBool>`; literal,
parameter, and column factories return the matching SQL-typed operator:

```dart
// (age >= :min) AND (name LIKE 'A%')
final predicate = and([
  group(gte(intF('age', ageCol), p<TomDbInt>('min'))),
  group(like(textF('name', nameCol), text('A%'))),
]);
final sql = predicate.generate(MariadbSqlDialect());
```

Use `p<T>('name')` for bound parameters (`:name`) — the driver binds the value,
avoiding SQL injection. Literal factories (`text`, `intOp`, `dateOp`, …)
interpolate directly and should be reserved for trusted values.

`Between` takes exactly two bounds, and a node built with any other number is
refused with `between_expression.must_have_two_values`.

### Subqueries

A predicate about another result set is built from a `TomSubquery`: the entity
types it reads, an optional `where` predicate over their columns, and — for
`IN` — the one column it selects as `projection` (`1` when there is none).

| Factory | Renders |
| ------- | ------- |
| `exists(subquery)` | `EXISTS (<subquery>)` |
| `notExists(subquery)` | `NOT EXISTS (<subquery>)` |
| `isInSubquery<T>(what, subquery)` | `<what> IN (<subquery>)` |
| `isNotInSubquery<T>(what, subquery)` | `NOT <what> IN (<subquery>)` |

```dart
// order.id IN (SELECT order_line.order_id FROM order_line
//              WHERE (order_line.sku = :sku))
final predicate = isInSubquery<TomDbInt>(
  intF('id', orderId),
  TomSubquery(
    [OrderLine],
    projection: intF('orderId', lineOrderId),
    where: eq<TomDbInt>(intF('sku', lineSku), p<TomDbInt>('sku')),
  ),
);
```

The subquery renders `SELECT <projection> FROM <tables> WHERE (<where>)`, one
table per entity type in the order given. Its `TomExists` and `TomInSubquery`
nodes are what the expression tree holds, and both are ordinary predicates:
they combine with `and`, `or` and `not` and render through the dialect's
`exists`, `inSubquery` and `subquery` members (see
[datasources](datasources.md)).

**A subquery is opaque to the walks over the enclosing tree.** `TomExists` has
no `children` and reports no fields, and `TomInSubquery` reports only its
operand's: the columns inside the subquery belong to the subquery's tables, not
to the enclosing query's. Its parameters are the enclosing statement's all the
same, and `getParameters` reports them in place — the projection's, then the
`where`'s — so binding follows the rendered text.

**Correlation is by table name.** A column renders as `table.column`, so a
subquery's `where` may name a column of the enclosing query's table and that
makes it correlated — the shape [Filtering on an association](#filtering-on-an-association)
compiles to. The one shape that cannot be written is a subquery over the
enclosing query's own table that correlates with it: both sides would render as
the same table name, and the tree has no aliases.

**A soft-deleted entity in a subquery contributes its live-row test.** For each
type that is `@TomSoftDelete`, the subquery adds `<table>.<deleted> IS NULL`
beside its `where`, as a repository read would — unless it renders inside
`TomSoftDelete.includingDeleted`, which leaves the test out.

## Row Scopes

A **row scope** (C-3) narrows every query on an entity to the rows the current
principal may see, by ANDing a `<column> IN (…)` predicate into the `WHERE`. It
is not a filter the caller opts into per query — it is a property of the
*entity*, applied by the repository to every read and enforced on every write,
so a caller cannot forget it.

### Declaring a scope

`@TomDbScope(field:, scope:)` names the entity field whose value is matched and
the **scope kind** that resolves the principal into a set of allowed values:

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'note', primaryKeyFields: ['id'])
@TomDbScope(field: 'ownerId')          // scope defaults to 'owner'
class Note {
  @TomEntityId() @TomDbColumn(columnName: 'id') int? id;
  @TomDbColumn(columnName: 'owner_id') String ownerId = '';
}
```

Three kinds are registered out of the box:

| Kind | Allowed values | Resolution |
| ---- | -------------- | ---------- |
| `owner` | `principal.qualifiedId` — the principal id qualified by its tenant (the bare id without tenancy; see [tenancy.md](tenancy.md#principals-per-tenant)). On an `int` column the bare id is bound as a number; a qualified id matches no row there | synchronous |
| `group` | `principal.aci.groups` | synchronous |
| `resource` (`TomDbScope.resourceScope`) | the resource keys the principal holds a grant on | **asynchronous**, through the installed `TomResourceScopeSource` |

An application adds its own (`'organization'`, `'department'`, …) with
`TomDataScopeRegistry.register` or `registerAsync`; `reset()` restores just the
built-ins. A scope naming a kind nothing registered fails the query rather than
leaving it unscoped: `data_scope.build.unknown_scope` when no resolver is
registered for it, `data_scope.build.unknown_async_scope` when the asynchronous
path finds no asynchronous one.

### Automatic scoping, and opting out

An entity that carries a **`resource_key` column** (or a `resourceKey` field) is
scoped under the `resource` kind *without an annotation* —
`TomAnnotationAnalyzer.autoScopeFor` synthesises exactly the `@TomDbScope` a
developer would have written. Grant-driven scoping is therefore the default, and
forgetting the annotation can no longer silently publish every row.

An entity that must stay global despite carrying such a column says so
explicitly:

```dart
@TomDbScope.unscoped()   // field: '', scope: '' — the deliberate opt-out
```

`TomAnnotationAnalyzer.findDataScope` resolves in that order: an explicit
annotation wins (including the opt-out, which yields no scope), then the
automatic resource scope, then nothing.

The framework's **own** authorization tables are excluded from automatic scoping
twice over. They declare `@TomDbScope.unscoped()`, and they are additionally
named in `TomAnnotationAnalyzer.resourceScopeInputTables`. The second guard is
the load-bearing one: those tables are the input the `resource` scope reads *in
order to compute itself*, so scoping them would close the authorization layer
against itself — a principal could reach its own grant rows only by already
holding a grant on them, which no row can satisfy. A constant set survives a
**stale generated `*.reflection.dart`** whose class metadata predates the
annotation, and a safety invariant must not depend on a deployment having re-run
code generation before it upgrades. A test asserts the constant names exactly
the tables those entities declare, so a table rename cannot silently disarm it.
(For detecting a stale generated file rather than surviving one, see
[`reflection_generation.md`](reflection_generation.md).)

Because the exclusion is a fact about the entity rather than about one of its
columns, `autoScopeFor` decides it for the whole column list up front: a list
naming one of the three tables anywhere yields no scope, and only then is the
resource key looked for. Every column the analyzer resolves carries the one
`@TomDbTable` of its type, so for a real entity the answer is the same either
way — but tested per column, whether a grant table gets scoped would read as
though it depended on where the resource key sits.

### How a scope renders

`TomDataScope.build` (sync) and `buildAsync` (async) turn the resolver's answer
into a `TomDataScopePredicate` — a boolean operator plus the bind values it
references:

- **`null`** from the resolver means *opt out* — no predicate, every row visible;
- **an empty result** denies every row, rendering a constant false predicate
  (`TruthPredicate`, through the dialect's `truthPredicate`: `false` on
  MariaDB, `FALSE` on PostgreSQL) — `IN ()` is not valid SQL, and an allowed-value set of no values
  matches no rows. It is a predicate rather than a `BoolLiteral` because the two
  differ on PostgreSQL, where a truth *value* is the `1`/`0` a `SMALLINT` truth
  column holds and a `WHERE 0` is a type error;
- otherwise `<col> IN (:__tomscope_0, …)`, **one bound parameter per value**, so
  no scope value is ever concatenated into the SQL text (C-7).

A **sync** resolver returns one value list and renders one `IN`. An **async**
resolver returns a *list of id-set groups* and renders their **union**:
`(<col> IN (…) OR <col> IN (…))`, with each group's placeholders namespaced
(`__tomscope_0_`, `__tomscope_1_`, …). The multi-group union is wrapped in an
explicit parenthesis group — the caller ANDs the whole thing into a larger
`WHERE`, and an unparenthesised `a OR b` would bind as `(base AND a) OR b`,
letting the second id-set escape the base filter and leak rows.

The union shape exists because some visibility rules are genuinely a union of
independently-computed sets (rows I own ∪ rows shared with me), which a single
intersecting `IN` list cannot express without silently hiding legitimately
shared rows.

### Async resolvers must not recurse

An async resolver typically computes its id-set by *reading the very entities it
scopes*. Those reads must not re-enter scope resolution. A resolver therefore
wraps its enumeration in `TomDataScope.runUnscoped`, which places a
`TomDataScopeBypass` marker in the zone; `TomDataScope.isBypassed` reads it, and
the repository skips scope resolution entirely while it is present. This is the
guard against unbounded resolver recursion, and it is why the reads that
*compute* a visible set are not themselves scoped.

### Reads filter, writes reject

The read paths *filter*: an out-of-scope row simply is not returned. A write
names a specific row, so filtering it away would be a silent no-op; the
repository *rejects* instead, with `TomDataScopeAuthorizationException`:

- **update / delete by id** — `_assertRowWritable` re-runs the exact scoped read
  predicate; if the row is not found it is refused, with
  `data_scope.write.out_of_scope`. Modelling the check as a
  scoped visibility read (rather than an atomic `UPDATE … AND <scope>` plus a
  zero-rows-affected test) sidesteps the MariaDB quirk that an `UPDATE` changing
  no value reports zero affected rows, which would otherwise reject a legitimate
  in-scope no-op write. A missing row and an out-of-scope row are reported
  identically, so existence is not leaked across the scope boundary.
- **bulk delete** — `_assertIdsWritable` requires the scoped existence check to
  see *all* the named ids, and refuses with the same `data_scope.write.out_of_scope`.
- **insert** — `_assertInsertWritable` checks the new row's scope-field value
  against the allowed set, which is what stops a principal creating a row scoped
  to a value it could not itself read; the refusal is
  `data_scope.write.insert_out_of_scope`. A scope **on the primary key** is a no-op
  here: a fresh insert has no id yet, so there is no value to check, and insert
  authorization for such entities belongs to the service layer.

### Reading and writing can differ

A scope kind may register a **write resolver** alongside its read resolver,
answering the narrower question "which values may this principal *modify*". A
kind that registers none writes exactly what it reads.

This is what lets the `resource` kind admit a `read`-graded key to queries while
rejecting every write to it, and it generalises: "may read every tenant, may
write only my own" has the same shape. The `forWrite` flag threads the choice
through `build` / `buildAsync` / `allowedValues` / `allowedValuesAsync` down to
the three write guards above.

### The grant-driven `resource` kind

The `resource` kind's resolver is deliberately *empty* in this module: it
delegates to whatever `TomResourceScopeSource` is installed in
`TomDataScopeRegistry.resourceScopeSource`, and denies every row while none is
— an unwired scope must be a closed door. The interface is declared here and
implemented in the authorization module by `TomResourceDataScope`, which is the
inversion that keeps the dependency arrow pointing from authorization down to
persistence rather than the reverse. See
[`authorization.md`](authorization.md#the-grant-driven-row-scope).

## Tenant-Owned Rows

A deployment serving several tenants marks the entities whose rows belong to a
tenant with `@TomTenantOwned`. The tenant itself comes from the zone —
`TomTenantContext.currentId`, set per request by the server's pipeline — so no
repository call takes a tenant argument. See [tenancy.md](tenancy.md) for where
tenants come from and the three isolation models.

```dart
@tomReflector
@TomTenantOwned()
@TomDbTable(datasource: 'main', table: 'invoice', primaryKeyFields: ['id'])
class Invoice {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomDbColumn(columnName: 'tenant_id')
  String? tenantId;
}
```

`field` names the entity field holding the tenant id — `tenantId` unless the
annotation says otherwise (`@TomTenantOwned(field: 'customer')`).

### What the repository does with it

| Operation | With a tenant in context | With no tenant in context |
| --------- | ------------------------ | ------------------------- |
| every read — `findAll`, `findById`, `count`, `findWhere`, the existence checks | adds `<field> = <tenant>` as a bound predicate | reads nothing (a `FALSE` predicate) |
| `save`, `saveFile` — insert | fills an unset tenant field with the current tenant; refuses an entity naming another, `data_scope.write.foreign_tenant` | refused, `data_scope.write.no_tenant` |
| `save`, `saveFile` — update | the same tenant check, then touches only a row the predicate admits; another tenant's row is reported exactly as a missing one, `data_scope.write.out_of_scope` | refused, `data_scope.write.no_tenant` |
| `delete`, `deleteById`, `deleteAllById` | touches only rows the predicate admits, `data_scope.write.out_of_scope` otherwise | nothing is in scope, `data_scope.write.out_of_scope` |

Naming another tenant on an update is refused the same way, which is what stops
an update from moving a row out of its tenant.

The tenant predicate is **independent of `@TomDbScope` and ANDed with it**, so an
entity can be a tenant's and scoped to its owner or to a resource grant at once.
Its parameters carry their own prefix,
`TomSqlDatasourceRepository.tenantParameterPrefix` (`__tomtenant_`), so the two
bind in one statement. And unlike the data scope it is **not suppressed inside an
async resolver's enumeration** (see
[Async resolvers must not recurse](#async-resolvers-must-not-recurse)): a
resolver computing one tenant's visible ids must not read another tenant's rows
to do it.

`TomAnnotationAnalyzer.findTenantOwnership(type)` answers the annotation, or
`null` for an entity that is not tenant-owned, memoised like the analyzer's
other lookups.

### One repository, every tenant

A repository's `datasourceInfo` is a getter, resolved through
`TomDataSourceInfo.route` on every access: in a deployment whose tenants live in
a schema or a database of their own, the same repository instance reaches the
current tenant's. Prepared statements are cached **per data source**, so a
statement prepared on one tenant's database is never executed against
another's. The predicate above applies in every isolation model — under schema
and database isolation it is a second wall rather than the only one, and it is
why moving a tenant between models is a copy of its rows rather than a schema
change.

## Column Authorization

A row scope decides *which rows*. **Column authorization** (C-4) decides *which
columns of a row the principal may see and change*, and — like the row scope —
it is a property of the mapping, applied by the repository on every path, not a
filter a caller opts into.

### Grading a column

A column opts in by naming a resource key, in either of two ways:

```dart
@TomDbColumn(columnName: 'salary', authKey: 'employee.salary')
int? salary;

// or, with the kernel's field annotation — which the JSON serializer honours
// too, so one key protects the field on the wire as well as in the store:
@TomProtectedField('employee.salary')
@TomDbColumn(columnName: 'salary')
int? salary;
```

`TomColumnInformation.authKey` is the resolved key: the column's `authKey`, else
the field's `@TomProtectedField`. It is resolved to a kernel `TomAuthState`, the
four-state grade `none < disabled < read < full`. A column with **no** key is
unrestricted: `TomColumnAuthorization.stateForKey(null)` is `full`, so an entity
that grades nothing pays nothing.

Unless a resolver is passed explicitly — which is what a test does — the grade
is `TomResourceKeyProtection.automaticState`: the installed `TomAuthorization`
adapter's grade met with the request principal's resource-key grade. Each side
answers `full` when it is not configured (no adapter; resource keys not
enforced), so an unconfigured deployment is unrestricted, a server grading from
its principals' grants needs no adapter, and a deployment configuring both gets
the more restrictive answer.

This is the **database tier** of the kernel's automatic protection. It applies
while `TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection` is
on — its default — and `tom.protection.database=false` (or
`tom.protection=false`) on the server's command line switches it off: every
column is then unrestricted, per-row resolvers included. Row filtering by
`@TomDbScope` is not part of the tier and stays in force.

The grade is honoured *here*, at the persistence boundary, rather than being left
to whatever renders the entity. A field the caller may not see never leaves the
repository.

### Reads mask

`TomColumnAuthorization.maskedColumns` selects the columns whose grade lacks
`showsContent` — `none` and `disabled` — and `applyReadMask` nulls those fields
on each returned row, in place. Every read path runs it, so masking is not a
thing a query can be written to avoid.

The consequence for the entity class: **a graded field must be nullable**. There
is no other value that means "withheld", and a non-nullable field cannot be
given one.

### Writes reject, or silently preserve

`decideWrites` partitions the graded columns of a pending save by comparing the
incoming entity against the stored row:

| Grade | Outcome |
| ----- | ------- |
| `full` | **Written** — the incoming value is persisted. |
| `read`, and the value changed | **Refused** — `TomColumnAuthorizationException` with key `column_authorization.write.field_forbidden`. |
| `read`, unchanged | **Preserved** — nothing to refuse. |
| `disabled` / `none` | **Preserved** unconditionally. |

The asymmetry between the last two rows is the point, and it follows from
masking. A masked column reads back as `null`; a client that loads an entity,
edits one field and saves it back therefore returns `null` for every masked
column, having never seen — let alone touched — the stored value. Rejecting that
would make every ordinary round trip fail on a column the caller cannot even
know exists, so the repository quietly overlays the stored value instead. A
change to a column the caller *can* see, on the other hand, is a real attempt to
write something it may not write, and it is named rather than swallowed.

The stored row this compares against is read **once** per save and shared with
the audit before-image and the file cascade below, which want the same row for
different reasons.

Grouped queries are the exception: a masked column there is refused outright
rather than masked, because aggregation has already consumed the hidden values —
see [Authorization](#authorization) under Grouping and Aggregation.

### Grades that depend on the row

Some grades are *relational*: "may edit the attachments of items in a project you
own, may only read the ones in a project shared with you". A `key → state`
lookup cannot express that, and it cannot be computed synchronously — it is a
question about the row's owning aggregate, which means a read.

`TomRowColumnAuthorization` is the async counterpart, and the column-level mirror
of `TomDataScopeRegistry.registerAsync`:

```dart
TomRowColumnAuthorization.register('task.attachment', (principal, rowId) async {
  if (rowId == null) return TomAuthState.full;   // an insert: no row yet
  return await gradeForTask(principal, rowId);
});
```

`resolve` reads the principal from the current zone and returns `null` when the
column is unrestricted or carries no per-row resolver, leaving the caller on its
column-wide answer; `isRegistered` asks whether a key has one, and `reset()`
clears the registrations (for tests).

**Only the file operations consult it.** Each addresses exactly one row and is
already asynchronous, so a per-row grade costs one extra `await`. The
row-projection paths are synchronous and operate on whole result sets, where the
same feature would mean a cross-table read per row per column. `applyReadMask`
therefore *skips* a column that has a per-row resolver rather than guessing:
a single synchronous answer applied to a whole result set has no authority to
decide it, and masking it would be self-defeating anyway — for a file column the
masked value *is* the storage key the file gate then needs in order to resolve
the grade at all.

## File-Reference Columns

A `@TomFileReference` column holds a **storage key**; the bytes live in a blob
store (see [`file_storage.md`](file_storage.md)). The row therefore stays small
enough to select, diff, audit and mask like any other, while a payload that may
be gigabytes never passes through SQL.

### Declaring one

```dart
@TomDbColumn(columnName: 'contract_key', authKey: 'deal.contract')
@TomFileReference(
  store: 'documents',
  keyPrefix: 'contracts',
  mediaType: 'application/pdf',
  exposed: true,
)
String? contractKey;
```

| Field | Default | Meaning |
| ----- | ------- | ------- |
| `store` | `null` | The named blob store to use; `null` means the default store. |
| `keyPrefix` | `''` | The prefix generated keys are placed under. It is joined into the key, so it obeys the same grammar (`TomBlobStore.isValidKeyPrefix`) and carries no trailing slash. |
| `cascadeDelete` | `true` | Whether deleting the row — or replacing/clearing the column's value — also deletes the blob. |
| `mediaType` | `'application/octet-stream'` | The media type assumed when an upload names none. |
| `exposed` | `false` | Whether the column is reachable over the framework's HTTP file endpoint, as the slot `<table>/<id>/<column>`. |

Two of those defaults are deliberate. `exposed` is **default-closed**, and it
decides only *addressability*, never entitlement: whether a given caller may have
the file stays with the row scope (C-3) and the column grade (C-4) the repository
already enforces. And `keyPrefix` is validated when the key is minted rather than
when the annotation is written, because a `const` constructor cannot refuse a
value.

### The key

`TomFileReferenceKeys.generate` mints `<keyPrefix>/<yyyy>/<mm>/<uuid><.ext>`:

- the **prefix** separates one column's blobs from another's, so a store shared
  by several entities stays navigable and a lifecycle rule can be written against
  a path;
- the **date partition** bounds how many objects land in one directory — which
  matters to a filesystem backend, and makes "everything from July" expressible
  as a prefix on an object store;
- the **UUID** makes the key collision-free without a round trip, so a fresh
  upload never silently overwrites a live one, and unguessable, so holding one
  key does not let a caller enumerate its neighbours;
- the **extension** is carried over from the uploaded file name because it costs
  nothing and makes a key readable to whoever is looking at the bucket. It is
  decoration — the media type of record lives in the blob descriptor, not in the
  key.

`extensionOf` is correspondingly conservative: it takes the lower-cased suffix
after the last dot, and only when it is at most twelve characters and purely
alphanumeric. Anything else yields the empty string. A "file name" arriving from
a browser is caller-supplied text, not a vetted identifier, and it is being
appended to a key whose grammar is narrow.

`storeFor` resolves the annotation's store on **every call** rather than caching
it on the column metadata: the registry is populated at start-up and replaced
wholesale by a test, and a column that captured a store at first use would keep
serving the previous test's.

### Moving the bytes

Four repository methods surround the store. They are also named on their own
contract, `TomFileRepository<T, K>` — that is what the HTTP file endpoint depends
on, so the endpoint's requirement is five methods rather than a whole persistence
stack, and it can be exercised without a database:

```dart
Future<T?> findById(K id);
Future<T> saveFile(T entity, String fieldName, Stream<List<int>> bytes,
    {String? mediaType, String? fileName});
Stream<List<int>> openFile(K id, String fieldName, {TomBlobRange? range});
Future<TomStoredBlob?> describeFile(K id, String fieldName);
Future<T> clearFile(T entity, String fieldName);
```

`saveFile` **uploads first and saves the row second**, and the order is the one
whose failure mode is survivable. Saving first would leave a row pointing at a
key that reads back `not_found` — a dangling reference, visible to users and
repairable only by hand. Uploading first can at worst leave an orphaned blob,
which nothing references and a sweep can collect
([Sweeping files no row refers to](#sweeping-files-no-row-refers-to)); and even
that is cleaned up when the save throws.

`describeFile` is the metadata read that precedes a download — a caller needs the
`Content-Type` and `Content-Length` before it starts streaming. `clearFile` is
expressed as a save of a nulled column rather than as its own delete path, so the
orphan collection, the audit record and both authorization gates are the ones
every other write goes through.

A field name that is not a file column of the entity raises
`storage.file_reference.unknown_column`. On the read side, a row that does not
exist (or is not visible) raises `storage.file_reference.row_not_found`, and a
row whose column holds no key raises `storage.file_reference.no_file` — asking
for a file that is not there is a different answer from an empty one.

### Authorization, by construction

The key is an ordinary column, so both existing controls already govern it. The
file methods therefore reach the bytes *through* the existing read paths rather
than beside them: `openFile` and `describeFile` take an **id** and load the row
with `findById`, so a principal who cannot see the row cannot see its file —
because the row scope filtered it, not because a second copy of the rule said so.

What is added on top is only what the masked case needs. A C-4 masked key reads
back as `null`, which is indistinguishable from "no file attached", so the grade
is checked explicitly and the refusal is named
(`column_authorization.read.field_forbidden`). The three write-side operations
share one check for the same reason they share a question — uploading a file,
replacing one and clearing one are all writes of the same column, and a grade
that refuses one must refuse all three. `clearFile` needs it in particular
because `save` resolves the grade *column-wide*, which is not the answer for a
column with a per-row resolver: without the explicit check a principal graded
`read`, allowed to download the file and nothing else, could delete it.

Grades here are resolved **per row** where a resolver is registered — see
[Grades that depend on the row](#grades-that-depend-on-the-row).

### Blobs that nothing references

`cascadeDelete` governs the tidy-up, and three details make it safe:

- **A replaced file** is collected on update, decided from the values about to be
  written and measured against the *baseline row* — never against the row read
  back. A masked column reads back `null`, which would otherwise look like the
  file having been removed and would delete a live blob. A column absent from the
  write set (a read-only one) was not changed by this save and orphans nothing.
  The old key is discarded only once the row no longer points at it.
- **A deleted row's** files are collected **after** the rows are gone: a delete
  that fails must not have destroyed the files of rows that are still there. The
  rows about to be deleted are read unmasked, so their keys are visible to the
  cascade, and that extra read is skipped entirely for an entity with no file
  columns.
- **A store that will not delete** is logged, not raised. Every caller has
  already completed the operation the user asked for; leaving bytes behind is a
  housekeeping problem, whereas reporting a completed operation as failed is a
  correctness one. The key is logged so a sweep can find what was left.

An entity with no `@TomFileReference` column short-circuits every path above, so
the feature costs nothing to the entities that do not use it.

### Sweeping files no row refers to

A file is uploaded and then attached: the upload writes the blob, a later save
writes the row naming it. An upload whose row never comes — the form abandoned,
the request failing after the upload — leaves a blob nothing serves and nothing
deletes. A plain blob store cannot find those, because it cannot list itself. A
`TomDeduplicatingBlobStore`
([Deduplication, Quota and Reclaim](file_storage.md#deduplication-quota-and-reclaim))
can, because its ledger records every key, and `TomBlobOrphanSweep` walks that
ledger and asks the rows:

```dart
final sweep = TomBlobOrphanSweep(
  store: store, // a TomDeduplicatingBlobStore
  sources: [
    TomRepositoryBlobReferences(contracts),
    TomRepositoryBlobReferences(avatars, fields: {'imageKey'}),
  ],
  prefixes: const ['contracts', 'avatars'],
);
final report = await sweep.sweep();
```

One `sweep` pages through the ledger's keys written before `now - grace`, in key
order, `batchSize` (default 500) at a time. A key under none of `prefixes` is
left alone — give them when the store also holds files no source describes; with
none, every key is considered. Each `TomBlobReferenceSource` is asked which of
the page's keys a row refers to, and the keys no source names are asked about a
**second time** immediately before they are deleted, so a row saved while the
page was being checked keeps its file. The keys still unreferenced are deleted
from the store, and then — unless `reclaim: false` — the store's `reclaim` runs,
freeing content no key names any more. The `TomBlobOrphanSweepReport` says how
many keys were considered (`scanned`), which were deleted (`deleted`) and how
many contents the reclaim freed (`reclaimed`).

**The grace is the attach window.** Only keys written more than `grace` ago
(default one day) are considered, so an upload has that long to be attached. A
row saved *after* the sweep's second question, naming a key older than the
grace, can still lose its file — the second question narrows that window to the
delete itself, it does not close it. Choose a grace far longer than any
upload-to-save delay a deployment allows. `now` defaults to the sweep's `clock`
(`DateTime.now` unless one is given).

**`TomRepositoryBlobReferences` reads the rows the way a sweep needs.** It
covers every `@TomFileReference` column of the entity, or those `fields` names
(by field or column name), and asks them in batches of `batchSize` (default
100) — one `FIND BY <column> IS IN (…)` per column and batch. Soft-deleted rows
count, because a restore brings their files back into use. A column graded with
an `authKey` is counted key by key instead (`COUNT BY <column> = :key`): a read
outside a request may mask such a column to `null`, and a key the sweep cannot
see is a key it deletes, whereas a count is never masked. Any other source —
rows in another database, a document store, a fixed list — implements
`TomBlobReferenceSource.referenced`.

**It refuses to run inside a request.** A request's data scope hides rows, and a
row the sweep cannot see is a reference it deletes, so `sweep` throws
`storage.sweep.scoped_run` when a principal is in the zone, unless the sweep was
built with `allowScopedRun: true`. A sweep with no sources, a grace that is not
positive or a batch size below one is refused at construction with an
`ArgumentError`: the first would empty the store, the others never make
progress.

`jobDefinition()` is the sweep as a `TomJobDefinition` named
`tom.storage.orphan_sweep`, daily by default, for a `TomScheduler` to run in its
own isolate (`TomInlineJobDispatcher`), since its body holds the sweep; a run's
result is the report's text.

`TomStorageException` covers the sweep under `storage.sweep.*` keys:

| Key | Raised when |
| --- | ----------- |
| `storage.sweep.scoped_run` | `sweep` was called with a request principal in the zone and `allowScopedRun` unset. Raised before a single key is read. |
| `storage.sweep.no_file_columns` | `TomRepositoryBlobReferences` was built for an entity that declares no `@TomFileReference` column. |
| `storage.sweep.unknown_field` | `fields` names a field that is not one of the entity's file columns. |

## Field-Level Encryption

A `String` field marked `@TomEncrypted` is stored as ciphertext and read as
plaintext. The repository encrypts it on every save and the data source decrypts
it on every read, so an entity — and everything above the repository — only
ever holds plaintext, while the database, its backups and its replicas only ever
hold ciphertext. The keys rotate without downtime, and a column that held
plaintext before it was marked is encrypted in place by a background pass. The
implementation is `field_encryption.dart`; the data-key table is declared in
`field_encryption_sql.dart`.

### Marking a field

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'patient', primaryKeyFields: ['id'])
class Patient {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomEncrypted()
  @TomDbColumn(columnName: 'name')
  String? name;

  @TomEncrypted()
  @TomDbColumn(columnName: 'email')
  String? email;

  @TomBlindIndex('email')
  @TomDbColumn(columnName: 'email_bidx')
  String? emailIndex;

  @TomDbColumn(columnName: 'ward')
  String? ward;
}
```

`TomAnnotationAnalyzer` refuses, when it resolves the entity's columns, every
declaration the repository could not maintain:

| Refused | Key |
| ------- | --- |
| `@TomEncrypted` or `@TomBlindIndex` on a field that is not a `String` | `annotation_analyzer.encryption.not_string` |
| both on one field — the index is a column of its own | `annotation_analyzer.encryption.both` |
| `@TomEncrypted` on the entity id, the version, a `@TomReference` or a `@TomFileReference` column — the database compares those, or the framework reads them | `annotation_analyzer.encryption.structural_column` |
| a `@TomBlindIndex` naming a field of the entity that is not `@TomEncrypted` | `annotation_analyzer.encryption.index_without_field` |

`TomAnnotationAnalyzer.encryptedColumns(type)` and `blindIndexColumns(type)`
answer the two column sets in declaration order, empty for an entity with none.
`TomColumnInformation.encrypted` and `blindIndex` carry the annotations.

### What is stored

The cipher is AES-256-GCM, **randomised**: every write draws a fresh 96-bit
nonce, so two equal values store differently and the column reveals nothing
about which rows share a value. A stored value reads

```text
tomenc:v1:<data key id>:<base64url of nonce, ciphertext and tag>
```

— `TomFieldEncryption.prefix` is `tomenc:v1:`, the key id names the data key the
value was encrypted under, and the body is unpadded base64url.
`TomFieldEncryption.isCiphertext(value)` and `keyIdOf(value)` read the format.

The table and column, `<table>.<column>`, are the cipher's **additional
authenticated data**. A value copied into another column, or another table,
fails its authentication rather than decrypting into the wrong place; so does a
value altered by one byte. `null` is stored as `NULL`, unencrypted: whether a
field is set is visible, its content is not.

**The column must be wide enough for the ciphertext.** A stored value is
`TomFieldEncryption.storedLength(n)` characters for a plaintext of `n` UTF-8
bytes — the prefix, a 36-character key id, the separator, and the base64url of
the 12-byte nonce, the ciphertext and the 16-byte tag:

| Plaintext (UTF-8 bytes) | Stored characters |
| ----------------------- | ----------------- |
| 0 | 85 |
| 64 | 170 |
| 254 — the longest e-mail address | 423 |

Declare the column `TEXT`, or a `VARCHAR` of `storedLength` of the longest
plaintext. A blind-index column holds 43 characters (an unpadded base64url
HMAC-SHA-256); `VARCHAR(64)` leaves room.

### Writes and reads

**A save** encrypts every written `@TomEncrypted` column under the active data
key, and fills every `@TomBlindIndex` column from the plaintext of the field it
indexes — whatever the entity holds in the index field itself is overwritten.
Encryption is resolved before the statements are built, so the plaintext never
reaches a bound parameter.

**A read** of an entity decrypts in the data source's row mapping. Before the
rows are mapped, the data source collects the data-key ids every encrypted value
of the result names and has the keyring load the ones it does not hold
(`TomFieldEncryption.prepareRead`); each value then decrypts without waiting
(`TomFieldEncryption.decrypt`). A value naming a data key the table does not
hold either fails with `field_encryption.unknown_key`; one that does not
authenticate fails with `field_encryption.decrypt_failed`.

`TomFieldEncryption.raw(body)` runs `body` with decryption off: the data source
maps an encrypted column's stored value as it is and loads no `@TomReference`.
It is what the [re-encryption pass](#the-re-encryption-pass) reads through, and
what a test or a maintenance script uses to see what the table holds:

```dart
final stored = await TomFieldEncryption.raw(() => patients.findById(id));
// stored!.name starts with 'tomenc:v1:'
```

`TomFieldEncryption.isRaw` answers whether the current zone reads raw.

### Finding a row by value

Randomised ciphertext compares equal to nothing, so an encrypted column cannot
be filtered on. A field that must be found by value carries a **blind index**: a
companion `@TomBlindIndex` column holding an HMAC-SHA-256 of the normalised
plaintext under an index key of its own. Equal plaintexts give equal index
values, so the index column can be compared, while the plaintext is not
recoverable from it. It does reveal which rows share a value — the price of
finding them — so a field nobody looks up carries no index.

`TomBlindIndexNormalization` says which values count as equal; the default is
`trimLowercase`:

| Normalization | Indexes |
| ------------- | ------- |
| `exact` | the value as it is |
| `trim` | the value without leading and trailing whitespace |
| `trimLowercase` | trimmed and lower-cased — an e-mail address, a user name |

The HMAC also covers the table and the indexed field's name, so two index
columns over equal values in different places hold different values.

A lookup uses `TomFieldEncryption.blindIndexCondition(entity, field,
plaintext)`, which answers a query-sentence condition with its parameters:

```dart
final c = await TomFieldEncryption.blindIndexCondition(Patient, 'email', email);
// c.condition: 'emailIndex is in ( :emailIndex0 , :emailIndex1 )'
final found = await patients.findByQuerySentence(
  'find by ${c.condition}',
  c.params,
);
```

The condition lists the index value under **every index key** of the current
context, the active one first (`blindIndexCandidates`), so a lookup finds every
row while an [index-key rotation](#rotating-keys) is being rewritten. Outside a
rotation there is one key and one value. `blindIndexOf(entity, field,
plaintext)` answers the single value under the active index key, for a caller
that compares it itself; `blindIndex(indexColumn, plaintext, keyId: …)` computes
one under a named key. A field without a `@TomBlindIndex` is a programmer error
and raises `ArgumentError`.

### What cannot be queried

The query compiler refuses an encrypted column in a **condition**, as a **group
key**, inside an **aggregate** or as a **sort term** — an `order by` clause or a
page request's sort — with `query_sentence_compiler.encrypted_column` naming the
entity and the field: the query would otherwise compare ciphertext and silently
match nothing, or order rows by chance. Compare its blind index instead. A condition on the
blind index admits equality and `is in`; an ordering, a range or a `like` over
it is meaningless, because the index preserves equality and nothing else.

Nothing can sort encrypted values in the database, so a result that must be
sorted by one is sorted after it is read.

### Keys: envelope encryption

Values are encrypted under **data keys**: random 256-bit keys kept in the
data-key table, `tom_encryption_key` (`defaultEncryptionKeyTable`), one row per
key. Each one is stored **wrapped** — itself encrypted — under a
**key-encryption key** that never touches the database, so the table never holds
a usable key and a dump of the database decrypts nothing without it.

| Column | Holds |
| ------ | ----- |
| `key_id` | The key's id: a UUID for an encryption key, `index-<n>` for an index key. Written into every value encrypted under it. |
| `purpose` | `encryption` (`TomDataKeyPurpose.encryption`) or `blindIndex` |
| `state` | `active` for the key new values use, `previous` for a key kept so older values still read (`TomDataKeyState`) |
| `kek_id` | The key-encryption key the row is wrapped under |
| `wrapped_key` | The wrapped key, base64: nonce, sealed key and tag |
| `created_at` | When the key was created |

A `TomDataKeyRecord` is one row; a `TomDataKeyStore` keeps them —
`TomSqlDataKeyStore` in a SQL data source, `TomMemoryDataKeyStore` in memory for
tests and for a single process whose encrypted data is in memory too.
`TomSqlDataKeyStore('main')` resolves the data source by name on every call and
creates the table on first use in each data source it reaches; with
`createSchema: false` the deployment applies the reference migration
`example/object_persistence/migrations/main/tomcore/[1]-create_tom_encryption_key.sql`
(or its `migrations_postgresql` form) instead. `TomSqlDataKeyStore.over(datasource)`
binds one data source once. A name that resolves to no registered data source
raises `field_encryption.no_datasource`.

A `TomKeyEncryptionKey` wraps and unwraps; the wrapping binds the data key's id,
so a wrapped key cannot be passed off as another's. `TomAesKeyEncryptionKey` is
a 256-bit AES key held by the application, wrapping with AES-GCM — built from 32
bytes, or from their base64 with `TomAesKeyEncryptionKey.base64(id, key)`. A key
with an empty id, an id longer than 128 characters, other than 32 bytes or
undecodable base64 raises `field_encryption.invalid_kek`. The key itself comes
from wherever the deployment keeps secrets — typically a `secret:` reference
resolved from Vault, AWS Secrets Manager or Azure Key Vault, which
`TomFieldEncryption.configure` resolves through the registered providers (see
[configuration.md](configuration.md#secret-references)).
A key that never leaves a key-management service — AWS KMS, Vault Transit,
Azure Key Vault — is another `TomKeyEncryptionKey`; see [Keys held by a
key-management service](#keys-held-by-a-key-management-service).

A `TomFieldKeyring` holds the key-encryption keys — the first is the
**primary**, which wraps every data key it creates; the others only unwrap — and
caches the unwrapped data keys in memory:

- `load()` reads the data keys of the current context, unwraps the ones not yet
  cached and, when the table has none, creates the first encryption key and the
  first index key, `index-1` (`TomFieldKeyring.indexKeyId`). Two nodes creating
  `index-1` at once insert one row. A data key wrapped under a key-encryption
  key the keyring was not given, or one that does not unwrap under it, raises
  `field_encryption.unknown_kek`.
- `activeKeyId()`, `indexKeyIdInUse()` and `indexKeyIds()` answer the active
  encryption key, the active index key, and every index key with the active one
  first; `records()` the rows as stored; `materialOf(id)` an unwrapped key, or
  `null` when it is not cached.
- `ensure(ids)` reads the table again when one of `ids` is not cached, and
  answers the ids still unknown — how a node reads a value written under a key
  another node created.
- Every `refreshInterval` (five minutes by default) the keyring reads the table
  again, which is how a node learns of a rotation another node made.

### Installing a keyring

A server installs one from the [`fieldEncryption`
configuration](configuration.md#field-level-encryption) when it starts. Without
it, `TomFieldEncryption.install` does the same in code:

```dart
await TomFieldEncryption.install(
  TomFieldKeyring(
    store: TomSqlDataKeyStore('main'),
    keys: [TomAesKeyEncryptionKey.base64('kek-2026', base64Key)],
  ),
);
```

`install` loads the keys of the current context; `TomFieldEncryption.keyring`
answers the installed keyring, and `reset()` removes it and restores the
defaults (for tests). `TomFieldEncryption.configure(settings)` builds and
installs one from a `fieldEncryption` map. With no keyring installed, a write of
an encrypted column — or a read of one holding ciphertext — fails with
`field_encryption.not_configured` rather than storing plaintext.

### Keys held by a key-management service

Each entry of the configuration's `keys` list has an `id` and a `kind`. The kind
`aes` (`TomFieldEncryption.aesKeyKind`) is the default and is built in: an
application-held `TomAesKeyEncryptionKey`, whose entry carries `key` — the
base64 of 32 bytes or a `secret:` reference to it. Any other kind is a key that
never leaves a key-management service: `configure` hands the whole entry to the
`TomKeyEncryptionKeyFactory` a package registered for that kind, and the factory
builds the `TomKeyEncryptionKey`:

```dart
typedef TomKeyEncryptionKeyFactory =
    Future<TomKeyEncryptionKey> Function(String id, Map<String, Object?> settings);

TomFieldEncryption.registerKeyKind('my-hsm', (id, settings) async =>
    MyHsmKeyEncryptionKey(id, slot: settings['slot']! as String));
```

`TomFieldEncryption.registerKeyKind(kind, factory)` registers a kind; a kind
registered again has its factory replaced, and `aes` or an empty kind is
refused with `field_encryption.config.invalid`. `TomFieldEncryption.keyKinds`
lists the registered kinds besides `aes`. An entry whose kind nothing
registered stops `configure` with `field_encryption.config.invalid`, naming the
kinds that are known. A factory registers before `configure` runs — before
`TomServer.start` applies `fieldEncryption`.

[`tom_core_secrets`](../../../core_extension/tom_core_secrets/README.md)
registers three kinds, each with one call from its library, and reaches the
service with the credentials of the matching secrets provider:

| Kind | Registered by | Wraps with |
| ---- | ------------- | ---------- |
| `aws-kms` | `TomAwsKmsKeyEncryptionKey.register()` (`aws.dart`) | AWS KMS `Encrypt` / `Decrypt`, the data key id bound as the encryption context |
| `vault-transit` | `TomVaultTransitKeyEncryptionKey.register()` (`vault.dart`) | HashiCorp Vault Transit `encrypt` / `decrypt`, the data key id bound as associated data |
| `azure-keyvault` | `TomAzureKeyVaultKeyEncryptionKey.register()` (`azure.dart`) | Azure Key Vault `wrapkey` / `unwrapkey`, the data key id bound into the wrapped bytes |

```dart
import 'dart:io';

import 'package:tom_core_secrets/tom_core_secrets.dart';

TomAwsKmsKeyEncryptionKey.register(environment: Platform.environment);
TomVaultTransitKeyEncryptionKey.register(environment: Platform.environment);
TomAzureKeyVaultKeyEncryptionKey.register(environment: Platform.environment);
```

One entry per kind:

```yaml
fieldEncryption:
  datasource: main
  keys:
    - id: kms-2026
      kind: aws-kms
      kmsKeyId: alias/field-keys     # required: key id, ARN or alias
      region: eu-central-1           # default: secrets.aws / AWS_REGION
```

```yaml
fieldEncryption:
  datasource: main
  keys:
    - id: transit-2026
      kind: vault-transit
      keyName: field-keys            # required: the Transit key
      mount: transit                 # default
```

```yaml
fieldEncryption:
  datasource: main
  keys:
    - id: keyvault-2026
      kind: azure-keyvault
      keyName: field-keys            # required: the vault key
      algorithm: RSA-OAEP-256        # default; RSA-OAEP; A256KW on a Managed HSM
```

The settings of each kind, the credentials and the failures
(`secrets.kek.config.invalid`, `secrets.kek.failed`) are in the package's
guides: [AWS KMS](../../../core_extension/tom_core_secrets/doc/aws_secrets.md#key-encryption-keys-for-field-encryption),
[Vault Transit](../../../core_extension/tom_core_secrets/doc/vault_secrets.md#key-encryption-keys-for-field-encryption)
and [Azure Key Vault](../../../core_extension/tom_core_secrets/doc/azure_secrets.md#key-encryption-keys-for-field-encryption).

**Moving to a service key** is a key-encryption-key rotation: list the service
key first and the application-held AES key after it, restart, and run
`keyring.rewrap()` (in every tenant whose data keys are kept apart). The service
key wraps every data key created from then on, and `rewrap` puts the existing
ones under it; once it has run, the AES key can leave the list, and a node
holding only the service key reads everything:

```yaml
fieldEncryption:
  datasource: main
  keys:
    - id: kms-2026                   # primary: wraps every data key created
      kind: aws-kms
      kmsKeyId: alias/field-keys
    - id: kek-2025                   # unwraps the data keys until rewrap has run
      key: "secret:vault:secret/data/billing#fieldKek"
```

### Rotating keys

Every rotation happens while the application runs, and none of them makes a
stored value unreadable at any point.

| Key | Rotated by | What changes |
| --- | ---------- | ------------ |
| A data key | `keyring.rotateDataKey()` | A key is created and becomes active; the one it replaces turns `previous` and still decrypts. New writes use the new key at once; a [re-encryption pass](#the-re-encryption-pass) moves the old values over. Blind indexes are unaffected. |
| The index key | `keyring.rotateIndexKey()` | The next index key — `index-2`, `index-3`, … — is created and becomes active; the previous one is kept. Saved rows are indexed under the new key at once, and the pass recomputes the rest. `blindIndexCondition` matches every index key meanwhile, so no row goes missing. The numbering makes two nodes rotating at once create one key, not two. |
| A key-encryption key | the new key first in the keyring's list, then `keyring.rewrap()` | Every data key not wrapped under the primary is wrapped again under it; `rewrap` answers how many. No value is touched. Once it has run, the old key-encryption key can leave the list. |

`rotateDataKey` and `rotateIndexKey` answer the id they created. Other nodes pick a rotated key up
within their keyring's refresh interval, or as soon as they read a value naming
it; a value they write under the previous key meanwhile is still readable, and
the next pass rewrites it. A key-encryption key is rotated in configuration —
`keys` lists the new key first and the old one second until `rewrap` has run.

### The re-encryption pass

`TomFieldReencryption` rewrites what is not yet stored the way the keyring wants
it: values under a previous data key, plaintext in an encrypted column, and blind
indexes that are missing or computed under a previous index key.

```dart
final report = await TomFieldReencryption().run();
// TomReencryptionReport(examined 1200, rewritten 37, conflicts 0, failures 0)
```

By default it covers every reflected `@TomDbTable` entity declaring a
`@TomEncrypted` field; `entities:` narrows it, and `batchSize` (200) is how many
rows each statement reads. It reads the rows raw, in primary-key order, and
writes each row that needs it with an `UPDATE` **guarded by the values it
read**: a concurrent save that changed the row in between makes the update
match nothing, and the row is counted as a conflict for the next pass instead of
overwriting the save. A row whose value does not decrypt is skipped and listed.

| `TomReencryptionReport` field | Counts |
| ----------------------------- | ------ |
| `examined` | rows read |
| `rewritten` | rows written: a value moved to the active key, plaintext encrypted, or a blind index filled |
| `conflicts` | rows a concurrent save changed between the read and the write |
| `failures` | one line per row that could not be decrypted, naming the entity, its key and the error key |

Reports add up with `+`, and `toJson()` renders one as JSON-native values. A
pass can always run again; a second one over a converged table rewrites nothing.

`pass.job(schedule: …)` makes the pass a scheduler job, named
`object_persistence.reencrypt` (`tomReencryptionJobName`) unless given another
name, with a one-hour timeout, recovery requested, and the report as the run's
result:

```dart
final scheduler = TomScheduler(
  store: jobs,
  dispatcher: const TomInlineJobDispatcher(),
);
scheduler.register(
  TomFieldReencryption().job(schedule: TomCronSchedule('0 3 * * *')),
);
```

The job uses the isolate's keyring, so it is registered on a scheduler with a
`TomInlineJobDispatcher`; a worker isolate has no keyring.

### Encrypting a column that held plaintext

A column that already holds data is encrypted in four steps:

1. Widen the column to hold ciphertext (see [What is stored](#what-is-stored)),
   and add the blind-index column if the field is looked up.
2. Mark the field `@TomEncrypted` (and the index `@TomBlindIndex`). Saves now
   write ciphertext. While `TomFieldEncryption.acceptPlaintext` is on — the
   default — a stored value that is not ciphertext reads as it is, so the rows
   not yet encrypted keep reading.
3. Run the re-encryption pass. It encrypts every plaintext value and fills every
   blind index.
4. Turn `acceptPlaintext` off (`acceptPlaintext: false` in the configuration).
   A plaintext value then fails its read with `field_encryption.plaintext_refused`,
   so a value written past the repository is noticed rather than served.

### Tenancy

The data keys live in the data source the store names, and
`TomSqlDataKeyStore` resolves it by name on every call, through the tenant
routing. When that data source is one of `TomTenancy.datasources`, a `schema` or
`database` tenant's data keys are kept in that tenant's schema or database —
created there on first use or, with `createSchema: false`, by the migration in
the per-tenant tree — so each tenant's data is encrypted under keys of its own.
Shared tenants share the one table and its keys. The keyring keeps what it read
per data source.

`rotateDataKey`, `rotateIndexKey`, `rewrap` and `load` act on the current
context's keys; a deployment rotating every tenant's runs them in each
(`tenancy.forEachTenant`). The re-encryption pass runs in the current context
and then, when a `TomTenancy` is installed, in every tenant's. See
[tenancy.md](tenancy.md#what-stays-deployment-wide).

### Audit records

The before and after images of a repository's audit record replace the value of
every encrypted field and every blind index with `[encrypted]`
(`TomFieldEncryption.redacted`), so the audit trail records *that* such a field
changed and never becomes a plaintext copy of what the table encrypts.
`TomFieldEncryption.redact(entity, image)` is the replacement; a `null` stays
`null`. See [audit.md](audit.md#the-audit-record).

The values of a `@TomPersonal` field — personal data, declared for the privacy
module — are sealed instead, under a key of the data subject the row names, when
subject keys are installed: the repository hands the audit trail each such
field's subject (`TomPersonalDataModel.sealingSubjects` of the row before and
after) and the trail seals the value, so erasing the subject makes it unreadable
in the trail without changing an entry. An encrypted field is left out of that —
its value is `[encrypted]` already. The cipher is the same one: `TomAesGcm`,
AES-256-GCM with a fresh 96-bit nonce per value, public so field encryption,
key wrapping and the sealing share one implementation. See
[privacy.md](privacy.md#crypto-shredding-in-the-audit-trail).

### How field encryption fails

`TomFieldEncryptionException` (extends `TomServerException`) carries every
failure of this feature; none is client-visible, because each describes the
deployment's keys rather than the caller's input.

| Key | Raised when |
| --- | ----------- |
| `field_encryption.not_configured` | An encrypted column was written, or a ciphertext read, with no keyring installed. |
| `field_encryption.unknown_key` | A stored value names a data key the keyring's table does not hold. |
| `field_encryption.decrypt_failed` | A stored value failed its authentication: it was altered, is malformed, or belongs to another column. |
| `field_encryption.plaintext_refused` | An encrypted column held plaintext while `acceptPlaintext` is off. |
| `field_encryption.unknown_kek` | A data key is wrapped under a key-encryption key the keyring was not given, or does not unwrap under it. |
| `field_encryption.invalid_kek` | A key-encryption key has no id, too long an id, or not 32 bytes; or a keyring was given none. |
| `field_encryption.config.invalid` | The `fieldEncryption` configuration has the wrong shape, or a `keys` entry names a kind no package registered; or `registerKeyKind` was given `aes` or an empty kind. |
| `field_encryption.no_datasource` | The data source a `TomSqlDataKeyStore`, or an entity the pass covers, names is not registered. |

The four `annotation_analyzer.encryption.*` refusals are in
[Marking a field](#marking-a-field), and the query compiler's
`query_sentence_compiler.encrypted_column` (raised from
`query_sentence_compiler.dart`) in [What cannot be queried](#what-cannot-be-queried).

## Grouping and Aggregation

Everything above describes *rows*. A grouped query describes *groups*: rows
collapsed by one or more key columns, with an aggregate value computed per
group.

It is a separate query kind rather than an option on the select because its
**result is a different shape**. A grouped row holds the group keys and the
aggregates the query asked for — a tuple decided by the query, not by any
entity class — so it comes back as a `TomGroupedRow` rather than as `T`:

```dart
Future<List<TomGroupedRow>> findGroupedByQuery(
  TomGroupedSelect query,
  Map<String, Object?> params,
);
```

### The aggregates

Every aggregate is a `TomAggregate`, which *is* a `TomOperator` — so it composes
with the ordinary predicate factories, which is what makes `HAVING COUNT(*) > 3`
expressible without a second expression language.

| Builder factory | SQL | Dart value type |
| --------------- | --- | --------------- |
| `countAll(alias)` | `COUNT(*)` | `int` |
| `countOf(value, alias, {distinct})` | `COUNT([DISTINCT] v)` | `int` |
| `sum(value, alias, {distinct})` | `SUM([DISTINCT] v)` | `double` |
| `avg(value, alias, {distinct})` | `AVG([DISTINCT] v)` | `double` |
| `minInt` / `maxInt` | `MIN(v)` / `MAX(v)` | `int` |
| `minDouble` / `maxDouble` | `MIN(v)` / `MAX(v)` | `double` |
| `minText` / `maxText` | `MIN(v)` / `MAX(v)` | `String` |
| `minDateTime` / `maxDateTime` | `MIN(v)` / `MAX(v)` | `DateTime` |

`countAll` and `countOf` are not the same question: `COUNT(*)` counts rows,
`COUNT(column)` counts non-null values, so a group whose column is entirely
`NULL` yields the row count from the first and `0` from the second.

`sum` and `avg` always widen to `double` — SQL widens a sum to an exact-numeric
type, and widening once here keeps the Dart type predictable instead of
dialect-dependent. `min`/`max` are split by type instead, because an extremum is
one of the operand's own values and so preserves the column's type on both
sides.

Every aggregate carries an **alias**. Unlike an entity projection there is no
column metadata to map results back by, so the alias is the name the value comes
back under. It is validated at construction against `^[A-Za-z_][A-Za-z0-9_]*$`,
and refused with `grouped_query.aggregate.invalid_alias`:
an alias is written into the statement text rather than bound, so it is the one
injection surface a grouped query adds, and it is closed where it opens. An
aggregate whose value type the result mapper cannot materialise is refused at
construction too, with `grouped_query.aggregate.unmappable_value_type`.

### Building one

Through the builder:

```dart
// SELECT title, COUNT(*) AS n, SUM(priority) AS total
//   FROM task WHERE priority >= :floor
//   GROUP BY title HAVING COUNT(*) > 2 ORDER BY total DESC
final query = TomGroupedSelect(
  [Task],
  query: gte(priorityCol, p<TomDbInt>('floor')),
  groupBy: [titleCol],
  aggregates: [countAll('n'), sum(priorityCol, 'total')],
  having: gt(countAll('n'), intOp(2)),
  orderBy: ['total'],
  ascending: false,
);
final groups = await repo.findGroupedByQuery(query, {'floor': 1});
```

Or as a query sentence, using the fourth sentence kind, `group`:

```text
group count ( * ) as total , sum ( priority ) as weight over title
  by priority >= :floor having total > 2 order by total desc
```

The projection is a comma-separated list of `<fn> ( <arg> ) as <alias>`, with
`count ( * )` for the row count and a leading `distinct` inside the parentheses
for `count`/`sum`/`avg`. `over <fields>` names the group key — **omit it to
aggregate the whole filtered set into exactly one row**. `top N` / `first N` and
`skip M` / `offset M` work as they do on `find`, so a grouped result pages too.

The sort names *projection aliases* — a group column's declared field name or an
aggregate's alias — not arbitrary entity fields. Ordering a grouped result by an
ungrouped column has no meaning, and the constructor rejects it with
`grouped_query.select.order_by_not_projected` rather than letting the database
pick a behaviour. The constructor refuses three other shapes as well:

| Refused | Key |
| ------- | --- |
| no aggregate at all — that is a `DISTINCT` select, which `TomSelect` already expresses | `grouped_query.select.no_aggregates` |
| one result-column name projected twice, by a group column or an alias | `grouped_query.select.duplicate_alias` |
| a group column of a type the result mapper cannot materialise | `grouped_query.select.unmappable_group_column` |

The sentence form adds the projection's own grammar:

| Refused | Key |
| ------- | --- |
| a word in the projection that is not an aggregate function | `query_sentence_compiler.parse_aggregates.unknown_function` |
| a function with no argument inside its brackets | `query_sentence_compiler.parse_aggregates.missing_argument` |
| `as` with no alias after it | `query_sentence_compiler.parse_aggregates.missing_alias` |
| any other token where the projection expects a bracket, `as` or a comma | `query_sentence_compiler.parse_aggregates.unexpected_token` |
| `*` as the argument of anything but a plain `count` | `query_sentence_compiler.parse_aggregates.star_only_for_count` |
| `distinct` inside `min` or `max`, where the extreme of a set is the extreme of its distinct values | `query_sentence_compiler.parse_aggregates.distinct_not_supported` |
| `min` or `max` over a column type with no typed extremum | `query_sentence_compiler.parse_aggregates.unsupported_min_max_column` |
| `over` with no field after it | `query_sentence_compiler.compile_grouped.empty_over_clause` |
| `having` with no predicate after it | `query_sentence_compiler.compile_grouped.empty_having` |

### Reading the result

`TomGroupedRow` is a keyed holder with typed accessors:

```dart
for (final row in groups) {
  final title = row.stringValue('title');  // the group key, under its field name
  final n     = row.intValue('n');
  final total = row.doubleValue('total');
}
```

- Group keys come back under the column's **declared field name**; aggregates
  under their **alias**. `row.keyOf(titleCol)` resolves the former from the
  column itself.
- `intValue` / `doubleValue` / `stringValue` / `boolValue` / `dateTimeValue`
  coerce from whatever the driver handed over. `value(alias)` returns it raw.
- An aggregate node reads its own value: `total.read(row)` returns a `double?`
  without naming the type twice.
- Reading an alias the query did not project **throws**
  `TomQuerySyntaxException` with `grouped_query.row.unknown_alias`. An accessor
  asked for a type outside the mappable set is
  `grouped_query.row.unsupported_value_type`, and a value that does not convert
  to the type asked for is `grouped_query.row.value_conversion_failed`. Returning `null` would be indistinguishable from
  "this group had no value", which is a real and different answer — an aggregate
  over an all-null column is `null`, and a typo must not look like one.

`TomGroupedRow` is also directly consumable by the export module's tabular
projection (see [`export.md`](export.md)), which is the usual destination for a
grouped result.

### `WHERE` filters rows, `HAVING` filters groups

The two predicates stay separate all the way down to the dialect, for the same
reason they are separate in SQL: `WHERE` runs before aggregation and `HAVING`
after it, so ANDing them together would change the meaning of both.

`HAVING` therefore addresses the **projection**, by alias, while the `by`
predicate addresses **columns**. A `HAVING` on a bare column that is neither a
group key nor inside an aggregate is rejected with
`grouped_query.select.having_on_ungrouped_field` — such a predicate has many
values per group and no rule for picking one, and databases differ on whether
they refuse it or silently choose a row. Catching it in the query layer makes
the behaviour identical on every dialect.

### Authorization

Both server-side controls apply, and the column control applies *differently*
here than on the row-returning paths:

- **Row scope (C-3)** — see [Row Scopes](#row-scopes) — is ANDed into the
  `WHERE`, never into `HAVING`: it decides which rows the principal may see, so
  it must apply before aggregation. Filtering groups afterwards would still have
  counted the hidden rows.
- **Column rights (C-4)** — see [Column Authorization](#column-authorization) —
  cause the query to be **refused outright** rather than
  masked. The row paths null a forbidden column out of each returned entity; a
  grouped query cannot, because by the time rows exist the column has already
  been collapsed into a key or folded into an aggregate. Nulling the result would
  not undo the leak — a `COUNT(*)` per masked group still discloses the masked
  values' distribution. A grouped query naming a masked column therefore raises
  `TomColumnAuthorizationException` with `crud_repository.grouped.masked_column`
  before it reaches the database.

### Value types across drivers

The value type is the one the **projection declared**, not the one the driver
happens to hand back. `TomSqlDatasource.mapGroupedRow` reads each alias as the
declared type, which is the only type information a grouped row has.

That mapping is load-bearing for `SUM` and `AVG`. MariaDB types `SUM(<int
column>)` as `NEWDECIMAL`, and `mysql_client` converts a column to `double` only
from a fixed whitelist of protocol types that does not include it — asking the
driver for a `double` there *throws* rather than widening. The driver therefore
reads numeric columns as raw text and parses them; the text form is lossless, so
nothing is given up. A caller sees a `double` either way and does not need to
know. The same applies to every entity-mapping path, not only to grouped rows:
`DECIMAL` is the correct SQL type for money, so a plain entity with a money
column meets the identical gap on its first select. See
[`datasources.md`](datasources.md#reading-rows) for the shared read
helpers and for the rule governing an `int`-declared field over a `DECIMAL`
column (exactly integral values are read; fractional ones are refused by name,
never truncated).

The consequence worth remembering: **`SUM` over an integer column is a `double`,
not an `int`.** Read it with `doubleValue`, and do not reach past the accessors
for a raw `as int`.

## How Metadata Is Resolved

`TomAnnotationAnalyzer` reads the `tomReflector` `ClassMirror` of an entity and
translates its annotations into a `TomTypePersistenceInfo` and a list of
`TomColumnInformation` (one per annotated field). A `TomColumnInformation` also
provides reflection-backed `getVariableValue` / `setVariableValue` accessors
that the repository uses to read and write entity fields. A type the analyzer
cannot resolve raises `TomAnnotationAnalyzerException`, or its syntax subclass
for an annotation written wrongly:

| Refused | Key |
| ------- | --- |
| a type that is not registered with `tomReflector` | `annotation_analyzer.analyse_persistent_type.mirror_not_found` |
| reflecting the type threw | `annotation_analyzer.find_mirror.reflection_failed` |
| a registered type that is not a class, so carries no persistence annotations | `annotation_analyzer.find_mirror.not_a_class` |
| a type without `@TomDbTable` | `annotation_analyzer.analyse_persistent_type.table_not_found`, or `annotation_analyzer.get_persistent_columns.no_table_info` when reached through the column list |
| `@TomDbColumn` on a declaration that is not a field | `annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable` |
| `@TomReference` on a declaration that is not a field | `annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable_for_reference` |

Every resolution is memoised per entity type, and the memo is *shared*: two
callers asking for the same entity receive the same list of the same objects,
for the life of the isolate. Sharing is what makes the metadata free after the
first use, and it is also what makes any writable path into it dangerous — an
assignment to a column's mapped name would change what every later query on that
entity compiles to, silently, and nowhere near the code that made the mistake.
So there is no such path: `TomColumnInformation`'s fields are `final`, the
column lists are handed out unmodifiable, and the memo maps themselves are
private.

Discarding a resolution is therefore all-or-nothing: `TomAnnotationAnalyzer
.reset()` empties all six memos, and nothing else can empty any of them. The
memos are derived from one another — the columns come from the mirror, the row
scope and the two column subsets come from the columns — so clearing a subset
would leave the rest describing an entity that no longer exists. A server never
calls it, because an entity's declaration is fixed for the run; a test that
re-registers a fixture type it has already analysed, under a different mapping,
is the case that does.

The mirror lookup at the front of that chain distinguishes *not registered* from
*could not be reflected*, and the distinction is the difference between a
one-line fix and an afternoon. `findMirror` answers `null` for one cause only —
the reflector holds no mirror for the type, which it says by raising
`NoSuchCapabilityError` — because callers legitimately ask about types that
carry no persistence annotations at all. Every other failure is thrown as
`TomAnnotationAnalyzerException` carrying the original as `rootException`.

Two of them are worth naming, because both would otherwise arrive disguised as
"it is not in `tomReflector`" and send the reader to the entity's annotations and
its generated file, neither of which is at fault. If `initializeReflection()` was
never called, *every* type looks unregistered; the reflection library's own error
names the missing call, and that sentence — the actual fix — survives into the
wrapped exception. If the name resolves to something that is not a class
(`dynamic` and `void` are registered with every type-capable reflector, and an
erased generic parameter arrives here as `dynamic`), the message says so rather
than accusing the reflection setup of a gap it does not have. A thrown lookup
memoises nothing, so the second call reports the fault again instead of reading
back a `null` the first call refused to give.

A `null` that *is* memoised, though, has to be read back as one. `findMirror`,
`findTable`, `findDataScope` and `getPersistentColumns` each answer `null` for an
ordinary reason, and each stores that `null` beside the real answers — so
`containsKey` true with a null value is a designed state of all four maps, and a
cache-hit path that read the entry as non-nullable would answer the first call
correctly and throw on the second, out of the memo.

For the same reason no caller null-asserts one of these lookups.
`findTable(type)!` is a null check written as an expression: where the caller has
established that the type is mapped, it records that fact in a form that stops
being true as soon as the branch above it moves; where it has not, it reports
`Null check operator used on a null value` from inside a static cache, in code
that runs for every entity, naming neither the type nor the annotation that was
missing. A caller that knows it holds an entity asks `analysePersistentType`,
which returns a non-nullable `TomTypePersistenceInfo` or names precisely what is
absent; a caller that is asking *whether* it does reads the lookup into a local
and tests it. Both halves are pinned by
`test/annotation_analyzer_null_memo_test.dart`, the second by reading `lib/`:
the assertions worth guarding against are the ones no runtime test can reach,
because the branch that makes them correct today is exactly what a later change
moves.

`familyOf` reduces one column to the `TomSqlTypeFamily` it is **stored** in — a
JSON column is text whatever its types, an explicit `columnType:` decides next
(a `TomDbType` box such as `TomDbString`, or a Dart type such as `bool`), and
only failing both does the Dart type (`dartType:`, else the field's own) stand
in. One table maps every one of those spellings, observable `Tom…` wrappers
included. An explicit type that names no family is `unknown` rather than the
field's type: the entity stated a storage type, and substituting another is the
disagreement this resolver exists to prevent. `unknown` is compatible with
everything in the convergence check, because a gap in the reader's knowledge
must not be reported as a defect, and the query compiler refuses it, naming the
annotation.

It is homed here, beside the annotations it reads, and it is the only answer:
the query compiler, the schema-convergence check
([`db_migration.md`](db_migration.md#schema-convergence)) and the reflected
export projection ([`export.md`](export.md#columns-derived-from-the-entity)) all
read it, and `test/query_sentence_column_test.dart` holds the compiler to it
over every reflected column of its fixture. Note what it does *not* describe —
the Dart value a getter returns; a caller that cares about that reads
`dartTypeOf` as well, which is what the export projection does.

`@TomDbColumn` takes no type parameters, and that is deliberate. An annotation
reaches the persistence layer through reflection, which reconstructs it without
type arguments, so a `TomDbColumn<int, TomDbBool>` would have been read back as
if neither argument were written. `columnType:` and `dartType:` are fields, and
survive.

## SQL Dialects

Every operator renders itself through a `TomStandardSqlDialect` (see
`doc/datasources.md`). A driver subclasses the dialect to override any fragment.
A `TomSqlDatasourceRepository` renders through its data source's dialect
(`sqlDialect` defaults to `datasourceInfo.datasource.sqlDialect`), so one
repository class serves MariaDB and PostgreSQL alike — which is how every
repository in the package's own test fixtures is declared.
`MariadbRepository` pins `MariadbSqlDialect` and is therefore for MariaDB only;
on PostgreSQL extend `TomSqlDatasourceRepository` directly, or override
`sqlDialect`.

A repository is **constructed, not discovered**: `MariadbRepository<User,
int>([User])`, as every example above does. There is no registry keyed on a
data-source type name, and one would not help — the type arguments are what make
a repository the repository *for an entity*, and a string cannot supply them.

## Verification

Three suites carry the module's name: two split by whether a server is needed,
and one pinning the error vocabulary.

`test/object_persistence_error_keys_test.dart` pins the module's error vocabulary: each case reaches a raise with a real input and asserts the exact key, so a key the module stops raising, or raises for a different condition, fails by name. None needs a database.

`test/object_persistence_test.dart` always runs, and reaches most of the module:
the operator tree's literals, comparisons, parameters, typed column references
and compound predicates, `BETWEEN` arity, the persistence annotations and
`TomColumnInformation`, the save SQL builders,
`TomAnnotationAnalyzer.getPersistentColumns`, the C-7 injection neutralisation,
the dialect's `objectOp` dispatch, the lifecycle overrides of
[Lifecycle work](#lifecycle-work) — run end to end against a scripted data
source, so the ordering claims are asserted and not merely written down — and
that a repository is constructed rather than discovered.

`test/object_persistence_db_test.dart` is tagged `db` and skips when no server
is reachable, so the default run stays green without one. It covers CRUD through
a repository against a real database — MariaDB or PostgreSQL, whichever the DB
suites run against — which is the half that cannot be settled by
reading generated SQL — including the one claim in
[Matching literal text](#matching-literal-text) that is about what the
*database* does with a pattern rather than about what the query says.

The orphan sweep is covered beside the store it sweeps.
`test/deduplicating_blob_store_test.dart` runs it over three content stores, with
the second question before a delete, its refusals and `TomRepositoryBlobReferences`
asking a plain column in batches and a graded one key by key;
`test/deduplicating_blob_store_db_test.dart`, tagged `db`, runs it over a real
repository's file columns. `example/file_storage/deduplicating_store_example.dart`
shows a sweep deleting the one key no row names.

`test/query_sentence_options_test.dart` asserts the matrix in
[Which kind takes which option](#which-kind-takes-which-option) cell by cell —
each permitted option reaches the rendered SQL, each refused one raises its
documented key — and reads the table out of this document, so the guide, the
compiler and the suite cannot drift apart without one of them failing.

`test/query_sentence_declined_words_test.dart` runs both halves of
[Words this grammar does not have](#words-this-grammar-does-not-have): that each
declined word really is refused, and that the form named in its place really
renders what the table says. It reads the table back, so a row added there
without a test, or a word promoted to a keyword, fails rather than drifts.

`test/query_associations_test.dart` renders
[Filtering on an association](#filtering-on-an-association) and the
[Subqueries](#subqueries) nodes without a database — the correlated `EXISTS`,
`is empty`, the refusals by key, the opaque walk and the soft-delete test — and
`test/query_associations_db_test.dart` runs them on MariaDB and PostgreSQL:
an owner answered once however many associated rows match, a term combined with
the owner's columns and with `or`, `is empty` / `is not empty`, a count and a
delete by an association, a delete that binds no parameter, and the builder's
`IN (SELECT …)`, `NOT IN`, correlated `EXISTS` and `NOT EXISTS`.

```bash
dart run example/object_persistence/subquery_example.dart
```

`example/object_persistence/subquery_example.dart` builds a correlated
`EXISTS`, its `NOT EXISTS` and an `IN (SELECT …)` over the example entities in
five steps without a database, checking the SQL each renders and that the
enclosing tree references none of the subquery's columns; `test/examples_test.dart`
runs it.

Several neighbouring surfaces are covered by suites named after the type rather
than the module, and are named where each is described:
`crud_repository_exceptions_test.dart` and
`crud_repository_delete_counts_test.dart` for the repository's refusals and
counts, `reference_query_test.dart` and `reference_association_db_test.dart` for
`@TomReference`, `data_scope_test.dart` and `column_authorization_test.dart` for
row and column authorization, and `persistence_metadata_sharing_test.dart` for
the resolution described in [How Metadata Is Resolved](#how-metadata-is-resolved).

```bash
dart run example/object_persistence/object_persistence_example.dart
```

`example/object_persistence/object_persistence_example.dart` runs the real
surface in seventeen steps rather than describing it — mapping an entity,
compiling the four sentence kinds, grouping and aggregation, paging, column
authorization, `LIKE`-pattern escaping, and the `TomQueryBuilder` DSL every
sentence compiles down to, each with its refusals. The refusals are most of what the module has to say: a
query it accepts is one you would have written anyway, so what is worth showing
is where it stops you. Its entities live in
`example/object_persistence/object_persistence_entities.dart`. Every step checks
its own result, and `test/examples_test.dart` runs it.

[Optimistic Locking](#optimistic-locking) is covered twice.
`test/optimistic_locking_test.dart` needs no database: which fields may be the
version, the versioned `UPDATE` and its bind names, the values a save binds and
the refusals a scripted data source's `0`-row answer produces, and the
migration shapes the convergence check accepts and reports.
`test/optimistic_locking_db_test.dart`, tagged `db`, runs it against a live
database — MariaDB or PostgreSQL —
two saves of one loaded row with the second refused, six saves of one row at
the same instant with exactly one winning, a refused editor reloading and
saving on top of the winner, a versioned delete, and a table that gains the
column through a migration, its existing row loading at version `0`.

```bash
dart run example/object_persistence/optimistic_locking_example.dart
```

`example/object_persistence/optimistic_locking_example.dart` walks the same
decisions without a database, checking each result, and
`test/examples_test.dart` runs it.

[Field-Level Encryption](#field-level-encryption) is covered twice.
`test/field_encryption_test.dart` needs no database: the cipher and its stored
form — a round trip, two encryptions of one value differing, a value moved to
another column or altered refusing to decrypt, plaintext accepted until it is
not, `storedLength` covering what is stored — the envelope a first load creates
and the key-encryption keys it refuses, the rotation of a data key, of the index
key and of a key-encryption key, a second keyring reading a key another created,
blind indexes and the lookup condition across an index-key rotation, audit
redaction, and the refusals of the analyzer, the query compiler and the
configuration. `test/field_encryption_db_test.dart`, tagged `db`, runs it
through a repository against a live database — MariaDB or PostgreSQL: values
stored as ciphertext and read as plaintext, a lookup by blind index, a data-key
rotation re-encrypted by the pass as a scheduler job while reads go on, an
index-key rotation found by the lookup before and after the pass, a plaintext
column encrypted and indexed by the pass, and a keyring installed from
configuration over the data-key table. `test/framework_schema_test.dart`
converges the reference migration of `tom_encryption_key` with
`encryptionKeyTable`.

```bash
dart run example/object_persistence/field_encryption_example.dart
```

`example/object_persistence/field_encryption_example.dart` walks the feature in
ten steps without a database, over the in-memory data-key store: the data keys
a first load creates, a value stored and read, the additional authenticated data
refusing a moved value, the lookup condition, a data-key, index-key and
key-encryption-key rotation, audit redaction, the refused query, and plaintext
read until it is refused. Its entity, `ExamplePatientRecord`, lives in
`example/object_persistence/object_persistence_entities.dart`. Every step checks its own result, and `test/examples_test.dart`
runs it.

[Entity Lifecycle](#entity-lifecycle) is covered twice.
`test/entity_lifecycle_test.dart` needs no database: the annotations read back,
the `includingDeleted` zone, the `TomUpdate` a soft delete renders and its bind
order, a change's JSON form, and when a write is observed.
`test/entity_lifecycle_db_test.dart`, tagged `db`, runs it through a repository
against a live database — MariaDB or PostgreSQL: a deleted row hidden from every
read and kept, every delete path soft, a restore and a purge, a soft delete
version-checked, a delete cut to a window, the history of updates, deletes and a
restore with the principal that made them, a rolled-back write leaving no
history, the hooks in order with `beforeSave` changing the entity and vetoing
it, a throwing `afterSave` rolling the write back, change events of every kind,
and a change listener's outbox row committing and rolling back with the change.

```bash
dart run example/object_persistence/entity_lifecycle_example.dart
```

`example/object_persistence/entity_lifecycle_example.dart` walks the feature in
six steps without a database: the declarations read back, the history table's
own columns, the `includingDeleted` zone, a listener making a write observed, a
change listener hearing its entity with an encrypted field redacted, and the
change as JSON. Every step checks its own result, and `test/examples_test.dart`
runs it.

[Tenant-Owned Rows](#tenant-owned-rows) is asserted by
`test/tenancy_db_test.dart`, tagged `db`: two tenants writing and reading
through one repository under each of the three isolation models, the tenant
filled on insert, a foreign tenant refused, and the rows landing in the shared
table, in each tenant's schema or in each tenant's database.

## Core Components

- **Annotations** — `TomDbTable`, `TomDbColumn`, `TomEntityId`, `TomReference`,
  plus `TomDartType`.
- **`TomVersion` + `TomOptimisticLockException`** — the version field that turns
  on optimistic locking, and the refusal of a save or delete whose version has
  moved. See [Optimistic Locking](#optimistic-locking).
- **`TomColumnInformation`** — resolved per-field metadata + reflection accessors.
- **`TomRepository` / `TomSqlDatasourceRepository` / `MariadbRepository`** — the
  CRUD/query contract and its SQL/MariaDB implementations;
  `TomSqlDatasourceRepository.upsert` / `saveByKey` / `upsertBlocker` write by a
  unique business key (see [Upserting by a unique key](#upserting-by-a-unique-key)).
- **`TomQuerySentenceCompiler`** — query-sentence parser, including the
  association terms it compiles to a correlated `EXISTS`.
- **`TomSubquery` + `TomExists` + `TomInSubquery`** — a subquery over entity
  types and the two predicates that test it. See [Subqueries](#subqueries).
- **`TomPageRequest` + `TomSortField` + `TomSortDirection`** — the caller-facing
  row window (offset, limit) and its ordered, per-field sort terms.
- **`TomQueryBuilder` + the operators** (`Eq`, `Lt`, `Like`, `In`, `Between`,
  `And`, `Or`, literals, `Parameter`, the `*Col` references) — the expression
  tree and its dialect-rendered SQL.
- **`TomAggregate` + `TomGroupedSelect` + `TomGroupedRow`** — the aggregation
  nodes (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`), the grouped sentence
  and its result shape.
- **`TomAnnotationAnalyzer`** — reflection-based metadata resolver, including
  `findDataScope` / `autoScopeFor` and the `resourceScopeInputTables` guard.
- **`TomTenantOwned`** — marks a tenant's entity; the repository ANDs the
  tenant predicate into every read and checks the tenant on every write.
- **`TomDbScope` + `TomDataScopeRegistry` + `TomDataScope`** — the row-scope
  declaration, its named resolvers (read and write, sync and async), and the
  bound-parameter predicate they render. `TomResourceScopeSource` is the hook the
  authorization module installs behind the `resource` kind;
  `TomDataScopeException` signals an unregistered kind and
  `TomDataScopeAuthorizationException` a refused write.
- **`TomColumnAuthorization` + `TomRowColumnAuthorization`** — the column-grade
  control: read masking, the write partition (`TomColumnWriteDecision`) and its
  refusal `TomColumnAuthorizationException`, plus the per-row resolvers
  (`TomRowColumnAuthResolver`) the file operations consult.
- **`TomFileReference` + `TomFileReferenceKeys` + `TomFileRepository`** — the
  file-column declaration, the store resolution and key scheme it implies, and
  the five-method surface (`findById`, `saveFile`, `openFile`, `describeFile`,
  `clearFile`) that moves the bytes.
- **`TomBlobOrphanSweep` + `TomRepositoryBlobReferences`** — the sweep deleting
  the keys of a deduplicating blob store that no row refers to, and the reading
  of a repository's file columns it asks (`TomBlobReferenceSource`), reporting a
  `TomBlobOrphanSweepReport`. See
  [Sweeping files no row refers to](#sweeping-files-no-row-refers-to).
- **`TomEncrypted` + `TomBlindIndex` + `TomFieldEncryption`** — the encrypted
  field, its blind index, and the cipher, the lookup
  (`blindIndexCondition`), raw reads and audit redaction the repository and the
  data source call. **`TomFieldKeyring`** holds the data keys a
  `TomDataKeyStore` keeps wrapped under a `TomKeyEncryptionKey`, and rotates
  them; **`TomFieldReencryption`** rewrites what a rotation or a plaintext
  column left behind, reporting a `TomReencryptionReport`; every failure is a
  `TomFieldEncryptionException`; **`TomAesGcm`** is the cipher, shared with the
  privacy module's sealing of audit values. See [Field-Level Encryption](#field-level-encryption).
- **`TomSoftDelete` + `TomHistory` + `TomEntityLifecycle`** — the soft-delete
  and history declarations, and the registry of `TomEntityListener` hooks and
  `TomEntityChangeListener`s told of every `TomEntityChange`; `historyOf`
  answers `TomHistoryEntry` versions read through `TomHistoryMeta`, and a
  declaration the repository cannot carry out is a
  `TomEntityLifecycleException`. See [Entity Lifecycle](#entity-lifecycle).

## Not Yet Implemented

The first three entries are about [Field-Level Encryption](#field-level-encryption).

- **The key-encryption key is held by the application.**
  `TomAesKeyEncryptionKey` is the only `TomKeyEncryptionKey`: its key bytes are
  read into the process, usually from a secret store. A key-encryption key that
  never leaves a key-management service — AWS KMS, Azure Key Vault keys,
  HashiCorp Vault Transit — unwrapping each data key by a call, is not offered.
  `TomKeyEncryptionKey` is the seam one implements, and its `wrap` and `unwrap`
  are asynchronous for that reason.
  <!-- unpinned: absence — no KMS-backed key-encryption key exists -->
- **An observable `TomClass` entity cannot have encrypted fields.** The
  repository encrypts, and the row mapping decrypts, the fields of a reflected
  entity class; the mapping of a `TomClass` holder reads its observable members
  as stored.
  <!-- unpinned: absence — the TomClass row mapping does not decrypt -->
- **A retired data key is never deleted.** A `previous` key stays in the
  data-key table after the re-encryption pass has moved every value off it, and
  nothing reports that a key is no longer named by any value. Deleting one is a
  deployment's own decision — and a value restored from a backup that names a
  deleted key no longer reads.
  <!-- unpinned: absence — no retirement of data keys exists -->

The next two are about [Entity Lifecycle](#entity-lifecycle).

- **There is no after-commit hook.** Every `TomEntityListener` hook and change
  listener runs inside the write's transaction, before it commits. Work that
  must wait for the commit is written to an outbox in the transaction and done
  by whatever reads it.
  <!-- unpinned: absence — no after-commit hook exists -->
- **There is no outbox relay.** A change listener writing an outbox row in the
  change's transaction is the pattern ([Feeding an outbox](#feeding-an-outbox));
  the outbox table, and the relay that reads it and publishes through
  [messaging](messaging.md), are the application's.
  <!-- unpinned: absence — no outbox table or relay exists -->

The last two are about
[Sweeping files no row refers to](#sweeping-files-no-row-refers-to).

- **Only a deduplicating store can be swept.** `TomBlobOrphanSweep` walks the
  ledger of a `TomDeduplicatingBlobStore`; a plain backend records no keys, so a
  blob uploaded into one and never attached is found by nothing in this
  package.
  <!-- unpinned: absence — a plain store keeps no record of its keys -->
- **A row saved during the delete can lose its file.** The sweep asks the
  sources a second time immediately before deleting, which narrows the window to
  the delete itself: a row naming a key older than the grace, saved between that
  question and the delete, is left pointing at nothing.
  <!-- unpinned: untestable — a race between the sweep and a concurrent save -->

What is *not* listed here is a vocabulary of word-operators — *After*,
*Containing*, *StartsWith* and their siblings. They are set in italics because
none of them is code: they are not missing but declined, since a query sentence
is a string and `>` and `%` are directly writable in one. See
[Words this grammar does not have](#words-this-grammar-does-not-have).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `blob_migration.dart`, `blob_orphan_sweep.dart`, `data_scope.dart`, `entity_lifecycle.dart`, `field_encryption.dart` | `Future` and `FutureOr`; `runZoned` and `Zone`, which carry a raw read and `TomSoftDelete.includingDeleted` |
| `dart:convert` | dart | `field_encryption.dart` | `utf8`, `base64` and `base64Url`: a value's bytes, a wrapped key, the stored ciphertext and a blind index |
| `dart:math` | dart | `field_encryption.dart` | `Random.secure`, for nonces and data keys |
| `dart:typed_data` | dart | `field_encryption.dart` | `Uint8List`, the bytes the cipher works on |
| `crypto` | package | `field_encryption.dart` | `Hmac` and `sha256`, the blind index |
| `pointycastle` | package | `field_encryption.dart` | `GCMBlockCipher` over `AESEngine`, the AES-256-GCM cipher values and data keys are sealed with |
| `tom_core_kernel` | package | 10 of 19 files | `tomReflector` (mirrors), the `TomZoned*` date/time types, and `TomJobDefinition` / `TomSchedule` / `TomCommand` / `TomTenantContext` for the re-encryption job and its run in every tenant, and for the orphan-sweep job; `getFromCurrentZone` / `TomPrincipal` and `TomTenantContext` for the principal and tenant a change and a history row record |
| `uuid` | package | `field_encryption.dart`, `file_reference.dart` | `Uuid.v4`, for the file name in a blob key; `UuidV4`, for a data key's id |
| [audit](audit.md) | module | `crud_repository.dart` | `TomAuditAction`, `TomAuditTrail` |
| [configuration](configuration.md) | module | `field_encryption.dart` | `TomSecrets.resolve` and `TomSecretReference.isReference`, which resolve a `secret:` reference to a key-encryption key in `configure` |
| [datasources](datasources.md) | module | 12 of 19 files | `TomDbType`/`TomOperator`/`SqlString`, `TomStandardSqlDialect` / `MariadbSqlDialect` (including the `aggregate`, `aliased`, `groupByClause` and `havingClause` fragments, the `exists`, `inSubquery` and `subquery` fragments, and the `upsert` fragment), `TomQuery` family (`TomSelect` / `TomCount` / `TomDelete` / `TomUpdate` / `TomLiteralSelect`), `TomAggregateFunction`, `TomTypedPersistenceBase`, `TomTypePersistenceInfo`, `TomDataSourceInfo`, `TomPreparedStatement`; `TomFrameworkTable`, `TomSchemaProvisioning` and `sqlInstant` / `parseSqlInstant` for the data-key table |
| [file_storage](file_storage.md) | module | `blob_migration.dart`, `blob_orphan_sweep.dart`, `crud_repository.dart`, `file_reference.dart` | `TomBlobStore`, `TomBlobStoreInfo`, `TomStorageException`, `TomStoredBlob`; `TomDeduplicatingBlobStore` and `tomBlobKeyUnder` for the orphan sweep |
| [little_things](little_things.md) | module | 8 of 19 files | `TomServerException` (base of the module's exceptions) |
| [privacy](privacy.md) | module | `crud_repository.dart` | `TomPersonalDataModel.sealingSubjects`, which names the data subject each `@TomPersonal` value of an audit record is sealed for |
| [tenancy](tenancy.md) | module | `field_encryption.dart` | `TomTenancy.current` and its tenants, which the re-encryption pass runs in |
| [transactions](transactions.md) | module | `crud_repository.dart` | `TomTransactionManager.runInTransaction`, the transaction an observed entity's write runs in |
