import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../datasources/queries.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/sql_placeholder_scan.dart';
import '../datasources/types_operator.dart';
import '../file_storage/blob_store.dart';
import '../little_things/server_exception.dart';

import 'grouped_query.dart';
import 'file_reference.dart';
import 'operators_expressions.dart';
import 'paging.dart';
import 'persistence_annotations.dart';
import 'query_sentence_compiler.dart';
import 'query_builder.dart';
import 'annotation_analyzer.dart';
import 'column_authorization.dart';
import 'composite_key.dart';
import 'data_scope.dart';

/// Raised when a repository operation cannot complete: the entity's data source
/// was never registered, a primary-key lookup matched more than one row, a
/// `COUNT(*)` returned other than one row, a row written by
/// [TomRepository.save] could not be read back, [TomRepository.delete] was
/// handed an entity that was never persisted, a key did not match the entity's
/// key fields, or a composite key was saved with a field unset.
///
/// The first three are *server* faults — a broken registration or a database
/// that contradicts its own schema — so [TomServerException.clientThrow]
/// defaults to `false` and the message is kept off the wire; the `key` is what a
/// caller matches on and what the endpoints pipeline logs.
///
/// The other three (`delete.unsaved_entity`, `key.shape_mismatch`,
/// `save.incomplete_key`) set `clientThrow` explicitly. Each is raised for
/// something the caller did rather than something the deployment did, and its
/// message describes only the argument it was handed — so masking it would tell
/// a caller nothing about a mistake it is the only party able to fix.
///
/// It sits beside the repository rather than in the module's other exception
/// files because those describe *inputs* the repository rejects
/// ([TomQuerySyntaxException], [TomColumnAuthorizationException],
/// [TomDataScopeException]); this one describes the repository's own
/// preconditions failing — including, in the delete case, the precondition that
/// there is a persisted row to address at all.
class TomRepositoryException extends TomServerException {
  /// Creates a repository failure with a `crud_repository.<method>.<condition>`
  /// [key] and a default user message.
  ///
  /// [clientThrow] defaults to `false` — override it only where the message is
  /// known to be safe for the caller.
  TomRepositoryException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow = false,
  });
}

/// Result holder for a `COUNT(*)` query: a single [count] field populated by
/// the row mapper. Reflectable so the data source can materialise it.
///
/// It is a plain reflected holder (no `@TomDbTable`), so the row mapper fills it
/// by *field name*: the `COUNT(*) AS count` projection names its column `count`,
/// which matches this field. That name is the entire binding, and it is checked
/// nowhere — rename [count], or project the count under a different alias, and
/// the mapper finds no column for the field, leaves it at its default `0`, and
/// every count reports an empty table instead of failing.
@tomReflector
class TomCountResult {
  /// The row count returned by the query, mapped from the `count` result column.
  int count = 0;
}

/// The persistence contract for an entity [T] keyed by [K].
///
/// Modelled on Spring Data's `CrudRepository`: it offers id-based CRUD
/// ([save], [findById], [delete], …) plus three query styles — a parsed
/// Spring-style *query sentence* (`findByQuerySentence` and friends), a built
/// `TomQuery` object ([findByQuery] / [deleteByQuery] / [countByQuery]), and a
/// raw SQL string ([executeQueryString]).
///
/// **Paging and sorting.** Every read that can return more than one row takes an
/// optional [TomPageRequest]: an offset, a row limit, and an ordered list of
/// (field, direction) sort terms. The result is the window itself — a plain
/// `List<T>` — and the *total* comes from the matching `count` method, which
/// applies the same row scope, so page metadata never reports rows the
/// principal may not see. A caller that does not page passes nothing and gets
/// exactly the behaviour it had before.
abstract class TomRepository<T extends Object, K> {
  /// Deletes [entity] by its primary key.
  ///
  /// Alone among the delete methods this returns nothing: it addresses one row
  /// the caller already holds, so a count could only ever be `1` or `0`, and
  /// `0` — the row having gone since it was read — is not a distinction any
  /// caller has asked to act on.
  ///
  /// An [entity] that was never persisted has no row to address, and is refused
  /// with `crud_repository.delete.unsaved_entity` rather than deleting nothing
  /// and reporting success.
  Future<void> delete(T entity);

  /// Deletes every entity whose id is in [ids] and returns how many rows were
  /// deleted.
  ///
  /// The count can be lower than `ids.length`: an id may name no row, or a row
  /// outside the principal's data scope.
  Future<int> deleteAllById(Iterable<K> ids);

  /// Deletes the entity with the given [id] and returns how many rows were
  /// deleted — `1`, or `0` when no row matched.
  Future<int> deleteById(K id);

  /// Whether every id in [ids] exists.
  Future<bool> existsById(Iterable<K> ids);

  /// Loads all entities, or the window [page] asks for.
  Future<List<T>> findAll([TomPageRequest? page]);

  /// Loads every entity whose id is in [ids], or the window [page] asks for.
  Future<List<T>> findAllById(Iterable<K> ids, [TomPageRequest? page]);

  /// Loads the entity with the given [id], or `null` if absent.
  Future<T?> findById(K id);

  /// Counts all entities.
  Future<TomDbInt> count();

  /// Inserts [toSave] (no primary key) or updates it (primary key set), and
  /// returns the stored entity.
  Future<T> save(T toSave);

  /// Saves every entity in [entities] and returns the stored entities.
  Future<Iterable<T>> saveAll(Iterable<T> entities);

  /// Runs a parsed query sentence as a `SELECT`, binding [params]; an optional
  /// [resultType] overrides the row type and an optional [page] narrows the
  /// result to one window.
  ///
  /// A [page] that carries a sort replaces the sentence's own `order by`; one
  /// that carries only a window keeps it.
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
    TomPageRequest? page,
  ]);

  /// Runs a parsed query sentence as a `DELETE`, binding [params], and returns
  /// how many rows were deleted.
  ///
  /// The count is the deleted row count *after* the principal's data scope has
  /// been ANDed into the predicate, so it never reports rows the principal may
  /// not see.
  Future<int> deleteByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  );

  /// Runs a parsed query sentence as a `COUNT`, binding [params].
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  );

  /// Runs a built [TomSelect], binding [params], optionally narrowed to the
  /// window [page] asks for.
  Future<Iterable<T>> findByQuery(
    TomSelect query,
    Map<String, Object?> params, [
    TomPageRequest? page,
  ]);

  /// Runs a built [TomDelete], binding [params], and returns how many rows were
  /// deleted — scoped like [deleteByQuerySentence].
  Future<int> deleteByQuery(TomDelete query, Map<String, Object?> params);

  /// Runs a built [TomCount], binding [params].
  Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params);

  /// Runs a built [TomGroupedSelect], binding [params], and returns one
  /// [TomGroupedRow] per group.
  ///
  /// The result is deliberately not [T]: a grouped row holds the group keys and
  /// the aggregate values the query asked for, a shape the entity class does
  /// not have.
  Future<List<TomGroupedRow>> findGroupedByQuery(
    TomGroupedSelect query,
    Map<String, Object?> params,
  );

  /// Runs a raw SQL string [dbQuery], binding [params], and maps the rows to [T].
  Future<Iterable<T>> executeQueryString(
    String dbQuery,
    Map<String, Object?> params,
  );
}

/// The subset of a repository the file surfaces need: load a row, and move the
/// bytes of one of its `@TomFileReference` columns.
///
/// Split out of [TomRepository] rather than folded into it because it is what
/// the HTTP file endpoint depends on, and an endpoint that depended on the full
/// SQL repository could only ever be exercised against a database. Every method
/// here is already implemented by [TomSqlDatasourceRepository]; naming them as a
/// contract costs nothing and makes the endpoint's requirement explicit — five
/// methods, not a persistence stack.
abstract class TomFileRepository<T extends Object, K> {
  /// Loads the entity with the given [id], or `null` if absent (or not visible
  /// to the current principal under the entity's row scope).
  Future<T?> findById(K id);

  /// Uploads [bytes] into the file column [fieldName] of [entity] and saves the
  /// row, returning the stored entity.
  Future<T> saveFile(
    T entity,
    String fieldName,
    Stream<List<int>> bytes, {
    String? mediaType,
    String? fileName,
  });

  /// Streams the file held by the file column [fieldName] of row [id], or
  /// [range] of it.
  Stream<List<int>> openFile(K id, String fieldName, {TomBlobRange? range});

  /// The descriptor of the file held by [fieldName] on row [id], or `null` when
  /// the row (or its column) holds nothing.
  Future<TomStoredBlob?> describeFile(K id, String fieldName);

  /// Clears the file column [fieldName] on [entity], deleting the blob.
  Future<T> clearFile(T entity, String fieldName);
}

