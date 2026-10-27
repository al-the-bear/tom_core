# authentication

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Server-side login. A `TomAuthenticationService` verifies credentials and returns
a `TomAuthenticationInfo` pairing the authenticated `TomPrincipal` with its
access-control definition. `TomAuthenticationServer` drives the flow (including
the optional second factor via `Tom2FAService`); `TomDummyAuthenticationService`
is a no-op implementation for tests and bring-up that accepts any non-`"GUEST"`
user.

## The seam every login goes through

**A credential is verified in exactly one place, and everything that happens
after it has been verified happens in exactly one place.** That is the whole
design of this module, and it is what the sections below elaborate rather than
qualify.

`TomAuthenticationService.authenticateUser` is the *first* half: it turns a
credential into a `TomPrincipal`. A deployment's user table, an LDAP directory
and an OAuth provider are three answers to that one question, so they are three
implementations of that one contract — never three entry points.

`TomAuthenticationServer._completeLogin` is the *second* half: given a resolved
principal it asks `Tom2FAPolicy` whether a second factor is owed, branches into
challenge or enrolment if so, and otherwise mints the token pair through
`_issueTokens`. Nothing in that half knows or asks *how* the principal was
resolved, and nothing may be re-stated outside it.

The consequence to hold on to: a login that resolves a principal by some new
means gets the 2FA policy, the enrolment offer, the stored-timezone
resolution, the interim-token discipline and the claim set **for free and
identically**, because it reaches them through the same code, not through a
second copy that agrees today.

### External identity (OAuth / OIDC) is an implementation of that seam

`TomOAuthAuthenticationService` **implements `TomAuthenticationService`**. It is
not a parallel login path and must never become one.

* It receives a `TomOAuthCredential` (authorization code + state) in
  `TomAuthenticationData.key` — the slot that carries a password for a password
  login, typed `Object?` for exactly this reason.
* It exchanges that code with the provider, maps the external claims onto a
  local account through the linking table, and returns an ordinary
  `TomAuthenticationInfo`.
* It then **stops**. It issues no token, consults no 2FA policy and makes no
  session decision. `TomAuthenticationServer.authenticateExternal` hands its
  result to the same `_completeLogin` a password login reaches, so an
  externally-authenticated principal is challenged for its second factor,
  offered enrolment, and issued exactly the claims a password login would have
  produced for that principal.
* Password logins are not disturbed by its presence: the service takes an
  optional `delegate` and passes any non-`TomOAuthCredential` straight through,
  so wiring it up is one line and an account may hold a password *and* several
  external identities at once.

**The decision this records, and which the implementation must not quietly
reverse:** there is no "OAuth login endpoint" that mints tokens. `/oauth/*`
carries the *protocol* (provider list, authorization redirect, callback); the
*login* it results in is the same login every other credential produces. Any
change that gives the external path its own token issuance, its own 2FA check,
or its own principal-to-claims projection is a regression of this design even if
every test still passes, because the two copies will drift and the copy that
drifts is the one that stops asking for a second factor.

### Single sign-on: one login over two protocols

An enterprise identity provider speaks OpenID Connect or SAML 2.0, and both are
the *same* external login. `TomOAuthProviderConfig` and `TomSamlProviderConfig`
both implement `TomExternalProvider` (`external_provider.dart`) — id, issuer,
provisioning mode, role mapping, clock skew — and `TomOAuthAuthenticationService`
links, provisions and maps roles against that type alone. `TomOAuthFlow` is the
one entry point: a provider id naming a SAML identity provider is begun and
completed through its `saml` field, a `TomSamlFlow` sharing the same
pending-authorization store, so a login page drives both through `/oauth/*`.

* **OpenID Connect** providers (Entra ID, Okta, Keycloak) set `discovery: true`
  and name their issuer; `TomOAuthProviders.load` reads the endpoints from the
  issuer's discovery document at start-up and refuses a document published for
  another issuer. Every `openid` flow sends a nonce the `id_token` must return.
