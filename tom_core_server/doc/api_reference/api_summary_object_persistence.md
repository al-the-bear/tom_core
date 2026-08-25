# Tom Core Server API Reference: Object Persistence Module

A lightweight, annotation-driven ORM: map a reflected entity class to a database
table, then read and write it through a Spring-Data-style repository. Queries can
be expressed three ways — a parsed *query sentence*, a programmatically built
`TomQuery`, or raw SQL — and all of them render through a pluggable SQL dialect.
The module also carries server-authoritative row-level data scoping (C-3) and
column-level access rights (C-4).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [Annotations & Metadata](#annotations--metadata)
    - [TomDartType](#tomdarttype)
    - [TomDbTable](#tomdbtable)
    - [TomDbColumn&lt;DART_TYPE, COL_TYPE&gt;](#tomdbcolumndart_type-col_type)
    - [TomEntityId](#tomentityid)
    - [TomDbScope](#tomdbscope)
    - [TomJoinTable](#tomjointable)
    - [TomReference&lt;TARGET, K, REPO&gt;](#tomreferencetarget-k-repo)
    - [TomPersistenceEventHandler&lt;DBTYPE&gt;](#tompersistenceeventhandlerdbtype)
    - [TomColumnInformation](#tomcolumninformation)
    - [TomRepositoryType](#tomrepositorytype)
  - [Repositories](#repositories)
    - [TomCountResult](#tomcountresult)
    - [TomRepository&lt;T, K&gt;](#tomrepositoryt-k)
    - [TomSqlDatasourceRepository&lt;T, K&gt;](#tomsqldatasourcerepositoryt-k)
    - [MariadbRepository&lt;T, K&gt;](#mariadbrepositoryt-k)
  - [Query Building](#query-building)
    - [TomQueryBuilder](#tomquerybuilder)
    - [TomQuerySentenceCompiler](#tomquerysentencecompiler)
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
    - [TomDataScopeRegistry](#tomdatascoperegistry)
    - [TomDataScopePredicate](#tomdatascopepredicate)
    - [TomDataScopeBypass](#tomdatascopebypass)
    - [TomDataScope](#tomdatascope)
  - [Analyzer](#analyzer)
    - [TomAnnotationAnalyzer](#tomannotationanalyzer)
  - [Exceptions](#exceptions)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source:
`lib/src/tomserver/object_persistence/annotation_analyzer.dart`,
`lib/src/tomserver/object_persistence/column_authorization.dart`,
`lib/src/tomserver/object_persistence/crud_repository.dart`,
`lib/src/tomserver/object_persistence/data_scope.dart`,
`lib/src/tomserver/object_persistence/grouped_query.dart`,
`lib/src/tomserver/object_persistence/mariadb_repository.dart`,
`lib/src/tomserver/object_persistence/operators_expressions.dart`,
`lib/src/tomserver/object_persistence/persistence_annotations.dart`,
`lib/src/tomserver/object_persistence/query_builder.dart`,
`lib/src/tomserver/object_persistence/query_sentence_compiler.dart`.

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
expression tree rendered through a `TomStandardSqlDialect`. `@TomDbScope`
(row-level, C-3) and `@TomDbColumn(authKey: …)` (column-level, C-4) add
server-authoritative access control enforced by `TomDataScope` /
`TomColumnAuthorization`, all binding values as prepared-statement parameters
(C-7).

## Class Hierarchy

```
TomServerException  (server)
    ├── TomAnnotationAnalyzerException
    ├── TomAnnotationAnalyzerSyntaxException
    ├── TomColumnAuthorizationException
    ├── TomDataScopeException
    ├── TomDataScopeAuthorizationException
    └── TomQuerySyntaxException

TomRepository<T, K>
    └── TomSqlDatasourceRepository<T, K>  (with TomQueryBuilder)
            └── MariadbRepository<T, K>

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
    ├── TomUnaryOperator<T, R>
    │       ├── DbCol<R>
    │       │       ├── IntCol / StringCol / DoubleCol
    │       │       └── BoolCol / DateTimeCol / DateCol
    │       ├── StringLiteral / IntegerLiteral / DoubleLiteral
    │       ├── BoolLiteral / DateTimeLiteral / DateLiteral
    │       ├── Not / IsNull<T> / IsNotNull<T>
    │       ├── And / Or
    │       └── Group<T>
    └── TomBinaryOperator<T1, T2, R>
            ├── Eq<T> / Neq<T> / Lt<T> / Gt<T> / Lte<T> / Gte<T>
            ├── Like / NotLike / Regexp
            └── In<T> / Between<T>

TomGroupedRow  (plain value holder)

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
  required String primaryKeyField,
  String? idColumn,
  String? schema,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `String` | The registered data source that holds this table. |
| `table` | `String` | The table name. |
| `schema` | `String?` | The schema the table belongs to, if any. |
| `primaryKeyField` | `String` | The entity field that holds the primary key. |
| `idColumn` | `String?` | The primary-key column name, when it differs from `primaryKeyField`. |

#### TomDbColumn&lt;DART_TYPE, COL_TYPE&gt;

Annotation that maps an entity field to a database column. `authKey` opts the
column into column-level access rights (C-4).

- **Type Parameters:** `DART_TYPE` — the Dart-side type; `COL_TYPE extends TomDbType` — the SQL-side boxed type.

##### Constructors

```dart
const TomDbColumn({
  required String? columnName,
  bool isReadOnly = false,
  bool noLoad = false,
  bool isJson = false,
  String? authKey,
  Type? dartType,
  DART_TYPE Function(COL_TYPE)? fromDbConverter,
  COL_TYPE Function(DART_TYPE)? toDbConverter,
  Type? columnType,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columnName` | `String?` | The column name; defaults to the field name when `null`. |
| `isReadOnly` | `bool` | Whether the column is excluded from inserts and updates. |
| `noLoad` | `bool` | Whether the column is excluded from selects. |
| `isJson` | `bool` | Whether the column holds JSON-encoded data. |
| `authKey` | `String?` | The resource key that gates this column's read/write access (C-4); `null` leaves it unrestricted. |
| `dartType` | `Type?` | The Dart type, when it cannot be inferred from `DART_TYPE`. |
| `columnType` | `Type?` | The SQL column type, when it cannot be inferred from `COL_TYPE`. |
| `fromDbConverter` | `DART_TYPE Function(COL_TYPE)?` | Converts a stored `COL_TYPE` value back to the Dart `DART_TYPE`. |
| `toDbConverter` | `COL_TYPE Function(DART_TYPE)?` | Converts a Dart `DART_TYPE` value to the stored `COL_TYPE`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `declaredDartType` | `Type? declaredDartType()` | The declared Dart type: `DART_TYPE` when concrete, else `dartType`. |
| `declaredColumnType` | `Type? declaredColumnType()` | The declared SQL column type: `COL_TYPE` when concrete, else `columnType`. |

#### TomEntityId

Annotation marking the entity field that holds the primary key.

##### Constructors

```dart
const TomEntityId()
```

#### TomDbScope

Annotation declaring the row-level data scope of an entity (C-3): it restricts
which rows the repository returns to those the current principal may see.

##### Constructors

```dart
const TomDbScope({required String field, String scope = 'owner'})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The entity field whose value is matched against the principal's allowed scope values. |
| `scope` | `String` | The scope kind — a key into `TomDataScopeRegistry` selecting the resolver (default `'owner'`). |

#### TomJoinTable

Annotation describing a many-to-many join table between two entities. (Declared
for future use — not yet detected or applied by the persistence layer.)

##### Constructors

```dart
const TomJoinTable({
  required Type targetEntity,
  required Type repositoryType,
  required Type keyType,
  required Type originEntity,
  required List<String> leftSideColumns,
  required List<String> rightSideColumns,
  List<String> contextColumns = const [],
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `targetEntity` | `Type` | The entity on the far side of the join. |
| `repositoryType` | `Type` | The repository type that loads `targetEntity`. |
| `originEntity` | `Type` | The entity on the near side of the join. |
| `keyType` | `Type` | The key type linking the two sides. |
| `leftSideColumns` | `List<String>` | The join-table columns on the origin side. |
| `rightSideColumns` | `List<String>` | The join-table columns on the target side. |
| `contextColumns` | `List<String>` | Extra join-table columns carried as context. |

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

#### TomPersistenceEventHandler&lt;DBTYPE&gt;

Annotation registering lifecycle callbacks for an entity `DBTYPE`. (Declared
for future use — not yet detected or invoked by the persistence layer.)

- **Type Parameters:** `DBTYPE` — the entity type the callbacks receive.

##### Constructors

```dart
TomPersistenceEventHandler({
  void Function(DBTYPE)? postPersist,
  void Function(DBTYPE)? postLoad,
  void Function(DBTYPE)? preLoad,
  void Function(DBTYPE)? prePersist,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `postPersist` | `void Function(DBTYPE)?` | Called after the entity is persisted. |
| `postLoad` | `void Function(DBTYPE)?` | Called after the entity is loaded. |
| `prePersist` | `void Function(DBTYPE)?` | Called before the entity is persisted. |
| `preLoad` | `void Function(DBTYPE)?` | Called before the entity is loaded. |

#### TomColumnInformation

The resolved persistence metadata for a single entity field: the owning table,
the field's annotations, its declared type/name, the mapped column, and
reflection-backed accessors to read/write the field.

##### Constructors

```dart
TomColumnInformation(
  TomDbTable table,
  Type tableType,
  TomDbColumn? column,
  TomEntityId? entityId,
  TomReference? reference,
  TomPersistenceEventHandler? eventHandler,
  Type declaredType,
  String declaredName,
  String field, {
  TomFileReference? fileReference,
})
```

`fileReference` is named and optional because it arrived after the positional
list was already in use across the module; only a file-reference column passes
it.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tableType` | `Type` | The entity type that owns this field. |
| `table` | `TomDbTable` | The table the owning entity maps to. |
| `column` | `TomDbColumn?` | The field's column mapping, if annotated. |
| `entityId` | `TomEntityId?` | The entity-id annotation, if this field is the primary key. |
| `reference` | `TomReference?` | The reference annotation, if this field is an association. |
| `eventHandler` | `TomPersistenceEventHandler?` | The lifecycle-callback annotation, if any. |
| `fileReference` | `TomFileReference?` | The file-reference annotation, if this column holds a blob storage key. |
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

#### TomRepositoryType

Annotation binding a `TomSqlDatasourceRepository` subclass to a named data-source
type (e.g. `"mariadb"`) for reflection-based repository discovery. `@tomReflector`.

##### Constructors

```dart
const TomRepositoryType(String datasourceType)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceType` | `String` | The data-source type this repository serves. |

### Repositories

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
| `delete` | `Future<void> delete(T entity)` | Deletes `entity` by its primary key. |
| `deleteAllById` | `Future<void> deleteAllById(Iterable<K> ids)` | Deletes every entity whose id is in `ids`. |
| `deleteById` | `Future<void> deleteById(K id)` | Deletes the entity with the given `id`. |
| `existsById` | `Future<bool> existsById(Iterable<K> ids)` | Whether every id in `ids` exists. |
| `findAll` | `Future<List<T>> findAll([TomPageRequest? page])` | Loads all entities, or the window `page` asks for. |
| `findAllById` | `Future<List<T>> findAllById(Iterable<K> ids, [TomPageRequest? page])` | Loads every entity whose id is in `ids`, optionally windowed. |
| `findById` | `Future<T?> findById(K id)` | Loads the entity with the given `id`, or `null` if absent. |
| `count` | `Future<TomDbInt> count()` | Counts all entities. |
| `save` | `Future<T> save(T toSave)` | Inserts (no primary key) or updates (primary key set) and returns the stored entity. |
| `saveAll` | `Future<Iterable<T>> saveAll(Iterable<T> entities)` | Saves every entity and returns the stored entities. |
| `findByQuerySentence` | `Future<Iterable<T>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType, TomPageRequest? page])` | Runs a parsed query sentence as a `SELECT`, binding `params`, optionally windowed. |
| `deleteByQuerySentence` | `Future<void> deleteByQuerySentence(String querySentence, Map<String, Object?> params)` | Runs a parsed query sentence as a `DELETE`. |
| `countByQuerySentence` | `Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)` | Runs a parsed query sentence as a `COUNT`. |
| `findByQuery` | `Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params, [TomPageRequest? page])` | Runs a built `TomSelect`, binding `params`, optionally windowed. |
| `deleteByQuery` | `Future<void> deleteByQuery(TomDelete query, Map<String, Object?> params)` | Runs a built `TomDelete`, binding `params`. |
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
- **Type Parameters:** `T extends Object` — the entity type; `K` — its key type.

##### Constructors

```dart
TomSqlDatasourceRepository([List<Type>? queryTypes, Type? resultType])
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isUnsavedKey` | `static bool isUnsavedKey(Object? primaryKey)` | Whether `primaryKey` marks a not-yet-persisted entity (`null` or negative sentinel), so `save` should `INSERT`. |
| `readPrimaryKey` | `static K2? readPrimaryKey<K2>(Object? raw)` | Reads an entity's primary-key value as a nullable `K2`. |
| `buildInsertStatement` | `static (String, List<String>) buildInsertStatement(String table, List<TomColumnInformation> columns)` | Builds the `INSERT` SQL and its ordered bind-parameter names. |
| `buildUpdateStatement` | `static (String, List<String>) buildUpdateStatement(String table, List<TomColumnInformation> columns, TomColumnInformation primaryKey)` | Builds the `UPDATE ... SET ... WHERE pk = :pk` SQL and its ordered bind names. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `primaryKeyColumnInfo` | `TomColumnInformation` | Resolved metadata for the primary-key column. |
| `datasourceInfo` | `TomDataSourceInfo` | The resolved data source this repository runs against. |
| `persistenceInfo` | `TomTypePersistenceInfo` | The resolved persistence metadata of the entity. |
| `dbTable` | `TomDbTable` | The table the entity maps to. |
| `sqlDialect` | `TomStandardSqlDialect` | *(getter)* The SQL dialect used to render queries; defaults to the data source's dialect. |
| `queryTypes` | `List<Type>` | The entity types this repository can query (first is the primary entity). |
| `resultType` | `Type` | The default row type for results. |

##### Methods

Overrides every method of `TomRepository<T, K>` (see above), applying C-3 row
scoping and C-4 column masking/enforcement on the SQL data source.

#### MariadbRepository&lt;T, K&gt;

A `TomSqlDatasourceRepository` for MariaDB-backed entities, registered via
`@TomRepositoryType("mariadb")`. Overrides `sqlDialect` to render with
`MariadbSqlDialect`. `@tomReflector`.

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
| `boolOp` | `TomOperator<TomDbBool> boolOp(bool value)` | A boolean literal. |
| `dateTimeOp` | `TomOperator<TomDbDateTime> dateTimeOp(DateTime value)` | A timestamp literal. |
| `dateOp` | `TomOperator<TomDbDate> dateOp(DateTime value)` | A date literal. |
| `p` | `TomOperator<T> p<T>(String parameterName)` | A named positional parameter placeholder (`:parameterName`). |
| `textF` | `TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `String` column. |
| `intF` | `TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)` | A reference to an `int` column. |
| `doubleF` | `TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `double` column. |
| `boolF` | `TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)` | A reference to a `bool` column. |
| `dateTimeF` | `TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)` | A reference to a timestamp column. |
| `dateF` | `TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)` | A reference to a date column. |

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

`min`/`max` are split by type rather than left generic because they preserve the
operand's type on both sides (SQL and Dart); `sum`/`avg` always widen to `double`
and so need no such split.

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

### Paging & Sorting

#### TomSortDirection

The direction one sort term orders in: `ascending` or `descending`. `sqlKeyword`
renders it as `ASC` / `DESC`.

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
| `assertWindow` | `static void assertWindow({required int limit, required int offset})` | Rejects a row window that is not renderable. |

**The result is the page, not a page object.** A finder given a request returns
the rows of that window as a plain `List<T>`; the total comes from the matching
`count` method, which applies the same row scope — so a caller that does not need
the total does not pay for it, and page metadata never reports rows the principal
may not see. When a window is requested and the caller's `sort` does not already
settle the order, the repository appends the entity's primary key ascending, so
consecutive pages neither repeat nor drop rows.

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

Each takes the constructor `(Type tableType, String operant1, TomColumnInformation columnInformation)`.

#### Literals

Each literal wraps a Dart value and renders it through the dialect.

| Class | Extends | Constructor | Renders |
| ----- | ------- | ----------- | ------- |
| `StringLiteral` | `TomUnaryOperator<String, TomDbString>` | `StringLiteral(String operant1)` | A single-quoted string literal. |
| `IntegerLiteral` | `TomUnaryOperator<int, TomDbInt>` | `IntegerLiteral(int operant1)` | An integer literal. |
| `DoubleLiteral` | `TomUnaryOperator<double, TomDbDouble>` | `DoubleLiteral(double operant1)` | A double literal. |
| `BoolLiteral` | `TomUnaryOperator<bool, TomDbBool>` | `BoolLiteral(bool operant1)` | A boolean literal. |
| `DateTimeLiteral` | `TomUnaryOperator<DateTime, TomDbDateTime>` | `DateTimeLiteral(DateTime operant1)` | A timestamp literal. |
| `DateLiteral` | `TomUnaryOperator<DateTime, TomDbDate>` | `DateLiteral(DateTime operant1)` | A date literal. |

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
| `dateTimeValue` | `DateTime? dateTimeValue(String alias)` | The value as a `DateTime`. |
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
| `stateForKey` | `static TomAuthState stateForKey(String? authKey, {TomColumnAuthResolver? resolver})` | The `TomAuthState` the principal holds on the column identified by `authKey`, or `full` when `authKey` is `null`. |
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
| `resolve` | `static Future<TomAuthState?> resolve(String? authKey, Object? rowId)` | The per-row grade, or `null` when the column is unrestricted or has no resolver. |
| `reset` | `static void reset()` | Clears every registration (tests, re-boot). |

#### TomDataScopeRegistry

Registry of the named row-scope resolvers a `@TomDbScope` can reference. Ships
with `'owner'` and `'group'` resolvers. All members are static.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(String scope, TomDataScopeResolver resolver)` | Registers (or replaces) the synchronous resolver for scope kind `scope`. |
| `registerAsync` | `static void registerAsync(String scope, TomAsyncDataScopeResolver resolver)` | Registers (or replaces) the asynchronous (union/OR) resolver for `scope`. |
| `resolverFor` | `static TomDataScopeResolver? resolverFor(String scope)` | The synchronous resolver for `scope`, or `null`. |
| `asyncResolverFor` | `static TomAsyncDataScopeResolver? asyncResolverFor(String scope)` | The asynchronous resolver for `scope`, or `null`. |
| `isAsync` | `static bool isAsync(String scope)` | Whether `scope` resolves asynchronously (registered via `registerAsync`). |
| `reset` | `static void reset()` | Restores the built-in resolvers, discarding custom registrations. |

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
| `buildAsync` | `static Future<TomDataScopePredicate?> buildAsync(TomQueryBuilder builder, TomDbScope scope, TomColumnInformation col, TomPrincipal? principal)` | Builds the union scope predicate for an async scope (RCB8). |
| `anyOf` | `static TomDataScopePredicate anyOf(TomQueryBuilder builder, TomColumnInformation col, List<List<Object?>> groups)` | The union predicate over id-set groups: an OR of one `IN` list per group. |
| `inList` | `static TomDataScopePredicate inList(TomQueryBuilder builder, TomColumnInformation col, Iterable<Object?> values, {String prefix = parameterPrefix})` | Builds `<col> IN (…)` binding one parameter per value. |
| `allowedValues` | `static List<Object?>? allowedValues(TomDbScope scope, TomPrincipal? principal)` | Resolves the scope-field values `principal` is allowed for `scope`. |
| `permits` | `static bool permits(List<Object?>? allowed, Object? value)` | Whether `value` falls within the `allowed` scope values (C-3 write membership). |
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
annotations. A mixin whose members are all static; results are memoised in the
per-type caches.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analysePersistentType` | `static TomTypePersistenceInfo analysePersistentType(Type T)` | Resolves the full persistence metadata (table + columns) for entity `T`. Throws `TomAnnotationAnalyzerException`. |
| `findMirror` | `static ClassMirror? findMirror(Type dbType)` | The cached/looked-up `ClassMirror` for `dbType`, or `null` when unregistered. |
| `findTable` | `static TomDbTable? findTable(Type dbType)` | The `@TomDbTable` annotation on `dbType`, or `null` if absent. |
| `findDataScope` | `static TomDbScope? findDataScope(Type dbType)` | The `@TomDbScope` annotation on `dbType`, or `null` when unscoped. |
| `findAuthColumns` | `static List<TomColumnInformation> findAuthColumns(Type dbType)` | The columns of `dbType` that opt into column-level access rights (C-4), or empty. |
| `getPersistentColumns` | `static List<TomColumnInformation>? getPersistentColumns(Type dbType)` | The persistence metadata for every annotated field, or `null` if not reflectable. Throws `TomAnnotationAnalyzerSyntaxException`. |
| `determineColumn` | `static TomColumnInformation determineColumn(String name, List<TomTypePersistenceInfo> persistenceInfo)` | Finds the `TomColumnInformation` matching `name`. Throws `TomAnnotationAnalyzerSyntaxException` when nothing matches. |
| `referenceQuery` | `static ({String sentence, Map<String, Object?> parameters}) referenceQuery(TomReference reference, Type owningType, Object? Function(String field) readOwningField)` | The `FIND BY` sentence resolving a `@TomReference` for one mapped row, and the parameters it binds. Throws `TomAnnotationAnalyzerSyntaxException` for a malformed expression, `TomAnnotationAnalyzerException` for a context value the zone cannot supply. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mirrorCache` | `static final Map<Type, ClassMirror?>` | Cache of resolved class mirrors per entity type. |
| `tableCache` | `static final Map<Type, TomDbTable?>` | Cache of resolved `@TomDbTable` annotations per entity type. |
| `columnInfoCache` | `static final Map<Type, List<TomColumnInformation>?>` | Cache of resolved column metadata lists per entity type. |
| `dataScopeCache` | `static final Map<Type, TomDbScope?>` | Cache of resolved `@TomDbScope` annotations per entity type. |
| `authColumnCache` | `static final Map<Type, List<TomColumnInformation>>` | Cache of the column-authorized columns per entity type. |

### Exceptions

All extend the server `TomServerException`.

| Class | Source | Thrown when |
| ----- | ------ | ----------- |
| `TomAnnotationAnalyzerException` | `annotation_analyzer.dart` | An entity's persistence metadata cannot be resolved (not registered / no `@TomDbTable`). |
| `TomAnnotationAnalyzerSyntaxException` | `annotation_analyzer.dart` | Persistence annotations are present but malformed (e.g. `@TomDbColumn` on a non-variable). |
| `TomColumnAuthorizationException` | `column_authorization.dart` | A write changes a column visible-but-not-editable to the principal (C-4 violation). |
| `TomDataScopeException` | `data_scope.dart` | A `@TomDbScope` names a scope kind no resolver is registered for. |
| `TomDataScopeAuthorizationException` | `data_scope.dart` | A write targets a row outside the current principal's `@TomDbScope` (C-3). |
| `TomQuerySyntaxException` | `operators_expressions.dart` | A query expression is malformed (e.g. `BETWEEN` without exactly two bounds; also raised by the query-sentence compiler). |

Each exception constructor forwards the standard `TomServerException` positional
`key` and `defaultUserMessage` plus the optional named `parameters`, `stack`,
`rootException`, `autoLog` (and, for `TomColumnAuthorizationException` /
`TomDataScopeAuthorizationException`, `clientThrow`).

## Enums

One: `TomSortDirection`, documented under
[Paging & Sorting](#tomsortdirection) beside the `TomSortField` that carries it,
because a direction is only ever met as one term's direction.

## Global Functions and Constants

None — this module exposes no top-level functions or constants. It does declare
four top-level typedefs used by the scoping/authorization APIs:

| Typedef | Definition | Source |
| ------- | ---------- | ------ |
| `TomColumnAuthResolver` | `TomAuthState Function(String authKey)` | `column_authorization.dart` |
| `TomRowColumnAuthResolver` | `Future<TomAuthState> Function(TomPrincipal? principal, Object? rowId)` | `column_authorization.dart` |
| `TomDataScopeResolver` | `List<Object?>? Function(TomPrincipal? principal)` | `data_scope.dart` |
| `TomAsyncDataScopeResolver` | `Future<List<List<Object?>>?> Function(TomPrincipal? principal)` | `data_scope.dart` |
