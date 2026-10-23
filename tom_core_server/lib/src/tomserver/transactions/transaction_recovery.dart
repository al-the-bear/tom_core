/// Recovery of two-phase transactions a process left half-finished.
///
/// A process that dies between the two phases of a two-phase commit leaves
/// its branches PREPARED: durable, holding their locks, and resolved by
/// nobody. The coordinator therefore records its decision before the commit
/// phase — the transaction id and the ids of its prepared branches, in a
/// [TomTransactionDecisionLog] — and forgets it once every branch committed.
/// [TomTransactionRecovery.recover] then resolves what is left: it lists the
/// prepared branches of every two-phase data source (`XA RECOVER` on MariaDB,
/// `pg_prepared_xacts` on PostgreSQL), commits those the log records as
/// decided, rolls back the rest, and forgets the decisions nothing is left
/// of. The log, not the branch, is the authority on what was decided.
///
/// A recovery touches only branches this framework created (the branch id
/// names the data source it was opened through) and older than
/// [TomTransactionRecovery.minimumAge]: a younger branch may belong to a live
/// process between its two phases, which is resolving it itself.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'transaction_manager.dart';

/// Thrown when transaction recovery is misconfigured.
class TomTransactionRecoveryException extends TomServerException {
  /// Creates the exception with [key] and [defaultUserMessage].
  TomTransactionRecoveryException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
  });
}

/// A data source whose two-phase branches a recovery can list and resolve.
abstract interface class TomTwoPhaseRecoverable {
  /// The name it describes itself by in a report.
  String get recoveryLabel;

  /// The ids of the branches prepared on its database and not yet resolved.
  Future<List<String>> listPreparedBranches();

  /// Whether [branchId] is a branch this data source's kind opened on its
  /// database.
  bool ownsBranch(String branchId);

  /// When [branchId] was opened, read from the id, or `null` when it does not
  /// say.
  DateTime? branchOpenedAt(String branchId);

  /// Commits the prepared branch [branchId].
  Future<void> commitPreparedBranch(String branchId);

  /// Rolls the prepared branch [branchId] back.
  Future<void> rollbackPreparedBranch(String branchId);
}

/// What one [TomTransactionRecovery.recover] did.
class TomRecoveryReport {
  /// Branches committed because their transaction had decided to commit.
  final List<String> committed = [];

  /// Branches rolled back because no decision was recorded for them.
  final List<String> rolledBack = [];

  /// Branches left alone because they were younger than the minimum age.
  final List<String> tooYoung = [];

  /// Branches whose resolution failed, with the error.
  final Map<String, String> failed = {};

  /// Decisions forgotten because none of their branches is left.
  final List<String> forgotten = [];

  /// Whether every branch found was resolved or deliberately left alone.
  bool get isClean => failed.isEmpty;

  @override
  String toString() =>
      'TomRecoveryReport(committed: ${committed.length}, rolled back: '
      '${rolledBack.length}, too young: ${tooYoung.length}, failed: '
      '${failed.length}, forgotten: ${forgotten.length})';
}

/// Records decisions in memory — for a test, or a process that has no
/// two-phase data source; it does not survive the process it protects.
class TomMemoryDecisionLog implements TomTransactionDecisionLog {
  final Map<String, Set<String>> _decisions = {};

  @override
  Future<void> recordCommit(String transactionId, List<String> branches) async {
    _decisions[transactionId] = {...branches};
  }

  @override
  Future<void> forget(String transactionId) async {
    _decisions.remove(transactionId);
  }

  @override
  Future<Map<String, Set<String>>> decisions() async => {
    for (final e in _decisions.entries) e.key: {...e.value},
  };
}

/// The default name of the decision table.
const String defaultDecisionTable = 'tom_transaction_decision';