* **SAML 2.0** providers live under `saml.providers` (`saml_provider.dart`);
  `TomSamlProviders.load` fetches their metadata. The login has three legs
  (`saml_flow.dart`): the `AuthnRequest` out over the redirect binding, the
  identity provider's form post to `POST /saml/acs` (`saml_endpoints.dart`),
  which `TomSamlResponseValidator` verifies and answers with a `303` carrying a
  one-time handoff code, and the application's own `POST /oauth/complete` with
  that code. The third leg is what keeps the rule above: tokens travel only in
  the body of the application's call, never in a page answering a browser post.
* **Signatures** are verified by `TomXmlSignatureVerifier` over
  `TomExclusiveCanonicalizer` (`saml_xml_signature.dart`), in exactly the
  profile identity providers use — RSA-SHA256/512, exclusive canonicalization,
  one reference to the signed element's unique `ID`. SHA-1 is refused, the
  signature's `KeyInfo` is ignored in favour of the configured certificates, and
  the assertion read is always the one verified, which is what defeats signature
  wrapping.
* **Roles.** `TomExternalRoleMapping` (`groupsClaim`, `roleMapping`,
  `defaultRoles`) turns the provider's groups into Tom roles, recomputed on every
  login and added to the session's principal by `applyExternalRoles` before the
  access-control definition completes it. Nothing is written to a user store.
* **Provisioning** is `autoProvision` by default (just-in-time: behind an
  enterprise identity provider the provider is the account register),
  `linkExisting` for pre-provisioned accounts, `refuse` for a public provider.
  An existing account is never linked on an address the provider reports
  unverified.

### The provider's tokens: kept only when a provider is told to keep them

A provider's token response carries more than the claims a login needs. It
carries an **access token** — a credential for calling that provider's API as
the user — and usually a **refresh token**, which mints new access tokens for
months. Authentication needs neither: the framework has already learned who the
user is and issues its own session. So there is a real question about what to do
with them, and the answer is a decision rather than an oversight.

**The decision: the framework keeps nothing by default, and keeps the whole
grant properly when a provider opts in.** Both halves matter.

*Keeping nothing is the default* because most deployments want "Sign in with …"
and nothing else, and for them a stored refresh token is pure liability. A
framework session token is minted here and revocable here; a provider refresh
token is a long-lived credential **against a third party** that outlives the
session, is useful to anyone who obtains it, and is revocable only by the user
noticing. A deployment that never asked for delegated access must never end up
holding one, so `TomOAuthProviderConfig.storeTokens` defaults to `false` and
retention is opt-in per provider, exactly as scopes are.

*Keeping nothing as the only answer* was rejected, though it was tempting and is
the smaller surface. An application that genuinely needs to read the user's
calendar has to hold that credential somewhere, and refusing to hold it does not
remove the requirement — it pushes encryption at rest, retention limits and
refresh onto every application in turn. That is worse in a specific and
predictable way: the application that has to solve refresh reaches for the login
path, because the login path is the code that already knows how to talk to the
provider. Refreshing a token would then run the 2FA policy, touch the session and
mint claims — which is precisely the drift the seam decision above exists to
prevent. Better to own the capability and keep it off that path.

What that ownership consists of:

* **Always surfaced, retained only on request.** `TomOAuthExchange.tokens`
  carries the grant out of every exchange, so a caller that wants to use it for
  the duration of *this* request always may. "Keeps nothing" is therefore a
  statement about storage, not a capability the framework withholds.
* **Encrypted at rest, never in the clear.** `TomPersistentOAuthTokenStore`
  writes the whole grant through `TomJwtConfiguration.encrypt` into
  `tom_external_identity_token.token_data` — the same at-rest primitive behind a
  2FA enrolment secret. The scopes and the timestamps sit beside it unencrypted
  on purpose: an operator must be able to ask "is this grant live and what does
  it cover?" without the private key, and none of those three columns is
  authoritative.
* **Revoked, then deleted with the link.** `TomExternalIdentityStore.unlink`
  revokes the grant at the provider (RFC 7009, where a `revocationEndpoint` is
  configured) and then deletes it *before* the link it belongs to. Forgetting a
  credential is not ending one — a copy taken before the unlink goes on working
  until the provider's own lifetime runs out. Best effort: a provider that
  cannot be reached is logged and the deletion proceeds, because refusing to
  unlink would leave the deployment holding the credential it was told to drop.
