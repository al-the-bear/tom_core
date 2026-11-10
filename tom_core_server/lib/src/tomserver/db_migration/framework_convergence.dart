/// The convergence guard for the tables the **framework** owns.
///
/// `TomSchemaConvergenceCheck` proves that an *application's* migration chain
/// builds the shape its entity model declares. The framework's own tables — the
/// job queue, the lease table, the roll call, the blob pair, the audit trail —
/// are not entities, so they sat outside that guard. This is the same comparison
/// pointed at them.
///
/// ## What "one declaration" means here
///
/// Each framework table is declared once, as a [TomFrameworkTable]. This file
/// relates that declaration to the three other places its columns could
/// otherwise be spelled independently:
///
/// * [verifyChain] — against the **shipped reference migration** a deployment
///   applies when the migration module owns the schema, rather than letting the
///   store create it. The two must build the same table or a migrated deployment
///   and a self-provisioning one diverge.
/// * [verifyRowTypes] — against the **reflected row types** the data source's
///   mapper materialises. A row type is the other half of every `SELECT`: it
///   names the columns the statement projected. Binding it to the descriptor is
///   what makes a rename in the descriptor, left unmade in the statement, a
///   compile-free but test-caught failure.
/// * [verifyLive] — against a **provisioned database**, read from
///   `information_schema`. The only one of the three that can catch a schema
///   that was applied once and edited by hand afterwards, and therefore the only
///   one that needs a server; it is tagged `db` wherever it is used.
///
/// ## Why the model is replayed rather than translated
///
/// [modelOf] does not walk a descriptor's columns and classify their SQL types.
/// It renders the descriptor's `CREATE TABLE` and replays it through
/// [TomSchemaDdlReader] — the very reader the migration side uses. A second
/// classifier would be a second opinion about what `TINYINT(1)` means, and two
/// opinions that agree today are two opinions that can diverge; one parser
/// cannot disagree with itself.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/sql_audit_sql.dart';
import '../audit_reports/audit_question_sql.dart';
import '../authentication/oauth_state_sql.dart';
import '../authentication/scim_sql.dart';
import '../cache/invalidation_sql.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/mariadb_sql_dialect.dart';
import '../datasources/sql_dialects.dart';
import '../export/export_register_sql.dart';
import '../file_storage/blob_ledger_sql.dart';
import '../file_storage/database_blob_sql.dart';
import '../messaging/delivery_report_sql.dart';
import '../endpoints/idempotency_sql.dart';
import '../messaging/inbox_sql.dart';
import '../messaging/suppression_sql.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/field_encryption_sql.dart';
import '../object_persistence/persistence_annotations.dart';
import '../privacy/subject_keys_sql.dart';
import '../sync/sync_sql.dart';
import '../tenancy/tenant_registry_sql.dart';
import '../scheduling/sql_scheduling_sql.dart';
import '../transactions/saga_sql.dart';
import '../transactions/transaction_recovery.dart';
import 'schema_convergence.dart';
import 'schema_ddl_reader.dart';
import 'schema_model.dart';

