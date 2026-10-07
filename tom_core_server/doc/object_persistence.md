# Object Persistence Module

A lightweight, annotation-driven ORM: map a reflected entity class to a database
table, then read and write it through a Spring-Data-style repository. Queries can
be expressed three ways — a parsed *query sentence*, a programmatically built
`TomQuery`, or raw SQL — and all of them render through a pluggable SQL dialect.

## Table of Contents

- [Overview](#overview)
- [Mapping an Entity](#mapping-an-entity)
  - [Associations (`@TomReference`)](#associations-tomreference)
- [The Repository Contract](#the-repository-contract)
  - [What a delete returns](#what-a-delete-returns)
  - [How a repository fails](#how-a-repository-fails)
  - [Paging and Sorting](#paging-and-sorting)
  - [Lifecycle work](#lifecycle-work)
- [Query Sentences](#query-sentences)
  - [Which kind takes which option](#which-kind-takes-which-option)
  - [`IS IN` lists](#is-in-lists)
  - [Column types a predicate can address](#column-types-a-predicate-can-address)
  - [What a comparison compares](#what-a-comparison-compares)
  - [Writing a value inline](#writing-a-value-inline)
    - [Inside a text literal](#inside-a-text-literal)
  - [Matching literal text](#matching-literal-text)
  - [Words this grammar does not have](#words-this-grammar-does-not-have)
- [The Query Builder DSL](#the-query-builder-dsl)
- [Row Scopes](#row-scopes)
  - [Declaring a scope](#declaring-a-scope)
  - [Automatic scoping, and opting out](#automatic-scoping-and-opting-out)
  - [How a scope renders](#how-a-scope-renders)
  - [Async resolvers must not recurse](#async-resolvers-must-not-recurse)
  - [Reads filter, writes reject](#reads-filter-writes-reject)
  - [Reading and writing can differ](#reading-and-writing-can-differ)
  - [The grant-driven `resource` kind](#the-grant-driven-resource-kind)
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
| `TomDartType` | class | Wraps a `Type` so it can be carried as a value, where a bare `Type` literal is awkward to pass |
| `TomRepository<T, K>` | abstract class | The CRUD + query contract for entity `T` keyed by `K` |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL implementation of the contract |
| `MariadbRepository<T, K>` | class | MariaDB binding — constructed directly, and the only thing it adds is `MariadbSqlDialect` |
| `TomPageRequest` | class | One page of a query. The repository appends the primary key as a final sort term, because "page 2" of an unordered query is otherwise not the complement of "page 1" |
| `TomSortField` / `TomSortDirection` | class / enum | One sort term — a declared field name where the caller writes it, a rendered column expression by the time SQL is generated |
| `TomCountResult` | class | The row a `COUNT` projects into; the column alias *is* the binding, and nothing checks it |
| `TomQuerySentenceCompiler` | class | Parses a query sentence into a `TomQuery` |
| `TomQueryBuilder` | mixin | Fluent factory for the `TomOperator` expression tree |
| `TomAggregate` | abstract class | An aggregate function node (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`) |
| `TomGroupedSelect` | class | A `SELECT … GROUP BY … HAVING` compiled from group keys and aggregates |
| `TomGroupedRow` | class | One group's result: the group keys plus the aggregate values, keyed by alias |
| `TomAnnotationAnalyzer` | mixin | Resolves an entity's persistence metadata by reflection |
| `TomColumnInformation` | class | The resolved metadata for one entity field |
| `TomDbScope` | class | Declares (or explicitly opts out of) an entity's row scope |
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
| `TomRepositoryException` / `TomQuerySyntaxException` | class | A failed operation / a query sentence that will not parse |
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
| `DbCol<R>` | abstract class | A column reference, typed by what the column holds |
| `BoolCol` / `IntCol` / `DoubleCol` / `StringCol` / `DateCol` / `DateTimeCol` / `TimeCol` | class | The seven concrete column references |
| `BoolLiteral` / `IntegerLiteral` / `DoubleLiteral` / `StringLiteral` / `DateLiteral` / `DateTimeLiteral` / `TimeLiteral` | class | The seven inline literals |
| `Parameter<T>` | class | A bound placeholder — what a value becomes when it is not written inline |
| `CountAll` / `Count` / `Sum` / `Avg` / `Min` / `Max` | class | The six aggregates `TomGroupedSelect` projects |

## Mapping an Entity

Annotate a `@tomReflector` class with `@TomDbTable` and its fields with
`@TomDbColumn` (and `@TomEntityId` on the primary key):

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'users', primaryKeyField: 'id')
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

`@TomDbColumn` can mark a column `isReadOnly` (skipped on insert/update),
`noLoad` (skipped on select), or `isJson`, and can carry `fromDbConverter` /
`toDbConverter` functions to translate between the Dart value and the boxed
`TomDbType` stored in the column.

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
@TomDbTable(datasource: 'app', table: 'user_role', primaryKeyField: 'id')
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

The entity needs **one** primary-key field, so a join table maps unchanged when
it has a key column of its own. One keyed only by its two foreign keys has no
single field to name: the module has no composite primary key (see
[Not Yet Implemented](#not-yet-implemented)), and such a table needs a
surrogate key column before it can be mapped.

**One reference query per owning row.** The association cannot be resolved while
its row is being mapped, so the mapper stacks the row's pending references and
drains the stack at the end of *that row*. A stack shared across rows would
re-resolve every earlier row's associations for each row that follows, turning
an *n*-row read into *n(n+1)/2* reference queries. The answer would be the same
— each fill clears the list before adding, so resolving an owner twice
recomputes the same list — which is why the cost is the only observable, and why
`test/reference_association_db_test.dart` asserts it by counting statements
rather than by inspecting rows.

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

The number comes from the statement's own result
(`TomPreparedStatement.lastAffectedRows`), read while the statement is still
allocated. It is not derived from a follow-up `SELECT`, so it is exactly what
the server did — including `0` for a predicate that matched nothing.

### How a repository fails

Every repository rejection is a keyed `TomServerException`, never a bare
`Exception`, so a handler can match on the key and a catalogue can localise it.

`TomRepositoryException` covers the repository's own preconditions, under
`crud_repository.<method>.<condition>` keys:

| Key | Raised when |
| --- | ----------- |
| `crud_repository.constructor.datasource_not_registered` | The entity's `@TomDbTable` names a datasource no `TomDataSourceInfo` was registered for. |
| `crud_repository.find_by_id.duplicate_primary_key` | A primary-key lookup matched more than one row. |
| `crud_repository.count.illegal_count_result` | `count()`'s `COUNT(*)` returned other than exactly one row. |
| `crud_repository.count_by_query.illegal_count_result` | Ditto for `countByQuery`. |
| `crud_repository.count_by_query_sentence.illegal_count_result` | Ditto for `countByQuerySentence`. |
| `crud_repository.save.no_generated_key` | An `INSERT` whose primary key was left for the database to assign reported no generated key — the table assigns none, or the driver does not report one from the insert's result. |
| `crud_repository.save.insert_not_readable` | An `INSERT` reported success but the new row could not be read back. |
| `crud_repository.save.update_not_readable` | An `UPDATE` ran but the row could not be re-read. |
| `crud_repository.delete.unsaved_entity` | `delete(entity)` was handed an entity that was never persisted. |

The first eight are *server* faults — a broken deployment, a table contradicting
its own key, a driver that reported a write it then could not read — so
`clientThrow` defaults to `false`: the key travels to the caller, the message
(which names internals) does not.

`crud_repository.delete.unsaved_entity` is the exception, and sets
`clientThrow: true`. An entity whose primary key is still `null` (a nullable
surrogate key before its first save) or negative (the `id >= 0` sentinel
convention) addresses no row, so there is nothing to delete. Refusing it is a
statement about the caller's own argument, and the message says exactly that —
where masking it would leave the caller with a generic error for the one
repository failure it is the only party able to fix.

Before this check existed the two unsaved conventions failed differently and
neither failed usefully: a `null` key threw a raw `TypeError` naming `Null` and
`int`, and a negative key passed the cast, ran a `DELETE` that matched no row,
and reported success for a deletion that never happened.

The `*ByQuerySentence` methods add three keys of their own,
`crud_repository.<method>.sentence_verb_mismatch`, raised as
`TomQuerySyntaxException` because a sentence whose verb does not match the method
is the caller's mistake and the caller's to correct.

`TomBlobMigrationException` covers the row-driven blob migration
([Migrating Between Backends](file_storage.md#migrating-between-backends)),
under `storage.migration.*` keys:

| Key | Raised when |
| --- | ----------- |
| `storage.migration.scoped_run` | A request principal is in the zone. The sweep would migrate that principal's *view* of the table — row scope applied, protected columns masked to `null` — and report success. Raised before a single row is read. |
| `storage.migration.no_file_columns` | The entity declares no `@TomFileReference` column. Named rather than swept, because a migration reporting "0 blobs" for an entity that stores none looks exactly like one that worked. |
| `storage.migration.unknown_field` | `fields` names a column that is not a file column of the entity. |
| `storage.migration.verification_failed` | A copy did not match what was read. The one failure a later pass cannot detect — the next run finds the key present and moves on — so it stops the migration rather than being reported. |

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
therefore appends the entity's primary key ascending as a final sort term
whenever a window is requested and the caller's sort does not already settle it.

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

Work that has to happen just before a row is written, or just after one is read,
is an **override of the repository method that performs it**. There is no
annotation for it.

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

**The read side has four entry points, not one.** `findById`, `findAll`,
`findAllById` and the query-sentence / query-builder finds each materialise rows
independently, and the masking funnel they share is private. A hook that must
see *every* loaded row is therefore repeated per method rather than declared
once.

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
| *Exists* | — |
| *isEmpty*, *isNotEmpty* | — |

The last two have no dash for a reason: **they have nothing to address.** A
mapped column is one of eight scalar Dart types and none of them is a
collection, and an association declared with `@TomReference` is loaded by a
repository call rather than joined — so there is no collection-valued property
for `isEmpty` to test. `Exists` needs a correlated subquery, which the operator
tree has no node for. Both would be new machinery rather than new spellings, and
neither is promised.

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
@TomDbTable(datasource: 'main', table: 'note', primaryKeyField: 'id')
@TomDbScope(field: 'ownerId')          // scope defaults to 'owner'
class Note {
  @TomEntityId() @TomDbColumn(columnName: 'id') int? id;
  @TomDbColumn(columnName: 'owner_id') int ownerId = 0;
}
```

Three kinds are registered out of the box:

| Kind | Allowed values | Resolution |
| ---- | -------------- | ---------- |
| `owner` | `principal.id` | synchronous |
| `group` | `principal.aci.groups` | synchronous |
| `resource` (`TomDbScope.resourceScope`) | the resource keys the principal holds a grant on | **asynchronous**, through the installed `TomResourceScopeSource` |

An application adds its own (`'tenant'`, `'organization'`, …) with
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
- **an empty result** denies every row, rendering a bare `FALSE` (`IN ()` is not
  valid SQL, and an allowed-value set of no values matches no rows);
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
which nothing references and a sweep can collect; and even that is cleaned up
when the save throws.

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
happens to hand back. `MariaDbDatasource.mapGroupedRow` reads each alias as the
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
[`datasources.md`](datasources.md#the-mariadb-driver) for the shared read
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
JSON column is text whatever its Dart type, an explicit `TomDbType` box decides
next, and only failing both does the Dart type stand in; anything unrecognised is
`unknown`, which is compatible with everything, because a gap in the reader's
knowledge must not be reported as a defect. It is homed here, beside the
annotations it reads, rather than with either of its callers: the
schema-convergence check ([`db_migration.md`](db_migration.md#schema-convergence))
and the reflected export projection ([`export.md`](export.md#columns-derived-from-the-entity))
ask the same question of the same declaration, and a second answer would be a
second thing to keep in step. Note what it does *not* describe — the Dart value a
getter returns; a caller that cares about that must read
`TomColumnInformation.declaredType` as well, which is what the export projection
does.

## SQL Dialects

Every operator renders itself through a `TomStandardSqlDialect` (see
`doc/datasources.md`). A driver subclasses the dialect to override any fragment;
`MariadbRepository` uses `MariadbSqlDialect`.

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
a repository against a real MariaDB, which is the half that cannot be settled by
reading generated SQL — including the one claim in
[Matching literal text](#matching-literal-text) that is about what the
*database* does with a pattern rather than about what the query says.

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

## Core Components

- **Annotations** — `TomDbTable`, `TomDbColumn`, `TomEntityId`, `TomReference`,
  plus `TomDartType`.
- **`TomColumnInformation`** — resolved per-field metadata + reflection accessors.
- **`TomRepository` / `TomSqlDatasourceRepository` / `MariadbRepository`** — the
  CRUD/query contract and its SQL/MariaDB implementations.
- **`TomQuerySentenceCompiler`** — query-sentence parser.
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

## Not Yet Implemented

The first and last entries are about the *shape of a predicate*, and both are
bounded by the same thing: an expression tree over the columns of the tables a
query already names. The middle one is about how a row is addressed.

- **A predicate cannot address an association's columns.** `@TomReference`
  declares an association, and the repository loads the other side with a
  second query rather than joining it — so `find by author.name = :n` has no
  reading, and the sentence refuses `author.name` as a column it cannot
  resolve. Filter on the foreign key, or query the other entity's repository
  and pass the ids to an `IS IN` list.
  <!-- pinned: test/query_sentence_declined_words_test.dart › a predicate cannot address an association's columns -->
- **There is no composite primary key.** `@TomDbTable.primaryKeyField` names
  one field, and `findById`, `save` and `delete` address a row by that one
  value. A table keyed by several columns — the usual shape of a legacy
  many-to-many join table — is mapped once it has a single key column; until
  then its rows are reached through `executeQueryString`.
  <!-- unpinned: absence — TomDbTable takes one primaryKeyField -->
- **There is no subquery node**, so a predicate that is *about* another result
  set — `EXISTS`, `IN (SELECT …)`, a correlated aggregate — cannot be built.
  `executeQueryString` takes the SQL directly when a query genuinely needs one;
  it binds its parameters like any other statement, so reaching for it costs the
  compiler's checking, not the injection safety.
  <!-- unpinned: absence — no subquery node exists -->

What is *not* listed here is a vocabulary of word-operators — *After*,
*Containing*, *StartsWith* and their siblings. They are set in italics because
none of them is code: they are not missing but declined, since a query sentence
is a string and `>` and `%` are directly writable in one. See
[Words this grammar does not have](#words-this-grammar-does-not-have).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `blob_migration.dart`, `data_scope.dart` | `Future` |
| `tom_core_kernel` | package | 8 of 13 files | `tomReflector` (mirrors), the `TomZoned*` date/time types |
| `uuid` | package | `file_reference.dart` | `Uuid.v4`, for the file name in a blob key |
| [audit](audit.md) | module | `crud_repository.dart` | `TomAuditAction`, `TomAuditTrail` |
| [datasources](datasources.md) | module | 9 of 13 files | `TomDbType`/`TomOperator`/`SqlString`, `TomStandardSqlDialect` / `MariadbSqlDialect` (including the `aggregate`, `aliased`, `groupByClause` and `havingClause` fragments), `TomQuery` family (`TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect`), `TomAggregateFunction`, `TomTypedPersistenceBase`, `TomTypePersistenceInfo`, `TomDataSourceInfo`, `TomPreparedStatement` |
| [file_storage](file_storage.md) | module | `blob_migration.dart`, `crud_repository.dart`, `file_reference.dart` | `TomBlobStore`, `TomBlobStoreInfo`, `TomStorageException`, `TomStoredBlob` |
| [little_things](little_things.md) | module | `annotation_analyzer.dart`, `blob_migration.dart`, `column_authorization.dart`, `crud_repository.dart`, `data_scope.dart`, `operators_expressions.dart` | `TomServerException` (base of the module's exceptions) |
