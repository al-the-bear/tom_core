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

/// The job queue table [table], declared once.
///
/// Notes on the shape, because each column earns its place:
///
///  * `seq` is an `AUTO_INCREMENT` surrogate that exists only to give the queue
///    a stable insertion order — `all()` and the candidate scan both use it, so
///    two nodes reading the same queue see the same order. It is not the key:
///    the run's own id is, because that is what every other statement addresses.
///  * the **unique key on `(job_name, scheduled_for)`** is the point of the
///    whole table. The scheduler's idempotence key is "one run per job per
///    window"; expressing it as a database constraint makes a duplicate window
///    impossible rather than merely unlikely under a race.
///  * `state, run_at` is the index the claim scan rides; `state, claimed_at` is
///    the one abandoned-lease recovery rides.
///  * `started_at` is nullable **and that is the information**: a `running` row
///    without it was reserved and lost before anything executed, one with it was
///    interrupted mid-execution. Recovery may always re-queue the first and may
///    only re-queue the second when the job opted in. Quartz spends two trigger
///    states (`ACQUIRED`, `EXECUTING`) on the same distinction.
///  * instants are `DATETIME(6)` and always written in UTC — see
///    `sqlInstant` in `datasources/sql_instant.dart`.
///  * `job_name` is `VARCHAR(160)` rather than 191 so the composite unique key
///    stays inside the 767-byte index limit of older InnoDB row formats
///    (160 × 4 bytes of utf8mb4 + 8 bytes of `DATETIME(6)`).
TomFrameworkTable jobRunTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'jobRunTable',
  columns: const [
    TomFrameworkColumn('seq', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('id', 'VARCHAR(191)'),
    TomFrameworkColumn('job_name', 'VARCHAR(160)'),
    TomFrameworkColumn('scheduled_for', 'DATETIME(6)'),
    TomFrameworkColumn('run_at', 'DATETIME(6)'),
    TomFrameworkColumn('state', 'VARCHAR(16)'),
    TomFrameworkColumn('attempt', 'INT', defaultValue: '1'),
    TomFrameworkColumn('claimed_by', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('claimed_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('started_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('last_error', 'TEXT', nullable: true),
    TomFrameworkColumn('completed_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('payload', 'LONGTEXT', nullable: true),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey.unique('seq', ['seq']),
    TomFrameworkKey.unique('window', ['job_name', 'scheduled_for']),
    TomFrameworkKey('due', ['state', 'run_at']),
    TomFrameworkKey('lease', ['state', 'claimed_at']),
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
