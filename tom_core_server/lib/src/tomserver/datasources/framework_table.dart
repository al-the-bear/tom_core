/// The single column declaration of a table the **framework itself** owns.
///
/// ## The hole this closes
///
/// An application's tables are guarded by the CE-DB ↔ CE-MG convergence check:
/// the entity model declares a shape, the migration chain builds one, and
/// `TomSchemaConvergenceCheck` proves the two agree. The framework's own tables —
/// the job queue, the lease table, the roll call, the blob pair, the audit trail
/// — are not entities, so they sat outside that guard entirely, and each declared
/// its columns **twice**: once in a `CREATE TABLE` string and again in the column
/// lists of the statements that read and write it. Nothing related the two.
///
/// A column renamed on one side and not the other is a runtime failure on a path
/// that may only ever execute in production — `recoverAbandoned` after a node
/// dies, a chunk read of a large file — and the framework's own tables are the
/// ones a deployment is least able to repair.
///
/// A [TomFrameworkTable] is that single declaration. Everything else is derived
/// from it:
///
/// * the create-if-missing DDL the stores issue ([createTableDdl]);
/// * the column lists their statements interpolate ([columnList], [columnsOf]);
/// * the `INSERT`/`REPLACE` shape ([insert]);
/// * the [TomSchemaModel] the convergence guard compares — see
///   `db_migration/framework_convergence.dart`, which replays [createTableDdl]
///   through the very same [TomSchemaDdlReader] the migration side uses, so the
///   two sides cannot classify a type differently.
///
/// ## Why here and not in `db_migration/`
///
/// The stores that own these tables (`scheduling/`, `file_storage/`, `audit/`)
/// already depend on `datasources/` and must not be made to depend on the
/// migration module — a deployment can use the scheduler without ever running a
/// migration. The comparison, which is migration-shaped, lives in `db_migration/`
/// and depends on this file rather than the other way round.
///
/// ## What it deliberately does not do
///
/// It is **not** a query builder. The statements in these stores are conditional
/// writes whose exact shape is load-bearing and documented at length — the
/// affected-row count of `UPDATE ... WHERE state = 'pending'` *is* the
/// arbitration — so rendering them from a template would trade a readable
/// invariant for an unreadable one. What is generated here is the part that is
/// pure repetition: the DDL and the column *lists*. Column references inside
/// `SET` and `WHERE` clauses stay written out, and are guarded instead by
/// [unknownFrameworkColumns], which audits the statements a store actually
/// issues.
library;

import 'datasource_initialization.dart';
import 'sql_datasource.dart';
import 'sql_dialects.dart';
import '../transactions/transaction_manager.dart';

/// The dialect the canonical renderings ([TomFrameworkColumn.ddl],
/// [TomFrameworkTable.createTableDdl]) use: the type vocabulary as declared.
final TomStandardSqlDialect _canonical = TomStandardSqlDialect();

/// One column of a framework-owned table.
class TomFrameworkColumn {
  /// Declares a column.
  const TomFrameworkColumn(
    this.name,
    this.type, {
    this.nullable = false,
    this.defaultValue,
    this.autoIncrement = false,
  });

  /// The column name, exactly as it is spelled in SQL.
  final String name;

  /// The SQL type, including any length or precision — `VARCHAR(191)`.
  final String type;

  /// Whether the column accepts `NULL`.
  final bool nullable;

  /// The `DEFAULT` clause's value as SQL text, or `null` for no default.
  final String? defaultValue;

  /// Whether the column carries `AUTO_INCREMENT`.
  final bool autoIncrement;

  /// The column's line in a `CREATE TABLE` body, padded to [nameWidth] and
  /// [typeWidth] so a reader can scan the types in a column.
  ///
  /// The canonical rendering — the types as declared; [ddlIn] renders it for a
  /// database.
  String ddl(int nameWidth, int typeWidth) =>
      ddlIn(_canonical, nameWidth, typeWidth);

  /// The column's line as [dialect]'s database spells it.
  String ddlIn(TomStandardSqlDialect dialect, int nameWidth, int typeWidth) =>
      dialect.columnDefinition(
        name: name,
        type: type,
        nullable: nullable,
        defaultValue: defaultValue,
        autoIncrement: autoIncrement,
        nameWidth: nameWidth,
        typeWidth: typeWidth,
      );