* **Deleted when dead.** `TomOAuthFlow.accessTokenFor` deletes a grant it finds
  expired with no refresh token, rather than answering `null` and leaving it. It
  can never mint another token, so it is a fact about the past, not a credential
  — and the store would otherwise accumulate rows an operator cannot tell apart
  from live but idle ones. A *rejected* refresh is kept and thrown on instead: a
  provider erroring during an outage is not proof the grant is dead.
* **Refreshed through the flow, never through the service.**
  `TomOAuthFlow.refreshGrant` and `TomOAuthFlow.accessTokenFor` are one HTTP call
  to a token endpoint on behalf of a user who consented some time ago. They
  consult no `TomAuthenticationService`, ask no 2FA policy, touch no session and
  produce no principal. Refreshing is not a login; a change that makes it reach
  `_completeLogin` is a regression of the seam decision above.

A deployment that opts in usually has to say so to the provider as well — Google
returns no refresh token without `access_type=offline` — which is what
`TomOAuthProviderConfig.authorizationParameters` is for. Those extras are applied
*before* the flow's own parameters, so a configuration typo cannot replace
`state`, `redirect_uri` or the PKCE challenge.

### The pending authorization is *shared state*, not process state

An authorization-code flow is **two HTTP requests**, and the second one is not
issued by the client at all — the provider redirects the browser to the callback,
and a load balancer sends that redirect to whichever node it likes. So the record
written by the first request must be readable by *any* node serving the second.
Held in a field, it is readable by exactly one, and a flow that lands elsewhere
fails as `oauth.flow.unknown_state` — the same key an expired or replayed state
produces, which is why the symptom reads as "external login works, but
intermittently, and the log says replay attack".

`TomSqlOAuthStateStore` puts the record in `tom_oauth_state`, a framework table
declared once as a `TomFrameworkTable` like every other. Three decisions in it
are worth stating outright, because each could plausibly have gone the other way:

* **The PKCE verifier is stored as written, not encrypted.** It is a
  single-use, ten-minute nonce whose only purpose is to prove that the party
  redeeming the code is the party that began the flow, and it is worthless
  without the authorization code, which the store never sees. Encrypting it
  would need a key shared by every node — a second piece of distributed state
  to protect the first, guarding nothing that outlives the request pair. What
  the deployment *does* owe this table is ordinary database access control; it
  is not a public table.
* **Expiry is a predicate, not a job.** Every read carries
  `expires_at > :now`, so an expired row is invisible from the instant it
  expires regardless of whether anything has swept it — the correctness does
  not depend on the cleanup running. A throttled sweep on write then deletes
  what is invisible, so the table does not grow without bound. A scheduled job
  would have made liveness a dependency of correctness; this way it is only a
  dependency of size. That sweep runs `purgeExpired`, which is also what a
  deployment calls to prune from a job of its own: one predicate, so the
  background prune and an operator's prune cannot come to disagree about what
  "expired" means.
* **Completion is one statement.** `consume` is a single
  `DELETE … RETURNING`, so two nodes racing the same callback cannot both see
  the row: the database picks a winner and the loser gets nothing back. Reading
  and then deleting would have opened exactly the window that lets a state be
  spent twice.

Which store a deployment gets is configuration, read from `oauth.stateStore`
beside `oauth.providers` and defaulting to memory — a single-node deployment and
a test suite keep the in-memory store and need no database at all.

### Provisioning: the identity provider keeps the accounts

Over SCIM 2.0 the identity provider creates users and groups before anyone
signs in, keeps them current, and deactivates or deletes them. That is not a
second login path either: it is a register the login reads.
`TomScimService` (`scim_service.dart`) serves the identity provider's requests
over a `TomScimStore` — `TomMemoryScimStore`, or `TomSqlScimStore`
(`sql_scim_store.dart`) over the `tom_scim_resource` framework table
`scimResourceTable` declares (`scim_sql.dart`) — with the filter and
PATCH-path language in `scim_filter.dart`. `TomScimServer`
(`scim_endpoints.dart`) mounts it under `/scim/v2` once a `TomScimProvisioning`
read from `scim.bearerTokens` is installed, and installing claims `/scim/v2/` in
`TomEndpointCredentials`, so the framework leaves the identity provider's static
secret to the endpoint instead of refusing it as a token.

