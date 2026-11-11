/// One tenant's rows in the tenant tables of one data source: which tables
/// hold them, how many there are, and how they are copied, exported and
/// imported — what moving, backing up and restoring a tenant are built on.
library;

import '../datasources/postgres_sql_dialect.dart';
import '../datasources/sql_datasource.dart';
import 'tenancy.dart';

/// A column of a tenant table, as the database describes it.
class TomTenantColumn {
  /// The column [name] of the database type [type].
  const TomTenantColumn(this.name, this.type);

  /// The column name.
  final String name;

  /// The database type: `data_type` on MariaDB, `udt_name` on PostgreSQL.
  final String type;

  /// Whether the column holds bytes, carried as hexadecimal text.
  bool get isBinary => const {
    'blob',
    'tinyblob',
    'mediumblob',
    'longblob',
    'binary',
    'varbinary',
    'bytea',
  }.contains(type.toLowerCase());

  /// Whether the column holds a date, a time or an instant.
  bool get isTemporal {
    final lower = type.toLowerCase();
    return lower.contains('date') ||
        lower.contains('time') ||
        lower.startsWith('timestamp');
  }

  /// Whether the column is a PostgreSQL `boolean`.
  bool get isBoolean => type.toLowerCase() == 'bool';
}

/// One tenant table of a [TomTenantBackup]: its columns and the tenant's
/// rows, every value as text (bytes in hexadecimal), `null` for SQL `NULL`.
class TomTenantTableBackup {
  /// The rows of [table] on the data source [datasource].
  const TomTenantTableBackup({
    required this.datasource,
    required this.table,
    required this.tenantColumn,
    required this.columns,
    required this.rows,
  });

  /// Reads one from [json], the form [toJson] writes.
  factory TomTenantTableBackup.fromJson(Map<String, Object?> json) =>
      TomTenantTableBackup(
        datasource: json['datasource']! as String,
        table: json['table']! as String,
        tenantColumn: json['tenantColumn']! as String,
        columns: [
          for (final c in json['columns']! as List)
            TomTenantColumn(
              (c as Map)['name']! as String,
              c['type']! as String,
            ),
        ],
        rows: [
          for (final row in json['rows']! as List)
            [for (final value in row as List) value as String?],
        ],
      );

  /// The routed data source name, e.g. `main`.
  final String datasource;

  /// The table name.
  final String table;

  /// The column naming each row's tenant.
  final String tenantColumn;

  /// The columns, in the order of each row's values.
  final List<TomTenantColumn> columns;

  /// The rows.
  final List<List<String?>> rows;

  /// This table as JSON-native values.
  Map<String, Object?> toJson() => {
    'datasource': datasource,
    'table': table,
    'tenantColumn': tenantColumn,
    'columns': [
      for (final c in columns) {'name': c.name, 'type': c.type},
    ],
    'rows': rows,
  };
}

/// A tenant's rows in its tenant tables — a backup `TomTenancy.exportTenant`
/// writes and `TomTenancy.importTenant` restores, also into another schema,
/// database or server. The tenant's system-table rows (its queued jobs, its
/// audit entries) are not in it: they stay where they are.
class TomTenantBackup {
  /// The backup of [tenant], of type [type] and isolation [isolation], taken
  /// at [takenAt].
  const TomTenantBackup({
    required this.tenant,
    required this.type,
    required this.isolation,
    required this.takenAt,
    required this.tables,
  });

  /// Reads one from [json], the form [toJson] writes; refuses
  /// (`tenancy.backup.invalid`) a document that is not one.
  factory TomTenantBackup.fromJson(Map<String, Object?> json) {
    if (json['format'] != formatName) {
      throw TomTenancyException(
        'tenancy.backup.invalid',
        'The document is not a tenant backup (format ${json['format']}).',
        parameters: {'format': '${json['format']}'},
      );
    }
    return TomTenantBackup(
      tenant: json['tenant']! as String,
      type: json['type']! as String,
      isolation: json['isolation']! as String,
      takenAt: DateTime.parse(json['takenAt']! as String),
      tables: [
        for (final t in json['tables']! as List)
          TomTenantTableBackup.fromJson((t as Map).cast<String, Object?>()),
      ],
    );
  }

