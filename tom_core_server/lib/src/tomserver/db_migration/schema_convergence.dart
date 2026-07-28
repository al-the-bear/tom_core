/// The CE-DB ↔ CE-MG convergence check: proof that a schema's migration chain
/// builds exactly the shape its entity model declares.
///
/// The two halves of a persistence specification are written independently. The
/// entity model (`@TomDbTable` / `@TomDbColumn`) says the schema *has* a shape;
/// the migration chain under `<databaseMigrationsDirectory>/<datasource>/<schema>/`
/// independently *builds* one. Nothing in the type system relates them — and the
/// migration filenames, which decide the order that chain is replayed in, are one
/// of the few string surfaces deliberately left untyped. This check is their only
/// guard.
///
/// It runs with **no database**: the expected side comes from reflection, the
/// actual side from replaying the chain's DDL text ([TomSchemaDdlReader]). That
/// is a requirement, not an optimisation — a check that needs a live server
/// cannot gate code generation.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/mariadb_sql_dialect.dart';
import '../datasources/queries.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/persistence_annotations.dart';
import 'db_migration.dart';
import 'schema_ddl_reader.dart';
import 'schema_model.dart';

/// Derives the **expected** schema — the shape the entity model declares.
///
/// This is the half of the check that reads `@TomDbTable` / `@TomDbColumn`
/// through [TomAnnotationAnalyzer] and reduces it to the same [TomSchemaModel]
/// the DDL side produces, so the diff compares one vocabulary only.
///
/// ## What the entity model can and cannot say
///
/// The comparison scope is bounded by what the annotations actually declare, and
/// that boundary is deliberate rather than provisional:
///
/// * **Compared** — table existence, column existence, column *type family*
///   ([TomSqlTypeFamily]), and the primary key.
/// * **Not compared, because the entity model does not declare it** — column
///   length and precision (`VARCHAR(255)` vs `VARCHAR(64)`), defaults,
///   `AUTO_INCREMENT`, unique keys, secondary indexes, foreign keys, charset,
///   collation and engine.
/// * **Not compared, because the entity side carries no usable signal** —
///   nullability. Every mapped Dart field is nullable so an unsaved record can
///   exist, and [TomColumnInformation.declaredType] erases nullability anyway
///   (`int?` arrives as `int`). The DDL side still *parses* nullability into
///   [TomSchemaColumn.nullable], so a future entity-side declaration can switch
///   the comparison on without re-parsing anything.
/// * **Out of scope entirely** — seed data, generated columns, partitioning and
///   stored routines.
class TomEntitySchemaReader {
  /// The [TomDbType] boxes an entity may declare, mapped to their type family.
  static const Map<Type, TomSqlTypeFamily> _boxFamilies = {
    TomDbInt: TomSqlTypeFamily.integer,
    TomDbDouble: TomSqlTypeFamily.decimal,
    TomDbString: TomSqlTypeFamily.text,
    TomDbBool: TomSqlTypeFamily.boolean,
    TomDbDateTime: TomSqlTypeFamily.dateTime,
    TomDbDate: TomSqlTypeFamily.date,
    TomDbTime: TomSqlTypeFamily.time,
  };

  /// The Dart types a mapped field may have when no [TomDbType] box is declared.
  static const Map<Type, TomSqlTypeFamily> _dartFamilies = {
    int: TomSqlTypeFamily.integer,
    double: TomSqlTypeFamily.decimal,
    num: TomSqlTypeFamily.decimal,
    String: TomSqlTypeFamily.text,
    bool: TomSqlTypeFamily.boolean,
    DateTime: TomSqlTypeFamily.dateTime,
    TomZonedDate: TomSqlTypeFamily.date,
    TomZonedTime: TomSqlTypeFamily.time,
  };

