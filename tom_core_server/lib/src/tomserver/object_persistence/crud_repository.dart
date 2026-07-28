import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../datasources/queries.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/sql_placeholder_scan.dart';
import '../datasources/types_operator.dart';

import 'grouped_query.dart';
import 'persistence_annotations.dart';
import 'query_sentence_compiler.dart';
import 'query_builder.dart';
import 'annotation_analyzer.dart';
import 'column_authorization.dart';
import 'data_scope.dart';

/// Result holder for a `COUNT(*)` query: a single [count] field populated by
/// the row mapper. Reflectable so the data source can materialise it.
///
/// It is a plain reflected holder (no `@TomDbTable`), so the row mapper fills it
/// by *field name*: the `COUNT(*) AS count` projection names its column `count`,
/// which matches this field. (Before RCK13 the mapper had no field-name path for
/// table-less holders and silently left `count` at its default `0`.)
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
/// Note: pageable/limit/slice/sort result options are not yet supported (see the
/// quest completion steps).
abstract class TomRepository<T extends Object, K> {
  /// Deletes [entity] by its primary key.
  Future<void> delete(T entity);

  /// Deletes every entity whose id is in [ids].
  Future<void> deleteAllById(Iterable<K> ids);

  /// Deletes the entity with the given [id].
  Future<void> deleteById(K id);

  /// Whether every id in [ids] exists.
  Future<bool> existsById(Iterable<K> ids);

  /// Loads all entities.
  Future<List<T>> findAll();

