-- The two demo accounts that carry the second-factor story, and the two roles
-- the deployment's `Tom2FAPolicy` keys on — so both halves of C-10 are exercised
-- out of the box rather than merely available:
--
--   dave — already holds a TOTP factor, so his login is **challenged**;
--   erin — holds none, so her login is **offered** one she may decline.
--
-- Both are **demo** content, so the filename carries the `@dev,test` environment
-- tag (G-MIG-2/3, step 12): a production apply skips this file entirely and
-- gains neither the accounts, the pre-enrolled secret, nor the demo roles. The
-- columns dave fills are created by the untagged [004], which production *does*
-- apply.
--
-- Their passwords are left NULL and hashed at boot by seedDemoPasswords, exactly
-- like the [003] users — hashing is the auth server's job, never raw SQL.
--
-- ## Why roles rather than a server-wide requirement
--
-- `installTwoFactorPolicy()` installs a `TomRole2FAPolicy` keyed on the two role
-- rows below, with `defaultRequirement: disabled`. The obvious alternative —
-- `optional` for *every* principal — would be a truthful configuration but a bad
-- sample: it turns alice's, bob's, carol's and the administrator's every login
-- into an enrolment dialogue, so a suite whose subject is a grant matrix, a
-- share or a file upload would have to open with a 2FA step about something
-- else. Scoping the requirement to accounts that exist *for* it is the same
-- choice this seed already made for dave, and it is what keeps "which accounts
-- owe a factor" readable in one place instead of implied by a default.

-- Dave's secret is the well-known RFC-shaped base32 test value — a *sample*
-- credential, never to be shipped: anyone reading this file can generate his
-- codes. That is precisely why this migration is tagged. A real enrolment
-- generates a fresh random secret per user (TomTotp2FAService.encodeBase32) and
-- shows it once — which is exactly what erin's first login does.
INSERT INTO auth_users
  (id, username, display_name, email, status, two_factor_type, two_factor_secret)
VALUES
  (5, 'dave', 'Dave Dijkstra', 'dave@example.com', 'active',
   'totp', 'JBSWY3DPEHPK3PXP')
ON DUPLICATE KEY UPDATE
  two_factor_type = VALUES(two_factor_type),
  two_factor_secret = VALUES(two_factor_secret);

-- Erin owns nothing and is shared into nothing, exactly like dave: she exists
-- for the *enrolment* path, so signing in as her shows the method chooser, the
-- QR code and the skip affordance, and then lands on the board's empty state.
-- Her two_factor_* columns stay NULL — that is what makes her enrollable rather
-- than challengeable.
INSERT INTO auth_users (id, username, display_name, email, status) VALUES
  (6, 'erin', 'Erin Nakamura', 'erin@example.com', 'active')
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- The two roles the policy reads off the principal's access-control information.
-- They are ordinary `auth_roles` rows, so the authadmin console lists and
-- assigns them like any other — moving an account into or out of the second
-- factor is a role edit, not a schema change.
INSERT INTO auth_roles (id, role_key, name) VALUES
  (6, 'two_factor_required', 'Second factor required'),
  (7, 'two_factor_optional', 'Second factor offered')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO auth_user_roles (id, user_id, role_id) VALUES
  (2, 5, 6),
  (3, 6, 7)
ON DUPLICATE KEY UPDATE role_id = VALUES(role_id);
