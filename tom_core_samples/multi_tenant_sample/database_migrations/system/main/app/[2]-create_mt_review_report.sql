-- What the contract review recorded per tenant: a system table written
-- from inside each tenant's run.
CREATE TABLE mt_review_report (
  id        VARCHAR(100) NOT NULL,
  tenant    VARCHAR(32)  NOT NULL,
  contracts INT          NOT NULL,
  PRIMARY KEY (id)
);
