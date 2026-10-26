-- Reference migration for the export register (`TomSqlExportRegister`).
--
-- Creates the `tom_export` table: one row per stored export — its storage key,
-- who it counts against, its media type, size and the instant it was stored.
-- The export store holds the bytes and cannot list them; this table is the
-- record the per-owner quota sums and the retention purge scans. This file is
-- the canonical DDL and is kept in sync with `exportRegisterTableDdl()` in
-- `lib/src/tomserver/export/export_register_sql.dart`;
-- `test/export_register_test.dart` fails if the two drift apart.
--
-- `export_key` is as wide as a blob store key. `owner` is '' for an export of
-- no one, which no quota counts. `(owner, stored_at)` serves the quota and an
-- owner's listing; `stored_at` the purge, which reads the oldest first.
--
-- Instants are DATETIME(6) and are always written in UTC by the register.
CREATE TABLE IF NOT EXISTS tom_export (
  export_key VARCHAR(512) NOT NULL,
  owner      VARCHAR(191) NOT NULL DEFAULT '',
  media_type VARCHAR(255) NOT NULL,
  byte_count BIGINT       NOT NULL,
  stored_at  DATETIME(6)  NOT NULL,
  title      VARCHAR(255) NULL,
  PRIMARY KEY (export_key),
  KEY ix_tom_export_owner (owner, stored_at),
  KEY ix_tom_export_stored (stored_at)
);
