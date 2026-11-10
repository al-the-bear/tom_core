-- The framework's second-factor enrolment table.
--
-- Untagged: schema, not demo content, so it must reach every environment. It
-- backs `TomPersistent2FAEnrolmentStore`, which is what lets a user who has no
-- factor set one up at first login instead of a DBA writing a secret into
-- `auth_users.two_factor_secret` by hand.
--
-- Reproduced **verbatim** from `TomUserTwoFactorEnrolment.createTableSql` — the
-- entity's annotations are the authority for the column names and this file is
-- the authority for the database, so the two are kept identical rather than
-- merely compatible — test/entity_table_ddl_test.dart fails if they part.
-- `secret_data` holds the RSA-OAEP ciphertext of the mechanism's secret; a
-- readable copy would be a complete 2FA bypass.
--
-- The legacy `auth_users.two_factor_*` columns ([004]) stay: the framework
-- consults this store first and falls back to them, so the seeded demo account
-- keeps working while newly-enrolled users are recorded here. That is the
-- documented migrate-one-user-at-a-time path, not a duplication.

CREATE TABLE IF NOT EXISTS tom_user_two_factor_enrolment (
  id BIGINT NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32) NOT NULL DEFAULT 'default',
  principal_id VARCHAR(255) NOT NULL,
  enrolment_id VARCHAR(255) NOT NULL,
  mechanism VARCHAR(64) NOT NULL,
  hint VARCHAR(255) NOT NULL DEFAULT '',
  enrolled_at DATETIME(6) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  secret_data TEXT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_two_factor_enrolment (tenant_id, principal_id, enrolment_id),
  KEY idx_tom_user_two_factor_enrolment_principal (principal_id)
);
