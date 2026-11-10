-- Reference migration for the deduplicating blob store's ledger
-- (`TomSqlBlobLedger`), key table.
--
-- Creates `tom_blob_ledger`: one row per logical key of a
-- `TomDeduplicatingBlobStore` — who it counts against, the SHA-256 of its
-- content and the key that content is stored under, its size, media type,
-- file name and write time. Many rows may name one content; that is the
-- deduplication. This file is the canonical DDL and is kept in sync with
-- `blobLedgerTableDdl()` in `lib/src/tomserver/file_storage/blob_ledger_sql.dart`;
-- `test/file_storage_schema_test.dart` fails if the two drift apart, and
-- `test/framework_schema_test.dart` additionally replays this chain and
-- compares the schema it builds against the descriptor.
--
-- `owner` is '' for a blob of no one, which no quota counts. `(owner,
-- stored_at)` serves the quota's sum; `content_digest` the reclaim's "does
-- anything still name this content"; `stored_at` the orphan sweep.
--
-- Instants are DATETIME(6) and are always written in UTC by the ledger.
CREATE TABLE IF NOT EXISTS tom_blob_ledger (
  blob_key       VARCHAR(512) NOT NULL,
  owner          VARCHAR(191) NOT NULL DEFAULT '',
  content_digest CHAR(64)     NOT NULL,
  content_key    VARCHAR(512) NOT NULL,
  byte_count     BIGINT       NOT NULL,
  media_type     VARCHAR(255) NOT NULL,
  file_name      VARCHAR(255) NULL,
  stored_at      DATETIME(6)  NOT NULL,
  PRIMARY KEY (blob_key),
  KEY ix_tom_blob_ledger_owner (owner, stored_at),
  KEY ix_tom_blob_ledger_content (content_digest),
  KEY ix_tom_blob_ledger_stored (stored_at)
);
