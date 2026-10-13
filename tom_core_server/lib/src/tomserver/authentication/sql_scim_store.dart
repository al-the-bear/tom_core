/// A [TomScimStore] whose resources are rows in a [TomDataSource] — the store
/// for a deployment with more than one node, or with provisioned users that
/// must outlive a restart.
///
/// Every resource is one row of the table `scimResourceTable` declares. The
/// database arbitrates the one race the store has: two identity-provider
/// requests creating the same user at once both pass the service's
/// uniqueness check, and the unique `(resource_type, name_key)` key lets only
/// one of them write.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'scim_resource.dart';
import 'scim_sql.dart';

/// A [TomScimStore] over the SCIM resource table in [datasource].
class TomSqlScimStore implements TomScimStore {
  /// Creates a store over [datasource].
  ///
  /// With [createSchema] left `true` the table is created on first use; set it
  /// `false` when the schema is owned by the migration module.
  TomSqlScimStore(
    this.datasource, {
    this.table = defaultScimResourceTable,
    this.createSchema = true,
  });

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed `scim.store.unknown_datasource` when
  /// no such data source is registered — a configuration error better caught
  /// at start-up than on the identity provider's first call.
  factory TomSqlScimStore.named(
    String datasourceName, {
    String table = defaultScimResourceTable,
    bool createSchema = true,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'scim.store.unknown_datasource',
        'The SCIM store refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlScimStore(
      info.datasource,
      table: table,
      createSchema: createSchema,
    );
  }

  /// The data source the table lives in.
  final TomDataSource datasource;

  /// The SCIM resource table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  late final TomFrameworkTable _resources = scimResourceTable(table);
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  /// Creates the table if it does not exist. Idempotent; called by every
  /// operation.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema)
      await datasource.executeCommand(_resources.createTableDdl);
  });

  @override
  Future<TomScimResource> create(
    TomScimResourceType type,
    Map<String, Object?> document,
  ) async {
    await ensureSchema();
    final now = sqlInstant(DateTime.now().toUtc());
    final rows = await datasource.executeQuery<TomScimResourceRow>(
      '${_resources.insert('INSERT', const {'resource_type': ':type', 'name_key': ':nameKey', 'external_id': ':externalId', 'document': ':document', 'created_at': ':now', 'last_modified': ':now', 'version': '1'})} RETURNING ${_resources.columnList}',
      _bind(type, document)..['now'] = now,
    );
    return _resourceOf(rows.single);
  }

  @override
  Future<TomScimResource?> read(TomScimResourceType type, String id) async {
    final key = int.tryParse(id);
    if (key == null) return null;
    await ensureSchema();
    final rows = await datasource.executeQuery<TomScimResourceRow>(
      'SELECT ${_resources.columnList} FROM $table '
      'WHERE id = :id AND resource_type = :type',
      {'id': key, 'type': type.resourceName},
    );
    return rows.isEmpty ? null : _resourceOf(rows.single);
  }

  @override
  Future<TomScimResource?> findByName(
    TomScimResourceType type,
    String name,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomScimResourceRow>(
      'SELECT ${_resources.columnList} FROM $table '
      'WHERE resource_type = :type AND name_key = :nameKey',
      {'type': type.resourceName, 'nameKey': name.toLowerCase()},
    );
    return rows.isEmpty ? null : _resourceOf(rows.single);
  }

  @override
  Future<List<TomScimResource>> list(TomScimResourceType type) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomScimResourceRow>(
      'SELECT ${_resources.columnList} FROM $table '
      'WHERE resource_type = :type ORDER BY id',
      {'type': type.resourceName},
    );
    return [for (final row in rows) _resourceOf(row)];
  }

  @override
  Future<TomScimResource?> replace(
    TomScimResourceType type,
    String id,
    Map<String, Object?> document,
  ) async {
    final key = int.tryParse(id);
    if (key == null) return null;
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'UPDATE $table SET name_key = :nameKey, external_id = :externalId, '
      'document = :document, last_modified = :now, version = version + 1 '
      'WHERE id = :id AND resource_type = :type',
      _bind(type, document)
        ..['id'] = key
        ..['now'] = sqlInstant(DateTime.now().toUtc()),
    );
    return affected == BigInt.zero ? null : read(type, id);
  }

  @override
  Future<bool> delete(TomScimResourceType type, String id) async {
    final key = int.tryParse(id);
    if (key == null) return false;
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'DELETE FROM $table WHERE id = :id AND resource_type = :type',
      {'id': key, 'type': type.resourceName},
    );
    return affected > BigInt.zero;
  }

  /// Empties the table — for provisioning and tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  Map<String, dynamic> _bind(
    TomScimResourceType type,
    Map<String, Object?> document,
  ) {
    final probe = TomScimResource(
      id: '',
      type: type,
      document: document,
      created: DateTime.now(),
      lastModified: DateTime.now(),
      version: 0,
    );
    return {
      'type': type.resourceName,
      'nameKey': probe.nameKey,
      'externalId': probe.externalId,
      'document': jsonEncode(document),
    };
  }

  static TomScimResource _resourceOf(TomScimResourceRow row) => TomScimResource(
    id: '${row.id}',
    type: TomScimResourceType.values.firstWhere(
      (type) => type.resourceName == row.resourceType,
    ),
    document: Map.unmodifiable(
      (jsonDecode(row.document) as Map).cast<String, Object?>(),
    ),
    created: parseSqlInstant(row.createdAt),
    lastModified: parseSqlInstant(row.lastModified),
    version: row.version,
  );
}

/// One row of the SCIM resource table, as the store reads it.
///
/// The instants are `String` fields for the reason `TomOAuthStateRow` gives:
/// the driver reads a `DATETIME` as a local `DateTime`, and the text converts
/// exactly with `parseSqlInstant`.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomScimResourceRow {
  /// The resource's SCIM id.
  @TomDbColumn(columnName: "id")
  int id = 0;

  /// `User` or `Group`.
  @TomDbColumn(columnName: "resource_type")
  String resourceType = "";

  /// The lower-cased name attribute.
  @TomDbColumn(columnName: "name_key")
  String nameKey = "";

  /// The identity provider's `externalId`, or `null`.
  @TomDbColumn(columnName: "external_id")
  String? externalId;

  /// The resource's JSON document.
  @TomDbColumn(columnName: "document")
  String document = "";

  /// When the resource was created, as the stored text.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// When it last changed, as the stored text.
  @TomDbColumn(columnName: "last_modified")
  String lastModified = "";

  /// The change counter.
  @TomDbColumn(columnName: "version")
  int version = 0;
}
