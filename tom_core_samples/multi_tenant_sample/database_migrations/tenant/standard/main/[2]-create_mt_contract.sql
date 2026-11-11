-- A tenant's contracts: a tenant table, so every type's tree creates it
-- (the start refuses a type whose tree lacks a tenant table it routes).
CREATE TABLE mt_contract (
  id        VARCHAR(64)  NOT NULL,
  tenant_id VARCHAR(32)  NOT NULL,
  title     VARCHAR(200) NOT NULL,
  PRIMARY KEY (id)
);
