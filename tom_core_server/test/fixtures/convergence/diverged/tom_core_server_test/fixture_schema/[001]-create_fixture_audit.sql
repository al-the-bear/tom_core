-- A table the entity model does not map, so the check reports it as a warning
-- and still converges on it.
CREATE TABLE IF NOT EXISTS fixture_audit (
  id   BIGINT NOT NULL AUTO_INCREMENT,
  note TEXT   NULL,
  PRIMARY KEY (id)
);
