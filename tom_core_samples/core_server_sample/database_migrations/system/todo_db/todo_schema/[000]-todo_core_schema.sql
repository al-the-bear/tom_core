-- Core todo-management schema: users own projects, projects hold lists, lists
-- hold items. Column names match the @TomDbColumn mappings in
-- lib/src/persistence/todo_records.dart. Seed rows let the first `curl` return
-- non-empty without a write.

CREATE TABLE IF NOT EXISTS todo_users (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  display_name VARCHAR(255) NOT NULL,
  email       VARCHAR(255) NOT NULL,
  role        VARCHAR(64)  NOT NULL DEFAULT 'member',
  password_hash VARCHAR(255) NULL,
  hash_type   VARCHAR(64)  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_todo_users_email (email)
);

CREATE TABLE IF NOT EXISTS todo_projects (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(255) NOT NULL,
  description TEXT         NULL,
  owner_id    BIGINT       NOT NULL,
  PRIMARY KEY (id),
  KEY fk_todo_projects_owner (owner_id)
);

CREATE TABLE IF NOT EXISTS todo_lists (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(255) NOT NULL,
  project_id  BIGINT       NOT NULL,
  PRIMARY KEY (id),
  KEY fk_todo_lists_project (project_id)
);

CREATE TABLE IF NOT EXISTS todo_items (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  title       VARCHAR(255) NOT NULL,
  description TEXT         NULL,
  done        TINYINT(1)   NOT NULL DEFAULT 0,
  priority    VARCHAR(32)  NOT NULL DEFAULT 'medium',
  label       VARCHAR(32)  NOT NULL DEFAULT 'feature',
  assignee_id BIGINT       NULL,
  due_date    DATETIME     NULL,
  list_id     BIGINT       NOT NULL,
  PRIMARY KEY (id),
  KEY fk_todo_items_list (list_id)
);

-- Seed: one demo user, one project, one list, two items.
INSERT INTO todo_users (id, display_name, email, role)
VALUES (1, 'Demo Owner', 'owner@example.com', 'owner')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

INSERT INTO todo_projects (id, name, description, owner_id)
VALUES (1, 'Website relaunch', 'Ship the new marketing site', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO todo_lists (id, name, project_id)
VALUES (1, 'Sprint backlog', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO todo_items (id, title, description, done, priority, label, list_id)
VALUES
  (1, 'Write the launch article', 'Long-form post', 0, 'high', 'docs', 1),
  (2, 'Fix the nav contrast bug', 'A11y review finding', 0, 'critical', 'bug', 1)
ON DUPLICATE KEY UPDATE title = VALUES(title);
