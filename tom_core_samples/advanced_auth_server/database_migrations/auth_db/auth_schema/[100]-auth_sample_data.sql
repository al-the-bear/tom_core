-- auth_db sample data: the seed principals and the §A.4 grant matrix that let the
-- admin API, a first login, and per-field grading all return non-empty without a
-- write. Separated from the schema migrations ([000] identity tables, [001] the
-- grant table) so DDL and demo content are distinct concerns; a deployment that
-- provisions its own users can apply the schema migrations alone and skip this.
--
-- This migration runs after both [000] and [001], so every table it seeds already
-- exists. All inserts use `ON DUPLICATE KEY UPDATE` so a re-applied migration is
-- idempotent.
--
-- password_hash is left NULL on the seed users: hashing is the step-9
-- kernel-crypto helper's job, applied at boot/seed time, never in raw SQL (the
-- auth server, not the migration, owns the hash format).

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
-- keys on. The projectRoles exist as rows so the authadmin client can
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

-- Seed grant matrix — §A.4 of advanced_example_specification_plan.md:
--
--   Field        owner  editor  commenter  viewer
--   title        full   full    read       read
--   status       full   full    full       read
--   priority     full   full    read       read
--   assigneeId   full   full    read       none
--   dueDate      full   full    read       read
--   estimate     full   read    none       none
--   description  full   full    read       read
INSERT INTO tom_resource_grant (role_name, resource_key, access_level) VALUES
  ('owner',     'todo.item.title',       'full'),
  ('owner',     'todo.item.status',      'full'),
  ('owner',     'todo.item.priority',    'full'),
  ('owner',     'todo.item.assigneeId',  'full'),
  ('owner',     'todo.item.dueDate',     'full'),
  ('owner',     'todo.item.estimate',    'full'),
  ('owner',     'todo.item.description', 'full'),

  ('editor',    'todo.item.title',       'full'),
  ('editor',    'todo.item.status',      'full'),
  ('editor',    'todo.item.priority',    'full'),
  ('editor',    'todo.item.assigneeId',  'full'),
  ('editor',    'todo.item.dueDate',     'full'),
  ('editor',    'todo.item.estimate',    'read'),
  ('editor',    'todo.item.description', 'full'),

  ('commenter', 'todo.item.title',       'read'),
  ('commenter', 'todo.item.status',      'full'),
  ('commenter', 'todo.item.priority',    'read'),
  ('commenter', 'todo.item.assigneeId',  'read'),
  ('commenter', 'todo.item.dueDate',     'read'),
  ('commenter', 'todo.item.estimate',    'none'),
  ('commenter', 'todo.item.description', 'read'),

  ('viewer',    'todo.item.title',       'read'),
  ('viewer',    'todo.item.status',      'read'),
  ('viewer',    'todo.item.priority',    'read'),
  ('viewer',    'todo.item.assigneeId',  'none'),
  ('viewer',    'todo.item.dueDate',     'read'),
  ('viewer',    'todo.item.estimate',    'none'),
  ('viewer',    'todo.item.description', 'read')
ON DUPLICATE KEY UPDATE access_level = VALUES(access_level);
