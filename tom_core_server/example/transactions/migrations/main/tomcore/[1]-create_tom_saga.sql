-- Reference migration for the saga store (`TomSqlSagaStore`).
--
-- Creates `tom_saga`: one row per saga a `TomSagaOrchestrator` began, holding
-- where it is, its data and the version every transition is written over. This
-- file is the canonical DDL and is kept in sync with `sagaTable()` in
-- `lib/src/tomserver/transactions/saga_sql.dart`;
-- `test/framework_schema_test.dart` replays this chain and compares the schema
-- it builds against the descriptor, so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and configure the store with `createSchema: false`. Under tenancy with a
-- database or schema per tenant, apply it in each tenant's tree: the store
-- resolves its data source per call, so a tenant's sagas live with its data.
--
-- Notes on the shape:
--
--  * the primary key is `(tenant, saga_id)`; `tenant` is '' outside tenancy.
--  * `status` is running, compensating, completed, compensated or failed, and
--    `step` the cursor: the next step to run, or to compensate.
--  * `version` grows with every transition, which is written only over the
--    version it was made from — of two nodes advancing a saga, one wins.
--  * `data` is the saga's JSON data; `error` why it compensates or failed.
--  * `run_window` is the window instant of the job run carrying the current
--    version, its key in the job store: how a resumption tells whether that
--    run still exists.
--  * `(status, updated_at)` serves resumption and the purge, so it is indexed.
CREATE TABLE IF NOT EXISTS tom_saga (
  tenant     VARCHAR(32)  NOT NULL,
  saga_id    VARCHAR(191) NOT NULL,
  saga_name  VARCHAR(120) NOT NULL,
  status     VARCHAR(16)  NOT NULL,
  step       INT          NOT NULL,
  version    INT          NOT NULL,
  data       LONGTEXT     NOT NULL,
  error      TEXT         NULL,
  run_window DATETIME(6)  NOT NULL,
  created_at DATETIME(6)  NOT NULL,
  updated_at DATETIME(6)  NOT NULL,
  PRIMARY KEY (tenant, saga_id),
  KEY ix_tom_saga_progress (status, updated_at)
);
