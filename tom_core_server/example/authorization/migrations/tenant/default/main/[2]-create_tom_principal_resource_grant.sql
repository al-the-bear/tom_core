-- Reference migration for per-principal-per-resource roles (C-5).
--
-- Creates the `tom_principal_resource_grant` table that stores which role a
-- principal holds on a resource: one `(principal_id, resource_key) -> role` row.
-- The unique key enforces at most one direct role per (principal, resource);
-- delegated roles (C-6) arrive as separate rows and are folded by strength at
-- resolution time. This file is the canonical DDL and reproduces
-- `TomPrincipalResourceGrant.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. The
-- db_migration module applies it as version [2] of the tenant tree on every
-- tenant's `main` data source, after the four-state grant table [1].
-- `tenant_id` is the row's tenant: the entity is a tenant table
-- (`@TomTenantTable`), and the repository binds `tenant_id = <tenant>` into
-- every statement, in every isolation model. It defaults to `default`, the
-- implicit tenant of a deployment without tenancy, and leads the unique key,
-- so tenants sharing the table may each hold the same key.
CREATE TABLE IF NOT EXISTS tom_principal_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32) NOT NULL DEFAULT 'default',
  principal_id VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  role VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_principal_resource_grant (tenant_id, principal_id, resource_key)
);
