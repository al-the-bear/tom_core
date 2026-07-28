/// The relational job queue: one row per scheduled run, in the database the
/// application already has.
///
/// ## Why this exists one layer above the contract
///
/// `tom_core_kernel` defines [TomJobStore] and ships two implementations — an
/// in-memory one and a file-backed one. The file store is a correct multi-node
/// queue *wherever every node mounts the same filesystem*; where they do not,
/// there has to be something all the nodes can see, and in practice that is the
/// database they are already talking to. The kernel has no persistence layer,
/// so the relational implementation belongs here.
///
/// It is not merely the durable option. csex8 established that the queue and
/// the [TomLeaseLock] **must share a failure domain**: if the queue says one
/// node claimed a run while the lock says another node holds it, the
/// disagreement has no resolution. So this store is meant to be paired with
/// `TomSqlLeaseLock` over the same [TomDataSource] — one connection, one thing
/// to be up or down.
///
/// ## How a claim is arbitrated
///
/// The database decides who gets a run, never the application. A claim is a
/// conditional statement:
///
/// ```sql
/// UPDATE tom_job_run SET state='running', claimed_by=:owner, claimed_at=:now
///  WHERE id=:id AND state='pending'
/// ```
///
/// Exactly one of two racing nodes sees one affected row; the loser sees zero
/// and simply does not get that run. No read-then-write, no application-side
/// lock, no assumption that the scan the node did a moment ago is still true.
///
/// ### Why the claim is one statement *per run* rather than one for the batch
///
/// A single batched `UPDATE ... LIMIT n` would be the tidier shape, and it is
/// what a queue without a filter would use. But [claimDue] takes an `accept`
/// predicate and `TomScheduler` **always** supplies one — a stateful, order-
/// sensitive Dart closure that refuses a second window of a job already
/// dispatched in this tick. A Dart closure cannot run inside SQL, which leaves
/// two options:
///
///  * batch-claim first and release what `accept` rejects — but a rejected run
///    would be momentarily `running`, and a peer scanning in that window would
///    skip a run it *would* have accepted. Contention would then depend on
///    timing rather than on state;
///  * scan for candidates, filter in Dart, then claim each survivor
///    conditionally — which is what this does.
///
/// The `SELECT` is only a candidate scan; the `UPDATE` revalidates every
/// condition it relied on. The arbitration is still entirely the database's,
/// and a candidate that a peer claimed in between costs one failed update.
///
/// One visible consequence, and it is the conservative direction: when the
/// database refuses a claim, the scheduler's `accept` closure has already
/// recorded the job as busy for this tick, so that window waits for the next
/// one. A run is delayed by a tick, never executed twice.
///
/// ## Time
///
/// Instants are stored as `DATETIME(6)` in **UTC** and read back through
/// `String` columns rather than `DateTime` ones. The MariaDB driver materialises
/// a `DATETIME` with `DateTime.parse`, which yields a *local* `DateTime`; since
/// `DateTime.==` compares `isUtc` as well as the instant, a value written as UTC
/// would not compare equal to the value read back. Carrying the text and
/// converting here makes the round trip exact. A caller that writes a local
/// `DateTime` gets a UTC one back — the same instant, differently labelled,
/// which is the right answer for a cluster that must never compare wall clocks.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'sql_scheduling_sql.dart';

