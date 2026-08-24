/// The dialect-neutral schema shape both halves of the CE-DB ↔ CE-MG
/// convergence check are reduced to before they are compared.
///
/// The entity model (`@TomDbTable` / `@TomDbColumn`) and the cumulative DDL of a
/// migration chain describe the same schema from two sides but in two
/// vocabularies — Dart types on one, SQL type names on the other. Neither can be
/// compared to the other directly, so both are read into the structures here
/// and the diff runs over one vocabulary only.
library;

import '../datasources/sql_dialects.dart';

/// How tolerantly the two sides of the convergence check compare their
/// [TomSqlTypeFamily] classifications.
///
/// The families themselves are the dialect's vocabulary (a dialect decides that
/// `TINYINT(1)` is a truth value); how much difference between two families is
/// still *agreement* is the check's policy, and so lives here.
extension TomSqlTypeFamilyCompatibility on TomSqlTypeFamily {
  /// Whether a column of this (expected) family may be stored as [actual].
  ///
  /// The direction matters — the receiver is what the entity model declares,
  /// [actual] what the DDL creates:
  ///
  /// * `integer` ↔ `boolean` — both ways. A truth value stored as `TINYINT(1)`
  ///   is the normal MariaDB spelling, and an entity that reads that column as
  ///   an `int` is equally valid; the entity model does not pin the choice down.
  /// * `decimal` accepts `integer`, but **not** the reverse. Reading a whole
  ///   number as a `double` is lossless; declaring an `int` over a `DECIMAL`
  ///   column truncates, which is a real defect worth reporting.
  /// * `dateTime` ↔ `date` — both ways, for the same reason as integer/boolean:
  ///   whether the time-of-day part is stored is a storage decision the entity
  ///   model leaves open.
  /// * [unknown] on either side is compatible with everything.
  bool accepts(TomSqlTypeFamily actual) {
    if (this == actual) return true;
    const unknown = TomSqlTypeFamily.unknown;
    if (this == unknown || actual == unknown) return true;
    return switch (this) {
      TomSqlTypeFamily.integer => actual == TomSqlTypeFamily.boolean,
      TomSqlTypeFamily.boolean => actual == TomSqlTypeFamily.integer,
      TomSqlTypeFamily.decimal => actual == TomSqlTypeFamily.integer,
      TomSqlTypeFamily.dateTime => actual == TomSqlTypeFamily.date,
      TomSqlTypeFamily.date => actual == TomSqlTypeFamily.dateTime,
      _ => false,
    };
  }
}

/// One column of a [TomSchemaTable].
class TomSchemaColumn {
  /// The column name as written on the side this column was read from.
  ///
  /// Lookups are case-insensitive (see [TomSchemaTable.column]); this field
  /// keeps the original spelling so a report names the column the way the
  /// author wrote it.
  final String name;

  /// The type class this column is compared in.
  final TomSqlTypeFamily family;

  /// The type as declared on the source side — a SQL type (`VARCHAR(255)`) for
  /// a column read from DDL, a Dart or `TomDbType` name for one derived from an
  /// entity. Reported, never compared.
  final String declaredType;

  /// Whether the column accepts `NULL`.
  ///
  /// Parsed from the DDL and carried here, but **not** part of the comparison:
  /// the entity model has no nullability declaration to compare it against
  /// (every mapped field is Dart-nullable so an unsaved record can exist). It
  /// is modelled anyway so that a future entity-side declaration can turn the
  /// comparison on without re-parsing anything. Defaults to `true` on the
  /// entity side, where it is unknown.
  final bool nullable;

  /// Where this column came from — the migration artifact basename that last
  /// defined it, or the entity type name that declares it.
  ///
  /// This is the locality a divergence report points at: "column `x` is missing
  /// from `app_items`" is only actionable together with "and `UserRecord`
  /// expects it" or "and `[004]-add_columns` should have added it".
  final String origin;

  /// Creates a column description.
  const TomSchemaColumn({
    required this.name,
    required this.family,
    required this.declaredType,
    required this.origin,
    this.nullable = true,
  });

  /// A copy of this column under a new [name] (a `RENAME COLUMN` replay).
  TomSchemaColumn renamedTo(String name, String origin) => TomSchemaColumn(
    name: name,
    family: family,
    declaredType: declaredType,
    origin: origin,
    nullable: nullable,
  );

  @override
  String toString() => '$name $declaredType${nullable ? '' : ' NOT NULL'}';
}

/// One table of a [TomSchemaModel].
class TomSchemaTable {
  /// The table name as written on the side this table was read from.
  final String name;

  /// The table's columns keyed by lower-cased name, in declaration order.
  final Map<String, TomSchemaColumn> columns;

  /// The primary-key column names in key order, empty when none is declared.
  final List<String> primaryKey;

  /// The migration artifact or entity type that created this table.
  final String origin;

  /// Creates a table description.
  const TomSchemaTable({
    required this.name,
    required this.columns,
    required this.primaryKey,
    required this.origin,
  });

  /// The column called [name], case-insensitively, or `null`.
  TomSchemaColumn? column(String name) => columns[name.toLowerCase()];

  @override
  String toString() => '$name(${columns.values.join(', ')})';
}

/// A whole schema — the tables of one `<datasource>/<schema>` pair.
class TomSchemaModel {
  /// The schema's tables keyed by lower-cased name, in creation order.
  final Map<String, TomSchemaTable> tables;

  /// Creates a schema description.
  const TomSchemaModel(this.tables);

