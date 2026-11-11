/// Subqueries in a predicate: `EXISTS (…)`, `NOT EXISTS (…)` and
/// `<operand> IN (SELECT …)`.
///
/// A [TomSubquery] names the entity types it reads, a predicate over their
/// columns and, for `IN`, the one column it selects. A column renders as
/// `table.column`, so a subquery's predicate may name a column of the
/// enclosing query's table as well — that is a correlated subquery, the shape
/// an association filter compiles to. The one shape that cannot be written is
/// a subquery over the enclosing query's own table that correlates with it:
/// both would render as the same table name, and the tree has no aliases.
///
/// A [TomSoftDelete] entity a subquery reads contributes `<deleted> IS NULL`,
/// as it does to a repository read, unless [TomSoftDelete.includingDeleted]
/// is on.
///
/// A subquery reads tables of one classification — all tenant tables or all
/// system tables ([TomTenantTable]) — and the same as the query it is part of;
/// a repository refuses one that does not
/// (`annotation_analyzer.tenant_table.mixed`). A tenant table it reads
/// contributes `<tenant column> IN (:__tomtenant_0)`, bound to the enclosing
/// tenant-table query's tenant, so it never reaches another tenant's rows.
library;

import '../datasources/queries.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';
import 'annotation_analyzer.dart';
import 'crud_repository.dart';
import 'data_scope.dart';
import 'entity_lifecycle.dart';
import 'persistence_annotations.dart';
import 'query_builder.dart';
import '../datasources/table_qualification.dart';

/// `SELECT <projection> FROM <the tables of types> WHERE <where>` — a
/// subquery for [TomExists] and [TomInSubquery].
class TomSubquery {
  /// A subquery over [types] filtered by [where], selecting [projection] (a
  /// column, for `IN`) or `1` (for `EXISTS`) when it is `null`.
  ///
  /// Throws `annotation_analyzer.tenant_table.mixed` when [types] mix tenant
  /// tables and system tables.
  TomSubquery(this.types, {this.where, this.projection})
    : _info = [
        for (final type in types)
          TomAnnotationAnalyzer.analysePersistentType(type),
      ] {
    TomAnnotationAnalyzer.verifySameClassification(types, 'A subquery');
  }

  /// The subqueries [predicate] contains, nested ones included.
  static List<TomSubquery> within(TomOperator? predicate) {
    final found = <TomSubquery>[];
    void walk(TomOperator? node) {
      if (node == null) return;
      final subquery = switch (node) {
        TomExists(:final subquery) => subquery,
        TomInSubquery(:final subquery) => subquery,
        _ => null,
      };
      if (subquery != null) {
        found.add(subquery);
        walk(subquery.where);
        walk(subquery.projection);
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(predicate);
    return found;
  }

  /// The entity types read.
  final List<Type> types;

  /// The predicate over their rows, or `null` for all of them.
  final TomOperator<TomDbBool>? where;

  /// The selected column, or `null` for `1`.
  final TomOperator<Object?>? projection;

  final List<TomTypePersistenceInfo> _info;

  /// The `IS NULL` test of every [TomSoftDelete] entity read.
  List<SqlString> get _liveRows {
    if (TomSoftDelete.isIncludingDeleted) return const [];
    return [
      for (var i = 0; i < types.length; i++)
        if (TomSoftDelete.of(types[i]) case final softDelete?)
          '${_info[i].table.table}.'
              '${TomAnnotationAnalyzer.determineColumn(softDelete.field, [_info[i]]).getQueryFieldName()}'
              ' IS NULL',
    ];
  }

  /// `<tenant column> IN (:__tomtenant_0)` for every tenant table read.
  late final List<TomOperator<TomDbBool>> _tenantRows = [
    for (var i = 0; i < types.length; i++)
      if (TomAnnotationAnalyzer.findTenantTable(types[i]) case final table?)
        TomDataScope.inColumn(
          _SubqueryBuilder(),
          TomAnnotationAnalyzer.determineColumn(table.field, [_info[i]]),
          ['${TomSqlDatasourceRepository.tenantParameterPrefix}0'],
        ),
  ];

  /// The subquery's SQL.
  SqlString generate(TomStandardSqlDialect t) => t.subquery(
    projection?.generate(t) ?? '1',
    [
      for (final info in _info)
        TomSqlTableQualification.table(info.table.table),
    ],
    [
      ?where?.generate(t),
      ..._liveRows,
      for (final row in _tenantRows) row.generate(t),
    ],
  );

  /// Its parameters, in the order their placeholders appear.
  List<String> getParameters(TomStandardSqlDialect t) => [
    ...?projection?.getParameters(t),
    ...?where?.getParameters(t),
    for (final row in _tenantRows) ...row.getParameters(t),
  ];

  @override
  String toString() => 'TomSubquery($types, $where)';
}

/// `EXISTS (<subquery>)`.
///
/// Opaque to the walks over the enclosing tree: it has no [children] and
/// references no field of the enclosing query, because the columns inside it
/// are the subquery's. Its parameters are the enclosing statement's all the
/// same, and [getParameters] reports them in place.
class TomExists extends TomOperator<TomDbBool> {
  /// Tests that [subquery] answers at least one row.
  TomExists(this.subquery);

  /// The subquery.
  final TomSubquery subquery;

  @override
  SqlString generate(TomStandardSqlDialect t) => t.exists(subquery.generate(t));

  @override
  List<String> getParameters(TomStandardSqlDialect t) =>
      subquery.getParameters(t);

  @override
  Set<String> getFields(TomStandardSqlDialect t) => const {};

  @override
  String analyze(int l) => '${indent(l)} (TomExists $subquery)';
}

/// `<operand> IN (<subquery>)`; the subquery selects one column.
class TomInSubquery<T> extends TomOperator<TomDbBool> {
  /// Tests that [operand] is among the values [subquery] selects.
  TomInSubquery(this.operand, this.subquery);

  /// The value tested.
  final TomOperator<T> operand;

  /// The subquery; its projection is the column compared.
  final TomSubquery subquery;

  @override
  List<TomOperator> get children => [operand];

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.inSubquery(operand.generate(t), subquery.generate(t));

  @override
  List<String> getParameters(TomStandardSqlDialect t) => [
    ...operand.getParameters(t),
    ...subquery.getParameters(t),
  ];

  @override
  Set<String> getFields(TomStandardSqlDialect t) => operand.getFields(t);

  @override
  String analyze(int l) =>
      '${indent(l)} (TomInSubquery ${operand.analyze(l + 1)} $subquery)';
}

/// The builder a subquery's tenant predicate is made with.
class _SubqueryBuilder with TomQueryBuilder {}
