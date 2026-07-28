/// The schema and the instant encoding shared by the relational scheduling
/// pair.
///
/// The DDL lives here, in one place, rather than in each store: the shipped
/// migration files under `example/scheduling/migrations/` carry the same text,
/// and a test asserts they have not drifted apart. A schema that exists twice
/// and is checked once is a schema that will eventually exist in two versions.
library;

/// The default name of the job queue table.
const String defaultJobRunTable = 'tom_job_run';

/// The default name of the lease table.
const String defaultLeaseTable = 'tom_lease';

/// The DDL for the job queue table [table].
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
///  * instants are `DATETIME(6)` and always written in UTC — see
///    [sqlInstant].
///  * `job_name` is `VARCHAR(160)` rather than 191 so the composite unique key
///    stays inside the 767-byte index limit of older InnoDB row formats
///    (160 × 4 bytes of utf8mb4 + 8 bytes of `DATETIME(6)`).
String jobRunTableDdl(String table) => '''
CREATE TABLE IF NOT EXISTS $table (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  id            VARCHAR(191) NOT NULL,
  job_name      VARCHAR(160) NOT NULL,
  scheduled_for DATETIME(6)  NOT NULL,
  run_at        DATETIME(6)  NOT NULL,
  state         VARCHAR(16)  NOT NULL,
  attempt       INT          NOT NULL DEFAULT 1,
  claimed_by    VARCHAR(191) NULL,
  claimed_at    DATETIME(6)  NULL,
  last_error    TEXT         NULL,
  completed_at  DATETIME(6)  NULL,
  payload       LONGTEXT     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_${table}_seq (seq),
  UNIQUE KEY uq_${table}_window (job_name, scheduled_for),
  KEY ix_${table}_due (state, run_at),
  KEY ix_${table}_lease (state, claimed_at)
)''';

/// The DDL for the lease table [table].
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
/// self-fencing bug the kernel's contract suite caught during csex8.
/// Incrementing `version` on every write makes a matching update always change
/// the row, and doubles as the compare-and-set guard for takeover.
String leaseTableDdl(String table) => '''
CREATE TABLE IF NOT EXISTS $table (
  resource    VARCHAR(191) NOT NULL,
  owner       VARCHAR(191) NOT NULL,
  token       BIGINT       NOT NULL,
  acquired_at DATETIME(6)  NOT NULL,
  expires_at  DATETIME(6)  NOT NULL,
  released    TINYINT(1)   NOT NULL DEFAULT 0,
  version     BIGINT       NOT NULL DEFAULT 1,
  PRIMARY KEY (resource)
)''';

/// Renders [value] as the UTC `DATETIME(6)` literal the columns bind.
///
/// Always UTC, always six fractional digits. A cluster whose nodes disagree
/// about the local zone must still agree about an instant, and the fixed width
/// keeps the text comparable in SQL as well as in Dart.
String sqlInstant(DateTime value) {
  final utc = value.toUtc();
  String pad(int v, int width) => v.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}-${pad(utc.month, 2)}-${pad(utc.day, 2)} '
      '${pad(utc.hour, 2)}:${pad(utc.minute, 2)}:${pad(utc.second, 2)}.'
      '${pad(utc.millisecond, 3)}${pad(utc.microsecond, 3)}';
}

/// Reads a stored `DATETIME(6)` back as a UTC [DateTime].
///
/// The driver hands back the column's text; `DateTime.parse` on it alone would
/// produce a *local* `DateTime`, which compares unequal to the UTC value that
/// was written even though it denotes the same wall-clock reading. Appending
/// the zone marker is what makes the round trip exact.
DateTime parseSqlInstant(String value) {
  final text = value.trim();
  return DateTime.parse(text.endsWith('Z') ? text : '${text}Z');
}
