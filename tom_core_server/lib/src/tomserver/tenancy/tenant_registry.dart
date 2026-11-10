/// The tenant registry: the durable list of a deployment's tenants.
///
/// [TomTenancy] reads its tenants from a [TomTenantRegistry] at install, writes
/// every lifecycle change there before it changes routing, and refreshes from
/// it so every node of a cluster serves the same tenants. Configuration only
/// seeds the registry: a configured tenant the registry does not have yet is
/// written into it, and one that contradicts its row is reported
/// ([TomTenancy.registryConflicts]) — the row is what is used.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_datasource.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/persistence_annotations.dart';
import 'tenancy.dart';
import 'tenant_registry_sql.dart';

/// Where a tenant is in its lifecycle.
///
/// Only an [active] tenant is served; [suspended] is refused as
/// `tenancy.tenant.suspended` (403) and its queued work held, [provisioning]
/// and [migrating] as `tenancy.tenant.unavailable` (503), [migrationFailed]
/// as `tenancy.tenant.migration_failed` (503) and not routed, and a [removed]
/// tenant is unknown, its queued work cancelled.
enum TomTenantStatus {
  /// Its schema or database is being created.
  provisioning('provisioning'),

  /// Its type's migrations are being applied.
  migrating('migrating'),

  /// Served.
  active('active'),

  /// Kept, but refused.
  suspended('suspended'),

  /// A migration of it failed; refused until it is migrated again.
  migrationFailed('migration-failed'),

  /// Gone from the deployment; its data is left where it was.
  removed('removed');

  const TomTenantStatus(this.wireName);

  /// The name stored in the registry.
  final String wireName;

  /// The status stored as [raw]; throws `tenancy.registry.unknown_status`.
  static TomTenantStatus parse(String raw) {
    for (final value in values) {
      if (value.wireName == raw) return value;
    }
    throw TomTenancyException(
      'tenancy.registry.unknown_status',
      'The tenant registry holds an unknown status "$raw".',
      parameters: {'status': raw},
    );
  }
}

