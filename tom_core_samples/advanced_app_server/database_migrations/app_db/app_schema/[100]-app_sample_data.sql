-- app_db sample data: the starter rows that make the app non-empty on first run.
-- Separated from the schema migration ([000]-app_core_schema.sql) so the DDL and
-- the demo content are distinct concerns — a deployment that wants an empty app
-- can apply the schema migration alone and skip this one.
--
-- All inserts use `ON DUPLICATE KEY UPDATE` so a re-applied migration is
-- idempotent. The user-id values mirror the auth seed (1=admin, 2=alice, 3=bob,
-- 4=carol) in auth_db — a logical, cross-database reference.
--
-- Seed: a starter workspace owned by alice (auth user 2), one project with two
-- lists and three items, a comment from bob, two subtasks, and two shares.

INSERT INTO app_workspaces (id, name, owner_id, created_at) VALUES
  (1, 'Acme Engineering', 2, '2026-01-02 09:00:00')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO app_projects (id, workspace_id, name, description, colour, archived) VALUES
  (1, 1, 'Website Relaunch', 'Q1 marketing-site rebuild', '#3366FF', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO app_lists (id, project_id, name, position) VALUES
  (1, 1, 'Backlog',     0),
  (2, 1, 'In Progress', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- status/priority/label carry the domain enum `.name` tokens (TodoStatus,
-- TodoPriority, TodoLabel). assignee_id/reporter_id reference auth users.
INSERT INTO app_items
  (id, list_id, title, description, status, priority, label,
   assignee_id, reporter_id, due_date, estimate_hours, tags, created_at, updated_at)
VALUES
  (1, 1, 'Draft the new landing page', 'Hero + CTA above the fold',
   'backlog',    'high',   'feature', 3, 2, '2026-03-01 00:00:00', 8.0,
   '["frontend","design"]', '2026-02-01 09:00:00', '2026-02-01 09:00:00'),
  (2, 1, 'Audit current analytics events', NULL,
   'todo',       'medium', 'chore',   4, 2, NULL,                   3.5,
   NULL,                    '2026-02-01 09:05:00', '2026-02-01 09:05:00'),
  (3, 2, 'Set up the staging environment', 'Mirror prod for QA',
   'inProgress', 'high',   'chore',   3, 2, '2026-02-20 00:00:00', 5.0,
   '["devops"]',            '2026-02-02 10:00:00', '2026-02-05 14:30:00')
ON DUPLICATE KEY UPDATE title = VALUES(title);

INSERT INTO app_comments (id, item_id, author_id, body, created_at) VALUES
  (1, 1, 3, 'Started on the hero section — wireframe attached.', '2026-02-03 11:15:00')
ON DUPLICATE KEY UPDATE body = VALUES(body);

INSERT INTO app_subtasks (id, item_id, title, done, position) VALUES
  (1, 1, 'Write the hero copy',     1, 0),
  (2, 1, 'Pick the hero imagery',   0, 1)
ON DUPLICATE KEY UPDATE title = VALUES(title);

-- Cross-user access: alice (granted_by 2) shares the project with bob (editor)
-- and carol (viewer). On first run, bob and carol already see project 1 through
-- these rows — the cross-user mechanism is visible with no API call.
INSERT INTO app_shares
  (id, resource_type, resource_id, grantee_user_id, project_role, granted_by_id, created_at)
VALUES
  (1, 'project', 1, 3, 'editor', 2, '2026-02-04 08:00:00'),
  (2, 'project', 1, 4, 'viewer', 2, '2026-02-04 08:05:00')
ON DUPLICATE KEY UPDATE project_role = VALUES(project_role);
