/// A [TomSuppressionList] over a SQL data source.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'message.dart';
import 'suppression_list.dart';
import 'suppression_sql.dart';
import '../tenancy/tenant_data.dart';

/// A [TomSuppressionList] over a SQL data source: the list a deployment keeps,
/// since a list in memory is lost on restart and the next message goes to the
/// dead address again.
///
/// Built over a data source that is not routed per tenant: the list is the
/// deployment's ([TomSuppressionList]).
class TomSqlSuppressionList extends TomSuppressionList
    implements TomTenantData {
  /// Creates a list over [datasource] in [table], creating the table on first
  /// use when [createSchema] is set.
  TomSqlSuppressionList(
    TomDataSource datasource, {
    this.table = defaultSuppressionTable,
    this.createSchema = true,
  }) : datasource = TomFrameworkTable.systemOf(datasource);

  /// A list over the registered data source [datasourceName].
  factory TomSqlSuppressionList.named(
    String datasourceName, {
    String table = defaultSuppressionTable,
    bool createSchema = true,
  }) {
    final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'messaging.suppression.unknown_datasource',
        'The suppression list refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlSuppressionList(
      info.datasource,
      table: table,
      createSchema: createSchema,
    );
  }

  /// The data source the table lives in.
  final TomDataSource datasource;

  /// The table name.
  final String table;

  /// Whether the store creates its table on first use.
  final bool createSchema;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  late final TomFrameworkTable _rows = suppressionTable(table);

  static const Map<String, String> _writeColumns = {
    'channel': ':channel',
    'address': ':address',
    'suppressed_at': ':suppressedAt',
    'message_id': ':messageId',
    'remote_id': ':remoteId',
    'provider_code': ':providerCode',
    'detail': ':detail',
    'tenant': ':tenant',
  };

  /// Creates the table when [createSchema] is set, once per instance.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _rows.create(datasource);
    }
  });

  @override
  Future<void> suppress(TomSuppressedAddress entry) async {
    await ensureSchema();
    await _rows.replaceRow(datasource, _writeColumns, {
      'channel': entry.channel.name,
      'address': entry.address,
      'suppressedAt': sqlInstant(entry.suppressedAt),
      'messageId': entry.messageId,
      'remoteId': entry.remoteId,
      'providerCode': entry.providerCode,
      'detail': entry.detail,
      'tenant': entry.tenant,
    });
  }

  @override
  Future<bool> release(TomMessageChannel channel, String address) async {
    await ensureSchema();
    final key = TomSuppressionList.normalize(channel, address);
    // Read before the delete rather than trusting its count: MariaDB reports
    // changed rows, which is right for a delete, but the read is what the
    // answer means — "was it suppressed".
    final existed = await find(channel, key);
    if (existed == null) return false;
    await datasource.executeCommand(
      'DELETE FROM $table WHERE channel = :channel AND address = :address',
      {'channel': channel.name, 'address': key},
    );
    return true;
  }

  @override
  Future<TomSuppressedAddress?> find(
    TomMessageChannel channel,
    String address,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomSuppressionRow>(
      'SELECT ${_rows.columnList} FROM $table '
      'WHERE channel = :channel AND address = :address',
      {
        'channel': channel.name,
        'address': TomSuppressionList.normalize(channel, address),
      },
    );
    return rows.isEmpty ? null : _entryOf(rows.first);
  }

  @override
  Future<Set<String>> suppressedAmong(
    TomMessageChannel channel,
    Iterable<String> addresses,
  ) async {
    final given = addresses.toList(growable: false);
    if (given.isEmpty) return const {};
    await ensureSchema();
    final keys = {
      for (final address in given)
        TomSuppressionList.normalize(channel, address),
    }.toList(growable: false);
    final parameters = <String, Object?>{'channel': channel.name};
    final placeholders = <String>[];
    for (var i = 0; i < keys.length; i++) {
      parameters['a$i'] = keys[i];
      placeholders.add(':a$i');
    }
    final rows = await datasource.executeQuery<TomSuppressionRow>(
      'SELECT ${_rows.columnList} FROM $table WHERE channel = :channel '
      'AND address IN (${placeholders.join(', ')})',
      parameters,
    );
    final found = {for (final row in rows) row.address};
    return {
      for (final address in given)
        if (found.contains(TomSuppressionList.normalize(channel, address)))
          address,
    };
  }

  @override
  Future<List<TomSuppressedAddress>> all({TomMessageChannel? channel}) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomSuppressionRow>(
      'SELECT ${_rows.columnList} FROM $table'
      '${channel == null ? '' : ' WHERE channel = :channel'} '
      'ORDER BY suppressed_at DESC',
      {if (channel != null) 'channel': channel.name},
    );
    return rows.map(_entryOf).toList(growable: false);
  }

  /// Deletes the suppressions recorded for [tenant].
  @override
  Future<int> purgeTenant(String tenant) async {
    await ensureSchema();
    return (await datasource.executeCommand(
      'DELETE FROM $table WHERE tenant = :tenant',
      {'tenant': tenant},
    )).toInt();
  }

  /// Removes every entry. For tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  static TomSuppressedAddress _entryOf(TomSuppressionRow row) =>
      TomSuppressedAddress(
        channel: TomMessageChannel(row.channel),
        address: row.address,
        suppressedAt: parseSqlInstant(row.suppressedAt),
        messageId: row.messageId,
        remoteId: row.remoteId,
        providerCode: row.providerCode,
        detail: row.detail,
        tenant: row.tenant,
      );
}

/// One row of the suppression-list table, as the data source's mapper reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomSuppressionRow {
  /// The channel name.
  @TomDbColumn(columnName: "channel")
  String channel = "";

  /// The normalised address.
  @TomDbColumn(columnName: "address")
  String address = "";

  /// When it was suppressed.
  @TomDbColumn(columnName: "suppressed_at")
  String suppressedAt = "";

  /// The message whose failure suppressed it.
  @TomDbColumn(columnName: "message_id")
  String? messageId;

  /// The carrier's id of that message.
  @TomDbColumn(columnName: "remote_id")
  String? remoteId;

  /// The carrier's error code.
  @TomDbColumn(columnName: "provider_code")
  String? providerCode;

  /// The carrier's words or an operator's reason.
  @TomDbColumn(columnName: "detail")
  String? detail;

  /// The tenant of the failed message.
  @TomDbColumn(columnName: "tenant")
  String? tenant;
}
