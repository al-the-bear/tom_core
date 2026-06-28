-- Four-state authorization grants. The table DDL is the canonical
-- `tom_resource_grant` shape published by tom_core_server's graded_authorization
-- library (TomResourceGrant.createTableSql) — reused verbatim so the sample and
-- the framework agree on the storage shape. access_level is constrained to the
-- four TomAuthState tokens, so the database itself rejects an out-of-range grade.

CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (role_name, resource_key)
);

-- Seed grants demonstrating all four states on the todo-item fields:
--   owner  — full edit on every field
--   member — edits content, cannot reassign (assignee read-only), cannot see
--            the internal priority (hidden)
--   viewer — reads the visible fields, edits nothing; `done` is rendered but
--            disabled (cannot toggle)
INSERT INTO tom_resource_grant (role_name, resource_key, access_level) VALUES
  ('owner',  'todo.item.title',      'full'),
  ('owner',  'todo.item.done',       'full'),
  ('owner',  'todo.item.priority',   'full'),
  ('owner',  'todo.item.assigneeId', 'full'),
  ('member', 'todo.item.title',      'full'),
  ('member', 'todo.item.done',       'full'),
  ('member', 'todo.item.priority',   'none'),
  ('member', 'todo.item.assigneeId', 'read'),
  ('viewer', 'todo.item.title',      'read'),
  ('viewer', 'todo.item.done',       'disabled'),
  ('viewer', 'todo.item.priority',   'read'),
  ('viewer', 'todo.item.assigneeId', 'read')
ON DUPLICATE KEY UPDATE access_level = VALUES(access_level);
