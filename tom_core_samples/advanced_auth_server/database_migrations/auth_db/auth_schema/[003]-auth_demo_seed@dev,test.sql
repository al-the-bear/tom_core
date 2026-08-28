-- auth_db demo seed: the sample principals, project roles, demo group and the
-- tom_resource_grant matrix that let a first login, the admin lists, and
-- per-field grading all return non-empty out of the box. This is **demo**
-- content — the filename carries the `@dev,test` environment tag (G-MIG-2/3), so a
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
-- granted through tom_principal_resource_grant ownership rows and
-- tom_principal_delegation `share`-mode rows in this schema (see below),
-- resolved by the framework, not by app-server tables.
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (2, 'alice', 'Alice Lovelace', 'alice@example.com', 'active'),
  (3, 'bob',   'Bob Turing',     'bob@example.com',   'active'),
  (4, 'carol', 'Carol Hopper',   'carol@example.com', 'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- The four projectRoles the grant matrix keys on. They exist as rows so the
-- authadmin client can list/manage them; they are *assigned* per-resource via
-- ownership grants and `share`-mode delegations, not globally. (The global
-- `admin` role lives in [002].)
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
--   status       full   full    read       disabled
--   priority     full   full    none       read
--   assigneeId   full   read    read       read
--   dueDate      full   full    read       read
--   estimate     full   read    none       none
--   description  full   full    read       read
--
--   Column       owner  editor  commenter  viewer
--   attachment   full   full    read       read
--
-- These are the *initial* values of a table an administrator may edit at
-- runtime; what is seeded here is the **server-side twin** of the shared domain
-- map `projectRoleFieldGrades` / `projectRoleAttachmentGrades` in
-- advanced_todo_domain, which the app client uses to shape its item form. The
-- two are independent artifacts — the client's copy is cooperation, this table
-- is enforcement — but they must *start* identical, or a first run tells two
-- different stories about the same role. `test/grant_matrix_key_consistency_test.dart`
-- parses this file and asserts every cell against the domain map, so a change
-- made on one side alone fails there rather than silently at runtime.
--
-- `viewer`/`status` is the matrix's only `disabled` cell, and it is what makes
-- all four TomAuthState values reachable from the seed. Note that `disabled` is
-- *masked* (`showsContent` is false), so the write path preserves a changed
-- value silently instead of rejecting it the way a visible `read` field does —
-- see TomColumnAuthorization.decideWrites.
--
-- The last row is the item's **file column**, not a form field: no client ever
-- sends `attachment` in an item payload (the blob key is minted server-side by
-- `saveFile`), so it is graded on the file endpoint instead. The app server
-- registers a per-row resolver for it at boot (`registerAppColumnGrades`), which
-- folds the caller's role on *that item's* project and then reads its grade from
-- this very table — so `full` downloads and replaces, `read` downloads and is
-- refused the upload. Editing this row through the authadmin console therefore
-- changes what a role may do with a file, using the same screen and API that
-- govern the fields above it.
INSERT INTO tom_resource_grant (role_name, resource_key, access_level) VALUES
  ('owner',     'todo.item.title',       'full'),
  ('owner',     'todo.item.status',      'full'),
  ('owner',     'todo.item.priority',    'full'),
  ('owner',     'todo.item.assigneeId',  'full'),
  ('owner',     'todo.item.dueDate',     'full'),
  ('owner',     'todo.item.estimate',    'full'),
  ('owner',     'todo.item.description', 'full'),
  ('owner',     'todo.item.attachment',  'full'),

  ('editor',    'todo.item.title',       'full'),
  ('editor',    'todo.item.status',      'full'),
  ('editor',    'todo.item.priority',    'full'),
  ('editor',    'todo.item.assigneeId',  'read'),
  ('editor',    'todo.item.dueDate',     'full'),
  ('editor',    'todo.item.estimate',    'read'),
  ('editor',    'todo.item.description', 'full'),
  ('editor',    'todo.item.attachment',  'full'),

  ('commenter', 'todo.item.title',       'read'),
  ('commenter', 'todo.item.status',      'read'),
  ('commenter', 'todo.item.priority',    'none'),
  ('commenter', 'todo.item.assigneeId',  'read'),
  ('commenter', 'todo.item.dueDate',     'read'),
  ('commenter', 'todo.item.estimate',    'none'),
  ('commenter', 'todo.item.description', 'read'),
  ('commenter', 'todo.item.attachment',  'read'),

  ('viewer',    'todo.item.title',       'read'),
  ('viewer',    'todo.item.status',      'disabled'),
  ('viewer',    'todo.item.priority',    'read'),
  ('viewer',    'todo.item.assigneeId',  'read'),
  ('viewer',    'todo.item.dueDate',     'read'),
  ('viewer',    'todo.item.estimate',    'none'),
  ('viewer',    'todo.item.description', 'read'),
  ('viewer',    'todo.item.attachment',  'read')
ON DUPLICATE KEY UPDATE access_level = VALUES(access_level);

-- Ownership grants. Ownership is a per-principal-per-resource role grant that
-- the login folds into TomAccessControlInformation.resourceRoles, rather than an
-- implicit `workspace.owner_id` chain read by a bespoke resolver — one
-- framework-enforced representation instead of a second, hand-written one.
-- Alice (auth user 2) owns the whole demo tree: her starter workspace,
-- its project, both lists and all three items. The write paths (createProject/
-- createItem) stamp the same `owner` grant for whoever creates a resource, so
-- first-run demo ownership and runtime-created ownership share one representation.
-- resource_key is `<type>:<id>` (see ResourceRoleKeys in advanced_todo_domain).
-- Shares (bob editor / carol viewer) are `share`-mode tom_principal_delegation
-- rows, seeded below; this block seeds owner grants only.
INSERT INTO tom_principal_resource_grant (principal_id, resource_key, role) VALUES
  ('2', 'workspace:1', 'owner'),
  ('2', 'project:1',   'owner'),
  ('2', 'list:1',      'owner'),
  ('2', 'list:2',      'owner'),
  ('2', 'item:1',      'owner'),
  ('2', 'item:2',      'owner'),
  ('2', 'item:3',      'owner')
ON DUPLICATE KEY UPDATE role = VALUES(role);

-- Cross-user shares. Alice (delegator 2) shares project 1 with bob
-- (editor) and carol (viewer) as `share`-mode tom_principal_delegation rows.
-- The framework's TomDelegationResolver folds these in alongside each delegate's
-- direct grants, so on first run bob and carol already see project 1 through the
-- one framework enforcement path — no app_shares table, no bespoke resolver.
-- The app share endpoints write the identical shape at runtime. resource_key is
-- `<type>:<id>` (see ResourceRoleKeys in advanced_todo_domain); role carries the
-- ProjectRole `.name`. valid_from/valid_to are unbounded and revoked is 0, so the
-- shares are active at every timestamp.
INSERT INTO tom_principal_delegation
  (id, delegator_id, delegate_id, mode, resource_key, role, revoked)
VALUES
  (1, '2', '3', 'share', 'project:1', 'editor', 0),
  (2, '2', '4', 'share', 'project:1', 'viewer', 0)
ON DUPLICATE KEY UPDATE role = VALUES(role);
