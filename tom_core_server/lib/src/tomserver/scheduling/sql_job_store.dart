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
/// It is not merely the durable option. The queue and the [TomLeaseLock]
/// **must share a failure domain**: if the queue says one node claimed a run
/// while the lock says another node holds it, the disagreement has no
/// resolution. So this store is meant to be paired with
/// `TomSqlLeaseLock` over the same [TomDataSource] — one connection, one thing
/// to be up or down.
///
/// ## How a claim is arbitrated
///
/// The database decides who gets a run, never the application. A claim is a
/// conditional statement:
///
/// ```sql
/// UPDATE tom_job_run SET state='running', claimed_by=:owner, claimed_at=:now,
///        claim_token=:next
///  WHERE id=:id AND state='pending' AND claim_token=:current
/// ```
///
/// Exactly one of two racing nodes sees one affected row; the loser sees zero
/// and simply does not get that run. No read-then-write, no application-side
/// lock, no assumption that the scan the node did a moment ago is still true.
///
/// The `claim_token` half of that is the fence. It rises on every claim and
/// never repeats, so the ticket [claimDue] hands back names *this* claim of the
/// run rather than merely the run — which is what lets a transition refuse a
/// write from a node whose lease lapsed while it was partitioned. Comparing it
/// in the `WHERE` as well as setting it means the token issued with the ticket
/// is always the token the row now carries: without that condition, a run a peer
/// claimed, finished and re-queued for retry between the scan and this statement
/// could be claimed here with a token that peer had already been given.
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
/// ### When the answer to the claim is lost
///
/// The affected-row count *is* the arbitration, so a claim whose acknowledgement
/// never arrives is not the same as a claim that was refused. If the connection
/// drops after the `UPDATE` was sent, the row may well have been claimed, and a
/// node that reads the failure as "I did not get it" abandons a run it owns —
/// which then sits `running` until the lease expires, held by a node that
/// believes it holds nothing.
///
/// So a failed claim is classified (`classifySqlFailure`): a failure the server
/// itself reported is definitive and rethrown, while a transport-level one is
/// ambiguous and settled by re-reading the row and believing what it says. It is
/// Quartz's `TransactionValidator` in miniature — the same question, asked of a
/// single row rather than of `QRTZ_FIRED_TRIGGERS`.
///
/// No other statement in this store needs the recheck, and it is worth saying
/// why rather than leaving it to be rediscovered: a lost acknowledgement leaves
/// the row `running` for `complete`, `fail`, `markStarted` and `renewClaim`, and
/// `pending` for `release`. Both are states the lease already recovers from,
/// because none of them is answering a question with an affected-row count.
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
import '../datasources/framework_table.dart';
import '../datasources/sql_datasource.dart';
import '../datasources/sql_failure_mode.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../transactions/transaction_manager.dart';
import 'sql_scheduler_nodes.dart';
import 'sql_scheduling_sql.dart';
import '../tenancy/tenant_data.dart';

