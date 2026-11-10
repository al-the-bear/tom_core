-- The auditor: the demo account that reads the audit trail through the
-- framework's audit-report API (`tomAuditReportsApi`), which every endpoint
-- gates on the `auditor` role. The advanced_audit_client application signs in
-- as her.
--
-- Demo content, so tagged `@dev,test` like the other demo users: a production
-- deployment creates the `auditor` role and assigns it through the authadmin
-- console. password_hash is left NULL here, as on every seed user; the auth
-- server's boot fills it (`seedDemoPasswords`, `audrey-pass`).
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (7, 'audrey', 'Audrey Auditor', 'audrey@example.com', 'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

INSERT INTO auth_roles (id, role_key, name) VALUES
  (8, 'auditor', 'Auditor')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO auth_user_roles (id, user_id, role_id) VALUES
  (4, 7, 8)
ON DUPLICATE KEY UPDATE role_id = VALUES(role_id);