* **Deprovisioning revokes.** A deactivated, deleted or renamed user, and every
  member a group change touches, is passed to `TomScimService.revoke` —
  `TomCacheInvalidator.revokePrincipal` by default — so the sessions they
  already hold are refused on every node, not only their next login.
* **The login reads the register.** `TomScimIdentityDirectory`
  (`scim_directory.dart`) is the `TomExternalIdentityDirectory` over the
  provisioned users: under `provisioning: linkExisting` a single sign-on login
  resolves to the provisioned account, a deactivated one is refused with
  `login.error.scim.inactive`, and the roles come from the account's groups
  through a `TomExternalRoleMapping` — so the login still ends in the one
  `_completeLogin`.
* **LDAP and Active Directory are not provided.** An on-premises directory
  reaches this server through an identity provider that speaks SCIM, OpenID
  Connect or SAML.

### Service accounts: a credential that is not a login

A service account — a nightly import, another service, a partner's integration
— authenticates with an API key in `X-API-Key` rather than by logging in.
`TomApiKeys` (`api_keys.dart`) issues a key once as `tomk.<keyId>.<secret>`,
keeps only the SHA-256 of the secret, scopes the key to a subset of the
account's roles, and rotates and revokes it; `TomSqlApiKeyStore`
(`sql_api_key_store.dart`) keeps accounts and keys where every node sees them.

* **The key resolves a principal; it mints nothing.** The request pipeline reads
  `X-API-Key` only when no `Authorization` header was sent, and the key yields an
  authenticated principal — `service:<accountId>`, the key's roles intersected
  with the account's — that every access rule reads as it reads a user's. There
  is no token, no second factor and no session: a key is presented on every
  request.
* **A refusal looks like no key.** A malformed, unknown, revoked or expired key
  and a disabled account all authenticate nothing alike, and the request
  proceeds unauthenticated; the reason is logged, never the key.