/// One tenant as the registry records it.
class TomTenantRecord {
  /// Creates a record.
  const TomTenantRecord({
    required this.id,
    this.type = TomTenant.defaultType,
    this.name,
    this.isolation,
    this.schema,
    this.datasources = const {},
    required this.status,
    this.statusDetail,
    this.migrated = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// The record of [tenant] in [status] at [at]: its data-source settings
  /// without a literal `password` (see [storableDatasources]).
  factory TomTenantRecord.of(
    TomTenant tenant,
    TomTenantStatus status,
    DateTime at,
  ) => TomTenantRecord(
    id: tenant.id,
    type: tenant.type,
    name: tenant.name,
    isolation: tenant.isolation,
    schema: tenant.schema,
    datasources: storableDatasources(tenant.datasources),
    status: status,
    createdAt: at,
    updatedAt: at,
  );

  /// The tenant's id.
  final String id;

  /// Its tenant type.
  final String type;

  /// A display name, or `null`.
  final String? name;

  /// Its isolation, or `null` for the deployment's default.
  final TomTenantIsolation? isolation;

  /// Under schema isolation, its schema, or `null` for `<database>_<id>`.
  final String? schema;

  /// Under database isolation, per routed data source name: a registered data
  /// source's name or the settings of one to open (never a literal password).
  final Map<String, Object> datasources;

  /// Where it is in its lifecycle.
  final TomTenantStatus status;

  /// What the last status change said — the error of a failed step — or `null`.
  final String? statusDetail;

  /// The migration version applied per target `<datasource>/<schema>`.
  final Map<String, int> migrated;

  /// When it was first recorded.
  final DateTime createdAt;

  /// When it was last changed.
  final DateTime updatedAt;

  /// This record with the given fields replaced.
  TomTenantRecord copyWith({
    TomTenantStatus? status,
    String? statusDetail,
    bool clearDetail = false,
    Map<String, int>? migrated,
    DateTime? updatedAt,
  }) => TomTenantRecord(
    id: id,
    type: type,
    name: name,
    isolation: isolation,
    schema: schema,
    datasources: datasources,
    status: status ?? this.status,
    statusDetail: clearDetail ? null : (statusDetail ?? this.statusDetail),
    migrated: migrated ?? this.migrated,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// This record, created at [createdAt] when one is given — the first
  /// recording of a tenant that is recorded again.
  TomTenantRecord copyWithCreated(DateTime? createdAt) => createdAt == null
      ? this
      : TomTenantRecord(
          id: id,
          type: type,
          name: name,
          isolation: isolation,
          schema: schema,
          datasources: datasources,
          status: status,
          statusDetail: statusDetail,
          migrated: migrated,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// The tenant this record describes. A data source whose settings the
  /// registry holds without their `password` takes it from [configured], the
  /// same tenant as the configuration names it, when there is one.
  TomTenant toTenant({TomTenant? configured}) {
    final merged = <String, Object>{};
    datasources.forEach((name, value) {
      final given = configured?.datasources[name];
      if (value is Map && given is Map && given.containsKey(passwordKey)) {
        merged[name] = <String, dynamic>{
          for (final e in value.entries) '${e.key}': e.value,
          passwordKey: given[passwordKey],
        };
      } else if (value is Map) {
        merged[name] = <String, dynamic>{
          for (final e in value.entries) '${e.key}': e.value,
        };
      } else {
        merged[name] = value;
      }
    });
    return TomTenant(
      id,
      type: type,
      name: name,
      isolation: isolation,
      schema: schema,
      datasources: merged,
    );
  }

  /// The setting a data source's password is under.
  static const String passwordKey = 'password';

  /// [datasources] as the registry stores them: a `password` that is not a
  /// `secret:` reference is left out, so no credential is written into a table
  /// — it stays with the configuration, and a cluster that adds tenants at run
  /// time names its passwords by `secret:` reference.
  static Map<String, Object> storableDatasources(
    Map<String, Object> datasources,
  ) => {
    for (final entry in datasources.entries)
      entry.key: entry.value is Map
          ? <String, dynamic>{
              for (final setting in (entry.value as Map).entries)
                if (setting.key != passwordKey ||
                    '${setting.value}'.startsWith('secret:'))
                  '${setting.key}': setting.value,
            }
          : entry.value,
  };

  /// The fields of [tenant] this record disagrees with, by name — `type`,
  /// `isolation`, `schema`, `datasources` — each with the configured and the
  /// recorded value. Empty when they agree.
  Map<String, (Object?, Object?)> differencesFrom(TomTenant tenant) {
    final configuredSources = jsonEncode(
      _sorted(storableDatasources(tenant.datasources)),
    );
    final recordedSources = jsonEncode(_sorted(datasources));
    return {
      if (tenant.type != type) 'type': (tenant.type, type),
      if (tenant.isolation != isolation)
        'isolation': (tenant.isolation?.name, isolation?.name),
      if (tenant.schema != schema) 'schema': (tenant.schema, schema),
      if (configuredSources != recordedSources)
        'datasources': (configuredSources, recordedSources),
    };
  }

  static Object? _sorted(Object? value) => value is Map
      ? {
          for (final key in (value.keys.map((k) => '$k').toList()..sort()))
            key: _sorted(value[key]),
        }
      : value;

  @override
  String toString() => 'TomTenantRecord($id, ${status.wireName})';
}

/// A configured tenant that its registry row contradicts: the row is used,
/// and the difference is reported here.
class TomTenantRegistryConflict {
  /// Creates the report.
  const TomTenantRegistryConflict(this.tenant, this.differences);

  /// The tenant's id.
  final String tenant;

  /// The fields that differ: name → (configured, recorded).
  final Map<String, (Object?, Object?)> differences;

  @override
  String toString() =>
      'TomTenantRegistryConflict($tenant: ${differences.keys.join(', ')})';
}

/// The durable list of the deployment's tenants.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `tenancy.registry.unknown_tenant` | A status or version change for a tenant the registry does not hold. |
/// | `tenancy.registry.unknown_status` | A stored status this code does not know. |
/// | `tenancy.registry.unknown_datasource` | The registry's data source is not registered. |
abstract class TomTenantRegistry {
  /// Creates a registry.
  const TomTenantRegistry();

  /// Every recorded tenant, removed ones included, by id.
  Future<List<TomTenantRecord>> all();

  /// The tenant [id], or `null`.
  Future<TomTenantRecord?> find(String id);

  /// Writes [record], replacing the tenant's row.
  Future<void> put(TomTenantRecord record);

  /// Deletes the tenant [id]'s row — what [TomTenancy.purgeTenant] does
  /// last. A no-op for a tenant the registry does not hold.
  Future<void> delete(String id);

  /// Sets the status of tenant [id] to [status], with [detail] (cleared when
  /// `null`), at [at]; answers the updated record.
  Future<TomTenantRecord> setStatus(
    String id,
    TomTenantStatus status, {
    String? detail,
    required DateTime at,
  }) async {
    final record = await find(id);
    if (record == null) throw unknownTenant(id);
    final updated = record.copyWith(
      status: status,
      statusDetail: detail,
      clearDetail: detail == null,
      updatedAt: at,
    );
    await put(updated);
    return updated;
  }

  /// Records that [version] is the highest migration of the tenant's type tree
  /// applied to data source [target] for tenant [id], at [at]; answers the
  /// updated record.
  Future<TomTenantRecord> setMigrated(
    String id,
    String target,
    int version, {
    required DateTime at,
  }) async {
    final record = await find(id);
    if (record == null) throw unknownTenant(id);
    final updated = record.copyWith(
      migrated: {...record.migrated, target: version},
      updatedAt: at,
    );
    await put(updated);
    return updated;
  }

  static final Expando<Map<String, Future<void>>> _held = Expando();

  /// Runs [body] holding the registry's migration lock of [target] — a
  /// migration target, `shared:<type>` or `tenant:<id>` — so two migrations
  /// of one target never run at once.
  ///
  /// This one serialises within the process; a registry shared by several
  /// processes ([TomSqlTenantRegistry]) holds a database session lock, which
  /// serialises them all and is released by the database when the holder
  /// dies.
  Future<R> withMigrationLock<R>(
    String target,
    Future<R> Function() body,
  ) async {
    final held = _held[this] ??= {};
    for (var busy = held[target]; busy != null; busy = held[target]) {
      await busy;
    }
    final done = Completer<void>();
    held[target] = done.future;
    try {
      return await body();
    } finally {
      // The entry is the future just awaited by waiters; dropping it is not
      // waiting on it.
      unawaited(held.remove(target));
      done.complete();
    }
  }

  /// The exception for a change to a tenant the registry does not hold.
  static TomTenancyException unknownTenant(String id) => TomTenancyException(
    'tenancy.registry.unknown_tenant',
    'The tenant registry holds no tenant "$id".',
    parameters: {'tenant': id},
  );
}

/// A registry in memory: a single process's tenants, lost on restart. The
/// registry of a [TomTenancy] built in code, and of tests.
class TomMemoryTenantRegistry extends TomTenantRegistry {
  /// Creates an empty registry.
  TomMemoryTenantRegistry();

  final Map<String, TomTenantRecord> _records = {};

  @override
  Future<List<TomTenantRecord>> all() async =>
      (_records.values.toList()..sort((a, b) => a.id.compareTo(b.id)));

  @override
  Future<TomTenantRecord?> find(String id) async => _records[id];

  @override
  Future<void> put(TomTenantRecord record) async =>
      _records[record.id] = record;

  @override
  Future<void> delete(String id) async => _records.remove(id);
}

/// The registry in a SQL table of the system schema — the base data source's
/// own schema, which is never routed: it is read and written through
/// [TomDataSourceInfo.getBaseDataSourceInfo], also inside a tenant.
class TomSqlTenantRegistry extends TomTenantRegistry {
  /// A registry in [table] of the data source [datasource].
  TomSqlTenantRegistry(
    TomDataSource datasource, {
    this.table = defaultTenantTable,
    this.createSchema = true,
  }) : _fixed = datasource,
       datasourceName = null;

  /// A registry in [table] of the registered data source [datasourceName],
  /// looked up — unrouted — when it is first used, so it can be built before
  /// the data sources are registered.
  TomSqlTenantRegistry.named(
    String this.datasourceName, {
    this.table = defaultTenantTable,
    this.createSchema = true,
  }) : _fixed = null;

  final TomDataSource? _fixed;

  /// The registered data source's name, or `null` for a fixed data source.
  final String? datasourceName;

  /// The table name.
  final String table;

  /// Whether the store creates its table on first use.
  final bool createSchema;

  final Expando<TomSchemaProvisioning> _schemas = Expando();

  late final TomFrameworkTable _rows = tenantTable(table);

  static const Map<String, String> _writeColumns = {
    'id': ':id',
    'type': ':type',
    'name': ':name',
    'isolation': ':isolation',
    'schema_name': ':schemaName',
    'datasources': ':datasources',
    'status': ':status',
    'status_detail': ':statusDetail',
    'migrated': ':migrated',
    'created_at': ':createdAt',
    'updated_at': ':updatedAt',
  };

  /// The data source the table lives in.
  TomDataSource get datasource {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName!);
    if (info == null) {
      throw TomTenancyException(
        'tenancy.registry.unknown_datasource',
        "The tenant registry's data source '$datasourceName' is not "
            'registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return info.datasource;
  }

  /// Creates the table when [createSchema] is set, once per data source.
  Future<TomDataSource> _ready() async {
    final ds = datasource;
    await (_schemas[ds] ??= TomSchemaProvisioning()).ensure(() async {
      if (createSchema) await _rows.create(ds);
    });
    return ds;
  }

  @override
  Future<List<TomTenantRecord>> all() async {
    final ds = await _ready();
    final rows = await ds.executeQuery<TomTenantRow>(
      'SELECT ${_rows.columnList} FROM $table ORDER BY id',
    );
    return rows.map(_recordOf).toList(growable: false);
  }

  @override
  Future<TomTenantRecord?> find(String id) async {
    final ds = await _ready();
    final rows = await ds.executeQuery<TomTenantRow>(
      'SELECT ${_rows.columnList} FROM $table WHERE id = :id',
      {'id': id},
    );
    return rows.isEmpty ? null : _recordOf(rows.first);
  }

  @override
  Future<void> put(TomTenantRecord record) async {
    final ds = await _ready();
    await _rows.replaceRow(ds, _writeColumns, {
      'id': record.id,
      'type': record.type,
      'name': record.name,
      'isolation': record.isolation?.name,
      'schemaName': record.schema,
      'datasources': record.datasources.isEmpty
          ? null
          : jsonEncode(record.datasources),
      'status': record.status.wireName,
      'statusDetail': record.statusDetail,
      'migrated': record.migrated.isEmpty ? null : jsonEncode(record.migrated),
      'createdAt': sqlInstant(record.createdAt),
      'updatedAt': sqlInstant(record.updatedAt),
    });
  }

  /// The session-lock name of [target]'s migration lock: at most 64
  /// characters, as MariaDB allows, the target hashed when it would not fit.
  static String migrationLockName(String target) {
    const prefix = 'tom_tenant_migration:';
    final named = '$prefix$target';
    return named.length <= 64
        ? named
        : '$prefix${sha256.convert(utf8.encode(target)).toString().substring(0, 64 - prefix.length)}';
  }

  /// Holds the database session lock [migrationLockName] of [target] on the
  /// registry's data source, so no other process — of any node sharing the
  /// registry — migrates [target] meanwhile; within this process, the base
  /// registry's lock.
  @override
  Future<R> withMigrationLock<R>(String target, Future<R> Function() body) =>
      super.withMigrationLock(target, () async {
        final ds = datasource;
        if (ds is! TomSqlDatasource) return body();
        return ds.withSessionLock(migrationLockName(target), body);
      });

  @override
  Future<void> delete(String id) async {
    final ds = await _ready();
    await ds.executeCommand('DELETE FROM $table WHERE id = :id', {'id': id});
  }

  /// Removes every row. For tests.
  Future<void> deleteAll() async {
    final ds = await _ready();
    await ds.executeCommand('DELETE FROM $table');
  }

  static TomTenantRecord _recordOf(TomTenantRow row) {
    final sources = row.datasources == null
        ? const <String, Object>{}
        : (jsonDecode(row.datasources!) as Map).map(
            (key, value) => MapEntry('$key', value as Object),
          );
    final migrated = row.migrated == null
        ? const <String, int>{}
        : (jsonDecode(row.migrated!) as Map).map(
            (key, value) => MapEntry('$key', (value as num).toInt()),
          );
    return TomTenantRecord(
      id: row.id,
      type: row.type,
      name: row.name,
      isolation: row.isolation == null
          ? null
          : TomTenantIsolation.parse(row.isolation!),
      schema: row.schemaName,
      datasources: sources,
      status: TomTenantStatus.parse(row.status),
      statusDetail: row.statusDetail,
      migrated: migrated,
      createdAt: parseSqlInstant(row.createdAt),
      updatedAt: parseSqlInstant(row.updatedAt),
    );
  }
}

/// One row of the tenant registry table, as the data source's mapper reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["id"],
)
class TomTenantRow {
  /// The tenant's id.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// Its tenant type.
  @TomDbColumn(columnName: "type")
  String type = "";

  /// Its display name.
  @TomDbColumn(columnName: "name")
  String? name;

  /// Its isolation.
  @TomDbColumn(columnName: "isolation")
  String? isolation;

  /// Its schema, under schema isolation.
  @TomDbColumn(columnName: "schema_name")
  String? schemaName;

  /// Its data sources, as JSON.
  @TomDbColumn(columnName: "datasources")
  String? datasources;

  /// Its status.
  @TomDbColumn(columnName: "status")
  String status = "";

  /// What the last status change said.
  @TomDbColumn(columnName: "status_detail")
  String? statusDetail;

  /// The migration versions applied, as JSON.
  @TomDbColumn(columnName: "migrated")
  String? migrated;

  /// When it was first recorded.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// When it was last changed.
  @TomDbColumn(columnName: "updated_at")
  String updatedAt = "";
}
