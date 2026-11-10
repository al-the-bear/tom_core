-- Optional database-side guard: reject every DELETE from the audit trail.
--
-- Tagged `@immutable` rather than `@hardened`, and separated from the UPDATE
-- guard on purpose: this one has an operational cost. Retention is expressed
-- in rows — `TomSqlAuditSink.purgeBefore` and `purgeToMaxEntries` both issue
-- DELETE — so installing this trigger is a decision to keep the trail forever.
--
-- Apply it when the retention policy is "never", or when pruning is done out
-- of band by a role that drops the trigger, prunes, and recreates it. Do not
-- apply it and then expect retention to work; it will fail, loudly, which is
-- the correct outcome but a surprising one to discover in production.
--
-- Kept in sync with `auditTrailNoDeleteTriggerDdl()` in
-- `lib/src/tomserver/audit/sql_audit_sql.dart`; `test/audit_sql_test.dart`
-- fails if the two drift apart.
CREATE TRIGGER IF NOT EXISTS trg_tom_audit_trail_no_delete
BEFORE DELETE ON tom_audit_trail
FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'audit trail is append-only: DELETE is not permitted';
