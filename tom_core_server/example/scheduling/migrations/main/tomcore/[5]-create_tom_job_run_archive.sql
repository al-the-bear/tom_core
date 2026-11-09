-- Reference migration for the archive of the relational job queue
-- (`TomSqlJobStore.purgeFinished`).
--
-- Creates the `tom_job_run_archive` table: the runs a purge removed from
-- `tom_job_run`, with every column of the queue and `archived_at`, when the run
-- was moved. This file is the canonical DDL and is kept in sync with
-- `jobRunArchiveTableDdl()` in
-- `lib/src/tomserver/scheduling/sql_scheduling_sql.dart`;
-- `test/scheduling_schema_test.dart` fails if the two drift apart.
--
-- A purge copies the finished runs here and deletes exactly the copied ones
-- from the queue, in one transaction, so a run is in one table or the other.
-- `seq` is the queue's insertion order carried over, not a counter of its own,
-- and there is no unique window key: a window may be planned again after its
-- run was archived. The archive is bounded by its own purge
-- (`TomSqlJobStore.purgeArchive`), on `archived_at`.
--
-- Instants are DATETIME(6) and are always written in UTC by the store.
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
