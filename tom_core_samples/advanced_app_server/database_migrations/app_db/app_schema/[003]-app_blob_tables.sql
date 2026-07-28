-- Framework blob-store tables for TomDatabaseBlobStore, in app_db.
--
-- Untagged on purpose: schema, not demo content, so it reaches every
-- environment. The DDL is copied verbatim from the framework's canonical
-- reference migrations
-- (tom_core_server/example/file_storage/migrations/main/tomcore/[1] and [2]) and
-- is kept in sync with the blobManifestTable() / blobChunkTable() descriptors in
-- lib/src/tomserver/file_storage/database_blob_sql.dart. The convergence test
-- in test/app_blob_schema_test.dart fails if this file and those descriptors
-- drift apart.
--
-- **Why these tables live in app_db rather than in a store of their own.** The
-- app server already owns a database, and the blob store is backed by it — so
-- adding file transfer to this sample introduces no new infrastructure: no
-- object store, no shared mount, no extra credential. The auth server does the
-- same thing in auth_db ([006]-auth_blob_tables.sql, byte-identical to this
-- file). Each server therefore writes its blobs into its *own* database, which
-- keeps the two-database boundary of the sample intact: an app attachment never
-- lands in auth_db, and a user avatar never lands in app_db.
--
-- Both tables must live in the same database as each other: a manifest whose
-- chunks are unreachable is not a degraded store, it is a store that reports
-- files it cannot serve.
--
-- Notes on the shape (from the framework reference):
--
--  * storage_key is the primary key and is what a caller names a blob by. The
--    VARCHAR width matches TomBlobStore.maxKeyLength exactly, so the column
--    cannot silently truncate a key the validator accepted — the same width the
--    app_items.attachment / internal_note columns use.
--  * upload_id is the *committed* upload, and is the whole commit protocol:
--    chunks are written under a fresh id and this one row is then REPLACEd in a
--    single statement, so a reader sees either the previous blob or the complete
--    new one, never a manifest pointing at chunks still arriving.
--  * chunk_count is what a download iterates, so a manifest and its chunks
--    disagree loudly (a missing-chunk error) rather than quietly truncating.
--  * chunk_data is LONGTEXT and holds **base64**, not raw bytes: the MariaDB
--    driver decodes every column value into a Dart String before the row mapper
--    sees it, so a BLOB would come back mangled by UTF-8 decoding. Text is the
--    only correct representation available here, at a cost of 33 % in storage.

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

CREATE TABLE IF NOT EXISTS tom_blob_chunk (
  upload_id   VARCHAR(64) NOT NULL,
  chunk_index INT         NOT NULL,
  chunk_data  LONGTEXT    NOT NULL,
  PRIMARY KEY (upload_id, chunk_index)
);
