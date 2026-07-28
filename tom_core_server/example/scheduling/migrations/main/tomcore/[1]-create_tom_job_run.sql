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
--  * UNIQUE (job_name, scheduled_for) makes the scheduler's idempotence key —
--    one run per job per window — a database invariant rather than a
--    convention, so a duplicate window cannot exist even under a race.
--  * `seq` is an AUTO_INCREMENT surrogate that exists only to give the queue a
--    stable insertion order, so two nodes scanning it see the same order. The
--    run's own id remains the primary key, because that is what every claim,
--    completion and failure statement addresses.
--
-- `started_at` is nullable and the null carries meaning: a `running` row without
-- it was reserved and then lost before anything executed, so re-queueing it
-- cannot repeat a side effect; a `running` row with it was interrupted
-- mid-execution and may only be offered again when the job opted in
-- (`requestsRecovery`). Quartz spends two trigger states on the same line.
--
-- Instants are DATETIME(6) and are always written in UTC by the store.
CREATE TABLE IF NOT EXISTS tom_job_run (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  id            VARCHAR(191) NOT NULL,
  job_name      VARCHAR(160) NOT NULL,
  scheduled_for DATETIME(6)  NOT NULL,
  run_at        DATETIME(6)  NOT NULL,
  state         VARCHAR(16)  NOT NULL,
  attempt       INT          NOT NULL DEFAULT 1,
  claimed_by    VARCHAR(191) NULL,
  claimed_at    DATETIME(6)  NULL,
  started_at    DATETIME(6)  NULL,
  last_error    TEXT         NULL,
  completed_at  DATETIME(6)  NULL,
  payload       LONGTEXT     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_job_run_seq (seq),
  UNIQUE KEY uq_tom_job_run_window (job_name, scheduled_for),
  KEY ix_tom_job_run_due (state, run_at),
  KEY ix_tom_job_run_lease (state, claimed_at)
);
