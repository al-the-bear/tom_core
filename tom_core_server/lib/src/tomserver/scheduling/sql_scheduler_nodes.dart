/// The cluster's roll call: one row per scheduler node, refreshed on every
/// pass.
///
/// ## What it adds, and what it does not replace
///
/// Without it, nothing in the relational scheduler detects a dead **node** —
/// only an expired **lease**. That is enough for correctness: a run whose lease
/// lapses is recovered whatever became of its holder. But it is slow (a whole
/// lease timeout must elapse before anyone reacts, even when the cluster could
/// have known within one poll interval) and it is blind (the queue can say the
/// run was abandoned, never that node `worker-3` died and took four runs with
/// it).
///
/// The heartbeat fixes both, and neither of them is correctness. **The lease TTL
/// remains the floor.** A node that fails to check in but is still executing is
/// still protected by its lease, and a node declared failed here has its runs
/// recovered *earlier*, not by a different rule. Nothing in this file may be
/// the only thing standing between two nodes and the same run.
///
/// ## The failure formula
///
/// This is Quartz's, kept deliberately identical because both halves of it earn
/// their place ([schedulerNodeFailedAfter]):
///
/// ```text
/// failedAfter = peer.checkinAt
///             + max(peer.checkinInterval, now - myLastCheckin)
///             + slack
/// ```
///
///  * **the peer's own interval**, because a node that polls every 60 s is not
///    late at 20 s and a node that polls every 2 s is very late at 20 s. Using
///    the accuser's interval would make the verdict depend on who happened to
///    ask;
///  * **`now - myLastCheckin`**, because *a node that was itself stalled must
///    not accuse its peers*. If this process was descheduled, garbage-collecting
///    or paused for 90 s, every peer looks 90 s stale through no fault of its
///    own — and the accuser has no way to tell that case apart from a real
///    outage except by noticing that it, too, missed its own beat. Granting
///    peers exactly the slack it took for itself is what makes a stalled node
///    harmless rather than destructive.
///
/// ## Cadence
///
/// A node checks in from `recoverAbandoned`, which the scheduler calls once per
/// tick — so the *actual* cadence is the scheduler's `tickInterval`, while
/// [TomSqlSchedulerNodes.checkinInterval] is what this node *publishes* as its
/// cadence and is therefore what peers judge it by. **Publish an interval no
/// shorter than the scheduler's tick**, or the node accuses itself of being
/// late every pass and its peers will declare it failed while it is working
/// perfectly.
///
/// Deriving the published value from the observed gap was considered and
/// rejected: a node that genuinely stalled would then simply publish a longer
/// interval and excuse itself, which is precisely the outage the roll call
/// exists to notice. The value stays a deliberate statement of intent.
///
/// The consequence of getting it wrong is churn, not double execution — a
/// wrongly recovered run is re-claimed by a peer that then concedes the job's
/// lease to the node still holding it. That is the lease being the floor, again.
///
/// ## Clocks
///
/// The formula compares one node's `checkin_at` against another node's `now`, so
/// it assumes the cluster's clocks agree to within roughly a second. Quartz
/// documents the same requirement and for the same reason. Run NTP. Note that
/// this constrains only the *heartbeat*: claiming, leasing and lease expiry are
/// all decided from instants written and compared by the database, and are
/// unaffected by node clock skew.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'sql_scheduling_sql.dart';

/// The grace period added on top of a peer's expected check-in.
///
/// Quartz's 7.5 s, unchanged. It absorbs the ordinary jitter of a poll that had
/// to wait on a slow query or a busy connection pool, so a healthy node is not
/// declared dead for being briefly late.
const Duration defaultNodeFailureSlack = Duration(milliseconds: 7500);

/// One node of the cluster, as the roll call knows it.
class TomSchedulerNode {
  /// Creates a node record.
  const TomSchedulerNode({
    required this.nodeId,
    required this.checkinAt,
    required this.checkinInterval,
  });

