-- app_db application schema: the workspaces/projects/lists/items the app server
-- serves. Column names match the @TomDbColumn mappings in
-- lib/src/persistence/app_persistence_model.dart exactly, so the
-- records read/write these tables with no aliasing.
--
-- Cross-user *shares* are NOT an app_db table: they are framework
-- `share`-mode tom_principal_delegation rows in auth_db (see the auth server's
-- [001]-auth_authz_grants migration), resolved alongside the C-5 ownership
-- grants — so there is one framework enforcement path and no `app_shares` table.
--
-- The user-id columns (owner_id, assignee_id, reporter_id, author_id) are
-- logical references to auth_db.auth_users — a *different* database, so no FK
-- constraint is declared across the boundary; the values mirror the auth seed
-- (1=admin, 2=alice, 3=bob, 4=carol). Same-db parents (workspace_id, project_id,
-- list_id, item_id) are real foreign keys.
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
  -- @TomFileReference key columns. VARCHAR(512) is not arbitrary: it matches
  -- TomBlobStore.maxKeyLength exactly, so the column cannot silently truncate a
  -- key the validator accepted. NULL means "no file". See [002].
  attachment      VARCHAR(512) NULL,
  internal_note   VARCHAR(512) NULL,
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
