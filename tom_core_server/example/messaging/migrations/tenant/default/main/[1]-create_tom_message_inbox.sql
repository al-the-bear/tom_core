-- Reference migration for the idempotent-receiver inbox (`TomSqlInbox`).
--
-- Creates `tom_message_inbox`: one row per message a consumer has processed.
-- This file is the canonical DDL and is kept in sync with `inboxTable()` in
-- `lib/src/tomserver/messaging/inbox_sql.dart`; `test/framework_schema_test.dart`
-- replays this chain and compares the schema it builds against the descriptor,
-- so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and construct the inbox with `createSchema: false`. An inbox over a
-- renamed table ships no migration of its own: call `inboxTableDdl(name)` with
-- the name you passed the constructor and apply what it returns.
--
-- Notes on the shape:
--
--  * the primary key `(tenant, consumer, message_id)` is the mechanism: recording a
--    message is an insert the key refuses for a message already processed, in
--    the same transaction as the consumer's work.
--  * `consumer` is VARCHAR(150) so the composite key stays within the index
--    length a utf8mb4 column allows.
--  * `processed_at` carries the purge, so it is indexed.
-- A tenant table: it lives where the tenant's data lives, and `tenant` leads the
-- primary key, so tenants sharing one schema each process a message once.
CREATE TABLE IF NOT EXISTS tom_message_inbox (
  tenant       VARCHAR(32)  NOT NULL DEFAULT '',
  consumer     VARCHAR(150) NOT NULL,
  message_id   VARCHAR(191) NOT NULL,
  processed_at DATETIME(6)  NOT NULL,
  PRIMARY KEY (tenant, consumer, message_id),
  KEY ix_tom_message_inbox_processed (processed_at)
);