  /// The declared character capacity of a string column, or `null` when the
  /// type carries none.
  ///
  /// Read from [type] rather than declared beside it, so there is one statement
  /// of the width and it is the one the `CREATE TABLE` uses. A writer that
  /// trims a value to fit, and a reader that has to trim a search term the same
  /// way to find what the writer stored, both need this number — and a literal
  /// repeated at either call site is a number that survives a column being
  /// widened.
  ///
  /// `VARCHAR(160)` and `CHAR(64)` answer with their length; `BIGINT`,
  /// `LONGTEXT` and `DATETIME(6)` answer `null`. A precision is not a character
  /// capacity, which is why the type name is matched rather than the
  /// parenthesis alone.
  int? get maxCharacters {
    final match = RegExp(
      r'^\s*(?:VAR)?CHAR\s*\(\s*(\d+)\s*\)',
      caseSensitive: false,
    ).firstMatch(type);
    return match == null ? null : int.parse(match.group(1)!);
  }

  @override
  String toString() => '$name $type';
}

/// One index or unique constraint of a framework-owned table.
///
/// The name is built from the table's name and [suffix] rather than given
/// outright, because the table name is a per-instance argument: two stores over
/// differently-named tables in one schema would otherwise collide on an index
/// name and the second `CREATE TABLE` would fail.
class TomFrameworkKey {
  /// Declares a key.
  const TomFrameworkKey(this.suffix, this.columns, {this.unique = false});

  /// Declares a unique key.
  const TomFrameworkKey.unique(this.suffix, this.columns) : unique = true;

  /// The part of the key's name that identifies what it is for.
  final String suffix;

  /// The columns the key covers, in key order.
  final List<String> columns;

  /// Whether the key is a uniqueness constraint rather than an index.
  final bool unique;

  /// The key's name on [table].
  String nameOn(String table) => '${unique ? 'uq' : 'ix'}_${table}_$suffix';

  /// The key's line in a `CREATE TABLE` body, canonically rendered.
  String ddl(String table) =>
      _canonical.keyDefinition(nameOn(table), columns, unique: unique);
}

/// Whether a framework table holds the deployment's rows or one tenant's.
///
/// The kind decides where the store reaches the table
/// ([TomFrameworkTable.placed]) and which migration tree ships it: a
/// **system** table lives in the system schema — the base data source's own —
/// and is never routed; a **tenant** table lives where the current tenant's
/// data lives, and its migration is part of every tenant type's tree.
enum TomTableKind {
  /// The deployment's: the system schema, never routed. A system table that
  /// does work for tenants carries a `tenant` column.
  system,

  /// One tenant's: routed to the current tenant's schema or database.
  tenant,
}

/// A table the framework owns, declared once.
class TomFrameworkTable {
  /// Declares a table called [name].
  ///
  /// [origin] names the declaration for a divergence report — the function that
  /// builds this descriptor — so a finding says where to go and not merely what
  /// is wrong.
  TomFrameworkTable({
    required this.name,
    required this.columns,
    required this.origin,
    required this.kind,
    this.primaryKey = const [],
    this.keys = const [],
  }) : _byName = {
         for (final column in columns) column.name.toLowerCase(): column,
       } {
    // Both checks are on construction because a descriptor is built once at
    // start-up: a mistake here would otherwise surface as a `CREATE TABLE`
    // failure against a live server, which is exactly the class of failure this
    // type removes.
    //
    // A table needs at least one column. `createTableDdl` measures its padding
    // by reducing over them, so an empty descriptor fails there with "No
    // element" — a message about the renderer, arriving at the first
    // `CREATE TABLE`, about a table that could not have been valid SQL anyway.
    if (columns.isEmpty) {
      // throws-outside-family: programmer error — a framework table descriptor
      // is code, built once at start-up.
      throw ArgumentError.value(
        name,
        'columns',
        'declares no columns (from $origin); a table needs at least one',
      );
    }
    // Every key and every primary-key part must name a column of this table.
    for (final column in [
      ...primaryKey,
      for (final key in keys) ...key.columns,
    ]) {
      if (_byName.containsKey(column.toLowerCase())) continue;
      // throws-outside-family: programmer error — as above: the descriptor
      // names a key column it lacks.
      throw ArgumentError.value(
        column,
        'column',
        'is keyed on table "$name" but is not one of its columns',
      );
    }
  }

  /// The table's name, which is a per-instance argument of the owning store.
  final String name;

  /// Whether the table is the deployment's or a tenant's.
  final TomTableKind kind;

  /// The columns, in declaration order.
  final List<TomFrameworkColumn> columns;

  /// The primary-key column names, in key order.
  final List<String> primaryKey;

