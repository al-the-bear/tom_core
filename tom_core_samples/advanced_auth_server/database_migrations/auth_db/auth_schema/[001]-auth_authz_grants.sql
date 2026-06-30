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
