-- Baseline of the converged fixture chain for the CE-DB ↔ CE-MG check.
--
-- Creates only the two columns FixtureTaskRecord's baseline needs; the
-- remaining two arrive in [001], so the chain proves the check accumulates
-- across artifacts rather than reading one file. The secondary index is here to
-- be *ignored*: indexes are outside the comparison scope and must not surface
-- as an unsupported statement.
CREATE TABLE IF NOT EXISTS fixture_task (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  title VARCHAR(255) NULL,
  PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS fixture_task_title_idx ON fixture_task (title);