/// The decision table [table], declared once: one row per decided branch,
/// keyed by `(transaction_id, branch_id)`.
TomFrameworkTable decisionTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'decisionTable',
  columns: const [
    TomFrameworkColumn('transaction_id', 'VARCHAR(64)'),
    TomFrameworkColumn('branch_id', 'VARCHAR(200)'),
    TomFrameworkColumn('decided_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['transaction_id', 'branch_id'],
);

/// The DDL of the decision table [table].
String decisionTableDdl(String table) => decisionTable(table).createTableDdl;

/// Records decisions in [table] of the data source registered as
/// [datasourceName] — a one-phase data source: the record has to be durable
/// before the commit phase, on its own, and a two-phase source would hold it
/// in a branch of its own.
class TomSqlDecisionLog implements TomTransactionDecisionLog {
  /// A log in [table] of [datasourceName]; with [createSchema] the table is
  /// created on first use.
  TomSqlDecisionLog(
    this.datasourceName, {
    this.table = defaultDecisionTable,
    this.createSchema = true,
  });

  /// The registered name of the data source.
  final String datasourceName;

  /// The table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  late final TomFrameworkTable _table = decisionTable(table);
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  Future<TomDataSource> _datasource() async {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomTransactionRecoveryException(
        'transactions.recovery.no_datasource',
        "The decision log's data source '$datasourceName' is not registered.",
        parameters: {'datasource': datasourceName},
      );
    }
    final ds = info.datasource;
    if (createSchema) await _schema.ensure(() => _table.create(ds));
    return ds;
  }

  /// One statement for every branch: a decision is recorded whole or not at
  /// all, so a process dying during the write cannot leave a record naming
  /// some of its branches — which a recovery would commit, rolling back the
  /// others.
  @override
  Future<void> recordCommit(String transactionId, List<String> branches) async {
    final ds = await _datasource();
    final at = sqlInstant(DateTime.now().toUtc());
    await ds.executeCommand(
      'INSERT INTO $table (transaction_id, branch_id, decided_at) VALUES '
      '${[for (var i = 0; i < branches.length; i++) '(:tx, :b$i, :at)'].join(', ')}',
      {
        'tx': transactionId,
        'at': at,
        for (var i = 0; i < branches.length; i++) 'b$i': branches[i],
      },
    );
  }

  @override
  Future<void> forget(String transactionId) async {
    final ds = await _datasource();
    await ds.executeCommand('DELETE FROM $table WHERE transaction_id = :tx', {
      'tx': transactionId,
    });
  }

  @override
  Future<Map<String, Set<String>>> decisions() async {
    final ds = await _datasource();
    final rows = await ds.executeQuery<TomDecisionRow>(
      'SELECT transaction_id, branch_id, decided_at FROM $table',
    );
    final decisions = <String, Set<String>>{};
    for (final row in rows) {
      (decisions[row.transactionId] ??= {}).add(row.branchId);
    }
    return decisions;
  }
}

/// One row of the decision table.
@tomReflector
@TomDbTable(
  datasource: 'irrelevant',
  table: 'irrelevant',
  primaryKeyFields: ['transactionId', 'branchId'],
)
class TomDecisionRow {
  /// The transaction that decided.
  @TomDbColumn(columnName: 'transaction_id')
  String transactionId = '';

  /// A branch it decided to commit.
  @TomDbColumn(columnName: 'branch_id')
  String branchId = '';

  /// When.
  @TomDbColumn(columnName: 'decided_at')
  DateTime decidedAt = DateTime.utc(1970);
}

/// Resolves the prepared branches a dead process left behind.
abstract final class TomTransactionRecovery {
  /// The configuration key of the server configuration.
  static const String configurationKey = 'transactions';

  /// How old a prepared branch has to be before a recovery resolves it.
  static Duration minimumAge = const Duration(minutes: 1);

  /// Whether the server recovers at start ([configure] sets it).
  static bool recoverOnStart = false;