  /// Every `@TomDbTable`-annotated type registered with `tomReflector`.
  ///
  /// The check discovers entities the same way the rest of the persistence layer
  /// does, so a type the repository can load is a type the check can see.
  static List<Type> discoverEntityTypes() => [
    for (final candidate in tomReflector.annotatedClasses)
      if (candidate.metadata.any((m) => m is TomDbTable)) candidate.reflectedType,
  ];

  /// The entity types of [entityTypes] that map into [datasource] / [schema].
  ///
  /// An entity matches on [TomDbTable.datasource] — the same name the migration
  /// engine resolves its directory by. [TomDbTable.schema] narrows further when
  /// the entity declares one; an entity that declares none belongs to the
  /// datasource's only schema, which is why [TomSchemaConvergenceCheck] refuses
  /// to guess when a datasource has several schema directories.
  static List<Type> selectFor(
    Iterable<Type> entityTypes,
    String datasource,
    String schema,
  ) => [
    for (final type in entityTypes)
      if (_belongsTo(TomAnnotationAnalyzer.findTable(type), datasource, schema))
        type,
  ];

  static bool _belongsTo(TomDbTable? table, String datasource, String schema) {
    if (table == null) return false;
    if (table.datasource.toLowerCase() != datasource.toLowerCase()) return false;
    final declared = table.schema;
    return declared == null || declared.toLowerCase() == schema.toLowerCase();
  }

  /// Reduces [entityTypes] to the schema shape they declare.
  ///
  /// Two entities mapping to the same table name is not an error — a table may
  /// legitimately be read through more than one projection — so their columns
  /// are merged, and the table's origin names the first entity that declared it.
  static TomSchemaModel read(Iterable<Type> entityTypes) {
    final builder = TomSchemaBuilder();
    for (final type in entityTypes) {
      final info = TomAnnotationAnalyzer.analysePersistentType(type);
      final table = info.table;
      final origin = '$type';
      if (!builder.hasTable(table.table)) {
        builder.addTable(table.table, origin);
      }
      for (final column in info.columnInfo) {
        // An association is resolved through a join entity, not through a
        // column of this table; the owning table's foreign key, when it has
        // one, is declared as a plain @TomDbColumn field of its own.
        if (column.reference != null) continue;
        builder.addColumn(
          table.table,
          TomSchemaColumn(
            name: column.getQueryFieldName(),
            family: familyOf(column),
            declaredType: describeDeclaredType(column),
            origin: origin,
          ),
        );
      }
      builder.setPrimaryKey(table.table, primaryKeyOf(info));
    }
    return builder.build();
  }

  /// The type family [column] is stored in.
  ///
  /// A JSON column is text whatever its Dart type — the value is encoded before
  /// it reaches the database. Otherwise the declared [TomDbType] box decides,
  /// and only when there is none does the Dart type stand in. An unrecognised
  /// type (an enum behind a converter, say) yields [TomSqlTypeFamily.unknown],
  /// which is compatible with everything: a gap in the check's knowledge must
  /// not be reported as a defect in the schema.
  static TomSqlTypeFamily familyOf(TomColumnInformation column) {
    if (column.column?.isJson ?? false) return TomSqlTypeFamily.text;
    final boxed = column.column?.declaredColumnType();
    if (boxed != null) {
      final family = _boxFamilies[boxed];
      if (family != null) return family;
    }
    final dartType = column.column?.declaredDartType() ?? column.declaredType;
    return _dartFamilies[dartType] ?? TomSqlTypeFamily.unknown;
  }

  /// How [column]'s type is spelled on the entity side, for reporting only.
  static String describeDeclaredType(TomColumnInformation column) {
    if (column.column?.isJson ?? false) return 'JSON';
    final boxed = column.column?.declaredColumnType();
    if (boxed != null && _boxFamilies.containsKey(boxed)) return '$boxed';
    return '${column.column?.declaredDartType() ?? column.declaredType}';
  }