/// A [TomJobStore] whose queue is a table in a [TomDataSource].
class TomSqlJobStore implements TomJobStore {
  /// Creates a store over [datasource].
  ///
  /// [table] names the queue table. With [createSchema] left `true` the table
  /// is created on first use, which is what a test or a single-service
  /// deployment wants; set it `false` when the schema is owned by the migration
  /// module and the application's database user may not run DDL.
  ///
  /// [candidateFactor] bounds the candidate scan when an `accept` predicate is
  /// supplied: the scan reads up to `limit * candidateFactor` due runs so that
  /// rejected ones do not starve the accepted ones behind them. A rejected
  /// candidate costs a row read, not a claim.
  TomSqlJobStore(
    this.datasource, {
    this.table = defaultJobRunTable,
    this.createSchema = true,
    this.candidateFactor = 8,
  });

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] when no such data source is registered — a
  /// configuration error far better caught at start-up than on the first tick.
  factory TomSqlJobStore.named(
    String datasourceName, {
    String table = defaultJobRunTable,
    bool createSchema = true,
    int candidateFactor = 8,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'scheduling.store.unknown_datasource',
        'The job store refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlJobStore(
      info.datasource,
      table: table,
      createSchema: createSchema,
      candidateFactor: candidateFactor,
    );
  }

  /// The data source the queue table lives in.
  final TomDataSource datasource;

  /// The queue table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// How many due runs to consider per claim when a filter is present.
  final int candidateFactor;

  bool _schemaReady = false;

  static const String _columns =
      'id, job_name, scheduled_for, run_at, state, attempt, claimed_by, '
      'claimed_at, last_error, completed_at, payload';

  /// Creates the queue table if it does not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic.
  Future<void> ensureSchema() async {
    if (_schemaReady) return;
    if (createSchema) {
      await datasource.executeCommand(jobRunTableDdl(table));
    }
    _schemaReady = true;
  }

  @override
  Future<void> enqueue(TomJobRun run) async {
    await ensureSchema();
    // REPLACE rather than INSERT because enqueue is the store's only writer of
    // new rows and the scheduler may re-enqueue a window it is re-planning. The
    // unique key on (job_name, scheduled_for) is what keeps the idempotence key
    // a database invariant rather than a convention, so a second row for the
    // same window cannot exist even if a peer races this one.
    await datasource.executeCommand(
      'REPLACE INTO $table ($_columns) VALUES '
      '(:id, :jobName, :scheduledFor, :runAt, :state, :attempt, :claimedBy, '
      ':claimedAt, :lastError, :completedAt, :payload)',
      _bindOf(run),
    );
  }

  @override
  Future<TomJobRun?> findWindow(String jobName, DateTime scheduledFor) async {
    await ensureSchema();
    final rows = await _select(
      'WHERE job_name = :jobName AND scheduled_for = :scheduledFor LIMIT 1',
      {
        'jobName': jobName,
        'scheduledFor': sqlInstant(scheduledFor),
      },
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<DateTime?> lastWindow(String jobName) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomJobRunWindowRow>(
      'SELECT MAX(scheduled_for) AS scheduled_for FROM $table '
      'WHERE job_name = :jobName',
      {'jobName': jobName},
    );
    if (rows.isEmpty) return null;
    final value = rows.first.scheduledFor;
    return value == null || value.isEmpty ? null : parseSqlInstant(value);
  }

  @override
  Future<List<TomJobRun>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  }) async {
    await ensureSchema();
    final scanLimit = accept == null ? limit : limit * candidateFactor;
    final candidates = await _select(
      'WHERE state = :pending AND run_at <= :now ORDER BY seq LIMIT $scanLimit',
      {
        'pending': TomJobRunState.pending.name,
        'now': sqlInstant(now),
      },
    );

    final claimed = <TomJobRun>[];
    for (final run in candidates) {
      if (claimed.length >= limit) break;
      if (accept != null && !accept(run)) continue;
      final affected = await datasource.executeCommand(
        'UPDATE $table SET state = :running, claimed_by = :owner, '
        'claimed_at = :now WHERE id = :id AND state = :pending',
        {
          'running': TomJobRunState.running.name,
          'owner': owner,
          'now': sqlInstant(now),
          'id': run.id,
          'pending': TomJobRunState.pending.name,
        },
      );
      // Zero affected rows means a peer got there first. It is not an error and
      // it is the whole point: the database, not this process, decided.
      if (affected != BigInt.one) continue;
      run.state = TomJobRunState.running;
      run.claimedBy = owner;
      run.claimedAt = _asUtc(now);
      claimed.add(run);
    }
    return claimed;
  }

  @override
  Future<void> release(TomJobRun run) async {
    await ensureSchema();
    // Guarded on `running`: a completion that raced the release must win, and
    // resetting a finished row would resurrect it.
    final affected = await datasource.executeCommand(
      'UPDATE $table SET state = :pending, claimed_by = NULL, '
      'claimed_at = NULL WHERE id = :id AND state = :running',
      {
        'pending': TomJobRunState.pending.name,
        'running': TomJobRunState.running.name,
        'id': run.id,
      },
    );
    if (affected != BigInt.one) return;
    run.state = TomJobRunState.pending;
    run.claimedBy = null;
    run.claimedAt = null;
  }

  @override
  Future<void> renewClaim(TomJobRun run, DateTime now) async {
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'UPDATE $table SET claimed_at = :now '
      'WHERE id = :id AND state = :running',
      {
        'now': sqlInstant(now),
        'id': run.id,
        'running': TomJobRunState.running.name,
      },
    );
    if (affected != BigInt.one) return;
    run.claimedAt = _asUtc(now);
  }

  @override
  Future<void> complete(TomJobRun run, DateTime now) async {
    await ensureSchema();
    await datasource.executeCommand(
      'UPDATE $table SET state = :succeeded, completed_at = :now, '
      'claimed_by = NULL, claimed_at = NULL WHERE id = :id',
      {
        'succeeded': TomJobRunState.succeeded.name,
        'now': sqlInstant(now),
        'id': run.id,
      },
    );
    run.state = TomJobRunState.succeeded;
    run.completedAt = _asUtc(now);
    run.claimedBy = null;
    run.claimedAt = null;
  }

  @override
  Future<void> fail(
    TomJobRun run,
    String error,
    DateTime now, {
    DateTime? retryAt,
  }) async {
    await ensureSchema();
    if (retryAt == null) {
      await datasource.executeCommand(
        'UPDATE $table SET state = :failed, last_error = :error, '
        'completed_at = :now, claimed_by = NULL, claimed_at = NULL '
        'WHERE id = :id',
        {
          'failed': TomJobRunState.failed.name,
          'error': error,
          'now': sqlInstant(now),
          'id': run.id,
        },
      );
      run.state = TomJobRunState.failed;
      run.completedAt = _asUtc(now);
    } else {
      // `attempt = attempt + 1` in the statement, not `:attempt`: the counter
      // belongs to the row, and computing it from a possibly stale in-memory
      // copy would let a recovered run under-count its retries.
      await datasource.executeCommand(
        'UPDATE $table SET state = :pending, last_error = :error, '
        'attempt = attempt + 1, run_at = :retryAt, claimed_by = NULL, '
        'claimed_at = NULL WHERE id = :id',
        {
          'pending': TomJobRunState.pending.name,
          'error': error,
          'retryAt': sqlInstant(retryAt),
          'id': run.id,
        },
      );
      run.state = TomJobRunState.pending;
      run.attempt++;
      run.runAt = _asUtc(retryAt);
    }
    run.lastError = error;
    run.claimedBy = null;
    run.claimedAt = null;
  }

  @override
  Future<List<TomJobRun>> recoverAbandoned(
    DateTime now,
    Duration leaseTimeout,
  ) async {
    await ensureSchema();
    final cutoff = now.subtract(leaseTimeout);
    // `claimed_at IS NULL` counts as abandoned: a `running` row with no lease
    // stamp is corrupt state, and leaving it stuck forever is worse than
    // re-queueing it.
    final stale = await _select(
      'WHERE state = :running AND (claimed_at IS NULL OR claimed_at <= :cutoff)'
      ' ORDER BY seq',
      {
        'running': TomJobRunState.running.name,
        'cutoff': sqlInstant(cutoff),
      },
    );

    final recovered = <TomJobRun>[];
    for (final run in stale) {
      final affected = await datasource.executeCommand(
        'UPDATE $table SET state = :pending, claimed_by = NULL, '
        'claimed_at = NULL WHERE id = :id AND state = :running',
        {
          'pending': TomJobRunState.pending.name,
          'running': TomJobRunState.running.name,
          'id': run.id,
        },
      );
      if (affected != BigInt.one) continue;
      run.state = TomJobRunState.pending;
      run.claimedBy = null;
      run.claimedAt = null;
      recovered.add(run);
    }
    return recovered;
  }

  @override
  Future<List<TomJobRun>> all() async {
    await ensureSchema();
    return _select('ORDER BY seq', const {});
  }

  @override
  Future<int> purgeFinished(DateTime before) async {
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $table WHERE state IN (:succeeded, :failed) '
      'AND completed_at IS NOT NULL AND completed_at < :before',
      {
        'succeeded': TomJobRunState.succeeded.name,
        'failed': TomJobRunState.failed.name,
        'before': sqlInstant(before),
      },
    );
    return removed.toInt();
  }

  /// Empties the queue table.
  ///
  /// Not part of [TomJobStore] — the contract has no "delete everything",
  /// because no scheduler should ever want one. It exists for provisioning and
  /// for tests that need a known-empty queue.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  Future<List<TomJobRun>> _select(
    String suffix,
    Map<String, dynamic> params,
  ) async {
    final rows = await datasource.executeQuery<TomJobRunRow>(
      'SELECT $_columns, seq FROM $table $suffix',
      params,
    );
    return rows.map(_runOf).toList();
  }

  static TomJobRun _runOf(TomJobRunRow row) => TomJobRun(
        id: row.id,
        jobName: row.jobName,
        scheduledFor: parseSqlInstant(row.scheduledFor),
        runAt: parseSqlInstant(row.runAt),
        state: TomJobRunState.values.firstWhere(
          (s) => s.name == row.state,
          // An unrecognised state is corrupt data, not a crash: `pending` is
          // the one value from which the scheduler can recover, and it matches
          // what TomJobRun.fromJson does with the same input.
          orElse: () => TomJobRunState.pending,
        ),
        attempt: row.attempt,
        claimedBy: row.claimedBy,
        claimedAt: _parseOptional(row.claimedAt),
        lastError: row.lastError,
        completedAt: _parseOptional(row.completedAt),
        payload: _decodePayload(row.payload),
      );

  Map<String, dynamic> _bindOf(TomJobRun run) => {
        'id': run.id,
        'jobName': run.jobName,
        'scheduledFor': sqlInstant(run.scheduledFor),
        'runAt': sqlInstant(run.runAt),
        'state': run.state.name,
        'attempt': run.attempt,
        'claimedBy': run.claimedBy,
        'claimedAt': run.claimedAt == null ? null : sqlInstant(run.claimedAt!),
        'lastError': run.lastError,
        'completedAt':
            run.completedAt == null ? null : sqlInstant(run.completedAt!),
        'payload': _encodePayload(run),
      };

  static DateTime? _parseOptional(String? value) =>
      value == null || value.isEmpty ? null : parseSqlInstant(value);

  static DateTime _asUtc(DateTime value) => value.isUtc ? value : value.toUtc();

  /// Renders [TomJobRun.payload] as the JSON text the column holds.
  ///
  /// A durable queue can only store what it can serialise; the file store has
  /// the same constraint by virtue of writing JSON. Failing loudly here names
  /// the job, which is far more useful than a `JsonUnsupportedObjectError`
  /// thrown from inside a database call.
  static String? _encodePayload(TomJobRun run) {
    if (run.payload == null) return null;
    try {
      return jsonEncode(run.payload);
    } on JsonUnsupportedObjectError catch (error, stack) {
      throw TomServerException(
        'scheduling.store.unserialisable_payload',
        'The job payload cannot be stored because it is not JSON-encodable.',
        parameters: {'job': run.jobName, 'run': run.id},
        rootException: error,
        stack: stack,
      );
    }
  }

  static Object? _decodePayload(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      // Corrupt payload text must not take the whole queue read down with it;
      // the run is still schedulable and its other fields are intact.
      return null;
    }
  }

  @override
  String toString() => 'TomSqlJobStore($table)';
}

