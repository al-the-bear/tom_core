-- Reference migration for enrolled second factors (C-10).
--
-- Creates the `tom_user_two_factor_enrolment` table that stores which second
-- factors a principal has actually set up: one row per `(principal_id,
-- enrolment_id)` pair, carrying the mechanism key, a displayable hint, when it
-- was enrolled, whether it is the user's default, and the mechanism's own
-- secret. The unique key is what makes re-enrolling a mechanism an upsert rather
-- than a second, ambiguous row.
--
-- `secret_data` holds ciphertext, never a readable secret: TomPersistent2FA-
-- EnrolmentStore encrypts the mechanism's secret map (RSA-OAEP over its JSON,
-- base64-wrapped) before it reaches this column, because a TOTP shared secret
-- read out of a backup is a complete 2FA bypass.
--
-- This file is the canonical DDL kept in sync with
-- TomUserTwoFactorEnrolment.createTableSql; the db_migration module applies it
-- as version [1] of the `tomcore` schema on the `main` datasource. It carries no
-- `@environment` suffix on purpose: a schema migration is never
-- environment-tagged (G-MIG-1, G-MIG-2, C-16), because a table that exists only
-- in some environments makes the code above it conditional on the deployment.
CREATE TABLE IF NOT EXISTS tom_user_two_factor_enrolment (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  enrolment_id VARCHAR(255) NOT NULL,
  mechanism VARCHAR(64) NOT NULL,
  hint VARCHAR(255) NOT NULL DEFAULT '',
  enrolled_at DATETIME NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  secret_data TEXT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_two_factor_enrolment (principal_id, enrolment_id),
  KEY idx_tom_user_two_factor_enrolment_principal (principal_id)
);
