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
-- `preference_key` and `value_type` name their collation, utf8mb4_bin, rather
-- than inheriting the server's: under a case-insensitive default the unique key
-- would make `device.Theme` and `device.theme` one row, and ORDER BY would not
-- be the code-unit order the contract promises.
--
-- `principal_id` holds TomPrincipal.qualifiedId — the principal id qualified by
-- its tenant (`tenant:<id>/<principal id>`, the bare id without tenancy) —
-- because the entity's `@TomDbScope(field: 'principal_id', scope: 'owner')`
-- binds that key into every statement. A principal id is unique within its
-- tenant only; the qualified key keeps two tenants' rows apart when they share
-- this table.
--
-- This file is the canonical DDL and reproduces
-- `TomUserPreference.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. The
-- db_migration module applies it as version [1] of the `tomcore` schema on the
-- `main` datasource. It carries no
-- `@environment` suffix on purpose: a schema migration is never
-- environment-tagged (G-MIG-1, G-MIG-2, C-16), because a table that exists only
-- in some environments makes the code above it conditional on the deployment.
-- `tenant_id` is the row's tenant: the entity is a tenant table
-- (`@TomTenantTable`), and the repository binds `tenant_id = <tenant>` into
-- every statement, in every isolation model. It defaults to `default`, the
-- implicit tenant of a deployment without tenancy, and leads the unique key,
-- so tenants sharing the table may each hold the same key.
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32) NOT NULL DEFAULT 'default',
  principal_id VARCHAR(255) NOT NULL,
  preference_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_type VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_preference (tenant_id, principal_id, preference_key),
  KEY idx_tom_user_preference_principal (principal_id)
);
