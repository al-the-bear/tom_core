-- tom:expand
-- Expand: this migration only creates tables, so the app server — whose own
-- chain in this history ends below [100] — still serves the schema it leaves
-- (the schema version guard reads this marker; see the framework's
-- db_migration guide, "Expand, then contract").
-- Framework scheduling and audit tables, in the app server's existing app_db.
--
-- **Why this file is in the ops server's package and not the app server's.**
-- The migration engine matches a chain to a database by the folder names —
-- `<datasource>/<schema>` — not by which package the folder sits in, and it
-- imposes no contiguity on versions: it records an applied version per
-- (datasource, schema) and applies whatever it has not seen. So the same logical
-- chain can be *contributed to* by more than one package, and the natural owner
-- of a table is the server that needs it. `[000]`–`[099]` are the app server's
-- application schema; `[100]` and up are the ops server's operational schema.
-- Nothing in the app server's package mentions a job queue it never runs.
--
-- The version number is the one coordination cost of that arrangement, and it is
-- a real one: two packages numbering into one chain must not pick the same
-- number, and neither can see the other's choice. Hence the **bands** — the gap
-- between the app server's highest migration and `[100]` is deliberate. Within
-- its band each package numbers freely and no coordination is needed at all;
-- the app server may add a migration tomorrow without this file moving. The
-- bands are checked rather than trusted: `test/ops_migration_chain_test.dart`
-- reads both directories and fails if either side numbers outside its range.
--
-- This file was `[004]` until the app server legitimately grew an `[004]` of its
-- own and the two collided — the engine records "4 applied" and silently never
-- runs the second file, which surfaces as a missing table at the first tick of
-- whichever deployment was provisioned last. The bands exist so that cannot
-- recur.
--
-- **Why these tables live in app_db rather than a database of their own.** An
-- operations server with its own store is a second system of record. The queue
-- would then be transactionally separate from the rows the jobs mutate, and the
-- audit trail separate again — so "the purge deleted these items" and "the trail
-- says so" would be two facts that can disagree. One database keeps them one
-- fact. It also keeps the sample's promise: no new infrastructure.
--
-- The DDL is copied verbatim from the framework's canonical reference migrations
-- (tom_core_server/example/scheduling/migrations/system/main/tomcore/[1]–[5] and
-- example/audit/migrations/system/main/tomcore/[1]) and kept in step with the
-- jobRunTable() / leaseTable() / schedulerNodeTable() / jobPauseTable() /
-- jobRunArchiveTable() / auditTrailTable() descriptors by test/ops_framework_schema_test.dart, which fails if this file
-- and those descriptors drift apart.
--
-- Untagged on purpose: schema, not demo content, so it reaches every environment.

-- ---------------------------------------------------------------------------
-- The job queue.
-- ---------------------------------------------------------------------------
-- `uq_tom_job_run_window` is the load-bearing constraint: it makes "one run per
-- job per window" — per tenant, `tenant` being '' for a run of none — a
-- database invariant rather than a convention, so two ops nodes planning the
-- same nightly purge cannot both succeed. The window is `window_at`, which a run
-- the outbox enqueues under its own id leaves NULL: a unique key holds any number
-- of NULLs, so two messages queued in one instant stay two runs. This sample runs
-- one node — but the
-- table it runs on is the clustered one, because a schema that only works
-- single-node is a schema you discover you have on the day you add the second.
-- `claim_token` is the other clustered column: it rises on every claim of a run
-- and never repeats, so a node whose lease expired cannot report an outcome
-- over the peer that re-claimed its work. Single-node it never advances past 1,
-- and it is here for the same reason the unique key is. `priority` orders the
-- claim and `checkpoint` keeps a job's saved progress across retries and
-- recovery.
CREATE TABLE IF NOT EXISTS tom_job_run (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  id            VARCHAR(191) NOT NULL,
  job_name      VARCHAR(160) NOT NULL,
  tenant        VARCHAR(32)  NOT NULL DEFAULT '',
  scheduled_for DATETIME(6)  NOT NULL,
  window_at     DATETIME(6)  NULL,
  run_at        DATETIME(6)  NOT NULL,
  state         VARCHAR(16)  NOT NULL,
  attempt       INT          NOT NULL DEFAULT 1,
  claimed_by    VARCHAR(191) NULL,
  claimed_at    DATETIME(6)  NULL,
  claim_token   BIGINT       NOT NULL DEFAULT 0,
  started_at    DATETIME(6)  NULL,
  completed_at  DATETIME(6)  NULL,
  last_error    TEXT         NULL,
  payload       LONGTEXT     NULL,
  priority      INT          NOT NULL DEFAULT 0,
  checkpoint    LONGTEXT     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_job_run_seq (seq),
  UNIQUE KEY uq_tom_job_run_window (job_name, tenant, window_at),
  KEY ix_tom_job_run_due (state, run_at),
  KEY ix_tom_job_run_lease (state, claimed_at)
);

-- ---------------------------------------------------------------------------
-- Paused jobs.
-- ---------------------------------------------------------------------------
-- One row per paused job; the claim scan leaves out every job named here, on
-- every node. The store reads it on every pass, so it must exist even when no
-- job is ever paused.
CREATE TABLE IF NOT EXISTS tom_job_pause (
  job_name  VARCHAR(150) NOT NULL,
  paused_at DATETIME(6)  NOT NULL,
  PRIMARY KEY (job_name)
);

