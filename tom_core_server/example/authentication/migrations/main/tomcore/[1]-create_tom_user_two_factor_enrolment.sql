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
-- This file is the canonical DDL and reproduces
-- `TomUserTwoFactorEnrolment.createTableSql` verbatim;
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
