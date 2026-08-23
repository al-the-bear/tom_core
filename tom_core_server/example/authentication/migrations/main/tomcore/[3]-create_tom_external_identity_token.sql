-- Reference migration for retained provider tokens (`TomExternalIdentityToken`,
-- read and written through `TomPersistentOAuthTokenStore`).
--
-- Apply this **only** where at least one OAuth provider is configured
-- `storeTokens: true`. It is not part of "Sign in with …": a deployment that
-- only authenticates users never acquires a provider credential, has nothing to
-- put in this table, and is better off without it. The framework's position and
-- the reasoning behind it are in
-- `lib/src/tomserver/authentication/readme.md` and the library dartdoc of
-- `oauth_tokens.dart`.
--
-- What a row is: one provider grant — an access token, usually a refresh token,
-- the scopes they cover and their lifetime — held on behalf of the external
-- identity `(issuer, subject)` that consented to it. It exists so an
-- application can call a provider's API *as the user* (read their calendar, list
-- their repositories, send mail) long after the login that established who they
-- are. That is delegated authorization, a different capability from
-- authentication, which is why it is a different table from
-- `tom_external_identity` rather than three more columns on it.
--
-- Several columns are not obvious:
--
--  * `token_data` holds the **whole grant, encrypted** — the JSON of
--    `TomOAuthTokenGrant`, passed through `TomJwtConfiguration.encrypt`
--    (RSA-OAEP, block-chained, base64). Neither token is ever written in the
--    clear. A provider refresh token is the most dangerous value this framework
--    writes to a database: a live bearer credential *at a third party*, valid
--    long after the session that produced it, and revocable only by the user
--    noticing. Storing it readable would make a database backup a set of keys
--    to other people's mail. `TEXT` rather than `VARCHAR` because the ciphertext
--    of a grant carrying two long opaque tokens does not have a useful bound.
--  * `token_scope`, `obtained_at` and `expires_at` are deliberately **not**
--    encrypted. They are the operator projection: "is this grant live, and what
--    does it cover?" must be answerable by a query, because an operator who has
--    to hold the private key to answer it defeats the point of encrypting the
--    rest. None of the three is authoritative — the values the code decides
--    from live inside `token_data` — so a projection that drifted could not
--    cause a stale token to be presented.
--  * `(issuer, subject)` is UNIQUE, matching the key of `tom_external_identity`.
--    A second grant for one identity would make which credential an application
--    presents depend on row order, and the older of two rows is by definition
--    the one whose refresh token the provider may already have rotated away.
--  * there is no foreign key to `tom_external_identity`, because a deployment
--    may keep its identity links in a table of its own and still let the
--    framework hold the credentials. The retention bound is enforced in code
--    instead: `TomExternalIdentityStore.unlink` deletes the grant before it
--    deletes the link, so a third-party credential never outlives the link it
--    was granted through.
--
-- Instants are UTC. The MariaDB driver stores a UTC `DateTime` as its local
-- wall clock and reads it back as the same moment (see
-- `MariaDbDatasource._toBindValue`), so the column carries no zone and needs
-- none.
--
-- This file is the canonical DDL and reproduces
-- `TomExternalIdentityToken.createTableSql` verbatim;
-- `test/reference_migrations_test.dart` fails if the two drift apart.
CREATE TABLE IF NOT EXISTS tom_external_identity_token (
  id BIGINT NOT NULL AUTO_INCREMENT,
  issuer VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  token_data TEXT NULL,
  token_scope VARCHAR(1024) NOT NULL DEFAULT '',
  obtained_at DATETIME(6) NULL,
  expires_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_external_identity_token (issuer, subject)
);
