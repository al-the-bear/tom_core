-- Reference migration for the relational job queue (`TomSqlJobStore`).
--
-- Creates the `tom_job_run` table: one row per scheduled run of a job, shared
-- by every node of a cluster. This file is the canonical DDL and is kept in
-- sync with `jobRunTableDdl()` in
-- `lib/src/tomserver/scheduling/sql_scheduling_sql.dart`;
-- `test/scheduling_schema_test.dart` fails if the two drift apart.
--
-- Two things carry the design:
--
--  * UNIQUE (job_name, tenant, window_at) makes the scheduler's idempotence
--    key — one run per job per window, per tenant — a database invariant
--    rather than a convention, so a duplicate window cannot exist even under a
--    race. `tenant` is '' for a run of no tenant, not NULL: a unique key never
--    treats two NULLs as equal. That is exactly why `window_at` IS nullable:
--    it is `scheduled_for` for a run that realises a window and NULL for a run
--    a component enqueued under an id of its own (the outbox, the saga
--    orchestrator), whose id is its key — two such runs enqueued in one
--    instant, on two nodes, stay two runs. `job_name` is VARCHAR(150) so the
--    key stays inside the 767-byte limit of older InnoDB row formats.
--  * `seq` is an AUTO_INCREMENT surrogate that exists only to give the queue a
--    stable insertion order, so two nodes scanning it see the same order. The
--    run's own id remains the primary key, because that is what every claim,
--    completion and failure statement addresses.
--
--  * `claim_token` is the fencing counter: it rises on every claim of a run and
--    never repeats, so two claims of the same run are orderable and a node whose
--    lease lapsed while it was partitioned cannot record an outcome over the
--    peer that took its work. It is the queue's counterpart of `tom_lease.token`
--    — the same problem, solved the same way, because the queue and the lock
--    must agree about who holds a run. `claimed_at` cannot serve in its place:
--    that is the heartbeat, and it moves while an attempt runs.
--
-- `started_at` is nullable and the null carries meaning: a `running` row without
-- it was reserved and then lost before anything executed, so re-queueing it
-- cannot repeat a side effect; a `running` row with it was interrupted
-- mid-execution and may only be offered again when the job opted in
-- (`requestsRecovery`). Quartz spends two trigger states on the same line.
--
-- `priority` orders the claim (most urgent first, insertion order among
-- equals); it is copied from the job when the run is planned. `checkpoint` is
-- the JSON text of the progress the job last saved, kept across retries and
-- recovery so the next attempt can continue from it.
--
-- Instants are DATETIME(6) and are always written in UTC by the store.
CREATE TABLE IF NOT EXISTS tom_job_run (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
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
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_job_run_seq (seq),
  UNIQUE KEY uq_tom_job_run_window (job_name, tenant, window_at),
  KEY ix_tom_job_run_due (state, run_at),
  KEY ix_tom_job_run_lease (state, claimed_at)
);
