/// The schema and the instant encoding shared by the relational scheduling
/// pair.
///
/// Each table is declared **once**, as a [TomFrameworkTable]. The DDL the stores
/// issue, the column lists their statements interpolate, and the schema model the
/// convergence guard compares are all derived from that one declaration — see
/// `datasources/framework_table.dart` for why, and
/// `db_migration/framework_convergence.dart` for what the guard then proves. The
/// shipped migration files under `example/scheduling/migrations/` stay
/// hand-written, because a migration is what a DBA applies and must remain
/// readable; a test asserts they have not drifted from the descriptors.
library;

import '../datasources/framework_table.dart';

/// The default name of the job queue table.
const String defaultJobRunTable = 'tom_job_run';

/// The default name of the lease table.
const String defaultLeaseTable = 'tom_lease';

/// The default name of the scheduler roll-call table.
const String defaultSchedulerNodeTable = 'tom_scheduler_node';

/// The default name of the paused-job table.
const String defaultJobPauseTable = 'tom_job_pause';

/// The default name of the table purged runs are archived to.
const String defaultJobRunArchiveTable = 'tom_job_run_archive';

/// The job queue table [table], declared once.
///
/// Notes on the shape, because each column earns its place:
///
///  * `seq` is an `AUTO_INCREMENT` surrogate that exists only to give the queue
///    a stable insertion order — `all()` and the candidate scan both use it, so
///    two nodes reading the same queue see the same order. It is not the key:
///    the run's own id is, because that is what every other statement addresses.
///  * the **unique key on `(job_name, tenant, window_at)`** is the point of
///    the whole table. The scheduler's idempotence key is "one run per job per
///    window" — per tenant, since two tenants' events in one instant are two
///    runs; expressing it as a database constraint makes a duplicate window
///    impossible rather than merely unlikely under a race. `window_at` is
///    `scheduled_for` for a run that realises a window and `NULL` for a run a
///    component enqueued under an id of its own (the outbox, the saga
///    orchestrator): its id is its key, and since a unique key never treats two
///    `NULL`s as equal, two such runs enqueued in one instant — on two nodes —
///    stay two runs. `scheduled_for` itself keeps every run's instant.
///  * `tenant` is `''` for a run of no tenant rather than `NULL`, because a
///    unique key never treats two `NULL`s as equal — two tenant-less runs of
///    one window would both insert. It is at most 32 characters, the length a
///    tenant id is limited to.
///  * `state, run_at` is the index the claim scan rides; `state, claimed_at` is
///    the one abandoned-lease recovery rides.
///  * `started_at` is nullable **and that is the information**: a `running` row
///    without it was reserved and lost before anything executed, one with it was
///    interrupted mid-execution. Recovery may always re-queue the first and may
///    only re-queue the second when the job opted in. Quartz spends two trigger
///    states (`ACQUIRED`, `EXECUTING`) on the same distinction.
///  * `claim_token` is the queue's fencing counter, and the exact counterpart of
///    `token` on the lease table below: it rises on every claim of a run and
///    never repeats, so two claims of the same run are orderable. `claimed_at`
///    cannot serve — it is the heartbeat and moves during an attempt — and the
///    owner cannot either, since a node may re-claim a run it previously lost.
///    Without it the queue and the lock could disagree about who holds a run,
///    which is the one disagreement neither can resolve.
///  * instants are `DATETIME(6)` and always written in UTC — see
///    `sqlInstant` in `datasources/sql_instant.dart`.
///  * `job_name` is `VARCHAR(150)` rather than 191 so the composite unique key
///    stays inside the 767-byte index limit of older InnoDB row formats
///    (150 × 4 + 32 × 4 bytes of utf8mb4 + 8 bytes of `DATETIME(6)` = 736).
///  * `priority` orders the claim scan (`ORDER BY priority DESC, seq`); it is
///    copied from the job when the run is planned, so every node reads the
///    same order.
///  * `checkpoint` is the JSON text of the progress the job last saved, kept
///    across retries and recovery so the next attempt can continue from it.
TomFrameworkTable jobRunTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'jobRunTable',
  columns: _jobRunColumns,
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey.unique('seq', ['seq']),
    TomFrameworkKey.unique('window', ['job_name', 'tenant', 'window_at']),
    TomFrameworkKey('due', ['state', 'run_at']),
    TomFrameworkKey('lease', ['state', 'claimed_at']),
  ],
);