  /// The unique constraints and secondary indexes.
  final List<TomFrameworkKey> keys;

  /// The library-level function that declares this table.
  final String origin;

  final Map<String, TomFrameworkColumn> _byName;

  /// Where a store of this table reaches it in the current zone — the one
  /// placement rule every framework store follows, whatever it was built over:
  /// a data source name, a [TomDataSourceInfo] or a data source handed in.
  ///
  /// [held] is the data source the store holds. Its **system** data source is
  /// the registered base it belongs to: [held] itself, or for a pool tenancy
  /// opened over a tenant's schema or database (`<name>@<tenant>`,
  /// `<name>@type.<type>`) the data source `<name>`. A [TomTableKind.system]
  /// table is reached there, never routed — also inside a tenant; a
  /// [TomTableKind.tenant] table through [TomDataSourceInfo.route] of it — the
  /// current tenant's schema or database, or the system data source with no
  /// tenant in context.
  TomDataSourceInfo placedInfo(TomDataSourceInfo held) {
    final system = systemInfoOf(held);
    return kind == TomTableKind.system
        ? system
        : TomDataSourceInfo.route(system);
  }

  /// [placedInfo] for a store holding the data source object [held]. A data
  /// source registered under no name — a test's fake, a store's private pool —
  /// is not placed and is used as it is.
  TomDataSource placed(TomDataSource held) {
    final info = _registeredInfoOf(held);
    return info == null ? held : placedInfo(info).datasource;
  }

  /// The system data source of the data source object [held] — where every
  /// [TomTableKind.system] table is reached, whatever the zone: [held] itself,
  /// or the base `<name>` of a tenant pool `<name>@…`. A data source
  /// registered under no name is returned as it is.
  ///
  /// A system store applies it once, when it is built, because a system
  /// table's place does not depend on the tenant in context.
  static TomDataSource systemOf(TomDataSource held) {
    final info = _registeredInfoOf(held);
    return info == null ? held : systemInfoOf(info).datasource;
  }

  static TomDataSourceInfo? _registeredInfoOf(TomDataSource held) {
    final name = held is TomSqlDatasource ? held.registeredName : null;
    final info = name == null
        ? null
        : TomDataSourceInfo.getBaseDataSourceInfo(name);
    return info == null || !identical(info.datasource, held) ? null : info;
  }

  /// The registered system data source [info] belongs to: the base `<name>`
  /// of a tenant pool `<name>@…`, else [info] itself.
  static TomDataSourceInfo systemInfoOf(TomDataSourceInfo info) {
    final at = info.name.indexOf('@');
    if (at < 0) return info;
    return TomDataSourceInfo.getBaseDataSourceInfo(
          info.name.substring(0, at),
        ) ??
        info;
  }

  /// The column names, in declaration order.
  List<String> get columnNames => [for (final c in columns) c.name];

  /// Whether a column called [column] exists, case-insensitively.
  bool has(String column) => _byName.containsKey(column.toLowerCase());

  /// The column called [column], or `null`.
  TomFrameworkColumn? column(String column) => _byName[column.toLowerCase()];

  /// Every column, as a `SELECT`/`INSERT` list in declaration order.
  String get columnList => columnNames.join(', ');

  /// [names] as a column list, in the order given.
  ///
  /// Throws [ArgumentError] when a name is not a column — which is the point:
  /// a projection that outlived the column it names fails at the first call
  /// rather than at the database.
  String columnsOf(Iterable<String> names) {
    final unknown = [
      for (final n in names)
        if (!has(n)) n,
    ];
    if (unknown.isNotEmpty) {
      // throws-outside-family: programmer error — the caller's code names a
      // column the descriptor lacks.
      throw ArgumentError.value(
        unknown.join(', '),
        'names',
        'are not columns of "$name" (has: $columnList)',
      );
    }
    return names.join(', ');
  }

  /// Renders a row-writing statement for [dialect]'s database.
  ///
  /// [values] maps a column name to the SQL text that supplies it, which is
  /// usually a `:bind` but may be a literal: the lease lock's first acquisition
  /// writes `token` and `version` as `1` and `released` as `0` in the same
  /// statement it binds the rest of. With [ignoreConflict] a row whose key
  /// already exists is kept and the write changes nothing.
  ///
  /// Keying by column name rather than by position is deliberate. A positional
  /// list would put the column list and the value list in lock-step order, so
  /// inserting a column in the descriptor would silently shift every value one
  /// place along — which is a worse failure than the one this whole file exists
  /// to remove, because it type-checks.
  String insertRow(
    TomStandardSqlDialect dialect,
    Map<String, String> values, {
    bool ignoreConflict = false,
  }) {
    _refuseUnknown(values.keys, 'values');
    return dialect.insertInto(name, values, ignoreConflict: ignoreConflict);
  }

