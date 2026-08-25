-- Reference migration for the database blob store's content table
-- (`TomDatabaseBlobStore`).
--
-- Creates `tom_blob_chunk`: many rows per blob, one per chunk. This file is the
-- canonical DDL and is kept in sync with `blobChunkTableDdl()` in
-- `lib/src/tomserver/file_storage/database_blob_sql.dart`;
-- `test/file_storage_schema_test.dart` fails if the two drift apart, and
-- `test/framework_schema_test.dart` additionally replays this chain and
-- compares the schema it builds against the descriptor.
--
-- Keyed on `(upload_id, chunk_index)` rather than on the storage key, because
-- the chunks of an in-flight write must be addressable *before* anything commits
-- to them — that separation is what makes the manifest REPLACE atomic, and it is
-- also what leaves an interrupted upload as unreferenced chunk rows rather than
-- as a half-written blob.
--
-- `chunk_data` is LONGTEXT and holds **base64**, not raw bytes. The MariaDB
-- driver decodes every column value into a Dart String before the row mapper
-- sees it, so a BLOB would come back mangled by UTF-8 decoding; text is the only
-- correct representation available here, at a cost of 33 % in storage. Size the
-- tablespace accordingly, and prefer `TomS3BlobStore` or
-- `TomDirectoryBlobStore` where that cost matters.
CREATE TABLE IF NOT EXISTS tom_blob_chunk (
  upload_id   VARCHAR(64) NOT NULL,
  chunk_index INT         NOT NULL,
  chunk_data  LONGTEXT    NOT NULL,
  PRIMARY KEY (upload_id, chunk_index)
);
