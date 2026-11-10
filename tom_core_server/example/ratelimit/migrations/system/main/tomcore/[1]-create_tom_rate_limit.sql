-- Reference migration for the SQL rate limiter.
--
-- Creates `tom_rate_limit`: one counter row per bucket and window. A system
-- table: the counters are the deployment's, shared by every node, and a bucket
-- names its tenant where a rule counts per tenant.
--
-- The canonical DDL of `rateLimitTable` (ratelimit/sql_rate_limiter.dart);
-- `test/framework_schema_test.dart` fails if the two drift apart. A deployment
-- whose database user may not run DDL applies it and builds `TomSqlRateLimiter`
-- with `createSchema: false`.
CREATE TABLE IF NOT EXISTS tom_rate_limit (
  bucket       VARCHAR(191) NOT NULL,
  rule         VARCHAR(64)  NOT NULL,
  window_index BIGINT       NOT NULL,
  hits         INT          NOT NULL,
  PRIMARY KEY (bucket, window_index),
  KEY ix_tom_rate_limit_rule_window (rule, window_index)
);