  /// The statements writing a row over every row it supersedes — the one with
  /// its primary key, and any colliding on one of this table's unique keys —
  /// in [dialect]'s database; see [TomStandardSqlDialect.replaceInto].
  List<String> replaceStatements(
    TomStandardSqlDialect dialect,
    Map<String, String> values, {
    String? table,
  }) {
    _refuseUnknown(values.keys, 'values');
    return dialect.replaceInto(
      table ?? name,
      values,
      primaryKey: primaryKey,
      uniqueKeys: [
        for (final key in keys)
          if (key.unique) key.columns,
      ],
    );
  }

  /// Writes a row over every row it supersedes, in [datasource] — one
  /// statement on MariaDB, a `DELETE` and an `INSERT` in one transaction where
  /// the database has no `REPLACE`. [values] names the SQL text per column as
  /// for [insertRow]; [params] binds it. [table] names the table as the
  /// statement addresses it — a schema-qualified name, when [datasource] is
  /// not the one the table lives in — and defaults to [name].
  Future<void> replaceRow(
    TomDataSource datasource,
    Map<String, String> values,
    Map<String, dynamic> params, {
    String? table,
  }) async {
    final statements = replaceStatements(
      datasource.sqlDialect,
      values,
      table: table,
    );
    if (statements.length == 1) {
      await datasource.executeCommand(statements.single, params);
      return;
    }
    await TomTransactionManager.runInTransaction((_) async {
      for (final statement in statements) {
        await datasource.executeCommand(statement, params);
      }
    });
  }

  void _refuseUnknown(Iterable<String> names, String argument) {
    final unknown = [
      for (final n in names)
        if (!has(n)) n,
    ];
    if (unknown.isNotEmpty) {
      // throws-outside-family: programmer error — as columnsOf.
      throw ArgumentError.value(
        unknown.join(', '),
        argument,
        'are not columns of "$name" (has: $columnList)',
      );
    }
  }

  /// The `CREATE TABLE IF NOT EXISTS` statement that builds this table.
  ///
  /// `IF NOT EXISTS` because every store calls it on first use and a second
  /// process must not fail on a table the first one created.
  ///
  /// The canonical rendering, which the convergence guard reads; a store
  /// creates its table with [create], in its own database's words.
  String get createTableDdl => createStatements(_canonical).first;

  /// The statements building this table in [dialect]'s database: the
  /// `CREATE TABLE IF NOT EXISTS`, then — where the database cannot declare an
  /// index inside the table — one `CREATE INDEX IF NOT EXISTS` per index.
  List<String> createStatements(TomStandardSqlDialect dialect) {
    final nameWidth = columns
        .map((c) => c.name.length)
        .reduce((a, b) => a > b ? a : b);
    final typeWidth = columns
        .map((c) => dialect.columnType(c.type).length)
        .reduce((a, b) => a > b ? a : b);
    final inline = dialect.declaresIndexesInline;
    final lines = <String>[
      for (final column in columns) column.ddlIn(dialect, nameWidth, typeWidth),
      if (primaryKey.isNotEmpty) 'PRIMARY KEY (${primaryKey.join(', ')})',
      for (final key in keys)
        if (key.unique || inline)
          dialect.keyDefinition(
            key.nameOn(name),
            key.columns,
            unique: key.unique,
          ),
    ];
    return [
      'CREATE TABLE IF NOT EXISTS $name (\n'
          '${lines.map((line) => '  $line').join(',\n')}\n'
          ')',
      if (!inline)
        for (final key in keys)
          if (!key.unique)
            dialect.createIndex(key.nameOn(name), name, key.columns),
    ];
  }

  /// Creates this table in [datasource] if it does not exist, in the
  /// datasource's own dialect.
  Future<void> create(TomDataSource datasource) async {
    for (final statement in createStatements(datasource.sqlDialect)) {
      await datasource.executeCommand(statement);
    }
  }

  @override
  String toString() => 'TomFrameworkTable($name)';
}

