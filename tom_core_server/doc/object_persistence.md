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
- [Query Sentences](#query-sentences)
  - [Column types a predicate can address](#column-types-a-predicate-can-address)
  - [Writing a value inline](#writing-a-value-inline)
- [The Query Builder DSL](#the-query-builder-dsl)
- [Row Scopes](#row-scopes)
- [Grouping and Aggregation](#grouping-and-aggregation)
- [How Metadata Is Resolved](#how-metadata-is-resolved)
- [SQL Dialects](#sql-dialects)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` | annotations | Map an entity class and its fields to a table and columns |
| `TomRepository<T, K>` | abstract class | The CRUD + query contract for entity `T` keyed by `K` |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL implementation of the contract |
| `MariadbRepository<T, K>` | class | MariaDB driver binding (`@TomRepositoryType("mariadb")`) |
| `TomQuerySentenceCompiler` | class | Parses a query sentence into a `TomQuery` |
| `TomQueryBuilder` | mixin | Fluent factory for the `TomOperator` expression tree |
| `TomAggregate` | abstract class | An aggregate function node (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`) |
| `TomGroupedSelect` | class | A `SELECT … GROUP BY … HAVING` compiled from group keys and aggregates |
| `TomGroupedRow` | class | One group's result: the group keys plus the aggregate values, keyed by alias |
| `TomAnnotationAnalyzer` | mixin | Resolves an entity's persistence metadata by reflection |
| `TomColumnInformation` | class | The resolved metadata for one entity field |
| `TomDbScope` | annotation | Declares (or explicitly opts out of) an entity's row scope |
| `TomDataScopeRegistry` | class (statics) | The named scope-kind resolvers, read and write |
| `TomDataScope` | class (statics) | Renders a resolver's answer into a bound `IN` / union predicate |

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
from a mirror that carries no type arguments.

## The Repository Contract

`TomRepository<T, K>` mirrors Spring Data's `CrudRepository`:

```dart
final repo = MariadbRepository<User, int>([User]);

await repo.save(user);                 // INSERT (null key) or UPDATE (key set)
final u   = await repo.findById(42);   // by primary key
final all = await repo.findAll();
final n   = await repo.count();
await repo.deleteById(42);
```

Beyond id-based CRUD it exposes three query styles, each in find / delete / count
flavours: a parsed query sentence (`findByQuerySentence`), a built `TomQuery`
(`findByQuery`), and raw SQL (`executeQueryString`). A fourth entry point,
`findGroupedByQuery`, runs a grouped query — its result is not `T`, so it does
not fit the find/delete/count pattern (see
[Grouping and Aggregation](#grouping-and-aggregation)).

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

A malformed sentence raises `TomQuerySyntaxException`.

### Column types a predicate can address

A predicate addresses a column through three separate type dispatches — the
column node, the bind parameter, and the comparison that joins them — and all
three cover the same six families: `String`, `int`, `double`, `bool`,
`DateTime` and `TomZonedDate`, each with its `Tom…` and nullable `TomN…`
spellings, plus the `TomDb…` names when an entity gives `columnType:`
explicitly. A column outside them raises
`query_sentence_compiler.create_column.failed`.

### Writing a value inline

A value in a predicate is normally *bound* (`find by amount > :floor`), but it
can also be written out. Six literal forms are recognised, by shape:

| Form | Example | SQL type |
| ---- | ------- | -------- |
| Text | `find by title = 'draft'` | `String` |
| Boolean | `find by done = TRUE` | `bool` |
| Integer | `find by priority > 3`, `find by delta > -5` | `int` |
| Decimal | `find by amount > 1.5`, `find by amount > -0.25` | `double` |
| Date | `find by tag_day = 2026-07-05` | `TomZonedDate` |
| Timestamp | `find by created_at >= 2026-07-05T10:00:00Z` | `DateTime` |

A literal stands for exactly one type, so comparing one against a column of
another raises `…build_expression.<kind>_literal_invalid_type_expected`, and
negating one raises `…_literal_negation_attempt`.

Two shapes worth knowing. A **decimal is written with a point**, never a comma:
a comma separates an `IS IN` list, so a value spelled `1,5` is read as two
values rather than one. And a **timestamp is converted to UTC** as it compiles,
whether written with `Z` or with an offset — `2026-07-05T12:00:00+02:00` and
`2026-07-05T10:00:00Z` produce the same literal.

Binding is still the better habit: a bound value is typed by the parameter
rather than by its spelling, and it leaves the sentence reusable.

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
- **Column rights (C-4)** cause the query to be **refused outright** rather than
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
`TomColumnInformation` (one per annotated field). Results are memoised per type
in `mirrorCache` / `tableCache` / `columnInfoCache`. A `TomColumnInformation`
also provides reflection-backed `getVariableValue` / `setVariableValue`
accessors that the repository uses to read and write entity fields. A type that
is not registered with `tomReflector`, or lacks a `@TomDbTable`, raises
`TomAnnotationAnalyzerException`.

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
`MariadbRepository` uses `MariadbSqlDialect`. Repository discovery uses the
`@TomRepositoryType("...")` annotation to select the right repository for a data
source's type.

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

## Not Yet Implemented

Tracked in the quest completion steps:

- `@TomJoinTable` is declared but never read — neither detected nor acted on.
- `@TomPersistenceEventHandler` is *detected* (`TomAnnotationAnalyzer` resolves
  it onto `TomColumnInformation.eventHandler`) but never invoked, so declaring
  one currently has no effect.
- Additional query-sentence keywords (`After`, `Before`, `Containing`,
  `EndsWith`, `StartsWith`, `Exists`, `isEmpty`/`isNotEmpty`, `Within`, …). The
  sentence grammar covers comparison, `LIKE` / `NOT LIKE`, `REGEXP`,
  `IS IN` / `IS NOT IN`, `IS NULL` / `IS NOT NULL`, `AND` / `OR` / `NOT` and
  parenthesised groups.

## Dependencies

- `tom_core_kernel` — `tomReflector` (mirrors), the `TomZoned*` date/time types.
- The datasources module — `TomDbType`/`TomOperator`/`SqlString`,
  `TomStandardSqlDialect` / `MariadbSqlDialect` (including the `aggregate`,
  `aliased`, `groupByClause` and `havingClause` fragments), `TomQuery` family
  (`TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect`),
  `TomAggregateFunction`, `TomTypedPersistenceBase`, `TomTypePersistenceInfo`,
  `TomDataSourceInfo`, `TomPreparedStatement`.
- The little-things module — `TomServerException` (base of the module's
  exceptions).
