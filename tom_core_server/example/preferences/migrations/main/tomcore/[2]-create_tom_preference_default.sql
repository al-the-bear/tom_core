-- Reference migration for default preferences beneath every principal's own.
--
-- Creates the `tom_preference_default` table: one row per default, for the
-- whole deployment (`scope_kind` 'deployment', `scope_name` '') or for the
-- holders of one role (`scope_kind` 'role', `scope_name` the role). A principal
-- reads its own value first, then the default of a role it holds — the highest
-- `precedence`, then the role name first in code-unit order — then the
-- deployment's.
--
-- `(scope_kind, scope_name, preference_key)` is unique: it is the default's
-- identity, and the conflict key a write replaces a default on in one
-- statement. `scope_name`, `preference_key` and `value_type` are
-- utf8mb4_bin for the reason `tom_user_preference`'s are — identity and order
-- stay case-sensitive whatever the server's default collation is.
--
-- The table has no owner column and no row scope: a default is nobody's own
-- row, and writing one is an administrative act (TomPreferenceDefaults, a
-- server-side service with no endpoint).
--
-- This file is the canonical DDL and reproduces
-- `TomPreferenceDefault.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. It is
-- version [2] of the `tomcore` schema on the `main` datasource and carries no
-- `@environment` suffix: a schema migration is never environment-tagged.
CREATE TABLE IF NOT EXISTS tom_preference_default (
  id BIGINT NOT NULL AUTO_INCREMENT,
  scope_kind VARCHAR(16) NOT NULL,
  scope_name VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  preference_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_type VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_json TEXT NULL,
  precedence INT NOT NULL DEFAULT 0,
  updated_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_preference_default (scope_kind, scope_name, preference_key)
);
