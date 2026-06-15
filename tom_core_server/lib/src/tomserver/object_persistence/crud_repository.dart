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

  @override
  Future<void> deleteAllById(Iterable<K> ids) async {
    TomQuery deleteAllByIdQuery = _qsc.compileQuerySentence('''
delete by ${primaryKeyColumnInfo.getQueryFieldName()} IS IN ( :ids )
      ''');
    Map<String, Object?> params = {"ids": ids};
    await datasourceInfo.datasource.executeCommand(
      deleteAllByIdQuery.generateQuery(sqlDialect),
      params,
    );
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
    await _deleteQuery!.execute(params);
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

  @override
  Future<List<T>> findAllById(Iterable<K> ids) async {
    var query = TomLiteralSelect(
      [T],
      query:
          '''
SELECT * FROM ${dbTable.table} WHERE ${primaryKeyColumnInfo.field} IS IN ( :ids )
      ''',
    );
    Map<String, Object?> params = {"ids": ids};
    return await datasourceInfo.datasource.executeQuery<T>(
      query.generateQuery(sqlDialect),
      params,
    );
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

  TomPreparedStatement<T>? _saveInsertQuery;
  TomPreparedStatement<T>? _saveUpdateQuery;
  @override
  Future<T> save(T toSave) async {
    List<TomColumnInformation> persistentColumns =
        TomAnnotationAnalyzer.getPersistentColumns(T)!;
    var primaryKey = primaryKeyColumnInfo.getVariableValue(toSave) as K;
    if (primaryKey == null) {
      // INSERT
      List<String> fields = [];
      List<Object?> values = [];
      List<String> paramList = [];
      for (var col in persistentColumns) {
        if (col.column != null && col.column!.isReadOnly) {
          continue;
        }
        fields.add(col.getQueryFieldName());
        if (col.column!.toDbConverter != null) {
          values.add(col.column!.toDbConverter!(col.getVariableValue(toSave)));
        } else {
          values.add(col.getVariableValue(toSave));
        }
        paramList.add(":${col.declaredName}");
      }
      _saveInsertQuery ??= await datasourceInfo.datasource.prepareStatement<T>(
        TomLiteralSelect(
          [T],
          query:
              '''
      INSERT INTO ${dbTable.table} ( ${fields.join(',')} ) VALUES ( ${paramList.join(',')}
''',
        ),
      );
      var params = <String, Object?>{};
      for (int i = 0; i < values.length; i++) {
        params[paramList[i]] = values[i];
      }
      await _saveInsertQuery!.execute(params);
      var newRow = await findById(primaryKey);
      if (newRow != null) {
        return newRow;
      } else {
        throw Exception(
          "Insert failed. When saving object with primary key $primaryKey no record was created.",
        );
      }
    } else {
      // UPDATE
      List<String> fields = [];
      List<Object?> values = [];
      List<String> paramList = [];
      for (var col in persistentColumns) {
        if (col.column != null && col.column!.isReadOnly) {
          continue;
        }
        fields.add("${col.field} = :${col.declaredName}");
        values.add(col.getVariableValue(toSave));
        paramList.add(":${col.declaredName}");
      }
      _saveUpdateQuery ??= await datasourceInfo.datasource.prepareStatement<T>(
        TomLiteralSelect(
          [T],
          query:
              '''
      UPDATE ${dbTable.table} SET ${fields.join(',')}
''',
        ),
      );
      var params = <String, Object?>{};
      for (int i = 0; i < values.length; i++) {
        params[paramList[i]] = values[i];
      }
      await _saveUpdateQuery!.execute(params);
      var newRow = await findById(primaryKey);
      if (newRow != null) {
        return newRow;
      } else {
        throw Exception(
          "Update failed. When saving object with primary key $primaryKey the record could not be retrieved.",
        );
      }
    }
  }

  @override
  Future<Iterable<T>> saveAll(Iterable<T> entities) async {
    List<T> result = [];
    for (var entity in entities) {
      result.add(await save(entity));
    }
    return result;
  }

  @override
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> params, [
    Type? resultType,
  ]) async {
    TomSelect select = _qsc.compileQuerySentence(querySentence) as TomSelect;
    return await datasourceInfo.datasource.executeQuery<T>(
      select.generateQuery(sqlDialect),
      params,
      resultType,
    );
  }

  @override
  Future<int> deleteByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomDelete select = _qsc.compileQuerySentence(querySentence) as TomDelete;
    await datasourceInfo.datasource.executeQuery<T>(
      select.generateQuery(sqlDialect),
      params,
    );
    return 0;
  }

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    TomSelect select = _qsc.compileQuerySentence(querySentence) as TomSelect;
    List<TomCountResult> result = await datasourceInfo.datasource
        .executeQuery<TomCountResult>(select.generateQuery(sqlDialect), params);
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
    return await datasourceInfo.datasource.executeQuery<T>(
      query.generateQuery(sqlDialect),
      params,
    );
  }

  @override
  Future<int> deleteByQuery(
    TomDelete query,
    Map<String, Object?> params,
  ) async {
    await datasourceInfo.datasource.executeQuery<T>(
      query.generateQuery(sqlDialect),
      params,
    );
    return 0;
  }

  @override
  Future<TomDbInt> countByQuery(
    TomCount query,
    Map<String, Object?> params,
  ) async {
    List<TomCountResult> result = await datasourceInfo.datasource
        .executeQuery<TomCountResult>(query.generateQuery(sqlDialect), params);
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
    return datasourceInfo.datasource.executeQuery<T>(dbQuery, params);
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
