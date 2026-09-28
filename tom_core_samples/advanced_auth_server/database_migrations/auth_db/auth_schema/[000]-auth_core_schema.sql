-- auth_db identity schema: the principals the auth server authenticates and the
-- admin API manages. Column names match the @TomDbColumn mappings in
-- lib/src/persistence/auth_persistence_model.dart.
--
-- This migration is DDL only. The seed principals live in separate migrations,
-- applied after this one and after the grant table is created in [001]: the
-- untagged [002]-auth_admin_seed.sql, which every environment including
-- production applies, plus [003]-auth_demo_seed@dev,test.sql and
-- [005]-auth_two_factor_seed@dev,test.sql, whose tag makes a production apply
-- skip them.

CREATE TABLE IF NOT EXISTS auth_users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  username      VARCHAR(255) NOT NULL,
  display_name  VARCHAR(255) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  avatar_ref    VARCHAR(512) NULL,
  status        VARCHAR(32)  NOT NULL DEFAULT 'active',
  password_hash VARCHAR(512) NULL,
  hash_type     VARCHAR(128) NULL,
  -- Second-factor enrolment. NULL on both = password-only login, which is why
  -- enabling 2FA for an account is a data change and not a code change.
  -- two_factor_secret is server-only: it is never projected onto the principal
  -- and so never reaches a token claim.
  two_factor_type   VARCHAR(64)  NULL,
  two_factor_secret VARCHAR(255) NULL,
  -- Stored language preference, mirroring TomPrincipal.language / .country.
  -- NULL language = no preference; the reader falls back to the default.
  language      VARCHAR(16)  NULL,
  country       VARCHAR(8)   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_users_username (username),
  UNIQUE KEY uq_auth_users_email (email)
);

CREATE TABLE IF NOT EXISTS auth_roles (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  role_key  VARCHAR(64)  NOT NULL,
  name      VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_roles_role_key (role_key)
);

CREATE TABLE IF NOT EXISTS auth_groups (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  name  VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_groups_name (name)
);

CREATE TABLE IF NOT EXISTS auth_group_members (
  id        BIGINT NOT NULL AUTO_INCREMENT,
  group_id  BIGINT NOT NULL,
  user_id   BIGINT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_group_members (group_id, user_id),
  KEY fk_auth_group_members_group (group_id),
  KEY fk_auth_group_members_user (user_id)
);

CREATE TABLE IF NOT EXISTS auth_user_roles (
  id       BIGINT NOT NULL AUTO_INCREMENT,
  user_id  BIGINT NOT NULL,
  role_id  BIGINT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_user_roles (user_id, role_id),
  KEY fk_auth_user_roles_user (user_id),
  KEY fk_auth_user_roles_role (role_id)
);