/// Every table the framework owns, at the names it uses when nothing overrides
/// them.
///
/// The list exists so "all of them" is a thing that can be named. A deployment
/// that renames a table passes the corresponding argument; one that does not —
/// which is nearly all of them — gets the shipped set. Without this, each caller
/// would assemble its own list, and a table added to the framework later would
/// be checked wherever someone remembered to add it.
///
/// The direction of the dependency is deliberate: this module reaches into
/// `scheduling/`, `file_storage/`, `audit/`, `authentication/`, `messaging/`,
/// `cache/`, `endpoints/`, `transactions/`, `object_persistence/`, `privacy/`,
/// `export/`, `sync/` and `tenancy/` for their descriptors, and none of them
/// reaches back.
/// A deployment can run the scheduler without ever loading a migration.
List<TomFrameworkTable> frameworkOwnedTables({
  String jobRun = defaultJobRunTable,
  String lease = defaultLeaseTable,
  String schedulerNode = defaultSchedulerNodeTable,
  String jobPause = defaultJobPauseTable,
  String jobRunArchive = defaultJobRunArchiveTable,
  String blobManifest = defaultBlobManifestTable,
  String blobChunk = defaultBlobChunkTable,
  String blobLedger = defaultBlobLedgerTable,
  String blobContent = defaultBlobContentTable,
  String auditTrail = defaultAuditTrailTable,
  String auditQuestion = defaultAuditQuestionTable,
  String oauthState = defaultOAuthStateTable,
  String deliveryReport = defaultDeliveryReportTable,
  String suppression = defaultSuppressionTable,
  String invalidation = defaultInvalidationTable,
  String scimResource = defaultScimResourceTable,
  String inbox = defaultInboxTable,
  String idempotency = defaultIdempotencyTable,
  String saga = defaultSagaTable,
  String encryptionKey = defaultEncryptionKeyTable,
  String subjectKey = defaultSubjectKeyTable,
  String decision = defaultDecisionTable,
  String exportRegister = defaultExportRegisterTable,
  String syncChange = defaultSyncChangeTable,
  String syncSequence = defaultSyncSequenceTable,
  String tenant = defaultTenantTable,
}) => [
  jobRunTable(jobRun),
  leaseTable(lease),
  schedulerNodeTable(schedulerNode),
  jobPauseTable(jobPause),
  jobRunArchiveTable(jobRunArchive),
  blobManifestTable(blobManifest),
  blobChunkTable(blobChunk),
  blobLedgerTable(blobLedger),
  blobContentTable(blobContent),
  auditTrailTable(auditTrail),
  auditQuestionTable(auditQuestion),
  oauthStateTable(oauthState),
  deliveryReportTable(deliveryReport),
  suppressionTable(suppression),
  invalidationTable(invalidation),
  scimResourceTable(scimResource),
  inboxTable(inbox),
  idempotencyTable(idempotency),
  sagaTable(saga),
  encryptionKeyTable(encryptionKey),
  subjectKeyTable(subjectKey),
  decisionTable(decision),
  exportRegisterTable(exportRegister),
  syncChangeTable(syncChange),
  syncSequenceTable(syncSequence),
  tenantTable(tenant),
];

/// Compares framework-owned table descriptors against everything else that
/// spells their columns.
class TomFrameworkSchemaCheck {
  /// The stable name this check is referred to by.
  ///
  /// Deliberately a sibling of [TomSchemaConvergenceCheck.checkName] rather than
  /// the same name: the application check can only run where an application's
  /// entities and migrations exist, while this one holds for the framework
  /// itself and is meaningful in an empty project.
  static const String checkName = 'ce-fw.schema-convergence';

  /// The dialect SQL types are classified with.
  final TomStandardSqlDialect dialect;

  /// The diff both this check and the application check are expressed in.
  final TomSchemaConvergenceCheck _comparison;

  /// Creates a check.
  ///
  /// [dialect] defaults to [MariadbSqlDialect]: the descriptors declare their
  /// types in MariaDB's spelling, whose `TINYINT(1)` truth value the
  /// classification has to know about. [verifyLive] classifies in the
  /// connected database's own dialect instead.
  TomFrameworkSchemaCheck({TomStandardSqlDialect? dialect})
    : dialect = dialect ?? MariadbSqlDialect(),
      _comparison = TomSchemaConvergenceCheck(dialect: dialect);

  /// The schema [tables] declare, in the vocabulary the diff compares in.
  TomSchemaModel modelOf(Iterable<TomFrameworkTable> tables) {
    final replay = TomSchemaDdlReader(dialect).replay([
      for (final table in tables)
        TomMigrationArtifact(table.origin, table.createTableDdl),
    ]);
    // A descriptor that will not replay is a defect in this file's DDL
    // rendering, not in anything it was asked to check — so it is thrown rather
    // than reported as a divergence of the subject under test.
    if (replay.errors.isNotEmpty) {
      // throws-outside-family: programmer error — the framework's own
      // descriptors rendering DDL that does not replay is a defect in this
      // package, never a divergence of the subject.
      throw StateError(
        'A framework table descriptor produced DDL that could not be replayed: '
        '${replay.errors.map((e) => '${e.artifact}: ${e.message}').join('; ')}',
      );
    }
    return replay.schema;
  }

