-- Four-state authorization grants. The table DDL is the canonical
-- `tom_resource_grant` shape published by tom_core_server's graded_authorization
-- library (TomResourceGrant.createTableSql) — reused verbatim so the sample and
-- the framework agree on the storage shape. access_level is constrained to the
-- four TomAuthState tokens, so the database itself rejects an out-of-range grade.
--
-- The grant matrix is *data* owned by auth_db and managed through the authadmin
-- client. The seed below is the §A.4 matrix transcribed exactly: rows keyed by
-- (projectRole, todo.item.<field>) that the app server folds per request via
-- TomGradedAccessControlInformation.fromGrants to resolve each field's state.

CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (role_name, resource_key)
);

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
