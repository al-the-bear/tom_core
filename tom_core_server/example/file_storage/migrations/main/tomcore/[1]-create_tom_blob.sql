-- Reference migration for the database blob store's manifest table
-- (`TomDatabaseBlobStore`).
--
-- Creates `tom_blob`: one row per stored blob. This file is the canonical DDL
-- and is kept in sync with the `blobManifestTable()` descriptor in
-- `lib/src/tomserver/file_storage/database_blob_sql.dart`;
-- `test/framework_schema_test.dart` fails if the two drift apart.
--
-- Apply this file (and its `[2]` sibling) when the application's database user
-- is not permitted to run DDL, and construct the store with
-- `createSchema: false`. Both tables must live in the same database as each
-- other: a manifest whose chunks are unreachable is not a degraded store, it is
-- a store that reports files it cannot serve.
--
-- Notes on the shape:
--
--  * `storage_key` is the primary key and is what a caller names a blob by. The
--    VARCHAR width matches `TomBlobStore.maxKeyLength` exactly, so the column
--    cannot silently truncate a key the validator accepted.
--  * `upload_id` is the *committed* upload, and is the whole commit protocol:
--    chunks are written under a fresh id and this one row is then REPLACEd in a
--    single statement, so a reader sees either the previous blob or the complete
--    new one, never a manifest pointing at chunks still arriving.
--  * `chunk_count` is what a download iterates, so a manifest and its chunks
--    disagree loudly (a missing-chunk error) rather than quietly truncating the
--    file.
--  * `stored_at` is a plain DATETIME, not DATETIME(6). A blob's write time is
--    metadata for a human, never an ordering the code depends on, so the
--    sub-second precision the scheduling tables need would be noise here.
CREATE TABLE IF NOT EXISTS tom_blob (
  storage_key VARCHAR(512) NOT NULL,
  upload_id   VARCHAR(64)  NOT NULL,
  media_type  VARCHAR(255) NOT NULL,
  file_name   VARCHAR(255) NULL,
  byte_count  BIGINT       NOT NULL,
  chunk_count INT          NOT NULL,
  stored_at   DATETIME     NOT NULL,
  PRIMARY KEY (storage_key)
);
