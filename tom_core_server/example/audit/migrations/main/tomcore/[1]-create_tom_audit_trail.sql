-- Reference migration for the relational audit trail (`TomSqlAuditSink`).
--
-- Creates the `tom_audit_trail` table: one row per audit entry, appended and
-- never modified. This file is the canonical DDL and is kept in sync with
-- `auditTrailTableDdl()` in `lib/src/tomserver/audit/sql_audit_sql.dart`;
-- `test/audit_sql_test.dart` fails if the two drift apart.
--
-- Apply this migration with a **privileged** credential and serve the trail
-- with a restricted one — the serving user needs INSERT and SELECT and nothing
-- else. That grant, not this file, is what makes the table write-once; see
-- `doc/audit.md` § "The Write-Once Story".
--
-- Three things carry the design:
--
--  * `seq` is the primary key. Nothing addresses an audit row by anything else
--    — the trail is never updated and never joined — while insertion order is
--    load-bearing twice: it is the order the hash chain is read back in, and it
--    is the order retention trims a prefix from.
--  * `writer` names the chain a row belongs to, so several nodes may append to
--    one table without their entries interleaving into a sequence that fails
--    its own verification.
--  * UNIQUE (writer, previous_hash) makes chain linearity a database
--    invariant. Two entries claiming the same predecessor is a fork, and as a
--    constraint it surfaces at insert time instead of as silent corruption
--    discovered at the next verification.
--
-- Instants are DATETIME(6) and are always written in UTC by the sink.
CREATE TABLE IF NOT EXISTS tom_audit_trail (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  writer        VARCHAR(64)  NOT NULL,
  entry_id      VARCHAR(191) NOT NULL,
  recorded_at   DATETIME(6)  NOT NULL,
  actor         VARCHAR(160) NOT NULL,
  action        VARCHAR(16)  NOT NULL,
  target        VARCHAR(160) NOT NULL,
  target_key    VARCHAR(191) NULL,
  outcome       VARCHAR(16)  NOT NULL,
  request_id    VARCHAR(191) NULL,
  previous_hash CHAR(64)     NOT NULL,
  hash          CHAR(64)     NOT NULL,
  record        LONGTEXT     NOT NULL,
  PRIMARY KEY (seq),
  UNIQUE KEY uq_tom_audit_trail_link (writer, previous_hash),
  UNIQUE KEY uq_tom_audit_trail_hash (writer, hash),
  KEY ix_tom_audit_trail_time (writer, recorded_at),
  KEY ix_tom_audit_trail_target (target, action),
  KEY ix_tom_audit_trail_actor (actor)
);