  /// The `format` a backup document names.
  static const String formatName = 'tom-tenant-backup/1';

  /// The tenant the rows are of.
  final String tenant;

  /// Its type when the backup was taken.
  final String type;

  /// Its isolation when the backup was taken.
  final String isolation;

  /// When the backup was taken.
  final DateTime takenAt;

  /// Its tables, with the tenant's rows.
  final List<TomTenantTableBackup> tables;

  /// The rows, by `<datasource>/<table>`.
  Map<String, int> get counts => {
    for (final t in tables) '${t.datasource}/${t.table}': t.rows.length,
  };

  /// This backup as JSON-native values.
  Map<String, Object?> toJson() => {
    'format': formatName,
    'tenant': tenant,
    'type': type,
    'isolation': isolation,
    'takenAt': takenAt.toUtc().toIso8601String(),
    'tables': [for (final t in tables) t.toJson()],
  };
}

/// The SQL that reads, counts, copies, exports and imports one tenant's rows
/// of one table — every statement filtered by the table's tenant column.
abstract final class TomTenantTables {
  /// The tenant tables of the data source [name] that [datasource] holds, by
  /// table name, each with the column naming its rows' tenant: the
  /// application's (`@TomTenantTable`) and the framework's.
  static Future<Map<String, String>> present(
    TomSqlDatasource datasource,
    String name,
  ) async {
    final candidates = TomTenancy.tenantTableColumns(name);
    final present = <String, String>{};
    for (final MapEntry(key: table, value: column) in candidates.entries) {
      if (await exists(datasource, table)) present[table] = column;
    }
    return present;
  }

  /// Whether [datasource]'s schema holds [table].
  static Future<bool> exists(TomSqlDatasource datasource, String table) async {
    final result = await datasource.executeResult(
      'SELECT COUNT(*) AS n FROM information_schema.tables '
      'WHERE table_schema = ${datasource.sqlDialect.currentSchema} '
      'AND LOWER(table_name) = :table',
      {'table': table.toLowerCase()},
    );
    return int.parse(result.rows.single.text('n')!) > 0;
  }

  /// The columns of [table] in [datasource]'s schema, in their order.
  static Future<List<TomTenantColumn>> columns(
    TomSqlDatasource datasource,
    String table,
  ) async {
    final type = datasource.sqlDialect is PostgresSqlDialect
        ? 'udt_name'
        : 'data_type';
    final result = await datasource.executeResult(
      'SELECT column_name AS name, $type AS type '
      'FROM information_schema.columns '
      'WHERE table_schema = ${datasource.sqlDialect.currentSchema} '
      'AND LOWER(table_name) = :table ORDER BY ordinal_position',
      {'table': table.toLowerCase()},
    );
    return [
      for (final row in result.rows)
        TomTenantColumn(row.text('name')!, row.text('type')!),
    ];
  }

  /// How many of [table]'s rows in [datasource] are [tenant]'s.
  static Future<int> count(
    TomSqlDatasource datasource,
    String table,
    String column,
    String tenant,
  ) async {
    final quoted = datasource.sqlDialect.quoteIdentifier(column);
    final result = await datasource.executeResult(
      'SELECT COUNT(*) AS n FROM $table WHERE $quoted = :tenant',
      {'tenant': tenant},
    );
    return int.parse(result.rows.single.text('n')!);
  }

  /// Copies [tenant]'s rows of [table] from [source] into [target] with one
  /// `INSERT … SELECT` on [target]'s connection, the source table named
  /// qualified — [target] must reach it ([TomSqlDatasource.canQualify]).
  /// The values travel as the database holds them. Answers the rows copied.
  static Future<int> copyQualified({
    required TomSqlDatasource source,
    required TomSqlDatasource target,
    required String table,
    required String column,
    required List<TomTenantColumn> columns,
    required String tenant,
  }) async {
    final dialect = target.sqlDialect;
    final list = [
      for (final c in columns) dialect.quoteIdentifier(c.name),
    ].join(', ');
    final copied = await target.executeCommand(
      'INSERT INTO $table ($list) SELECT $list FROM ${source.qualify(table)} '
      'WHERE ${dialect.quoteIdentifier(column)} = :tenant',
      {'tenant': tenant},
    );
    return copied.toInt();
  }

