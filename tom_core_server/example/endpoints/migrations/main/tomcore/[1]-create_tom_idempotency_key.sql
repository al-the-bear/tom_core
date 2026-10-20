-- Reference migration for the idempotency-key store (`TomSqlIdempotencyStore`).
--
-- Creates `tom_idempotency_key`: one row per Idempotency-Key a caller sent to a
-- `@TomIdempotent` endpoint, holding the first request's fingerprint and, once
-- it finished, its response. This file is the canonical DDL and is kept in sync
-- with `idempotencyTable()` in
-- `lib/src/tomserver/endpoints/idempotency_sql.dart`;
-- `test/framework_schema_test.dart` replays this chain and compares the schema
-- it builds against the descriptor, so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and configure the store with `createSchema: false`. Under tenancy with a
-- database or schema per tenant, apply it in each tenant's tree: the store
-- resolves its data source per request, so a tenant's keys live with its data.
--
-- Notes on the shape:
--
--  * the primary key `(tenant, principal, operation, idem_key)` makes a key the
--    caller's, for one named operation; `tenant` is '' outside tenancy.
--  * `request_hash` is the SHA-256 of the first request's method, path, query
--    and body — how a key reused for a different request is recognised.
--  * `status`, `headers` and `body` (base64) stay NULL until the response is
--    stored; `state` says which.
--  * `expires_at` carries the retention and the purge, so it is indexed.
CREATE TABLE IF NOT EXISTS tom_idempotency_key (
  tenant       VARCHAR(32)  NOT NULL,
  principal    VARCHAR(150) NOT NULL,
  operation    VARCHAR(191) NOT NULL,
  idem_key     VARCHAR(191) NOT NULL,
  request_hash VARCHAR(64)  NOT NULL,
  state        VARCHAR(16)  NOT NULL,
  status       INT          NULL,
  headers      TEXT         NULL,
  body         LONGTEXT     NULL,
  created_at   DATETIME(6)  NOT NULL,
  expires_at   DATETIME(6)  NOT NULL,
  PRIMARY KEY (tenant, principal, operation, idem_key),
  KEY ix_tom_idempotency_key_expiry (expires_at)
);
