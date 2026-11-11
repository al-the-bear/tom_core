# Tom Core Server API Reference: Object Persistence Module

A lightweight, annotation-driven ORM: map a reflected entity class to a database
table, then read and write it through a Spring-Data-style repository. Queries can
be expressed three ways — a parsed *query sentence*, a programmatically built
`TomQuery`, or raw SQL — and all of them render through a pluggable SQL dialect.
The module also carries server-authoritative row-level data scoping (C-3),
column-level access rights (C-4) and field-level encryption at rest.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [Annotations & Metadata](#annotations--metadata)
    - [TomDartType](#tomdarttype)
    - [TomDbTable](#tomdbtable)
    - [TomDbColumn](#tomdbcolumn)
    - [TomEntityId](#tomentityid)
    - [TomVersion](#tomversion)
    - [TomEncrypted](#tomencrypted)
    - [TomBlindIndexNormalization](#tomblindindexnormalization)
    - [TomBlindIndex](#tomblindindex)
    - [TomDbScope](#tomdbscope)
    - [TomTenantTable](#tomtenanttable)
    - [TomReference&lt;TARGET, K, REPO&gt;](#tomreferencetarget-k-repo)
    - [TomColumnInformation](#tomcolumninformation)
  - [Repositories](#repositories)
    - [TomCompositeKey](#tomcompositekey)
    - [TomCountResult](#tomcountresult)
    - [TomRepository&lt;T, K&gt;](#tomrepositoryt-k)
    - [TomSqlDatasourceRepository&lt;T, K&gt;](#tomsqldatasourcerepositoryt-k)
    - [MariadbRepository&lt;T, K&gt;](#mariadbrepositoryt-k)
  - [File References](#file-references)
    - [TomFileReference](#tomfilereference)
    - [TomFileReferenceKeys](#tomfilereferencekeys)
    - [TomFileRepository&lt;T, K&gt;](#tomfilerepositoryt-k)
  - [Query Building](#query-building)
    - [TomQueryBuilder](#tomquerybuilder)
    - [TomQuerySentenceCompiler](#tomquerysentencecompiler)
    - [TomSubquery](#tomsubquery)
    - [TomExists](#tomexists)
    - [TomInSubquery&lt;T&gt;](#tominsubqueryt)
  - [Paging & Sorting](#paging--sorting)
    - [TomSortDirection](#tomsortdirection)
    - [TomSortField](#tomsortfield)
    - [TomPageRequest](#tompagerequest)
  - [Operators & Expressions](#operators--expressions)
    - [TomUnaryOperator&lt;T, R&gt;](#tomunaryoperatort-r)
    - [TomBinaryOperator&lt;T1, T2, R&gt;](#tombinaryoperatort1-t2-r)
    - [Parameter&lt;T&gt;](#parametert)
    - [DbCol&lt;R&gt; and column references](#dbcolr-and-column-references)
    - [Literals](#literals)
    - [Logical & comparison operators](#logical--comparison-operators)
  - [Grouping & Aggregation](#grouping--aggregation)
    - [TomAggregate&lt;R, V&gt;](#tomaggregater-v)
    - [The aggregate nodes](#the-aggregate-nodes)
    - [TomGroupedSelect](#tomgroupedselect)
    - [TomGroupedRow](#tomgroupedrow)
  - [Authorization & Scoping](#authorization--scoping)
    - [TomColumnWriteDecision&lt;C&gt;](#tomcolumnwritedecisionc)
    - [TomColumnAuthorization](#tomcolumnauthorization)
    - [TomRowColumnAuthorization](#tomrowcolumnauthorization)
    - [TomResourceScopeSource](#tomresourcescopesource)
    - [TomDataScopeRegistry](#tomdatascoperegistry)
    - [TomDataScopePredicate](#tomdatascopepredicate)
    - [TomDataScopeBypass](#tomdatascopebypass)
    - [TomDataScope](#tomdatascope)
  - [Analyzer](#analyzer)
    - [TomAnnotationAnalyzer](#tomannotationanalyzer)
  - [Migrating Blobs Between Backends](#migrating-blobs-between-backends)
    - [TomBlobMigration](#tomblobmigration)
    - [TomBlobMigrationReport](#tomblobmigrationreport)
  - [Sweeping Files No Row Refers To](#sweeping-files-no-row-refers-to)
    - [TomBlobReferenceSource](#tomblobreferencesource)
    - [TomRepositoryBlobReferences&lt;T, K&gt;](#tomrepositoryblobreferencest-k)
    - [TomBlobOrphanSweepReport](#tombloborphansweepreport)
    - [TomBlobOrphanSweep](#tombloborphansweep)
  - [Field-Level Encryption](#field-level-encryption)
    - [TomDataKeyPurpose](#tomdatakeypurpose)
    - [TomDataKeyState](#tomdatakeystate)
    - [TomDataKeyRecord](#tomdatakeyrecord)
    - [TomKeyEncryptionKey](#tomkeyencryptionkey)
    - [TomAesKeyEncryptionKey](#tomaeskeyencryptionkey)
    - [TomAesGcm](#tomaesgcm)
    - [TomDataKeyStore](#tomdatakeystore)
    - [TomMemoryDataKeyStore](#tommemorydatakeystore)
    - [TomSqlDataKeyStore](#tomsqldatakeystore)
    - [TomDataKeyRow](#tomdatakeyrow)
    - [TomFieldKeyring](#tomfieldkeyring)
    - [TomFieldEncryption](#tomfieldencryption)
    - [TomReencryptionReport](#tomreencryptionreport)
    - [TomFieldReencryption](#tomfieldreencryption)
  - [Entity Lifecycle](#entity-lifecycle)
    - [TomSoftDelete](#tomsoftdelete)
    - [TomHistory](#tomhistory)
    - [TomHistoryEntry&lt;T&gt;](#tomhistoryentryt)
    - [TomHistoryMeta](#tomhistorymeta)
    - [TomEntityChangeKind](#tomentitychangekind)
    - [TomEntityChange](#tomentitychange)
    - [TomEntityListener&lt;T&gt;](#tomentitylistenert)
    - [TomEntityLifecycle](#tomentitylifecycle)
  - [Exceptions](#exceptions)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source:
`lib/src/tomserver/object_persistence/annotation_analyzer.dart`,
`lib/src/tomserver/object_persistence/blob_migration.dart`,
`lib/src/tomserver/object_persistence/blob_orphan_sweep.dart`,
`lib/src/tomserver/object_persistence/column_authorization.dart`,
`lib/src/tomserver/object_persistence/composite_key.dart`,
`lib/src/tomserver/object_persistence/crud_repository.dart`,
`lib/src/tomserver/object_persistence/data_scope.dart`,
`lib/src/tomserver/object_persistence/entity_lifecycle.dart`,
`lib/src/tomserver/object_persistence/field_encryption.dart`,
`lib/src/tomserver/object_persistence/field_encryption_sql.dart`,
`lib/src/tomserver/object_persistence/file_reference.dart`,
`lib/src/tomserver/object_persistence/grouped_query.dart`,
`lib/src/tomserver/object_persistence/mariadb_repository.dart`,
`lib/src/tomserver/object_persistence/operators_expressions.dart`,
`lib/src/tomserver/object_persistence/paging.dart`,
`lib/src/tomserver/object_persistence/persistence_annotations.dart`,
`lib/src/tomserver/object_persistence/query_builder.dart`,
`lib/src/tomserver/object_persistence/query_sentence_compiler.dart`,
`lib/src/tomserver/object_persistence/subquery.dart`.

An entity is a `@tomReflector` class annotated with `@TomDbTable`, its fields
mapped with `@TomDbColumn` (and `@TomEntityId` on the primary key). A
`TomRepository<T, K>` offers Spring-Data-style CRUD plus three query styles: a
parsed *query sentence* (`findByQuerySentence`), a built `TomQuery`
(`findByQuery`), and raw SQL (`executeQueryString`). A fourth entry point,
`findGroupedByQuery`, runs a `TomGroupedSelect` — grouping and aggregation
return `TomGroupedRow`s rather than entities, because a group's shape is decided
by the query rather than by any entity class. `TomAnnotationAnalyzer`
resolves an entity's metadata by reflection into a `TomColumnInformation` per
field; `TomQueryBuilder` and `TomQuerySentenceCompiler` assemble a `TomOperator`
expression tree rendered through a `TomStandardSqlDialect`; a `TomSubquery`
tested by `TomExists` or `TomInSubquery` is the predicate about another result
set, and the shape a query sentence's term on an association compiles to. `@TomDbScope`
(row-level, C-3) and `@TomDbColumn(authKey: …)` (column-level, C-4) add
server-authoritative access control enforced by `TomDataScope` /
`TomColumnAuthorization`, all binding values as prepared-statement parameters
(C-7). A column annotated `@TomFileReference` holds a blob *key* rather than the
file's bytes, so the row stays small enough to read, diff, audit and mask like
any other while the payload moves as a stream through `TomFileRepository`.
A field annotated `@TomVersion` turns on optimistic locking: every update and
`delete(entity)` matches the row only at the version the caller loaded, and a
write that finds it moved raises `TomOptimisticLockException` instead of
overwriting somebody else's change. A `String` field annotated `@TomEncrypted`
is stored as AES-256-GCM ciphertext and read as plaintext, under data keys a
`TomFieldKeyring` keeps wrapped under a key-encryption key and rotates without
downtime; a `@TomBlindIndex` column makes it findable by value, and
`TomFieldReencryption` rewrites what a rotation or a plaintext column left
behind. `@TomSoftDelete` turns a repository delete into setting a timestamp and
hides the rows that carry one, `@TomHistory` copies a row into a history table
before every update, delete and restore, and `TomEntityLifecycle` registers the
`TomEntityListener` hooks and change listeners every repository write of an
entity runs, inside one transaction with it. `TomBlobOrphanSweep` deletes the
keys of a `TomDeduplicatingBlobStore` that no row refers to — asking each
`TomBlobReferenceSource`, typically a `TomRepositoryBlobReferences` over an
entity's file columns — and reports a `TomBlobOrphanSweepReport`.

## Class Hierarchy

```
TomServerException  (little_things)
    ├── TomAnnotationAnalyzerException
    ├── TomAnnotationAnalyzerSyntaxException
    ├── TomColumnAuthorizationException
    ├── TomDataScopeException
    ├── TomDataScopeAuthorizationException
    ├── TomEntityLifecycleException
    ├── TomFieldEncryptionException
    ├── TomQuerySyntaxException
    └── TomRepositoryException
            └── TomOptimisticLockException

TomRepository<T, K>
    └── TomSqlDatasourceRepository<T, K>  (with TomQueryBuilder,
        │                                  implements TomFileRepository<T, K>)
        └── MariadbRepository<T, K>

TomEntityListener<T>  (hooks — registered with TomEntityLifecycle)

TomFileRepository<T, K>  (contract — the five methods the HTTP file
                          endpoint needs, no persistence stack)

TomResourceScopeSource  (hook — implemented in authorization by
                         TomResourceDataScope)

TomBlobReferenceSource  (contract — which blob keys rows refer to)
    └── TomRepositoryBlobReferences<T, K>

TomBlobOrphanSweep
TomBlobOrphanSweepReport  (plain value holder)

TomTypedPersistenceBase  (queries)
    └── TomQuerySentenceCompiler  (with TomQueryBuilder)

TomGeneratedQuery  (queries)
    └── TomGroupedSelect

TomOperator<R>  (types_operator)
    ├── Parameter<T>
    ├── TomAggregate<R, V>
    │       ├── CountAll / Count<T>
    │       ├── Sum<T> / Avg<T>
    │       └── Min<R, V> / Max<R, V>
    ├── TomExists / TomInSubquery<T>  (over a TomSubquery)
    ├── TomUnaryOperator<T, R>
    │       ├── DbCol<R>
    │       │       ├── IntCol / StringCol / DoubleCol
    │       │       └── BoolCol / DateTimeCol / DateCol / TimeCol
    │       ├── StringLiteral / IntegerLiteral / DoubleLiteral
    │       ├── BoolLiteral / DateTimeLiteral / DateLiteral / TimeLiteral
    │       ├── TruthPredicate
    │       ├── Not / IsNull<T> / IsNotNull<T>
    │       ├── And / Or
    │       └── Group<T>
    └── TomBinaryOperator<T1, T2, R>
            ├── Eq<T> / Neq<T> / Lt<T> / Gt<T> / Lte<T> / Gte<T>
            ├── Like / NotLike / Regexp
            └── In<T> / Between<T>

TomGroupedRow  (plain value holder)

TomSubquery  (plain value holder — rendered by TomExists / TomInSubquery)

TomKeyEncryptionKey  (contract — wraps the data keys)
    └── TomAesKeyEncryptionKey
        (and every key kind a package registers with registerKeyKind)

TomAesGcm  (abstract final, static-only — the cipher)

TomDataKeyStore  (contract — where the wrapped data keys are kept)
    ├── TomMemoryDataKeyStore
    └── TomSqlDataKeyStore

TomQueryBuilder  (mixin)
TomAnnotationAnalyzer  (mixin)
```

## Classes

### Annotations & Metadata

#### TomDartType

Wraps a Dart `Type` so it can be carried as a value (e.g. in an annotation
argument list, where a bare `Type` literal is awkward to pass around).

##### Constructors

```dart
TomDartType(Type type)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `Type` | The wrapped Dart type. |

#### TomDbTable

Annotation that maps an entity class to a database table.

##### Constructors

```dart
const TomDbTable({
  required String datasource,
  required String table,
  required List<String> primaryKeyFields,
  String? schema,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `String` | The registered data source that holds this table. |
| `table` | `String` | The table name. |
| `schema` | `String?` | The schema the table belongs to, if any. |
| `primaryKeyFields` | `List<String>` | The entity fields that hold the primary key, in key order; never empty. More than one makes the repository's key a `TomCompositeKey`. |

#### TomDbColumn

Annotation that maps an entity field to a database column. `authKey` opts the
column into column-level access rights (C-4); the kernel's `@TomProtectedField`
on the same field does the same, and also protects the field in JSON output.

The column's storage type is the field's Dart type unless `columnType` names
another — a `TomDbType` box (`TomDbString`) or a Dart type whose storage it
shares (`bool`). The class takes no type parameters: an annotation is read back
through reflection, which reconstructs it without type arguments, so the storage
type is stated in fields the reflected copy keeps. `TomAnnotationAnalyzer.familyOf`
is the one resolver that turns them into a storage family.

##### Constructors

```dart
const TomDbColumn({
  required String? columnName,
  bool isReadOnly = false,
  bool noLoad = false,
  bool isJson = false,
  String? authKey,
  Type? dartType,
  Object? Function(TomDbType value)? fromDbConverter,
  TomDbType Function(dynamic value)? toDbConverter,
  Type? columnType,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columnName` | `String?` | The column name; defaults to the field name when `null`. |
| `isReadOnly` | `bool` | Whether the column is excluded from inserts and updates. |
| `noLoad` | `bool` | Whether the column is excluded from selects. |
| `isJson` | `bool` | Whether the column holds JSON-encoded data (stored as text). |
| `authKey` | `String?` | The resource key that gates this column's read/write access (C-4); `null` leaves it unrestricted. |
| `dartType` | `Type?` | The Dart type the column is read as, when it is not the field's own. |
| `columnType` | `Type?` | The type the column is stored as, when it is not the field's Dart type: a `TomDbType` box or a Dart type. |
| `fromDbConverter` | `Object? Function(TomDbType value)?` | Converts the stored boxed value back to the field's Dart value; typed with the widest box, narrowing inside by cast. |
| `toDbConverter` | `TomDbType Function(dynamic value)?` | Converts the field's Dart value to the boxed value to store. |

#### TomEntityId

Annotation marking the entity field that holds the primary key.

##### Constructors

```dart
const TomEntityId()
```

#### TomVersion

Annotation marking the `int` field that holds the row's **version**, turning on
optimistic locking for the entity. The repository maintains the field itself:

- an insert writes version `1`, whatever the field held;
- an update writes `version + 1` only where the stored version is still the one
  the entity was loaded with (`… WHERE id = :id AND version =
  :__tomversion_expected`), and raises `TomOptimisticLockException`
  (`crud_repository.save.version_conflict`) when that matches no row;
- `delete(entity)` checks the version the same way
  (`crud_repository.delete.version_conflict`); `deleteById` and the query
  deletes name no version and are not checked;
- an update or `delete(entity)` whose version field is `null` is refused with
  `crud_repository.save.version_missing` /
  `crud_repository.delete.version_missing` before any statement runs.

At most one field may carry it (`annotation_analyzer.version.more_than_one`),
and that field must be an `int` the repository can write — not the entity id,
not an association, not `isReadOnly`
(`annotation_analyzer.version.invalid_field`). Its column must be `NOT NULL`;
the schema-convergence check reports a nullable one as `nullableVersionColumn`.

##### Constructors

```dart
const TomVersion()
```

#### TomEncrypted

Annotation encrypting the annotated `String` column at rest. A value is written
as AES-256-GCM ciphertext under the active data key of the installed
`TomFieldKeyring`, bound to its table and column, and read back as plaintext:
an entity holds plaintext, the database never does. The encryption is
randomised, so an encrypted column cannot be filtered, grouped, aggregated or
sorted on (`query_sentence_compiler.encrypted_column`); a field that must be found by
value carries a companion `TomBlindIndex` column. The column must be wide enough
for the ciphertext — `TEXT`, or a `VARCHAR` of `TomFieldEncryption.storedLength`
of the longest plaintext.

Only a `String` field may carry it, not together with `TomBlindIndex`, and not
on the entity id, the version, a reference or a file column
(`annotation_analyzer.encryption.not_string` / `both` / `structural_column`).

##### Constructors

```dart
const TomEncrypted()
```

#### TomBlindIndexNormalization

How a `TomBlindIndex` normalises a value before indexing it, so the values the
application treats as equal index equally.

##### Enum Values

| Value | Meaning |
| ----- | ------- |
| `exact` | The value as it is. |
| `trim` | Leading and trailing whitespace removed. |
| `trimLowercase` | Trimmed and lower-cased — an e-mail address, a user name. The default. |

#### TomBlindIndex

Annotation making the annotated `String` column the **blind index** of the
`TomEncrypted` field `field`: an HMAC-SHA-256 of the normalised plaintext under
the keyring's index key, written by the repository with every save. Equal
plaintexts give equal index values, so the column can be compared —
`TomFieldEncryption.blindIndexCondition` builds the lookup — while the plaintext
is not recoverable from it. A blind index naming a field that is not encrypted
is refused (`annotation_analyzer.encryption.index_without_field`).

##### Constructors

```dart
const TomBlindIndex(String field, {TomBlindIndexNormalization normalization = TomBlindIndexNormalization.trimLowercase})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The declared name of the `TomEncrypted` field this column indexes. |
| `normalization` | `TomBlindIndexNormalization` | How the plaintext is normalised before it is indexed. |

#### TomDbScope

Annotation declaring the row-level data scope of an entity (C-3): it restricts
which rows the repository returns to those the current principal may see.

Writing it is often unnecessary. An entity carrying a resource-key column is
scoped under `resourceScope` automatically —
`TomAnnotationAnalyzer.autoScopeFor` synthesizes exactly the annotation a
developer would have written — so the declaration mechanism stays single rather
than gaining a parallel one, and forgetting the annotation can no longer
silently publish every row. Where automatic scoping would apply but must not,
`TomDbScope.unscoped()` is the deliberate opt-out.

##### Constructors

```dart
const TomDbScope({required String field, String scope = 'owner'})
const TomDbScope.unscoped()
```

`unscoped()` declares that the entity's rows are visible to every principal. It
is needed only where automatic scoping would otherwise apply. The authorization
metadata tables are the framework's own instance of that: the rows that *say*
who may see what cannot themselves be filtered by who may see what, or the
resolver would deny itself its own input.

##### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `resourceScope` | `String` | `'resource'` | The scope kind resolving a principal's granted resource keys — direct ownership grants folded with the delegations active right now (C-5 ∪ C-6). |
| `noScope` | `String` | `''` | The sentinel `scope` of `TomDbScope.unscoped()`. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The entity field whose value is matched against the principal's allowed scope values. |
| `scope` | `String` | The scope kind — a key into `TomDataScopeRegistry` selecting the resolver (default `'owner'`). |
| `isOptOut` | `bool` | *(getter)* Whether this is the explicit opt-out (`scope == noScope`) rather than a scope declaration. `findDataScope` returns `null` for such an annotation. |

#### TomTenantTable

Annotation classifying an entity as a **tenant table**: its rows are one
tenant's data. Every entity without it is a **system table**, whose rows belong
to the deployment. The repository resolves its data source by the
classification — a system table always through the registered data source,
unrouted, also inside a tenant; a tenant table through the current tenant's
route (its own schema or database, or its type's shared schema). With no tenant
in context a tenant table is refused under an installed tenancy
(`tenancy.context.missing`) and runs as the implicit tenant `default` without
one. It is independent of `TomDbScope` and is ANDed with it.

- every read — `findAll`, `findById`, `count`, `findByQuery`, the existence
  checks, `historyOf` — carries `<field> = <tenant>` as a bound predicate
  (parameters prefixed `TomSqlDatasourceRepository.tenantParameterPrefix`);
- every update and delete may touch only rows that predicate admits;
- an insert whose `field` is unset is filled with the tenant, and one naming
  another tenant is refused with `data_scope.write.foreign_tenant`.

The predicate applies in every isolation model; the column is on every tenant
table, since any tenant may move. A `@TomReference`, a `TomSubquery` or a
repository over tenant tables and system tables together is refused when
analysed (`annotation_analyzer.tenant_table.mixed`).

##### Constructors

```dart
const TomTenantTable({String field = 'tenantId'})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The entity field holding the row's tenant id (default `'tenantId'`). |

#### TomReference&lt;TARGET, K, REPO&gt;

Annotation describing a reference (association) from one entity to another,
resolved through a join entity.

- **Type Parameters:** `TARGET extends Object` — the referenced entity; `K` — its key type; `REPO extends TomRepository<TARGET, K>` — the loading repository.

##### Constructors

```dart
const TomReference({
  required Type targetEntity,
  required Type repositoryType,
  required Type keyType,
  required Type joinEntity,
  required List<String> leftSideColumns,
  required List<String> rightSideColumns,
  List<String> contextColumns = const [],
  bool isOneToOne = false,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `targetEntity` | `Type` | The referenced entity type. |
| `repositoryType` | `Type` | The repository type that loads `targetEntity`. |
| `joinEntity` | `Type` | The entity that models the join. |
| `keyType` | `Type` | The key type linking the two sides. |
| `leftSideColumns` | `List<String>` | The join columns on this (owning) side. |
| `rightSideColumns` | `List<String>` | The join columns on the referenced side. |
| `contextColumns` | `List<String>` | Extra join columns carried as context. |
| `isOneToOne` | `bool` | Whether this is a one-to-one (single-valued) association. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getReferencedType` | `Type getReferencedType()` | The referenced entity type (`targetEntity`). |
| `getRepositoryType` | `Type getRepositoryType()` | The repository type that loads the referenced entity. |
| `getKeyType` | `Type getKeyType()` | The key type linking the two sides. |
| `toString` | `String toString()` | *(override)* A debug rendering of the reference. |

#### TomColumnInformation

The resolved persistence metadata for a single entity field: the owning table,
the field's annotations, its declared type/name, the mapped column, and
reflection-backed accessors to read/write the field.

##### Constructors

```dart
TomColumnInformation({
  required Type tableType,
  required TomDbTable table,
  required Type declaredType,
  required String declaredName,
  required String field,
  TomDbColumn? column,
  TomEntityId? entityId,
  TomReference? reference,
  TomFileReference? fileReference,
  TomProtectedField? protectedField,
  TomVersion? version,
  TomEncrypted? encrypted,
  TomBlindIndex? blindIndex,
})
```

The five required parameters are the ones every mapped field has; the eight
optional ones each correspond to an annotation the field may or may not carry,
and are `null` when it does not.

All are named because two pairs are otherwise interchangeable by miscounting and
type-check either way. `declaredName` and `field` are both `String`: passing them
the wrong way round maps the entity's field name to itself as a column and the
column name to itself as a field, so the mistake surfaces as wrong SQL somewhere
else. `declaredType` and `tableType` are both `Type`, and confusing them reports
every column of an entity as being of the entity's own type.

Every property is `final`. An instance is not private to whoever obtained it —
the analyzer resolves an entity's columns once and hands the same objects to
every repository, query compiler and datasource — so a write to one of them
would change what every later query on that entity compiles to, at no point
raising an error. Re-resolving an entity means re-running the analyzer, not
editing its metadata in place.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tableType` | `Type` | The entity type that owns this field. |
| `table` | `TomDbTable` | The table the owning entity maps to. |
| `column` | `TomDbColumn?` | The field's column mapping, if annotated. |
| `entityId` | `TomEntityId?` | The entity-id annotation, if this field is the primary key. |
| `reference` | `TomReference?` | The reference annotation, if this field is an association. |
| `fileReference` | `TomFileReference?` | The file-reference annotation, if this column holds a blob storage key. |
| `protectedField` | `TomProtectedField?` | The kernel's field-protection annotation, if the field carries one. |
| `version` | `TomVersion?` | The optimistic-locking annotation, if this field is the row's version. |
| `encrypted` | `TomEncrypted?` | The encryption annotation, if the column is encrypted at rest. |
| `blindIndex` | `TomBlindIndex?` | The blind-index annotation, if the column indexes an encrypted field. |
| `authKey` | `String?` | *(getter)* The resource key gating this column (C-4): `column.authKey`, else `protectedField.resourceKey`, else `null`. One `@TomProtectedField` therefore protects the field in the JSON tier and here. |
| `declaredType` | `Type` | The declared Dart type of the field. |
| `declaredName` | `String` | The field's name on the entity. |
| `field` | `String` | The mapped column name. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getDatabaseType` | `Type getDatabaseType()` | The owning entity type (`tableType`). |
| `getQueryFieldName` | `String getQueryFieldName()` | The column name to use in a query: annotated `columnName` when present, else `declaredName`. |
| `getVariableValue` | `Object? getVariableValue(Object instance)` | Reads this field's value from `instance` via reflection. |
| `setVariableValue` | `Object? setVariableValue(Object instance, Object? value)` | Writes `value` to this field on `instance` via reflection. |

### Repositories

#### TomCompositeKey

The primary-key value of an entity whose `@TomDbTable.primaryKeyFields` names
more than one field — the `K` of its repository. Keyed by **field** name, and
must carry exactly the entity's key fields: a key with a field missing or extra
is refused with `crud_repository.key.shape_mismatch`. Two keys are equal when
they hold the same values for the same fields, in any order. `final class`.

##### Constructors

```dart
TomCompositeKey(Map<String, Object?> values)
```

##### Properties and Methods

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `values` | `final Map<String, Object?> values` | The key's values, keyed by entity field name; unmodifiable. |
| `fields` | `Iterable<String> get fields` | The field names this key carries. |
| `operator []` | `Object? operator [](String field)` | The value of `field`, or `null` when the key does not carry it. |
| `toString` | `String toString()` | `(userId: 7, roleId: 3)` — the form audit records and error messages carry. |

#### TomCountResult

Result holder for a `COUNT(*)` query: a single `count` field populated by the
row mapper. `@tomReflector`.

##### Constructors

```dart
TomCountResult()
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `count` | `int` | The row count returned by the query. |

#### TomRepository&lt;T, K&gt;

The persistence contract for an entity `T` keyed by `K`, modelled on Spring
Data's `CrudRepository`.

- **Type Parameters:** `T extends Object` — the entity type; `K` — its key type.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `delete` | `Future<void> delete(T entity)` | Deletes `entity` by its primary key. The one delete that returns nothing: it addresses a row the caller already holds, so the count could only be `1` or `0`. An entity that was never persisted addresses no row and raises `crud_repository.delete.unsaved_entity`. For a `@TomVersion` entity it deletes only at the version `entity` carries, and raises `TomOptimisticLockException` (`crud_repository.delete.version_conflict`) when the row has moved or is gone. |
| `deleteAllById` | `Future<int> deleteAllById(Iterable<K> ids)` | Deletes every entity whose id is in `ids` and returns how many rows were deleted — which can be lower than `ids.length` when an id names no row, or one outside the principal's data scope. |
| `deleteById` | `Future<int> deleteById(K id)` | Deletes the entity with the given `id` and returns how many rows were deleted: `1`, or `0` when no row matched. |
| `existsById` | `Future<bool> existsById(Iterable<K> ids)` | Whether every id in `ids` exists. |
| `findAll` | `Future<List<T>> findAll([TomPageRequest? page])` | Loads all entities, or the window `page` asks for. |
| `findAllById` | `Future<List<T>> findAllById(Iterable<K> ids, [TomPageRequest? page])` | Loads every entity whose id is in `ids`, optionally windowed. |
| `findById` | `Future<T?> findById(K id)` | Loads the entity with the given `id`, or `null` if absent. |
| `count` | `Future<TomDbInt> count()` | Counts all entities. |
| `save` | `Future<T> save(T toSave)` | Inserts (no primary key) or updates (primary key set) and returns the stored entity. For a `@TomVersion` entity an insert stores version `1` and an update stores the next version only where the stored one is still the one `toSave` carries, raising `TomOptimisticLockException` (`crud_repository.save.version_conflict`) otherwise; the returned entity carries the new version. |
| `saveAll` | `Future<Iterable<T>> saveAll(Iterable<T> entities)` | Saves every entity and returns the stored entities. |
| `findByQuerySentence` | `Future<Iterable<T>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType, TomPageRequest? page])` | Runs a parsed query sentence as a `SELECT`, binding `params`, optionally windowed. |
| `deleteByQuerySentence` | `Future<int> deleteByQuerySentence(String querySentence, Map<String, Object?> params)` | Runs a parsed query sentence as a `DELETE` and returns how many rows were deleted — counted *after* the principal's data scope is ANDed in, so it never reports rows the principal may not see. |
| `countByQuerySentence` | `Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)` | Runs a parsed query sentence as a `COUNT`. |
| `findByQuery` | `Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params, [TomPageRequest? page])` | Runs a built `TomSelect`, binding `params`, optionally windowed. |
| `deleteByQuery` | `Future<int> deleteByQuery(TomDelete query, Map<String, Object?> params)` | Runs a built `TomDelete`, binding `params`, and returns how many rows were deleted — scoped like `deleteByQuerySentence`. |
| `countByQuery` | `Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params)` | Runs a built `TomCount`, binding `params`. |
| `findGroupedByQuery` | `Future<List<TomGroupedRow>> findGroupedByQuery(TomGroupedSelect query, Map<String, Object?> params)` | Runs a built `TomGroupedSelect`, binding `params`, and returns one `TomGroupedRow` per group. Deliberately not `T`: a grouped row's shape is the query's, not the entity's. |
| `executeQueryString` | `Future<Iterable<T>> executeQueryString(String dbQuery, Map<String, Object?> params)` | Runs a raw SQL string, binding `params`, and maps the rows to `T`. |

#### TomSqlDatasourceRepository&lt;T, K&gt;

SQL-datasource implementation of `TomRepository`. On construction it resolves the
entity's metadata via `TomAnnotationAnalyzer`, looks up the named data source, and
builds a `TomQuerySentenceCompiler`. CRUD methods enforce C-3 row scope and C-4
column rights, and bind all values as prepared-statement parameters (C-7).

- **Extends:** `TomRepository<T, K>`
- **Mixes in:** `TomQueryBuilder`
- **Implements:** `TomFileRepository<T, K>`
- **Type Parameters:** `T extends Object` — the entity type; `K` — its key type.

##### Constructors

```dart
TomSqlDatasourceRepository([List<Type>? queryTypes, Type? resultType])
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isUnsavedKey` | `static bool isUnsavedKey(Object? primaryKey)` | Whether `primaryKey` marks a not-yet-persisted entity (`null`, a negative sentinel, or a `TomCompositeKey` with a `null` field). For a single key, `save` then inserts; a complete composite key is looked up instead. |
| `readPrimaryKey` | `static K2? readPrimaryKey<K2>(Object? raw)` | Reads an entity's primary-key value as a nullable `K2`. |
| `buildInsertStatement` | `static (String, List<String>) buildInsertStatement(String table, List<TomColumnInformation> columns)` | Builds the `INSERT` SQL and its ordered bind-parameter names. |
| `buildUpdateStatement` | `static (String, List<String>) buildUpdateStatement(String table, List<TomColumnInformation> columns, List<TomColumnInformation> primaryKey, {TomColumnInformation? version})` | Builds the `UPDATE ... SET ... WHERE pk = :pk` SQL — every key column ANDed — and its ordered bind names. With a `version` column the `WHERE` also requires `version = :__tomversion_expected` (`versionParameter`, bound last), so the statement matches no row once another save has moved the version. |

##### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `tenantParameterPrefix` | `String` | `'__tomtenant_'` | The parameter prefix of the tenant-table predicate, apart from the data scope's, so the two bind in one statement; a subquery over tenant tables binds `<prefix>0` too. |
| `tenantSystemTransactionKey` | `String` | `'crud_repository.transaction.tenant_and_system_one_phase'` | The key of the refusal raised when one transaction would hold a tenant table and a system table on two data sources of which one commits in a single phase, the tenant's not reaching the system's. |
| `literalOnTenantConnectionKey` | `String` | `'crud_repository.transaction.literal_on_tenant_connection'` | The key of the refusal raised when a raw statement (`executeQueryString`) would run for a system table that the transaction already runs on a tenant's connection, where its text — which the repository cannot qualify — would name the tenant's schema. |
| `deletedAtParameter` | `String` | `'__tomdeleted_at'` | The bind name of the deletion time a soft delete sets (and a restore clears). |
| `nextVersionParameter` | `String` | `'__tomversion_next'` | The bind name of the next version a versioned soft `delete(entity)` writes — a soft delete moves the version like any write. |
| `versionParameter` | `String` | `'__tomversion_expected'` | The bind name of the version a versioned update or `delete(entity)` expects to find stored. Prefixed like the scope and tenant parameters so it cannot collide with a column's declared name. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `primaryKeyColumns` | `List<TomColumnInformation>` | Resolved metadata for the primary-key columns, in `primaryKeyFields` order. |
| `hasCompositeKey` | `bool` | *(getter)* Whether the key spans more than one field, making `K` a `TomCompositeKey`. |
| `isTenantTable` | `bool` | Whether the entity is a tenant table (`@TomTenantTable`) rather than a system table (late final). |
| `datasourceInfo` | `TomDataSourceInfo` | *(getter)* The data source this repository runs against, by the entity's classification: a system table's registered data source, unrouted; a tenant table's route for the current tenant (`TomDataSourceInfo.route`) — refused with no tenant under an installed tenancy (`tenancy.context.missing`). Resolved on every access, so one repository serves every tenant; prepared statements are cached per data source. Inside a running transaction a system table runs on a tenant's connection when that connection reaches the system schema (`TomSqlDatasource.canQualify`) — the work runs in such a tenant, or the transaction already holds a tenant table there — unless the transaction already holds the table's own data source; its statements are then qualified (`tableQualifier`) and the transaction stays one branch. A tenant table and a system table on two data sources of which one is one-phase and the tenant's does not reach the system's are refused (`tenantSystemTransactionKey`). |
| `tableQualifier` | `String Function(String)?` | *(getter)* How this repository's statements name their tables in the current zone: `null` for the bare name, or — for a system table running on a tenant's connection in a transaction — `TomSqlDatasource.qualify` of its own data source. Code running statements of its own for the entity beside the repository (sync's change log) renders them in `TomSqlTableQualification.run(tableQualifier, ...)`. |
| `persistenceInfo` | `TomTypePersistenceInfo` | The resolved persistence metadata of the entity. |
| `dbTable` | `TomDbTable` | The table the entity maps to. |
| `sqlDialect` | `TomStandardSqlDialect` | *(getter)* The SQL dialect used to render queries; defaults to the data source's dialect. |
| `queryTypes` | `List<Type>` | The entity types this repository can query (first is the primary entity). |
| `resultType` | `Type` | The default row type for results. |
| `isSoftDelete` | `bool` | *(getter)* Whether the entity's deletes are soft (`@TomSoftDelete`). |
| `upsertBlocker` | `String?` | *(getter)* Why `upsert` cannot write this entity type, or `null` when it can: `column access rights`, `file-reference columns`, `encrypted columns`, `a version column`, `soft delete`, `entity listeners, change listeners or history`, or `an audit policy` (one auditing a create or an update) — each needs the stored row, which a single statement does not read. |

##### Methods

Overrides every method of `TomRepository<T, K>` (see above), applying C-3 row
scoping and C-4 column masking/enforcement on the SQL data source.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `keyOf` | `Object? keyOf(T entity)` | The primary-key value of `entity`: the key field's value, or a `TomCompositeKey` of every key field's. |
| `restoreById` | `Future<int> restoreById(K id)` | Clears the deletion time of the soft-deleted row `id`; answers `1`, or `0` when the row is not deleted or not there. Writes a `restore` history row and a `restored` change event. Refused (`crud_repository.soft_delete.not_soft_delete`) for an entity whose deletes are hard. |
| `purgeById` | `Future<int> purgeById(K id)` | Deletes the row `id` for good, soft-deleted or not — a hard `DELETE` with the file cascade, the delete hooks, history and change event. Refused (`crud_repository.soft_delete.not_soft_delete`) for an entity whose deletes are hard. |
| `historyOf` | `Future<List<TomHistoryEntry<T>>> historyOf(K id)` | The past versions of the row `id`, oldest first: the row as it was before each update, delete and restore. Refused (`crud_repository.history.not_declared`) for an entity without `@TomHistory`. |
| `insert` | `Future<T> insert(T entity)` | Inserts `entity` as a new row, whatever its key holds, and returns the stored entity. `save` inserts only a single key the database has not assigned yet, so a key the caller chooses — a client-generated id — is never inserted by `save`; `insert` writes it as given, through the same write path (hooks with `insert: true`, the tenant and insert-side scope checks, column grades, version, encryption, audit, history, change listeners). A row already holding the key is refused by the table's primary key. A single key left unsaved is assigned by the database, as with `save`. |
| `upsert` | `Future<T> upsert(T entity, {required List<String> conflictFields})` | Writes `entity` in one statement (`TomStandardSqlDialect.upsert`): inserted, or — when a row holds the same values in `conflictFields`, which must be a unique key of the table — written over that row, every writable column outside the key overwritten. Returns `entity` carrying the key of the row written. Two writers racing for one key cannot both insert. Refused with `crud_repository.upsert.unsupported` when `upsertBlocker` is not `null`, and with `crud_repository.upsert.unscoped_conflict_key` when `conflictFields` leave out the entity's `@TomDbScope` or tenant field; the tenant and insert-side scope checks run first, as for `save`. |
| `saveByKey` | `Future<T> saveByKey(T entity, {required List<String> conflictFields})` | Writes `entity` as the row identified by `conflictFields` and returns the stored entity: `upsert` when `upsertBlocker` is `null`; otherwise the row is looked up by `conflictFields` and `save`d with its key, so every write feature sees the stored row — two writers racing for a new key can then both reach the insert, and the table's unique key refuses the second. |

On a `@TomSoftDelete` entity every delete method sets the deletion time instead
of removing the row, and the filter `<deleted> IS NULL` joins the row scope and
the tenant predicate in every read, count, existence check and write guard —
`TomSoftDelete.includingDeleted` lifts it. A delete cut to a window is resolved
to the keys the window holds first. On an entity with a registered listener, a
change listener or a `@TomHistory`, every write runs inside a transaction (the
caller's or its own), so the history rows, the listeners' writes and the change
commit or roll back together. See
[Entity Lifecycle](../object_persistence.md#entity-lifecycle).

#### MariadbRepository&lt;T, K&gt;

A `TomSqlDatasourceRepository` for MariaDB-backed entities, pinned to
`MariadbSqlDialect`; a repository extending `TomSqlDatasourceRepository`
directly renders through its data source's dialect and serves MariaDB and
PostgreSQL alike. Constructed
directly — `MariadbRepository<User, int>([User])` — there being no repository
registry to resolve it from a data-source name: the type argument is what makes
a repository the repository *for an entity*, and a lookup keyed on a string
cannot supply one. Overrides `sqlDialect` to render with `MariadbSqlDialect`.
`@tomReflector`.

- **Extends:** `TomSqlDatasourceRepository<T, K>`
- **Type Parameters:** `T extends Object` — the entity type; `K` — its key type.

##### Constructors

```dart
MariadbRepository([List<Type>? queryTypes, Type? resultType])
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | *(getter, override)* The MariaDB SQL dialect used to render queries. |

### File References

A file column is an ordinary short `VARCHAR` that holds a **blob key** instead of
the file's bytes. Every other persistence feature keeps working on it unchanged —
it is row-scoped by `@TomDbScope`, can carry an `authKey` and be masked or
write-protected like any column, and appears in the audit trail as the key it
holds. What the annotation adds is the bytes: they move as a stream through the
`TomFileRepository` methods, so a payload that may be gigabytes never passes
through a `SELECT`.

The split across three types is deliberate. `TomFileReference` is declarative and
lives with the other annotations; `TomFileReferenceKeys` is the behaviour it
implies, as pure functions over the annotation, so the key scheme can be
unit-tested without a database, a store, or the reflection runtime;
`TomFileRepository` is the narrow contract the HTTP file endpoint depends on.

#### TomFileReference

Annotation marking a `String` column as holding a blob storage key rather than
the file's bytes. Declarative only — the runtime half is `TomFileReferenceKeys`
and the repository's file methods.

##### Constructors

```dart
const TomFileReference({
  String? store,
  String keyPrefix = '',
  bool cascadeDelete = true,
  String mediaType = 'application/octet-stream',
  bool exposed = false,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `String?` | The named blob store to use, or `null` for the default store — so a deployment with one place to put files configures nothing per column. |
| `keyPrefix` | `String` | The prefix generated keys are placed under, e.g. `invoices`. Must satisfy `TomBlobStore.isValidKeyPrefix`; because a `const` constructor cannot refuse a value, the check happens where the key is minted. |
| `cascadeDelete` | `bool` | Whether deleting (or clearing) the owning row deletes the blob. Set `false` for a key the application shares between rows or manages itself. |
| `mediaType` | `String` | The media type assumed when an upload does not name one. Mirrors `TomStoredBlob.defaultMediaType`, spelled literally so the annotation library does not depend on the storage module. |
| `exposed` | `bool` | Whether the column is reachable over the framework's HTTP file endpoint (`TomFileService`), addressable as the slot `<table>/<id>/<column>`. **Default-closed** — reflection must never publish a column by accident. It does not decide *whether* a caller may have the file, which stays with the row scope (C-3) and column grade (C-4). |

#### TomFileReferenceKeys

Resolves the store and mints the keys for a `@TomFileReference` column. All
members are static; the class is not constructible.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `storeFor` | `static TomBlobStore storeFor(TomFileReference reference)` | The blob store `reference` names, or the default store when it names none. Resolved per call rather than cached on the column metadata: the registry is populated at start-up and replaced wholesale by a test, and a column that captured a store at first use would keep serving the previous test's. |
| `generate` | `static String generate(TomFileReference reference, {String? fileName, DateTime? now})` | Mints a fresh key, shaped `<keyPrefix>/<yyyy>/<mm>/<uuid><.ext>`. `now` is injectable so a test can assert the exact partition. |
| `extensionOf` | `static String extensionOf(String? fileName)` | The lower-cased extension of `fileName` including the dot (`.pdf`), or the empty string when there is none worth carrying. |

The key shape earns each of its four parts: the **prefix** separates one column's
blobs from another's, so a store shared by several entities stays navigable and a
lifecycle rule can be written against a path; the **date partition** bounds how
many objects land in one directory, and makes "everything from July" expressible
as a prefix on an object store; the **UUID** makes the key collision-free without
a round trip (a fresh upload never silently overwrites a live one) and
unguessable, so holding one key does not let a caller enumerate its neighbours;
the **extension** is decoration carried over because it costs nothing and makes a
key readable to whoever is looking at the bucket — the media type of record lives
in the descriptor, not in the key.

`extensionOf` is deliberately conservative: only a short (≤ 12 character), purely
alphanumeric suffix is carried, because the extension is appended to a key whose
grammar is narrow (`TomBlobStore.isValidKey`) and a "file name" arriving from a
browser is caller-supplied text, not a vetted identifier.

#### TomFileRepository&lt;T, K&gt;

The subset of a repository the file surfaces need: load a row, and move the bytes
of one of its `@TomFileReference` columns.

Split out of `TomRepository` rather than folded into it because it is what the
HTTP file endpoint depends on, and an endpoint that depended on the full SQL
repository could only ever be exercised against a database. Every method is
already implemented by `TomSqlDatasourceRepository`; naming them as a contract
costs nothing and makes the endpoint's requirement explicit — five methods, not a
persistence stack.

- **Type Parameters:** `T extends Object` — the entity type; `K` — its key type.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `findById` | `Future<T?> findById(K id)` | Loads the entity with the given `id`, or `null` if absent (or not visible to the current principal under the entity's row scope). |
| `saveFile` | `Future<T> saveFile(T entity, String fieldName, Stream<List<int>> bytes, {String? mediaType, String? fileName})` | Uploads `bytes` into the file column `fieldName` of `entity` and saves the row, returning the stored entity. |
| `openFile` | `Stream<List<int>> openFile(K id, String fieldName, {TomBlobRange? range})` | Streams the file held by the file column `fieldName` of row `id`, or `range` of it. The range is passed to the store, which serves it natively where the backend can seek; both authorization gates run first and unchanged, since a range is a narrower read of the same bytes and never a way to reach bytes a whole read would refuse. |
| `describeFile` | `Future<TomStoredBlob?> describeFile(K id, String fieldName)` | The descriptor of the file held by `fieldName` on row `id`, or `null` when the row (or its column) holds nothing. |
| `clearFile` | `Future<T> clearFile(T entity, String fieldName)` | Clears the file column `fieldName` on `entity`, deleting the blob. |

### Query Building

#### TomQueryBuilder

A fluent factory (mixin) for the `TomOperator` expression tree. Predicate
builders return `TomOperator<TomDbBool>`; literal/column/parameter builders
return the matching SQL-typed operator.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isNull` | `TomOperator<TomDbBool> isNull<T>(TomOperator<T> what)` | `<what> IS NULL`. |
| `isNotNull` | `TomOperator<TomDbBool> isNotNull<T>(TomOperator<T> what)` | `<what> IS NOT NULL`. |
| `exists` | `TomOperator<TomDbBool> exists(TomSubquery subquery)` | `EXISTS (<subquery>)`. |
| `notExists` | `TomOperator<TomDbBool> notExists(TomSubquery subquery)` | `NOT EXISTS (<subquery>)`. |
| `isInSubquery` | `TomOperator<TomDbBool> isInSubquery<T>(TomOperator<T> what, TomSubquery subquery)` | `<what> IN (<subquery>)` — `subquery` selects the one column compared. |
| `isNotInSubquery` | `TomOperator<TomDbBool> isNotInSubquery<T>(TomOperator<T> what, TomSubquery subquery)` | `NOT <what> IN (<subquery>)`. |
| `isIn` | `TomOperator<TomDbBool> isIn<T>(TomOperator<T> what, List<TomOperator<T>> choices)` | `<what> IN (<choices...>)`. |
| `between` | `TomOperator<TomDbBool> between<T>(TomOperator<T> what, List<TomOperator<T>> betweenLimits)` | `<what> BETWEEN <lo> AND <hi>`. |
| `like` | `TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | `<text> LIKE <test>`. |
| `notLike` | `TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | `<text> NOT LIKE <test>`. |
| `regexp` | `TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | `<text> REGEXP <test>`. |
| `group` | `TomOperator<T> group<T>(TomOperator<T> operant)` | `( <operant> )`. |
| `eq` | `TomOperator<TomDbBool> eq<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> = <b>`. |
| `neq` | `TomOperator<TomDbBool> neq<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> <> <b>`. |
| `lt` | `TomOperator<TomDbBool> lt<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> < <b>`. |
| `lte` | `TomOperator<TomDbBool> lte<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> <= <b>`. |
| `gt` | `TomOperator<TomDbBool> gt<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> > <b>`. |
| `gte` | `TomOperator<TomDbBool> gte<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | `<a> >= <b>`. |
| `not` | `TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)` | `NOT <operant1>`. |
| `and` | `TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)` | The predicates joined with ` AND `. |
| `or` | `TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)` | The predicates joined with ` OR `. |
| `text` | `TomOperator<TomDbString> text(String text)` | A string literal. |
| `intOp` | `TomOperator<TomDbInt> intOp(int value)` | An integer literal. |
| `doubleOp` | `TomOperator<TomDbDouble> doubleOp(double value)` | A double literal. |
| `boolOp` | `TomOperator<TomDbBool> boolOp(bool value)` | A boolean literal — a value compared with a truth column. |
| `truthPredicate` | `TomOperator<TomDbBool> truthPredicate(bool value)` | A constant predicate, one that admits every row or none (`TruthPredicate`) — what a data scope that admits nothing renders as its `WHERE`. |
| `dateTimeOp` | `TomOperator<TomDbDateTime> dateTimeOp(DateTime value)` | A timestamp literal. |
| `dateOp` | `TomOperator<TomDbDate> dateOp(DateTime value)` | A date literal. |
| `timeOp` | `TomOperator<TomDbTime> timeOp(DateTime value)` | A time-of-day literal — only the clock components of `value` are used. |
| `p` | `TomOperator<T> p<T>(String parameterName)` | A named positional parameter placeholder (`:parameterName`). |
| `textF` | `TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `String` column. |
| `intF` | `TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)` | A reference to an `int` column. |
| `doubleF` | `TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `double` column. |
| `boolF` | `TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `bool` column. |
| `dateTimeF` | `TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)` | A reference to a timestamp column. |
| `dateF` | `TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)` | A reference to a date column. |
| `timeF` | `TomOperator<TomDbTime> timeF(String fieldName, TomColumnInformation columnInformation)` | A reference to a time-of-day column. |

##### Methods — aggregates

Each returns a `TomAggregate`, which *is* a `TomOperator`, so an aggregate
composes with the predicate builders above: `gt(countAll('n'), intOp(3))` is the
`HAVING COUNT(*) > 3` of a grouped select. Every factory takes the `alias` the
aggregate is projected under.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `countAll` | `CountAll countAll(String alias)` | `COUNT(*) AS <alias>` — the number of rows in each group. |
| `countOf` | `Count<T> countOf<T>(TomOperator<T> value, String alias, {bool distinct = false})` | `COUNT([DISTINCT] <value>) AS <alias>` — the non-null values in each group. Named `countOf`, not `count`, because repositories mix this builder in beside `TomRepository.count()`. |
| `sum` | `Sum<T> sum<T>(TomOperator<T> value, String alias, {bool distinct = false})` | `SUM(<value>) AS <alias>`, always a `double`. |
| `avg` | `Avg<T> avg<T>(TomOperator<T> value, String alias, {bool distinct = false})` | `AVG(<value>) AS <alias>`, always a `double`. |
| `minInt` / `maxInt` | `Min<TomDbInt, int> minInt(TomOperator<TomDbInt> value, String alias)` | `MIN`/`MAX` over an `int` expression. |
| `minDouble` / `maxDouble` | `Min<TomDbDouble, double> minDouble(TomOperator<TomDbDouble> value, String alias)` | `MIN`/`MAX` over a `double` expression. |
| `minText` / `maxText` | `Min<TomDbString, String> minText(TomOperator<TomDbString> value, String alias)` | `MIN`/`MAX` over a `String` expression. |
| `minDateTime` / `maxDateTime` | `Min<TomDbDateTime, DateTime> minDateTime(TomOperator<TomDbDateTime> value, String alias)` | `MIN`/`MAX` over a timestamp expression. |
| `minDate` / `maxDate` | `Min<TomDbDate, DateTime> minDate(TomOperator<TomDbDate> value, String alias)` | `MIN`/`MAX` over a date expression. |
| `minTime` / `maxTime` | `Min<TomDbTime, DateTime> minTime(TomOperator<TomDbTime> value, String alias)` | `MIN`/`MAX` over a time-of-day expression. |

`min`/`max` are split by type rather than left generic because they preserve the
operand's type on both sides (SQL and Dart); `sum`/`avg` always widen to `double`
and so need no such split.

The date and time variants project a plain `DateTime` rather than a
`TomZonedDate` / `TomZonedTime`: it is the widest type that accepts both the
driver's own reading of the column and the kernel half-instant, which extends
it. Writing the two type arguments out at a call site instead of using these
factories is what `grouped_query.dart` warns against — the pair must agree, and
only the factory guarantees it.

#### TomQuerySentenceCompiler

Compiles a Spring-Data-style query sentence (e.g. `find by name = :name order by
age desc`) into a `TomQuery` (`TomSelect` / `TomCount` / `TomDelete` /
`TomGroupedSelect`).

- **Extends:** `TomTypedPersistenceBase`
- **Mixes in:** `TomQueryBuilder`

##### Constructors

```dart
TomQuerySentenceCompiler(List<Type> types)
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `compileQuerySentence` | `TomQuery compileQuerySentence(String qs)` | Parses query sentence `qs` into a `TomSelect`, `TomCount`, `TomDelete` or `TomGroupedSelect`. Throws `TomQuerySyntaxException` for a malformed sentence. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `comparable` | `static TomColumnInformation comparable(TomColumnInformation column, String statement)` | `column`, unless it is `@TomEncrypted`: then throws `TomQuerySyntaxException` `query_sentence_compiler.encrypted_column` naming `statement`. Called for every condition operand, group key, aggregate and sort term. |

The kind is the first word: `find` / `count` / `delete` / `group`. The `group`
sentence carries an aggregate projection and an optional `over <fields>` group
key before `by`, and accepts a `having <predicate>` clause after it:

```text
group count ( * ) as total , sum ( amount ) as revenue over status
  by createdAt >= :from having total > :minCount order by total desc
```

`having` addresses the projection **by alias**; the `by` predicate addresses
columns. Omitting `over` aggregates the whole filtered set into one row.

The window options `top N` / `first N` (the cap) and `skip M` / `offset M` (the
skip) precede `by`; the two spellings of each are synonyms and naming both is
rejected. A skip needs a cap, and only `find` and `group` accept one. The trailing
`order by` clause takes a direction per field, each keyword applying back to the
previous one — `order by a b desc` sorts both descending, `order by a desc b asc`
mixes them, and an undirected field sorts ascending.

A predicate term may name a field of an association — a `@TomReference` field
of the queried entity — as `<association>.<field> <test>`, or test the
association as `<association> is empty` / `is not empty`. The term compiles to a
correlated `EXISTS (SELECT 1 FROM <join>, <target> WHERE …)` whose conditions
are the association's `leftSideColumns` and `rightSideColumns` as column
comparisons plus the test on the target's column, so an owning row is answered
once however many associated rows match; `is empty` is the `NOT EXISTS` of the
join alone. A leading `not` negates the whole term. It is accepted in `find`,
`count` and `delete` sentences. Refusals, as `TomQuerySyntaxException`:
`query_sentence_compiler.association.no_field` (the association without a field),
`.unknown_field` (a field the target does not map), `.context_columns` (an
association declaring `contextColumns`, which only a load can bind),
and `.self_reference` (a join or target table that is the queried table). A
join term with no `=`, or naming no column, is refused by the column lookup with
`annotation_analyzer.determine_column.no_column_match`.

#### TomSubquery

`SELECT <projection or 1> FROM <the tables of types> WHERE (<where>)` — the
subquery `TomExists` and `TomInSubquery` test. A column renders as
`table.column`, so `where` may name a column of the enclosing query's table and
correlate with it; a subquery over the enclosing query's own table cannot
correlate, as the tree has no aliases. Every `@TomSoftDelete` type read adds
`<table>.<deleted> IS NULL` as a condition of its own, unless
`TomSoftDelete.includingDeleted` is on. Its types are all tenant tables or all
system tables (`annotation_analyzer.tenant_table.mixed` otherwise), and every
tenant table read adds `<tenant column> IN (:__tomtenant_0)`, bound to the
enclosing tenant-table query's tenant.

##### Constructors

```dart
TomSubquery(List<Type> types, {TomOperator<TomDbBool>? where, TomOperator<Object?>? projection})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `types` | `List<Type>` | The entity types read (final). |
| `where` | `TomOperator<TomDbBool>?` | The predicate over their rows, or `null` for all of them (final). |
| `projection` | `TomOperator<Object?>?` | The selected column, or `null` for `1` (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | The subquery's SQL, through the dialect's `subquery`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | Its parameters in the order their placeholders appear: the projection's, the `where`'s, then the tenant predicate's. |
| `toString` | `String toString()` | `TomSubquery(<types>, <where>)`. |
| `within` | `static List<TomSubquery> within(TomOperator? predicate)` | The subqueries `predicate` contains, nested ones included — what a repository checks against its own entity's classification. |

#### TomExists

`EXISTS (<subquery>)`. Opaque to the walks over the enclosing tree: it has no
`children` and reports no fields, because the columns inside it are the
subquery's. Its parameters are the enclosing statement's all the same, and
`getParameters` reports them in place.

- **Extends:** `TomOperator<TomDbBool>`

##### Constructors

```dart
TomExists(TomSubquery subquery)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subquery` | `TomSubquery` | The subquery (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | `EXISTS (<subquery>)`, through the dialect's `exists`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | The subquery's parameters. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | Always empty. |
| `analyze` | `String analyze(int l)` | The node's line in a tree dump. |

#### TomInSubquery&lt;T&gt;

`<operand> IN (<subquery>)`; the subquery's projection is the column compared.
Its one child is `operand`, and it reports `operand`'s fields only.

- **Extends:** `TomOperator<TomDbBool>`

##### Constructors

```dart
TomInSubquery(TomOperator<T> operand, TomSubquery subquery)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `operand` | `TomOperator<T>` | The value tested (final). |
| `subquery` | `TomSubquery` | The subquery; its projection is the column compared (final). |
| `children` | `List<TomOperator>` | *(getter)* `[operand]`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | `<operand> IN (<subquery>)`, through the dialect's `inSubquery`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | The operand's parameters, then the subquery's. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | The operand's fields. |
| `analyze` | `String analyze(int l)` | The node's line in a tree dump. |

### Paging & Sorting

#### TomSortDirection

The direction one sort term orders in. It is written up here, beside the
`TomSortField` that carries it, because a direction is only ever met as one
term's direction.

##### Enum Values

| Value | `sqlKeyword` | Meaning |
| ----- | ------------ | ------- |
| `ascending` | `ASC` | Smallest value first. |
| `descending` | `DESC` | Largest value first. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlKeyword` | `String` | *(getter)* The SQL keyword for this direction — the column above. It is the only rendering of the enum, so a dialect never spells `ASC`/`DESC` itself. |

#### TomSortField

One term of a sort: a `field` and the `direction` it orders in. A sort is an
*ordered list* of these rather than a field list plus one shared flag, because
`ORDER BY priority DESC, due_date ASC` cannot be expressed by a direction every
column has to agree on.

##### Constructors

```dart
const TomSortField(String field, {TomSortDirection direction = TomSortDirection.ascending})
const TomSortField.asc(String field)
const TomSortField.desc(String field)
```

##### Properties and Methods

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `field` | `String` | The field name, or — once resolved — the column expression to sort on. |
| `direction` | `TomSortDirection` | The direction `field` orders in. |
| `isAscending` | `bool` | *(getter)* Whether this term orders ascending. |
| `withField` | `TomSortField withField(String resolved)` | This term with `field` replaced, keeping the direction — how a declared name becomes a qualified column expression. |
| `withDirection` | `TomSortField withDirection(TomSortDirection direction)` | This term ordering in `direction` instead. |
| `allOf` | `static List<TomSortField> allOf(List<String> fields, {TomSortDirection direction})` | Maps `fields` onto terms that all order in `direction`. |

#### TomPageRequest

A caller's request for one window of a result set: `offset` rows in, at most
`limit` rows wide, ordered by `sort`. It is the only paging vocabulary the
repository speaks, and is passed to the finders as an optional argument rather
than duplicating them into a paged family.

##### Constructors

```dart
TomPageRequest({int offset = 0, int limit = 0, List<TomSortField> sort = const []})
TomPageRequest.page(int pageNumber, int pageSize, {List<TomSortField> sort = const []})
TomPageRequest.sorted(List<TomSortField> sort)
```

Throws `TomQuerySyntaxException` for a negative bound, or for an `offset` without
a `limit` — MariaDB's grammar is `LIMIT n [OFFSET m]`, so there is no bare
`OFFSET` and the skip would be silently dropped.

##### Properties and Methods

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `offset` | `int` | Rows to skip before the first returned row. |
| `limit` | `int` | The maximum number of rows to return; `0` means unbounded. |
| `sort` | `List<TomSortField>` | The ordering the window is cut from, outermost term first. |
| `isUnpaged` | `bool` | *(getter)* Whether this request shapes nothing at all. |
| `needsStableSort` | `bool` | *(getter)* Whether this request cuts a window, and so needs a total ordering to be reproducible across pages. |
| `withSort` | `TomPageRequest withSort(List<TomSortField> sort)` | This request with `sort` replaced. |
| `stableUnder` | `TomPageRequest stableUnder(List<String> keys)` | This request with every field of `keys` it does not already sort on appended as an ascending sort term, in key order, when it cuts a window; otherwise itself. |
| `assertWindow` | `static void assertWindow({required int limit, required int offset})` | Rejects a row window that is not renderable. |

**The result is the page, not a page object.** A finder given a request returns
the rows of that window as a plain `List<T>`; the total comes from the matching
`count` method, which applies the same row scope — so a caller that does not need
the total does not pay for it, and page metadata never reports rows the principal
may not see. When a window is requested and the caller's `sort` does not already
settle the order, the repository appends the entity's primary key ascending
(`stableUnder`), so consecutive pages neither repeat nor drop rows.

### Operators & Expressions

All operators extend the kernel/datasource `TomOperator<R>` and override
`generate` / `getParameters` / `getFields` / `analyze` to render their SQL and
contribute their bound parameters and referenced fields.

#### TomUnaryOperator&lt;T, R&gt;

A `TomOperator` with a single operand. Base class for literals, columns,
`IS NULL`, `NOT`, and `AND`/`OR` over a list.

- **Extends:** `TomOperator<R>`
- **Type Parameters:** `T` — the operand type; `R` — the SQL result type.

##### Constructors

```dart
TomUnaryOperator(T operant1)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `operant1` | `T` | The single operand. |
| `children` | `List<TomOperator>` | *(getter)* *(override)* `operant1`'s operand children — the operands that are themselves operators, which `getParameters` and `getFields` recurse over. A plain value contributes none. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* The bound parameter names contributed by the operand. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(override)* The columns referenced by the operand. |
| `analyze` | `String analyze(int l)` | *(override)* A debug rendering of the operator tree. |

#### TomBinaryOperator&lt;T1, T2, R&gt;

A `TomOperator` with two operands. Base class for comparisons, `LIKE`/`NOT
LIKE`/`REGEXP`, `IN`, and `BETWEEN`.

- **Extends:** `TomOperator<R>`
- **Type Parameters:** `T1` — the left operand type; `T2` — the right operand type; `R` — the SQL result type.

##### Constructors

```dart
TomBinaryOperator(T1 operant1, T2 operant2)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `operant1` | `T1` | The left operand. |
| `operant2` | `T2` | The right operand. |
| `children` | `List<TomOperator>` | *(getter)* *(override)* Both operands' operator children, left before right, which `getParameters` and `getFields` recurse over in that order. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* The bound parameter names contributed by both operands. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(override)* The columns referenced by both operands. |
| `analyze` | `String analyze(int l)` | *(override)* A debug rendering of the operator tree. |

#### Parameter&lt;T&gt;

A named positional parameter placeholder (`:name`), rendered via the dialect,
contributing its `name` to the statement's parameter list.

- **Extends:** `TomOperator<T>`

##### Constructors

```dart
Parameter(String name)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The parameter name (without the leading `:`). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | *(override)* Renders the placeholder. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* `[name]`. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(override)* The empty set (references no columns). |
| `analyze` | `String analyze(int l)` | *(override)* A debug rendering. |

#### DbCol&lt;R&gt; and column references

`DbCol<R>` is the abstract base for a reference to a database column, carrying its
`columnInformation` and owning `tableType`, rendered as a qualified
`table.column`. The concrete subclasses select the SQL type.

- **`DbCol<R>`** — **Extends:** `TomUnaryOperator<String, R>`

##### Constructors (DbCol)

```dart
DbCol(Type tableType, String operant1, TomColumnInformation columnInformation)
```

##### Properties (DbCol)

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columnInformation` | `TomColumnInformation` | The resolved metadata for the referenced column. |
| `tableType` | `Type` | The entity type that owns the column. |

##### Concrete column references

| Class | Extends | Renders |
| ----- | ------- | ------- |
| `IntCol` | `DbCol<TomDbInt>` | An `int` column reference. |
| `StringCol` | `DbCol<TomDbString>` | A `String` column reference. |
| `DoubleCol` | `DbCol<TomDbDouble>` | A `double` column reference. |
| `BoolCol` | `DbCol<TomDbBool>` | A `bool` column reference. |
| `DateTimeCol` | `DbCol<TomDbDateTime>` | A timestamp column reference. |
| `DateCol` | `DbCol<TomDbDate>` | A date column reference. |
| `TimeCol` | `DbCol<TomDbTime>` | A time-of-day column reference — the sibling of `DateCol` for the other half a timestamp splits into. A `TIME` column names a position within a day and no day at all, so it is neither a date nor a timestamp. |

Each takes the constructor `(Type tableType, String operant1, TomColumnInformation columnInformation)`.

#### Literals

Each literal wraps a Dart value and renders it through the dialect.

| Class | Extends | Constructor | Renders |
| ----- | ------- | ----------- | ------- |
| `StringLiteral` | `TomUnaryOperator<String, TomDbString>` | `StringLiteral(String operant1)` | A single-quoted string literal. |
| `IntegerLiteral` | `TomUnaryOperator<int, TomDbInt>` | `IntegerLiteral(int operant1)` | An integer literal. |
| `DoubleLiteral` | `TomUnaryOperator<double, TomDbDouble>` | `DoubleLiteral(double operant1)` | A double literal. |
| `BoolLiteral` | `TomUnaryOperator<bool, TomDbBool>` | `BoolLiteral(bool operant1)` | A boolean literal: a value compared with a truth column, through `boolOp`. |
| `TruthPredicate` | `TomUnaryOperator<bool, TomDbBool>` | `TruthPredicate(bool operant1)` | A constant truth value used as a predicate in its own right, through the dialect's `truthPredicate` — the `WHERE` of a scope that admits nothing. Distinct from `BoolLiteral` because the two read alike on MariaDB and differently on PostgreSQL, where a truth column is a `SMALLINT` (a value is `1`/`0`) and a predicate has to be a boolean (`TRUE`/`FALSE`). |
| `DateTimeLiteral` | `TomUnaryOperator<DateTime, TomDbDateTime>` | `DateTimeLiteral(DateTime operant1)` | A timestamp literal. |
| `DateLiteral` | `TomUnaryOperator<DateTime, TomDbDate>` | `DateLiteral(DateTime operant1)` | A date literal. |
| `TimeLiteral` | `TomUnaryOperator<DateTime, TomDbTime>` | `TimeLiteral(DateTime operant1)` | A time-of-day literal. Holds a `DateTime` rather than a `TomZonedTime`, as `DateLiteral` does: a `TomZonedTime` *is* a `DateTime`, so the wider operand accepts both a kernel time value and a plain one built for the epoch day, and only the clock components are read out when it renders. |

#### Logical & comparison operators

Each overrides `generate` to render its SQL.

| Class | Extends | Constructor | Renders |
| ----- | ------- | ----------- | ------- |
| `Not` | `TomUnaryOperator<TomOperator<TomDbBool>, TomDbBool>` | `Not(TomOperator<TomDbBool> operant1)` | `NOT <operand>`. |
| `IsNull<T>` | `TomUnaryOperator<TomOperator<T>, TomDbBool>` | `IsNull(TomOperator<T> operant1)` | `<operand> IS NULL`. |
| `IsNotNull<T>` | `TomUnaryOperator<TomOperator<T>, TomDbBool>` | `IsNotNull(TomOperator<T> operant1)` | `<operand> IS NOT NULL`. |
| `And` | `TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool>` | `And(List<TomOperator<TomDbBool>> operant1)` | Operands joined with ` AND `. |
| `Or` | `TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool>` | `Or(List<TomOperator<TomDbBool>> operant1)` | Operands joined with ` OR `. |
| `Eq<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Eq(operant1, operant2)` | `<a> = <b>`. |
| `Neq<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Neq(operant1, operant2)` | `<a> <> <b>`. |
| `Lt<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Lt(operant1, operant2)` | `<a> < <b>`. |
| `Gt<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Gt(operant1, operant2)` | `<a> > <b>`. |
| `Lte<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Lte(operant1, operant2)` | `<a> <= <b>`. |
| `Gte<T>` | `TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool>` | `Gte(operant1, operant2)` | `<a> >= <b>`. |
| `Like` | `TomBinaryOperator<TomOperator<TomDbString>, TomOperator<TomDbString>, TomDbBool>` | `Like(operant1, operant2)` | `<text> LIKE <pattern>`. |
| `NotLike` | `TomBinaryOperator<TomOperator<TomDbString>, TomOperator<TomDbString>, TomDbBool>` | `NotLike(operant1, operant2)` | `<text> NOT LIKE <pattern>`. |
| `Regexp` | `TomBinaryOperator<TomOperator<TomDbString>, TomOperator<TomDbString>, TomDbBool>` | `Regexp(operant1, operant2)` | `<text> REGEXP <pattern>`. |
| `In<T>` | `TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool>` | `In(operant1, operant2)` | `<a> IN (<choices...>)`. |
| `Between<T>` | `TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool>` | `Between(TomOperator<T> operant1, List<TomOperator<T>> operant2)` | `<a> BETWEEN <lo> AND <hi>`; throws `TomQuerySyntaxException` if not exactly two bounds. |
| `Group<T>` | `TomUnaryOperator<TomOperator<T>, T>` | `Group(TomOperator<T> operant1)` | `( <operand> )`. |

### Grouping & Aggregation

`grouped_query.dart`. Where the operators above describe *rows*, these describe
*groups*: rows collapsed by one or more key columns with an aggregate value per
group. A grouped query is a separate compiled sentence rather than an option on
`TomSelect` because its result is a different shape — `TomGroupedRow`s, not
entities.

#### TomAggregate&lt;R, V&gt;

An aggregate function applied to a group: `COUNT(*)`, `SUM(t.amount)`,
`MAX(t.created)`. Abstract; the concrete nodes are listed below and are normally
built through the `TomQueryBuilder` factories.

- **Extends:** `TomOperator<R>` — so an aggregate composes with the ordinary
  predicates, which is what makes `HAVING COUNT(*) > 3` expressible.
- **Type Parameters:** `R` — the SQL type of the result; `V` — the Dart type the
  value materialises as.

##### Constructors

```dart
TomAggregate(
  TomAggregateFunction function,
  TomOperator? operand,
  String alias, {
  bool distinct = false,
})
```

Throws `TomQuerySyntaxException` when `alias` is not a plain SQL identifier
(`^[A-Za-z_][A-Za-z0-9_]*$`), or when `V` is not one of `int`, `double`,
`String`, `bool`, `DateTime`. The alias is written into the statement text rather
than bound — it names a result column — so validating it at construction closes
the one injection surface a grouped query adds.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `function` | `TomAggregateFunction` | The SQL function this node renders. |
| `operand` | `TomOperator?` | The expression being aggregated; `null` for the argument-less `COUNT(*)`. |
| `distinct` | `bool` | Whether to aggregate over distinct operand values. |
| `alias` | `String` | The result-column name this aggregate is projected under. |
| `valueType` | `Type` | *(late final)* The Dart type `V`, captured at construction so the result mapper can read the column without a type argument. |
| `children` | `List<TomOperator>` | *(override)* The operand, or empty. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | *(override)* Renders the call via the dialect's `aggregate` fragment. |
| `generateProjection` | `SqlString generateProjection(TomStandardSqlDialect t)` | The projected form, `<function>(<operand>) AS <alias>`. |
| `read` | `V? read(TomGroupedRow row)` | This aggregate's value in `row`, typed as `V`, or `null` when the group produced no value (an aggregate over an all-null column). |

#### The aggregate nodes

| Class | Extends | Constructor | Renders / value type |
| ----- | ------- | ----------- | -------------------- |
| `CountAll` | `TomAggregate<TomDbInt, int>` | `CountAll(String alias)` | `COUNT(*)` — the number of rows in the group, including rows whose columns are `NULL`. |
| `Count<T>` | `TomAggregate<TomDbInt, int>` | `Count(TomOperator<T> value, String alias, {bool distinct = false})` | `COUNT([DISTINCT] v)` — the number of non-null values. |
| `Sum<T>` | `TomAggregate<TomDbDouble, double>` | `Sum(TomOperator<T> value, String alias, {bool distinct = false})` | `SUM(v)`, always a `double`. |
| `Avg<T>` | `TomAggregate<TomDbDouble, double>` | `Avg(TomOperator<T> value, String alias, {bool distinct = false})` | `AVG(v)`, always a `double`. |
| `Min<R, V>` | `TomAggregate<R, V>` | `Min(TomOperator<R> value, String alias)` | `MIN(v)`, preserving the operand's SQL and Dart types. |
| `Max<R, V>` | `TomAggregate<R, V>` | `Max(TomOperator<R> value, String alias)` | `MAX(v)`, preserving the operand's SQL and Dart types. |

`CountAll` and `Count` answer different questions: `COUNT(*)` counts rows,
`COUNT(column)` counts non-null values, so a group whose column is entirely
`NULL` yields the row count from the first and `0` from the second.

`Sum` and `Avg` widen to `double` because SQL widens a sum to an exact-numeric
type (MariaDB returns `DECIMAL` for an integer column), which does not round-trip
through Dart's `int`. Widening once, in the node, keeps the value type
predictable instead of dialect-dependent. `Min`/`Max` do not widen — an extremum
is one of the operand's own values — so prefer the typed builder factories
(`minInt`, `minText`, …) over naming both type arguments.

#### TomGroupedSelect

A `SELECT … GROUP BY …` over the entity types: the group-key columns and the
aggregate projection, filtered by a row predicate (`WHERE`) and a group predicate
(`HAVING`).

- **Extends:** `TomGeneratedQuery`

##### Constructors

```dart
TomGroupedSelect(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  List<DbCol> groupBy = const [],
  required List<TomAggregate> aggregates,
  TomOperator<TomDbBool>? having,
  List<String> orderBy,
  bool ascending,
  List<TomSortField>? sort,
  int top,
  int offset,
})
```

Throws `TomQuerySyntaxException` when no aggregate is given (a grouped select
with none is a `DISTINCT` select, which `TomSelect` already expresses), when two
projections share an alias, when a group column's type cannot be materialised, or
when a sort term is not a projection alias.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `groupBy` | `List<DbCol>` | The key columns. May be empty, which aggregates the whole filtered set into exactly one row. |
| `aggregates` | `List<TomAggregate>` | The projected aggregates; at least one is required. |
| `having` | `TomOperator<TomDbBool>?` | The group predicate, evaluated after aggregation. |
| `projectionAliases` | `List<String>` | *(getter)* The result-column names, group keys first: a group column under its declared field name, an aggregate under its alias. |
| `projectionTypes` | `Map<String, Type>` | *(getter)* The Dart type each projected column materialises as, keyed by alias — the only type information a grouped row has. |
| `referencedColumns` | `Set<TomColumnInformation>` | *(getter)* Every column read outside an aggregate: the group keys plus the columns `WHERE` and `HAVING` reference directly. The repository uses this to refuse a query touching a column the principal may not read (C-4). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders the full statement. Rejects a `HAVING` on a bare column that is neither a group key nor inside an aggregate (`grouped_query.select.having_on_ungrouped_field`) — such a predicate has many values per group and databases differ on whether they refuse it or silently pick a row. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* Parameters in statement-text order — projection, `WHERE`, then `HAVING`. The order is load-bearing: placeholders bind positionally. |
| `columnsOf` | `static Set<TomColumnInformation> columnsOf(TomOperator node)` | Every `DbCol` reachable from `node`, descending through aggregates. |

`WHERE` and `HAVING` stay separate all the way down to the dialect for the same
reason they are separate in SQL: `WHERE` filters rows before aggregation,
`HAVING` filters groups after it, and ANDing them would change the meaning of
both. The C-3 row scope is therefore ANDed into `WHERE`, never `HAVING` —
filtering groups afterwards would still have counted the hidden rows.

#### TomGroupedRow

One row of a grouped result: the group-key values plus the aggregate values, each
under the alias the query projected it as. Deliberately not an entity — a grouped
row's shape is decided by the query, so there is no entity class it could map
onto.

##### Constructors

```dart
TomGroupedRow(Map<String, Object?> values)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `values` | `Map<String, Object?>` | Every value in the row, keyed by its projection alias (unmodifiable). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `has` | `bool has(String alias)` | Whether the row carries a value (possibly `null`) under `alias`. |
| `value` | `Object? value(String alias)` | The raw value. Throws `TomQuerySyntaxException` (`grouped_query.row.unknown_alias`) when the row has no such alias. |
| `intValue` | `int? intValue(String alias)` | The value as an `int`. |
| `doubleValue` | `double? doubleValue(String alias)` | The value as a `double`. |
| `stringValue` | `String? stringValue(String alias)` | The value as a `String`. |
| `boolValue` | `bool? boolValue(String alias)` | The value as a `bool` (MariaDB stores booleans as `1`/`0`). |
| `dateTimeValue` | `DateTime? dateTimeValue(String alias)` | The value as a **UTC** `DateTime`. A read path like any other: column text goes through `parseSqlInstant`, and a value that is already a `DateTime` is relabelled with `toUtc` rather than reparsed — the same moment, in the frame every other read path answers in. A second reading of the same text would be a second convention, differing by the machine's UTC offset with no error and no type difference; see `datasources/sql_instant.dart`. |
| `typed` | `V? typed<V>(String alias)` | The value coerced to `V` — the accessor `TomAggregate.read` and `keyOf` use, so a caller never names a type twice. Throws for an unsupported `V`. |
| `keyOf` | `Object? keyOf(DbCol column)` | The group-key value for `column`, which a grouped query projects under the column's declared field name. |

An unknown alias **throws** rather than yielding `null`, because `null` is a real
answer here — an aggregate over an all-null column is `null` — and a typo must
not be indistinguishable from it.

A conversion that cannot succeed raises
`grouped_query.row.value_conversion_failed`; an unsupported declared type raises
`grouped_query.row.unsupported_value_type`.

### Authorization & Scoping

#### TomColumnWriteDecision&lt;C&gt;

The write outcome for a set of authorized columns `C`: which the caller may write
(grade `full`) and which must be preserved from the baseline.

- **Type Parameters:** `C` — the abstract column token type.

##### Constructors

```dart
const TomColumnWriteDecision(List<C> writable, List<C> preserved)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `writable` | `List<C>` | Columns the caller may write — their incoming value is persisted. |
| `preserved` | `List<C>` | Columns the caller may not write — the baseline value is persisted instead. |

#### TomColumnAuthorization

The C-4 decision algorithm, pure over abstract column tokens, plus the
reflection-backed read-mask. All members are static.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `stateForKey` | `static TomAuthState stateForKey(String? authKey, {TomColumnAuthResolver? resolver})` | The `TomAuthState` the principal holds on the column identified by `authKey`, or `full` when `authKey` is `null` or the database tier is off (`TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection`). Without a `resolver` it grades through `TomResourceKeyProtection.automaticState` — the installed adapter's grade met with the request principal's resource-key grade. |
| `maskedColumns` | `static List<C> maskedColumns<C>({required Iterable<C> columns, required String? Function(C) keyOf, TomColumnAuthResolver? resolver})` | The subset of `columns` the principal may not see (grade lacks `showsContent`). |
| `decideWrites` | `static TomColumnWriteDecision<C> decideWrites<C>({required Iterable<C> columns, required String? Function(C) gradeOf, required bool Function(C) changed, required Never Function(C column, String authKey, TomAuthState grade) onForbidden, TomColumnAuthResolver? resolver})` | Partitions `columns` into writable vs preserved, rejecting an unauthorized visible change. |
| `applyReadMask` | `static T applyReadMask<T extends Object>(T instance, List<TomColumnInformation> columns, {TomColumnAuthResolver? resolver})` | Nulls out — in place — every masked field of `instance` (skipping per-row-graded columns); returns `instance`. |

#### TomRowColumnAuthorization

Per-row column grades (C-4), for columns whose grade depends on *which row* is
addressed. The column-grade counterpart of `TomDataScopeRegistry.registerAsync`:
a resolver is registered once at boot against the column's `authKey` and awaited
per operation with the current-zone principal and the row's id. Only the file
operations (`saveFile` / `openFile` / `describeFile`) consult it — they address
exactly one row and are already asynchronous. All members are static.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String authKey, TomRowColumnAuthResolver resolver)` | Registers (or replaces) the per-row grade source for `authKey`. |
| `isRegistered` | `static bool isRegistered(String? authKey)` | Whether `authKey` has a per-row resolver — the read mask skips such columns. |
| `resolve` | `static Future<TomAuthState?> resolve(String? authKey, Object? rowId)` | The per-row grade, or `null` when the column is unrestricted or has no resolver; `full`, without consulting the resolver, while the database tier is off. |
| `reset` | `static void reset()` | Clears every registration (tests, re-boot). |

#### TomResourceScopeSource

The grant-driven source behind the built-in `resource` scope kind
(`TomDbScope.resourceScope`), which filters rows by the resource keys a principal
holds a grant for — direct ownership grants folded with the share/absence
delegations active right now.

Resolving that needs the authorization layer (grant store, delegation resolver,
role registry), which sits *above* persistence. This interface is the inversion
that keeps the dependency pointing the right way: `object_persistence` declares
the hook, `authorization` implements and installs it
(`TomResourceDataScope.install`). While no source is installed the built-in
resolver denies every row — an unwired scope must be a closed door, not an open
one.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `readableResourceKeys` | `Future<List<Object?>> readableResourceKeys(TomPrincipal? principal)` | The resource keys `principal` may **read** — grade `read` or `full`. |
| `writableResourceKeys` | `Future<List<Object?>> writableResourceKeys(TomPrincipal? principal)` | The resource keys `principal` may **write** — grade `full` only, so a `read` grant admits a row to queries but rejects every write to it. |

#### TomDataScopeRegistry

Registry of the named row-scope resolvers a `@TomDbScope` can reference. Three
resolvers ship out of the box: `'owner'` (the principal's own tenant-qualified id, `principal.qualifiedId`), `'group'` (the
principal's groups) — both synchronous, and both showing a `null` principal
nothing — and `'resource'` (`TomDbScope.resourceScope`), which resolves
asynchronously through the installed `resourceScopeSource` and denies every row
while no source is installed. All members are static.

A scope kind is either a synchronous single-`IN` scope or an asynchronous
union/OR scope over several id-sets, never both; `isAsync` is the one seam that
tells the repository which path to take. Each kind may additionally register a
**write** resolver, answering the narrower question "which values may this
principal *modify*" — a kind with no write resolver writes exactly what it reads.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String scope, TomDataScopeResolver resolver, {TomDataScopeResolver? write})` | Registers (or replaces) the synchronous resolver for scope kind `scope`, optionally with a narrower `write` resolver naming the values the principal may modify. |
| `registerAsync` | `static void registerAsync(String scope, TomAsyncDataScopeResolver resolver, {TomAsyncDataScopeResolver? write})` | Registers (or replaces) the asynchronous (union/OR) resolver for `scope`, optionally with a narrower `write` resolver. |
| `resolverFor` | `static TomDataScopeResolver? resolverFor(String scope)` | The synchronous resolver for `scope`, or `null`. |
| `writeResolverFor` | `static TomDataScopeResolver? writeResolverFor(String scope)` | The synchronous **write** resolver for `scope`, or `null` when the kind writes exactly what it reads. |
| `asyncResolverFor` | `static TomAsyncDataScopeResolver? asyncResolverFor(String scope)` | The asynchronous resolver for `scope`, or `null`. |
| `asyncWriteResolverFor` | `static TomAsyncDataScopeResolver? asyncWriteResolverFor(String scope)` | The asynchronous **write** resolver for `scope`, or `null` when the kind writes exactly what it reads. |
| `isAsync` | `static bool isAsync(String scope)` | Whether `scope` resolves asynchronously (registered via `registerAsync`). |
| `reset` | `static void reset()` | Restores the built-in resolvers, discarding custom registrations (synchronous *and* asynchronous, read *and* write). Deliberately does **not** clear `resourceScopeSource`, which is deployment wiring rather than a scope-kind registration. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resourceScopeSource` | `TomResourceScopeSource?` | *(static)* The installed grant source backing the built-in `resource` scope kind, or `null` while none is installed — in which case the scope denies every row. Installed by `TomResourceDataScope.install` from the authorization layer. |

#### TomDataScopePredicate

A resolved row-scope predicate: the boolean predicate to AND into a query's
`WHERE`, plus the parameters it binds.

##### Constructors

```dart
TomDataScopePredicate(TomOperator<TomDbBool> predicate, Map<String, Object?> parameters)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `predicate` | `TomOperator<TomDbBool>` | The predicate (`<field> IN (…)` or a `FALSE` deny literal). |
| `parameters` | `Map<String, Object?>` | The bind values for the predicate's parameters, keyed by placeholder name. |

#### TomDataScopeBypass

A zone marker that suppresses row-scope resolution for the reads performed inside
it (installed by `TomDataScope.runUnscoped`).

##### Constructors

```dart
const TomDataScopeBypass()
```

#### TomDataScope

Builds the row-scope predicate for an entity's `@TomDbScope` from the current
principal's allowed values, one bound parameter per value. All members are
static.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `runUnscoped` | `static Future<T> runUnscoped<T>(Future<T> Function() body)` | Runs `body` with row-scope resolution suppressed (the guard against resolver recursion). |
| `build` | `static TomDataScopePredicate? build(TomQueryBuilder builder, TomDbScope scope, TomColumnInformation col, TomPrincipal? principal)` | Builds the scope predicate for a synchronous scope; `null` when the resolver opts out. |
| `buildAsync` | `static Future<TomDataScopePredicate?> buildAsync(TomQueryBuilder builder, TomDbScope scope, TomColumnInformation col, TomPrincipal? principal)` | Builds the union scope predicate for an async scope. |
| `anyOf` | `static TomDataScopePredicate anyOf(TomQueryBuilder builder, TomColumnInformation col, List<List<Object?>> groups)` | The union predicate over id-set groups: an OR of one `IN` list per group. |
| `inList` | `static TomDataScopePredicate inList(TomQueryBuilder builder, TomColumnInformation col, Iterable<Object?> values, {String prefix = parameterPrefix})` | Builds `<col> IN (…)` binding one parameter per value, in `col`'s type: on an `int` column a value given as text is bound as the number it spells, and one that spells no number (a tenant-qualified id) is left out — it matches no row. |
| `allowedValues` | `static List<Object?>? allowedValues(TomDbScope scope, TomPrincipal? principal)` | Resolves the scope-field values `principal` is allowed for a **synchronous** `scope`. |
| `allowedValuesAsync` | `static Future<List<Object?>?> allowedValuesAsync(TomDbScope scope, TomPrincipal? principal, {bool forWrite = false})` | The same for an **async** scope, flattening the resolver's OR-groups into one membership set. The read path keeps the groups apart because each renders its own `IN` list; a membership check only asks whether the value is in *any* group. `null` (the resolver opted out) passes through, so the result feeds `permits` exactly as `allowedValues` does. |
| `permits` | `static bool permits(List<Object?>? allowed, Object? value)` | Whether `value` falls within the `allowed` scope values (C-3 write membership). Values compare by their text, as the read side binds them: an `int` owner column holding `7` belongs to the principal whose id is `'7'`. |
| `inColumn` | `static TomOperator<TomDbBool> inColumn(TomQueryBuilder builder, TomColumnInformation col, List<String> parameterNames)` | Builds `<col> IN (:name0, …)` against one bound parameter per name. |
| `columnEqualsParam` | `static TomOperator<TomDbBool> columnEqualsParam(TomQueryBuilder builder, TomColumnInformation col, String parameterName)` | Builds `<col> = :parameterName`, typed on the column's declared Dart type. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `parameterPrefix` | `static const String` | The prefix of the generated scope parameter names (`__tomscope_`). |
| `isBypassed` | `static bool` | *(getter)* Whether the current zone suppresses row-scope resolution. |

### Analyzer

#### TomAnnotationAnalyzer

Resolves the persistence metadata of an entity type from its reflection
annotations. A mixin whose members are all static; every lookup is memoised in
one of the seven per-type caches below.

Three of its members are not lookups but *policy*: `resourceKeyColumn`,
`resourceKeyField` and `resourceScopeInputTables` are what make grant-driven
scoping the default rather than an annotation anyone has to remember — see
`autoScopeFor`.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analysePersistentType` | `static TomTypePersistenceInfo analysePersistentType(Type T)` | Resolves the full persistence metadata (table + columns) for entity `T`. Throws `TomAnnotationAnalyzerException` when the type is not reflectable or has no `@TomDbTable`, and lets its lookups' `TomAnnotationAnalyzerSyntaxException` through unchanged. |
| `findMirror` | `static ClassMirror? findMirror(Type dbType)` | The cached/looked-up `ClassMirror` for `dbType`, or `null` when — and only when — `dbType` is not registered with `tomReflector`. Every other reflection failure is thrown as `TomAnnotationAnalyzerException`; see *Reflection failures*. |
| `findTable` | `static TomDbTable? findTable(Type dbType)` | The `@TomDbTable` annotation on `dbType`, or `null` if absent. |
| `findTenantTable` | `static TomTenantTable? findTenantTable(Type dbType)` | The entity's `@TomTenantTable`, or `null` for a system table. Memoised, `null` included, and cleared by `reset`. |
| `isTenantTable` | `static bool isTenantTable(Type dbType)` | Whether `dbType` is a tenant table; every other entity is a system table. |
| `tenantTables` | `static Map<Type, TomDbTable> tenantTables()` | Every reflected `@TomDbTable` entity marked `@TomTenantTable`, with its table — what `TomTenancy.tenantTables` reports. |
| `verifySameClassification` | `static void verifySameClassification(Iterable<Type> types, String what)` | Throws `annotation_analyzer.tenant_table.mixed` unless every one of `types` is of one kind; `what` names the construct that would join them. |
| `findDataScope` | `static TomDbScope? findDataScope(Type dbType)` | The row scope of `dbType`, or `null` when unscoped. An explicit `@TomDbScope` wins — including `@TomDbScope.unscoped()`, for which this returns `null`; failing that, `autoScopeFor` decides. |
| `autoScopeFor` | `static TomDbScope? autoScopeFor(List<TomColumnInformation> columns)` | The scope an entity with these `columns` carries *implicitly* — a `TomDbScope(field: …, scope: resourceScope)` when one column is a resource key, `null` otherwise. `null` whenever any column names a `resourceScopeInputTables` table, which is decided for the whole list before the resource key is looked for. |
| `findAuthColumns` | `static List<TomColumnInformation> findAuthColumns(Type dbType)` | The columns of `dbType` that opt into column-level access rights (C-4), or empty. |
| `findVersionColumn` | `static TomColumnInformation? findVersionColumn(Type dbType)` | The column of `dbType` annotated `@TomVersion`, or `null` when the entity is not versioned. Read from the memoised column list, which is also where a second `@TomVersion` field is refused, so there is never more than one. |
| `findFileColumns` | `static List<TomColumnInformation> findFileColumns(Type dbType)` | The columns of `dbType` annotated `@TomFileReference`, or empty. Consulted before *any* file work, so an entity that stores no files pays nothing for the feature. |
| `encryptedColumns` | `static List<TomColumnInformation> encryptedColumns(Type dbType)` | The `@TomEncrypted` columns of `dbType`, in declaration order — empty for an entity with none or a type that is not an entity. Read from the memoised column list, which is where a misdeclared encrypted field is refused (`annotation_analyzer.encryption.*`). |
| `blindIndexColumns` | `static List<TomColumnInformation> blindIndexColumns(Type dbType)` | The `@TomBlindIndex` columns of `dbType`, in declaration order. |
| `familyOf` | `static TomSqlTypeFamily familyOf(TomColumnInformation column)` | The type family `column` is **stored** in — the one answer the query compiler, the schema-convergence check and the export projection all read. JSON is text whatever the types; otherwise an explicit `columnType` (a box or a Dart type) decides, and only when there is none does `dartTypeOf` stand in. An explicit type naming no family yields `unknown` rather than falling back — compatible with everything in the convergence check, refused by the query compiler. |
| `dartTypeOf` | `static Type dartTypeOf(TomColumnInformation column)` | The Dart type `column` is read as: the annotation's `dartType` when given, else the field's declared type. |
| `describeDeclaredType` | `static String describeDeclaredType(TomColumnInformation column)` | How `column`'s type is spelled on the entity side, for reporting only — `'JSON'`, else the explicit `columnType`, else the Dart type. |
| `getPersistentColumns` | `static List<TomColumnInformation>? getPersistentColumns(Type dbType)` | The persistence metadata for every annotated field, or `null` if not reflectable. Throws `TomAnnotationAnalyzerSyntaxException`. The list is unmodifiable and shared with every other caller for the same entity; a caller wanting one of its own copies it. |
| `determineColumn` | `static TomColumnInformation determineColumn(String name, List<TomTypePersistenceInfo> persistenceInfo)` | Finds the `TomColumnInformation` matching `name`. Throws `TomAnnotationAnalyzerSyntaxException` when nothing matches. |
| `referenceQuery` | `static ({String sentence, Map<String, Object?> parameters}) referenceQuery(TomReference reference, Type owningType, Object? Function(String field) readOwningField)` | The `FIND BY` sentence resolving a `@TomReference` for one mapped row, and the parameters it binds. Throws `TomAnnotationAnalyzerSyntaxException` for a malformed expression, `TomAnnotationAnalyzerException` for a context value the zone cannot supply. |
| `reset` | `static void reset()` | Discards every memoised resolution, so the next lookup of any entity re-reads its reflection metadata. All seven memos together — see *Memoisation*. |

##### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `resourceKeyColumn` | `String` | `'resource_key'` | The column name that marks an entity as carrying a resource key, and so as automatically grant-scoped. |
| `resourceKeyField` | `String` | `'resourceKey'` | The camelCase entity-field spelling of `resourceKeyColumn`. |
| `resourceScopeInputTables` | `Set<String>` | `{'tom_principal_resource_grant', 'tom_principal_delegation', 'tom_resource_grant'}` | The framework's own authorization tables — never auto-scoped. See below. |

`resourceScopeInputTables` is a safety invariant, not a convenience. Those three
tables carry a resource key, so without the exclusion each would match
`autoScopeFor` and filter *itself*: a principal could reach its own grant rows
only by already holding a grant on them, which no row can satisfy, and the
authorization layer would resolve to nothing at all.

The entities also declare `@TomDbScope.unscoped()`, which is the readable
statement of the same fact. This set is the half that survives a **stale
generated `*.reflection.dart`**, whose class metadata predates the annotation —
an invariant of this kind must not depend on a deployment having re-run code
generation before it upgrades. The names are duplicated from the entities'
`@TomDbTable` annotations rather than imported, because `authorization` depends
on `object_persistence` and not the other way round;
`test/resource_data_scope_test.dart` asserts the two agree.

The exclusion is a property of the entity, so `autoScopeFor` settles it for the
whole column list before looking at any column: a list naming one of the three
tables anywhere yields no scope. Every column the analyzer resolves carries the
one `@TomDbTable` of its type, so for the entities this method actually sees the
two readings coincide — but only one of them says what the invariant is. Decided
per column, whether a grant table ends up scoped would read as though it turned
on where the resource key sits in the list.

##### Memoisation

Each of the seven resolutions above — mirror, table, columns, row scope,
tenant ownership, column-authorized columns, file columns — is computed once per entity type and
kept in a private `static final` map. The memos are not part of the API: there
is no way to read, seed or replace one, and `reset()` is the only way to clear
them.

That is deliberate, because the memoised answers are *shared*. Every caller
asking for the same entity receives the same objects, so anything writable
reachable from them would let one holder change what every later query
compiles to — silently, and far from the code that made the mistake. Closing
the memos completes what `TomColumnInformation`'s `final` fields and the
unmodifiable column lists start: two resolutions of one entity cannot be made
to disagree. `test/persistence_metadata_sharing_test.dart` pins it.

`reset()` clears all seven or none. They are derived from one another — the
columns come from the mirror, the row scope, the tenant ownership and the two
column subsets come from the columns — so emptying a subset would leave the rest describing an
entity that no longer exists. A server never calls it: an entity's annotations
are fixed for the run. A test does, when it re-registers a fixture type it has
already analysed under a different mapping and would otherwise read the first
answer back. The same test file asserts `reset()` reaches every memo the mixin
declares, so an eighth added later cannot quietly survive the reset.

##### Reflection failures

`findMirror` is the gate every entity's mapping passes through, and its `null`
answer means exactly one thing: the reflector holds no mirror for the type. That
is an ordinary result — `findTable` and `getPersistentColumns` are asked about
types that may carry no persistence annotations at all — and it is recognised by
the `NoSuchCapabilityError` the reflector raises to say so.

Anything else the lookup raises is reported as `TomAnnotationAnalyzerException`
with the original as `rootException`, because answering `null` for it would
reappear one frame up as *"it is not in `tomReflector`"* — a diagnosis that is
plausible, wrong, and sends the reader to the entity's annotations and its
generated file, neither of which is at fault. Two causes reach here:

- **Reflection was never initialized.** `initializeReflection()` was not called,
  so *every* type looks unregistered. The reflection library's own `StateError`
  names the missing call; that sentence is the fix, and is preserved verbatim in
  the wrapped exception.
- **The name is not a class.** `dynamic` and `void` are registered with every
  reflector that can reflect types and have no `ClassMirror`; a generic
  parameter that erased arrives here as `dynamic`. This is a caller-side
  mistake, not a gap in the reflection setup, and the message says which.

Neither is memoised: a thrown lookup leaves no entry behind, so the second call
reports the fault again rather than reading a `null` back.
`test/annotation_analyzer_mirror_lookup_test.dart` pins all three outcomes.

##### A memoised `null`

`findMirror`, `findTable`, `findDataScope` and `getPersistentColumns` all store
their `null` answer, so `containsKey` true with a null value is a designed state
of each of their maps. Two rules follow.

A cache-hit path reads the entry back **as nullable**. Casting it to the
lookup's non-nullable element type gives the worst shape of bug available: the
first call answers correctly and the second, served from the memo, throws.

Callers **do not null-assert** these lookups. `findTable(type)!` is a null check
written as an expression — where the caller has established that the type is
mapped it records that in a form that stops being true when the branch above it
moves, and where it has not it reports `Null check operator used on a null value`
from inside a static cache, naming neither the type nor the missing annotation.
A caller holding an entity uses `analysePersistentType`, which is non-nullable
and names what is absent; a caller asking *whether* it holds one reads the lookup
into a local and tests it. `test/annotation_analyzer_null_memo_test.dart` pins
the read-back at runtime and the absence of assertions by scanning `lib/`.

### Migrating Blobs Between Backends

`TomBlobMigration` moves the blobs a repository's rows point at from one
`TomBlobStore` to another. The key list comes from the rows because the blob
contract cannot enumerate itself: a `@TomFileReference` column *is* the index of
what a deployment stored, and it is the index that matters, since a blob no row
names is one nothing can serve.

#### TomBlobMigration

- **Extends:** none

##### Constructors

```dart
const TomBlobMigration({
  required TomBlobStore source,
  required TomBlobStore target,
  int pageSize = 200,
  bool deleteFromSource = false,
  bool allowScopedRun = false,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `source` | `TomBlobStore` | The store blobs are read from (final). |
| `target` | `TomBlobStore` | The store they are written to (final). |
| `pageSize` | `int` | How many rows are read at a time; paged rather than read whole, because a migration is run against the table that grew large enough to need one (final). |
| `deleteFromSource` | `bool` | Whether a *verified* copy is then deleted from `source`. `false` by default, and the asymmetry is deliberate: a migration that leaves both copies is undone by changing one setting back, where one that deleted as it went is undone by restoring a backup (final). |
| `allowScopedRun` | `bool` | Whether to run with a request principal in the zone. `false` by default, because `findAll` applies the entity's row scope (C-3) and masks the columns the principal may not read (C-4) — so the sweep would migrate that principal's *view* and report success, and a masked file column reads back `null`, indistinguishable from a row holding no file (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `migrate` | `Future<TomBlobMigrationReport> migrate<T extends Object, K>(TomRepository<T, K> repository, {Set<String> fields = const {}})` | Copies every blob the rows name, using only `get` / `describe` / `put`, so it works between any two backends including one an application wrote. Read-only on the database: a backend migration changes no key, since the column holds the key and which *store* it is read from is configuration. "Already there" is a digest comparison, which makes a second run confirm the first and an interrupted one resumable; a target holding different bytes under the same key is overwritten. A dangling reference is reported rather than thrown — an operator wants the whole list — while a copy that does not match what was read throws, that being the one failure a later pass cannot detect. `fields` narrows the sweep to named file columns. |

#### TomBlobMigrationReport

What one migration did. Counts rather than a boolean, because "it worked" is not
the question an operator has afterwards.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `rows` | `int` | How many rows the sweep read (final). |
| `copied` | `int` | How many blobs it copied into the target (final). |
| `alreadyPresent` | `int` | How many it found already there, verified and left alone (final). |
| `bytes` | `int` | How many bytes were copied — the transfer, not the total stored (final). |
| `claimed` | `List<String>` | Every key the target now holds because a row named it. The list a deployment diffs its old store against to find what the rows do not claim; that diff cannot happen here, because it needs an enumeration of the source (final). |
| `absent` | `List<String>` | The keys a row names that the source does not hold (final). |
| `complete` | `bool` | *(getter)* Whether every key a row named ended up in the target. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders the five counts. |

### Sweeping Files No Row Refers To

`blob_orphan_sweep.dart` deletes stored files no row refers to. A plain blob
store cannot find those, because it cannot list itself; a
`TomDeduplicatingBlobStore` can, because its ledger records every key.
`TomBlobOrphanSweep` walks that ledger and asks the rows, through one or more
`TomBlobReferenceSource`s. Only keys written more than `grace` ago are
considered, so an upload has that long to be attached; the sources are asked a
second time immediately before a delete, which narrows the window in which a row
saved during the sweep loses its file to the delete itself. The sweep's
refusals are `TomStorageException`s (file_storage): `storage.sweep.scoped_run`,
`storage.sweep.no_file_columns` and `storage.sweep.unknown_field`.

#### TomBlobReferenceSource

Something that knows which blob keys its rows refer to.

- **Extends:** none (abstract)

##### Constructors

```dart
const TomBlobReferenceSource()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `referenced` | `Future<Set<String>> referenced(List<String> keys)` | *(abstract)* Which of `keys` a row refers to. |

#### TomRepositoryBlobReferences&lt;T, K&gt;

The `@TomFileReference` columns of a repository's entity, as a
`TomBlobReferenceSource`. Soft-deleted rows count: a restore brings their files
back into use.

- **Extends:** `TomBlobReferenceSource`

##### Constructors

```dart
TomRepositoryBlobReferences(
  TomRepository<T, K> repository, {
  Set<String> fields = const {},
  int batchSize = 100,
})
```

Reads the file columns of `T` — all of them, or those `fields` names by field or
column name. Throws `storage.sweep.no_file_columns` when `T` stores no files,
`storage.sweep.unknown_field` when `fields` names a field that is not one of its
file columns, and an `ArgumentError` for a `batchSize` below one.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomRepository<T, K>` | The repository the rows are read through (final). |
| `batchSize` | `int` | How many keys one query asks about (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `referenced` | `Future<Set<String>> referenced(List<String> keys)` | *(override)* Asks the keys in batches of `batchSize`, inside `TomSoftDelete.includingDeleted`: one `FIND BY <column> IS IN (…)` per file column and batch. A column graded with an `authKey` is counted key by key instead (`COUNT BY <column> = :key`), because a read outside a request may mask it to `null` — and a key the sweep cannot see is one it deletes — while a count is never masked. |

#### TomBlobOrphanSweepReport

What one `TomBlobOrphanSweep.sweep` did.

##### Constructors

```dart
const TomBlobOrphanSweepReport({
  required int scanned,
  required List<String> deleted,
  required int reclaimed,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scanned` | `int` | How many keys were old enough, and under a configured prefix, to be considered (final). |
| `deleted` | `List<String>` | The keys no row referred to, which were deleted (final). |
| `reclaimed` | `int` | How many contents the reclaim after the sweep freed (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomBlobOrphanSweepReport(<scanned> scanned, <n> deleted, <reclaimed> reclaimed)`. |

#### TomBlobOrphanSweep

Deletes the keys of a `TomDeduplicatingBlobStore` that no source refers to, once
they are older than `grace`, and then reclaims the content they held.

- **Extends:** none

##### Constructors

```dart
TomBlobOrphanSweep({
  required TomDeduplicatingBlobStore store,
  required List<TomBlobReferenceSource> sources,
  Duration grace = const Duration(days: 1),
  List<String> prefixes = const [],
  int batchSize = 500,
  bool reclaim = true,
  bool allowScopedRun = false,
  DateTime Function()? clock,
})
```

`prefixes` are validated as keys. An empty `sources` — every key would be
unreferenced and the sweep would empty the store — a `grace` that is not
positive, or a `batchSize` below one is an `ArgumentError`. `clock` (default
`DateTime.now`) is the time a sweep run without `now` measures the grace from.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomDeduplicatingBlobStore` | The store swept (final). |
| `sources` | `List<TomBlobReferenceSource>` | Everything that may refer to a key; unmodifiable (final). |
| `grace` | `Duration` | How old a key must be to be considered — far longer than any upload-to-save delay a deployment allows (final). |
| `prefixes` | `List<String>` | The key prefixes considered, matched by segment — the `keyPrefix`es of the file columns the sources read, when the store also holds files nothing here describes; empty for every key (final). |
| `batchSize` | `int` | How many keys one page of the ledger holds (final). |
| `reclaim` | `bool` | Whether to run `TomDeduplicatingBlobStore.reclaim` after the sweep (final). |
| `allowScopedRun` | `bool` | Whether the sweep may run inside a request. `false` by default, because a request's data scope hides rows, and a row the sweep cannot see is a reference it deletes (final). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sweep` | `Future<TomBlobOrphanSweepReport> sweep({DateTime? now})` | Deletes every key written before `now` (default: the sweep's clock) minus `grace` that no source refers to: pages the ledger's keys in key order, keeps those under `prefixes`, asks the sources, asks again about the unreferenced ones immediately before deleting them, and then runs the store's `reclaim` at `now` unless `reclaim` is `false`. Throws `storage.sweep.scoped_run` when a principal is in the zone and `allowScopedRun` is unset. |
| `jobDefinition` | `TomJobDefinition jobDefinition({String name = 'tom.storage.orphan_sweep', TomSchedule? schedule})` | A job running `sweep` on `schedule` (default: daily), missed windows run once, for a `TomScheduler` to run in its own isolate (`TomInlineJobDispatcher`), since its body holds this sweep. A run's result is the report's text. |

### Field-Level Encryption

`field_encryption.dart` encrypts `@TomEncrypted` columns at rest under **data
keys** — random 256-bit keys kept in the data-key table `tom_encryption_key`
(declared by `encryptionKeyTable` in `field_encryption_sql.dart`), each stored
wrapped under a **key-encryption key** that never touches the database. A
`TomFieldKeyring` reads, unwraps and caches the data keys and rotates them;
`TomFieldEncryption` is what the repository and the data source call;
`TomFieldReencryption` rewrites what a rotation or a plaintext column left
behind. `TomAesGcm` is the cipher underneath all of it, public because the
privacy module seals audit values with it too. A stored value reads
`tomenc:v1:<data key id>:<base64url of nonce, ciphertext and tag>`, with the
table and column as the cipher's additional authenticated data.

#### TomDataKeyPurpose

What a data key is for.

##### Enum Values

| Value | Meaning |
| ----- | ------- |
| `encryption` | Values are encrypted under it. |
| `blindIndex` | Blind indexes are computed with it. |

#### TomDataKeyState

Whether a data key is the one new values use.

##### Enum Values

| Value | Meaning |
| ----- | ------- |
| `active` | New values use it; one per purpose. |
| `previous` | Kept so the values written under it still decrypt — or, for an index key, so a lookup still matches the rows not yet re-indexed. |

#### TomDataKeyRecord

One data key as the data-key table holds it: wrapped.

##### Constructors

```dart
const TomDataKeyRecord({required String id, required TomDataKeyPurpose purpose, required TomDataKeyState state, required String kekId, required String wrapped, required DateTime createdAt})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The key's id, written into every value encrypted under it: a UUID for an encryption key, `index-<n>` for an index key. |
| `purpose` | `TomDataKeyPurpose` | What the key is for. |
| `state` | `TomDataKeyState` | Whether new values use it. |
| `kekId` | `String` | The key-encryption key it is wrapped under. |
| `wrapped` | `String` | The wrapped key, base64. |
| `createdAt` | `DateTime` | When it was created. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `copyWith` | `TomDataKeyRecord copyWith({TomDataKeyState? state, String? kekId, String? wrapped})` | This record with `state`, `kekId` or `wrapped` replaced — a rotation and a re-wrap. |

#### TomKeyEncryptionKey

A key-encryption key: what wraps the data keys, and never touches the database.
`wrap` and `unwrap` are asynchronous, so an implementation may call out to a
key-management service. `tom_core_secrets` implements it for AWS KMS
(`TomAwsKmsKeyEncryptionKey`), Vault Transit
(`TomVaultTransitKeyEncryptionKey`) and Azure Key Vault
(`TomAzureKeyVaultKeyEncryptionKey`), each registered as a `fieldEncryption`
key kind.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | *(getter)* The key's id, recorded with every data key it wraps. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `wrap` | `Future<List<int>> wrap(List<int> dataKey, {required String keyId})` | `dataKey`, wrapped; `keyId` is the data key's id, bound into the wrapping so a wrapped key cannot be passed off as another. |
| `unwrap` | `Future<List<int>> unwrap(List<int> wrapped, {required String keyId})` | The data key `wrapped` holds; throws when it was not wrapped by this key for `keyId`. |

#### TomAesKeyEncryptionKey

- **Implements:** `TomKeyEncryptionKey`

A key-encryption key held by the application: a 256-bit AES key, wrapping with
AES-GCM under the additional data `tom-data-key:<keyId>`. The key comes from
wherever the deployment keeps secrets — most often a `secret:` reference in the
`fieldEncryption` configuration.

##### Constructors

```dart
TomAesKeyEncryptionKey(String id, List<int> key)
factory TomAesKeyEncryptionKey.base64(String id, String base64Key)
```

Both throw `TomFieldEncryptionException` (`field_encryption.invalid_kek`) for an
id that is empty or longer than 128 characters, a key that is not 32 bytes, or
— `base64` — text that is not base64.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | *(override)* The key's id. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `wrap` | `Future<List<int>> wrap(List<int> dataKey, {required String keyId})` | *(override)* The data key sealed with AES-256-GCM under a fresh nonce: nonce, sealed key and tag. |
| `unwrap` | `Future<List<int>> unwrap(List<int> wrapped, {required String keyId})` | *(override)* The data key; throws when `wrapped` does not authenticate under this key for `keyId`. |

#### TomAesGcm

AES-256-GCM with a random 96-bit nonce prepended to the sealed bytes — the
cipher of field encryption, of data-key wrapping (`TomAesKeyEncryptionKey`) and
of the per-subject sealing of audit values (the privacy module's
`TomSubjectKeys`). Public so those three share one implementation; a caller
supplies the key and the additional authenticated data that binds a value to
where it belongs.

- **Extends:** none (abstract final, static members only)

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `seal` | `static Uint8List seal(List<int> key, List<int> plaintext, String aad)` | `plaintext` sealed under the 32-byte `key`, `aad` authenticated with it: nonce, ciphertext and tag. Each call draws a fresh nonce, so equal plaintexts seal differently. |
| `open` | `static Uint8List open(List<int> key, List<int> sealed, String aad)` | The plaintext `sealed` holds. Throws `ArgumentError` (pointycastle's `InvalidCipherTextException` included) when `sealed` is too short or does not authenticate under `key` and `aad`; callers turn it into their own key (`field_encryption.decrypt_failed`, `privacy.seal.invalid`). |

#### TomDataKeyStore

Where the wrapped data keys are kept.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scope` | `Object` | *(getter)* What the current context's keys belong to: one data source's keys are not another's. The keyring caches per scope. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | Makes the store ready — creates its table — for the data source the current context resolves. Called outside any transaction. |
| `all` | `Future<List<TomDataKeyRecord>> all()` | Every data key of `scope`. |
| `insert` | `Future<bool> insert(TomDataKeyRecord record)` | Stores `record`; `false` when its id is taken — which is how two nodes creating one key insert one row. |
| `update` | `Future<void> update(TomDataKeyRecord record)` | Replaces the stored record of `record`'s id. |

#### TomMemoryDataKeyStore

- **Implements:** `TomDataKeyStore`

Data keys in memory: for tests, and for a single process whose encrypted data is
in memory too. Its `scope` is itself.

##### Constructors

```dart
TomMemoryDataKeyStore()
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scope` | `Object` | *(override, getter)* The store itself. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Nothing to prepare. |
| `all` | `Future<List<TomDataKeyRecord>> all()` | *(override)* Every record held. |
| `insert` | `Future<bool> insert(TomDataKeyRecord record)` | *(override)* Stores `record` unless its id is taken. |
| `update` | `Future<void> update(TomDataKeyRecord record)` | *(override)* Replaces the record of `record`'s id. |

#### TomSqlDataKeyStore

- **Implements:** `TomDataKeyStore`

Data keys in the data-key table of a SQL data source. Built with a name, it
resolves the data source through `TomDataSourceInfo.getDataSourceInfo` on every
call — so under tenancy each tenant's routed data source holds its own keys;
built `over` a data source, it binds that one. Its statements derive from
`encryptionKeyTable`.

##### Constructors

```dart
TomSqlDataKeyStore(String this.datasourceName, {String table = defaultEncryptionKeyTable, bool createSchema = true})
TomSqlDataKeyStore.over(TomDataSource datasource, {String table = defaultEncryptionKeyTable, bool createSchema = true})
```

With `createSchema` (the default) the table is created on first use in each data
source; a deployment whose user may not run DDL applies the shipped migration
and passes `false`. A name that resolves to no registered data source raises
`field_encryption.no_datasource` on first use.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceName` | `String?` | The registered name of the data source, or `null` for a store built `over` one. |
| `table` | `String` | The table's name. |
| `createSchema` | `bool` | Whether the table is created on first use. |
| `scope` | `Object` | *(override, getter)* The data source the current context resolves. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Creates the table in the resolved data source, once per data source, unless `createSchema` is `false`. |
| `all` | `Future<List<TomDataKeyRecord>> all()` | *(override)* Every row of the table, read as `TomDataKeyRow`s. |
| `insert` | `Future<bool> insert(TomDataKeyRecord record)` | *(override)* Inserts `record`, ignoring a conflict on its id; `false` when the id was taken. |
| `update` | `Future<void> update(TomDataKeyRecord record)` | *(override)* Updates the row's `state`, `kek_id` and `wrapped_key`. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table of the data source this context resolves. For tests. |

#### TomDataKeyRow

One row of the data-key table, as `TomSqlDataKeyStore` reads it — a reflected
row holder, not an application entity.

##### Constructors

```dart
TomDataKeyRow()
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keyId` | `String` | The key's id (`key_id`). |
| `purpose` | `String` | The purpose's name (`purpose`). |
| `state` | `String` | The state's name (`state`). |
| `kekId` | `String` | The wrapping key-encryption key (`kek_id`). |
| `wrappedKey` | `String` | The wrapped key, base64 (`wrapped_key`). |
| `createdAt` | `String` | When it was created, as stored UTC text (`created_at`). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toRecord` | `TomDataKeyRecord toRecord()` | The record this row stores. |

#### TomFieldKeyring

The data keys, unwrapped and cached in memory. Reads decrypt from the cache; a
value naming a key the cache does not hold — one another node created — makes
the keyring read the table again.

##### Constructors

```dart
TomFieldKeyring({required TomDataKeyStore store, required List<TomKeyEncryptionKey> keys, Duration refreshInterval = const Duration(minutes: 5), DateTime Function()? clock})
```

`keys` are the key-encryption keys, primary first: the primary wraps every data
key the keyring creates and every `rewrap`; the others only unwrap, so a
rotated-out key-encryption key stays in the list until `rewrap` has run. An
empty list throws `field_encryption.invalid_kek`. `clock` replaces
`DateTime.now`, for tests of the refresh.

##### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `indexKeyId` | `String` | `'index-1'` | The id of the first index key, the same in every scope: two nodes creating it at once insert one row. `rotateIndexKey` numbers its successors the same way. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomDataKeyStore` | Where the wrapped data keys are kept. |
| `keys` | `List<TomKeyEncryptionKey>` | The key-encryption keys, unmodifiable; the first is the primary. |
| `refreshInterval` | `Duration` | How long the keyring trusts what it read; afterwards it reads the table again, which is how a node learns of a rotation another node made. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `load` | `Future<void> load()` | Reads the data keys of the current context's scope and unwraps the ones not yet cached; creates the first encryption key and the index key when the scope has none. A data key wrapped under a key-encryption key the keyring was not given, or not unwrapping under it, throws `field_encryption.unknown_kek`. |
| `activeKeyId` | `Future<String> activeKeyId()` | The id of the data key new values in the current context are encrypted under. |
| `indexKeyIdInUse` | `Future<String> indexKeyIdInUse()` | The id of the active index key of the current context. |
| `indexKeyIds` | `Future<List<String>> indexKeyIds()` | Every index key of the current context, the active one first: what a lookup matches while an index-key rotation is being rewritten. |
| `materialOf` | `Uint8List? materialOf(String id)` | The unwrapped key `id`, or `null` when it is not cached. |
| `ensure` | `Future<Set<String>> ensure(Iterable<String> ids)` | Makes sure every key in `ids` is cached, reading the table again when one is not; answers the ids still unknown. |
| `records` | `Future<List<TomDataKeyRecord>> records()` | The data keys of the current context, as stored. |
| `rotateDataKey` | `Future<String> rotateDataKey()` | Creates a data key and makes it the active encryption key of the current context; the key it replaces turns `previous` and stays, for reading. Answers the new key's id. New values use it at once; a `TomFieldReencryption` pass moves the old ones over. |
| `rotateIndexKey` | `Future<String> rotateIndexKey()` | Creates the next index key (`index-2`, `index-3`, …) and makes it the active one of the current context; the previous one is kept. Answers its id. The numbering makes two nodes rotating at once create one key. Saved rows are indexed under it at once and a pass recomputes the rest; until then `TomFieldEncryption.blindIndexCondition` matches every index key. |
| `rewrap` | `Future<int> rewrap()` | Wraps every data key of the current context not yet wrapped under the primary key-encryption key under it; answers how many. The rotation of a key-encryption key: no value is touched. |

#### TomFieldEncryption

The isolate's field encryption: the installed keyring, and what the repository
and the data source call. All members are static.

##### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `prefix` | `String` | `'tomenc:v1:'` | What every stored ciphertext starts with. |
| `redacted` | `String` | `'[encrypted]'` | What an audit record holds for an encrypted field or a blind index, in place of its value. |
| `configurationKey` | `String` | `'fieldEncryption'` | The configuration key `configure`'s settings are read from. |
| `aesKeyKind` | `String` | `'aes'` | The kind of a `keys` entry that names none: an application-held AES key, built in. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static Future<void> install(TomFieldKeyring keyring)` | Installs `keyring` and loads its keys for the current context. |
| `reset` | `static void reset()` | Removes the keyring and restores the defaults (`acceptPlaintext` on). For tests. |
| `registerKeyKind` | `static void registerKeyKind(String kind, TomKeyEncryptionKeyFactory factory)` | Lets a `keys` entry of `kind` build its key with `factory` — how a provider package offers a key held by its key-management service. Registering a kind again replaces its factory. Throws `field_encryption.config.invalid` for `aes` or an empty kind. |
| `configure` | `static Future<void> configure(Object? settings)` | Installs a keyring from `settings`, the `fieldEncryption` configuration map: `datasource` (required), `table` (default `tom_encryption_key`), `createSchema` (default `true`), `keys` (required, primary first: each with an `id` and a `kind`, default `aes`; an `aes` entry carries `key`, the base64 of 32 bytes or a `secret:` reference to it, resolved here through `TomSecrets.resolve`; any other kind is built from the entry by the factory registered for it), `refreshSeconds` (default 300) and `acceptPlaintext` (default `true`). Throws `field_encryption.config.invalid` for a value of the wrong shape or a kind nothing registered (naming the known kinds) and `field_encryption.invalid_kek` for a bad key, before anything is installed. |
| `raw` | `static R raw<R>(R Function() body)` | Runs `body` with decryption off: the data source maps an encrypted column's stored value as it is, and loads no references. What a `TomFieldReencryption` pass reads through. |
| `isCiphertext` | `static bool isCiphertext(String? stored)` | Whether `stored` is ciphertext of this format. |
| `keyIdOf` | `static String? keyIdOf(String? stored)` | The data key id `stored` was encrypted under, or `null` for plaintext. |
| `storedLength` | `static int storedLength(int plaintextBytes)` | How many characters a stored value of `plaintextBytes` UTF-8 bytes takes: what an encrypted column's width must allow. |
| `encrypt` | `static Future<String?> encrypt(TomColumnInformation column, String? plaintext)` | `plaintext` encrypted for `column` under the active data key of the current context; `null` stays `null`. Throws `field_encryption.not_configured` without a keyring. |
| `prepareRead` | `static Future<void> prepareRead(Iterable<String?> stored, {required Type entity})` | Loads the data keys the ciphertexts among `stored` name, so `decrypt` finds them — the keys of `entity`'s classification (`forEntity`). Called by the data source before it maps a result. |
| `forEntity` | `static R forEntity<R>(Type entity, R Function() body)` | Runs `body` with the data keys of `entity`'s classification: a system table's are the system's (`isSystemScope`), a tenant table's the tenant in context's. Every entry point that knows its entity — `encrypt`, `decrypt`, `blindIndex`, `blindIndexCandidates`, `prepareRead` — runs through it. |
| `decrypt` | `static String? decrypt(TomColumnInformation column, String? stored)` | The plaintext of `stored`, read from `column`; `null` stays `null`. A value that is not ciphertext reads as it is while `acceptPlaintext` is on, and throws `field_encryption.plaintext_refused` otherwise; a key the keyring does not hold throws `field_encryption.unknown_key`, a value that does not authenticate `field_encryption.decrypt_failed`. |
| `blindIndex` | `static Future<String?> blindIndex(TomColumnInformation indexColumn, String? plaintext, {String? keyId})` | The blind index of `plaintext` for the index column `indexColumn`, under the index key `keyId` — the active one unless given; `null` stays `null`. |
| `blindIndexOf` | `static Future<String?> blindIndexOf(Type entity, String field, String? plaintext)` | The value `entity`'s blind index of the encrypted field `field` holds for `plaintext` under the active index key. Enough while no index-key rotation is being rewritten. Throws `ArgumentError` when `field` has no `@TomBlindIndex`. |
| `blindIndexCandidates` | `static Future<List<String>> blindIndexCandidates(Type entity, String field, String plaintext)` | The values `entity`'s blind index of `field` may hold for `plaintext`: one per index key of the current context, the active one first. |
| `blindIndexCondition` | `static Future<({String condition, Map<String, Object?> params})> blindIndexCondition(Type entity, String field, String plaintext)` | A query-sentence condition finding the rows whose `field` is `plaintext` — `<index field> is in ( :<index field>0 , … )` — with its parameters, matching every index key so it holds through an index-key rotation. The lookup to use. |
| `redact` | `static Map<String, Object?> redact(Type entity, Map<String, Object?> image)` | `image` — an audit record's field values — with the non-null values of `entity`'s encrypted fields and blind indexes replaced by `redacted`. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keyring` | `TomFieldKeyring?` | *(static, getter)* The installed keyring, or `null`. |
| `keyKinds` | `Iterable<String>` | *(static, getter)* The kinds registered with `registerKeyKind`, besides `aes`. |
| `acceptPlaintext` | `bool` | *(static)* Whether a value of an encrypted column that is not ciphertext reads as it is. On by default, so a column marked `@TomEncrypted` after it held data keeps reading until a pass has encrypted it; off once every column is. |
| `isRaw` | `bool` | *(static, getter)* Whether the current zone reads raw. |
| `isSystemScope` | `bool` | *(static, getter)* Whether the zone's encryption work is for a system table: its data keys are kept in the system data source under tenant `''`, whatever tenant is in context, so every tenant reads the row back. |

#### TomReencryptionReport

What a `TomFieldReencryption` pass did.

##### Constructors

```dart
const TomReencryptionReport({int examined = 0, int rewritten = 0, int conflicts = 0, List<String> failures = const []})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `examined` | `int` | Rows read. |
| `rewritten` | `int` | Rows written: a value moved to the active key, plaintext encrypted, or a blind index filled or recomputed. |
| `conflicts` | `int` | Rows a concurrent save changed between the read and the write; the next pass looks at them again. |
| `failures` | `List<String>` | Rows whose values could not be decrypted, one line each: the entity, its key values and the error key. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `operator +` | `TomReencryptionReport operator +(TomReencryptionReport other)` | This report and `other` summed. |
| `toJson` | `Map<String, Object?> toJson()` | The report as JSON-native values — the result a re-encryption job's run records. |
| `toString` | `String toString()` | *(override)* The three counts and the number of failures. |

#### TomFieldReencryption

Rewrites what is not yet stored the way the keyring wants it: values under a
previous data key, plaintext in an encrypted column, blind indexes that are
missing or computed under a previous index key. Rows are read raw, in
primary-key order, and each is written by an `UPDATE` guarded by the values it
read, so a concurrent save is never overwritten — it is counted as a conflict.

##### Constructors

```dart
TomFieldReencryption({Iterable<Type>? entities, int batchSize = 200})
```

`entities` defaults to every reflected `@TomDbTable` class declaring a
`@TomEncrypted` field.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entities` | `List<Type>` | The entities the pass covers. |
| `batchSize` | `int` | Rows read per statement. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `run` | `Future<TomReencryptionReport> run()` | Runs one pass over every entity, in the current context and — when a `TomTenancy` is installed — in every tenant's. An entity whose data source is not registered throws `field_encryption.no_datasource`. |
| `job` | `TomJobDefinition job({required TomSchedule schedule, String name = tomReencryptionJobName, Duration timeout = const Duration(hours: 1)})` | A scheduler job running a pass on `schedule`, recovery requested, its result the report's `toJson`. The body uses the isolate's keyring, so register it on a scheduler with a `TomInlineJobDispatcher`; a worker isolate has no keyring. |

### Entity Lifecycle

Source: `lib/src/tomserver/object_persistence/entity_lifecycle.dart`. Carried
out by `TomSqlDatasourceRepository` and by no other code path; see
[Entity Lifecycle](../object_persistence.md#entity-lifecycle) for the DDL of a
history table and the transaction rule.

#### TomSoftDelete

Marks an entity whose repository deletes are soft: a delete sets `field`, a
nullable `DateTime` column, to the time of the delete, and every repository read
leaves out the rows whose `field` is set. `@tomReflector` metadata, read off the
entity.

##### Constructors

```dart
const TomSoftDelete({String field = 'deletedAt'})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The entity field holding the deletion time — `null` while the row lives. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `includingDeleted` | `static Future<R> includingDeleted<R>(Future<R> Function() body)` | Runs `body` in a zone where repository reads see soft-deleted rows. |
| `of` | `static TomSoftDelete? of(Type entity)` | The `TomSoftDelete` of `entity`, or `null` when its deletes are hard. |

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isIncludingDeleted` | `bool` | *(getter)* Whether the current zone reads soft-deleted rows. |

#### TomHistory

Marks an entity whose rows keep their past: before every update and every
delete — soft, hard or by query — and every restore, the row as it was is copied
into `table`, which carries every column of the entity's table plus
`history_id`, `history_action`, `history_at` and `history_by`. An encrypted
column is copied as its ciphertext.

##### Constructors

```dart
const TomHistory({required String table})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `table` | `String` | The history table. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomHistory? of(Type entity)` | The `TomHistory` of `entity`, or `null` when it keeps none. |

#### TomHistoryEntry&lt;T&gt;

One past version of a row, as `historyOf` answers it.

- **Type Parameters:** `T extends Object` — the entity type.

##### Constructors

```dart
const TomHistoryEntry({
  required T entity,
  required String action,
  required DateTime at,
  String? by,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entity` | `T` | The row as it was. |
| `action` | `String` | What replaced it: `update`, `delete` or `restore`. |
| `at` | `DateTime` | When (UTC). |
| `by` | `String?` | The principal that did it, if any. |

#### TomHistoryMeta

The history table's own columns, read beside the entity's by reflection. The
`@TomDbTable` values are placeholders, as the table is named by each entity's
`TomHistory`. `@tomReflector`.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `historyId` | `int` | `history_id`: the history row's own key, in insertion order. |
| `historyAction` | `String` | `history_action`: `update`, `delete` or `restore`. |
| `historyAt` | `DateTime` | `history_at`: when the version was replaced. |
| `historyBy` | `String?` | `history_by`: the principal that replaced it, if any. |

#### TomEntityChangeKind

What a `TomEntityChange` reports.

##### Enum Values

| Value | Meaning |
| ----- | ------- |
| `inserted` | A row was inserted. |
| `updated` | A row was updated. |
| `deleted` | A row was deleted — or, for a `@TomSoftDelete` entity, marked deleted (`TomEntityChange.soft`). |
| `restored` | A soft-deleted row was restored. |

#### TomEntityChange

One change of one row, as a `TomEntityChangeListener` is told of it. `before`
and `after` are the row as stored, read without the current principal's column
masks; either is `null` where the change has no such side.

##### Constructors

```dart
TomEntityChange({
  required Type entityType,
  required TomEntityChangeKind kind,
  required Object? key,
  Object? before,
  Object? after,
  Map<String, Object?> beforeValues = const {},
  Map<String, Object?> afterValues = const {},
  bool soft = false,
  DateTime? at,
  String? principalId,
  String? tenant,
})
```

`at` defaults to now (UTC), `principalId` to the id of the `TomPrincipal` in the
zone, `tenant` to `TomTenantContext.currentId`.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entityType` | `Type` | The entity type. |
| `kind` | `TomEntityChangeKind` | What happened. |
| `key` | `Object?` | The row's key. |
| `before` | `Object?` | The row before the change. |
| `after` | `Object?` | The row after the change. |
| `beforeValues` | `Map<String, Object?>` | `before`'s field values, encrypted fields redacted. |
| `afterValues` | `Map<String, Object?>` | `after`'s field values, encrypted fields redacted. |
| `soft` | `bool` | Whether a delete marked the row deleted rather than removing it. |
| `at` | `DateTime` | When the change was made (UTC). |
| `principalId` | `String?` | The principal that made it, if any. |
| `tenant` | `String?` | The tenant it was made in, if any. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The change as JSON-ready values — `entity`, `kind`, `key` (as a string), `soft`, `at` (ISO 8601 UTC), `principal`, `tenant`, `before`, `after` — an outbox row's payload. |
| `toString` | `String toString()` | *(override)* `TomEntityChange(<type> <kind> <key>)`. |

#### TomEntityListener&lt;T&gt;

The hooks of one entity type's repository writes; override what it hooks. Each
runs inside the write's transaction. A `before` hook may change the entity it is
handed and may throw to refuse the write; an `after` hook sees the row as stored
and may write elsewhere — its writes commit with the change, and its throw rolls
the change back.

- **Type Parameters:** `T extends Object` — the entity type.

##### Constructors

```dart
const TomEntityListener()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `beforeSave` | `FutureOr<void> beforeSave(T entity, {required bool insert})` | Before `entity` is inserted (`insert`) or updated. |
| `afterSave` | `FutureOr<void> afterSave(T entity, {required bool insert})` | After `entity` was inserted or updated; `entity` is the row as stored. |
| `beforeDelete` | `FutureOr<void> beforeDelete(Object key, T? entity)` | Before the row `key` is deleted. |
| `afterDelete` | `FutureOr<void> afterDelete(Object key, T? entity)` | After the row `key` was deleted; `entity` is the row before it was. |

#### TomEntityLifecycle

The registry of `TomEntityListener`s and `TomEntityChangeListener`s. Statics
only (`abstract final class`).

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void Function() register<T extends Object>(TomEntityListener<T> listener)` | Registers `listener` for the writes of `T`; the function returned removes it. |
| `onChange` | `static void Function() onChange(TomEntityChangeListener listener, {Type? entity})` | Registers `listener` for the changes of `entity`, or of every entity when `entity` is `null`; the function returned removes it. |
| `listenersOf` | `static List<TomEntityListener<Object>> listenersOf(Type entity)` | The listeners registered for `entity`. |
| `hasChangeListeners` | `static bool hasChangeListeners(Type entity)` | Whether a change of `entity` has a listener to tell. |
| `isObserved` | `static bool isObserved(Type entity)` | Whether a write of `entity` has a listener, a change listener or a history — and so runs inside a transaction. |
| `notify` | `static Future<void> notify(TomEntityChange change)` | Tells every listener registered for `change`'s entity of it, in registration order. |
| `reset` | `static void reset()` | Removes every listener. For tests. |

### Exceptions

All extend the server `TomServerException`.

| Class | Source | Thrown when |
| ----- | ------ | ----------- |
| `TomBlobMigrationException` | `blob_migration.dart` | A blob migration cannot proceed — a request principal is in the zone (`storage.migration.scoped_run`), the entity stores no files (`no_file_columns`), a named column is not one (`unknown_field`) — or cannot be trusted, a copy not matching what was read (`verification_failed`). |
| `TomAnnotationAnalyzerException` | `annotation_analyzer.dart` | An entity's persistence metadata cannot be resolved (not registered / no `@TomDbTable`), or reflecting it failed for a reason that is not "unregistered" — see *Reflection failures*. |
| `TomAnnotationAnalyzerSyntaxException` | `annotation_analyzer.dart` | Persistence annotations are present but malformed (e.g. `@TomDbColumn` on a non-variable). |
| `TomColumnAuthorizationException` | `column_authorization.dart` | A write changes a column visible-but-not-editable to the principal (C-4 violation). |
| `TomDataScopeException` | `data_scope.dart` | A `@TomDbScope` names a scope kind no resolver is registered for. |
| `TomEntityLifecycleException` | `entity_lifecycle.dart` | A lifecycle declaration cannot be carried out — a `@TomSoftDelete` field that is not a writable `DateTime` column (`crud_repository.soft_delete.invalid_field`) — or a method needs one the entity lacks: `restoreById` / `purgeById` on an entity whose deletes are hard (`crud_repository.soft_delete.not_soft_delete`), `historyOf` without `@TomHistory` (`crud_repository.history.not_declared`). `clientThrow` defaults to `false`. |
| `TomFieldEncryptionException` | `field_encryption.dart` | Field-level encryption cannot proceed: no keyring installed (`field_encryption.not_configured`), a value naming an unknown data key (`unknown_key`) or failing its authentication (`decrypt_failed`), plaintext refused (`plaintext_refused`), a data key wrapped under a key-encryption key the keyring lacks (`unknown_kek`), a malformed key-encryption key (`invalid_kek`), a malformed `fieldEncryption` configuration (`config.invalid`), or an unregistered data source (`no_datasource`). `clientThrow` is always `false`. |
| `TomDataScopeAuthorizationException` | `data_scope.dart` | A write targets a row outside the current principal's `@TomDbScope` (C-3). |
| `TomQuerySyntaxException` | `operators_expressions.dart` | A query expression is malformed (e.g. `BETWEEN` without exactly two bounds; also raised by the query-sentence compiler, and by the repository when a sentence's verb does not match the method it was handed to). |
| `TomRepositoryException` | `crud_repository.dart` | A repository precondition fails: the entity's datasource is not registered, a primary-key lookup matched more than one row, a `COUNT(*)` returned other than one row, a row `save` wrote could not be read back, `delete` was handed an entity that was never persisted, or a versioned entity carries no version (`crud_repository.save.version_missing` / `crud_repository.delete.version_missing`); `upsert` was called for an entity whose write needs the stored row (`crud_repository.upsert.unsupported`) or with a conflict key leaving out the scope or tenant field (`crud_repository.upsert.unscoped_conflict_key`). |
| `TomOptimisticLockException` | `crud_repository.dart` | A save or `delete(entity)` of a `@TomVersion` entity changed no row because the stored version is no longer the one the caller held, or the row is gone (`crud_repository.save.version_conflict` / `crud_repository.delete.version_conflict`). Extends `TomRepositoryException`; `clientThrow` is always `true`. Carries `heldVersion` (`int`, the version the refused write presented) and `storedVersion` (`int?`, the version stored now — `null` when the row no longer exists or is no longer visible to the caller), both also in `parameters` beside `entity` and `id`. |

Each exception constructor forwards the standard `TomServerException` positional
`key` and `defaultUserMessage` plus the optional named `parameters`, `stack`,
`rootException`, `autoLog` (and, for `TomColumnAuthorizationException` /
`TomDataScopeAuthorizationException` / `TomRepositoryException`, `clientThrow`;
the two analyzer types deliberately do not take it).

The two analyzer types are never client-visible, and not by default:
`clientThrow` is not a parameter on either, so it is an invariant of the type
rather than a value a raise site could override. Every diagnosis they carry
describes the deployment — a type absent from the reflector, an entity without
`@TomDbTable`, the `@TomDbColumn` a field was expected to have — and a caller
can act on none of it, so a sentence compiled inside a served request would
otherwise return the entity's shape to whoever made that request.
`TomQuerySyntaxException` stays visible for the opposite reason: it names the
token that broke the sentence, which is the caller's own input when the sentence
arrived in a request.

`TomRepositoryException` is the one whose `clientThrow` defaults to **`false`**.
Almost every one of its causes is a server fault — a broken deployment, a table
that contradicts its own key, a driver that reported a write it then could not
read — and each message names internals, so the key travels to the caller and
the message does not.

The causes that are *not* server faults override that default and set
`clientThrow: true`: `crud_repository.delete.unsaved_entity`, raised when
`delete(entity)` is handed an entity whose primary key is still `null` or
negative; `crud_repository.save.incomplete_key` and
`crud_repository.key.shape_mismatch`, for a composite key that addresses no row
or the wrong fields; and `crud_repository.save.version_missing` /
`crud_repository.delete.version_missing`, for a versioned entity that arrived
without its version. Each message describes the argument the caller passed and
nothing else, so it is the caller's to read. `TomOptimisticLockException` is
always client-visible for the same reason: the refused write is the caller's
own, and the usual answer — reload the row, show what changed, decide again — is
one only the caller can give.

Its keys follow `crud_repository.<method>.<condition>`, for example
`crud_repository.save.insert_not_readable` or
`crud_repository.count_by_query.illegal_count_result`. The repository's three
sentence-verb mismatches are keyed the same way
(`crud_repository.count_by_query_sentence.sentence_verb_mismatch`) but raise
`TomQuerySyntaxException`, because handing `find by …` to a counting method is a
mistake in the *sentence*, which is the caller's to correct.

## Enums

Five.

| Enum | Values | Members | Written up |
| ---- | ------ | ------- | ---------- |
| `TomSortDirection` | `ascending`, `descending` | `sqlKeyword` → `ASC` / `DESC` | [Paging & Sorting](#tomsortdirection) |
| `TomBlindIndexNormalization` | `exact`, `trim`, `trimLowercase` | — | [Annotations & Metadata](#tomblindindexnormalization) |
| `TomDataKeyPurpose` | `encryption`, `blindIndex` | — | [Field-Level Encryption](#tomdatakeypurpose) |
| `TomDataKeyState` | `active`, `previous` | — | [Field-Level Encryption](#tomdatakeystate) |
| `TomEntityChangeKind` | `inserted`, `updated`, `deleted`, `restored` | — | [Entity Lifecycle](#tomentitychangekind) |

Each is filed beside the type that carries it — a direction is only ever met as
one sort term's, a normalization as one blind index's, a purpose and a state as
one data key's, a change kind as one change's. This section accounts for them
rather than repeating them: the rows above are an index, the sections linked
from them are the documentation.

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultEncryptionKeyTable` | `String` | `'tom_encryption_key'`, the data-key table's name when nothing overrides it. |
| `tomReencryptionJobName` | `String` | `'object_persistence.reencrypt'`, the default name of the re-encryption job `TomFieldReencryption.job` defines. Stable across restarts by necessity, like every job name. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `encryptionKeyTable` | `TomFrameworkTable encryptionKeyTable(String table)` | The one declaration of the data-key table: primary key `key_id`, `purpose`, `state`, the wrapping `kek_id`, the base64 `wrapped_key` and `created_at`, with the `(purpose, state)` index a keyring reads by. Listed by `frameworkOwnedTables`. |
| `encryptionKeyTableDdl` | `String encryptionKeyTableDdl(String table)` | The `CREATE TABLE` statement for the data-key table, derived from `encryptionKeyTable`. |

### Typedefs

Six top-level typedefs: four used by the scoping/authorization APIs, one by the
entity lifecycle, one by field encryption:

| Typedef | Definition | Source |
| ------- | ---------- | ------ |
| `TomColumnAuthResolver` | `TomAuthState Function(String authKey)` | `column_authorization.dart` |
| `TomRowColumnAuthResolver` | `Future<TomAuthState> Function(TomPrincipal? principal, Object? rowId)` | `column_authorization.dart` |
| `TomDataScopeResolver` | `List<Object?>? Function(TomPrincipal? principal)` | `data_scope.dart` |
| `TomAsyncDataScopeResolver` | `Future<List<List<Object?>>?> Function(TomPrincipal? principal)` | `data_scope.dart` |
| `TomEntityChangeListener` | `FutureOr<void> Function(TomEntityChange)` | `entity_lifecycle.dart` |
| `TomKeyEncryptionKeyFactory` | `Future<TomKeyEncryptionKey> Function(String id, Map<String, Object?> settings)` — builds the key-encryption key `id` of a `fieldEncryption.keys` entry from the entry, for a kind registered with `TomFieldEncryption.registerKeyKind` | `field_encryption.dart` |
