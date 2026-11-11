-- The plan catalogue: a system table, the same for every tenant.
CREATE TABLE mt_plan (
  code          VARCHAR(32)  NOT NULL,
  name          VARCHAR(100) NOT NULL,
  monthly_cents INT          NOT NULL,
  PRIMARY KEY (code)
);

INSERT INTO mt_plan (code, name, monthly_cents) VALUES ('starter', 'Starter', 900);
INSERT INTO mt_plan (code, name, monthly_cents) VALUES ('business', 'Business', 4900);
