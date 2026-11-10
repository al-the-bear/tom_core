-- Reference migration for the four-state authorization model.
--
-- Creates the `tom_resource_grant` table that stores a per-(role, resource-key)
-- TomAuthState grade (one of 'none' / 'disabled' / 'read' / 'full'). The
-- access_level column is constrained to the four enum tokens so the database
-- itself rejects an out-of-range grade. This file is the canonical DDL and
-- reproduces `TomResourceGrant.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. The
-- db_migration module applies it as version [1] of the `tomcore` schema on the
-- `main` datasource.
-- `tenant_id` is the row's tenant: the entity is a tenant table
-- (`@TomTenantTable`), and the repository binds `tenant_id = <tenant>` into
-- every statement, in every isolation model. It defaults to `default`, the
-- implicit tenant of a deployment without tenancy, and leads the unique key,
-- so tenants sharing the table may each hold the same key.
CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32) NOT NULL DEFAULT 'default',
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (tenant_id, role_name, resource_key)
);
