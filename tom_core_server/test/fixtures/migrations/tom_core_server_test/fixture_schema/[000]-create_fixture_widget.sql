-- Fixture migration for the db_migration DB-backed test (RCK13).
--
-- A minimal, multi-statement DDL script: it exercises the migrator's
-- statement splitting (two statements on their own commands) and gives the
-- versioning/idempotency assertions a real table to create. The `fixture_widget`
-- table itself is incidental — the test asserts on the `fixture_schema_versioning`
-- bookkeeping the migrator maintains, not on this table's contents.
CREATE TABLE IF NOT EXISTS fixture_widget (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  label VARCHAR(255) NULL,
  PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS fixture_widget_label_idx ON fixture_widget (label);
