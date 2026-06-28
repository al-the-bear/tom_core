-- app_db application schema: the workspaces/projects/lists/items the app server
-- serves, plus the `app_shares` rows that grant cross-user access. Column names
-- match the @TomDbColumn mappings in lib/src/persistence/app_persistence_model.dart
-- (step 14) exactly, so the records read/write these tables with no aliasing.
--
-- The user-id columns (owner_id, assignee_id, reporter_id, author_id,
-- grantee_user_id, granted_by_id) are logical references to auth_db.auth_users —
-- a *different* database, so no FK constraint is declared across the boundary;
-- the values mirror the auth seed (1=admin, 2=alice, 3=bob, 4=carol). Same-db
-- parents (workspace_id, project_id, list_id, item_id) are real foreign keys.
--
-- Seed rows make the app non-empty on first run: one workspace owned by alice,
-- a project with two lists and three items, a comment, two subtasks, and two
-- `app_shares` — alice shares the project with bob (editor) and carol (viewer),
-- so cross-user access is visible without a single write. All inserts use
-- `ON DUPLICATE KEY UPDATE` so a re-applied migration is idempotent.

CREATE TABLE IF NOT EXISTS app_workspaces (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(255) NOT NULL,
  owner_id    BIGINT       NULL,
  created_at  DATETIME     NULL,
  PRIMARY KEY (id),
  KEY ix_app_workspaces_owner (owner_id)
);

CREATE TABLE IF NOT EXISTS app_projects (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  workspace_id  BIGINT       NULL,
  name          VARCHAR(255) NOT NULL,
  description   TEXT         NULL,
  colour        VARCHAR(32)  NULL,
  archived      TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY fk_app_projects_workspace (workspace_id),
  CONSTRAINT fk_app_projects_workspace
    FOREIGN KEY (workspace_id) REFERENCES app_workspaces (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app_lists (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  project_id  BIGINT       NULL,
  name        VARCHAR(255) NOT NULL,
  position    INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY fk_app_lists_project (project_id),
  CONSTRAINT fk_app_lists_project
    FOREIGN KEY (project_id) REFERENCES app_projects (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app_items (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  list_id         BIGINT       NULL,
  title           VARCHAR(512) NOT NULL,
  description     TEXT         NULL,
  status          VARCHAR(32)  NULL,
  priority        VARCHAR(32)  NULL,
  label           VARCHAR(32)  NULL,
  assignee_id     BIGINT       NULL,
  reporter_id     BIGINT       NULL,
  due_date        DATETIME     NULL,
  estimate_hours  DOUBLE       NULL,
  tags            TEXT         NULL,
  created_at      DATETIME     NULL,
  updated_at      DATETIME     NULL,
  PRIMARY KEY (id),
  KEY fk_app_items_list (list_id),
  KEY ix_app_items_assignee (assignee_id),
  CONSTRAINT fk_app_items_list
    FOREIGN KEY (list_id) REFERENCES app_lists (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app_comments (
  id          BIGINT   NOT NULL AUTO_INCREMENT,
  item_id     BIGINT   NULL,
  author_id   BIGINT   NULL,
  body        TEXT     NOT NULL,
  created_at  DATETIME NULL,
  PRIMARY KEY (id),
  KEY fk_app_comments_item (item_id),
  CONSTRAINT fk_app_comments_item
    FOREIGN KEY (item_id) REFERENCES app_items (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app_subtasks (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  item_id   BIGINT       NULL,
  title     VARCHAR(512) NOT NULL,
  done      TINYINT(1)   NOT NULL DEFAULT 0,
  position  INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY fk_app_subtasks_item (item_id),
  CONSTRAINT fk_app_subtasks_item
    FOREIGN KEY (item_id) REFERENCES app_items (id) ON DELETE CASCADE
);

-- app_shares: the cross-user access grant. `resource_type` names which table the
-- polymorphic `resource_id` keys into ('project'/'list'/'item'); `project_role`
-- is one of owner/editor/commenter/viewer. No FK on resource_id (it is
-- polymorphic) nor on the auth-user columns (cross-database).
CREATE TABLE IF NOT EXISTS app_shares (
  id               BIGINT      NOT NULL AUTO_INCREMENT,
  resource_type    VARCHAR(32) NOT NULL,
  resource_id      BIGINT      NULL,
  grantee_user_id  BIGINT      NULL,
  project_role     VARCHAR(32) NULL,
  granted_by_id    BIGINT      NULL,
  created_at       DATETIME    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_app_shares (resource_type, resource_id, grantee_user_id),
  KEY ix_app_shares_grantee (grantee_user_id)
);

-- ---------------------------------------------------------------------------
-- Seed: a starter workspace owned by alice (auth user 2), one project with two
-- lists and three items, a comment from bob, two subtasks, and two shares.
-- ---------------------------------------------------------------------------

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