-- ---------------------------------------------------------------------------
-- The run archive.
-- ---------------------------------------------------------------------------
-- Where the nightly housekeeping moves finished runs instead of deleting them:
-- every queue column plus `archived_at`. No unique window key — a window may be
-- planned again after its run was archived.
CREATE TABLE IF NOT EXISTS tom_job_run_archive (
  seq           BIGINT       NOT NULL,
  id            VARCHAR(191) NOT NULL,
  job_name      VARCHAR(150) NOT NULL,
  tenant        VARCHAR(32)  NOT NULL DEFAULT '',
  scheduled_for DATETIME(6)  NOT NULL,
  window_at     DATETIME(6)  NULL,
  run_at        DATETIME(6)  NOT NULL,
  state         VARCHAR(16)  NOT NULL,
  attempt       INT          NOT NULL DEFAULT 1,
  claimed_by    VARCHAR(191) NULL,
  claimed_at    DATETIME(6)  NULL,
  claim_token   BIGINT       NOT NULL DEFAULT 0,
  started_at    DATETIME(6)  NULL,
  last_error    TEXT         NULL,
  completed_at  DATETIME(6)  NULL,
  payload       LONGTEXT     NULL,
  priority      INT          NOT NULL DEFAULT 0,
  checkpoint    LONGTEXT     NULL,
  archived_at   DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_tom_job_run_archive_archived (archived_at),
  KEY ix_tom_job_run_archive_job (job_name, scheduled_for)
);

-- ---------------------------------------------------------------------------
-- The coordination lease.
-- ---------------------------------------------------------------------------
-- `token` is the fencing counter, which is why a released lease keeps its row
-- (flagged `released = 1`) rather than being deleted: a deleted row restarts the
-- counter at 1 for the next holder, and a token that repeats is not a fencing
-- token. `version` exists because MariaDB reports *changed* rows rather than
-- matched rows — without it, a renewal writing the values already present would
-- affect zero rows and read as a lost lease.
CREATE TABLE IF NOT EXISTS tom_lease (
  resource    VARCHAR(191) NOT NULL,
  owner       VARCHAR(191) NOT NULL,
  token       BIGINT       NOT NULL,
  acquired_at DATETIME(6)  NOT NULL,
  expires_at  DATETIME(6)  NOT NULL,
  released    TINYINT(1)   NOT NULL DEFAULT 0,
  version     BIGINT       NOT NULL DEFAULT 1,
  PRIMARY KEY (resource)
);

-- ---------------------------------------------------------------------------
-- The roll call.
-- ---------------------------------------------------------------------------
-- One row per node, rewritten on every check-in, so recovery can notice a
-- departed *node* rather than only an expired lease.
CREATE TABLE IF NOT EXISTS tom_scheduler_node (
  node_id          VARCHAR(191) NOT NULL,
  checkin_at       DATETIME(6)  NOT NULL,
  checkin_interval BIGINT       NOT NULL,
  PRIMARY KEY (node_id)
);

-- ---------------------------------------------------------------------------
-- The audit trail.
-- ---------------------------------------------------------------------------
-- Each entry hashes its predecessor, so a chain has exactly one head — and the
-- three unique keys are what turn a fork into a duplicate-key error at insert
-- time rather than silent corruption found at the next audit. `writer` scopes
-- all three: two processes appending to one table each track their own head, and
-- interleaved rows would fail verification not because anything was tampered
-- with but because they were never one chain.
--
-- The trail is written by *this* server (the purge job's deletes go through the
-- app server's repository, which is the chokepoint) and read by anyone. Nothing
-- here grants the write-once property; that is a deployment's grant to make, and
-- the sink reports what it found at boot rather than assuming — see
-- README_advanced_14_operations.md.
CREATE TABLE IF NOT EXISTS tom_audit_trail (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  writer        VARCHAR(64)  NOT NULL,
  entry_index   BIGINT       NOT NULL,
  entry_id      VARCHAR(191) NOT NULL,
  recorded_at   DATETIME(6)  NOT NULL,
  actor         VARCHAR(160) NOT NULL,
  action        VARCHAR(16)  NOT NULL,
  target        VARCHAR(160) NOT NULL,
  target_key    VARCHAR(191) NULL,
  outcome       VARCHAR(16)  NOT NULL,
  request_id    VARCHAR(191) NULL,
  tenant        VARCHAR(32)  NULL,
  previous_hash CHAR(64)     NOT NULL,
  hash          CHAR(64)     NOT NULL,
  record        LONGTEXT     NOT NULL,
  PRIMARY KEY (seq),
  UNIQUE KEY uq_tom_audit_trail_link (writer, previous_hash),
  UNIQUE KEY uq_tom_audit_trail_hash (writer, hash),
  UNIQUE KEY uq_tom_audit_trail_index (writer, entry_index),
  KEY ix_tom_audit_trail_time (writer, recorded_at),
  KEY ix_tom_audit_trail_target (target, action),
  KEY ix_tom_audit_trail_actor (actor),
  KEY ix_tom_audit_trail_tenant (tenant, recorded_at)
);
