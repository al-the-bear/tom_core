-- Reference migration for role delegation (C-6).
--
-- Creates the `tom_principal_delegation` table that stores a delegator lending
-- roles to a delegate in one of three modes ('share' / 'absence' /
-- 'intentional'). For `share`, resource_key + role name the single shared
-- resource and role; for `absence` / `intentional` they optionally narrow /
-- override the delegator's inherited roles. The `[valid_from, valid_to]` window
-- and the `revoked` kill-switch bound every mode. The delegate index backs the
-- resolver's "delegations live for this delegate" lookup and covers `revoked`
-- as well, because revocation is a flag rather than a delete: a delegate's dead
-- rows accumulate for life, and the index is what keeps them off the read. This file is the
-- canonical DDL and reproduces `TomPrincipalDelegation.createTableSql`
-- verbatim; `test/reference_migrations_test.dart` fails if the two drift apart.
-- The db_migration module applies it as version [3] of the `tomcore` schema on
-- the `main` datasource, after the per-principal grant table [2].
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
  KEY idx_tom_principal_delegation_delegate (delegate_id, revoked)
);
