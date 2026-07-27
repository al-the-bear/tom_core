-- One demo account that actually owes a second factor, so the two-pass login
-- path is exercised out of the box rather than merely available.
--
-- Dave is **demo** content, so the filename carries the `@dev,test` environment
-- tag (G-MIG-2/3, step 12): a production apply skips this file entirely and
-- gains neither the demo account nor a pre-enrolled secret. The columns he fills
-- are created by the untagged [004], which production *does* apply.
--
-- His password is left NULL and hashed at boot by seedDemoPasswords, exactly
-- like the [003] users — hashing is the auth server's job, never raw SQL.

-- The secret is the well-known RFC-shaped base32 test value — a *sample*
-- credential, never to be shipped: anyone reading this file can generate Dave's
-- codes. That is precisely why this migration is tagged. A real enrolment
-- generates a fresh random secret per user (TomTotp2FAService.encodeBase32) and
-- shows it once.
INSERT INTO auth_users
  (id, username, display_name, email, status, two_factor_type, two_factor_secret)
VALUES
  (5, 'dave', 'Dave Dijkstra', 'dave@example.com', 'active',
   'totp', 'JBSWY3DPEHPK3PXP')
ON DUPLICATE KEY UPDATE
  two_factor_type = VALUES(two_factor_type),
  two_factor_secret = VALUES(two_factor_secret);
