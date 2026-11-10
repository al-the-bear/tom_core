-- Reference migration for the cache-invalidation log
-- (`TomSqlInvalidationChannel`).
--
-- Creates `tom_cache_invalidation`: one row per invalidation or principal
-- revocation a node raised, which every other node reads by polling. This file
-- is the canonical DDL and is kept in sync with `invalidationTable()` in
-- `lib/src/tomserver/cache/invalidation_sql.dart`;
-- `test/framework_schema_test.dart` replays this chain and compares the schema
-- it builds against the descriptor, so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and construct the channel with `createSchema: false`. A channel over a
-- renamed table ships no migration of its own: call
-- `invalidationTableDdl(name)` with the name you passed the constructor and
-- apply what it returns.
--
-- Notes on the shape:
--
--  * `id` is what every node reads by: each remembers the highest id it has
--    seen and asks for the rows above it. An instant could not do that job —
--    two nodes' clocks disagree, and two rows written in one microsecond tie.
--  * `raised_at` carries the retention sweep and the start-up catch-up of the
--    revocations still in force, so it is indexed.
--  * `entry_key` is NULL except for a single-entry invalidation.
--  * instants are DATETIME(6) and are always written in UTC, at the precision
--    the framework binds them with.

CREATE TABLE IF NOT EXISTS tom_cache_invalidation (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  kind      VARCHAR(16)  NOT NULL,
  target    VARCHAR(191) NOT NULL,
  entry_key VARCHAR(512) NULL,
  origin    VARCHAR(32)  NOT NULL,
  raised_at DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_tom_cache_invalidation_raised (raised_at)
);
