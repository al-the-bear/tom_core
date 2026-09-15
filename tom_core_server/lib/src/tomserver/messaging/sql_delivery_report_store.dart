/// The delivery-correlation index, in a relational table.
///
/// The durable half of [TomDeliveryReportStore]. The memory implementation is
/// right for a test and for a single process that only cares while it runs;
/// this one is what a deployment needs, because a carrier's callback arrives
/// minutes or hours after the send and a restart in between must not lose the
/// only thing that ties the two together.
///
/// One row per carrier id, addressed by it. Every statement is derived from the
/// single [deliveryReportTable] declaration, so the DDL this store issues, the
/// columns its statements name and the model the convergence guard compares
/// cannot come apart.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'delivery_report.dart';
import 'delivery_report_sql.dart';
import 'message.dart';

/// A [TomDeliveryReportStore] over a relational table.
class TomSqlDeliveryReportStore extends TomDeliveryReportStore {
  /// Creates a store over [datasource].
  ///
  /// [table] names the correlation table. With [createSchema] left `true` the
  /// table is created on first use, which is what a test or a self-provisioning
  /// deployment wants; set it `false` when the schema is owned by the migration
  /// module and the application's database user may not run DDL.
  TomSqlDeliveryReportStore(
    this.datasource, {
    this.table = defaultDeliveryReportTable,
    this.createSchema = true,
  });

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed
  /// `messaging.delivery_report.unknown_datasource` when no such data source is
  /// registered — a configuration error far better caught at start-up than on
  /// the first callback. The base class rather than a subtype is deliberate;
  /// [TomServerException] says why.
  factory TomSqlDeliveryReportStore.named(
    String datasourceName, {
    String table = defaultDeliveryReportTable,
    bool createSchema = true,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'messaging.delivery_report.unknown_datasource',
        'The delivery-report store refers to a data source that is not '
            'registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlDeliveryReportStore(
      info.datasource,
      table: table,
      createSchema: createSchema,
    );
  }

  /// The data source the correlation table lives in.
  final TomDataSource datasource;

  /// The correlation table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  bool _schemaReady = false;

  /// The table's single column declaration — see `delivery_report_sql.dart`.
  late final TomFrameworkTable _rows = deliveryReportTable(table);

  /// The columns [remember] writes, and the bind each takes.
  ///
  /// Keyed by column name rather than given as a list, so adding a column
  /// cannot shift every value one place along — a failure that would
  /// type-check.
  static const Map<String, String> _writeColumns = {
    'remote_id': ':remoteId',
    'message_id': ':messageId',
    'channel': ':channel',
    'sent_at': ':sentAt',
    'state': ':state',
    'reported_at': ':reportedAt',
    'detail': ':detail',
  };

  /// Creates the correlation table if it does not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic.
  Future<void> ensureSchema() async {
    if (_schemaReady) return;
    if (createSchema) {
      await datasource.executeCommand(_rows.createTableDdl);
    }
    _schemaReady = true;
  }

  @override
  Future<void> remember(TomDeliveryCorrelation correlation) async {
    await ensureSchema();
    // REPLACE rather than INSERT, unlike the OAuth state store. A carrier id is
    // the carrier's to mint, and re-sending a message that was already accepted
    // once — the at-least-once delivery the outbox states plainly — can hand
    // back an id already on file. The later send is the one worth keeping, and
    // an insert that failed would turn a documented duplicate into an error.
    await datasource.executeCommand(
      _rows.insert('REPLACE', _writeColumns),
      _bindOf(correlation),
    );
  }

  @override
  Future<TomDeliveryCorrelation?> messageOf(String remoteId) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomDeliveryReportRow>(
      'SELECT ${_rows.columnList} FROM $table WHERE remote_id = :remoteId',
      {'remoteId': remoteId},
    );
    return rows.isEmpty ? null : _correlationOf(rows.first);
  }

  @override
  Future<TomDeliveryCorrelation?> record(TomDeliveryReport report) async {
    await ensureSchema();
    // The update carries the `WHERE` rather than a read-then-write, so a report
    // for an id this deployment never sent changes nothing — no window in which
    // two callbacks for one id could both read "not yet reported".
    await datasource.executeCommand(
      'UPDATE $table SET state = :state, reported_at = :reportedAt, '
      'detail = :detail WHERE remote_id = :remoteId',
      {
        'state': report.state.name,
        'reportedAt': sqlInstant(report.at),
        'detail': report.detail,
        'remoteId': report.remoteId,
      },
    );
    // The row is read back rather than the affected count being believed:
    // MariaDB reports *changed* rows, not matched ones, so a carrier repeating
    // a report it already sent affects nothing and is indistinguishable by that
    // count from an id nobody remembered. The read tells them apart, and it is
    // the value the caller wanted anyway.
    return messageOf(report.remoteId);
  }

  @override
  Future<int> purgeSentBefore(DateTime before) async {
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'DELETE FROM $table WHERE sent_at < :before',
      {'before': sqlInstant(before)},
    );
    return affected.toInt();
  }

  /// Empties the table.
  ///
  /// For provisioning and for tests that need a known-empty state — the same
  /// reason `TomSqlOAuthStateStore.deleteAll` exists.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  Map<String, Object?> _bindOf(TomDeliveryCorrelation row) => {
    'remoteId': row.remoteId,
    'messageId': row.messageId,
    'channel': row.channel.name,
    'sentAt': sqlInstant(row.sentAt),
    'state': row.state?.name,
    'reportedAt': row.reportedAt == null ? null : sqlInstant(row.reportedAt!),
    'detail': row.detail,
  };

  static TomDeliveryCorrelation _correlationOf(TomDeliveryReportRow row) =>
      TomDeliveryCorrelation(
        remoteId: row.remoteId,
        messageId: row.messageId,
        channel: TomMessageChannel(row.channel),
        sentAt: parseSqlInstant(row.sentAt),
        state: row.state == null ? null : TomDeliveryReport.stateOf(row.state),
        reportedAt: row.reportedAt == null
            ? null
            : parseSqlInstant(row.reportedAt!),
        detail: row.detail,
      );
}

/// One row of the correlation table, as the driver hands it back.
///
/// Instants are mapped as text and parsed here rather than as `DateTime`,
/// matching every other framework store: the driver's own coercion differs by
/// dialect, and `parseSqlInstant` is the single place the framework decides what
/// a stored instant means.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomDeliveryReportRow {
  /// The carrier's identifier for the message.
  @TomDbColumn(columnName: "remote_id")
  String remoteId = "";

  /// The message the carrier's id stands for.
  @TomDbColumn(columnName: "message_id")
  String messageId = "";

  /// The channel that delivered it.
  @TomDbColumn(columnName: "channel")
  String channel = "";

  /// When the transport accepted it, as the stored `DATETIME(6)` text.
  @TomDbColumn(columnName: "sent_at")
  String sentAt = "";

  /// The last state reported, or `null` while none has arrived.
  @TomDbColumn(columnName: "state")
  String? state;

  /// When that report was recorded, as the stored text.
  @TomDbColumn(columnName: "reported_at")
  String? reportedAt;

  /// The carrier's own words from that report.
  @TomDbColumn(columnName: "detail")
  String? detail;
}
