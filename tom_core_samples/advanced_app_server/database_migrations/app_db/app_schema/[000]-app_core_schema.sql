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
-- This migration is DDL only. The starter rows that make the app non-empty on
-- first run live in the separate sample-data migration [100]-app_sample_data.sql,
-- applied after this one.

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