  /// The primary-key **column** names [info] declares, in declaration order.
  ///
  /// `@TomEntityId` is the primary signal and supports a composite key. When no
  /// field carries it, [TomDbTable.idColumn] is used, and failing that
  /// [TomDbTable.primaryKeyField] — resolved through the column mapping, since
  /// it names a *field* and the DDL side knows only columns.
  static List<String> primaryKeyOf(TomTypePersistenceInfo info) {
    final annotated = [
      for (final column in info.columnInfo)
        if (column.entityId != null) column.getQueryFieldName(),
    ];
    if (annotated.isNotEmpty) return annotated;
    final idColumn = info.table.idColumn;
    if (idColumn != null) return [idColumn];
    final keyField = info.table.primaryKeyField;
    for (final column in info.columnInfo) {
      if (column.declaredName == keyField) return [column.getQueryFieldName()];
    }
    return [keyField];
  }
}

/// What kind of disagreement a [TomSchemaDivergence] reports.
enum TomSchemaDivergenceKind {
  /// The entity model declares a table the migration chain never creates.
  missingTable,

  /// The chain creates a table no entity maps to.
  ///
  /// A warning, not an error: version-tracking tables, join tables and tables
  /// read only through raw SQL legitimately have no entity.
  unexpectedTable,

  /// The entity model declares a column the chain never adds to the table.
  missingColumn,

  /// The chain creates a column the entity does not map.
  ///
  /// A warning: an entity may deliberately project a subset of its table.
  unmappedColumn,

  /// Both sides have the column, in incompatible type families.
  columnTypeMismatch,

  /// The two sides disagree on which columns form the primary key.
  primaryKeyMismatch,

  /// A statement in the chain could not be replayed — the actual side of the
  /// comparison is incomplete, so everything downstream of it is unreliable.
  chainError,

  /// An entity declares no [TomDbTable.schema] in a datasource that has more
  /// than one schema directory, so which schema it belongs to is unknowable.
  ambiguousEntitySchema,
}

/// One disagreement between the entity model and the migration chain.
class TomSchemaDivergence {
  /// What kind of disagreement this is.
  final TomSchemaDivergenceKind kind;

  /// The table the disagreement is about, or `''` when it is chain-wide.
  final String table;

  /// The column the disagreement is about, or `null` for a table-level finding.
  final String? column;

  /// Where to go to act on it — the migration artifact or the entity type that
  /// last touched the subject, and the counterpart that expected otherwise.
  final String origin;

  /// A one-line explanation naming both sides.
  final String message;

  /// Whether this finding fails the check (`false` for the two warnings).
  final bool isError;

  /// Records a divergence.
  const TomSchemaDivergence({
    required this.kind,
    required this.table,
    required this.origin,
    required this.message,
    this.column,
    this.isError = true,
  });

  /// The subject as `table` or `table.column`.
  String get subject => column == null ? table : '$table.$column';

  @override
  String toString() =>
      '${isError ? 'ERROR' : 'WARN '} ${kind.name} $subject: $message '
      '[$origin]';
}

/// The outcome of one `<datasource>/<schema>` convergence check.
class TomSchemaConvergenceReport {
  /// The datasource directory this report covers.
  final String datasource;

  /// The schema directory this report covers.
  final String schema;

  /// The migration artifacts that were replayed, in the order they were applied.
  final List<String> chain;

  /// Every finding, errors and warnings alike, in table order.
  final List<TomSchemaDivergence> divergences;

  /// Records the outcome.
  const TomSchemaConvergenceReport({
    required this.datasource,
    required this.schema,
    required this.chain,
    required this.divergences,
  });

  /// The findings that fail the check.
  List<TomSchemaDivergence> get errors => [
    for (final divergence in divergences)
      if (divergence.isError) divergence,
  ];

  /// The findings that are worth knowing but do not fail the check.
  List<TomSchemaDivergence> get warnings => [
    for (final divergence in divergences)
      if (!divergence.isError) divergence,
  ];

