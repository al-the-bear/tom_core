-- auth_db demo seed: the sample principals, project roles, demo group and the
-- §A.4 grant matrix that let a first login, the admin lists, and per-field
-- grading all return non-empty out of the box. This is **demo** content — the
-- filename carries the `@dev,test` environment tag (G-MIG-2/3, step 12), so a
-- production apply (any environment other than `dev`/`test`) **skips** it and is
-- seeded only with the admin account from [002]-auth_admin_seed.
--
-- Runs after [000] (identity tables), [001] (grant table) and [002] (admin
-- account); it references no [002] row, so the two seeds are independent. Every
-- insert uses `ON DUPLICATE KEY UPDATE`, so a re-applied migration is idempotent.
--
-- password_hash is left NULL on the demo users: hashing is the auth server's
-- boot-time job (seedDemoPasswords), never raw SQL.

-- Demo end-users. They carry no global role row — their per-project access is
-- granted at runtime through Share records in the app server, not here.
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (2, 'alice', 'Alice Lovelace', 'alice@example.com', 'active'),
  (3, 'bob',   'Bob Turing',     'bob@example.com',   'active'),
  (4, 'carol', 'Carol Hopper',   'carol@example.com', 'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- The four projectRoles the grant matrix keys on. They exist as rows so the
-- authadmin client can list/manage them; they are *assigned* per-resource via
-- Share, not globally. (The global `admin` role lives in [002].)
INSERT INTO auth_roles (id, role_key, name) VALUES
  (2, 'owner',     'Owner'),
  (3, 'editor',    'Editor'),
  (4, 'commenter', 'Commenter'),
  (5, 'viewer',    'Viewer')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- One demo group with two members, so the group admin API returns a non-empty
-- list out of the box.
INSERT INTO auth_groups (id, name) VALUES
  (1, 'Engineering')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO auth_group_members (id, group_id, user_id) VALUES
  (1, 1, 2),
  (2, 1, 3)
ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);

-- Seed grant matrix (see ../../../../README_advanced_07_authorization.md):
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
