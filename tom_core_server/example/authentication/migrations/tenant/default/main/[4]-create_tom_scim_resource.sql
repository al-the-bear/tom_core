-- Reference migration for the relational SCIM store (`TomSqlScimStore`).
--
-- Creates the `tom_scim_resource` table: one row per user or group an identity
-- provider has provisioned over SCIM 2.0. This file is the canonical DDL and is
-- kept in sync with `scimResourceTableDdl()` in
-- `lib/src/tomserver/authentication/scim_sql.dart`;
-- `test/framework_schema_test.dart` fails if the two drift apart.
--
-- Apply this only where SCIM provisioning uses the SQL store. Several columns
-- are not obvious:
--
--  * `id` is an auto-increment key and is the resource's SCIM `id`, in decimal.
--    It is never reused, which is what SCIM requires of an id.
--  * `name_key` is the name attribute — a user's `userName`, a group's
--    `displayName` — lower-cased, and unique within a `resource_type`. SCIM
--    compares both case-insensitively, so the key holds the form the
--    comparison uses, and the database refuses a second resource of one name.
--  * `external_id` is indexed for the identity provider's reconciliation and
--    is nullable: a resource created without one has none.
--  * `document` is the resource's JSON without `id` and `meta`, so every
--    attribute the identity provider maps survives whatever its schema.
--
-- `tenant` is the tenant a resource belongs to, `''` for none. Every
-- statement names the tenant in context, so under `shared` isolation two
-- tenants' resources stay apart in this one table, and a name is unique per
-- tenant.
--
-- Instants are `DATETIME(6)` and are always written in UTC.
CREATE TABLE IF NOT EXISTS tom_scim_resource (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  resource_type VARCHAR(16)  NOT NULL,
  name_key      VARCHAR(191) NOT NULL,
  external_id   VARCHAR(191) NULL,
  document      LONGTEXT     NOT NULL,
  created_at    DATETIME(6)  NOT NULL,
  last_modified DATETIME(6)  NOT NULL,
  version       BIGINT       NOT NULL,
  tenant        VARCHAR(32)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_scim_resource_name (tenant, resource_type, name_key),
  KEY ix_tom_scim_resource_external (tenant, resource_type, external_id)
);