  /// The node's identity, which is the `owner` it claims runs under.
  ///
  /// Deliberately the same string: an attribution that cannot be joined back to
  /// the runs it explains is not an attribution.
  final String nodeId;

  /// When the node last announced itself.
  final DateTime checkinAt;

  /// How often the node says it intends to check in.
  ///
  /// Carried in the row rather than assumed, so nodes configured with different
  /// poll intervals judge each other by the interval each actually keeps.
  final Duration checkinInterval;

  @override
  String toString() =>
      'TomSchedulerNode($nodeId, checkinAt: $checkinAt, '
      'interval: $checkinInterval)';
}

/// The instant after which [peer] counts as failed.
///
/// [lastSelfCheckin] is when the *asking* node last managed to check in; see the
/// library comment for why it belongs in the formula.
///
/// A pure function, and separate from the store, because it is the whole of the
/// judgement and it must be assertable without a database — including the case
/// that is easiest to get wrong, a stalled accuser.
DateTime schedulerNodeFailedAfter({
  required TomSchedulerNode peer,
  required DateTime now,
  required DateTime lastSelfCheckin,
  Duration slack = defaultNodeFailureSlack,
}) {
  final selfLateness = now.difference(lastSelfCheckin);
  final allowance = selfLateness > peer.checkinInterval
      ? selfLateness
      : peer.checkinInterval;
  return peer.checkinAt.add(allowance).add(slack);
}

/// Whether [peer] has missed its check-in for long enough to count as failed.
bool isSchedulerNodeFailed({
  required TomSchedulerNode peer,
  required DateTime now,
  required DateTime lastSelfCheckin,
  Duration slack = defaultNodeFailureSlack,
}) => now.isAfter(
  schedulerNodeFailedAfter(
    peer: peer,
    now: now,
    lastSelfCheckin: lastSelfCheckin,
    slack: slack,
  ),
);

/// The roll call, backed by a table in a [TomDataSource].
///
/// One instance per node. It writes this node's row and reads everyone else's;
/// it holds no lock and arbitrates nothing, which is the point — a heartbeat
/// that could block a peer would be a liveness dependency, and this is only ever
/// an accelerator.
class TomSqlSchedulerNodes {
  /// Creates the roll call for [nodeId] over [datasource].
  ///
  /// [nodeId] must be the same string the node claims runs under
  /// (`TomScheduler.ownerId`), or a failed node's work cannot be attributed to
  /// it.
  ///
  /// [checkinInterval] is what this node *promises*, not what it enforces; it is
  /// published so peers judge it by its own cadence. Set it to the scheduler's
  /// tick interval.
  TomSqlSchedulerNodes(
    this.datasource, {
    required this.nodeId,
    this.table = defaultSchedulerNodeTable,
    this.checkinInterval = const Duration(seconds: 30),
    this.createSchema = true,
    this.slack = defaultNodeFailureSlack,
  });

  /// Creates the roll call over the registered data source named
  /// [datasourceName].
  ///
  /// Throws a [TomServerException] keyed `scheduling.nodes.unknown_datasource`
  /// when no such data source is registered — a configuration error far better
  /// caught at start-up than on the first check-in. The base class rather than
  /// a subtype is deliberate; [TomServerException] says why.
  factory TomSqlSchedulerNodes.named(
    String datasourceName, {
    required String nodeId,
    String table = defaultSchedulerNodeTable,
    Duration checkinInterval = const Duration(seconds: 30),
    bool createSchema = true,
    Duration slack = defaultNodeFailureSlack,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'scheduling.nodes.unknown_datasource',
        'The scheduler roll call refers to a data source that is not '
            'registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlSchedulerNodes(
      info.datasource,
      nodeId: nodeId,
      table: table,
      checkinInterval: checkinInterval,
      createSchema: createSchema,
      slack: slack,
    );
  }

  /// The data source the roll-call table lives in.
  final TomDataSource datasource;