/// SQL-datasource implementation of [TomRepository].
///
/// On construction it resolves the entity's persistence metadata via
/// [TomAnnotationAnalyzer] (table, primary-key column, columns), looks up the
/// named [TomDataSourceInfo], and builds a [TomQuerySentenceCompiler] for the
/// query types. CRUD methods compile/cache prepared statements and render them
/// through the active [sqlDialect]; the [TomQueryBuilder] mixin supplies the
/// expression-tree factories. Concrete drivers (e.g. [MariadbRepository])
/// subclass this and override [sqlDialect].
abstract class TomSqlDatasourceRepository<T extends Object, K>
    extends TomRepository<T, K>
    with TomQueryBuilder
    implements TomFileRepository<T, K> {
  /// Resolved metadata for the primary-key columns, in the order
  /// `@TomDbTable.primaryKeyFields` lists their fields.
  late List<TomColumnInformation> primaryKeyColumns;

  /// Whether the primary key spans more than one field, in which case the
  /// repository's `K` is [TomCompositeKey].
  bool get hasCompositeKey => primaryKeyColumns.length > 1;

  /// The resolved data source this repository runs against.
  late TomDataSourceInfo datasourceInfo;

  /// The resolved persistence metadata of the entity.
  late TomTypePersistenceInfo persistenceInfo;

  /// The table the entity maps to.
  late TomDbTable dbTable;

  late TomQuerySentenceCompiler _qsc;

  /// The SQL dialect used to render queries; defaults to the data source's
  /// dialect and is overridden by concrete drivers.
  TomStandardSqlDialect get sqlDialect => datasourceInfo.datasource.sqlDialect;

  /// The entity types this repository can query (first is the primary entity).
  List<Type> queryTypes = [T];

  /// The default row type for results.
  Type resultType = T;

  /// Resolves the entity's persistence metadata and data source.
  ///
  /// [queryTypes] defaults to `[T]` and [resultType] to `T`. Throws if the
  /// data source named on the entity's `@TomDbTable` is not registered.
  TomSqlDatasourceRepository([List<Type>? queryTypes, Type? resultType]) {
    this.queryTypes = queryTypes ?? this.queryTypes;
    this.resultType = resultType ?? this.resultType;
    _qsc = TomQuerySentenceCompiler(this.queryTypes);
    // Assign the `persistenceInfo` field (not a shadowing local): the scope
    // resolver (`_resolveScope`) reads it long after construction, so a local
    // here would leave the `late` field uninitialised and only fail the first
    // time a scoped read runs (LateInitializationError).
    persistenceInfo = TomAnnotationAnalyzer.analysePersistentType(
      this.queryTypes[0],
    );
    dbTable = persistenceInfo.table;
    if (dbTable.primaryKeyFields.isEmpty) {
      throw TomRepositoryException(
        'crud_repository.constructor.no_primary_key',
        "@TomDbTable on ${this.queryTypes[0]} names no primary-key field; "
            "primaryKeyFields must list at least one.",
        parameters: {'entity': '${this.queryTypes[0]}'},
      );
    }
    primaryKeyColumns = [
      for (final field in dbTable.primaryKeyFields)
        TomAnnotationAnalyzer.determineColumn(field, [persistenceInfo]),
    ];
    for (final column in primaryKeyColumns) {
      if (column.entityId == null) {
        tomLog.warn(
          "Primary key field/column ${column.declaredName} is not marked as EntityId",
        );
      }
    }
    var dsInfo = TomDataSourceInfo.getDataSourceInfo(dbTable.datasource);
    if (dsInfo != null) {
      datasourceInfo = dsInfo;
    } else {
      throw TomRepositoryException(
        'crud_repository.constructor.datasource_not_registered',
        "No datasource information obtainable for datasource ${dbTable.datasource} which was specified for class ${this.queryTypes[0]}",
      );
    }
  }

  /// Resolves the row-scope predicate (C-3) for the current-zone principal, or
  /// `null` when the entity declares no `@TomDbScope` or its resolver opts out.
  ///
  /// The predicate is bound (`<field> IN (:__tomscope_0, …)`), so a principal's
  /// allowed values ride the prepared-statement protocol as positional
  /// parameters — never concatenated into the SQL (C-7). Because the number of
  /// allowed values (and thus placeholders) varies per principal, a scoped read
  /// path prepares a fresh statement rather than reusing a cached one.
  ///
  /// A scope kind registered asynchronously resolves through
  /// [TomDataScope.buildAsync] — the union/OR path that folds ownership and
  /// share-mode delegations (resolved from another database) into the visible
  /// id-set; every other kind takes the synchronous single-`IN` path. The
  /// method is async so the union path can await its cross-database resolution;
  /// the sync path completes synchronously via the returned already-completed
  /// future.
  ///
  /// [forWrite] selects the (possibly narrower) set the principal may *modify*
  /// rather than the set it may see — the difference the grant-driven
  /// `resource` scope draws between a `read` grant and a `full` one. A
  /// scope kind that registers no write resolver writes exactly what it reads,
  /// so every other kind is unaffected.
  Future<TomDataScopePredicate?> _resolveScope({bool forWrite = false}) async {
    // Inside an async resolver's own enumeration, scope resolution is
    // suppressed so the reads that *compute* the visible id-set are not
    // themselves re-scoped — the guard against unbounded resolver recursion.
    if (TomDataScope.isBypassed) return null;
    final scope = TomAnnotationAnalyzer.findDataScope(queryTypes[0]);
    if (scope == null) return null;
    final col = TomAnnotationAnalyzer.determineColumn(scope.field, [
      persistenceInfo,
    ]);
    final principal = getFromCurrentZone<TomPrincipal>();
    if (TomDataScopeRegistry.isAsync(scope.scope)) {
      return TomDataScope.buildAsync(
        this,
        scope,
        col,
        principal,
        forWrite: forWrite,
      );
    }
    return TomDataScope.build(this, scope, col, principal, forWrite: forWrite);
  }

  /// Asserts the current principal may write the row keyed by [id] under the
  /// entity's `@TomDbScope` (C-3 write enforcement). A no-op when the entity
  /// declares no scope; otherwise a scoped read must find the row — an
  /// out-of-scope (or absent) row raises [TomDataScopeAuthorizationException].
  ///
  /// The guard reuses the *exact* scoped read predicate the read paths apply
  /// (via [_selectById]), so a principal cannot update or delete a row it could
  /// not itself read, and the scope values ride the prepared-statement protocol
  /// as bound parameters (C-7). Modelling it as a scoped visibility read — not
  /// an atomic `… WHERE id = ? AND <scope>` with a zero-rows-affected test —
  /// deliberately sidesteps the MariaDB quirk that an `UPDATE` which changes no
  /// value reports zero affected rows, which would otherwise reject a legitimate
  /// in-scope no-op write. A missing row and an out-of-scope row are reported
  /// identically, so existence is not leaked across the scope boundary.
  ///
  /// The read it performs is resolved `forWrite`, so a scope kind that grades
  /// its values measures the row against the *writable* set: a row the
  /// principal may only read is reported here exactly as an invisible one is —
  /// as not writable.
  Future<void> _assertRowWritable(K id) async {
    if (TomAnnotationAnalyzer.findDataScope(queryTypes[0]) == null) return;
    if (await _selectById(id, forWrite: true) == null) {
      throw TomDataScopeAuthorizationException(
        'data_scope.write.out_of_scope',
        'The requested row is not within your data scope.',
      );
    }
  }

  /// Asserts every id in [ids] is writable under the entity's `@TomDbScope`
  /// before a bulk delete. A no-op when the entity declares no scope; otherwise
  /// a scoped existence check must see *all* of them — if any is out of scope
  /// (or absent) it raises [TomDataScopeAuthorizationException]. Reuses the
  /// scoped [existsById] so the same bound-parameter predicate governs the
  /// check and the reads — resolved against the *writable* set.
  Future<void> _assertIdsWritable(Iterable<K> ids) async {
    if (TomAnnotationAnalyzer.findDataScope(queryTypes[0]) == null) return;
    if (!await _existsById(ids, forWrite: true)) {
      throw TomDataScopeAuthorizationException(
        'data_scope.write.out_of_scope',
        'One or more of the requested rows is not within your data scope.',
      );
    }
  }

  /// Asserts the current principal may create [entity] under the entity's
  /// `@TomDbScope`: its scope-field value must be one the principal is allowed
  /// (C-3 write enforcement for inserts). A no-op when the entity declares no
  /// scope or its resolver opts out; an out-of-scope value raises
  /// [TomDataScopeAuthorizationException]. Without this a principal could create
  /// a row scoped to a value it cannot itself read (e.g. owned by someone else),
  /// silently bypassing the read scope.
  ///
  /// A scope **on the primary key** is a no-op here: a fresh insert has no id
  /// yet, so there is no scope-field value to check — insert authorization for
  /// such entities is enforced at the service layer (the caller must hold a
  /// create grant on the parent). Applying the read scope to a null/unassigned
  /// id would reject every legitimate insert. Note this is a property of the
  /// *column*, not of the resolver being async: a grant-driven scope on a
  /// `resource_key` column carries its value on the incoming entity and
  /// is checked here like any other, which is what stops a principal from
  /// creating a row under a resource key it holds no `full` grant on.
  ///
  /// The check resolves the **writable** value set, so a `read`-graded value is
  /// rejected for an insert exactly as an ungranted one is.
  Future<void> _assertInsertWritable(T entity) async {
    // Suppressed inside a resolver's own enumeration, exactly as the other two
    // write guards are (they resolve through the bypass-aware `_resolveScope`).
    if (TomDataScope.isBypassed) return;
    final scope = TomAnnotationAnalyzer.findDataScope(queryTypes[0]);
    if (scope == null) return;
    final col = TomAnnotationAnalyzer.determineColumn(scope.field, [
      persistenceInfo,
    ]);
    // Only a single generated key is unknown before the insert; every field of
    // a composite key is supplied by the caller and is checked like any other.
    if (!hasCompositeKey &&
        col.getQueryFieldName() ==
            primaryKeyColumns.single.getQueryFieldName()) {
      return;
    }
    final principal = getFromCurrentZone<TomPrincipal>();
    final allowed = TomDataScopeRegistry.isAsync(scope.scope)
        ? await TomDataScope.allowedValuesAsync(
            scope,
            principal,
            forWrite: true,
          )
        : TomDataScope.allowedValues(scope, principal, forWrite: true);
    if (!TomDataScope.permits(allowed, col.getVariableValue(entity))) {
      throw TomDataScopeAuthorizationException(
        'data_scope.write.insert_out_of_scope',
        'You may not create a row outside your data scope.',
      );
    }
  }

  /// Returns [base] with [scope]'s predicate ANDed into its `WHERE` (preserving
  /// every shaping option), or [base] unchanged when [scope] is `null`.
  TomDelete _scopedDelete(TomDelete base, TomDataScopePredicate? scope) {
    if (scope == null) return base;
    return TomDelete(
      base.types,
      query: and([base.query, scope.predicate]),
      distinct: base.distinct,
      sort: base.sort,
      top: base.top,
      ignoreFields: base.ignoreFields,
    );
  }

  /// Returns [base] with [scope]'s predicate ANDed into its `WHERE` (preserving
  /// every shaping option), or [base] unchanged when [scope] is `null`.
  TomSelect _scopedSelect(TomSelect base, TomDataScopePredicate? scope) {
    if (scope == null) return base;
    return TomSelect(
      base.types,
      query: and([base.query, scope.predicate]),
      distinct: base.distinct,
      sort: base.sort,
      top: base.top,
      offset: base.offset,
      ignoreFields: base.ignoreFields,
    );
  }

  /// Returns [base] with [scope]'s predicate ANDed into its `WHERE` (preserving
  /// the grouping, aggregates and `HAVING`), or [base] unchanged when [scope]
  /// is `null`.
  ///
  /// The scope goes into the *row* predicate, never into `HAVING`: it decides
  /// which rows the principal may see, and so must apply before aggregation —
  /// filtering groups afterwards would still have counted the hidden rows.
  TomGroupedSelect _scopedGrouped(
    TomGroupedSelect base,
    TomDataScopePredicate? scope,
  ) {
    if (scope == null) return base;
    return TomGroupedSelect(
      base.types,
      query: and([base.query, scope.predicate]),
      groupBy: base.groupBy,
      aggregates: base.aggregates,
      having: base.having,
      sort: base.sort,
      top: base.top,
      offset: base.offset,
    );
  }

  /// Returns [base] with [scope]'s predicate ANDed into its `WHERE` (preserving
  /// every shaping option), or [base] unchanged when [scope] is `null`.
  ///
  /// A count's shaping options are the projection ones only — it has no window
  /// and no ordering to carry over (see [TomCount]).
  TomCount _scopedCount(TomCount base, TomDataScopePredicate? scope) {
    if (scope == null) return base;
    return TomCount(
      base.types,
      query: and([base.query, scope.predicate]),
      distinct: base.distinct,
      ignoreFields: base.ignoreFields,
    );
  }

  // ───────────────────────── Paging and sorting ──────────────────────────

  /// Normalises [page] into the window actually applied, or `null` when it asks
  /// for nothing.
  ///
  /// A request that cuts a window is made stable under the entity's primary
  /// key, every field of it — see [TomPageRequest.stableUnder].
  TomPageRequest? _effectivePage(TomPageRequest? page) {
    if (page == null || page.isUnpaged) return null;
    return page.stableUnder(dbTable.primaryKeyFields);
  }

  /// Returns [base] narrowed to [page]'s window and ordering, or [base]
  /// unchanged when [page] is `null`.
  ///
  /// A page without a sort keeps the query's own ordering (a query sentence's
  /// `order by`, say); a page with one replaces it, because the caller asking
  /// for page N is the one that knows what N is counted in.
  TomSelect _pagedSelect(TomSelect base, TomPageRequest? page) {
    if (page == null) return base;
    return TomSelect(
      base.types,
      query: base.query,
      distinct: base.distinct,
      sort: page.sort.isEmpty ? base.sort : page.sort,
      top: page.limit > 0 ? page.limit : base.top,
      offset: page.offset,
      ignoreFields: base.ignoreFields,
    );
  }

  /// The entity's column-level access-controlled columns (C-4), or empty when it
  /// declares none — in which case every C-4 read/write path is a no-op.
  List<TomColumnInformation> get _authColumns =>
      TomAnnotationAnalyzer.findAuthColumns(queryTypes[0]);

  /// Masks every row of [rows] in place — nulling the columns the current
  /// principal may not see (C-4) — and returns the list. A no-op when the entity
  /// declares no column access rights.
  List<T> _maskRows(List<T> rows) {
    final authColumns = _authColumns;
    if (authColumns.isEmpty) return rows;
    for (final row in rows) {
      TomColumnAuthorization.applyReadMask(row, authColumns);
    }
    return rows;
  }

  // ─────────────────────── File-reference columns ────────────────────────
  //
  // A `@TomFileReference` column holds a *storage key*; the bytes live in a
  // blob store (`TomBlobStoreInfo`). The row therefore stays small enough to
  // select, diff, audit and mask like any other, while the payload — which may
  // be gigabytes — never passes through SQL.
  //
  // The authorization story is deliberately unremarkable: the key is an
  // ordinary column, so the entity's `@TomDbScope` (C-3) and the column's
  // `authKey` (C-4) already govern who can read or change it. The methods below
  // therefore reach the bytes *through* the existing read paths rather than
  // beside them — `openFile` takes an **id** and loads the row with `findById`,
  // so a principal who cannot see the row cannot see its file, by construction
  // and not by a second copy of the rule. What is added on top is only what the
  // masked case needs: a masked key reads back as `null`, which is
  // indistinguishable from "no file attached", so the grade is checked
  // explicitly and the refusal is named.

  /// The entity's file-reference columns, or empty when it stores no files — in
  /// which case every path below short-circuits and the feature costs nothing.
  List<TomColumnInformation> get _fileColumns =>
      TomAnnotationAnalyzer.findFileColumns(queryTypes[0]);

  /// Resolves the `@TomFileReference` column named [fieldName] (by declared
  /// name or column name), throwing when the entity has no such file column.
  TomColumnInformation _fileColumn(String fieldName) {
    for (final column in _fileColumns) {
      if (column.declaredName == fieldName ||
          column.getQueryFieldName() == fieldName) {
        return column;
      }
    }
    throw TomStorageException(
      'storage.file_reference.unknown_column',
      'That field is not a stored-file column of this entity.',
      parameters: {'entity': T.toString(), 'field': fieldName},
    );
  }

  /// The grade the current principal holds on [column] (C-4);
  /// [TomAuthState.full] for an unrestricted column.
  TomAuthState _columnGrade(TomColumnInformation column) =>
      TomColumnAuthorization.stateForKey(column.authKey);

  /// The grade the current principal holds on [column] **for the row keyed by
  /// [rowId]** — a registered per-row resolver when the column has one
  /// ([TomRowColumnAuthorization]), otherwise the column-wide [_columnGrade].
  ///
  /// Only the file operations resolve a grade this way. Each addresses exactly
  /// one row and is already asynchronous, so a relational grade — "may edit the
  /// attachments of items in a project you own, may only read the ones in a
  /// project shared with you" — costs one extra await where the synchronous
  /// row-projection paths could not express it at all.
  Future<TomAuthState> _rowColumnGrade(
    TomColumnInformation column,
    Object? rowId,
  ) async =>
      await TomRowColumnAuthorization.resolve(column.authKey, rowId) ??
      _columnGrade(column);

  /// Raises when the principal may not **write** [column] on the row keyed by
  /// [rowId] — its per-row grade lacks [TomAuthState.isInteractive].
  ///
  /// The three write-side file operations share this because they share the
  /// question: uploading a file, replacing one and clearing one are all writes
  /// of the same column, and a grade that refuses one must refuse all three.
  Future<void> _assertColumnWritable(
    TomColumnInformation column,
    Object? rowId,
  ) async {
    final grade = await _rowColumnGrade(column, rowId);
    if (grade.isInteractive) return;
    throw TomColumnAuthorizationException(
      'column_authorization.write.field_forbidden',
      'Column "${column.declaredName}" (resource "${column.authKey}") '
          'is not writable at your access level (${grade.name}).',
    );
  }

  /// Raises when the principal may not **read** [column] on the row keyed by
  /// [rowId] — its per-row grade lacks [TomAuthState.showsContent].
  Future<void> _assertColumnReadable(
    TomColumnInformation column,
    Object? rowId,
  ) async {
    final grade = await _rowColumnGrade(column, rowId);
    if (grade.showsContent) return;
    throw TomColumnAuthorizationException(
      'column_authorization.read.field_forbidden',
      'Column "${column.declaredName}" (resource "${column.authKey}") '
          'is not readable at your access level (${grade.name}).',
    );
  }

  /// The blob store [column]'s `@TomFileReference` names.
  TomBlobStore _fileStore(TomColumnInformation column) =>
      TomFileReferenceKeys.storeFor(column.fileReference!);

  /// Uploads [bytes] to the store behind the file-reference column [fieldName],
  /// writes the resulting key into [entity], and saves the row.
  ///
  /// Returns the stored entity, exactly as [save] does. When the column already
  /// held a key, the superseded blob is deleted by [save] itself, so replacing
  /// a file leaves nothing behind.
  ///
  /// The order — upload, then save — is the one whose failure mode is
  /// survivable. Saving first would leave a row pointing at a key that reads
  /// back `not_found`: a *dangling reference*, visible to users and repairable
  /// only by hand. Uploading first can at worst leave an orphaned blob, which
  /// nothing references and a sweep can collect; and even that is cleaned up
  /// here when the save throws.
  Future<T> saveFile(
    T entity,
    String fieldName,
    Stream<List<int>> bytes, {
    String? mediaType,
    String? fileName,
  }) async {
    final column = _fileColumn(fieldName);
    final reference = column.fileReference!;

    // C-4 and C-3 up front. `save` enforces both authoritatively at the end,
    // and that check remains the binding one; doing it here as well turns a
    // refusal that would have arrived *after* the transfer into an immediate
    // one, so a principal who may not write the column never uploads at all.
    //
    // The primary key is read before the grade rather than after, because a
    // per-row grade needs to know which row is being written; on an insert
    // there is no row yet and the resolver is handed the unsaved key.
    final primaryKey = readPrimaryKey<K>(keyOf(entity));
    await _assertColumnWritable(column, primaryKey);
    if (isUnsavedKey(primaryKey)) {
      await _assertInsertWritable(entity);
    } else {
      await _assertRowWritable(primaryKey as K);
    }

    final store = TomFileReferenceKeys.storeFor(reference);
    final key = TomFileReferenceKeys.generate(reference, fileName: fileName);
    await store.put(
      key: key,
      bytes: bytes,
      mediaType: mediaType ?? reference.mediaType,
      fileName: fileName,
    );

    column.setVariableValue(entity, key);
    try {
      return await save(entity);
    } on Object {
      // The row never took the key, so nothing references these bytes.
      await _discardBlob(store, key);
      rethrow;
    }
  }

  /// Streams the file held by the file-reference column [fieldName] of the row
  /// with primary key [id], or [range] of it.
  ///
  /// [range] is passed to the store, which serves it natively where the backend
  /// can seek. Both authorization gates run first and unchanged: a range is a
  /// narrower read of the same bytes, never a way to reach bytes a whole read
  /// would refuse.
  ///
  /// Reads the row through [findById], so the entity's row scope (C-3) applies
  /// unchanged: a row the principal may not see is simply not found. A column
  /// the principal may not *read* (C-4) raises
  /// [TomColumnAuthorizationException] rather than reporting an absent file,
  /// and a row whose column holds no key raises `storage.file_reference
  /// .no_file` — the caller asked for a file that is not there, which is a
  /// different answer from an empty one.
  Stream<List<int>> openFile(
    K id,
    String fieldName, {
    TomBlobRange? range,
  }) async* {
    final column = _fileColumn(fieldName);
    final row = await findById(id);
    if (row == null) {
      throw TomStorageException(
        'storage.file_reference.row_not_found',
        'No such record exists, or it is not visible to you.',
        parameters: {'entity': T.toString(), 'id': '$id'},
      );
    }
    await _assertColumnReadable(column, id);
    final key = column.getVariableValue(row);
    if (key is! String || key.isEmpty) {
      throw TomStorageException(
        'storage.file_reference.no_file',
        'That record has no file attached.',
        parameters: {'entity': T.toString(), 'field': fieldName, 'id': '$id'},
      );
    }
    yield* _fileStore(column).get(key, range: range);
  }

  /// The descriptor of the file held by [fieldName] on row [id] — its media
  /// type, size and original name — or `null` when the row holds no key.
  ///
  /// The metadata read that precedes a download: a caller needs the
  /// `Content-Type` and `Content-Length` before it starts streaming. Gated
  /// identically to [openFile].
  Future<TomStoredBlob?> describeFile(K id, String fieldName) async {
    final column = _fileColumn(fieldName);
    final row = await findById(id);
    if (row == null) return null;
    await _assertColumnReadable(column, id);
    final key = column.getVariableValue(row);
    if (key is! String || key.isEmpty) return null;
    return _fileStore(column).describe(key);
  }

  /// Clears the file-reference column [fieldName] on [entity] and saves the row,
  /// deleting the blob it referenced.
  ///
  /// Expressed as a save of a nulled column rather than as its own delete path,
  /// so the orphan collection, the audit record and both authorization gates are
  /// the ones every other write goes through.
  ///
  /// The per-row C-4 grade is checked here for the same reason [saveFile] checks
  /// it: [save] resolves the column *column-wide*, which is not the answer for a
  /// column with a [TomRowColumnAuthorization] resolver. Without this a
  /// principal graded `read` — allowed to download the file and nothing else —
  /// could delete it, which is the most destructive of the three writes.
  Future<T> clearFile(T entity, String fieldName) async {
    final column = _fileColumn(fieldName);
    await _assertColumnWritable(column, readPrimaryKey<K>(keyOf(entity)));
    column.setVariableValue(entity, null);
    return save(entity);
  }

  /// Deletes [key] from [store], logging rather than raising on failure.
  ///
  /// Every caller has already completed the operation the user asked for — the
  /// row was updated, the row was deleted, the save was rolled back. A store
  /// that will not delete leaves bytes behind, which is a housekeeping problem;
  /// raising would report a completed operation as failed, which is a
  /// correctness problem. The key is logged so a sweep can find what was left.
  Future<void> _discardBlob(TomBlobStore store, String key) async {
    try {
      await store.delete(key);
    } on Object catch (error) {
      tomLog.warn(
        'Orphaned blob "$key" could not be deleted from $store: $error',
      );
    }
  }

  /// The (column, key) pairs whose blobs an update has orphaned: file columns
  /// that cascade, whose [baseline] value is a key, and whose newly [written]
  /// value differs from it.
  ///
  /// Measured against the value actually **written** rather than the row read
  /// back: a C-4 masked column reads back as `null`, which would otherwise look
  /// like the file having been removed and would delete a live blob. A column
  /// absent from [written] — a read-only one — was not changed by this save and
  /// so orphans nothing.
  List<(TomColumnInformation, String)> _supersededFiles(
    T? baseline,
    Map<String, Object?> written,
  ) {
    final result = <(TomColumnInformation, String)>[];
    if (baseline == null) return result;
    for (final column in _fileColumns) {
      if (!column.fileReference!.cascadeDelete) continue;
      if (!written.containsKey(column.declaredName)) continue;
      final previous = column.getVariableValue(baseline);
      if (previous is! String || previous.isEmpty) continue;
      if (written[column.declaredName] == previous) continue;
      result.add((column, previous));
    }
    return result;
  }

  /// Deletes the blobs referenced by [rows], for the cascade of a row delete.
  ///
  /// Called **after** the rows are gone: a delete that fails must not have
  /// destroyed the files of rows that are still there.
  Future<void> _deleteReferencedFiles(Iterable<T> rows) async {
    final columns = _fileColumns;
    if (columns.isEmpty) return;
    for (final row in rows) {
      for (final column in columns) {
        if (!column.fileReference!.cascadeDelete) continue;
        final key = column.getVariableValue(row);
        if (key is! String || key.isEmpty) continue;
        await _discardBlob(_fileStore(column), key);
      }
    }
  }

  /// The rows a pending delete is about to remove, read **unmasked** so their
  /// file keys are visible for the cascade; empty when the entity stores no
  /// files, so a delete on an ordinary entity keeps its single statement.
  ///
  /// [where] is the delete's own predicate (scope already ANDed in) and
  /// [params] its bind values, so exactly the rows that will be deleted are the
  /// rows whose files are collected.
  Future<List<T>> _rowsAboutToBeDeleted(
    TomOperator<TomDbBool> where,
    Map<String, Object?> params,
  ) async {
    if (_fileColumns.isEmpty) return const [];
    return _runPrepared<T>(TomSelect(queryTypes, query: where), params);
  }

  /// The audit name of this repository's entity — what a record's
  /// `target` says the action was performed on (CE-LG).
  ///
  /// The entity type name rather than the table name: an auditor reads a trail
  /// alongside the domain, and the storage table is an implementation detail
  /// that may be renamed without the audited thing changing.
  String get _auditTarget => T.toString();

  /// The entity's persisted state as a `column -> value` map, for a record's
  /// `before`/`after` image.
  ///
  /// Keyed by declared field name, matching what a spec author and an auditor
  /// both recognise; the database column name is a mapping detail.
  Map<String, Object?> _auditValues(T? entity) {
    if (entity == null) return const {};
    final columns = TomAnnotationAnalyzer.getPersistentColumns(T) ?? const [];
    return {
      for (final col in columns) col.declaredName: col.getVariableValue(entity),
    };
  }

  /// Whether [action] on this entity is audited right now.
  ///
  /// Consulted before doing any *work* for the trail (a before-image read, a
  /// value map), so an unaudited entity pays nothing.
  bool _audits(TomAuditAction action) =>
      TomAuditTrail.isEnabled && TomAuditTrail.policyFor(T).audits(action);

  /// Writes a mutation record for this entity (CE-LG).
  ///
  /// Called after the statement has succeeded, so the recorded outcome is
  /// truthful. It is deliberately **awaited and not caught**: if the trail
  /// cannot store the entry the mutation raises, which inside a transaction
  /// rolls the change back, and outside one still refuses to report success
  /// for an action that left no record.
  Future<void> _audit(
    TomAuditAction action, {
    Object? key,
    Map<String, Object?> before = const {},
    Map<String, Object?> after = const {},
  }) => TomAuditTrail.recordMutation(
    entityType: T,
    action: action,
    target: _auditTarget,
    targetKey: key?.toString(),
    before: before,
    after: after,
  );

  TomPreparedStatement<T>? _deleteQuery;

  @override
  Future<void> delete(T entity) async {
    // Read through `readPrimaryKey` for the same reason [save] does: an entity
    // that was never persisted carries a null or negative key, and a direct
    // `as K` turns that ordinary caller mistake into a `TypeError` naming
    // `Null` and `int` — two types the caller never wrote.
    final primaryKey = readPrimaryKey<K>(keyOf(entity));
    if (isUnsavedKey(primaryKey)) {
      throw TomRepositoryException(
        'crud_repository.delete.unsaved_entity',
        'That record has never been saved, so there is nothing to delete.',
        parameters: {'entity': T.toString(), 'id': '$primaryKey'},
        // The one repository error the caller caused, so unlike its siblings
        // its message is the caller's to see: it describes the caller's own
        // argument and names nothing about the server.
        clientThrow: true,
      );
    }
    // Non-null: `isUnsavedKey` is false, exactly as at the [save] call sites.
    final K id = primaryKey as K;
    // C-3: a principal may only delete a row within its data scope.
    await _assertRowWritable(id);
    // The caller handed us the row, so the before-image costs no extra read.
    final before = _audits(TomAuditAction.delete)
        ? _auditValues(entity)
        : const <String, Object?>{};
    // The file keys are read back from storage rather than taken from the
    // caller's [entity]: if the entity came from `findById` its C-4 masked
    // columns are null, and a masked file key would then silently escape the
    // cascade. Only entities that declare file columns pay for this read.
    final doomed = <T>[];
    if (_fileColumns.isNotEmpty) {
      final stored = await _selectById(id);
      if (stored != null) doomed.add(stored);
    }
    _deleteQuery ??= await datasourceInfo.datasource.prepareStatement(
      TomDelete(queryTypes, query: _keyPredicate()),
    );
    await _deleteQuery!.execute(_keyParameters(id));
    await _deleteReferencedFiles(doomed);
    await _audit(TomAuditAction.delete, key: id, before: before);
    return;
  }

  /// Namespace for the per-element placeholders the id-list methods
  /// ([existsById], [findAllById], [deleteAllById]) generate, kept distinct
  /// from the row-scope prefix (`__tomscope_`) so an id list ANDed with a scope
  /// cannot collide on parameter names.
  static const String _idListPrefix = '__idlist_';

  /// Builds the `<pk> IN (:__idlist_0, …)` predicate for [ids] with one bound
  /// placeholder per id — for a composite key, one `(<k1> = … AND <k2> = …)`
  /// term per id, ORed — ANDed with the current principal's row scope (C-3)
  /// when the entity declares one, together with the merged bind-parameter map.
  ///
  /// Centralises the IN-list rendering the three id-list methods share: the
  /// MySQL driver does not expand a bound `Iterable` into `IN (?,?,…)`, so the
  /// placeholders are generated per element here and the statement is prepared
  /// per call (its `?` count varies with the id set size). An empty [ids]
  /// yields a `FALSE` predicate — matching no rows — rather than the invalid
  /// `IN ()`.
  Future<(TomOperator<TomDbBool>, Map<String, Object?>)> _idListPredicate(
    Iterable<K> ids, {
    bool forWrite = false,
  }) async {
    final scope = await _resolveScope(forWrite: forWrite);
    final idList = hasCompositeKey
        ? _compositeKeyList(ids)
        : TomDataScope.inList(
            this,
            primaryKeyColumns.single,
            ids,
            prefix: _idListPrefix,
          );
    final where = scope == null
        ? idList.predicate
        : and([idList.predicate, scope.predicate]);
    final params = <String, Object?>{
      ...idList.parameters,
      ...?scope?.parameters,
    };
    return (where, params);
  }

  @override
  Future<int> deleteAllById(Iterable<K> ids) async {
    // C-3: every named row must be within the principal's data scope.
    await _assertIdsWritable(ids);
    final (where, params) = await _idListPredicate(ids);
    // Collected before the delete (the rows are about to be unreadable) but
    // discarded after it — see [_rowsAboutToBeDeleted].
    final doomed = await _rowsAboutToBeDeleted(where, params);
    final affected = await _runPreparedAffecting(
      TomDelete(queryTypes, query: where),
      params,
    );
    await _deleteReferencedFiles(doomed);
    // One record per row, not per call: an auditor asks what happened to a
    // record, and an entry naming a batch cannot answer that.
    for (final id in ids) {
      await _audit(TomAuditAction.delete, key: id);
    }
    return affected;
  }

  TomPreparedStatement<T>? _deleteByIdQuery;
  @override
  Future<int> deleteById(K id) async {
    // C-3: a principal may only delete a row within its data scope.
    await _assertRowWritable(id);
    final doomed = <T>[];
    if (_fileColumns.isNotEmpty) {
      final stored = await _selectById(id);
      if (stored != null) doomed.add(stored);
    }
    _deleteByIdQuery ??= await datasourceInfo.datasource.prepareStatement(
      TomDelete(queryTypes, query: _keyPredicate()),
    );
    await _deleteByIdQuery!.execute(_keyParameters(id));
    // Read before anything else runs: the count is per-execution state on the
    // handle, and the file cascade below executes further statements.
    final affected = _deleteByIdQuery!.lastAffectedRows;
    await _deleteReferencedFiles(doomed);
    // Key only, no before-image. Reading the row first would put an extra
    // SELECT on every delete in every deployment, to recover data the trail is
    // not there to restore — attribution ("who destroyed which record") is the
    // question an audit trail answers, and the key answers it. A caller that
    // needs the row's final state recorded has it in hand and calls
    // [delete] with the entity.
    await _audit(TomAuditAction.delete, key: id);
    return affected;
  }

  @override
  Future<bool> existsById(Iterable<K> ids) => _existsById(ids);

  /// The body of [existsById], additionally able to ask the question of the
  /// *writable* row set — which is what `_assertIdsWritable` needs and a caller
  /// asking "do these rows exist" does not.
  Future<bool> _existsById(Iterable<K> ids, {bool forWrite = false}) async {
    final idSet = ids.toSet();
    // The empty set is vacuously contained; short-circuit before emitting the
    // invalid `IN ()`.
    if (idSet.isEmpty) return true;
    final (where, params) = await _idListPredicate(idSet, forWrite: forWrite);
    // Every requested id exists iff the COUNT of matching rows equals the
    // number of distinct ids. The prior code compared the *row count* of a
    // COUNT query — always 1 — to `ids.length`, so it only ever held for a
    // single id. Under a row scope the count reflects only in-scope
    // rows, so the check doubles as the writability guard `_assertIdsWritable`
    // reuses. Prepared per call: the placeholder count tracks the id set size.
    final result = await _runPrepared<TomCountResult>(
      TomCount(queryTypes, query: where),
      params,
      TomCountResult,
    );
    return result.isNotEmpty && result[0].count == idSet.length;
  }

  TomPreparedStatement<T>? _findAllQuery;
  @override
  Future<List<T>> findAll([TomPageRequest? page]) async {
    final scope = await _resolveScope();
    final window = _effectivePage(page);
    if (scope == null) {
      if (window == null) {
        _findAllQuery ??= await datasourceInfo.datasource.prepareStatement(
          TomLiteralSelect(
            [T],
            query:
                '''
SELECT * FROM ${dbTable.table}
      ''',
          ),
        );
        return _maskRows(await _findAllQuery!.execute({}));
      }
      // A window varies per call, so it cannot share the cached statement; the
      // clauses are appended to the same `SELECT *`, with the sort names
      // resolved against the entity's columns first — a literal select renders
      // its own text, so nothing else would resolve them.
      final sort = TomGeneratedQuery.resolveSortColumns(window.sort, [
        persistenceInfo,
      ]);
      return _maskRows(
        await _runPrepared<T>(
          TomLiteralSelect(
            [T],
            query:
                'SELECT * FROM ${dbTable.table}'
                '${TomGeneratedQuery.orderByClause(sort)}'
                '${TomGeneratedQuery.limitClause(window.limit, window.offset)}',
          ),
          {},
        ),
      );
    }
    // Scoped: the WHERE is the scope predicate alone; a generated SELECT emits
    // the persistent columns and binds the principal's allowed values.
    return _maskRows(
      await _runPrepared<T>(
        _pagedSelect(TomSelect(queryTypes, query: scope.predicate), window),
        {...scope.parameters},
      ),
    );
  }

  @override
  Future<List<T>> findAllById(Iterable<K> ids, [TomPageRequest? page]) async {
    // One bound `?` per id: the MySQL driver does not expand a bound
    // Iterable into `IN (?,?,…)`, so `_idListPredicate` renders the placeholders
    // per element and ANDs the principal's row scope on top. No value is
    // concatenated into the SQL (C-7); prepared per call as the `?` count
    // varies with `ids.length`.
    final (where, params) = await _idListPredicate(ids);
    return _maskRows(
      await _runPrepared<T>(
        _pagedSelect(TomSelect(queryTypes, query: where), _effectivePage(page)),
        params,
      ),
    );
  }

  TomPreparedStatement<T>? _findByIdQuery;
  @override
  Future<T?> findById(K id) async {
    final row = await _selectById(id);
    // C-4: mask the columns the current principal may not see before the row
    // leaves the server. `save` reads its update baseline through the unmasked
    // `_selectById` instead, so a masked-null never reaches the diff.
    if (row == null) return null;
    final authColumns = _authColumns;
    if (authColumns.isEmpty) return row;
    return TomColumnAuthorization.applyReadMask<T>(row, authColumns);
  }

  /// Loads the row with primary key [id] **without** C-4 column masking, ANDing
  /// the current principal's row scope (C-3) when the entity declares one, or
  /// `null` when no such row is visible.
  ///
  /// This is the raw read [findById] masks and [save] diffs its update against —
  /// a write must be measured against the true stored value, not a masked null.
  Future<T?> _selectById(K id, {bool forWrite = false}) async {
    final scope = await _resolveScope(forWrite: forWrite);
    List<T> result;
    if (scope == null) {
      final params = _keyParameters(id);
      _findByIdQuery =
          _findByIdQuery ??
          await datasourceInfo.datasource.prepareStatement(
            TomLiteralSelect(
              [T],
              query:
                  'SELECT * FROM ${dbTable.table} WHERE ${_keyWhereClause()}',
              parameters: params.keys.toList(),
            ),
          );
      result = await _findByIdQuery!.execute(params);
    } else {
      // Scoped: the id match is ANDed with the principal's row scope, so a
      // principal cannot read another principal's row by its id.
      final params = <String, Object?>{
        ..._keyParameters(id),
        ...scope.parameters,
      };
      final where = and([_keyPredicate(), scope.predicate]);
      result = await _runPrepared<T>(
        TomSelect(queryTypes, query: where),
        params,
      );
    }
    if (result.length == 1) {
      return result[0];
    } else if (result.isEmpty) {
      return null;
    } else {
      throw TomRepositoryException(
        'crud_repository.find_by_id.duplicate_primary_key',
        "Found more than one record with the same ID, this is not possible for a primary key",
      );
    }
  }

  /// Unwraps the single row a `COUNT(*)` must return, raising
  /// [TomRepositoryException] under [key] when it returned any other number.
  ///
  /// Shared by [count], [countByQuery] and [countByQuerySentence]. [key] is
  /// passed in rather than derived from the caller so that each method's key
  /// stays a literal at its own call site and remains greppable.
  static TomDbInt _singleCount(List<TomCountResult> rows, String key) {
    if (rows.length != 1) {
      throw TomRepositoryException(
        key,
        "Illegal count result. Must have exactly one result row, but had ${rows.length}",
      );
    }
    return TomDbInt(rows[0].count);
  }

  TomPreparedStatement<TomCountResult>? _countQuery;
  @override
  Future<TomDbInt> count() async {
    final scope = await _resolveScope();
    List<TomCountResult> result;
    if (scope == null) {
      _countQuery ??= await datasourceInfo.datasource
          .prepareStatement<TomCountResult>(
            TomLiteralSelect(
              [T],
              query:
                  '''
    SELECT COUNT(*) AS count FROM ${dbTable.table}
''',
            ),
          );
      result = await _countQuery!.execute({});
    } else {
      result = await _runPrepared<TomCountResult>(
        TomCount(queryTypes, query: scope.predicate),
        {...scope.parameters},
        TomCountResult,
      );
    }
    return _singleCount(result, 'crud_repository.count.illegal_count_result');
  }

  // ───────────────────────────── Primary key ──────────────────────────────

  /// The primary-key value of [entity]: the key field's value, or for a
  /// composite key a [TomCompositeKey] of every key field's value.
  Object? keyOf(T entity) {
    if (!hasCompositeKey)
      return primaryKeyColumns.single.getVariableValue(entity);
    return TomCompositeKey({
      for (var i = 0; i < primaryKeyColumns.length; i++)
        dbTable.primaryKeyFields[i]: primaryKeyColumns[i].getVariableValue(
          entity,
        ),
    });
  }

  /// [id] as the composite key it must be, refused when it is not one or
  /// carries other fields than the entity's key.
  ///
  /// A key with a field missing would match every row that agrees on the rest,
  /// and every by-key method promises one row; a key with an extra field names
  /// something the table is not keyed by. Both are the caller's mistake, so the
  /// message is the caller's to see.
  TomCompositeKey _compositeKey(Object? id) {
    final expected = dbTable.primaryKeyFields.toSet();
    if (id is TomCompositeKey &&
        id.values.length == expected.length &&
        expected.every(id.values.containsKey)) {
      return id;
    }
    throw TomRepositoryException(
      'crud_repository.key.shape_mismatch',
      '$T is keyed by (${dbTable.primaryKeyFields.join(', ')}), '
          'which the key $id does not match.',
      parameters: {
        'entity': '$T',
        'fields': dbTable.primaryKeyFields.join(','),
        'id': '$id',
      },
      clientThrow: true,
    );
  }

  /// The bind values that address the row keyed by [id], named as
  /// [_keyPredicate] and [_keyWhereClause] name their placeholders: [prefix]
  /// for a single key, `<prefix>_0`, `<prefix>_1`, … for a composite one.
  Map<String, Object?> _keyParameters(Object? id, [String prefix = 'id']) {
    if (!hasCompositeKey) return {prefix: id};
    final key = _compositeKey(id);
    return {
      for (var i = 0; i < primaryKeyColumns.length; i++)
        '${prefix}_$i': key[dbTable.primaryKeyFields[i]],
    };
  }

  /// The predicate matching the row whose key binds through [prefix] — one
  /// equality, or one per key column ANDed.
  TomOperator<TomDbBool> _keyPredicate([String prefix = 'id']) {
    if (!hasCompositeKey) {
      return TomDataScope.columnEqualsParam(
        this,
        primaryKeyColumns.single,
        prefix,
      );
    }
    return and([
      for (var i = 0; i < primaryKeyColumns.length; i++)
        TomDataScope.columnEqualsParam(
          this,
          primaryKeyColumns[i],
          '${prefix}_$i',
        ),
    ]);
  }

  /// [_keyPredicate] as SQL text, for the literal statements that address a row
  /// by key without going through the query builder.
  String _keyWhereClause() {
    if (!hasCompositeKey) return '${primaryKeyColumns.single.field} = :id';
    return [
      for (var i = 0; i < primaryKeyColumns.length; i++)
        '${primaryKeyColumns[i].field} = :id_$i',
    ].join(' AND ');
  }

  /// One `(<k1> = … AND <k2> = …)` term per key in [ids], ORed, with its bind
  /// values — the composite counterpart of [TomDataScope.inList].
  TomDataScopePredicate _compositeKeyList(Iterable<K> ids) {
    final keys = ids.toList();
    if (keys.isEmpty) return TomDataScopePredicate(boolOp(false), const {});
    final parameters = <String, Object?>{};
    final terms = <TomOperator<TomDbBool>>[];
    for (var n = 0; n < keys.length; n++) {
      final prefix = '$_idListPrefix$n';
      parameters.addAll(_keyParameters(keys[n], prefix));
      terms.add(_keyPredicate(prefix));
    }
    return TomDataScopePredicate(or(terms), parameters);
  }

  /// Whether [save] inserts the entity whose key is [primaryKey].
  ///
  /// A single key decides by itself: an unsaved key is one the database has not
  /// assigned yet. A composite key is supplied whole by the caller and so says
  /// nothing about whether the row exists — the table is asked, without the
  /// row scope, because an existing row the principal may not write must take
  /// the update path and be refused there, not collide as a duplicate insert. A
  /// composite key with a field missing addresses no row and is refused.
  Future<bool> _isInsert(Object? primaryKey) async {
    if (!hasCompositeKey) return isUnsavedKey(primaryKey);
    if (isUnsavedKey(primaryKey)) {
      throw TomRepositoryException(
        'crud_repository.save.incomplete_key',
        'Every field of the key (${dbTable.primaryKeyFields.join(', ')}) must '
            'be set before $T can be saved, but the key was $primaryKey.',
        parameters: {'entity': '$T', 'id': '$primaryKey'},
        clientThrow: true,
      );
    }
    _keyStoredQuery ??= await datasourceInfo.datasource
        .prepareStatement<TomCountResult>(
          TomLiteralSelect(
            [T],
            query:
                'SELECT COUNT(*) AS count FROM ${dbTable.table} '
                'WHERE ${_keyWhereClause()}',
            parameters: _keyParameters(primaryKey).keys.toList(),
          ),
        );
    final rows = await _keyStoredQuery!.execute(_keyParameters(primaryKey));
    return rows.isEmpty || rows[0].count == 0;
  }

  TomPreparedStatement<TomCountResult>? _keyStoredQuery;

  /// Whether [primaryKey] marks an entity that has **not** yet been persisted,
  /// so [save] should `INSERT` rather than `UPDATE`.
  ///
  /// Two unsaved conventions are honoured: a nullable surrogate key is `null`
  /// before its first persist, and a non-nullable `int` key uses a negative
  /// sentinel (the `id >= 0` convention `TomResourceGrant` and friends rely on).
  ///
  /// A [TomCompositeKey] is unsaved while any of its fields is `null`: the
  /// caller supplies every field of such a key, so one left out means the
  /// entity is not yet a row anything could address. A complete composite key
  /// does not say whether it is stored — [save] asks the table.
  static bool isUnsavedKey(Object? primaryKey) =>
      primaryKey == null ||
      (primaryKey is num && primaryKey < 0) ||
      (primaryKey is TomCompositeKey &&
          primaryKey.values.values.any((value) => value == null));

  /// Reads an entity's primary-key value as a *nullable* [K2].
  ///
  /// A not-yet-persisted entity with a nullable surrogate key (`int?`) carries
  /// `null`, which [isUnsavedKey] is explicitly designed to accept. Casting
  /// straight to a non-nullable `K` (e.g. `int`) threw
  /// `Null is not a subtype of int` on every insert of such an entity,
  /// defeating the very check that gates INSERT vs UPDATE — so the read must
  /// tolerate null. Negative-sentinel `int` keys arrive non-null and are
  /// handled by [isUnsavedKey] all the same.
  static K2? readPrimaryKey<K2>(Object? raw) => raw as K2?;

  /// Builds the `INSERT` statement and its ordered bind-parameter names for
  /// [table] over the writable [columns] (the caller filters out read-only
  /// columns such as an auto-increment primary key).
  ///
  /// Each value binds through a `:declaredName` placeholder, and the parameter
  /// list is those declared names in column order — matching the
  /// `:name -> ?` substitution and positional binding `prepareStatement`
  /// performs from [TomLiteralSelect.getParameters].
  static (String, List<String>) buildInsertStatement(
    String table,
    List<TomColumnInformation> columns,
  ) {
    final fields = [for (final c in columns) c.getQueryFieldName()];
    final paramNames = [for (final c in columns) c.declaredName];
    final placeholders = [for (final n in paramNames) ':$n'];
    final sql =
        'INSERT INTO $table ( ${fields.join(',')} )'
        ' VALUES ( ${placeholders.join(',')} )';
    return (sql, paramNames);
  }

  /// Builds the `UPDATE ... SET ... WHERE pk = :pk` statement and its ordered
  /// bind-parameter names for [table] over the writable [columns], keyed on
  /// the [primaryKey] columns.
  ///
  /// The `SET` clause assigns each column by its mapped column name; the
  /// trailing `WHERE` scopes the update to the single row by every primary-key
  /// column, ANDed (each placeholder and bind name is the key field's declared
  /// name, appended last in key order). Without that clause the statement would
  /// rewrite every row.
  static (String, List<String>) buildUpdateStatement(
    String table,
    List<TomColumnInformation> columns,
    List<TomColumnInformation> primaryKey,
  ) {
    final assignments = [
      for (final c in columns) '${c.getQueryFieldName()} = :${c.declaredName}',
    ];
    final paramNames = [
      for (final c in columns) c.declaredName,
      for (final k in primaryKey) k.declaredName,
    ];
    final where = [
      for (final k in primaryKey)
        '${k.getQueryFieldName()} = :${k.declaredName}',
    ];
    final sql =
        'UPDATE $table SET ${assignments.join(',')}'
        ' WHERE ${where.join(' AND ')}';
    return (sql, paramNames);
  }

  TomPreparedStatement<T>? _saveInsertQuery;
  TomPreparedStatement<T>? _saveUpdateQuery;
  @override
  Future<T> save(T toSave) async {
    // The repository resolved this in its constructor, where a type that is
    // not a mapped entity is reported as one. Asking the analyzer again would
    // hit the same memo, so the only thing a second lookup could add is the
    // chance to null-assert it.
    final persistentColumns = persistenceInfo.columnInfo;
    final primaryKey = readPrimaryKey<K>(keyOf(toSave));
    // The columns the statement writes: everything except the read-only ones
    // (the auto-increment primary key, audit-managed columns, …).
    final writable = [
      for (final col in persistentColumns)
        if (!(col.column?.isReadOnly ?? false)) col,
    ];
    Object? dbConvert(TomColumnInformation col, Object? raw) {
      final convert = col.column?.toDbConverter;
      return convert != null ? convert(raw) : raw;
    }

    final insert = await _isInsert(primaryKey);

    // C-3 row-level write enforcement. An insert must carry a scope-field value
    // the principal is allowed (it cannot create a row outside its scope); an
    // update must target a row already within the principal's scope (it cannot
    // update a row it could not read). Both raise before any statement runs.
    if (insert) {
      await _assertInsertWritable(toSave);
    } else {
      await _assertRowWritable(primaryKey as K);
    }

    // C-4 column-level write enforcement. For an entity that declares
    // `@TomDbColumn(authKey: …)` columns, a change to one the principal is not
    // `full` on is rejected when the column is *visible* (`read`), and preserved
    // from the baseline when it is *masked* (`none`/`disabled`) — so a
    // round-tripped masked-null cannot clobber the stored value. `overrides`
    // holds the baseline (db-converted) value to bind for each preserved column.
    final authColumns = TomAnnotationAnalyzer.findAuthColumns(T);
    final overrides = <String, Object?>{};

    // The stored row before this save: the true, unmasked state, `null` for an
    // insert (a fresh row starts empty, so any populated column is a change).
    //
    // Read **once** and shared by the three features that need it — C-4 write
    // authorization, which compares against it to decide what changed, the
    // CE-LG audit before-image, which records it, and the file-reference
    // cascade, which needs the key a replaced file column is about to orphan.
    // They ask for the same row for different reasons; reading it once per
    // reason would multiply the cost of every update on an entity that uses
    // more than one.
    final needsBaseline =
        !insert &&
        (authColumns.isNotEmpty ||
            _fileColumns.isNotEmpty ||
            _audits(TomAuditAction.update));
    final baseline = needsBaseline ? await _selectById(primaryKey as K) : null;

    if (authColumns.isNotEmpty) {
      Object? baselineOf(TomColumnInformation col) =>
          baseline == null ? null : col.getVariableValue(baseline);
      final decision = TomColumnAuthorization.decideWrites<TomColumnInformation>(
        columns: authColumns,
        gradeOf: (col) => col.authKey,
        changed: (col) => col.getVariableValue(toSave) != baselineOf(col),
        onForbidden: (col, key, grade) => throw TomColumnAuthorizationException(
          'column_authorization.write.field_forbidden',
          'Column "${col.declaredName}" (resource "$key") is not writable at '
              'your access level (${grade.name}).',
        ),
      );
      for (final col in decision.preserved) {
        overrides[col.declaredName] = dbConvert(col, baselineOf(col));
      }
    }

    Object? dbValue(TomColumnInformation col) =>
        overrides.containsKey(col.declaredName)
        ? overrides[col.declaredName]
        : dbConvert(col, col.getVariableValue(toSave));

    if (insert) {
      // INSERT
      final (sql, paramNames) = buildInsertStatement(dbTable.table, writable);
      _saveInsertQuery ??= await datasourceInfo.datasource.prepareStatement<T>(
        TomLiteralSelect([T], query: sql, parameters: paramNames),
      );
      final params = <String, Object?>{
        for (final col in writable) col.declaredName: dbValue(col),
      };
      await _saveInsertQuery!.execute(params);
      // Resolve the row's key. A composite key was supplied whole and is the
      // row's key as written. A single key reaches this branch exactly when it
      // was left unsaved, so the database assigned an auto-increment surrogate
      // and the insert statement's own result is the only place it can be read
      // from:
      // `lastGeneratedId` is connection-correct by construction, where a
      // follow-up query for "the last key" is session-scoped and answers about
      // whichever connection it happens to run on.
      //
      // A driver that answers `null` here is saying the insert assigned no key,
      // which for a row whose key this repository asked the database to assign
      // is not a state to carry forward: every later step — the read-back, the
      // audit record, the key returned to the caller — would name a row that is
      // not the one just written. So it is refused by name.
      final K rowKey = hasCompositeKey
          ? primaryKey as K
          : (_saveInsertQuery!.lastGeneratedId ??
                    _noGeneratedKey(dbTable.table))
                as K;
      final newRow = await findById(rowKey);
      if (newRow != null) {
        // A create has no before-image; the whole stored row is the change.
        await _audit(
          TomAuditAction.create,
          key: rowKey,
          after: _audits(TomAuditAction.create)
              ? _auditValues(newRow)
              : const {},
        );
        return newRow;
      }
      throw TomRepositoryException(
        'crud_repository.save.insert_not_readable',
        "Insert failed. When saving object with primary key $rowKey no "
            "record was created.",
      );
    } else {
      // UPDATE
      final (sql, paramNames) = buildUpdateStatement(
        dbTable.table,
        writable,
        primaryKeyColumns,
      );
      _saveUpdateQuery ??= await datasourceInfo.datasource.prepareStatement<T>(
        TomLiteralSelect([T], query: sql, parameters: paramNames),
      );
      final params = <String, Object?>{
        for (final col in writable) col.declaredName: dbValue(col),
        for (final key in primaryKeyColumns)
          key.declaredName: key.getVariableValue(toSave),
      };
      // Which blobs this update strands, decided from the values about to be
      // written and collected *before* the statement runs — afterwards the
      // baseline key is no longer anywhere to be read.
      final superseded = _supersededFiles(baseline, params);
      await _saveUpdateQuery!.execute(params);
      // Discarded only once the row no longer points at them.
      for (final (column, key) in superseded) {
        await _discardBlob(_fileStore(column), key);
      }
      // Reached only when `isUnsavedKey` is false, so the key is non-null.
      final newRow = await findById(primaryKey as K);
      if (newRow != null) {
        // Only the fields that actually changed: a full row image on every
        // update multiplies the trail by the row width and the unchanged
        // columns tell an auditor nothing. `newRow` is read back through
        // [findById], so a C-4 masked column reads as null on both sides of
        // the diff and drops out rather than being recorded as a false change.
        if (_audits(TomAuditAction.update)) {
          final diff = auditDiff(_auditValues(baseline), _auditValues(newRow));
          await _audit(
            TomAuditAction.update,
            key: primaryKey,
            before: diff.before,
            after: diff.after,
          );
        }
        return newRow;
      }
      throw TomRepositoryException(
        'crud_repository.save.update_not_readable',
        "Update failed. When saving object with primary key $primaryKey the "
            "record could not be retrieved.",
      );
    }
  }

  /// Refuses an insert whose surrogate key the driver did not report.
  ///
  /// Named separately so the raise site stays one expression, and separately
  /// from the insert's other failure — `insert_not_readable`, which is what a
  /// *key* that reads back no row looks like. The two are different faults with
  /// different fixes: this one is the driver or the table (no key was assigned,
  /// or the driver does not report one), that one is the row.
  Never _noGeneratedKey(String table) {
    throw TomRepositoryException(
      'crud_repository.save.no_generated_key',
      "Insert into '$table' reported no generated key, but the row's primary "
          "key was left for the database to assign. Either the table assigns "
          "no auto-increment key for its primary key, or the driver "
          "(${datasourceInfo.datasource.runtimeType}) does not report one from "
          "the insert's result — see TomPreparedStatement.lastGeneratedId.",
      parameters: {
        'table': table,
        'type': '$T',
        'datasource': '${datasourceInfo.datasource.runtimeType}',
      },
    );
  }

  @override
  Future<Iterable<T>> saveAll(Iterable<T> entities) async {
    List<T> result = [];
    for (var entity in entities) {
      result.add(await save(entity));
    }
    return result;
  }

  /// Prepares [query], runs it once with [params], releases the server-side
  /// statement, and returns the mapped rows (optionally typed by [resultType]).
  ///
  /// Every dynamic (non-cached) query path routes through here so its bind
  /// values ride the prepared-statement protocol as positional parameters —
  /// no value is ever concatenated into the SQL text, closing the injection
  /// surface `executeQuery`/`executeCommand` left open.
  Future<List<R>> _runPrepared<R extends Object>(
    TomQuery query,
    Map<String, Object?> params, [
    Type? resultType,
  ]) async {
    final stmt = await datasourceInfo.datasource.prepareStatement<R>(
      query,
      resultType,
    );
    try {
      return await stmt.execute(params);
    } finally {
      await stmt.deallocate();
    }
  }

  /// Prepares [query], runs it once with [params], releases the server-side
  /// statement, and returns the number of rows it changed.
  ///
  /// The write counterpart of [_runPrepared], which returns rows and therefore
  /// cannot answer "how many did that touch": a `DELETE` returns no rows, and
  /// its count is per-execution state on the statement handle. Reading it here
  /// — inside the `try`, before the `finally` deallocates — is the only place
  /// it is still available.
  Future<int> _runPreparedAffecting(
    TomQuery query,
    Map<String, Object?> params,
  ) async {
    final stmt = await datasourceInfo.datasource.prepareStatement<T>(query);
    try {
      await stmt.execute(params);
      return stmt.lastAffectedRows;
    } finally {
      await stmt.deallocate();
    }
  }

  /// Extracts `:name` placeholder names from [sql] in textual order (repeats
  /// included), so a raw statement can be prepared and its values bound
  /// positionally in the order the `?` slots appear.
  ///
  /// Delegates to the shared, quote-aware [SqlPlaceholderScan.extractNames] so
  /// this extraction and [MariaDbDatasource.toPositionalStatement]'s positional
  /// rewrite tokenise identically — including skipping a `:name`-looking
  /// substring inside an inlined string literal.
  static List<String> _extractPlaceholderNames(String sql) =>
      SqlPlaceholderScan.extractNames(sql);

  /// Compiles a caller-supplied [querySentence] and checks that it is the kind
  /// of query [Q] the calling method can actually run, raising
  /// [TomQuerySyntaxException] under [key] when it is not.
  ///
  /// The sentence's verb selects the compiled type — `find by …` yields a
  /// [TomSelect], `count by …` a [TomCount], `delete by …` a [TomDelete] — so
  /// handing `find by …` to a counting method is a caller mistake, and a
  /// mistake in the *sentence*, which is why it reuses the compiler's own
  /// [TomQuerySyntaxException] rather than a repository error. [verb] names the
  /// verb the method expects, so the message says what to write instead.
  ///
  /// A bare cast would surface a raw `TypeError` naming internal query classes:
  /// unclassified, unlocalisable, and outside the module's exception family.
  Q _compileSentenceAs<Q extends TomQuery>(
    String querySentence,
    String key,
    String verb,
  ) {
    final compiled = _qsc.compileQuerySentence(querySentence);
    if (compiled is Q) return compiled;
    throw TomQuerySyntaxException(
      key,
      'Query sentence must start with "$verb", but was "$querySentence".',
    );
  }

  @override
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
    TomPageRequest? page,
  ]) async {
    TomSelect select = _compileSentenceAs<TomSelect>(
      querySentence,
      'crud_repository.find_by_query_sentence.sentence_verb_mismatch',
      'find by',
    );
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    final rows = await _runPrepared<T>(
      _scopedSelect(_pagedSelect(select, _effectivePage(page)), scope),
      effective,
      resultType,
    );
    // C-4: mask only when the rows are the primary entity type; a caller-chosen
    // [resultType] is a projection/aggregate whose columns aren't the entity's.
    return (resultType == null || resultType == T) ? _maskRows(rows) : rows;
  }

  @override
  Future<int> deleteByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomDelete select = _compileSentenceAs<TomDelete>(
      querySentence,
      'crud_repository.delete_by_query_sentence.sentence_verb_mismatch',
      'delete by',
    );
    // C-3: filter the delete to the principal's scope, mirroring the scoped
    // reads — a query-based delete cannot reach out-of-scope rows.
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    final scoped = _scopedDelete(select, scope);
    final doomed = await _rowsAboutToBeDeleted(scoped.query, effective);
    final affected = await _runPreparedAffecting(scoped, effective);
    await _deleteReferencedFiles(doomed);
    return affected;
  }

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomCount select = _compileSentenceAs<TomCount>(
      querySentence,
      'crud_repository.count_by_query_sentence.sentence_verb_mismatch',
      'count by',
    );
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    List<TomCountResult> result = await _runPrepared<TomCountResult>(
      _scopedCount(select, scope),
      effective,
      TomCountResult,
    );
    return _singleCount(
      result,
      'crud_repository.count_by_query_sentence.illegal_count_result',
    );
  }

  @override
  Future<Iterable<T>> findByQuery(
    TomSelect query,
    Map<String, Object?> params, [
    TomPageRequest? page,
  ]) async {
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    return _maskRows(
      await _runPrepared<T>(
        _scopedSelect(_pagedSelect(query, _effectivePage(page)), scope),
        effective,
      ),
    );
  }

  @override
  Future<int> deleteByQuery(
    TomDelete query,
    Map<String, Object?> params,
  ) async {
    // C-3: AND the principal's scope into the delete predicate (as the scoped
    // reads do), so a built delete cannot reach out-of-scope rows.
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    final scoped = _scopedDelete(query, scope);
    final doomed = await _rowsAboutToBeDeleted(scoped.query, effective);
    final affected = await _runPreparedAffecting(scoped, effective);
    await _deleteReferencedFiles(doomed);
    return affected;
  }

  @override
  Future<TomDbInt> countByQuery(
    TomCount query,
    Map<String, Object?> params,
  ) async {
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    List<TomCountResult> result = await _runPrepared<TomCountResult>(
      _scopedCount(query, scope),
      effective,
      TomCountResult,
    );
    return _singleCount(
      result,
      'crud_repository.count_by_query.illegal_count_result',
    );
  }

  @override
  Future<List<TomGroupedRow>> findGroupedByQuery(
    TomGroupedSelect query,
    Map<String, Object?> params,
  ) async {
    _assertGroupedColumnsReadable(query);
    // C-3: the scope goes into the row predicate (see [_scopedGrouped]), so it
    // filters the rows *before* they are aggregated.
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    return _runPrepared<TomGroupedRow>(_scopedGrouped(query, scope), effective);
  }

  /// Rejects a grouped query that touches a column the principal may not see
  /// (C-4).
  ///
  /// The row-returning paths *mask* such a column — they null it out of each
  /// returned entity. A grouped query cannot: by the time the rows exist the
  /// column has already been collapsed into a group key or folded into an
  /// aggregate, so nulling the result would not undo the leak (`COUNT(*)` per
  /// masked group still discloses the masked values' distribution). The only
  /// sound enforcement is therefore to refuse the query outright, and to do so
  /// before it reaches the database.
  void _assertGroupedColumnsReadable(TomGroupedSelect query) {
    final authColumns = _authColumns;
    if (authColumns.isEmpty) return;
    final masked = TomColumnAuthorization.maskedColumns<TomColumnInformation>(
      columns: authColumns,
      keyOf: (column) => column.authKey,
    );
    if (masked.isEmpty) return;
    final maskedNames = {for (final column in masked) column.declaredName};
    final offending = [
      for (final column in query.referencedColumns)
        if (maskedNames.contains(column.declaredName)) column.declaredName,
    ];
    if (offending.isEmpty) return;
    throw TomColumnAuthorizationException(
      "crud_repository.grouped.masked_column",
      "The grouped query references column(s) you are not authorized to read: "
          "${offending.join(', ')}",
      parameters: {"columns": offending.join(', ')},
    );
  }

  @override
  Future<Iterable<T>> executeQueryString(
    String dbQuery,
    Map<String, Object?> params,
  ) async {
    // Wrap the raw SQL as a literal query whose parameters are its `:name`
    // placeholders in textual order, so it prepares and binds positionally
    // instead of string-substituting values into the command.
    final query = TomLiteralSelect(
      [T],
      query: dbQuery,
      parameters: _extractPlaceholderNames(dbQuery),
    );
    return _maskRows(await _runPrepared<T>(query, params));
  }
}
