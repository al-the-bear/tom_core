-- Deliberately divergent baseline: the failure case the check exists to catch.
--
-- Two defects against FixtureTaskRecord, both of the kind that a hand-written
-- migration chain drifts into and that nothing else in the stack would notice:
--
--   * `priority` is created as VARCHAR(32) although the entity maps it to an
--     `int` — a type-family divergence;
--   * `done` is never created at all, here or in any later artifact — a missing
--     column.
--
-- `[001]` then adds a table no entity maps to, which is a *warning* rather than
-- an error, since audit and join tables legitimately have no entity.
CREATE TABLE IF NOT EXISTS fixture_task (
  id       BIGINT       NOT NULL AUTO_INCREMENT,
  title    VARCHAR(255) NULL,
  priority VARCHAR(32)  NULL,
  PRIMARY KEY (id)
);
