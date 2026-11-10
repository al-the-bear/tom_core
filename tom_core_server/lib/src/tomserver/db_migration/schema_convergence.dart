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
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/persistence_annotations.dart';
import 'db_migration.dart';
import 'schema_ddl_reader.dart';
import 'schema_model.dart';

/// Whether two primary keys are the same key.
///
/// Compared as case-insensitive **sets**. The entity model orders a composite
/// key by field declaration order, which carries no intent, so reporting a
/// reordering as a disagreement would be a false positive on a key that is in
/// fact correct.
///
/// One function, because every primary-key comparison in the module runs
/// through it — entity against entity in [TomEntitySchemaReader.read], entity
/// against replayed DDL in [TomSchemaConvergenceCheck.diff]. Two tolerance
/// policies would let a key pass one comparison and fail the other, which is a
/// key nobody can act on.
bool _sameKey(List<String> a, List<String> b) {
  final left = {for (final column in a) column.toLowerCase()};
  final right = {for (final column in b) column.toLowerCase()};
  return left.length == right.length && left.containsAll(right);
}

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
///   ([TomSqlTypeFamily]), the primary key, and that a `@TomVersion` column is
///   `NOT NULL`.
/// * **Not compared, because the entity model does not declare it** — column
///   length and precision (`VARCHAR(255)` vs `VARCHAR(64)`), defaults,
///   `AUTO_INCREMENT`, unique keys, secondary indexes, foreign keys, charset,
///   collation and engine.
/// * **Not compared, because the entity side carries no usable signal** —
///   the nullability of any other column. Every mapped Dart field is nullable
///   so an unsaved record can exist, and [TomColumnInformation.declaredType]
///   erases nullability anyway (`int?` arrives as `int`). `@TomVersion` is the
///   one declaration that says a column must hold a value.
/// * **Out of scope entirely** — seed data, generated columns, partitioning and
///   stored routines.
class TomEntitySchemaReader {
  /// Every `@TomDbTable`-annotated type registered with `tomReflector`.
  ///
  /// The check discovers entities the same way the rest of the persistence layer
  /// does, so a type the repository can load is a type the check can see.
  static List<Type> discoverEntityTypes() => [
    for (final candidate in tomReflector.annotatedClasses)
      if (candidate.metadata.any((m) => m is TomDbTable))
        candidate.reflectedType,
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
    if (table.datasource.toLowerCase() != datasource.toLowerCase())
      return false;
    final declared = table.schema;
    return declared == null || declared.toLowerCase() == schema.toLowerCase();
  }