  /// Applies the `transactions` section of the server configuration:
  ///
  /// ```yaml
  /// transactions:
  ///   decisionLog: main            # a one-phase data source
  ///   decisionTable: tom_transaction_decision
  ///   createSchema: true
  ///   recoverOnStart: true
  ///   recoveryMinimumAgeSeconds: 60
  /// ```
  ///
  /// `null` leaves everything as it is. Without `decisionLog` no decision is
  /// recorded, and a recovery can only roll branches back.
  static void configure(Object? config) {
    if (config == null) return;
    if (config is! Map) {
      throw TomTransactionRecoveryException(
        'transactions.recovery.config.invalid',
        'The transactions settings must be a map, not a ${config.runtimeType}.',
      );
    }
    final log = config['decisionLog'];
    if (log != null) {
      TomTransactionManager.decisionLog = TomSqlDecisionLog(
        '$log',
        table: '${config['decisionTable'] ?? defaultDecisionTable}',
        createSchema: config['createSchema'] != false,
      );
    }
    recoverOnStart = config['recoverOnStart'] == true;
    final age = config['recoveryMinimumAgeSeconds'];
    if (age != null) {
      final seconds = age is int ? age : int.tryParse('$age');
      if (seconds == null || seconds < 0) {
        throw TomTransactionRecoveryException(
          'transactions.recovery.config.invalid',
          "The transactions setting 'recoveryMinimumAgeSeconds' must be a "
              "whole number of seconds, not '$age'.",
        );
      }
      minimumAge = Duration(seconds: seconds);
    }
  }

  /// Restores the defaults. For tests.
  static void reset() {
    TomTransactionManager.decisionLog = null;
    minimumAge = const Duration(minutes: 1);
    recoverOnStart = false;
  }

  /// Resolves the prepared branches of [sources] — every registered
  /// two-phase data source when `null` — against the decisions of [log] —
  /// [TomTransactionManager.decisionLog] when `null`, and then none.
  ///
  /// A failure to resolve one branch is reported and the rest are still
  /// resolved; another node recovering at the same time is one cause.
  static Future<TomRecoveryReport> recover({
    Iterable<TomTwoPhaseRecoverable>? sources,
    TomTransactionDecisionLog? log,
    DateTime? now,
  }) async {
    final report = TomRecoveryReport();
    final decisionLog = log ?? TomTransactionManager.decisionLog;
    final decisions = decisionLog == null
        ? const <String, Set<String>>{}
        : await decisionLog.decisions();
    final decided = {for (final branches in decisions.values) ...branches};
    final at = now ?? DateTime.now().toUtc();
    final scanned = [
      ...?sources,
      if (sources == null)
        for (final info in TomDataSourceInfo.datasources.values)
          if (info.isOperational && info.datasource is TomTwoPhaseRecoverable)
            info.datasource as TomTwoPhaseRecoverable,
    ];
    final stillPrepared = <String>{};
    for (final source in scanned) {
      for (final branch in await source.listPreparedBranches()) {
        if (!source.ownsBranch(branch)) continue;
        final opened = source.branchOpenedAt(branch);
        if (opened != null && at.difference(opened) < minimumAge) {
          report.tooYoung.add(branch);
          stillPrepared.add(branch);
          continue;
        }
        final commit = decided.contains(branch);
        try {
          if (commit) {
            await source.commitPreparedBranch(branch);
            report.committed.add(branch);
          } else {
            await source.rollbackPreparedBranch(branch);
            report.rolledBack.add(branch);
          }
          tomLog.info(
            "Transaction recovery ${commit ? 'committed' : 'rolled back'} "
            "branch $branch on ${source.recoveryLabel}.",
          );
        } catch (error) {
          report.failed[branch] = '$error';
          stillPrepared.add(branch);
          tomLog.error(
            "Transaction recovery could not resolve branch $branch on "
            "${source.recoveryLabel}: $error",
          );
        }
      }
    }
    if (decisionLog != null) {
      for (final MapEntry(key: transaction, value: branches)
          in decisions.entries) {
        final known = branches.every(
          (b) => scanned.any((source) => source.ownsBranch(b)),
        );
        if (known && branches.every((b) => !stillPrepared.contains(b))) {
          await decisionLog.forget(transaction);
          report.forgotten.add(transaction);
        }
      }
    }
    return report;
  }
}
