-- An environment-tagged seed (C-16), present so the check is seen to apply the
-- engine's own environment filter.
--
-- Under the production-safe default environment this artifact is not part of
-- the chain at all; under `dev` it is, and its INSERT is then skipped as data
-- rather than reported as unreadable DDL. Either way it cannot change the
-- schema the check compares.
INSERT INTO fixture_task (title, priority, done) VALUES ('demo task', 1, 0);
