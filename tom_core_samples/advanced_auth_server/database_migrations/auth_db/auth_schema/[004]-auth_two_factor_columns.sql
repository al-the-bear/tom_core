-- Second-factor enrolment columns.
--
-- Untagged on purpose: these are schema, not demo content, so they must reach
-- **every** environment including production. (The demo account that uses them
-- is a separate, `@dev,test`-tagged migration — [005].)
--
-- The same two columns are also declared in [000]-auth_core_schema.sql, which is
-- what a fresh database gets. They are repeated here as idempotent `ADD COLUMN
-- IF NOT EXISTS` so a database created *before* 2FA existed — whose [000] is
-- already recorded as applied and will never run again — picks them up too.
--
-- NULL on both columns means "password-only login", which is what makes
-- enabling 2FA for an account a data change rather than a code change.
-- two_factor_secret is server-only: it is never projected onto the principal and
-- so never reaches a token claim.

ALTER TABLE auth_users
  ADD COLUMN IF NOT EXISTS two_factor_type   VARCHAR(64)  NULL,
  ADD COLUMN IF NOT EXISTS two_factor_secret VARCHAR(255) NULL;