/// A [TomJobStore] whose queue is a table in a [TomDataSource].
class TomSqlJobStore implements TomJobStore, TomTenantData {
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
  ///
  /// [nodes], when supplied, is this node's entry in the cluster roll call. It
  /// makes [recoverAbandoned] react to a departed node within a poll interval
  /// instead of a whole lease timeout, and lets it name the node that left. It
  /// is an accelerator only: leave it `null` and the lease timeout recovers
  /// exactly the same runs, just later and anonymously.
  ///
  /// [pauseTable] holds the paused jobs. [archiveTable] receives the runs
  /// [purgeFinished] removes from the queue; with `null` a purge deletes them
  /// instead.
  TomSqlJobStore(
    TomDataSource datasource, {
    this.table = defaultJobRunTable,
    this.pauseTable = defaultJobPauseTable,
    this.archiveTable = defaultJobRunArchiveTable,
    this.createSchema = true,
    this.candidateFactor = 8,
    this.nodes,
  }) : datasource = TomFrameworkTable.systemOf(datasource);

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed `scheduling.store.unknown_datasource`
  /// when no such data source is registered — a configuration error far better
  /// caught at start-up than on the first tick. The base class rather than a
  /// subtype is deliberate; [TomServerException] says why.
  factory TomSqlJobStore.named(
    String datasourceName, {
    String table = defaultJobRunTable,
    String pauseTable = defaultJobPauseTable,
    String? archiveTable = defaultJobRunArchiveTable,
    bool createSchema = true,
    int candidateFactor = 8,
    TomSqlSchedulerNodes? nodes,
  }) {
    final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName);
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
      pauseTable: pauseTable,
      archiveTable: archiveTable,
      createSchema: createSchema,
      candidateFactor: candidateFactor,
      nodes: nodes,
    );
  }

  /// The data source the queue table lives in.
  final TomDataSource datasource;

  /// The queue table.
  final String table;

  /// The paused-job table.
  final String pauseTable;

  /// The table purged runs are moved to, or `null` when a purge deletes them.
  final String? archiveTable;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// How many due runs to consider per claim when a filter is present.
  final int candidateFactor;

  /// The cluster roll call, or `null` when the lease timeout is the only
  /// liveness signal.
  final TomSqlSchedulerNodes? nodes;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  /// The queue table's single column declaration — see `sql_scheduling_sql.dart`.
  late final TomFrameworkTable _queue = jobRunTable(table);

  late final TomFrameworkTable _pauses = jobPauseTable(pauseTable);

  late final TomFrameworkTable? _archive = switch (archiveTable) {
    final name? => jobRunArchiveTable(name),
    null => null,
  };

  /// The columns [enqueue] writes, and the bind each takes.
  ///
  /// `seq` is absent deliberately: it is the `AUTO_INCREMENT` surrogate, so the
  /// database owns its value and naming it here would be naming a value this
  /// store does not have. Keyed by column name rather than given as a list, so
  /// adding a column cannot shift every value one place along — a failure that
  /// would type-check.
  static const Map<String, String> _writeColumns = {
    'id': ':id',
    'job_name': ':jobName',
    'tenant': ':tenant',
    'scheduled_for': ':scheduledFor',
    'window_at': ':windowAt',
    'run_at': ':runAt',
    'state': ':state',
    'attempt': ':attempt',
    'claimed_by': ':claimedBy',
    'claimed_at': ':claimedAt',
    'claim_token': ':claimToken',
    'started_at': ':startedAt',
    'last_error': ':lastError',
    'completed_at': ':completedAt',
    'payload': ':payload',
    'priority': ':priority',
    'checkpoint': ':checkpoint',
  };

  /// Creates the queue, pause and archive tables if they do not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic.
  ///
  /// Never inside the caller's transaction: the DDL runs in a transaction
  /// scope of its own, on a connection of its own. On MariaDB a `CREATE TABLE`
  /// commits the transaction its connection holds, so the first enqueue made
  /// in a transaction would otherwise commit the caller's work before the
  /// caller decided to.
  Future<void> ensureSchema() => _schema.ensure(
    () => TomTransactionManager.runInTransactionScope(() async {
      if (createSchema) {
        await _queue.create(datasource);
        await _pauses.create(datasource);
        await _archive?.create(datasource);
      }
    }),
  );

  /// Where the queue is written and read in the current zone: this store's
  /// data source, or — in a transaction, for a tenant whose data source the
  /// deployment routes ([TomDataSourceInfo.route]) to one on the same server,
  /// as `schema` tenancy does — the routed data source, the table qualified
  /// with this store's schema.
  ///
  /// The routed data source is the one the tenant's business writes enlist in
  /// the transaction, so the queue row rides on their connection and commits
  /// or rolls back with them in one branch. The row still lands in this
  /// store's own table, which is where the scheduler polls.
  ({TomDataSource datasource, String table}) _queueTarget() {
    final own = (datasource: datasource, table: table);
    final store = datasource;
    if (store is! TomSqlDatasource) return own;
    final transaction = TomTransactionManager.getCurrentTransaction();
    if (transaction == null || !transaction.isRunning) return own;
    final base = TomDataSourceInfo.getBaseDataSourceInfo(store.registeredName);
    if (base == null || !identical(base.datasource, store)) return own;
    final routed = TomDataSourceInfo.route(base).datasource;
    if (identical(routed, store) ||
        routed is! TomSqlDatasource ||
        !routed.canQualify(store)) {
      return own;
    }
    return (datasource: routed, table: store.qualify(table));
  }

  /// Queues [run].
  ///
  /// Inside a transaction the row is written in it — on this store's data
  /// source when the transaction writes there too, else as a participant of
  /// its own; see [_queueTarget] for a tenant routed to a schema of the same
  /// server, where it joins the tenant's branch.
  @override
  Future<void> enqueue(TomJobRun run) async {
    await ensureSchema();
    final target = _queueTarget();
    // REPLACE rather than INSERT because enqueue is the store's only writer of
    // new rows and the scheduler may re-enqueue a window it is re-planning. The
    // unique key on (job_name, tenant, window_at) is what keeps the idempotence
    // key a database invariant rather than a convention, so a second row for
    // the same window cannot exist even if a peer races this one. A run
    // enqueued under an id of its own writes no window_at, and the key holds
    // any number of NULLs, so two such runs of one instant never meet.
    await _queue.replaceRow(
      target.datasource,
      _writeColumns,
      _bindOf(run),
      table: target.table,
    );
  }

  /// The run [id], read where [enqueue] writes — so a transaction sees the
  /// runs it queued itself.
  @override
  Future<TomJobRun?> findRun(String id) async {
    await ensureSchema();
    final rows = await _select('WHERE id = :id LIMIT 1', {
      'id': id,
    }, target: _queueTarget());
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<TomJobRun?> findWindow(
    String jobName,
    DateTime scheduledFor, {
    String? tenant,
  }) async {
    await ensureSchema();
    final rows = await _select(
      'WHERE job_name = :jobName AND tenant = :tenant '
      'AND window_at = :scheduledFor LIMIT 1',
      {
        'jobName': jobName,
        'tenant': tenant ?? '',
        'scheduledFor': sqlInstant(scheduledFor),
      },
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<DateTime?> lastWindow(String jobName, {String? tenant}) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomJobRunWindowRow>(
      'SELECT MAX(window_at) AS scheduled_for FROM $table '
      'WHERE job_name = :jobName AND tenant = :tenant',
      {'jobName': jobName, 'tenant': tenant ?? ''},
    );
    if (rows.isEmpty) return null;
    final value = rows.first.scheduledFor;
    return value == null || value.isEmpty ? null : parseSqlInstant(value);
  }

  @override
  Future<List<TomJobClaim>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  }) async {
    await ensureSchema();
    final scanLimit = accept == null ? limit : limit * candidateFactor;
    // Most urgent first, queue order among equals; a paused job's runs are not
    // candidates at all. The claim below does not re-check the pause: a run
    // scanned a moment before its job was paused may still be claimed, as it
    // could have been a moment earlier — a pause stops what starts after it.
    final candidates = await _select(
      'WHERE state = :pending AND run_at <= :now $_notPaused '
      'ORDER BY priority DESC, seq LIMIT $scanLimit',
      {'pending': TomJobRunState.pending.name, 'now': sqlInstant(now)},
    );

    final claimed = <TomJobClaim>[];
    for (final run in candidates) {
      if (claimed.length >= limit) break;
      if (accept != null && !accept(run)) continue;
      final won = await _claim(run, owner, now);
      if (won != null) claimed.add(won);
    }
    return claimed;
  }

  /// Runs the conditional claim of [run] for [owner], returning the ticket for
  /// the claim or `null` when it was not won.
  ///
  /// The `UPDATE` is the arbitration; everything else here is about the one case
  /// in which its result does not arrive.
  ///
  /// It is a compare-and-set on `claim_token` as well as on the state, and both
  /// conditions are load-bearing. `state = :pending` says the run is available;
  /// `claim_token = :current` says it is available *in the shape this node
  /// scanned*. Without the second, a run that a peer claimed, finished and
  /// re-queued for retry between the scan and the update would be claimed here
  /// with a token the peer had already been issued — and two nodes holding
  /// tickets with the same token is the very thing the fence exists to prevent.
  /// With it, the token this call writes is the token the ticket carries, always.
  Future<TomJobClaim?> _claim(TomJobRun run, String owner, DateTime now) async {
    final current = run.claimToken;
    final next = current + 1;
    final BigInt affected;
    try {
      affected = await datasource.executeCommand(
        'UPDATE $table SET state = :running, claimed_by = :owner, '
        'claimed_at = :now, claim_token = :next '
        'WHERE id = :id AND state = :pending AND claim_token = :current',
        {
          'running': TomJobRunState.running.name,
          'owner': owner,
          'now': sqlInstant(now),
          'next': next,
          'id': run.id,
          'pending': TomJobRunState.pending.name,
          'current': current,
        },
      );
    } catch (error, stack) {
      // A claim is the one statement whose *affected-row count is the answer*,
      // so losing the answer is not the same as losing the write. If the server
      // rejected the statement the row is untouched and this is an ordinary
      // failure; if the connection dropped, the claim may have committed and
      // this node would otherwise walk away from a run it owns — leaving it
      // stuck until the lease expires, owned by a node that believes it owns
      // nothing.
      //
      // Every other statement here is safe without the recheck, and for the
      // same reason stated positively: a lost acknowledgement leaves the row
      // `running` (complete/fail/markStarted/renewClaim) or `pending`
      // (release), and both are states the lease already recovers from.
      if (classifySqlFailure(error) == TomSqlFailureMode.definite) rethrow;
      return _resolveAmbiguousClaim(run, owner, now, next, error, stack);
    }
    // Zero affected rows means a peer got there first. It is not an error and
    // it is the whole point: the database, not this process, decided.
    if (affected != BigInt.one) return null;
    run.state = TomJobRunState.running;
    run.claimedBy = owner;
    run.claimedAt = _asUtc(now);
    run.claimToken = next;
    return TomJobClaim(run, owner, next);
  }

  /// Decides a claim whose outcome was lost, by re-reading the row.
  ///
  /// This is Quartz's `TransactionValidator` in miniature: after a commit whose
  /// acknowledgement never arrived, ask the database what it actually holds
  /// rather than assuming either answer.
  ///
  /// The row must identify *this* write, not merely a claim by this owner: a
  /// node whose earlier claim of the same run is still in flight would otherwise
  /// read its own older lease as proof and dispatch the run twice.
  ///
  /// So all three of owner, [expectedToken] and `claimed_at` must match, and the
  /// last is not redundant. Two overlapping passes of the *same* node scan the
  /// same `pending` row, so both compute the same next token; if the first
  /// commits and the second's acknowledgement is lost, the token in the row is
  /// the token the second was expecting. `claimed_at` is the instant this call
  /// bound, and two passes of one node do not share a tick — which is what
  /// separates them.
  Future<TomJobClaim?> _resolveAmbiguousClaim(
    TomJobRun run,
    String owner,
    DateTime now,
    int expectedToken,
    Object error,
    StackTrace stack,
  ) async {
    final List<TomJobRun> rows;
    try {
      rows = await _select('WHERE id = :id LIMIT 1', {'id': run.id});
    } catch (_) {
      // Still blind. Surfacing the original failure is the honest answer, and
      // the lease timeout remains what it always was: the backstop that frees
      // the run if the claim did land.
      Error.throwWithStackTrace(error, stack);
    }

    final stored = rows.isEmpty ? null : rows.first;
    final landed =
        stored != null &&
        stored.state == TomJobRunState.running &&
        stored.claimedBy == owner &&
        stored.claimToken == expectedToken &&
        stored.claimedAt == _asUtc(now);
    if (landed) {
      tomLog.warn(
        'TomSqlJobStore: the claim of run ${run.id} by "$owner" failed in '
        'transport but had committed; taking ownership from the stored row. '
        'Cause: $error',
      );
      return TomJobClaim(stored, owner, expectedToken);
    }
    tomLog.warn(
      'TomSqlJobStore: the claim of run ${run.id} by "$owner" failed in '
      'transport and did not commit; the run stays available. Cause: $error',
    );
    return null;
  }

  /// The `WHERE` clause every transition out of a claim is guarded by.
  ///
  /// The whole of the rule on [TomJobStore], as one fragment: the row must still
  /// exist, still be `running`, and still be `running` *under the claim being
  /// presented*. Written once because five statements need it and five copies of
  /// a four-way predicate is five chances for one of them to lose a conjunct —
  /// silently, since a missing condition only widens what the statement matches.
  ///
  /// `claimed_by` is checked as well as `claim_token`, which is strictly
  /// redundant: the token alone already identifies the claim. It is here because
  /// it costs nothing and it makes the statement legible to whoever reads the
  /// slow query log at three in the morning.
  static const String _heldByClaim =
      'WHERE id = :id AND state = :running '
      'AND claimed_by = :owner AND claim_token = :token';

  /// The binds [_heldByClaim] needs, for [claim].
  static Map<String, dynamic> _fence(TomJobClaim claim) => {
    'id': claim.id,
    'running': TomJobRunState.running.name,
    'owner': claim.owner,
    'token': claim.token,
  };

  @override
  Future<void> release(TomJobClaim claim) async {
    await ensureSchema();
    // A completion that raced the release must win, and resetting a finished row
    // would resurrect it. `claim_token` is deliberately left where it is: the
    // next claim raises it again, and a token that went backwards would stop
    // being a fence.
    final affected = await datasource.executeCommand(
      'UPDATE $table SET state = :pending, claimed_by = NULL, '
      'claimed_at = NULL $_heldByClaim',
      {..._fence(claim), 'pending': TomJobRunState.pending.name},
    );
    if (affected != BigInt.one) return;
    final run = claim.run;
    run.state = TomJobRunState.pending;
    run.claimedBy = null;
    run.claimedAt = null;
  }

  @override
  Future<void> markStarted(TomJobClaim claim, DateTime now) async {
    await ensureSchema();
    // Not guarded on `started_at IS NULL`: a retry re-runs the same row, and
    // the field means "this attempt began", not "the first attempt began".
    final affected = await datasource.executeCommand(
      'UPDATE $table SET started_at = :now $_heldByClaim',
      {..._fence(claim), 'now': sqlInstant(now)},
    );
    if (affected != BigInt.one) return;
    claim.run.startedAt = _asUtc(now);
  }

  @override
  Future<void> renewClaim(TomJobClaim claim, DateTime now) async {
    await ensureSchema();
    // Only `claimed_at` moves. The token is the claim's identity and a heartbeat
    // does not begin a new claim, so touching it here would make this attempt's
    // first heartbeat invalidate its own ticket.
    final affected = await datasource.executeCommand(
      'UPDATE $table SET claimed_at = :now $_heldByClaim',
      {..._fence(claim), 'now': sqlInstant(now)},
    );
    if (affected != BigInt.one) return;
    claim.run.claimedAt = _asUtc(now);
  }

  /// The condition leaving out the runs of paused jobs.
  String get _notPaused =>
      'AND job_name NOT IN (SELECT job_name FROM $pauseTable)';

  @override
  Future<bool> saveCheckpoint(
    TomJobClaim claim,
    Map<String, Object?>? checkpoint,
  ) async {
    final text = TomJobStore.encodeCheckpoint(claim.run, checkpoint);
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'UPDATE $table SET checkpoint = :checkpoint $_heldByClaim',
      {..._fence(claim), 'checkpoint': text},
    );
    if (affected != BigInt.one) return false;
    claim.run.checkpoint = _decodeCheckpoint(text);
    return true;
  }

  @override
  Future<void> complete(TomJobClaim claim, DateTime now) async {
    await ensureSchema();
    // Ungated, this would stamp a fresh `completed_at` onto a row that recovery
    // had already handed to another node, restarting the retention clock on a
    // run whose outcome is no longer ours to report.
    final affected = await datasource.executeCommand(
      'UPDATE $table SET state = :succeeded, completed_at = :now, '
      'claimed_by = NULL, claimed_at = NULL $_heldByClaim',
      {
        ..._fence(claim),
        'succeeded': TomJobRunState.succeeded.name,
        'now': sqlInstant(now),
      },
    );
    if (affected != BigInt.one) return;
    final run = claim.run;
    run.state = TomJobRunState.succeeded;
    run.completedAt = _asUtc(now);
    run.claimedBy = null;
    run.claimedAt = null;
  }

  @override
  Future<void> fail(
    TomJobClaim claim,
    String error,
    DateTime now, {
    DateTime? retryAt,
  }) async {
    await ensureSchema();
    // Fenced in both branches, for the reason given on [complete]. The retrying
    // branch has a second reason: it increments `attempt`, so an ungated
    // statement would charge a retry to whoever holds the run now.
    final run = claim.run;
    if (retryAt == null) {
      final affected = await datasource.executeCommand(
        'UPDATE $table SET state = :failed, last_error = :error, '
        'completed_at = :now, claimed_by = NULL, claimed_at = NULL '
        '$_heldByClaim',
        {
          ..._fence(claim),
          'failed': TomJobRunState.failed.name,
          'error': error,
          'now': sqlInstant(now),
        },
      );
      if (affected != BigInt.one) return;
      run.state = TomJobRunState.failed;
      run.completedAt = _asUtc(now);
    } else {
      // `attempt = attempt + 1` in the statement, not `:attempt`: the counter
      // belongs to the row, and computing it from a possibly stale in-memory
      // copy would let a recovered run under-count its retries.
      final affected = await datasource.executeCommand(
        'UPDATE $table SET state = :pending, last_error = :error, '
        'attempt = attempt + 1, run_at = :retryAt, claimed_by = NULL, '
        'claimed_at = NULL $_heldByClaim',
        {
          ..._fence(claim),
          'pending': TomJobRunState.pending.name,
          'error': error,
          'retryAt': sqlInstant(retryAt),
        },
      );
      if (affected != BigInt.one) return;
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
    Duration leaseTimeout, {
    bool Function(String jobName)? requestsRecovery,
  }) async {
    await ensureSchema();
    // This node's own liveness, announced on the same pass that judges everyone
    // else's — so a node that stops recovering also stops claiming to be alive,
    // and the two facts cannot drift apart. Failing to announce it is swallowed
    // like every other roll-call failure: the invariant holds either way — a
    // pass that could not check in also did not renew this node's claim to be
    // alive — whereas propagating would let the accelerator abort the recovery
    // it exists to speed up.
    try {
      await nodes?.checkIn(now);
    } catch (error) {
      tomLog.warn(
        'TomSqlJobStore: could not announce this node in the '
        'scheduler roll call; peers will judge it by its last check-in. '
        'Cause: $error',
      );
    }

    final cutoff = now.subtract(leaseTimeout);
    // `claimed_at IS NULL` counts as abandoned: a `running` row with no lease
    // stamp is corrupt state, and leaving it stuck forever is worse than
    // re-queueing it.
    final stale = await _select(
      'WHERE state = :running AND (claimed_at IS NULL OR claimed_at <= :cutoff)'
      ' ORDER BY seq',
      {'running': TomJobRunState.running.name, 'cutoff': sqlInstant(cutoff)},
    );
    final abandoned = await _withFailedNodesWork(stale, now);

    final recovered = <TomJobRun>[];
    for (final run in abandoned) {
      // The decision is the kernel's, shared with the memory store so both
      // answer identically; only the transition differs, because "goes back to
      // the queue" and "is written off" are two different statements here.
      final recoverable = TomJobStore.isRecoverable(run, requestsRecovery);
      final affected = recoverable
          ? await datasource.executeCommand(
              'UPDATE $table SET state = :pending, claimed_by = NULL, '
              'claimed_at = NULL WHERE id = :id AND state = :running',
              {
                'pending': TomJobRunState.pending.name,
                'running': TomJobRunState.running.name,
                'id': run.id,
              },
            )
          : await datasource.executeCommand(
              'UPDATE $table SET state = :failed, completed_at = :now, '
              'last_error = :error, claimed_by = NULL, claimed_at = NULL '
              'WHERE id = :id AND state = :running',
              {
                'failed': TomJobRunState.failed.name,
                'now': sqlInstant(now),
                'error': TomJobStore.recoveryDeclinedError,
                'running': TomJobRunState.running.name,
                'id': run.id,
              },
            );
      // Still guarded on `running`: between the scan and this write a peer may
      // have recovered the same row, and the loser must not report a change it
      // did not make.
      if (affected != BigInt.one) continue;
      run.claimedBy = null;
      run.claimedAt = null;
      if (recoverable) {
        run.state = TomJobRunState.pending;
      } else {
        run.state = TomJobRunState.failed;
        run.completedAt = _asUtc(now);
        run.lastError = TomJobStore.recoveryDeclinedError;
      }
      recovered.add(run);
    }
    return recovered;
  }

  /// [stale] plus any run still held by a node the roll call says has died.
  ///
  /// The lease timeout finds these too, eventually — this only finds them
  /// sooner, and knows whose they were. Which is why every failure in here is
  /// swallowed after logging: the roll call is an accelerator, and an
  /// accelerator that can break recovery is worse than no accelerator.
  Future<List<TomJobRun>> _withFailedNodesWork(
    List<TomJobRun> stale,
    DateTime now,
  ) async {
    final roll = nodes;
    if (roll == null) return stale;

    final List<TomSchedulerNode> failed;
    try {
      failed = await roll.failedNodes(now);
    } catch (error) {
      tomLog.warn(
        'TomSqlJobStore: could not read the scheduler roll call; falling back '
        'to lease expiry alone. Cause: $error',
      );
      return stale;
    }
    if (failed.isEmpty) return stale;

    final byId = {for (final run in stale) run.id: run};
    for (final peer in failed) {
      final List<TomJobRun> orphans;
      try {
        orphans = await _select(
          'WHERE state = :running AND claimed_by = :owner ORDER BY seq',
          {'running': TomJobRunState.running.name, 'owner': peer.nodeId},
        );
      } catch (error) {
        tomLog.warn(
          'TomSqlJobStore: could not read the work of failed node '
          '"${peer.nodeId}"; leaving it to lease expiry. Cause: $error',
        );
        continue;
      }
      // Attribution is the second thing the roll call buys, and it is worth a
      // log line even when there is nothing to recover: "worker-3 left" is the
      // sentence an operator is looking for.
      tomLog.warn(
        'TomSqlJobStore: scheduler node "${peer.nodeId}" last checked in at '
        '${peer.checkinAt} and is treated as failed; recovering '
        '${orphans.length} run(s) it held.',
      );
      for (final run in orphans) {
        byId.putIfAbsent(run.id, () => run);
      }
      try {
        // Its work is accounted for, so the departure is dealt with; leaving the
        // row would re-report it on every pass. A node that comes back simply
        // registers again on its next check-in.
        await roll.forget(peer.nodeId);
      } catch (error) {
        tomLog.warn(
          'TomSqlJobStore: could not drop failed node "${peer.nodeId}" from '
          'the roll call. Cause: $error',
        );
      }
    }
    return byId.values.toList();
  }

  @override
  Future<List<TomJobRun>> all() async {
    await ensureSchema();
    return _select('ORDER BY seq', const {});
  }

  @override
  Future<List<TomJobBacklog>> backlog(DateTime now) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomJobBacklogRow>(
      'SELECT job_name, COUNT(*) AS due, MIN(run_at) AS oldest_run_at '
      'FROM $table WHERE state = :pending AND run_at <= :now $_notPaused '
      'GROUP BY job_name',
      {'pending': TomJobRunState.pending.name, 'now': sqlInstant(now)},
    );
    return [
      for (final row in rows)
        if (row.oldestRunAt != null && row.oldestRunAt!.isNotEmpty)
          TomJobBacklog(
            jobName: row.jobName,
            due: row.due,
            oldestDueAt: parseSqlInstant(row.oldestRunAt!),
          ),
    ];
  }

  /// Removes terminal runs that completed before [before] from the queue,
  /// returning how many — moving them to [archiveTable], or deleting them when
  /// it is `null`.
  ///
  /// The move is one transaction: the runs are copied with `archived_at` set
  /// to [now] (default: the current time), and the queue's copies of exactly
  /// the archived runs are deleted, so a run is in one table or the other,
  /// never in both and never in neither.
  @override
  Future<int> purgeFinished(DateTime before, {DateTime? now}) async {
    await ensureSchema();
    const finished =
        'state IN (:succeeded, :failed) '
        'AND completed_at IS NOT NULL AND completed_at < :before';
    final params = {
      'succeeded': TomJobRunState.succeeded.name,
      'failed': TomJobRunState.failed.name,
      'before': sqlInstant(before),
    };
    final archive = archiveTable;
    if (archive == null) {
      final removed = await datasource.executeCommand(
        'DELETE FROM $table WHERE $finished',
        params,
      );
      return removed.toInt();
    }
    final columns = _queue.columnList;
    return TomTransactionManager.runInTransaction((_) async {
      final moved = await datasource.executeCommand(
        'INSERT INTO $archive ($columns, archived_at) '
        'SELECT $columns, :archivedAt FROM $table WHERE $finished',
        {...params, 'archivedAt': sqlInstant(now ?? DateTime.now().toUtc())},
      );
      if (moved == BigInt.zero) return 0;
      final removed = await datasource.executeCommand(
        'DELETE FROM $table WHERE $finished '
        'AND id IN (SELECT id FROM $archive)',
        params,
      );
      return removed.toInt();
    });
  }

  /// Cancels the pending runs of [tenant]: each becomes `failed` with
  /// [TomJobStore.tenantRemovedError], at [now]. A running one finishes.
  @override
  Future<int> cancelTenantRuns(String tenant, DateTime now) async {
    await ensureSchema();
    final cancelled = await datasource.executeCommand(
      'UPDATE $table SET state = :failed, last_error = :error, '
      'completed_at = :now WHERE tenant = :tenant AND state = :pending',
      {
        'failed': TomJobRunState.failed.name,
        'pending': TomJobRunState.pending.name,
        'error': TomJobStore.tenantRemovedError,
        'now': sqlInstant(now),
        'tenant': tenant,
      },
    );
    return cancelled.toInt();
  }

  /// Deletes every run of [tenant] from the queue, and from [archiveTable]
  /// when the store archives.
  @override
  Future<int> purgeTenant(String tenant) async {
    await ensureSchema();
    var removed = (await datasource.executeCommand(
      'DELETE FROM $table WHERE tenant = :tenant',
      {'tenant': tenant},
    )).toInt();
    final archive = archiveTable;
    if (archive != null) {
      removed += (await datasource.executeCommand(
        'DELETE FROM $archive WHERE tenant = :tenant',
        {'tenant': tenant},
      )).toInt();
    }
    return removed;
  }

  /// The archived runs, most recently archived first — of [jobName] only when
  /// given — at most [limit] of them.
  ///
  /// Empty when the store does not archive.
  Future<List<TomArchivedJobRun>> archivedRuns({
    String? jobName,
    int limit = 100,
  }) async {
    final archive = _archive;
    if (archive == null) return const [];
    await ensureSchema();
    final rows = await datasource.executeQuery<TomJobRunArchiveRow>(
      'SELECT ${archive.columnList} FROM ${archive.name} '
      '${jobName == null ? '' : 'WHERE job_name = :jobName '}'
      'ORDER BY archived_at DESC, seq DESC LIMIT $limit',
      {'jobName': ?jobName},
    );
    return [
      for (final row in rows)
        TomArchivedJobRun(
          _runOf(row.toRunRow()),
          parseSqlInstant(row.archivedAt),
        ),
    ];
  }

  /// Deletes the archived runs archived before [before], returning how many.
  ///
  /// The archive keeps history for as long as the deployment wants it, which
  /// is a decision for its retention job, as [purgeFinished] is for the queue.
  Future<int> purgeArchive(DateTime before) async {
    final archive = archiveTable;
    if (archive == null) return 0;
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $archive WHERE archived_at < :before',
      {'before': sqlInstant(before)},
    );
    return removed.toInt();
  }

  @override
  Future<void> pauseJob(String jobName, DateTime now) async {
    await ensureSchema();
    // A conflict keeps the stored row: a second pause does not move the
    // instant of the first.
    await datasource.executeCommand(
      _pauses.insertRow(datasource.sqlDialect, {
        'job_name': ':jobName',
        'paused_at': ':now',
      }, ignoreConflict: true),
      {'jobName': jobName, 'now': sqlInstant(now)},
    );
  }

  @override
  Future<void> resumeJob(String jobName) async {
    await ensureSchema();
    await datasource.executeCommand(
      'DELETE FROM $pauseTable WHERE job_name = :jobName',
      {'jobName': jobName},
    );
  }

  @override
  Future<Map<String, DateTime>> pausedJobs() async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomJobPauseRow>(
      'SELECT job_name, paused_at FROM $pauseTable',
    );
    return {for (final row in rows) row.jobName: parseSqlInstant(row.pausedAt)};
  }

  /// Empties the queue, the pause table and the archive.
  ///
  /// Not part of [TomJobStore] — the contract has no "delete everything",
  /// because no scheduler should ever want one. It exists for provisioning and
  /// for tests that need a known-empty queue.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
    await datasource.executeCommand('DELETE FROM $pauseTable');
    if (archiveTable case final archive?) {
      await datasource.executeCommand('DELETE FROM $archive');
    }
  }

  Future<List<TomJobRun>> _select(
    String suffix,
    Map<String, dynamic> params, {
    ({TomDataSource datasource, String table})? target,
  }) async {
    final rows = await (target?.datasource ?? datasource)
        .executeQuery<TomJobRunRow>(
          'SELECT ${_queue.columnList} FROM ${target?.table ?? table} $suffix',
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
    claimedAt: parseOptionalSqlInstant(row.claimedAt),
    claimToken: row.claimToken,
    startedAt: parseOptionalSqlInstant(row.startedAt),
    lastError: row.lastError,
    completedAt: parseOptionalSqlInstant(row.completedAt),
    payload: _decodePayload(row.payload),
    tenant: row.tenant.isEmpty ? null : row.tenant,
    priority: row.priority,
    checkpoint: _decodeCheckpoint(row.checkpoint),
    windowed: row.windowAt != null,
  );

  /// Binds [run] to the queue table's columns.
  ///
  /// The payload is rendered by the kernel's [TomJobStore.encodePayload] rather
  /// than by a local `jsonEncode`, so that a store this node cannot serialise
  /// is refused with the same `schedule.job.payload` exception the memory and
  /// file stores raise. Every binding site is evaluated before the statement is
  /// sent, so the refusal still precedes any write.
  Map<String, dynamic> _bindOf(TomJobRun run) => {
    'id': run.id,
    'jobName': run.jobName,
    'tenant': run.tenant ?? '',
    'scheduledFor': sqlInstant(run.scheduledFor),
    'windowAt': run.windowed ? sqlInstant(run.scheduledFor) : null,
    'runAt': sqlInstant(run.runAt),
    'state': run.state.name,
    'attempt': run.attempt,
    'claimedBy': run.claimedBy,
    'claimedAt': run.claimedAt == null ? null : sqlInstant(run.claimedAt!),
    'claimToken': run.claimToken,
    'startedAt': run.startedAt == null ? null : sqlInstant(run.startedAt!),
    'lastError': run.lastError,
    'completedAt': run.completedAt == null
        ? null
        : sqlInstant(run.completedAt!),
    'payload': TomJobStore.encodePayload(run),
    'priority': run.priority,
    'checkpoint': TomJobStore.encodeCheckpoint(run, run.checkpoint),
  };

  static DateTime _asUtc(DateTime value) => value.isUtc ? value : value.toUtc();

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

  /// The checkpoint stored as [value]; `null` for none, and for text that is
  /// not a JSON object — corrupt progress restarts the run from the beginning
  /// rather than making it unreadable.
  static Map<String, Object?>? _decodeCheckpoint(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'TomSqlJobStore($table)';
}

/// A run [TomSqlJobStore.purgeFinished] moved to the archive, and when.
class TomArchivedJobRun {
  /// [run], archived at [archivedAt].
  const TomArchivedJobRun(this.run, this.archivedAt);

  /// The run as it was when it left the queue.
  final TomJobRun run;

  /// When it was archived.
  final DateTime archivedAt;
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
  primaryKeyFields: ["irrelevant"],
)
class TomJobRunRow {
  /// The run's stable id.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// The job this run belongs to.
  @TomDbColumn(columnName: "job_name")
  String jobName = "";

  /// The run's tenant, or `''` for a run of no tenant.
  @TomDbColumn(columnName: "tenant")
  String tenant = "";

  /// The schedule window this run represents, as stored UTC text.
  @TomDbColumn(columnName: "scheduled_for")
  String scheduledFor = "";

  /// [scheduledFor] for a windowed run, `null` for one enqueued under an id
  /// of its own.
  @TomDbColumn(columnName: "window_at")
  String? windowAt;

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

  /// Which claim of this run is current — the queue's fencing token.
  @TomDbColumn(columnName: "claim_token")
  int claimToken = 0;

  /// When the body began executing, as stored UTC text; `null` if it never did.
  ///
  /// The one column that separates an interrupted *execution* from an abandoned
  /// *reservation*, which is what recovery has to know before it may offer a
  /// run again.
  @TomDbColumn(columnName: "started_at")
  String? startedAt;

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

  /// How urgent the run is; a higher value is claimed first.
  @TomDbColumn(columnName: "priority")
  int priority = 0;

  /// The JSON text of the progress the run last saved.
  @TomDbColumn(columnName: "checkpoint")
  String? checkpoint;
}

/// One row of the run archive: a [TomJobRunRow]'s columns plus `archived_at`.
///
/// Its own type rather than a [TomJobRunRow] with one more field, because a row
/// type maps only columns its table declares (the framework schema check holds
/// every row type to that), and a subclass would not do either: the row mapper
/// reads a class's own fields only.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomJobRunArchiveRow {
  /// The run's stable id.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// The job this run belongs to.
  @TomDbColumn(columnName: "job_name")
  String jobName = "";

  /// The run's tenant, or `''` for a run of no tenant.
  @TomDbColumn(columnName: "tenant")
  String tenant = "";

  /// The schedule window this run represents, as stored UTC text.
  @TomDbColumn(columnName: "scheduled_for")
  String scheduledFor = "";

  /// [scheduledFor] for a windowed run, `null` for one enqueued under an id
  /// of its own.
  @TomDbColumn(columnName: "window_at")
  String? windowAt;

  /// When the run was last due, as stored UTC text.
  @TomDbColumn(columnName: "run_at")
  String runAt = "";

  /// The [TomJobRunState] name.
  @TomDbColumn(columnName: "state")
  String state = "";

  /// How many times the run was attempted, counting from one.
  @TomDbColumn(columnName: "attempt")
  int attempt = 1;

  /// The node that last held the run, if any.
  @TomDbColumn(columnName: "claimed_by")
  String? claimedBy;

  /// When the claim was last stamped, as stored UTC text.
  @TomDbColumn(columnName: "claimed_at")
  String? claimedAt;

  /// The run's last fencing token.
  @TomDbColumn(columnName: "claim_token")
  int claimToken = 0;

  /// When the last attempt began, as stored UTC text.
  @TomDbColumn(columnName: "started_at")
  String? startedAt;

  /// The message of the most recent failure.
  @TomDbColumn(columnName: "last_error")
  String? lastError;

  /// When the run reached its terminal state, as stored UTC text.
  @TomDbColumn(columnName: "completed_at")
  String? completedAt;

  /// The JSON text of the run's payload.
  @TomDbColumn(columnName: "payload")
  String? payload;

  /// The queue's insertion order, carried over.
  @TomDbColumn(columnName: "seq")
  int seq = 0;

  /// How urgent the run was.
  @TomDbColumn(columnName: "priority")
  int priority = 0;

  /// The JSON text of the progress the run last saved.
  @TomDbColumn(columnName: "checkpoint")
  String? checkpoint;

  /// When the run was archived, as stored UTC text.
  @TomDbColumn(columnName: "archived_at")
  String archivedAt = "";

  /// The run's columns as a queue row, so one conversion turns both into a
  /// [TomJobRun].
  TomJobRunRow toRunRow() => TomJobRunRow()
    ..id = id
    ..jobName = jobName
    ..tenant = tenant
    ..scheduledFor = scheduledFor
    ..windowAt = windowAt
    ..runAt = runAt
    ..state = state
    ..attempt = attempt
    ..claimedBy = claimedBy
    ..claimedAt = claimedAt
    ..claimToken = claimToken
    ..startedAt = startedAt
    ..lastError = lastError
    ..completedAt = completedAt
    ..payload = payload
    ..seq = seq
    ..priority = priority
    ..checkpoint = checkpoint;
}

/// One row of the paused-job table.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomJobPauseRow {
  /// The paused job.
  @TomDbColumn(columnName: "job_name")
  String jobName = "";

  /// When it was paused, as stored UTC text.
  @TomDbColumn(columnName: "paused_at")
  String pausedAt = "";
}

/// The single aggregate column [TomSqlJobStore.lastWindow] projects.
///
/// A separate row type because the mapper binds by column name and the
/// aggregate select has no other columns to fill.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomJobRunWindowRow {
  /// The latest window, or `null` when the job has no runs at all.
  @TomDbColumn(columnName: "scheduled_for")
  String? scheduledFor;
}

/// One job's aggregate row of [TomSqlJobStore.backlog]: how many of its runs
/// are due and unclaimed, and the earliest `run_at` among them.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomJobBacklogRow {
  /// The job.
  @TomDbColumn(columnName: "job_name")
  String jobName = "";

  /// How many of its runs are due and unclaimed.
  @TomDbColumn(columnName: "due")
  int due = 0;

  /// The earliest due `run_at`, as stored UTC text.
  @TomDbColumn(columnName: "oldest_run_at")
  String? oldestRunAt;
}