  /// Reduces [entityTypes] to the schema shape they declare, together with any
  /// contradiction *within* the entity model itself.
  ///
  /// Two entities mapping to the same table name is not an error — a table may
  /// legitimately be read through more than one projection — so their columns
  /// are merged, and the table's origin names the first entity that declared it.
  ///
  /// They must agree on the **primary key**, though, because a table has
  /// exactly one. The first entity to declare a table fixes its key; a later
  /// entity on the same table whose key differs (compared by [_sameKey], the
  /// same tolerance the diff applies to the DDL side) yields a
  /// [TomSchemaDivergenceKind.conflictingEntityPrimaryKey] and leaves the first
  /// declarer's key in place.
  ///
  /// Keeping the *first* key is what makes the reported [TomSchemaTable.origin]
  /// and the reported key describe the same entity. The alternatives are worse:
  /// letting the last entity win — which is what this did before — is a silent
  /// overwrite whose outcome depends on the caller's iteration order, and
  /// merging the two keys into a union would put a key in the model that
  /// *neither* entity declares, so every downstream comparison would run
  /// against a shape nobody wrote and report a second, invented divergence
  /// against the DDL.
  ///
  /// The *verdict* is therefore order-independent — both orders report the
  /// contradiction — while which key survives follows the origin by design.
  static ({TomSchemaModel schema, List<TomSchemaDivergence> divergences}) read(
    Iterable<Type> entityTypes,
  ) {
    final builder = TomSchemaBuilder();
    final divergences = <TomSchemaDivergence>[];
    // Keyed by lower-cased table name, like the builder's own map: what the
    // first entity to claim each table declared, so a later one can be
    // reconciled against it.
    final declared = <String, ({String origin, List<String> key})>{};
    for (final type in entityTypes) {
      final info = TomAnnotationAnalyzer.analysePersistentType(type);
      final table = info.table;
      final origin = '$type';
      final key = primaryKeyOf(info);
      final owner = declared[table.table.toLowerCase()];
      if (owner == null) {
        builder.addTable(table.table, origin);
        builder.setPrimaryKey(table.table, key);
        declared[table.table.toLowerCase()] = (origin: origin, key: key);
      } else if (!_sameKey(owner.key, key)) {
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.conflictingEntityPrimaryKey,
            table: table.table,
            origin: '${owner.origin} vs $origin',
            message:
                '${owner.origin} declares the primary key of "${table.table}" '
                'as (${owner.key.join(', ')}) but $origin, which maps to the '
                'same table, declares it as (${key.join(', ')}); a table has '
                'one primary key, so the entity model contradicts itself',
          ),
        );
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
            family: TomAnnotationAnalyzer.familyOf(column),
            declaredType: TomAnnotationAnalyzer.describeDeclaredType(column),
            origin: origin,
            // The one nullability the entity model declares: a version column
            // must hold a value, or no versioned save of its row can match.
            nullable: column.version == null,
          ),
        );
      }
    }
    return (schema: builder.build(), divergences: divergences);
  }

  /// The primary-key **column** names [info] declares, in declaration order.
  ///
  /// `@TomEntityId` is the primary signal and supports a composite key. When no
  /// field carries it, [TomDbTable.primaryKeyFields] is used — each field
  /// resolved through the column mapping, since it names a *field* and the DDL
  /// side knows only columns.
  static List<String> primaryKeyOf(TomTypePersistenceInfo info) {
    final annotated = [
      for (final column in info.columnInfo)
        if (column.entityId != null) column.getQueryFieldName(),
    ];
    if (annotated.isNotEmpty) return annotated;
    return [
      for (final keyField in info.table.primaryKeyFields)
        info.columnInfo
                .where((column) => column.declaredName == keyField)
                .firstOrNull
                ?.getQueryFieldName() ??
            keyField,
    ];
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

  /// An entity's `@TomVersion` column is nullable in the chain.
  ///
  /// An error rather than a warning: a versioned update matches its row by
  /// `version = ?`, and `NULL` equals nothing, so every save of a row whose
  /// version is `NULL` would be refused as a conflict. The column is added
  /// `NOT NULL` with a default.
  nullableVersionColumn,

  /// Two entities map to the same table but declare different primary keys.
  ///
  /// A contradiction *within* the entity model, reported before the migration
  /// chain is consulted at all: a table has exactly one primary key, so two
  /// projections of it cannot each be right. Distinct from
  /// [primaryKeyMismatch], which is the entity model disagreeing with the
  /// chain — the two have different culprits and different fixes, and reporting
  /// this one as that would send the reader to the migration scripts to correct
  /// something no migration script did.
  conflictingEntityPrimaryKey,

  /// A statement in the chain could not be replayed — the actual side of the
  /// comparison is incomplete, so everything downstream of it is unreliable.
  chainError,

  /// An entity declares no [TomDbTable.schema] in a datasource that has more
  /// than one schema directory, so which schema it belongs to is unknowable.
  ambiguousEntitySchema,

  /// A migration tree of one kind — `system/` or `tenant/` — creates a table
  /// of the other kind: a system table in a tenant type's tree would be built
  /// in every tenant's schema, a tenant table in the system tree only once.
  misplacedTable,
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
/// [verify] is the pure core: hand it an already-read chain and the entity
/// types, and it computes the report with no I/O at all.
///
/// ## Everything here is synchronous, and says so
///
/// No database is opened and none needs to exist; the only I/O is reading a
/// handful of migration files, which this module does synchronously throughout.
/// So these methods block, and their signatures admit it — across the module a
/// `Future` means a database is involved ([TomDbMigrations.migrateAll],
/// [TomDbMigrator.applyMigration], [TomFrameworkSchemaCheck.verifyLive]) and
/// nothing else does.
///
/// The honesty is not cosmetic. A future that is already complete before the
/// first `await` tells a caller the file walk is off the event loop when it is
/// not — which is exactly wrong for a check that runs at startup. Worse, it
/// makes the missing-directory refusal ignorable: a caller who omits the
/// `await` gets a value that reads as success, and the exception arrives later
/// as an unhandled rejection nothing is watching. That is the vacuous pass
/// [TomDbMigrations.requireMigrationsDirectory] exists to prevent. Thrown from
/// the call itself, it cannot be dropped.
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

  /// Checks every chain under the migration root [migrationsDirectory]:
  /// each `system/<datasource>/<schema>` pair against the system tables
  /// among [entityTypes], and each `tenant/<type>/<datasource>` chain against
  /// the tenant tables (`@TomTenantTable`), reported under the schema name
  /// [TomDbMigrations.tenantHistoryLabel] of the type.
  ///
  /// [entityTypes] defaults to every `@TomDbTable` type known to `tomReflector`.
  /// A system data-source directory with several schemas whose entities
  /// declare no [TomDbTable.schema] yields an
  /// [TomSchemaDivergenceKind.ambiguousEntitySchema] error rather than an
  /// arbitrary attribution.
  ///
  /// A [migrationsDirectory] that does not exist throws
  /// [TomDbMigrationException] via
  /// [TomDbMigrations.requireMigrationsDirectory] — the same refusal the engine
  /// gives the same path. An empty report list would be indistinguishable, at
  /// every call site, from "every pair converged", so a mistyped path would read
  /// as a clean bill of health. An *existing* but empty tree is a different
  /// thing and still yields no reports: there is genuinely nothing to check.
  List<TomSchemaConvergenceReport> checkAll(
    String migrationsDirectory, {
    Iterable<Type>? entityTypes,
  }) {
    final root = Directory(migrationsDirectory);
    TomDbMigrations.requireMigrationsDirectory(root, 'Migrations directory');
    final types = entityTypes ?? TomEntitySchemaReader.discoverEntityTypes();
    final systemTypes = [
      for (final type in types)
        if (!TomAnnotationAnalyzer.isTenantTable(type)) type,
    ];
    final tenantTypes = [
      for (final type in types)
        if (TomAnnotationAnalyzer.isTenantTable(type)) type,
    ];
    final reports = <TomSchemaConvergenceReport>[];
    final system = Directory(p.join(root.path, TomDbMigrations.systemTreeName));
    if (system.existsSync()) {
      for (final datasourceDirectory in _subdirectories(system)) {
        final datasource = p.basename(datasourceDirectory.path);
        final schemaDirectories = _subdirectories(datasourceDirectory);
        final ambiguous = schemaDirectories.length > 1;
        for (final schemaDirectory in schemaDirectories) {
          reports.add(
            verify(
              datasource: datasource,
              schema: p.basename(schemaDirectory.path),
              chain: readChain(schemaDirectory.path),
              entityTypes: systemTypes,
              reportUnschemedEntitiesAsAmbiguous: ambiguous,
            ),
          );
        }
      }
    }
    final tenant = Directory(
      p.join(root.path, TomDbMigrations.tenantTreesName),
    );
    if (tenant.existsSync()) {
      for (final typeDirectory in _subdirectories(tenant)) {
        final label = TomDbMigrations.tenantHistoryLabel(
          p.basename(typeDirectory.path),
        );
        for (final chain in _subdirectories(typeDirectory)) {
          reports.add(
            verify(
              datasource: p.basename(chain.path),
              schema: label,
              chain: readChain(chain.path),
              entityTypes: tenantTypes,
            ),
          );
        }
      }
    }
    return reports;
  }

  /// Checks the single system pair [datasource] / [schema] under the
  /// migration root [migrationsDirectory] (`system/<datasource>/<schema>`).
  ///
  /// [migrationsDirectory] is the tree root and must exist, exactly as it must
  /// for [checkAll] — the two take the same argument and cannot hold different
  /// opinions about it. The *pair* below it need not: a schema directory that
  /// was never created reads as an empty chain, which the report renders as
  /// every entity missing from the migrations. That is a finding, and producing
  /// findings is what this check is for.
  TomSchemaConvergenceReport checkSchema(
    String migrationsDirectory,
    String datasource,
    String schema, {
    Iterable<Type>? entityTypes,
  }) {
    TomDbMigrations.requireMigrationsDirectory(
      Directory(migrationsDirectory),
      'Migrations directory',
    );
    return verify(
      datasource: datasource,
      schema: schema,
      chain: readChain(
        p.join(
          migrationsDirectory,
          TomDbMigrations.systemTreeName,
          datasource,
          schema,
        ),
      ),
      entityTypes: entityTypes ?? TomEntitySchemaReader.discoverEntityTypes(),
    );
  }

  /// Reads the migration artifacts of one schema directory in applied order.
  ///
  /// Files are collected, parsed, ordered by numeric version and filtered for
  /// [environment] exactly as the engine does; a malformed name throws
  /// [TomDbMigrationException] from the shared parser, and two files whose
  /// basenames collide throw from the shared collector
  /// ([TomDbMigrations.collectMigrationFiles]) — because a tree the engine
  /// would reject is a defect the check must not paper over.
  ///
  /// A [schemaDirectory] that does not exist is the one absence this module
  /// does **not** treat as an error. It is content below a root that was
  /// already proven to exist, and an empty chain is the honest reading of it:
  /// [verify] then reports every entity as missing from the migrations, which
  /// localises the problem far better than an exception would. Contrast
  /// [checkAll] and [TomDbMigrations.migrateAll], where the absent
  /// directory is the *root* — an input, not content.
  List<TomMigrationArtifact> readChain(String schemaDirectory) {
    final directory = Directory(schemaDirectory);
    if (!directory.existsSync()) return const [];
    final files = TomDbMigrations.collectMigrationFiles(directory.listSync());
    final ordered = TomDbMigrations.orderMigrationNames(files.keys);
    return [
      for (final entry in TomDbMigrations.selectForEnvironment(
        ordered,
        environment,
      ))
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
        // One lookup, two uses. Written as two, the guard reads as though it
        // established a table — `?.schema != null` is false for a *missing*
        // table as much as for an unschemed one — and the second lookup would
        // then have to assert what the first did not check.
        final table = TomAnnotationAnalyzer.findTable(type);
        if (table == null || table.schema != null) continue;
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.ambiguousEntitySchema,
            table: table.table,
            origin: '$type',
            message:
                'datasource "$datasource" has more than one schema directory '
                'but $type declares no schema, so it cannot be attributed to '
                '"$schema" or to any other',
          ),
        );
      }
    }

    // Read the entity side first and take its self-contradictions with it: an
    // entity model that disagrees with itself is a defect of the model alone,
    // so it is reported next to the other entity-side finding above and ahead
    // of anything the chain has to say.
    final expected = TomEntitySchemaReader.read(selected);
    divergences.addAll(expected.divergences);

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

    divergences.addAll(diff(expected.schema, replay.schema));

    return TomSchemaConvergenceReport(
      datasource: datasource,
      schema: schema,
      chain: [for (final artifact in chain) artifact.basename],
      divergences: divergences,
    );
  }

  /// Diffs the [expected] declared schema against the [actual] built one.
  ///
  /// Public because it is the comparison itself, and the framework-owned tables
  /// are compared by the same rules through a different pair of sources — see
  /// `framework_convergence.dart`. Two diffs over one vocabulary would be two
  /// tolerance policies, and a schema that passes one and fails the other is a
  /// schema nobody can act on.
  List<TomSchemaDivergence> diff(
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
      if (!expectedColumn.nullable && actualColumn.nullable) {
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.nullableVersionColumn,
            table: expected.name,
            column: expectedColumn.name,
            origin: '${expectedColumn.origin} vs ${actualColumn.origin}',
            message:
                '${expectedColumn.origin} keeps its @TomVersion in '
                '"${expectedColumn.name}", which ${actualColumn.origin} creates '
                'nullable; a NULL version matches no versioned save, so the '
                'column must be NOT NULL (with a DEFAULT for existing rows)',
          ),
        );
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

  /// Compares the declared and the built primary key by [_sameKey].
  List<TomSchemaDivergence> _diffPrimaryKey(
    TomSchemaTable expected,
    TomSchemaTable actual,
  ) {
    if (_sameKey(expected.primaryKey, actual.primaryKey)) return const [];
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
