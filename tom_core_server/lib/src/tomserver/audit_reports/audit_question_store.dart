/// Where saved questions are kept: in memory, or in the `tom_audit_question`
/// table.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/persistence_annotations.dart';
import 'audit_question.dart';
import 'audit_question_sql.dart';

/// The saved questions.
abstract class TomAuditQuestionStore {
  /// Creates a store.
  const TomAuditQuestionStore();

  /// Stores [question], replacing the one with its id.
  Future<void> save(TomAuditQuestion question);

  /// The question with [id], or `null`.
  Future<TomAuditQuestion?> find(String id);

  /// The questions [owner] saved, by name.
  Future<List<TomAuditQuestion>> ownedBy(String owner);

  /// The questions whose next delivery is at or before [now], oldest due
  /// first, at most [limit].
  Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50});

  /// Removes the question with [id]; answers whether there was one.
  Future<bool> remove(String id);
}

/// [TomAuditQuestionStore] in memory.
class TomMemoryAuditQuestionStore extends TomAuditQuestionStore {
  final Map<String, TomAuditQuestion> _questions = {};

  /// Creates an empty store.
  TomMemoryAuditQuestionStore();

  @override
  Future<void> save(TomAuditQuestion question) async =>
      _questions[question.id] = question;

  @override
  Future<TomAuditQuestion?> find(String id) async => _questions[id];

  @override
  Future<List<TomAuditQuestion>> ownedBy(String owner) async =>
      _questions.values.where((q) => q.owner == owner).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50}) async {
    final due = [
      for (final q in _questions.values)
        if (q.nextDeliveryAt != null && !q.nextDeliveryAt!.isAfter(now)) q,
    ]..sort((a, b) => a.nextDeliveryAt!.compareTo(b.nextDeliveryAt!));
    return due.take(limit).toList();
  }

  @override
  Future<bool> remove(String id) async => _questions.remove(id) != null;
}

/// [TomAuditQuestionStore] over the `tom_audit_question` table.
class TomSqlAuditQuestionStore extends TomAuditQuestionStore {
  /// The data source holding [table].
  final TomDataSource datasource;

  /// The table.
  final String table;

  /// Whether the store creates its table when it is missing; `false` hands
  /// the schema to the migration chain.
  final bool createSchema;

  final DateTime Function() _clock;
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();
  late final TomFrameworkTable _rows = auditQuestionTable(table);

  static const Map<String, String> _writeColumns = {
    'id': ':id',
    'owner': ':owner',
    'name': ':name',
    'definition': ':definition',
    'schedule': ':schedule',
    'next_delivery_at': ':nextDeliveryAt',
    'last_delivered_at': ':lastDeliveredAt',
    'updated_at': ':updatedAt',
  };

  /// Keeps the questions in [table] of [datasource].
  TomSqlAuditQuestionStore(
    TomDataSource datasource, {
    this.table = defaultAuditQuestionTable,
    this.createSchema = true,
    DateTime Function()? clock,
  }) : datasource = TomFrameworkTable.systemOf(datasource),
       _clock = clock ?? DateTime.now;

  /// A store over the registered data source [datasourceName]; refuses
  /// (`audit_reports.store.unknown_datasource`) a name the registry does not
  /// hold.
  factory TomSqlAuditQuestionStore.named(
    String datasourceName, {
    String table = defaultAuditQuestionTable,
    bool createSchema = true,
    DateTime Function()? clock,
  }) => TomSqlAuditQuestionStore(
    tomAuditReportsDatasource(datasourceName, 'store'),
    table: table,
    createSchema: createSchema,
    clock: clock,
  );

  /// Creates the table when [createSchema] is set; once per store.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) await _rows.create(datasource);
  });

  @override
  Future<void> save(TomAuditQuestion question) async {
    await ensureSchema();
    await _rows.replaceRow(datasource, _writeColumns, {
      'id': question.id,
      'owner': question.owner,
      'name': question.name,
      'definition': jsonEncode(question.definitionJson()),
      'schedule': question.schedule,
      'nextDeliveryAt': question.nextDeliveryAt == null
          ? null
          : sqlInstant(question.nextDeliveryAt!),
      'lastDeliveredAt': question.lastDeliveredAt == null
          ? null
          : sqlInstant(question.lastDeliveredAt!),
      'updatedAt': sqlInstant(_clock()),
    });
  }

  @override
  Future<TomAuditQuestion?> find(String id) async {
    final rows = await _select('WHERE id = :id', {'id': id});
    return rows.isEmpty ? null : rows.single;
  }

  @override
  Future<List<TomAuditQuestion>> ownedBy(String owner) =>
      _select('WHERE owner = :owner ORDER BY name, id', {'owner': owner});

  @override
  Future<List<TomAuditQuestion>> due(DateTime now, {int limit = 50}) => _select(
    'WHERE next_delivery_at IS NOT NULL AND next_delivery_at <= :now '
    'ORDER BY next_delivery_at, id LIMIT $limit',
    {'now': sqlInstant(now)},
  );

  @override
  Future<bool> remove(String id) async {
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $table WHERE id = :id',
      {'id': id},
    );
    return removed > BigInt.zero;
  }

  Future<List<TomAuditQuestion>> _select(
    String suffix,
    Map<String, Object?> params,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomAuditQuestionRow>(
      'SELECT ${_rows.columnList} FROM $table $suffix',
      params,
    );
    return [
      for (final row in rows)
        () {
          final definition = TomAuditQuestion.readDefinition(
            (jsonDecode(row.definition) as Map).cast<String, Object?>(),
          );
          return TomAuditQuestion(
            id: row.id,
            name: row.name,
            owner: row.owner,
            filter: definition.filter,
            schedule: row.schedule,
            recipients: definition.recipients,
            format: definition.format,
            nextDeliveryAt: _instant(row.nextDeliveryAt),
            lastDeliveredAt: _instant(row.lastDeliveredAt),
          );
        }(),
    ];
  }

  static DateTime? _instant(String? value) =>
      value == null || value.isEmpty ? null : parseSqlInstant(value);
}

/// A row of the saved-question table.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditQuestionRow {
  /// `id`.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// `owner`.
  @TomDbColumn(columnName: "owner")
  String owner = "";

  /// `name`.
  @TomDbColumn(columnName: "name")
  String name = "";

  /// `definition`.
  @TomDbColumn(columnName: "definition")
  String definition = "";

  /// `schedule`.
  @TomDbColumn(columnName: "schedule")
  String? schedule;

  /// `next_delivery_at`.
  @TomDbColumn(columnName: "next_delivery_at")
  String? nextDeliveryAt;

  /// `last_delivered_at`.
  @TomDbColumn(columnName: "last_delivered_at")
  String? lastDeliveredAt;

  /// `updated_at` — when the question was last saved, as stored text.
  @TomDbColumn(columnName: "updated_at")
  String updatedAt = "";
}