  /// Whether the two sides agree — no errors. Warnings do not break convergence.
  bool get converged => errors.isEmpty;

  /// A human-readable rendering: the verdict, then every finding.
  String describe() {
    final buffer = StringBuffer()
      ..writeln(
        '$datasource/$schema: ${converged ? 'converged' : 'DIVERGED'} '
        '(${chain.length} migration(s), ${errors.length} error(s), '
        '${warnings.length} warning(s))',
      );
    for (final divergence in divergences) {
      buffer.writeln('  $divergence');
    }
    return buffer.toString();
  }

  @override
  String toString() =>
      'TomSchemaConvergenceReport($datasource/$schema, '
      'converged: $converged, ${divergences.length} finding(s))';
}

/// The named CodeSpecs validator check that proves CE-DB and CE-MG agree.
///
/// ## Using it
///
/// [checkAll] walks a whole `<databaseMigrationsDirectory>` tree and returns one
/// report per `<datasource>/<schema>` pair; [checkSchema] does a single pair.
/// Both are asynchronous only because they read files — no database is opened,
/// and none needs to exist. [verify] is the pure core: hand it an already-read
/// chain and the entity types, and it computes the report with no I/O at all.
///
/// ## Ordering
///
/// The chain is ordered and environment-filtered through
/// [TomDbMigrations.orderMigrationNames] and
/// [TomDbMigrations.selectForEnvironment] — the very functions the engine uses —
/// so the replay order is the applied order by construction rather than by a
/// second implementation that could drift. This check reads that model; it does
/// not change it.
class TomSchemaConvergenceCheck {
  /// The stable name this check is referred to by.
  ///
  /// No CodeSpecs validator *runtime* exists yet — `tom_code_specs` is
  /// annotations only. The name is fixed here so that when one arrives it has a
  /// check to register rather than a behaviour to re-derive.
  static const String checkName = 'ce-mg.schema-convergence';

  /// The dialect the actual side's SQL types are classified with.
  final TomStandardSqlDialect dialect;

  /// The environment migrations are filtered for, as
  /// [TomDbMigrations.resolveActiveEnvironment] would resolve it when omitted.
  final String environment;

  /// Creates a check.
  ///
  /// [dialect] defaults to [MariadbSqlDialect] — the only dialect with a
  /// migration adaptor today, and the one whose `TINYINT(1)` spelling of a
  /// boolean the classification has to know about.
  TomSchemaConvergenceCheck({
    TomStandardSqlDialect? dialect,
    String? environment,
  }) : dialect = dialect ?? MariadbSqlDialect(),
       environment = environment ?? TomDbMigrations.resolveActiveEnvironment();

  /// Checks every `<datasource>/<schema>` pair under [migrationsDirectory].
  ///
  /// [entityTypes] defaults to every `@TomDbTable` type known to `tomReflector`.
  /// A datasource directory with several schemas whose entities declare no
  /// [TomDbTable.schema] yields an [TomSchemaDivergenceKind.ambiguousEntitySchema]
  /// error rather than an arbitrary attribution.
  Future<List<TomSchemaConvergenceReport>> checkAll(
    String migrationsDirectory, {
    Iterable<Type>? entityTypes,
  }) async {
    final types = entityTypes ?? TomEntitySchemaReader.discoverEntityTypes();
    final reports = <TomSchemaConvergenceReport>[];
    final root = Directory(migrationsDirectory);
    if (!root.existsSync()) return reports;
    for (final datasourceDirectory in _subdirectories(root)) {
      final datasource = p.basename(datasourceDirectory.path);
      final schemaDirectories = _subdirectories(datasourceDirectory);
      final ambiguous = schemaDirectories.length > 1;
      for (final schemaDirectory in schemaDirectories) {
        final schema = p.basename(schemaDirectory.path);
        reports.add(
          verify(
            datasource: datasource,
            schema: schema,
            chain: readChain(schemaDirectory.path),
            entityTypes: types,
            reportUnschemedEntitiesAsAmbiguous: ambiguous,
          ),
        );
      }
    }
    return reports;
  }

