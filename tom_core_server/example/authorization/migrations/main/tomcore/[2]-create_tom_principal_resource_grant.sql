-- Reference migration for per-principal-per-resource roles (C-5).
--
-- Creates the `tom_principal_resource_grant` table that stores which role a
-- principal holds on a resource: one `(principal_id, resource_key) -> role` row.
-- The unique key enforces at most one direct role per (principal, resource);
-- delegated roles (C-6) arrive as separate rows and are folded by strength at
-- resolution time. This file is the canonical DDL and reproduces
-- `TomPrincipalResourceGrant.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart. The
-- db_migration module applies it as version [2] of the `tomcore` schema on the
-- `main` datasource, after the four-state grant table [1].
CREATE TABLE IF NOT EXISTS tom_principal_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  role VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_principal_resource_grant (principal_id, resource_key)
);