  /// [tenant]'s rows of [table] in [datasource] as a backup of the data
  /// source [name]: dates and instants as the driver's temporal text, bytes in
  /// hexadecimal, `null` for SQL `NULL`.
  static Future<TomTenantTableBackup> export(
    TomSqlDatasource datasource,
    String name,
    String table,
    String column,
    String tenant,
  ) async {
    final dialect = datasource.sqlDialect;
    final postgres = dialect is PostgresSqlDialect;
    final described = await columns(datasource, table);
    final select = [
      for (final (i, c) in described.indexed)
        '${c.isBinary ? (postgres ? "encode(${dialect.quoteIdentifier(c.name)}, 'hex')" : 'HEX(${dialect.quoteIdentifier(c.name)})') : dialect.quoteIdentifier(c.name)} AS c$i',
    ].join(', ');
    final result = await datasource.executeResult(
      'SELECT $select FROM $table '
      'WHERE ${dialect.quoteIdentifier(column)} = :tenant',
      {'tenant': tenant},
    );
    return TomTenantTableBackup(
      datasource: name,
      table: table,
      tenantColumn: column,
      columns: described,
      rows: [
        for (final row in result.rows)
          [
            for (final (i, c) in described.indexed)
              c.isTemporal
                  ? row.temporalText('c$i')
                  : c.isBoolean
                  ? row.boolean('c$i')?.toString()
                  : row.text('c$i'),
          ],
      ],
    );
  }

  /// Writes [backup]'s rows into [datasource]'s table of the same name, the
  /// values converted to the target column's type — a `CAST` on PostgreSQL,
  /// bytes from hexadecimal on both. Every column of the backup must be a
  /// column of the target table; refused (`tenancy.import.target_rejects`)
  /// otherwise, before a row is written. Answers the rows written.
  static Future<int> import(
    TomSqlDatasource datasource,
    TomTenantTableBackup backup,
  ) async {
    final dialect = datasource.sqlDialect;
    final postgres = dialect is PostgresSqlDialect;
    final target = {
      for (final c in await columns(datasource, backup.table))
        c.name.toLowerCase(): c,
    };
    final missing = [
      for (final c in backup.columns)
        if (!target.containsKey(c.name.toLowerCase())) c.name,
    ];
    if (missing.isNotEmpty) {
      throw TomTenancyException(
        'tenancy.import.target_rejects',
        "The table '${backup.table}' of data source '${backup.datasource}' "
            'has no column ${missing.join(', ')}: the rows cannot be written '
            'there.',
        parameters: {
          'table': backup.table,
          'datasource': backup.datasource,
          'columns': missing,
        },
      );
    }
    final list = [
      for (final c in backup.columns) dialect.quoteIdentifier(c.name),
    ].join(', ');
    final values = [
      for (final (i, c) in backup.columns.indexed)
        _value(':v$i', target[c.name.toLowerCase()]!, postgres),
    ].join(', ');
    final statement = 'INSERT INTO ${backup.table} ($list) VALUES ($values)';
    var written = 0;
    for (final row in backup.rows) {
      await datasource.executeCommand(statement, {
        for (final (i, value) in row.indexed) 'v$i': value,
      });
      written++;
    }
    return written;
  }

  /// Deletes [tenant]'s rows of [table] in [datasource]; answers how many.
  static Future<int> delete(
    TomSqlDatasource datasource,
    String table,
    String column,
    String tenant,
  ) async {
    final quoted = datasource.sqlDialect.quoteIdentifier(column);
    final deleted = await datasource.executeCommand(
      'DELETE FROM $table WHERE $quoted = :tenant',
      {'tenant': tenant},
    );
    return deleted.toInt();
  }

  static String _value(
    String parameter,
    TomTenantColumn column,
    bool postgres,
  ) {
    if (column.isBinary) {
      return postgres ? "decode($parameter, 'hex')" : 'UNHEX($parameter)';
    }
    return postgres ? 'CAST($parameter AS ${column.type})' : parameter;
  }
}