  /// Checks the single pair [datasource] / [schema] under [migrationsDirectory].
  Future<TomSchemaConvergenceReport> checkSchema(
    String migrationsDirectory,
    String datasource,
    String schema, {
    Iterable<Type>? entityTypes,
  }) async => verify(
    datasource: datasource,
    schema: schema,
    chain: readChain(p.join(migrationsDirectory, datasource, schema)),
    entityTypes: entityTypes ?? TomEntitySchemaReader.discoverEntityTypes(),
  );

  /// Reads the migration artifacts of one schema directory in applied order.
  ///
  /// Names are parsed, ordered by numeric version and filtered for
  /// [environment] exactly as the engine does; a malformed name throws
  /// [TomDbMigrationException] from the shared parser, because a name the engine
  /// would reject is a defect the check must not paper over.
  List<TomMigrationArtifact> readChain(String schemaDirectory) {
    final directory = Directory(schemaDirectory);
    if (!directory.existsSync()) return const [];
    final files = <String, File>{};
    for (final entry in directory.listSync()) {
      if (entry is File) {
        files[p.basenameWithoutExtension(entry.path)] = entry;
      }
    }
    final ordered = TomDbMigrations.orderMigrationNames(files.keys);
    return [
      for (final entry
          in TomDbMigrations.selectForEnvironment(ordered, environment))
        TomMigrationArtifact(
          entry.basename,
          files[entry.basename]!.readAsStringSync(),
        ),
    ];
  }

