-- Reference migration for the four-state authorization model.
--
-- Creates the `tom_resource_grant` table that stores a per-(role, resource-key)
-- TomAuthState grade (one of 'none' / 'disabled' / 'read' / 'full'). The
-- access_level column is constrained to the four enum tokens so the database
-- itself rejects an out-of-range grade. This file is the canonical DDL kept in
-- sync with TomResourceGrant.createTableSql; the db_migration module applies it
-- as version [1] of the `tomcore` schema on the `main` datasource.
CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (role_name, resource_key)
);
