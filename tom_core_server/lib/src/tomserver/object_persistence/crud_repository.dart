import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/queries.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';

import 'persistence_annotations.dart';
import 'query_sentence_compiler.dart';
import 'query_builder.dart';
import 'annotation_analyzer.dart';

/// Result holder for a `COUNT(*)` query: a single [count] field populated by
/// the row mapper. Reflectable so the data source can materialise it.
@tomReflector
class TomCountResult {
  /// The row count returned by the query.
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
    var persistenceInfo = TomAnnotationAnalyzer.analysePersistentType(
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

  TomPreparedStatement<T>? _deleteQuery;

  @override
  Future<void> delete(T entity) async {
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
    return;
  }

  TomPreparedStatement<T>? _deleteAllByIdQuery;
  @override
  Future<void> deleteAllById(Iterable<K> ids) async {
    _deleteAllByIdQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
delete by ${primaryKeyColumnInfo.getQueryFieldName()} IS IN ( :ids )
      ''')
          as TomDelete,
    );
    await _deleteAllByIdQuery!.execute({"ids": ids});
    return;
  }

  TomPreparedStatement<T>? _deleteByIdQuery;
  @override
  Future<int> deleteById(K id) async {
    _deleteByIdQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
delete by ${primaryKeyColumnInfo.getQueryFieldName()} = \$id
      ''')
          as TomDelete,
    );
    Map<String, Object?> params = {"id": id};
    await _deleteByIdQuery!.execute(params);
    return 1;
  }

  TomPreparedStatement<T>? _existsByIdsQuery;
  @override
  Future<bool> existsById(Iterable<K> ids) async {
    _existsByIdsQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
count by ${primaryKeyColumnInfo.getQueryFieldName()} IS IN ( :ids )
      ''')
          as TomCount,
    );
    Map<String, Object?> params = {"ids": ids};
    List<T> result = await _existsByIdsQuery!.execute(params);
    return result.length == ids.length;
  }

  TomPreparedStatement<T>? _findAllQuery;
  @override
  Future<List<T>> findAll() async {
    _findAllQuery ??= await datasourceInfo.datasource.prepareStatement(
      TomLiteralSelect(
        [T],
        query:
            '''
SELECT * FROM ${dbTable.table}
      ''',
      ),
    );
    Map<String, Object?> params = {};
    return await _findAllQuery!.execute(params);
  }

  TomPreparedStatement<T>? _findAllByIdQuery;
  @override
  Future<List<T>> findAllById(Iterable<K> ids) async {
    // Compile through the query-sentence compiler (like `existsById`) so the
    // `IS IN` list renders as a bound `IN (?)` placeholder rather than an
    // inline literal — no value is concatenated into the SQL. (The prior
    // hand-written SQL also embedded the invalid `IS IN` keyword, which the
    // compiler translates to a proper `IN (...)`.)
    _findAllByIdQuery ??= await datasourceInfo.datasource.prepareStatement(
      _qsc.compileQuerySentence('''
find by ${primaryKeyColumnInfo.getQueryFieldName()} IS IN ( :ids )
      ''')
          as TomSelect,
    );
    return await _findAllByIdQuery!.execute({"ids": ids});
  }

  TomPreparedStatement<T>? _findByIdQuery;
  @override
  Future<T?> findById(K id) async {
    var params = {"id": id};
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
    var result = await _findByIdQuery!.execute(params);
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
    Map<String, Object?> params = {};
    List<TomCountResult> result = await _countQuery!.execute(params);
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
    Object? dbValue(TomColumnInformation col) {
      final raw = col.getVariableValue(toSave);
      final convert = col.column?.toDbConverter;
      return convert != null ? convert(raw) : raw;
    }

    if (isUnsavedKey(primaryKey)) {
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
  static List<String> _extractPlaceholderNames(String sql) {
    return [
      for (final m in RegExp(r':([A-Za-z_][A-Za-z0-9_]*)').allMatches(sql))
        m.group(1)!,
    ];
  }

  @override
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
  ]) async {
    TomSelect select = _qsc.compileQuerySentence(querySentence) as TomSelect;
    return await _runPrepared<T>(select, params, resultType);
  }

  @override
  Future<int> deleteByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomDelete select = _qsc.compileQuerySentence(querySentence) as TomDelete;
    await _runPrepared<T>(select, params);
    return 0;
  }

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomCount select = _qsc.compileQuerySentence(querySentence) as TomCount;
    List<TomCountResult> result = await _runPrepared<TomCountResult>(
      select,
      params,
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
    return await _runPrepared<T>(query, params);
  }

  @override
  Future<int> deleteByQuery(
    TomDelete query,
    Map<String, Object?> params,
  ) async {
    await _runPrepared<T>(query, params);
    return 0;
  }

  @override
  Future<TomDbInt> countByQuery(
    TomCount query,
    Map<String, Object?> params,
  ) async {
    List<TomCountResult> result = await _runPrepared<TomCountResult>(
      query,
      params,
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
    return await _runPrepared<T>(query, params);
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
