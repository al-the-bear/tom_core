-- auth_db admin seed: the single administrator account the /admin/* API is
-- gated on, plus the `admin` role and the assignment that grants it. This is the
-- one seed a **production** apply keeps — it is **untagged**, so it runs in every
-- environment (G-MIG-2/3). The demo users, the project roles, the demo group and
-- the tom_resource_grant matrix are all sample content and live in the
-- `@dev,test`-tagged [003]-auth_demo_seed migration, which a production apply
-- skips.
--
-- Runs after [000] (identity tables) and [001] (grant table), so auth_users,
-- auth_roles and auth_user_roles all exist. Every insert uses
-- `ON DUPLICATE KEY UPDATE`, so a re-applied migration is idempotent.
--
-- password_hash is left NULL: hashing is the auth server's kernel-crypto job
-- (lib/src/auth/password_hashing.dart), applied at boot by seedDemoPasswords,
-- never in raw SQL. On boot the admin
-- row is filled with the sample `admin` credential — sample only, never ship it.

-- The administrator account. Holds the global `admin` role for /admin/* gating;
-- no other seed user carries a global role.
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (1, 'admin', 'System Administrator', 'admin@example.com', 'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- The global `admin` role — the axis the /admin/* endpoints require. Defined
-- here (not in the demo seed) because the admin assignment below FKs it, and a
-- production apply that omits the demo seed still needs the gate to resolve.
INSERT INTO auth_roles (id, role_key, name) VALUES
  (1, 'admin', 'Administrator')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- The admin user holds the global `admin` role assignment.
INSERT INTO auth_user_roles (id, user_id, role_id) VALUES
  (1, 1, 1)
ON DUPLICATE KEY UPDATE role_id = VALUES(role_id);
