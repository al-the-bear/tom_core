-- tom:expand
-- Expand: this migration only creates tables, so the app server — whose own
-- chain in this history ends below [100] — still serves the schema it leaves
-- (the schema version guard reads this marker; see the framework's
-- db_migration guide, "Expand, then contract").
-- The saved audit questions (the framework's audit_reports module), in app_db.
--
-- The ops server delivers saved questions on their schedules — it is the
-- process with the scheduler, the outbox and the export store — and the app
-- server serves the `/audit-reports` API that saves them, so the table sits in
-- the database both reach, beside the audit trail `[100]` creates. It is in the
-- ops server's band for the reason `[100]` gives: the ops server is the table's
-- natural owner, and nothing in the app server's chain mentions a delivery pass
-- it never runs.
--
-- Copied from the framework's reference migration
-- (`tom_core_server/example/audit_reports/migrations/`), so the DDL is
-- `auditQuestionTable()`'s; `test/ops_framework_schema_test.dart` replays the
-- whole chain and fails if the two drift apart.

CREATE TABLE IF NOT EXISTS tom_audit_question (
  id                VARCHAR(64)  NOT NULL,
  owner             VARCHAR(191) NOT NULL,
  name              VARCHAR(255) NOT NULL,
  definition        TEXT         NOT NULL,
  schedule          VARCHAR(255) NULL,
  next_delivery_at  DATETIME(6)  NULL,
  last_delivered_at DATETIME(6)  NULL,
  updated_at        DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_tom_audit_question_owner (owner, name),
  KEY ix_tom_audit_question_due (next_delivery_at)
);
