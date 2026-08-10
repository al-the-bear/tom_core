-- Reference migration for the identity linking table
-- (`TomExternalIdentityLink`, read and written through
-- `TomPersistentExternalIdentityStore`).
--
-- Apply this wherever any OAuth/OIDC provider is configured. Unlike the token
-- table in `[3]`, this one is not opt-in: it is what "Sign in with …" *is*. The
-- framework ships no default identity store precisely so that a deployment can
-- keep its links in a table of its own — but the moment it uses the framework's
-- persistent store, this is the table it reads.
--
-- What a row is: one external identity — the pair `(issuer, subject)` a provider
-- guarantees — bound to one local account. The reasoning behind the shape is in
-- the library dartdoc of `oauth_identity.dart`; the two points that decide the
-- DDL are worth repeating here:
--
--  * `(issuer, subject)` is UNIQUE because that pair *is* the identity. A
--    duplicate would make which local account a sign-in reaches depend on row
--    order, which is an authentication bug with no error message. The pair is
--    also the key rather than the email claim: people change their email address
--    (which would silently provision a second account for the same human), and
--    two providers can assert the same email for two different people, one of
--    them by simply not verifying it.
--  * `local_username` is deliberately **not** unique, and is indexed rather than
--    keyed. One account may hold a Google identity, a corporate SSO identity and
--    a local password at once — the state every real deployment converges on —
--    so several rows per account is the normal case, not an anomaly. The index
--    is what makes "every identity linked to this account", the
--    account-settings question, a lookup rather than a table scan.
--
-- `display_name` is what the provider asserted when the link was made, kept for
-- operator diagnostics ("which Google account is this?"); nothing authenticates
-- from it. `last_login_at` is not decoration either: it is what lets an operator
-- answer "is this link still in use?" before revoking a provider, and what makes
-- an unexpected sign-in visible.
--
-- There is no foreign key from `tom_external_identity_token` (`[3]`) to this
-- table, so the two migrations have no ordering dependency and either may be
-- applied without the other. The retention bound between them is enforced in
-- code instead: `TomExternalIdentityStore.unlink` deletes the grant before it
-- deletes the link, so a third-party credential never outlives the link it was
-- granted through.
--
-- Instants are UTC. The MariaDB driver stores a UTC `DateTime` as its local
-- wall clock and reads it back as the same moment (see
-- `MariaDbDatasource._toBindValue`), so the column carries no zone and needs
-- none.
--
-- This file is the canonical DDL and reproduces
-- `TomExternalIdentityLink.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart.
CREATE TABLE IF NOT EXISTS tom_external_identity (
  id BIGINT NOT NULL AUTO_INCREMENT,
  issuer VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  local_username VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL DEFAULT '',
  linked_at DATETIME NULL,
  last_login_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_external_identity (issuer, subject),
  KEY idx_tom_external_identity_local (local_username)
);