/// The identifiers in [sql] that are not a column of any of [tables], not one of
/// their names, and not SQL.
///
/// The guard for the half of a statement a column *list* cannot cover: the
/// column references inside `SET`, `WHERE` and `ORDER BY`. Those stay written
/// out — the exact shape of a conditional write is load-bearing and documented,
/// so generating it would cost more than it saves — and are audited instead, by
/// driving each store through a recording data source and passing every
/// statement it issued through here.
///
/// Deliberately conservative in the direction that matters. String literals,
/// `:bind` placeholders and numbers are removed before the scan, and a fixed set
/// of SQL words is ignored; anything else that survives is reported. A word
/// missing from that set is a **false positive in a test**, which is noisy and
/// self-correcting, whereas a missed column reference is the production failure
/// this exists to prevent.
List<String> unknownFrameworkColumns(
  String sql,
  Iterable<TomFrameworkTable> tables,
) {
  final stripped = sql
      // Quoted text first: it can contain anything, including column names.
      .replaceAll(RegExp(r"'[^']*'"), ' ')
      .replaceAll(RegExp(r'"[^"]*"'), ' ')
      // Binds are values, not identifiers, and are named after Dart fields.
      .replaceAll(RegExp(r':\w+'), ' ')
      .replaceAll(RegExp(r'\b\d+\b'), ' ');
  final known = <String>{
    for (final table in tables) ...[
      table.name.toLowerCase(),
      for (final column in table.columns) column.name.toLowerCase(),
      // Index names too, so the audit can be pointed at a `CREATE TABLE` as
      // well as at the statements that use it. They are derived from the same
      // descriptor, so admitting them is not a widening of what is trusted.
      for (final key in table.keys) key.nameOn(table.name).toLowerCase(),
    ],
  };
  final seen = <String>{};
  return [
    for (final match in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(stripped))
      if (!known.contains(match[0]!.toLowerCase()) &&
          !_sqlWords.contains(match[0]!.toLowerCase()) &&
          seen.add(match[0]!.toLowerCase()))
        match[0]!,
  ];
}

/// The SQL vocabulary [unknownFrameworkColumns] ignores.
///
/// Keywords, the aggregate and scalar functions these stores use, and the SQL
/// type names, so the audit can be pointed at DDL as well as DML.
const Set<String> _sqlWords = {
  'add',
  'all',
  'alter',
  'and',
  'as',
  'asc',
  'auto_increment',
  'avg',
  'before',
  'between',
  'bigint',
  'binary',
  'blob',
  'boolean',
  'by',
  'case',
  'cast',
  'char',
  'coalesce',
  'column',
  'count',
  'create',
  'database',
  'date',
  'datetime',
  'decimal',
  'default',
  'delete',
  'desc',
  'distinct',
  'double',
  'drop',
  'duplicate',
  'else',
  'end',
  'escape',
  'exists',
  'float',
  'for',
  'from',
  'group',
  'having',
  'if',
  'ignore',
  'in',
  'index',
  'information_schema',
  'inner',
  'insert',
  'int',
  'integer',
  'interval',
  'into',
  'is',
  'join',
  'key',
  'left',
  'like',
  'limit',
  'longblob',
  'longtext',
  'max',
  'min',
  'mod',
  'modify',
  'not',
  'now',
  'null',
  'nullif',
  'offset',
  'on',
  'or',
  'order',
  'outer',
  'primary',
  'rename',
  'replace',
  'returning',
  'right',
  'select',
  'set',
  'smallint',
  'sum',
  'table',
  'text',
  'then',
  'time',
  'timestamp',
  'tinyint',
  'to',
  'unique',
  'update',
  'utc_timestamp',
  'values',
  'varbinary',
  'varchar',
  'when',
  'where',
  'with',
};

/// Provisions a store's tables at most once, however many first calls arrive
/// together.
///
/// A store creates its tables on first use. Two requests reaching a fresh
/// store at the same moment both see "not yet created"; with a connection pool
/// their two `CREATE TABLE IF NOT EXISTS` run on two connections, and the
/// second can return — the table "exists" — before the first has finished
/// creating it, so the second request's statement fails on a table that does
/// not exist yet. Sharing the one creation in flight closes that: every
/// caller awaits the same run.
///
/// A creation that fails is forgotten, so the next call tries again rather
/// than inheriting the failure for the life of the store.
class TomSchemaProvisioning {
  Future<void>? _ready;

  /// Runs [create] once, or awaits the run already in flight or finished.
  Future<void> ensure(Future<void> Function() create) =>
      _ready ??= create().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _ready = null;
          return Future<void>.error(error, stack);
        },
      );
}