/// The columns of a run, shared by the queue and its archive.
const List<TomFrameworkColumn> _jobRunColumns = [
  TomFrameworkColumn('seq', 'BIGINT', autoIncrement: true),
  TomFrameworkColumn('id', 'VARCHAR(191)'),
  TomFrameworkColumn('job_name', 'VARCHAR(150)'),
  TomFrameworkColumn('tenant', 'VARCHAR(32)', defaultValue: "''"),
  TomFrameworkColumn('scheduled_for', 'DATETIME(6)'),
  TomFrameworkColumn('window_at', 'DATETIME(6)', nullable: true),
  TomFrameworkColumn('run_at', 'DATETIME(6)'),
  TomFrameworkColumn('state', 'VARCHAR(16)'),
  TomFrameworkColumn('attempt', 'INT', defaultValue: '1'),
  TomFrameworkColumn('claimed_by', 'VARCHAR(191)', nullable: true),
  TomFrameworkColumn('claimed_at', 'DATETIME(6)', nullable: true),
  TomFrameworkColumn('claim_token', 'BIGINT', defaultValue: '0'),
  TomFrameworkColumn('started_at', 'DATETIME(6)', nullable: true),
  TomFrameworkColumn('last_error', 'TEXT', nullable: true),
  TomFrameworkColumn('completed_at', 'DATETIME(6)', nullable: true),
  TomFrameworkColumn('payload', 'LONGTEXT', nullable: true),
  TomFrameworkColumn('priority', 'INT', defaultValue: '0'),
  TomFrameworkColumn('checkpoint', 'LONGTEXT', nullable: true),
];

/// The paused-job table [table], declared once.
///
/// One row per paused job, deleted on resume. A table of its own rather than a
/// flag on the queue's rows, because a pause belongs to the job, not to its
/// runs: runs enqueued while the job is paused must wait too, and a pause of a
/// job with no runs yet is still a pause. The claim scan excludes the jobs
/// named here.
TomFrameworkTable jobPauseTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'jobPauseTable',
  columns: const [
    TomFrameworkColumn('job_name', 'VARCHAR(150)'),
    TomFrameworkColumn('paused_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['job_name'],
);

/// The archive table [table] purged runs are moved to, declared once.
///
/// Every column of the queue, plus `archived_at`, when the run was moved.
/// `seq` is the queue's insertion order carried over, not an `AUTO_INCREMENT`
/// of its own, and the archive has no unique window key: a window can be
/// planned again after its run was archived. Indexed on `archived_at` for the
/// archive's own purge and on `(job_name, scheduled_for)` for a job's history.
TomFrameworkTable jobRunArchiveTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'jobRunArchiveTable',
  columns: [
    for (final column in _jobRunColumns)
      column.name == 'seq' ? const TomFrameworkColumn('seq', 'BIGINT') : column,
    const TomFrameworkColumn('archived_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey('archived', ['archived_at']),
    TomFrameworkKey('job', ['job_name', 'scheduled_for']),
  ],
);

/// The lease table [table], declared once.
///
/// One row per resource, kept after release rather than deleted. That is not
/// tidiness — the row *is* the fencing counter. Deleting it on release would
/// restart the token at 1 for the next holder, and a token that repeats is not
/// a fencing token.
///
/// `version` exists because MariaDB reports *changed* rows, not matched rows:
/// an `UPDATE` that writes the values already present affects zero rows. A
/// renewal landing in the same clock instant with the same TTL would therefore
/// look like a lost lease and fall through to takeover — precisely the
/// self-fencing bug the kernel's scheduling contract suite exists to catch.
/// Incrementing `version` on every write makes a matching update always change
/// the row, and doubles as the compare-and-set guard for takeover.
TomFrameworkTable leaseTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'leaseTable',
  columns: const [
    TomFrameworkColumn('resource', 'VARCHAR(191)'),
    TomFrameworkColumn('owner', 'VARCHAR(191)'),
    TomFrameworkColumn('token', 'BIGINT'),
    TomFrameworkColumn('acquired_at', 'DATETIME(6)'),
    TomFrameworkColumn('expires_at', 'DATETIME(6)'),
    TomFrameworkColumn('released', 'TINYINT(1)', defaultValue: '0'),
    TomFrameworkColumn('version', 'BIGINT', defaultValue: '1'),
  ],
  primaryKey: const ['resource'],
);

/// The scheduler roll-call table [table], declared once.
///
/// One row per node, rewritten on every pass. It has no index beyond its key and
/// wants none: a cluster is read in full, and it is a handful of rows.
///
/// `checkin_interval` is stored in milliseconds and is each node's *own*
/// published cadence, because a node that polls every 60 s is not late at 20 s
/// while a node that polls every 2 s is very late at 20 s. Judging a peer by the
/// accuser's interval would make the verdict depend on who happened to ask.
///
/// `node_id` is the same string the node claims runs under, so a failed node's
/// abandoned work can be attributed to it by an ordinary join.
TomFrameworkTable schedulerNodeTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'schedulerNodeTable',
  columns: const [
    TomFrameworkColumn('node_id', 'VARCHAR(191)'),
    TomFrameworkColumn('checkin_at', 'DATETIME(6)'),
    TomFrameworkColumn('checkin_interval', 'BIGINT'),
  ],
  primaryKey: const ['node_id'],
);

/// The DDL for the job queue table [table].
String jobRunTableDdl(String table) => jobRunTable(table).createTableDdl;

/// The DDL for the lease table [table].
String leaseTableDdl(String table) => leaseTable(table).createTableDdl;

/// The DDL for the scheduler roll-call table [table].
String schedulerNodeTableDdl(String table) =>
    schedulerNodeTable(table).createTableDdl;

/// The DDL for the paused-job table [table].
String jobPauseTableDdl(String table) => jobPauseTable(table).createTableDdl;

/// The DDL for the run archive table [table].
String jobRunArchiveTableDdl(String table) =>
    jobRunArchiveTable(table).createTableDdl;
