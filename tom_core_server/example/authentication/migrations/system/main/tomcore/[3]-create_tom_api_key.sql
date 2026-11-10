-- Reference migration for the API-key store's keys.
--
-- Creates `tom_api_key`: one row per key — the account it belongs to, the
-- SHA-256 of its secret (never the secret), its roles and label, and when it
-- was created, expires, was revoked and last used. A system table, in the
-- system schema beside the accounts.
--
-- The canonical DDL of `apiKeyTable` (authentication/sql_api_key_store.dart);
-- `test/framework_schema_test.dart` fails if the two drift apart.
CREATE TABLE IF NOT EXISTS tom_api_key (
  id           VARCHAR(64)  NOT NULL,
  account_id   VARCHAR(191) NOT NULL,
  secret_hash  CHAR(64)     NOT NULL,
  roles        TEXT         NOT NULL,
  label        VARCHAR(191) NOT NULL,
  created_at   DATETIME(6)  NOT NULL,
  expires_at   DATETIME(6)  NULL,
  revoked_at   DATETIME(6)  NULL,
  last_used_at DATETIME(6)  NULL,
  PRIMARY KEY (id),
  KEY ix_tom_api_key_account (account_id)
);
