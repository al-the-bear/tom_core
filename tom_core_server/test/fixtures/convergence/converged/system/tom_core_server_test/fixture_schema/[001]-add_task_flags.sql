-- Adds the two columns [000] leaves out, in the multi-action, guarded form real
-- migrations use.
--
-- `ADD COLUMN IF NOT EXISTS` is the shape that lets an artifact catch up a
-- database created before the column existed while staying a no-op on a fresh
-- one — the replay has to model the guard or it would report a false collision.
-- `done` is spelled TINYINT(1), which only the MariaDB dialect classifies as a
-- truth value; under the standard dialect it would read as an integer.
ALTER TABLE fixture_task
  ADD COLUMN IF NOT EXISTS priority INT         NULL,
  ADD COLUMN IF NOT EXISTS done     TINYINT(1)  NOT NULL DEFAULT 0;
