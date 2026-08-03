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

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthenticationService` | Abstract contract: `Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData)`. |
| `TomAuthenticationInfo` | Successful outcome: the authenticated `principal` plus its `acd` (access-control definition). |
| `TomAuthenticationData` | The login attempt: `username` + `key` (credential) plus the org/app/process/locale/client context. |
| `TomAuthenticationServer` | Orchestrates pass-1 / pass-2 authentication, the external-identity pass and the 2FA handshake. |
| `Tom2FAService` · `Tom2FAAdaptor` | Optional second-factor contract and adaptor. |
| `TomDummyAuthenticationService` | No-op service that authenticates any non-`"GUEST"` user (tests / bring-up). |
| `LoginException` | A `TomServerException` raised on failed authentication. |
| `TomOAuthAuthenticationService` | `TomAuthenticationService` for authorization-code + PKCE logins; delegates everything else. |
| `TomOAuthProviderConfig` · `TomOAuthProviders` | Provider configuration as **data**, read from the configuration tree under `oauth.providers`. |
| `TomOAuthFlow` · `TomOAuthPkce` · `TomOAuthStateStore` | The authorization-code + PKCE handshake and its pending-authorization records. |
| `TomOAuthTokenTransport` | The one HTTP call to a provider's token endpoint — the seam a stub provider replaces in tests. |
| `TomExternalIdentityStore` · `TomExternalIdentityLink` | The linking table: (issuer, subject) → local account, many per account. |
| `TomExternalIdentityDirectory` | What the deployment supplies: local principal lookup, and provisioning for a first external login. |

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
