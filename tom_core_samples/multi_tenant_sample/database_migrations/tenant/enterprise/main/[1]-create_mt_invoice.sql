-- A tenant's invoices: a tenant table, its rows carrying their tenant.
CREATE TABLE mt_invoice (
  id           VARCHAR(64) NOT NULL,
  tenant_id    VARCHAR(32) NOT NULL,
  plan_code    VARCHAR(32) NOT NULL,
  amount_cents INT         NOT NULL,
  PRIMARY KEY (id)
);

CREATE INDEX ix_mt_invoice_tenant ON mt_invoice (tenant_id);