  /// This node's identity.
  final String nodeId;

  /// The roll-call table.
  final String table;

  /// The cadence this node publishes.
  final Duration checkinInterval;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// The grace period applied on top of a peer's expected check-in.
  final Duration slack;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();
  DateTime? _lastCheckin;

  /// When this node last checked in, or `null` before its first pass.
  DateTime? get lastCheckin => _lastCheckin;

  /// The roll call's single column declaration — see `sql_scheduling_sql.dart`.
  late final TomFrameworkTable _roll = schedulerNodeTable(table);

  /// The columns [checkIn] writes, and the bind each takes.
  static const Map<String, String> _checkInColumns = {
    'node_id': ':nodeId',
    'checkin_at': ':checkinAt',
    'checkin_interval': ':checkinInterval',
  };

  /// Creates the roll-call table if it does not exist.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _roll.create(datasource);
    }
  });

  /// Announces this node as alive at [now].
  Future<void> checkIn(DateTime now) async {
    await ensureSchema();
    await _roll.replaceRow(datasource, _checkInColumns, {
      'nodeId': nodeId,
      'checkinAt': sqlInstant(now),
      'checkinInterval': checkinInterval.inMilliseconds,
    });
    _lastCheckin = now.isUtc ? now : now.toUtc();
  }

  /// Every node in the roll call, including this one.
  Future<List<TomSchedulerNode>> nodes() async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomSchedulerNodeRow>(
      'SELECT ${_roll.columnList} FROM $table ORDER BY node_id',
      const {},
    );
    return rows.map(_nodeOf).toList();
  }

  /// The peers that have missed their check-in for long enough to count as
  /// failed at [now].
  ///
  /// Never includes this node: a process cannot conclude its own death, and a
  /// long pass would otherwise let it recover its own live runs.
  Future<List<TomSchedulerNode>> failedNodes(DateTime now) async {
    // Before the first check-in this node has no lateness of its own to grant,
    // which is correct rather than merely convenient: it has not yet missed
    // anything, so peers are judged by their own published cadence alone.
    final since = _lastCheckin ?? now;
    return [
      for (final peer in await nodes())
        if (peer.nodeId != nodeId &&
            isSchedulerNodeFailed(
              peer: peer,
              now: now,
              lastSelfCheckin: since,
              slack: slack,
            ))
          peer,
    ];
  }

  /// Removes [nodeId]'s row from the roll call.
  ///
  /// Called once a failed node's runs have been recovered, so the cluster stops
  /// re-reporting a departure it has already dealt with. Also the clean way for
  /// a node to leave on shutdown.
  Future<void> forget(String nodeId) async {
    await ensureSchema();
    await datasource.executeCommand(
      'DELETE FROM $table WHERE node_id = :nodeId',
      {'nodeId': nodeId},
    );
  }

  /// Empties the roll-call table. For provisioning and tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  static TomSchedulerNode _nodeOf(TomSchedulerNodeRow row) => TomSchedulerNode(
    nodeId: row.nodeId,
    checkinAt: parseSqlInstant(row.checkinAt),
    checkinInterval: Duration(milliseconds: row.checkinInterval),
  );

  @override
  String toString() => 'TomSqlSchedulerNodes($table, node: $nodeId)';
}

/// One row of the roll-call table, as the result mapper materialises it.
///
/// `checkin_at` is typed `String` for the reason the job queue's instants are —
/// the driver's `DateTime` mapping yields a *local* `DateTime` and would not
/// compare equal to the UTC value that was written.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomSchedulerNodeRow {
  /// The node's identity.
  @TomDbColumn(columnName: "node_id")
  String nodeId = "";

  /// When the node last checked in, as stored UTC text.
  @TomDbColumn(columnName: "checkin_at")
  String checkinAt = "";

  /// The node's published cadence, in milliseconds.
  @TomDbColumn(columnName: "checkin_interval")
  int checkinInterval = 0;
}
