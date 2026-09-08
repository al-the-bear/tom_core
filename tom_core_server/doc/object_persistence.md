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
- [Query Sentences](#query-sentences)
  - [`IS IN` lists](#is-in-lists)
  - [Column types a predicate can address](#column-types-a-predicate-can-address)
  - [What a comparison compares](#what-a-comparison-compares)
  - [Writing a value inline](#writing-a-value-inline)
    - [Inside a text literal](#inside-a-text-literal)
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
| `TomJoinTable` | class | A join-table annotation the persistence layer neither detects nor applies — declared, and inert |
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
| `TomPersistenceEventHandler` | class | A field-level lifecycle-callback annotation; resolved by the analyzer, and no callback is invoked yet |
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
rejected outright: it constrains nothing, so it would load every join row for
every owner row.

The field must be **non-null and modifiable** — `List<Role> roles = []`, not
`List<Role>? roles`. The mapper fills the list the entity already holds instead
of assigning a fresh one, because reflection cannot construct a `List<Role>`
from a mirror that carries no type arguments. A `null` field is refused with
`error.result_processing.ref_reference_field_must_have_non-null_value`, naming
the field: leaving the association empty instead would be indistinguishable
from an owner that genuinely has none.

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
| `crud_repository.save.insert_not_readable` | An `INSERT` reported success but the new row could not be read back. |
| `crud_repository.save.update_not_readable` | An `UPDATE` ran but the row could not be re-read. |
| `crud_repository.delete.unsaved_entity` | `delete(entity)` was handed an entity that was never persisted. |

The first seven are *server* faults — a broken deployment, a table contradicting
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
negative bound, or an offset with no limit (MariaDB's grammar is
`LIMIT n [OFFSET m]`, so there is no bare `OFFSET` and the skip would be
silently dropped).

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
  them; a field with no direction of its own sorts ascending.
- **`count` takes neither a cap nor an ordering.** Its statement returns a
  single row, so `top`/`first` would cap what is *returned* rather than what is
  counted, and an `order by` would have one row to order. Both are rejected
  rather than accepted and ignored, so `count first 5 by …` fails instead of
  quietly counting the whole filtered set. Use `group` to cap or order
  aggregates.

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
so an empty list is refused at compile time rather than handed to the database.
A list that is never closed (`by id is in ( 1 , 2`) is a syntax error like any
other. A boolean column is refused outright: `IN` over the two values a boolean
can take is a predicate written the long way round.

### Column types a predicate can address

A predicate addresses a column through three separate type dispatches — the
column node, the bind parameter, and the comparison that joins them — and all
three cover the same seven families: `String`, `int`, `double`, `bool`,
`DateTime`, `TomZonedDate` and `TomZonedTime`, each with its `Tom…` and nullable
`TomN…` spellings, plus the `TomDb…` names when an entity gives `columnType:`
explicitly. A column outside them raises
`query_sentence_compiler.create_column.failed`.

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
negating one raises `…_literal_negation_attempt`.

`true` and `false` are therefore **reserved in operand position**: a field whose
sentence name is one of them is read as the literal and never resolves as a
column. Reaching that clash takes deliberate effort — a sentence names a field
by its `@TomDbColumn(name: ...)` when it has one and by its Dart declaration
otherwise, and Dart will not let a field be *declared* `true` or `false` — so the
only way in is to write that name explicitly, and the way out is to write a
different one.

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
built-ins.

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
  predicate; if the row is not found it is refused. Modelling the check as a
  scoped visibility read (rather than an atomic `UPDATE … AND <scope>` plus a
  zero-rows-affected test) sidesteps the MariaDB quirk that an `UPDATE` changing
  no value reports zero affected rows, which would otherwise reject a legitimate
  in-scope no-op write. A missing row and an out-of-scope row are reported
  identically, so existence is not leaked across the scope boundary.
- **bulk delete** — `_assertIdsWritable` requires the scoped existence check to
  see *all* the named ids.
- **insert** — `_assertInsertWritable` checks the new row's scope-field value
  against the allowed set, which is what stops a principal creating a row scoped
  to a value it could not itself read. A scope **on the primary key** is a no-op
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

A column opts in by naming a resource key:

```dart
@TomDbColumn(columnName: 'salary', authKey: 'employee.salary')
int? salary;
```

The key is resolved to a kernel `TomAuthState`, the four-state grade
`none < disabled < read < full`. A column with **no** `authKey` is unrestricted:
`TomColumnAuthorization.stateForKey(null)` is `full`, so an entity that grades
nothing pays nothing. The resolver is the process-wide `TomAuthorization`
singleton unless one is passed explicitly — which is what a test does, and it is
worth knowing that the singleton answers `full` for everything in development
mode.

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
Stream<List<int>> openFile(K id, String fieldName);
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
back under. It is validated at construction against `^[A-Za-z_][A-Za-z0-9_]*$`:
an alias is written into the statement text rather than bound, so it is the one
injection surface a grouped query adds, and it is closed where it opens.

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
ungrouped column has no meaning, and the constructor rejects it rather than
letting the database pick a behaviour.

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
  `TomQuerySyntaxException`. Returning `null` would be indistinguishable from
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
  `TomColumnAuthorizationException` before it reaches the database.

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
that the repository uses to read and write entity fields. A type that is not
registered with `tomReflector`, or lacks a `@TomDbTable`, raises
`TomAnnotationAnalyzerException`.

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

Two suites carry the module's name, split by whether a server is needed.

`test/object_persistence_test.dart` always runs, and reaches most of the module:
the operator tree's literals, comparisons, parameters, typed column references
and compound predicates, `BETWEEN` arity, the persistence annotations and
`TomColumnInformation`, the save SQL builders,
`TomAnnotationAnalyzer.getPersistentColumns`, the C-7 injection neutralisation,
the dialect's `objectOp` dispatch, the fact that `TomPersistenceEventHandler` is
resolved and then never invoked — pinned against the source, because two
documents say so in prose — and that a repository is constructed rather than
discovered.

`test/object_persistence_db_test.dart` is tagged `db` and skips when no server
is reachable, so the default run stays green without one. It covers CRUD through
a repository against a real MariaDB, which is the half that cannot be settled by
reading generated SQL.

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
surface in sixteen steps rather than describing it — mapping an entity,
compiling the four sentence kinds, grouping and aggregation, paging, column
authorization, and the `TomQueryBuilder` DSL every sentence compiles down to,
each with its refusals. The refusals are most of what the module has to say: a
query it accepts is one you would have written anyway, so what is worth showing
is where it stops you. Its entities live in
`example/object_persistence/object_persistence_entities.dart`. Every step checks
its own result, and `test/examples_test.dart` runs it.

## Core Components

- **Annotations** — `TomDbTable`, `TomDbColumn`, `TomEntityId`, `TomReference`,
  `TomJoinTable`, `TomPersistenceEventHandler`, plus `TomDartType`.
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

The first two are *declared*, so they can look available from the outside — an
annotation you can write and the analyzer accepts. The third is simply absent
from the grammar, and a sentence using it is refused.

- `@TomJoinTable` is declared but never read — neither detected nor acted on.
- `@TomPersistenceEventHandler` is *detected* (`TomAnnotationAnalyzer` resolves
  it onto `TomColumnInformation.eventHandler`) but never invoked, so declaring
  one currently has no effect. Detection is field-level — the analyzer reads a
  field's metadata — so although the callbacks take the whole entity, one placed
  on a class declaration is not seen at all.
- Additional query-sentence keywords (`After`, `Before`, `Containing`,
  `EndsWith`, `StartsWith`, `Exists`, `isEmpty`/`isNotEmpty`, `Within`, …). The
  sentence grammar covers comparison, `LIKE` / `NOT LIKE`, `REGEXP`,
  `IS IN` / `IS NOT IN`, `IS NULL` / `IS NOT NULL`, `AND` / `OR` / `NOT` and
  parenthesised groups.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `data_scope.dart` | `Future` |
| `tom_core_kernel` | package | 7 of 12 files | `tomReflector` (mirrors), the `TomZoned*` date/time types |
| `uuid` | package | `file_reference.dart` | `Uuid.v4`, for the file name in a blob key |
| [audit](audit.md) | module | `crud_repository.dart` | `TomAuditAction`, `TomAuditTrail` |
| [datasources](datasources.md) | module | 9 of 12 files | `TomDbType`/`TomOperator`/`SqlString`, `TomStandardSqlDialect` / `MariadbSqlDialect` (including the `aggregate`, `aliased`, `groupByClause` and `havingClause` fragments), `TomQuery` family (`TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect`), `TomAggregateFunction`, `TomTypedPersistenceBase`, `TomTypePersistenceInfo`, `TomDataSourceInfo`, `TomPreparedStatement` |
| [file_storage](file_storage.md) | module | `crud_repository.dart`, `file_reference.dart` | `TomBlobStore`, `TomBlobStoreInfo`, `TomStorageException`, `TomStoredBlob` |
| [little_things](little_things.md) | module | `annotation_analyzer.dart`, `column_authorization.dart`, `crud_repository.dart`, `data_scope.dart`, `operators_expressions.dart` | `TomServerException` (base of the module's exceptions) |
