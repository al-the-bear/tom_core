-- @TomFileReference key columns on app_items.
--
-- Untagged on purpose: these are schema, not demo content, so they must reach
-- **every** environment including production.
--
-- The same two columns are also declared in [000]-app_core_schema.sql, which is
-- what a fresh database gets. They are repeated here as idempotent `ADD COLUMN
-- IF NOT EXISTS` so a database created *before* file columns existed — whose
-- [000] is already recorded as applied and will never run again — picks them up
-- too. This mirrors the auth server's [004] two-factor migration.
--
-- Both columns hold a **blob storage key**, never bytes; the payload lives in
-- the tom_blob / tom_blob_chunk tables created by [003]. VARCHAR(512) matches
-- TomBlobStore.maxKeyLength exactly, so the column cannot silently truncate a
-- key the validator accepted. NULL means "no file", which is what the blob
-- lifecycle reads as "nothing to delete".
--
-- The two differ only in what the *annotation* says about them, and that
-- difference is the point of the pair:
--
--   * attachment    — exposed: true, so the framework file endpoint publishes
--                     it as the slot app_items/<id>/attachment.
--   * internal_note — exposed defaults to false, so no slot is published and a
--                     request for app_items/<id>/internal_note is a 404 however
--                     privileged the caller is.
--
-- Nothing in the DDL encodes that distinction — the columns are identical here.
-- Whether a file may be fetched over HTTP is an authorization decision, and it
-- is declared next to the column in app_persistence_model.dart rather than in
-- the schema, precisely so it cannot drift away from the field it governs.

ALTER TABLE app_items
  ADD COLUMN IF NOT EXISTS attachment    VARCHAR(512) NULL,
  ADD COLUMN IF NOT EXISTS internal_note VARCHAR(512) NULL;
