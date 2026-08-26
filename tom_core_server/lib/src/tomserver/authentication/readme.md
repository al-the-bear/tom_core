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
* **Deleted with the link.** `TomExternalIdentityStore.unlink` deletes the grant
  *before* the link it belongs to. A third-party credential never outlives the
  link it was granted through, and the other order would leave an orphaned live
  credential behind.
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
| `TomOAuthTokenTransport` | The one HTTP call to a provider's token endpoint — the seam a stub provider replaces in tests. |
| `TomExternalIdentityStore` · `TomExternalIdentityLink` | The linking table: (issuer, subject) → local account, many per account. |
| `TomExternalIdentityDirectory` | What the deployment supplies: local principal lookup, and provisioning for a first external login. |
| `TomOAuthTokenGrant` | One provider grant: access token, refresh token, scopes, lifetime. Never prints either token. |
| `TomOAuthTokenStore` · `TomMemoryOAuthTokenStore` | Where a grant lives, keyed `(issuer, subject)`. Unregistered means nothing is ever stored. |
| `TomPersistentOAuthTokenStore` · `TomExternalIdentityToken` | The grant over `tom_external_identity_token`, encrypted at rest. |
| `TomServerSelfLogin` | Logs the *deployment* in as itself and installs the `TomServerPrincipal` that caps user grants. `TomServer.start()` calls it before binding the socket. |
| `TomServiceCredential` | The deployment's own credential and where to present it, read from the configuration; `null` when none was configured, which is what makes the whole feature opt-in. |
| `TomServiceLoginTransport` | The one JSON POST the self-login makes — the seam a test replaces instead of running an auth server. |
| `TomServerSelfLoginException` | Raised when a *configured* self-login cannot complete; it aborts `TomServer.start()` rather than degrading to uncapped. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // One login attempt carries the user plus its org/app/locale context.
  final data = TomAuthenticationData(
    username: 'alice',
    key: 'secret',
    organization: 'acme',
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

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