  /// Computes the report for one pair — the pure core, with no I/O.
  ///
  /// [reportUnschemedEntitiesAsAmbiguous] is set by [checkAll] when the
  /// datasource has more than one schema directory; a caller naming a single
  /// pair has already resolved the attribution itself.
  TomSchemaConvergenceReport verify({
    required String datasource,
    required String schema,
    required List<TomMigrationArtifact> chain,
    required Iterable<Type> entityTypes,
    bool reportUnschemedEntitiesAsAmbiguous = false,
  }) {
    final selected = TomEntitySchemaReader.selectFor(
      entityTypes,
      datasource,
      schema,
    );
    final divergences = <TomSchemaDivergence>[];

    if (reportUnschemedEntitiesAsAmbiguous) {
      for (final type in selected) {
        if (TomAnnotationAnalyzer.findTable(type)?.schema != null) continue;
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.ambiguousEntitySchema,
            table: TomAnnotationAnalyzer.findTable(type)!.table,
            origin: '$type',
            message:
                'datasource "$datasource" has more than one schema directory '
                'but $type declares no schema, so it cannot be attributed to '
                '"$schema" or to any other',
          ),
        );
      }
    }

    final replay = TomSchemaDdlReader(dialect).replay(chain);
    for (final error in replay.errors) {
      divergences.add(
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.chainError,
          table: '',
          origin: error.artifact,
          message: '${error.message}: ${error.statement}',
        ),
      );
    }

    divergences.addAll(
      _diff(TomEntitySchemaReader.read(selected), replay.schema),
    );

    return TomSchemaConvergenceReport(
      datasource: datasource,
      schema: schema,
      chain: [for (final artifact in chain) artifact.basename],
      divergences: divergences,
    );
  }

  /// Diffs the [expected] entity-model schema against the [actual] replayed one.
  List<TomSchemaDivergence> _diff(
    TomSchemaModel expected,
    TomSchemaModel actual,
  ) {
    final divergences = <TomSchemaDivergence>[];
    for (final entry in expected.tables.entries) {
      final expectedTable = entry.value;
      final actualTable = actual.tables[entry.key];
      if (actualTable == null) {
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.missingTable,
            table: expectedTable.name,
            origin: expectedTable.origin,
            message:
                '${expectedTable.origin} maps to table "${expectedTable.name}", '
                'which the migration chain never creates',
          ),
        );
        continue;
      }
      divergences.addAll(_diffColumns(expectedTable, actualTable));
      divergences.addAll(_diffPrimaryKey(expectedTable, actualTable));
    }
    for (final entry in actual.tables.entries) {
      if (expected.tables.containsKey(entry.key)) continue;
      divergences.add(
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.unexpectedTable,
          table: entry.value.name,
          origin: entry.value.origin,
          message:
              'the migration chain creates table "${entry.value.name}", which '
              'no entity maps to',
          isError: false,
        ),
      );
    }
    return divergences;
  }

  List<TomSchemaDivergence> _diffColumns(
    TomSchemaTable expected,
    TomSchemaTable actual,
  ) {
    final divergences = <TomSchemaDivergence>[];
    for (final entry in expected.columns.entries) {
      final expectedColumn = entry.value;
      final actualColumn = actual.columns[entry.key];
      if (actualColumn == null) {
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.missingColumn,
            table: expected.name,
            column: expectedColumn.name,
            origin: '${expectedColumn.origin} vs ${actual.origin}',
            message:
                '${expectedColumn.origin} maps column "${expectedColumn.name}" '
                '(${expectedColumn.declaredType}), which no artifact adds to '
                '"${actual.name}" (created by ${actual.origin})',
          ),
        );
        continue;
      }
      if (expectedColumn.family.accepts(actualColumn.family)) continue;
      divergences.add(
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.columnTypeMismatch,
          table: expected.name,
          column: expectedColumn.name,
          origin: '${expectedColumn.origin} vs ${actualColumn.origin}',
          message:
              '${expectedColumn.origin} declares "${expectedColumn.name}" as '
              '${expectedColumn.declaredType} (${expectedColumn.family.name}) '
              'but ${actualColumn.origin} creates it as '
              '${actualColumn.declaredType} (${actualColumn.family.name})',
        ),
      );
    }
    for (final entry in actual.columns.entries) {
      if (expected.columns.containsKey(entry.key)) continue;
      divergences.add(
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.unmappedColumn,
          table: expected.name,
          column: entry.value.name,
          origin: entry.value.origin,
          message:
              '${entry.value.origin} creates column "${entry.value.name}" on '
              '"${actual.name}", which ${expected.origin} does not map',
          isError: false,
        ),
      );
    }
    return divergences;
  }

  /// Compares primary keys as case-insensitive **sets**.
  ///
  /// The entity model orders a composite key by field declaration order, which
  /// carries no intent — reporting a reordering as a divergence would be a false
  /// positive on a schema that is in fact correct.
  List<TomSchemaDivergence> _diffPrimaryKey(
    TomSchemaTable expected,
    TomSchemaTable actual,
  ) {
    final expectedKey = {for (final c in expected.primaryKey) c.toLowerCase()};
    final actualKey = {for (final c in actual.primaryKey) c.toLowerCase()};
    if (expectedKey.isEmpty && actualKey.isEmpty) return const [];
    if (expectedKey.length == actualKey.length &&
        expectedKey.containsAll(actualKey)) {
      return const [];
    }
    return [
      TomSchemaDivergence(
        kind: TomSchemaDivergenceKind.primaryKeyMismatch,
        table: expected.name,
        origin: '${expected.origin} vs ${actual.origin}',
        message:
            '${expected.origin} declares the primary key of "${expected.name}" '
            'as (${expected.primaryKey.join(', ')}) but ${actual.origin} '
            'creates it as '
            '(${actual.primaryKey.isEmpty ? 'none' : actual.primaryKey.join(', ')})',
      ),
    ];
  }

  static List<Directory> _subdirectories(Directory directory) => [
    for (final entry in directory.listSync())
      if (entry is Directory) entry,
  ]..sort((a, b) => a.path.compareTo(b.path));
}
