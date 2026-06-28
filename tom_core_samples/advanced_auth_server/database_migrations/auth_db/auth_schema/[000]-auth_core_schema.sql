-- auth_db identity schema: the principals the auth server authenticates and the
-- admin API manages. Column names match the @TomDbColumn mappings in
-- lib/src/persistence/auth_persistence_model.dart (step 7). Seed rows let the
-- admin API and a first login return non-empty without a write.
--
-- password_hash is left NULL on the seed rows: hashing is the step-9 kernel-crypto
-- helper's job, applied at boot/seed time, never in raw SQL (the auth server, not
-- the migration, owns the hash format).

CREATE TABLE IF NOT EXISTS auth_users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  username      VARCHAR(255) NOT NULL,
  display_name  VARCHAR(255) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  avatar_ref    VARCHAR(512) NULL,
  status        VARCHAR(32)  NOT NULL DEFAULT 'active',
  password_hash VARCHAR(512) NULL,
  hash_type     VARCHAR(128) NULL,
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

-- Seed: one admin + three end-users. The admin gets the global `admin` role for
-- the /admin/* gating; the end-users carry no global role row — their per-project
-- access is granted at runtime through Share records in the app server, not here.
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (1, 'admin', 'System Administrator', 'admin@example.com',  'active'),
  (2, 'alice', 'Alice Lovelace',       'alice@example.com',  'active'),
  (3, 'bob',   'Bob Turing',           'bob@example.com',    'active'),
  (4, 'carol', 'Carol Hopper',         'carol@example.com',  'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- Roles: the global `admin` axis plus the four projectRoles the grant matrix
-- ([001]) keys on. The projectRoles exist as rows so the authadmin client can
-- list/manage them; they are *assigned* per-resource via Share, not globally.
INSERT INTO auth_roles (id, role_key, name) VALUES
  (1, 'admin',     'Administrator'),
  (2, 'owner',     'Owner'),
  (3, 'editor',    'Editor'),
  (4, 'commenter', 'Commenter'),
  (5, 'viewer',    'Viewer')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Only the admin user holds a global role assignment (the admin axis).
INSERT INTO auth_user_roles (id, user_id, role_id) VALUES
  (1, 1, 1)
ON DUPLICATE KEY UPDATE role_id = VALUES(role_id);

-- One demo group with two members, so the group admin API returns a non-empty
-- list out of the box.
INSERT INTO auth_groups (id, name) VALUES
  (1, 'Engineering')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO auth_group_members (id, group_id, user_id) VALUES
  (1, 1, 2),
  (2, 1, 3)
ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);