* **Revocation reaches every node** that shares the cache invalidation channel:
  a node caches the key records it looked up for at most a minute, and `revoke`
  and `rotate` drop the entry through `TomCacheInvalidator`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthenticationService` | Abstract contract: `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData)`. |
| `TomAuthenticationInfo` | Successful outcome: the authenticated `principal` plus its `acd` (access-control definition). |
| `TomAuthenticationData` | The login attempt: `username` + `key` (credential) plus the org/app/process/locale/client context. |
| `TomAuthenticationServer` | Orchestrates pass-1 / pass-2 authentication, the external-identity pass and the 2FA handshake. |
| `Tom2FAService` · `Tom2FAAdaptor` | Optional second-factor contract and adaptor. |
| `TomDummyAuthenticationService` | No-op service that authenticates any non-`"GUEST"` user (tests / bring-up). |
| `TomLoginException` | A `TomServerException` raised on failed authentication. Declared in `little_things`, next to its base class, so the 2FA subsystem can throw it without importing the server that catches it. |
| `TomOAuthAuthenticationService` | `TomAuthenticationService` for authorization-code + PKCE logins; delegates everything else. |
| `TomOAuthProviderConfig` · `TomOAuthProviders` | Provider configuration as **data**, read from the configuration tree under `oauth.providers`. |
| `TomOAuthFlow` · `TomOAuthPkce` · `TomOAuthStateStore` | The authorization-code + PKCE handshake and its pending-authorization records. |
| `TomSqlOAuthStateStore` | A `TomOAuthStateStore` over the `tom_oauth_state` table — the one every node of a cluster shares. |
| `TomOAuthStateStoreSettings` | Which store a deployment gets, read from `oauth.stateStore`; memory unless told otherwise. |
| `TomOAuthTokenTransport` | The one HTTP call to a provider's token endpoint — the seam a stub provider replaces in tests. The live `TomHttpOAuthTokenTransport` sends through the kernel's `TomResilientClient`: every call is bounded by the provider's timeout and circuit breaker, a `GET` is retried, the token `POST` is not (a code is single-use). |
| `TomExternalIdentityStore` · `TomExternalIdentityLink` | The linking table: (issuer, subject) → local account, many per account. |
| `TomExternalIdentityDirectory` | What the deployment supplies: local principal lookup, and provisioning for a first external login. |
| `TomOAuthTokenGrant` | One provider grant: access token, refresh token, scopes, lifetime. Never prints either token. |
| `TomOAuthTokenStore` · `TomMemoryOAuthTokenStore` | Where a grant lives, keyed `(issuer, subject)`. Unregistered means nothing is ever stored. |
| `TomPersistentOAuthTokenStore` · `TomExternalIdentityToken` | The grant over `tom_external_identity_token`, encrypted at rest. |
| `TomOAuthServer` | The three `/oauth/*` endpoints the handshake is driven through — list the providers, begin an authorization, complete one. |
| `TomExternalProvider` · `TomExternalRoleMapping` · `applyExternalRoles` · `TomExternalTenancyMapping` | What an OIDC and a SAML provider share, the group-to-role mapping applied to every login's principal, and the claims naming the tenant and sign-in organization of a Tom identity provider's tokens. In `external_provider.dart`. |
| `TomSamlProviders` · `TomSamlProviderConfig` · `TomSamlIdpMetadata` · `TomSamlCertificates` · `TomSamlNames` | SAML 2.0 identity providers as data, read from `saml.providers`, with their metadata fetched by `load`. In `saml_provider.dart`. |
| `TomTenantProviderSets` | Provider sets keyed by tenant: a tenant with a set of its own (`oauth.tenants.<id>.providers`, `saml.tenants.<id>.providers`, or installed at run time) offers only its providers. In `tenant_provider_sets.dart`. |
| `TomSamlFlow` · `TomSamlResponseValidator` | The three-leg SAML login and every check a response must pass. In `saml_flow.dart`. |
| `TomXmlSignatureVerifier` · `TomExclusiveCanonicalizer` · `TomXmlDsig` · `TomSamlException` | XML Signature verification in the identity-provider profile, its canonicalization, and the SAML exception. In `saml_xml_signature.dart`. |
| `TomSamlService` · `TomSamlServer` | `POST /saml/acs` and `GET /saml/metadata/<providerId>`. In `saml_endpoints.dart`. |
| `oauthStateTable` · `oauthStateTableDdl` | The single declaration of `tom_oauth_state`, from which its DDL and the convergence check are derived; `defaultOAuthStateTable` is the name a deployment gets when it chooses none. |
| `Tom2FASendLimiter` · `Tom2FASend` · `Tom2FAMemorySendLimiter` | The bound on *sending*: the first email or SMS code to an address goes out at once, each later one waits twice as long, up to 30 days, and a correct code ends the run. Refused sends fail with `login.error.2fa.send-limit` (`rateLimited`). On by default, per process; a cluster installs one its nodes share. |
| `Tom2FAAttemptStore` · `Tom2FAAttempt` · `tom2FATokenFingerprint` | What makes the attempt counter a bound rather than a hint: a record that an interim token has been answered, so replaying an earlier token in the chain cannot mint a fresh allowance. `Tom2FAMemoryAttemptStore` is the default and is per process; a cluster installs one its nodes share. The store is keyed on a SHA-256 of the token, never the token. |
| `Tom2FAEnrolment` · `Tom2FAEnrolmentStore` · `Tom2FAEnrolmentSupport` | A factor a principal has set up, where those live, and the extra contract a mechanism implements to be enrollable *through* a login rather than out of band. `TomMemory2FAEnrolmentStore` and `TomPersistent2FAEnrolmentStore` are the two shipped stores; `TomUserTwoFactorEnrolment` is the row behind the second. |
| `TomDeliveredCode2FAService` | The shape every *delivered* one-time code shares — generate, seal, send, recognise — with `TomEmailCode2FAService` and `TomSmsCode2FAService` as the two shipped mechanisms. |
| `TomWebAuthn2FAService` · `TomWebAuthnVerifier` · `TomWebAuthnSoftwareAuthenticator` | Passkeys: a credential made by the user's authenticator and verified by its signature over the challenge and the page's origin, which is what makes it phishing-resistant. Offered once a relying party id is configured; attestation is requested as `none` and not checked. The software authenticator makes real credentials in memory, for tests and bring-up only. |
| `TomServerSelfLogin` · `TomServerSession` | Logs the *deployment* in as itself and installs the `TomServerPrincipal` that caps user grants. `TomServer.start()` calls it before binding the socket. The session carries the token's expiry, and the install schedules its own renewal against it — a cap installed once would keep capping at yesterday's entitlements. A failed renewal keeps the principal it has, because dropping it widens access. |
| `TomServiceCredential` | The deployment's own credential and where to present it, read from the configuration; `null` when none was configured, which is what makes the whole feature opt-in. |
| `TomServiceLoginTransport` | The one JSON POST the self-login makes — the seam a test replaces instead of running an auth server. |
| `TomServerSelfLoginException` | Raised when a *configured* self-login cannot complete; it aborts `TomServer.start()` rather than degrading to uncapped. |
| `TomSignInOrganizationDirectory` · `TomSignInOrganizations` · `TomSignInOrganization` · `TomOrganizationFallback` | The sign-in organization: the deployment's hook listing a principal's organizations and signing it in for one; every login settles its organization against the list, and `TomAuthenticationServer.switchOrganization` re-issues tokens for another within a session, audited. In `sign_in_organization.dart`. |
| `installJwtSigning` | Builds the process-wide token signing from the server configuration — `jwtAlgorithm` (RS256 by default, ES256, HS256), the signing key in `jwtSigningKeyFile` (or `jwtSharedSecretKey` under HS256), the retired keys in `jwtVerificationKeyFiles`, `jwtIssuer`, `jwtAudience` and the payload-encryption pair `jwtRsaPrivKey` / `jwtRsaPubKey` — and installs it as `TomJwtSigning.current`. Key material left unset falls back to the framework's bundled sample key — permitted in a development or test environment, refused anywhere else; ES256 has no sample key. |
| `verifyBearerToken` | The inbound check: the configured algorithm (never the token's `alg`), a `kid` naming a held key, the signature, the issuer and the audience. A failure is `null` — no credentials — and a warning. |
| `TomSigningKeyException` | Raised by `installJwtSigning` when a server outside development would have signed with the bundled sample keys; names the fields that were not configured. `clientThrow: false` — it is a deployment fault, not a request's. |
| `TomJwtSigning` | How this process signs and verifies tokens: the algorithm, every verification key, the signing key id, whether it can sign at all, the issuer and the audience. `requireSigning()` refuses to issue on a verify-only server. |
| `TomJwtAlgorithm` · `TomJwtKey` · `TomJwtSigningKey` · `readPemFile` | The three algorithms; a verification key under its `kid`, the RFC 7638 thumbprint of its public JWK, so every server derives the same id from the same key; a private key with its public half; and the PEM file reader. In `jwt_keys.dart`. |
| `TomJwtKeyException` | A key or signing setting that cannot be used. `clientThrow: false`. |
| `TomJwksService` · `TomJwksServer` | `GET /.well-known/jwks.json`: the public half of every verification key, public, cacheable for five minutes, `404` under HS256. Mounted by the endpoints pipeline like every component. In `jwks_endpoint.dart`. |
| `TomScimService` | The SCIM 2.0 service provider over a store, independent of HTTP: users and groups created, read, queried, replaced, patched and deleted, and `revoke` called for every user a change takes access from. In `scim_service.dart`. |
| `TomScimStore` · `TomMemoryScimStore` · `TomSqlScimStore` · `TomScimResourceRow` | Where provisioned resources are kept: per process, or rows of `tom_scim_resource` every node shares — per tenant in both, the SQL store routed and filtered by its `tenant` column. In `scim_resource.dart` and `sql_scim_store.dart`. |
| `TomScimResource` · `TomScimResourceType` · `TomScimSchemas` · `TomScimException` | One provisioned user or group, the two resource types, the SCIM URNs, and the exception carrying a status and `scimType`. In `scim_resource.dart`. |
| `scimResourceTable` · `scimResourceTableDdl` · `defaultScimResourceTable` | The single declaration of `tom_scim_resource`. In `scim_sql.dart`. |
| `TomScimFilter` · `TomScimPath` · `TomScimAnd` · `TomScimOr` · `TomScimNot` · `TomScimValuePath` · `TomScimComparison` · `scimValues` · `scimLookup` · `scimKeyOf` | The SCIM filter and PATCH-path language, and the case-insensitive JSON reads it is written over. In `scim_filter.dart`. |
| `TomScimProvisioning` · `TomScimApi` · `TomScimServer` | The installed service and its bearer secrets (SHA-256 digests, compared in constant time), and the seventeen endpoints under `/scim/v2` in `application/scim+json`. In `scim_endpoints.dart`. |
| `TomScimIdentityDirectory` | Single sign-on over the provisioned users, with roles from their groups. In `scim_directory.dart`. |
| `TomApiKeys` · `TomApiKeyException` | Issues, rotates, revokes and checks API keys; `install` makes it the one the request pipeline reads `X-API-Key` with. In `api_keys.dart`. |
| `TomServiceAccount` · `TomApiKey` · `TomIssuedApiKey` · `TomApiKeyIdentity` | The account, a key's stored record (the hash of its secret, never the secret), a key as issued — the one time its value is visible — and the key a request authenticated with, in the request zone. In `api_keys.dart`. |
| `TomApiKeyStore` · `TomMemoryApiKeyStore` · `TomSqlApiKeyStore` · `TomServiceAccountRow` · `TomApiKeyRow` | Where accounts and key records live: per process, or rows of `tom_service_account` and `tom_api_key` every node shares. In `api_keys.dart` and `sql_api_key_store.dart`. |
| `serviceAccountTable` · `apiKeyTable` · `defaultServiceAccountTable` · `defaultApiKeyTable` | The two tables' declarations and default names. In `sql_api_key_store.dart`. |
| `TomSessionCookie` · `TomSameSite` · `TomSessionCookieException` | A browser session's access token in an `HttpOnly` cookie (`attach`, `clear`), with a page-readable CSRF token beside it. Once `TomSessionCookie.current` is installed from the `sessionCookie` key, the request pipeline reads the cookie from a request without an `Authorization` header and holds an unsafe method to the double-submit check (`checkCsrf`), answering `403` otherwise. In `session_cookie.dart`. |

### Error keys raised by the token signing

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `jwt.signing.key.unconfigured` | `TomSigningKeyException` | Key material would fall back to the bundled sample keys outside development or test, or an ES256 server has no key. |
| `jwt.keys.unknown_algorithm` | `TomJwtKeyException` | `jwtAlgorithm` names no supported algorithm. |
| `jwt.keys.unreadable_key_file` | `TomJwtKeyException` | A configured key file cannot be read or holds no key of the configured algorithm's kind. |
| `jwt.keys.verify_only` | `TomJwtKeyException` | A token was to be issued by a server configured with verification keys only. |

### Error keys raised by single sign-on

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `oauth.config.discovery_not_loaded` · `oauth.config.discovery_failed` · `oauth.config.discovery_issuer_mismatch` | `TomOAuthException` | A `discovery: true` provider read without its document, a document that cannot be read, or one naming another issuer. |
| `oauth.config.invalid_role_mapping` | `TomOAuthException` | `roleMapping` or `defaultRoles` has the wrong shape. |
| `oauth.config.duplicate_provider_id` | `TomOAuthException` | One id configured as both an OAuth and a SAML provider. |
| `oauth.flow.nonce_mismatch` | `TomOAuthException` | The `id_token` does not carry the flow's nonce. |
| `login.error.oauth.unverified-email` | `TomLoginException` | An existing account would be linked on an address the provider reports unverified. |
| `saml.config.*` | `TomSamlException` | The `saml.providers` block, a provider's metadata, certificates or key files cannot be used. |
| `saml.acs.unknown_state` · `saml.flow.not_asserted` · `saml.flow.handoff_mismatch` | `TomSamlException` | A response or a completion that does not belong to a pending SAML login. |
| `saml.response.*` · `saml.assertion.*` · `saml.signature.*` · `saml.xml.unbound_prefix` | `TomSamlException` | A refused response; the key reaches the application's page as `error_description`. |

### Error keys raised by SCIM provisioning

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `scim.not_found` | `TomScimException` (404) | No resource, resource type or schema has that id. |
| `scim.uniqueness` | `TomScimException` (409) | Another user has the `userName`, or another group the `displayName`, in any case. |
| `scim.invalid_filter` · `scim.invalid_path` | `TomScimException` (400) | A `filter` or a PATCH `path` cannot be read. |
| `scim.invalid_value` · `scim.invalid_syntax` | `TomScimException` (400) | A body that is not a resource, or a PATCH that is not a PATCH. |
| `scim.no_target` · `scim.mutability` | `TomScimException` (400) | A PATCH with nothing to act on, or of an attribute the service owns. |
| `scim.unauthorized` | `TomScimException` (401) | The request carries no configured bearer secret. |
| `scim.not_enabled` | `TomScimException` (404) | No `TomScimProvisioning` is installed, or none could be configured. |
| `scim.store.unknown_datasource` | `TomServerException` | `TomSqlScimStore.named` names a data source that is not registered. |
| `login.error.scim.inactive` | `TomLoginException` | A single sign-on login to an account its identity provider deactivated. |

### Error keys raised by API keys

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `api_key.issue.unknown_account` | `TomApiKeyException` | `issue` names an account that does not exist. |
| `api_key.issue.role_not_held` | `TomApiKeyException` | `issue` asks for a role the account does not hold. |
| `api_key.rotate.unknown_key` · `api_key.revoke.unknown_key` | `TomApiKeyException` | `rotate` or `revoke` names a key that does not exist. |

### Error keys raised by session cookies

| Key | Exception | Meaning |
| --- | --------- | ------- |
| `authentication.session_cookie.config.invalid` | `TomSessionCookieException` | The `sessionCookie` settings have a value of the wrong shape, or `SameSite=None` without `Secure`. |
| `authentication.csrf.rejected` | `TomSessionCookieException` (403) | A cookie-authenticated request with an unsafe method failed the CSRF check: no or a mismatched `X-CSRF-Token`, or a foreign `Origin` the CORS policy does not admit. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // One login attempt carries the user plus its org/app/locale context.
  final data = TomAuthenticationData(
    username: 'alice',
    key: 'secret',
    organization: 'sales',
    application: 'todo',
    process: 'login',
    language: 'en',
    country: 'US',
    timezone: 'UTC',
    client: 'web',
  );

  // The dummy service authenticates any non-"GUEST" user — handy for tests.
  final TomAuthenticationService service = TomDummyAuthenticationService();
  final info = await service.authenticateUser(data);

  print(data.username);                 // alice
  print(info.principal.runtimeType);    // the authenticated TomPrincipal
}
```

See [`doc/authentication.md`](../../../../doc/authentication.md) for the two
authentication passes, the 2FA handshake, the external-identity path, SCIM
provisioning, service accounts with API keys and browser sessions in a cookie.
Five examples split the module along the seam described above:
`example/authentication/authentication_example.dart` is the local login,
`two_factor_enrolment_example.dart` and `two_factor_login_example.dart` the
second factor either side of enrolment, `oauth_login_example.dart` the
external path, and `scim_provisioning_example.dart` provisioning from the
identity provider's first call to the deactivation that ends a session — all
five connection-free and checking their own results.
`test/authentication_test.dart`, `test/two_factor_test.dart`,
`test/oauth_test.dart`, `test/saml_test.dart`, `test/scim_test.dart`,
`test/jwt_signing_test.dart`, `test/jwt_keys_test.dart` and
`test/api_keys_test.dart` cover the module, `test/web_security_test.dart` the
session cookie and its CSRF check,
`test/scim_store_db_test.dart` and `test/ratelimit_api_keys_db_test.dart`
(tag `db`) run the relational SCIM and API-key stores, and
`test/sso_keycloak_test.dart` (tag `sso`, started by `tool/run_sso_tests.sh`)
logs in against a real Keycloak; `test/examples_test.dart` runs the five
examples and
`test/readme_quick_start_test.dart` runs the snippet above, so none of them can
drift away from the code.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
