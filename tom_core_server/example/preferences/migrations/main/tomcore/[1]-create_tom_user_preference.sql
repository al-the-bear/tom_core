-- Reference migration for server-stored user preferences (C-13).
--
-- Creates the `tom_user_preference` table that holds the settings which follow a
-- user across devices: one row per `(principal_id, preference_key)` pair,
-- carrying the value's JSON text, the name of the type it was written as, and
-- when the server last wrote it. The unique key is what makes writing a key
-- twice a replacement rather than a second row — with a duplicate, which value a
-- user gets would depend on row order.
--
-- `value_type` is stored beside `value_json` rather than derived from it because
-- JSON forgets: `3` is an `int` and a `double`, an ISO instant is a `String` and
-- a `DateTime`, and an object literal is every reflected class at once. Keeping
-- the written type lets TomUserPreferenceCodec rebuild a reflected value and
-- refuse a mismatched read instead of coercing it.
--
-- `principal_id` is BIGINT, matching TomPrincipal.id, because the entity's
-- `@TomDbScope(field: 'principal_id', scope: 'owner')` binds that id straight
-- into every statement. A VARCHAR column would compare a stringified id against
-- an integer bind value and match nothing — a scope that denies everything.
--
-- This file is the canonical DDL and reproduces
-- `TomUserPreference.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. The
-- db_migration module applies it as version [1] of the `tomcore` schema on the
-- `main` datasource. It carries no
-- `@environment` suffix on purpose: a schema migration is never
-- environment-tagged (G-MIG-1, G-MIG-2, C-16), because a table that exists only
-- in some environments makes the code above it conditional on the deployment.
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id BIGINT NOT NULL,
  preference_key VARCHAR(191) NOT NULL,
  value_type VARCHAR(191) NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_preference (principal_id, preference_key),
  KEY idx_tom_user_preference_principal (principal_id)
);
