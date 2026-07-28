-- Reference migration for the scheduler roll call (`TomSqlSchedulerNodes`).
--
-- Creates the `tom_scheduler_node` table: one row per scheduler node, rewritten
-- on every pass. This file is the canonical DDL and is kept in sync with
-- `schedulerNodeTableDdl()` in
-- `lib/src/tomserver/scheduling/sql_scheduling_sql.dart`;
-- `test/scheduling_schema_test.dart` fails if the two drift apart.
--
-- What the table is for, and what it is not:
--
--  * it lets the cluster notice a dead *node* rather than only an expired
--    *lease*, so a departure is reacted to within a poll interval instead of a
--    whole lease timeout, and abandoned runs can be attributed to the node that
--    left rather than merely reported as orphaned;
--  * it is NOT a correctness mechanism. The lease TTL remains the floor: a node
--    that misses its check-in but is still executing is still protected by its
--    lease, and a node declared failed here has its runs recovered earlier, not
--    by a different rule.
--
-- `checkin_interval` is milliseconds and is each node's OWN published cadence,
-- so peers are judged by the interval each actually keeps rather than by the
-- interval of whichever node happened to ask.
--
-- `node_id` is the same string the node claims runs under (`tom_job_run
-- .claimed_by`), so a failed node's work joins straight back to it.
--
-- The failure test — Quartz's, unchanged — is
--   failedAfter = checkin_at + max(checkin_interval, now - my_last_checkin)
--               + 7.5s
-- The second term is the one that is easy to leave out: a node that was itself
-- stalled must not accuse its peers of the outage it was having.
--
-- The formula compares one node's clock against another's, so the cluster's
-- clocks must agree to within about a second. Run NTP. Claiming, leasing and
-- lease expiry are unaffected — those instants are written and compared by the
-- database.
--
-- Instants are DATETIME(6) and are always written in UTC by the roll call.
CREATE TABLE IF NOT EXISTS tom_scheduler_node (
  node_id          VARCHAR(191) NOT NULL,
  checkin_at       DATETIME(6)  NOT NULL,
  checkin_interval BIGINT       NOT NULL,
  PRIMARY KEY (node_id)
);