  /// Loads every entity whose id is in [ids].
  Future<List<T>> findAllById(Iterable<K> ids);

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
  /// [resultType] overrides the row type.
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
  ]);

  /// Runs a parsed query sentence as a `DELETE`, binding [params].
  Future<void> deleteByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  );

  /// Runs a parsed query sentence as a `COUNT`, binding [params].
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  );

  /// Runs a built [TomSelect], binding [params].
  Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params);

  /// Runs a built [TomDelete], binding [params].
  Future<void> deleteByQuery(TomDelete query, Map<String, Object?> params);

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
    with TomQueryBuilder {
  /// Resolved metadata for the primary-key column.
  late TomColumnInformation primaryKeyColumnInfo;

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
    primaryKeyColumnInfo = TomAnnotationAnalyzer.determineColumn(
      dbTable.primaryKeyField,
      [persistenceInfo],
    );
    if (primaryKeyColumnInfo.entityId == null) {
      tomLog.warn(
        "Primary key field/column ${dbTable.primaryKeyField} is not marked as EntityId",
      );
    }
    var dsInfo = TomDataSourceInfo.getDataSourceInfo(dbTable.datasource);
    if (dsInfo != null) {
      datasourceInfo = dsInfo;
    } else {
      throw Exception(
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
  /// A scope kind registered asynchronously (RCB8) resolves through
  /// [TomDataScope.buildAsync] — the union/OR path that folds ownership and
  /// share-mode delegations (resolved from another database) into the visible
  /// id-set; every other kind takes the synchronous single-`IN` path. The
  /// method is async so the union path can await its cross-database resolution;
  /// the sync path completes synchronously via the returned already-completed
  /// future.
  Future<TomDataScopePredicate?> _resolveScope() async {
    // Inside an async resolver's own enumeration (RCB8), scope resolution is
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
      return TomDataScope.buildAsync(this, scope, col, principal);
    }
    return TomDataScope.build(this, scope, col, principal);
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
  Future<void> _assertRowWritable(K id) async {
    if (TomAnnotationAnalyzer.findDataScope(queryTypes[0]) == null) return;
    if (await _selectById(id) == null) {
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
  /// check and the reads.
  Future<void> _assertIdsWritable(Iterable<K> ids) async {
    if (TomAnnotationAnalyzer.findDataScope(queryTypes[0]) == null) return;
    if (!await existsById(ids)) {
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
  /// An **async** union scope (RCB8) is a no-op here: it scopes on the primary
  /// key (`id IN (visible…)`), but a fresh insert has no id yet, so there is no
  /// scope-field value to check — insert authorization for such entities is
  /// enforced at the service layer (the caller must hold a create grant on the
  /// parent). Applying the read scope to a null/unassigned id would reject every
  /// legitimate insert.
  void _assertInsertWritable(T entity) {
    final scope = TomAnnotationAnalyzer.findDataScope(queryTypes[0]);
    if (scope == null) return;
    if (TomDataScopeRegistry.isAsync(scope.scope)) return;
    final allowed =
        TomDataScope.allowedValues(scope, getFromCurrentZone<TomPrincipal>());
    final col = TomAnnotationAnalyzer.determineColumn(scope.field, [
      persistenceInfo,
    ]);
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
      orderBy: base.orderBy,
      ascending: base.ascending,
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
      orderBy: base.orderBy,
      ascending: base.ascending,
      top: base.top,
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
      orderBy: base.orderBy,
      ascending: base.ascending,
      top: base.top,
    );
  }

  /// Returns [base] with [scope]'s predicate ANDed into its `WHERE` (preserving
  /// every shaping option), or [base] unchanged when [scope] is `null`.
  TomCount _scopedCount(TomCount base, TomDataScopePredicate? scope) {
    if (scope == null) return base;
    return TomCount(
      base.types,
      query: and([base.query, scope.predicate]),
      distinct: base.distinct,
      orderBy: base.orderBy,
      ascending: base.ascending,
      top: base.top,
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
    // C-3: a principal may only delete a row within its data scope.
    await _assertRowWritable(
      primaryKeyColumnInfo.getVariableValue(entity) as K,
    );
    // The caller handed us the row, so the before-image costs no extra read.
    final before = _audits(TomAuditAction.delete)
        ? _auditValues(entity)
        : const <String, Object?>{};
    _deleteQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
delete by ${primaryKeyColumnInfo.getQueryFieldName()} = \$id
      ''')
          as TomDelete,
    );
    Map<String, Object?> params = {
      "id": primaryKeyColumnInfo.getVariableValue(entity),
    };
    await _deleteQuery!.execute(params);
    await _audit(
      TomAuditAction.delete,
      key: primaryKeyColumnInfo.getVariableValue(entity),
      before: before,
    );
    return;
  }

  /// Namespace for the per-element placeholders the id-list methods
  /// ([existsById], [findAllById], [deleteAllById]) generate, kept distinct
  /// from the row-scope prefix (`__tomscope_`) so an id list ANDed with a scope
  /// cannot collide on parameter names (RCA5).
  static const String _idListPrefix = '__idlist_';

  /// Builds the `<pk> IN (:__idlist_0, …)` predicate for [ids] with one bound
  /// placeholder per id, ANDed with the current principal's row scope (C-3)
  /// when the entity declares one, together with the merged bind-parameter map.
  ///
  /// Centralises the IN-list rendering the three id-list methods share: the
  /// MySQL driver does not expand a bound `Iterable` into `IN (?,?,…)`, so the
  /// placeholders are generated per element here and the statement is prepared
  /// per call (its `?` count varies with the id set size). An empty [ids]
  /// yields a `FALSE` predicate — matching no rows — rather than the invalid
  /// `IN ()` (RCA5).
  Future<(TomOperator<TomDbBool>, Map<String, Object?>)> _idListPredicate(
    Iterable<K> ids,
  ) async {
    final scope = await _resolveScope();
    final idList = TomDataScope.inList(
      this,
      primaryKeyColumnInfo,
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
  Future<void> deleteAllById(Iterable<K> ids) async {
    // C-3: every named row must be within the principal's data scope.
    await _assertIdsWritable(ids);
    final (where, params) = await _idListPredicate(ids);
    await _runPrepared<T>(TomDelete(queryTypes, query: where), params);
    // One record per row, not per call: an auditor asks what happened to a
    // record, and an entry naming a batch cannot answer that.
    for (final id in ids) {
      await _audit(TomAuditAction.delete, key: id);
    }
  }

  TomPreparedStatement<T>? _deleteByIdQuery;
  @override
  Future<int> deleteById(K id) async {
    // C-3: a principal may only delete a row within its data scope.
    await _assertRowWritable(id);
    _deleteByIdQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
delete by ${primaryKeyColumnInfo.getQueryFieldName()} = \$id
      ''')
          as TomDelete,
    );
    Map<String, Object?> params = {"id": id};
    await _deleteByIdQuery!.execute(params);
    // Key only, no before-image. Reading the row first would put an extra
    // SELECT on every delete in every deployment, to recover data the trail is
    // not there to restore — attribution ("who destroyed which record") is the
    // question an audit trail answers, and the key answers it. A caller that
    // needs the row's final state recorded has it in hand and calls
    // [delete] with the entity.
    await _audit(TomAuditAction.delete, key: id);
    return 1;
  }

  @override
  Future<bool> existsById(Iterable<K> ids) async {
    final idSet = ids.toSet();
    // The empty set is vacuously contained; short-circuit before emitting the
    // invalid `IN ()`.
    if (idSet.isEmpty) return true;
    final (where, params) = await _idListPredicate(idSet);
    // Every requested id exists iff the COUNT of matching rows equals the
    // number of distinct ids. The prior code compared the *row count* of a
    // COUNT query — always 1 — to `ids.length`, so it only ever held for a
    // single id (RCA5). Under a row scope the count reflects only in-scope
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
  Future<List<T>> findAll() async {
    final scope = await _resolveScope();
    if (scope == null) {
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
    // Scoped: the WHERE is the scope predicate alone; a generated SELECT emits
    // the persistent columns and binds the principal's allowed values.
    return _maskRows(
      await _runPrepared<T>(
        TomSelect(queryTypes, query: scope.predicate),
        {...scope.parameters},
      ),
    );
  }

  @override
  Future<List<T>> findAllById(Iterable<K> ids) async {
    // One bound `?` per id (RCA5): the MySQL driver does not expand a bound
    // Iterable into `IN (?,?,…)`, so `_idListPredicate` renders the placeholders
    // per element and ANDs the principal's row scope on top. No value is
    // concatenated into the SQL (C-7); prepared per call as the `?` count
    // varies with `ids.length`.
    final (where, params) = await _idListPredicate(ids);
    return _maskRows(
      await _runPrepared<T>(TomSelect(queryTypes, query: where), params),
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
  Future<T?> _selectById(K id) async {
    final scope = await _resolveScope();
    List<T> result;
    if (scope == null) {
      final params = {"id": id};
      _findByIdQuery =
          _findByIdQuery ??
          await datasourceInfo.datasource.prepareStatement(
            TomLiteralSelect(
              [T],
              query:
                  '''
SELECT * FROM ${dbTable.table} WHERE ${primaryKeyColumnInfo.field} = :id
      ''',
              parameters: params.keys.toList(),
            ),
          );
      result = await _findByIdQuery!.execute(params);
    } else {
      // Scoped: the id match is ANDed with the principal's row scope, so a
      // principal cannot read another principal's row by its id.
      final params = <String, Object?>{"id": id, ...scope.parameters};
      final where = and([
        TomDataScope.columnEqualsParam(this, primaryKeyColumnInfo, 'id'),
        scope.predicate,
      ]);
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
      throw Exception(
        "Found more than one record with the same ID, this is not possible for a primary key",
      );
    }
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
    if (result.length != 1) {
      throw Exception(
        "Illegal count result. Must have exactly one result row, but had ${result.length}",
      );
    }
    return TomDbInt(result[0].count);
  }

  /// Whether [primaryKey] marks an entity that has **not** yet been persisted,
  /// so [save] should `INSERT` rather than `UPDATE`.
  ///
  /// Two unsaved conventions are honoured: a nullable surrogate key is `null`
  /// before its first persist, and a non-nullable `int` key uses a negative
  /// sentinel (the `id >= 0` convention `TomResourceGrant` and friends rely on).
  static bool isUnsavedKey(Object? primaryKey) =>
      primaryKey == null || (primaryKey is num && primaryKey < 0);

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
    final sql = 'INSERT INTO $table ( ${fields.join(',')} )'
        ' VALUES ( ${placeholders.join(',')} )';
    return (sql, paramNames);
  }

  /// Builds the `UPDATE ... SET ... WHERE pk = :pk` statement and its ordered
  /// bind-parameter names for [table] over the writable [columns], keyed on
  /// [primaryKey].
  ///
  /// The `SET` clause assigns each column by its mapped column name; the
  /// trailing `WHERE` scopes the update to the single row by the primary key
  /// (its placeholder name and bind name is the pk's declared name, appended
  /// last). Without that clause the statement would rewrite every row.
  static (String, List<String>) buildUpdateStatement(
    String table,
    List<TomColumnInformation> columns,
    TomColumnInformation primaryKey,
  ) {
    final assignments = [
      for (final c in columns) '${c.getQueryFieldName()} = :${c.declaredName}',
    ];
    final paramNames = [for (final c in columns) c.declaredName];
    final pkName = primaryKey.declaredName;
    paramNames.add(pkName);
    final sql = 'UPDATE $table SET ${assignments.join(',')}'
        ' WHERE ${primaryKey.getQueryFieldName()} = :$pkName';
    return (sql, paramNames);
  }

  TomPreparedStatement<T>? _saveInsertQuery;
  TomPreparedStatement<T>? _saveUpdateQuery;
  @override
  Future<T> save(T toSave) async {
    final persistentColumns = TomAnnotationAnalyzer.getPersistentColumns(T)!;
    final primaryKey =
        readPrimaryKey<K>(primaryKeyColumnInfo.getVariableValue(toSave));
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

    final insert = isUnsavedKey(primaryKey);

    // C-3 row-level write enforcement. An insert must carry a scope-field value
    // the principal is allowed (it cannot create a row outside its scope); an
    // update must target a row already within the principal's scope (it cannot
    // update a row it could not read). Both raise before any statement runs.
    if (insert) {
      _assertInsertWritable(toSave);
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
    // Read **once** and shared by the two features that need it — C-4 write
    // authorization, which compares against it to decide what changed, and the
    // CE-LG audit before-image, which records it. They ask for the same row for
    // different reasons; reading it twice would double the cost of every update
    // on an entity that uses both.
    final needsBaseline =
        !insert && (authColumns.isNotEmpty || _audits(TomAuditAction.update));
    final baseline = needsBaseline ? await _selectById(primaryKey as K) : null;

    if (authColumns.isNotEmpty) {
      Object? baselineOf(TomColumnInformation col) =>
          baseline == null ? null : col.getVariableValue(baseline);
      final decision = TomColumnAuthorization.decideWrites<TomColumnInformation>(
        columns: authColumns,
        gradeOf: (col) => col.column?.authKey,
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
      // Resolve the row's key: an auto-increment surrogate is assigned by the
      // database. Read it from the insert statement's *own* result
      // (`lastGeneratedId`) — authoritative and connection-correct. Only fall
      // back to a separate `SELECT LAST_INSERT_ID()` when the driver exposes no
      // generated key, since that follow-up query is session-scoped and returns
      // 0 if it runs on a different connection than the insert (bug §71). A
      // caller-supplied key is used as-is.
      // In the else branch `isUnsavedKey` is false, so the key is non-null.
      final K rowKey = isUnsavedKey(primaryKey)
          ? (_saveInsertQuery!.lastGeneratedId ?? await _lastInsertId()) as K
          : primaryKey as K;
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
      throw Exception(
        "Insert failed. When saving object with primary key $rowKey no "
        "record was created.",
      );
    } else {
      // UPDATE
      final (sql, paramNames) =
          buildUpdateStatement(dbTable.table, writable, primaryKeyColumnInfo);
      _saveUpdateQuery ??= await datasourceInfo.datasource.prepareStatement<T>(
        TomLiteralSelect([T], query: sql, parameters: paramNames),
      );
      final params = <String, Object?>{
        for (final col in writable) col.declaredName: dbValue(col),
        primaryKeyColumnInfo.declaredName: primaryKey,
      };
      await _saveUpdateQuery!.execute(params);
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
      throw Exception(
        "Update failed. When saving object with primary key $primaryKey the "
        "record could not be retrieved.",
      );
    }
  }

  /// Reads back the surrogate key the database assigned to the most recent
  /// `INSERT` on this repository's connection (`LAST_INSERT_ID()`), so [save]
  /// can return the freshly stored row.
  Future<int?> _lastInsertId() async {
    final rows = await datasourceInfo.datasource.executeQuery<TomCountResult>(
      'SELECT LAST_INSERT_ID() AS count',
      null,
      TomCountResult,
    );
    return rows.isEmpty ? null : rows.first.count;
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

  /// Extracts `:name` placeholder names from [sql] in textual order (repeats
  /// included), so a raw statement can be prepared and its values bound
  /// positionally in the order the `?` slots appear.
  ///
  /// Delegates to the shared, quote-aware [SqlPlaceholderScan.extractNames] so
  /// this extraction and [MariaDbDatasource.toPositionalStatement]'s positional
  /// rewrite tokenise identically — including skipping a `:name`-looking
  /// substring inside an inlined string literal (RCC6).
  static List<String> _extractPlaceholderNames(String sql) =>
      SqlPlaceholderScan.extractNames(sql);

  @override
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
  ]) async {
    TomSelect select = _qsc.compileQuerySentence(querySentence) as TomSelect;
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    final rows = await _runPrepared<T>(
      _scopedSelect(select, scope),
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
    TomDelete select = _qsc.compileQuerySentence(querySentence) as TomDelete;
    // C-3: filter the delete to the principal's scope, mirroring the scoped
    // reads — a query-based delete cannot reach out-of-scope rows.
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    await _runPrepared<T>(_scopedDelete(select, scope), effective);
    return 0;
  }

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomCount select = _qsc.compileQuerySentence(querySentence) as TomCount;
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    List<TomCountResult> result = await _runPrepared<TomCountResult>(
      _scopedCount(select, scope),
      effective,
      TomCountResult,
    );
    if (result.length != 1) {
      throw Exception(
        "Illegal count result. Must have exactly one result row, but had ${result.length}",
      );
    }
    return TomDbInt(result[0].count);
  }

  @override
  Future<Iterable<T>> findByQuery(
    TomSelect query,
    Map<String, Object?> params,
  ) async {
    final scope = await _resolveScope();
    final effective = <String, Object?>{...params, ...?scope?.parameters};
    return _maskRows(
      await _runPrepared<T>(_scopedSelect(query, scope), effective),
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
    await _runPrepared<T>(_scopedDelete(query, scope), effective);
    return 0;
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
    if (result.length != 1) {
      throw Exception(
        "Illegal count result. Must have exactly one result row, but had ${result.length}",
      );
    }
    return TomDbInt(result[0].count);
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
    return _runPrepared<TomGroupedRow>(
      _scopedGrouped(query, scope),
      effective,
    );
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
      keyOf: (column) => column.column?.authKey,
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

/// Annotation binding a [TomSqlDatasourceRepository] subclass to a named
/// [datasourceType] (e.g. `"mariadb"`), used by reflection-based repository
/// discovery to pick the right implementation for a data source.
@tomReflector
class TomRepositoryType {
  /// The data-source type this repository serves.
  final String datasourceType;

  /// Binds the repository to [datasourceType].
  const TomRepositoryType(this.datasourceType);
}
