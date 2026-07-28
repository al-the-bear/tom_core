-- Optional database-side guard: reject every UPDATE of the audit trail.
--
-- Tagged `@hardened`, so it applies only in an environment of that name (C-16
-- migration environment tags). It is deliberately not part of the default
-- chain: a deployment whose serving credential already lacks UPDATE gains
-- nothing from it, and applying it needs TRIGGER rights that a locked-down
-- schema owner may not wish to exercise.
--
-- Where it does earn its place is the deployment that cannot separate
-- credentials — one application user, one schema, UPDATE already granted on
-- everything in it. There the grant cannot express "append-only" and this can.
--
-- Kept in sync with `auditTrailNoUpdateTriggerDdl()` in
-- `lib/src/tomserver/audit/sql_audit_sql.dart`; `test/audit_sql_test.dart`
-- fails if the two drift apart.
--
-- This is defence in depth, not the primary mechanism: a connection holding
-- SUPER or TRIGGER can drop the trigger. The grant remains the guarantee.
CREATE TRIGGER IF NOT EXISTS trg_tom_audit_trail_no_update
BEFORE UPDATE ON tom_audit_trail
FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'audit trail is append-only: UPDATE is not permitted';
