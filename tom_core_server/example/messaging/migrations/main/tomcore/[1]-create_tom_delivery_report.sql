-- Reference migration for the delivery-correlation index
-- (`TomSqlDeliveryReportStore`).
--
-- Creates `tom_delivery_report`: one row per carrier identifier, which is the
-- only key a carrier's delivery callback carries. This file is the canonical
-- DDL and is kept in sync with `deliveryReportTable()` in
-- `lib/src/tomserver/messaging/delivery_report_sql.dart`;
-- `test/framework_schema_test.dart` replays this chain and compares the schema
-- it builds against the descriptor, so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and construct the store with `createSchema: false`. A store over a
-- renamed table ships no migration of its own: call
-- `deliveryReportTableDdl(name)` with the name you passed the constructor and
-- apply what it returns.
--
-- Notes on the shape:
--
--  * `remote_id` is the primary key and *is* the row's identity. There is no
--    surrogate key: a second row for one carrier id would make "which message
--    does this report concern" depend on row order, which is the one question
--    the table exists to answer.
--  * `message_id` is what a deployment actually wants back, and carries its own
--    index because the other direction — "what became of this message" — is the
--    question a support engineer asks and is not the primary key.
--  * `channel` lets a deployment routing several carriers through one endpoint
--    tell whose report it is reading, without joining anything.
--  * `state` is NULL until a report arrives, and that is the difference between
--    "sent, nothing heard" and "reported". A default would erase the
--    distinction that makes an outstanding delivery findable.
--  * `sent_at` carries the retention sweep, so it is indexed: pruning is
--    otherwise a full scan of a table that grows with every message ever sent.
--  * instants are DATETIME(6) and are always written in UTC. The width is the
--    column agreeing with its writer: every DateTime the framework binds is
--    rendered with six fractional digits, and MariaDB silently *rounds* the
--    extra precision onto a narrower column — so a plain DATETIME would hold a
--    different moment rather than a coarser one.

CREATE TABLE IF NOT EXISTS tom_delivery_report (
  remote_id   VARCHAR(191) NOT NULL,
  message_id  VARCHAR(191) NOT NULL,
  channel     VARCHAR(64)  NOT NULL,
  sent_at     DATETIME(6)  NOT NULL,
  state       VARCHAR(32)  NULL,
  reported_at DATETIME(6)  NULL,
  detail      TEXT         NULL,
  PRIMARY KEY (remote_id),
  KEY ix_tom_delivery_report_message (message_id),
  KEY ix_tom_delivery_report_sent (sent_at)
);