  /// An empty schema.
  static const TomSchemaModel empty = TomSchemaModel({});

  /// The table called [name], case-insensitively, or `null`.
  TomSchemaTable? table(String name) => tables[name.toLowerCase()];

  @override
  String toString() => 'TomSchemaModel(${tables.keys.join(', ')})';
}

/// The mutable accumulator both sides build their [TomSchemaModel] through.
///
/// The DDL side needs mutation by construction — replaying a chain means
/// applying `CREATE`, then `ALTER`, then `DROP` to a schema that is only
/// complete at the tip. Rather than give [TomSchemaModel] mutating members that
/// nothing may call after the build, the mutation lives here and the model
/// comes out immutable. The entity side uses the same builder, so both halves
/// of the check are assembled through one API and cannot drift apart in shape.
///
/// Every mutation is a **silent no-op on a table or column the builder does not
/// have**, never an error: [addColumn], [dropColumn], [renameColumn] and
/// [setPrimaryKey] against an unknown table all return with the model
/// unchanged. The builder accumulates; it never reports.
///
/// That is a division of labour, not leniency. Whether a statement operating on
/// something absent is a *defect* depends on the statement text — `DROP TABLE
/// IF EXISTS` on a table the chain never created is the guard doing its job,
/// the same drop without the guard is a chain defect worth reporting — and the
/// builder is handed parsed names and columns, never the SQL, so it is the one
/// participant that cannot tell those two apart. `TomSchemaDdlReader` can, and
/// does: it asks [hasTable] / [hasColumn] *before* mutating, and the answer
/// decides whether it records a `TomDdlReplayError`, not whether the call is
/// safe to make.
///
/// Two consequences follow, and both are why the checking is not moved down
/// here. The reader collects its errors and keeps replaying, so one run reports
/// every divergence in a chain rather than only the first; a builder that threw
/// would end the replay at the earliest defect. And the entity side builds from
/// `information_schema` rows, where there is no chain to contradict and nothing
/// to report — a builder that demanded a pre-check would impose guards on a
/// caller that cannot fail that way.
class TomSchemaBuilder {
  final Map<String, _TableBuilder> _tables = {};

  /// Whether a table called [table] exists (case-insensitively).
  bool hasTable(String table) => _tables.containsKey(table.toLowerCase());

  /// Whether [table] exists and has a column called [column].
  bool hasColumn(String table, String column) =>
      _tables[table.toLowerCase()]?.columns.containsKey(column.toLowerCase()) ??
      false;

  /// The table names currently in the builder, in creation order.
  Iterable<String> get tableNames => _tables.values.map((t) => t.name);

  /// Creates an empty table called [name], attributed to [origin]. Replaces any
  /// table of that name.
  void addTable(String name, String origin) {
    _tables[name.toLowerCase()] = _TableBuilder(name, origin);
  }

  /// Removes [name] if present.
  void dropTable(String name) => _tables.remove(name.toLowerCase());

  /// Renames table [from] to [to]; does nothing when [from] is absent.
  void renameTable(String from, String to) {
    final table = _tables.remove(from.toLowerCase());
    if (table == null) return;
    table.name = to;
    _tables[to.toLowerCase()] = table;
  }

  /// Adds or replaces [column] on [table]; does nothing when [table] is absent.
  void addColumn(String table, TomSchemaColumn column) {
    _tables[table.toLowerCase()]?.columns[column.name.toLowerCase()] = column;
  }

  /// Removes column [column] from [table]; does nothing when either is absent.
  void dropColumn(String table, String column) {
    _tables[table.toLowerCase()]?.columns.remove(column.toLowerCase());
  }

  /// Renames column [from] to [to] on [table], preserving its position and
  /// attributing the change to [origin]; does nothing when either is absent.
  void renameColumn(String table, String from, String to, String origin) {
    final builder = _tables[table.toLowerCase()];
    final existing = builder?.columns[from.toLowerCase()];
    if (builder == null || existing == null) return;
    // Rebuild the map so the renamed column keeps its declaration position —
    // column order is what a reader compares against the DDL by eye.
    final rebuilt = <String, TomSchemaColumn>{};
    for (final entry in builder.columns.entries) {
      if (entry.key == from.toLowerCase()) {
        rebuilt[to.toLowerCase()] = existing.renamedTo(to, origin);
      } else {
        rebuilt[entry.key] = entry.value;
      }
    }
    builder.columns
      ..clear()
      ..addAll(rebuilt);
  }

  /// Declares [columns] as the primary key of [table]; does nothing when
  /// [table] is absent.
  void setPrimaryKey(String table, List<String> columns) {
    _tables[table.toLowerCase()]?.primaryKey = columns;
  }

  /// Freezes the accumulated state into an immutable [TomSchemaModel].
  ///
  /// Every level is wrapped, the table map included: a model whose tables could
  /// still be added to would let a consumer edit the very thing the check just
  /// compared.
  TomSchemaModel build() => TomSchemaModel(
    Map.unmodifiable({
      for (final entry in _tables.entries)
        entry.key: TomSchemaTable(
          name: entry.value.name,
          columns: Map.unmodifiable(entry.value.columns),
          primaryKey: List.unmodifiable(entry.value.primaryKey),
          origin: entry.value.origin,
        ),
    }),
  );
}

class _TableBuilder {
  _TableBuilder(this.name, this.origin);

  String name;
  final String origin;
  final Map<String, TomSchemaColumn> columns = {};
  List<String> primaryKey = const [];
}
