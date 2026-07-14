-- Four-state authorization grants. The table DDL is the canonical
-- `tom_resource_grant` shape published by tom_core_server's graded_authorization
-- library (TomResourceGrant.createTableSql) — reused verbatim so the sample and
-- the framework agree on the storage shape. access_level is constrained to the
-- four TomAuthState tokens, so the database itself rejects an out-of-range grade.
--
-- This migration is DDL only. The seed grant matrix (§A.4) is data owned by
-- auth_db and lives in the separate sample-data migration
-- [100]-auth_sample_data.sql, applied after this one.

CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (role_name, resource_key)
);

-- C-5 per-principal-per-resource role grants. The table DDL is the canonical
-- `tom_principal_resource_grant` shape published by tom_core_server
-- (TomPrincipalResourceGrant.createTableSql) — reused verbatim so the sample and
-- the framework agree on the storage shape. A row is `(principal_id, resource_key)
-- -> role`; the unique key enforces at most one direct role per principal per
-- resource. The entity carries the framework default `main` datasource, which the
-- auth boot (step 13) delegates to auth_db, so these grants live in the same
-- physical schema as the identity tables and are reachable from the app server
-- (which binds its own `main` to this schema). RCC1 seeds ownership grants here;
-- the login folds them into TomAccessControlInformation.resourceRoles.
CREATE TABLE IF NOT EXISTS tom_principal_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  role VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_principal_resource_grant (principal_id, resource_key)
);

-- C-6 per-principal delegation rows. The table DDL is the canonical
-- `tom_principal_delegation` shape published by tom_core_server
-- (TomPrincipalDelegation.createTableSql) — reused verbatim so the sample and
-- the framework agree on the storage shape. A `share`-mode row is a delegator
-- lending a named `role` on one `resource_key` to a delegate; the framework's
-- TomDelegationResolver folds these in alongside the C-5 direct grants above.
-- RCC3 moved the app server's cross-user shares here: the app share endpoints
-- write `share`-mode rows and resolve them back through the framework delegation
-- resolver, so the same `main`/auth_db schema is the sole resource-access path.
CREATE TABLE IF NOT EXISTS tom_principal_delegation (
  id BIGINT NOT NULL AUTO_INCREMENT,
  delegator_id VARCHAR(255) NOT NULL,
  delegate_id VARCHAR(255) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  resource_key VARCHAR(255) NULL,
  role VARCHAR(255) NULL,
  valid_from DATETIME NULL,
  valid_to DATETIME NULL,
  revoked TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_tom_principal_delegation_delegate (delegate_id)
);