/// One row of the job queue table, as the result mapper materialises it.
///
/// Reflected and `@TomDbTable`-annotated because the data source's row mapper
/// requires both; the annotation values are placeholders because the real table
/// name is a constructor argument of [TomSqlJobStore]. Same arrangement, and
/// same reason, as `TomBlobManifestRow` in the file-storage module.
///
/// The instant columns are typed `String`, not `DateTime`, on purpose — see the
/// library comment: the driver's `DateTime` mapping yields a local `DateTime`
/// and would break equality with the UTC value that was written.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomJobRunRow {
  /// The run's stable id.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// The job this run belongs to.
  @TomDbColumn(columnName: "job_name")
  String jobName = "";

  /// The schedule window this run represents, as stored UTC text.
  @TomDbColumn(columnName: "scheduled_for")
  String scheduledFor = "";

  /// When the run may next be attempted, as stored UTC text.
  @TomDbColumn(columnName: "run_at")
  String runAt = "";

  /// The [TomJobRunState] name.
  @TomDbColumn(columnName: "state")
  String state = "";

  /// How many times the run has been attempted, counting from one.
  @TomDbColumn(columnName: "attempt")
  int attempt = 1;

  /// The node currently holding the run, or `null` when it is unclaimed.
  @TomDbColumn(columnName: "claimed_by")
  String? claimedBy;

  /// When the claim was last stamped, as stored UTC text.
  @TomDbColumn(columnName: "claimed_at")
  String? claimedAt;

  /// The message of the most recent failure.
  @TomDbColumn(columnName: "last_error")
  String? lastError;

  /// When the run reached a terminal state, as stored UTC text.
  @TomDbColumn(columnName: "completed_at")
  String? completedAt;

  /// The JSON text of the run's payload.
  @TomDbColumn(columnName: "payload")
  String? payload;

  /// Insertion order, which is the queue's natural order.
  @TomDbColumn(columnName: "seq")
  int seq = 0;
}

/// The single aggregate column [TomSqlJobStore.lastWindow] projects.
///
/// A separate row type because the mapper binds by column name and the
/// aggregate select has no other columns to fill.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomJobRunWindowRow {
  /// The latest window, or `null` when the job has no runs at all.
  @TomDbColumn(columnName: "scheduled_for")
  String? scheduledFor;
}
