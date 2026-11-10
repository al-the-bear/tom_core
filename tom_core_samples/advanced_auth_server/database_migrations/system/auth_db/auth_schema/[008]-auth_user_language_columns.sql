-- The account's stored language preference.
--
-- Untagged: a language preference is an account attribute every deployment
-- has, production included. Which demo user prefers German is demo content and
-- lives in the `@dev,test` seed beside this, [009].
--
-- The pair mirrors the framework's own model of a stored preference —
-- `TomPrincipal.language` / `.country`, read by `TomTextLocale.lenient` — rather
-- than one tag column, so a reader never has to decide whether `de-AT` and
-- `de_AT` are the same value. NULL language means "no preference": the reader
-- falls back to the deployment default in one place.
--
-- Declared in [000]-auth_core_schema.sql as well, which is what a fresh
-- database gets. Repeated here as idempotent `ADD COLUMN IF NOT EXISTS` so a
-- database whose [000] was applied before these columns existed picks them up.

ALTER TABLE auth_users
  ADD COLUMN IF NOT EXISTS language VARCHAR(16) NULL,
  ADD COLUMN IF NOT EXISTS country  VARCHAR(8)  NULL;