  /// Checks [tables] against the migration [chain] that also builds them.
  ///
  /// The chain is filtered down to the descriptors' tables before the diff, so a
  /// chain that legitimately creates other tables — an application's own, or the
  /// migration engine's version table — does not produce a warning per table.
  /// What is being asked here is only "does the chain build *these* correctly".
  TomSchemaConvergenceReport verifyChain({
    required String datasource,
    required String schema,
    required Iterable<TomFrameworkTable> tables,
    required List<TomMigrationArtifact> chain,
  }) {
    final expected = modelOf(tables);
    final replay = TomSchemaDdlReader(dialect).replay(chain);
    final divergences = <TomSchemaDivergence>[
      for (final error in replay.errors)
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.chainError,
          table: '',
          origin: error.artifact,
          message: '${error.message}: ${error.statement}',
        ),
      ..._comparison.diff(expected, _restrict(replay.schema, expected)),
    ];
    return TomSchemaConvergenceReport(
      datasource: datasource,
      schema: schema,
      chain: [for (final artifact in chain) artifact.basename],
      divergences: divergences,
    );
  }

  /// Checks that every column [rowTypes] map is one [table] declares.
  ///
  /// This is the guard on the half of a statement a generated column list cannot
  /// cover. A `SELECT` names columns and a row type maps them; if the descriptor
  /// renames a column and the mapper is not changed with it, the projection
  /// still compiles and still type-checks — it simply returns nothing at
  /// runtime, on whichever path happens to use it.
  ///
  /// The asymmetry is deliberate. A column a row type maps but the table does
  /// not declare is an **error**: the projection cannot work. A column the table
  /// declares that no row type maps is a **warning**: a row type may legitimately
  /// project a subset, and several do — `TomBlobChunkRow` reads only
  /// `chunk_data`, `TomAuditHeadRow` only the two values that recover a chain
  /// head.
  ///
  /// A `String` field is exempt from the type comparison, and that is not a
  /// loophole. The MariaDB driver decodes **every** column value into a Dart
  /// `String` before the mapper sees it, so a `String` field is the driver's raw
  /// form and claims nothing about the column's SQL type — the scheduling row
  /// types read their `DATETIME(6)` columns as text on purpose, and parse them
  /// with `parseSqlInstant`. A field of any other type *is* a coercion claim,
  /// and is checked.
  List<TomSchemaDivergence> verifyRowTypes(
    TomFrameworkTable table,
    Iterable<Type> rowTypes,
  ) {
    final divergences = <TomSchemaDivergence>[];
    final mapped = <String>{};
    for (final type in rowTypes) {
      final info = TomAnnotationAnalyzer.analysePersistentType(type);
      for (final column in info.columnInfo) {
        if (column.reference != null) continue;
        final name = column.getQueryFieldName();
        mapped.add(name.toLowerCase());
        final declared = table.column(name);
        if (declared == null) {
          divergences.add(
            TomSchemaDivergence(
              kind: TomSchemaDivergenceKind.missingColumn,
              table: table.name,
              column: name,
              origin: '$type vs ${table.origin}',
              message:
                  '$type maps column "$name", which ${table.origin} does not '
                  'declare on "${table.name}" (has: ${table.columnList})',
            ),
          );
          continue;
        }
        final expected = TomAnnotationAnalyzer.familyOf(column);
        final actual = dialect.typeFamily(declared.type);
        if (expected == TomSqlTypeFamily.text) continue;
        if (expected.accepts(actual)) continue;
        divergences.add(
          TomSchemaDivergence(
            kind: TomSchemaDivergenceKind.columnTypeMismatch,
            table: table.name,
            column: name,
            origin: '$type vs ${table.origin}',
            message:
                '$type reads "$name" as '
                '${TomAnnotationAnalyzer.describeDeclaredType(column)} '
                '(${expected.name}) but ${table.origin} declares it '
                '${declared.type} (${actual.name})',
          ),
        );
      }
    }
    for (final column in table.columns) {
      if (mapped.contains(column.name.toLowerCase())) continue;
      divergences.add(
        TomSchemaDivergence(
          kind: TomSchemaDivergenceKind.unmappedColumn,
          table: table.name,
          column: column.name,
          origin: table.origin,
          message:
              '${table.origin} declares "${column.name}" on "${table.name}", '
              'which no supplied row type maps',
          isError: false,
        ),
      );
    }
    return divergences;
  }

  /// Checks [tables] against the schema [datasource] is actually connected to.
  ///
  /// Needs a server, which is why it is separate from [verifyChain] rather than
  /// folded into it — but it is the only variant that can catch the case neither
  /// of the others can: a database whose schema was applied correctly once and
  /// then edited outside the migration chain.
  ///
  /// `DATABASE()` rather than a configured schema name, so the check asks the
  /// connection what it is connected to instead of being told, and cannot be
  /// pointed at the wrong schema by a stale setting.
  Future<TomSchemaConvergenceReport> verifyLive(
    TomDataSource datasource,
    Iterable<TomFrameworkTable> tables, {
    String datasourceName = 'live',
    String schema = 'DATABASE()',
  }) async {
    // Classified in the connected database's own dialect, on both sides: the
    // descriptors' canonical `TINYINT(1)` is a truth value to MariaDB and the
    // `smallint` PostgreSQL stores it as is an integer to PostgreSQL, so each
    // side has to be read the way the other one will be.
    final live = datasource.sqlDialect;
    final expected = TomFrameworkSchemaCheck(dialect: live).modelOf(tables);
    final builder = TomSchemaBuilder();
    for (final table in tables) {
      final rows = await datasource.executeQuery<TomInformationSchemaColumnRow>(
        live.tableColumnsQuery,
        {'table': table.name},
      );
      // No rows means no such table — the diff reports it as missing, which is
      // the accurate finding and a better one than an empty table would be.
      if (rows.isEmpty) continue;
      const origin = 'information_schema';
      builder.addTable(table.name, origin);
      for (final row in rows) {
        builder.addColumn(
          table.name,
          TomSchemaColumn(
            name: row.columnName,
            // COLUMN_TYPE, not DATA_TYPE: the latter drops the length, and
            // `TINYINT(1)` without its length is an ordinary integer rather
            // than MariaDB's spelling of a truth value.
            family: live.typeFamily(row.columnType),
            declaredType: row.columnType,
            origin: origin,
            nullable: row.isNullable.toUpperCase() == 'YES',
          ),
        );
      }
      builder.setPrimaryKey(table.name, [
        for (final row in rows)
          if (row.columnKey.toUpperCase() == 'PRI') row.columnName,
      ]);
    }
    return TomSchemaConvergenceReport(
      datasource: datasourceName,
      schema: schema,
      chain: const ['information_schema'],
      divergences: TomSchemaConvergenceCheck(
        dialect: live,
      ).diff(expected, builder.build()),
    );
  }

  /// [actual] narrowed to the tables [expected] declares.
  static TomSchemaModel _restrict(
    TomSchemaModel actual,
    TomSchemaModel expected,
  ) => TomSchemaModel({
    for (final entry in actual.tables.entries)
      if (expected.tables.containsKey(entry.key)) entry.key: entry.value,
  });
}

/// One `information_schema.COLUMNS` row, as the live framework-schema check
/// reads it.
///
/// The columns are aliased to lower case in the query because the mapper matches
/// by name and `information_schema` spells its own columns in upper case.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomInformationSchemaColumnRow {
  /// The column's name.
  @TomDbColumn(columnName: "column_name")
  String columnName = "";

  /// The full type including length — `varchar(191)`, `tinyint(1)`.
  @TomDbColumn(columnName: "column_type")
  String columnType = "";

  /// `YES` when the column accepts `NULL`.
  @TomDbColumn(columnName: "is_nullable")
  String isNullable = "";

  /// `PRI` when the column is part of the primary key.
  @TomDbColumn(columnName: "column_key")
  String columnKey = "";
}
