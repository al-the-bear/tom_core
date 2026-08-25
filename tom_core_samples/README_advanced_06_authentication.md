# Authentication (JWT)

*Part 06 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Authentication is where the two servers meet a single principal: the **auth
server issues** a signed JWT pair on a verified login, and the **app server
verifies** it — without ever calling back to the auth server — because both load
the *same* signing key. This part covers the `/auth/*` endpoints and the token
service that backs them, password hashing, the bearer-token pair and the shared
key that makes cross-server trust work, the **two-factor second pass** (TOTP),
the Flutter-free client auth layer (`auth_client.dart` + `authorized_http.dart`)
and its refresh-once-on-401, and the pre-login vs authenticated request paths.

## Token issuance at the auth server

The auth server exposes five `/auth/*` endpoints (plus the public login-resources
endpoint covered in part [08](README_advanced_08_resources_texts.md)), implemented
by `AdvancedAuthApiService` — the `@tomComponent` the endpoint pipeline routes to:

| Endpoint | Access | What it does |
| --- | --- | --- |
| `POST /auth/login` | **public** | Verify credentials, issue the token pair, return a `LoginResult`. |
| `POST /auth/second-factor` | **public** | Answer the challenge a `requires2FA` login came back with; on success returns the same token pair a 2FA-free login would have. See [Two-factor login](#two-factor-login-the-second-pass). |
| `POST /auth/refresh` | authenticated | Re-issue a fresh token pair for the caller's already-authenticated principal. |
| `GET /auth/me` | authenticated | Return the caller's `UserDto`. |
| `POST /auth/logout` | authenticated | A no-op server-side (stateless JWTs), kept so clients have a logout to call. |

The component is a deliberately thin boundary adapter. The real work splits across
two collaborators (the same seam philosophy as the persistence stores):

- **`AdvancedAuthenticationService`** (`implements TomAuthenticationService`) is
  the credential check the framework delegates each login to. It reads the account
  through an `AuthUserStore` seam — `RepositoryAuthUserStore` (live `auth_db`
  queries) in production, `InMemoryAuthUserStore` (seeded) under test — verifies
  the password, loads the user's role keys and group names, and builds the
  authenticated `TomPrincipal` + `TomAccessControlDefinition`.
- **`AuthTokenService`** is the pure, request-free logic that turns a verified
  login (or an already-authenticated principal) into the signed JWT pair and the
  wire `LoginResult`. Taking its collaborators by constructor is what lets the
  accept/reject/echo behaviour be unit-tested with no server, zone, or reflection.

`refresh`, `me`, and `logout` recover the caller's principal from the **request
zone** (`getFromCurrentZone<TomPrincipal>()`), which the server's authentication
middleware populates from the bearer token — *not* from the
`TomBearerAuthentication` client-side singleton, which the server never fills.
The contract-declared `TomAuthenticatedAccess` (`TomApiEndpoint.access`)
guarantees the pipeline already rejected any request without a principal, so the
zone value is non-null inside those methods.

A rejected login is the *expected* outcome of bad credentials, so the `login`
endpoint declares a `LoginUnauthorizedErrorHandler` that maps
`TomLoginException` to **HTTP 401** carrying only the stable error key; any
other error falls back to the opaque 500. Crucially, an unknown user and a
wrong password are rejected with the
*same* generic key (`error.invalid-user-or-password`), so the response never
reveals which of the two failed — no account-existence leak. A suspended account
is rejected distinctly (`error.user.suspended`) because that is an actionable
state, not a credential guess.

## Password hashing

Plaintext is turned into stored credentials in exactly one place —
`password_hashing.dart`, a thin adapter over the kernel `TomPasswordHasher`:

- **`hashPassword(plaintext)`** runs the kernel's default **Argon2** key
  derivation and returns a `(hash, hashType)` pair — a `salt$hash` value and its
  algorithm spec. A fresh random salt is generated per call, so the same plaintext
  hashes to a different value every time and the plaintext cannot be recovered —
  only re-derived and compared.
- The two halves are stored split across `UserRecord.passwordHash` (the `salt$hash`)
  and `UserRecord.hashType` (the spec the verifier needs to re-derive). The column
  split lives here and nowhere else.
- **`verifyUserPassword(record, plaintext)`** re-derives and compares; a user with
  no stored hash (a freshly seeded row) can never authenticate — it returns
  `false` rather than throwing.

This is why the migrations leave `password_hash` **NULL** (part
[05](README_advanced_05_persistence_database.md#migrations-schema-creation-vs-sample-data)):
hashing is the server's job, not the SQL's. At boot the auth server runs an
idempotent `seedDemoPasswords()` that fills a demo password onto each seed user
that still has none (`admin`/`alice`/`bob`/`carol`/`dave` → `*-pass`), so the README
`curl`s authenticate on first run; a user that already carries a hash is left
untouched, so a real credential is never clobbered.

## The bearer token and the shared signing key

A successful login mints **two** JWTs, mirroring what
`TomAuthenticationServer.authenticateUser` produces:

- the **authentication token** (`authToken`) — the public principal payload;
- the **authorization token** (`authzToken`) — the same public payload plus the
  *encrypted* access-control data (the roles/groups definition).

The login deliberately does **not** bake the principal's effective per-resource
role map into the token (RCD3, option b). The bearer token is opaque to the
client and is never read for enforcement, so a `resourceRoles` claim would have
no reader and could only go stale over the token's 2-hour life. Instead the
per-resource role map is resolved **live** wherever it is needed: the app
server's `ResourceRoleResolver` re-resolves the C-5 ownership grants
(`tom_principal_resource_grant`) **and** the C-6 `share`-mode delegations
(`tom_principal_delegation`) from `auth_db` on every request via
`TomDelegationResolver.resolveEffectiveRoles` (strongest role per resource,
resolving "now" so a revoked share stops granting access immediately, not at
token expiry), and its `GET /resource-roles` endpoint returns that same live map
to the client. The client reads its roles from that endpoint (RCB5), never from
the token — so there is a single live source of truth rather than a token claim
that must be kept consistent with it. `AdvancedAuthenticationService` therefore
leaves `aci.resourceRoles` empty at issue time.

Both are built by `TomBearerAuthentication.convertPrincipalToTokenPayload` +
`TomServerJwtToken(...).getJWT(issuer)`, signed under the issuer `'tom'`
(`TomAuthenticationServer.globalSettingJwtOrganization`), and expire after a
**2-hour** `tokenLifetime` — also the `LoginResult.expiresAt` horizon. The
`LoginResult` carries the `UserDto`, both tokens, and that expiry.

Cross-server trust rests on **one shared key, configured identically at both
boots**. Each server's `initializeJwtSigning()` installs the *framework's bundled
sample keypair* (`TomJwtConfiguration.hmacKey` / `rsaPrivKey` / `rsaPubKey`) as the
default sign configuration — the auth server signs with it, and the app server,
loading the *identical* keys, verifies a token the auth server issued **without a
network call back**. This is the standard "resource server trusts the auth
server's key" pattern: reusing one keypair rather than minting per-server keys is
exactly what makes a minted token verify on the other side. Both boots also set
the same issuer (`'tom'`), which the app server must match to accept a token.

### Sample keys and the development-key warning (G-AUTH-2)

The bundled keypair (`TomJwtConfiguration.hmacKey` / `rsaPrivKey` / `rsaPubKey`)
is a **development convenience, not a certificate**: it is the same
non-fresh key shipped with the framework and shared by every sample, so it is
public knowledge and useless for real trust. To make that impossible to miss,
each server leaves its `TomJwtConfiguration` marked as a *dummy* configuration
(`isDummy == true`, the constructor default), and the framework prints a
development-key warning **every time it signs or verifies a token** — the sample
does **not** suppress it. On boot you also see the one-line reminder emitted by
`warnIfDevelopmentSigningKey()`:

```
WARN  JWT signing uses the bundled development certificate (non-fresh,
      non-production). Install a real certificate before any real deployment;
      see README_advanced_06_authentication.md.
```

**Why it is always on.** The warning is the signal that no production
certificate has been installed. There is no flag to silence it — hiding this
deployment hazard behind a convenience toggle is exactly the failure mode the
warning exists to prevent.

**Installing a production certificate.** Mint your own HMAC/RSA keys, build a
`TomJwtConfiguration` from them, and pass `isDummy: false` (the last positional
argument) so the framework treats them as a real cert and stops warning:

```dart
TomJwtConfiguration.defaultSignConfiguration = TomJwtConfiguration(
  jwt.SecretKey(myHmacSecret),   // your signing secret
  base.algorithm,
  myRsaPrivateKeyPem,            // your RSA private key
  myRsaPublicKeyPem,             // your RSA public key
  false,                         // isDummy: false → real certificate, no warning
);
```

Both servers must install the **same** keys and issuer (`'tom'`) for the app
server to keep verifying tokens the auth server minted.

## Two-factor login: the second pass

Not every login finishes at `POST /auth/login`. An account enrolled in a second
factor gets back a `LoginResult` with **`requires2FA: true`** and an *interim*
token pair that authorizes nothing; the session only exists once the client
answers the challenge at `POST /auth/second-factor`. The sample ships this
working end-to-end with **TOTP** (RFC 6238 authenticator codes) and a seeded
dev/test account you can drive yourself — see [Trying it
locally](#trying-two-factor-login-locally).

### Enrolment is data, not code

Whether an account owes a second factor is two nullable columns on `auth_users`,
added by migration `[004]`:

| Column | Meaning |
| --- | --- |
| `two_factor_type` | The mechanism key, e.g. `'totp'`. **NULL/empty → password-only login.** |
| `two_factor_secret` | The mechanism's per-user secret (for TOTP, the base32 shared secret). |

So enabling or revoking 2FA for a user is a row update, not a deployment. The
secret is **server-only**: `AdvancedAuthenticationService` never projects it onto
the `TomPrincipal`, so it cannot reach a token claim. (It is deliberately not
carried in `TomUser.attributes` either — those *are* projected into the token's
public claims.)

### Pass 1 — the password is checked, but you are not authenticated

`AdvancedAuthenticationService` verifies the password exactly as before and then
builds a principal that says so out loud:

```dart
final twoFactorType = record.twoFactorType ?? '';
final requires2FA = twoFactorType.isNotEmpty;

final principal = TomPrincipal(
  authenticated: !requires2FA,     // ← passing the password is not enough
  requires2FA: requires2FA,
  twoFactorType: requires2FA ? twoFactorType : null,
```

`authenticated` is stated the same way the kernel *restores* it from a token
(`authenticated = username != GUEST && !requires2FA`), so the in-memory principal
and the token-restored one can never disagree. Bad credentials still fail here,
with the same generic key as always — a wrong password never reaches the second
pass.

Seeing `requires2FA`, `TomAuthenticationServer.authenticateUser` does not return
a session. It looks the mechanism's adaptor up in `Tom2FARegistry`, asks it to
`issueChallenge(...)`, and mints the **interim** pair carrying that challenge.

### What the interim token carries

The challenge lives *in the token* — there is no server-side pending-login
record, which is what keeps the auth server stateless and horizontally scalable.
Its **public** claims (`Tom2FAClaims`) hold:

| Claim | Content |
| --- | --- |
| `requires2FA` | The flag that marks this pair as interim. |
| `twoFactorType` | Mechanism key — `'totp'` here. |
| `twoFactorHint` | Short displayable hint (a masked phone number for a delivery mechanism). TOTP sets none: the code is already on the user's device. |
| `twoFactorAttempt` / `twoFactorAttemptsAllowed` | Attempts consumed / permitted (**3** for TOTP). |
| `twoFactorExpiresAt` | ISO-8601 UTC instant the challenge lapses (**5 minutes** for TOTP). |
| `twoFactorClientData` | The mechanism's opaque payload for the UI. TOTP sends `{digits: 6, periodSeconds: 30}` so an input field can size itself without hard-coding the mechanism. |

The token's **encrypted** section carries the access-control payload pass 1
already resolved, plus a `twoFactorVerification` slot for anything the adaptor
needs back on pass 2. Two consequences worth naming:

- pass 2 needs **no second trip to the user store** to rebuild the principal, and
  the principal **cannot be swapped** between the passes — it is recovered from
  the token the client presents;
- TOTP leaves `twoFactorVerification` **empty on purpose**. It re-resolves the
  secret from the database at verification time, so the secret never travels in a
  token at all — and revoking an enrolment takes effect on the very next login.

### Why the DTO only carries a flag

`LoginResult` exposes just `requires2FA` and `twoFactorType`. Everything else —
hint, attempts remaining, expiry, `clientData` — is read out of the stored token
by the kernel:

```dart
Tom2FAChallenge? get pendingChallenge =>
    TomBearerAuthentication.pendingTwoFactorChallenge;
```

One source of truth. A client that mirrored the attempt counter into its own
state would eventually disagree with the server about how many tries are left.

### Pass 2 — answering the challenge

`POST /auth/second-factor` takes a `SecondFactorRequest { code, challengeToken }`
and is declared **`TomPublicAccess()` with `includeBearerAuthentication: false`**
in `api_registry.dart`. That is forced, not lax: the interim principal is
`authenticated: false`, so a bearer gate would reject the very request the
endpoint exists to serve. The interim token therefore travels in the **body**,
not the `Authorization` header.

`AuthClient.submitSecondFactor(code)` reads the stored token, posts it with the
code, and on success stores the completed pair — the same call a UI makes:

```dart
final result = await authClient.login(
    LoginRequest(username: 'dave', password: 'dave-pass'));
if (result.requires2FA) {
  final challenge = authClient.pendingChallenge;   // digits, attempts, expiry
  await authClient.submitSecondFactor(codeFromUser);
}
```

On acceptance the returned pair is **exactly what a 2FA-free login would have
produced** — same claims, `requires2FA` cleared. That is not a coincidence:
`TomAuthenticationServer._issueTokens` is the single point at which either pass
mints, so the only difference between them is the challenge fed into the
projection. `AuthTokenService` delegates to `authenticatePass1` /
`authenticatePass2` rather than minting itself, which is what buys the sample the
second pass essentially for free.

### Refusal, retry, and what the attempt counter really bounds

A wrong code with attempts left comes back **401** carrying the stable key
`login.error.2fa.invalid-code` *and a re-issued `challengeToken`* with the
attempt spent (`SecondFactorRetryException` → `LoginUnauthorizedErrorHandler`).
`AuthClient` stores that token **before** throwing, and sets
`AuthClientException.canRetrySecondFactor`, so retrying is just another
`submitSecondFactor` call with a new code.

Storing it is load-bearing rather than tidy: the counter lives *inside* the
token, so a client that kept retrying against its previous copy would never spend
an attempt and would show the user "3 tries left" forever. Exhausting the
attempts (`login.error.2fa.attempts-exhausted`) or letting the challenge lapse
(`login.error.2fa.expired`) burns the chain — the client must restart at
`/auth/login`.

> **This is not a brute-force defence, and the sample says so.** A stateless
> server keeps no record of which interim tokens it has already answered, so it
> cannot distinguish a replay of an *earlier* token in the chain — still valid,
> still carrying its lower count — from the original presentation. The counter
> bounds a *cooperative* client and gives a UI its "2 tries left". What bounds an
> uncooperative one is the challenge's **5-minute** expiry. A deployment needing
> a hard per-challenge cap must add the server-side state that stateless
> verification deliberately omits (a spent-token denylist or a per-user counter),
> or rely on the mechanism's own rate limiting. `two_factor_login_test.dart`
> asserts this replay behaviour on purpose, so the limitation stays visible
> rather than being quietly assumed away.

### Mechanism selection and the secret resolver

`Tom2FARegistry` finds adaptors **by annotation**: it scans
`tomReflector.annotatedClasses` for `@Tom2FAAdaptor('<key>')`, so the running
server auto-registers `TomTotp2FAService` with no wiring. (The scan tolerates a
program with no generated reflection, which is why unit tests can call
`Tom2FARegistry.register` by hand instead.)

`TomTotp2FAService` ships **without** a secret source on purpose — a framework
class cannot know where your secrets live, and an unwired one fails every
challenge with `login.error.2fa.not-enrolled` rather than silently accepting. The
sample points it at the column from `AuthTokenService`'s constructor:

```dart
void installTotpSecretResolver(AuthUserStore store) {
  TomTotp2FAService.globalSettingSecretResolver = (context) async {
    final record = await store.findByUsername(context.principal.username);
    final secret = record?.twoFactorSecret ?? '';
    return secret.isEmpty ? null : secret;
  };
}
```

The TOTP policy is static settings, changeable at boot: `globalSettingDigits`
(6), `globalSettingPeriod` (30 s), `globalSettingWindowSteps` (1 step either
side, for clock skew), `globalSettingAttemptsAllowed` (3),
`globalSettingChallengeValidity` (5 min). Codes are compared in constant time,
and a submission of the wrong width is rejected before any HMAC is computed.

### Trying two-factor login locally

Migration `[005]-auth_two_factor_seed@dev,test.sql` is tagged `@dev,test`, so a
**production** database never gets it. In dev/test it enrols one demo account:

| | |
| --- | --- |
| Username | `dave` (Dave Dijkstra) |
| Password | `dave-pass` — NULL in SQL, hashed at boot by `seedDemoPasswords()` like every other demo user |
| Mechanism | `totp` |
| Secret | `JBSWY3DPEHPK3PXP` (base32) |

That secret is the RFC's own test vector — a **sample credential**, fine to print
in a README and useless anywhere real. Add it to any authenticator app (or
generate codes with `TomTotp2FAService.expectedCode('JBSWY3DPEHPK3PXP')`, which
applies the server's own digits/period so your code cannot drift from the
verifier's).

With the auth server running on `:8081`:

```bash
# Pass 1 — password accepted, but the session is not open yet.
curl -s -X POST http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"dave","password":"dave-pass"}'
# → {"requires2FA":true,"twoFactorType":"totp","authzToken":"<interim>", ...}

# Pass 2 — answer with the current 6-digit code and the interim token.
curl -s -X POST http://localhost:8081/auth/second-factor \
  -H 'Content-Type: application/json' \
  -d '{"code":"123456","challengeToken":"<interim>"}'
# → the completed pair: {"requires2FA":false,"authzToken":"<real>", ...}

# The completed token works everywhere a password-only one does.
curl -s http://localhost:8081/auth/me -H 'Authorization: Bearer <real>'
```

Try it wrong once and you get `401 {"error":"login.error.2fa.invalid-code",
"challengeToken":"<re-issued>"}` — use *that* token for the next attempt, and the
third failure ends the challenge.

Compare with `alice` / `alice-pass`, whose `two_factor_type` is NULL: the same
`POST /auth/login` returns `requires2FA: false` and a usable pair immediately.

### In the Flutter clients

Both Flutter clients complete the second pass. `advanced_app_client`'s sign-in
screen is **two phases on one screen**: `AppSession.login` branches on
`requires2FA` and — deliberately storing nothing but a flag, because the interim
token authorizes no call — leaves `isLoggedIn` false, so the shell keeps showing
the login screen while it switches to a code phase. Staying on one screen rather
than pushing a route is what keeps the shell's rule intact: the home is a pure
function of `isLoggedIn`, with no navigator state to unwind when a spent
challenge drops back to the credentials phase. The code field is sized from the
challenge's own `clientData['digits']`, never from a hardcoded 6, so a mechanism
with a different code width needs no client change. Sign in as `dave` /
`dave-pass` and enter the code your authenticator shows for `JBSWY3DPEHPK3PXP`.

The refusal path is the interesting half. `AuthClientException.canRetrySecondFactor`
travels across the backend seam as `AppBackendException.canRetrySecondFactor`,
and it is the only signal separating *wrong code, try again* from *the challenge
is spent, start over* — two different screens. On a retryable refusal the client
core has **already stored** the re-issued challenge token, so a retry is simply
another `submitSecondFactor` call and the screen re-reads `pendingChallenge` for
the decremented attempt count. When it is false the session abandons the pending
login and the screen falls back to username/password.

`advanced_authadmin_client` does the same, with one ordering consequence: its
login *probes* an admin call, because the `admin` role gate is per-operation
rather than on login. That probe moves to after pass 2 — it cannot run against an
interim token that authorizes nothing — so an enrolled non-admin is still
refused, just one pass later.

No administrator is 2FA-enrolled in the seeded `auth_db`, so
`InMemoryAdminBackend` enrols none either; an offline console that demanded a
code the real one does not would teach the wrong thing. But an enrolment is an
*account* property the console does not control, so the fake takes
`twoFactorUsernames` as a constructor argument, and
`advanced_authadmin_client/test/admin_login_two_factor_test.dart` uses it to
prove the console still works the day someone enrols `admin`.

Neither in-memory backend fakes the crypto: both verify with the kernel's own
`TomTotp`, against the same secret the migration seeds — so the offline path
accepts exactly what the server accepts, and the widget tests derive their code
the way a human derives one.

The second pass is asserted by `advanced_auth_server/test/two_factor_login_test.dart`
(server side), `advanced_client_core/test/auth_client_two_factor_test.dart`
(client side), `auth_client_integration_test.dart`'s `TC-22-12` (the whole
two-pass loop over a real socket against the running server), and
`advanced_app_client/test/login_two_factor_test.dart` +
`advanced_authadmin_client/test/admin_login_two_factor_test.dart` (the two
screens).

## The client auth layer

The Flutter-free `advanced_client_core` carries two cooperating pieces:

**`AuthClient`** (`auth_client.dart`) sequences the `/auth/*` calls and owns token
storage. On a successful `login` / `refresh` it stores the returned pair through
`TomBearerAuthentication.setTokens(...)`, so every following request can attach the
bearer; `logout` tells the server best-effort and then **always** discards the
local pair (even if the server call fails) by replacing the singleton. It maps any
non-success status to a typed `AuthClientException` carrying the HTTP status and
the server's stable error key — so a UI can branch on the key without parsing a
message, and a rejected login still never says *which* credential was wrong. It
talks through a `JsonTransport` seam (live `IoJsonTransport`, or a fake under
test).

> **Opaque token, by design.** `AuthClient` defaults `decryptTokens: false`: this
> Flutter-free sample treats the authorization token as an *opaque* bearer — it
> reads identity from `LoginResult.user` and field grades from the app API, so no
> RSA key needs to be configured client-side.

**`AuthorizedHttp`** (`authorized_http.dart`) is the decorator the app and admin
API clients send through. It composes — rather than reimplements — the two pieces
above: the `JsonTransport` carries the call, and `AuthClient.refresh` re-mints the
pair. The bearer is read from `TomBearerAuthentication` **fresh on every attempt**,
which is what makes the retry transparently pick up a just-refreshed token.

## Token refresh

`AuthorizedHttp.send` attaches the current bearer and defers the recovery
decision to the framework's pluggable policy (`tom_core_kernel`'s
`tomRunWithAuthRetry`, G-AUTH-3) — **refresh-once-on-401**: it sends the request
with the current bearer; a 2xx or any non-401 status (403/404/… the API client
interprets itself) returns as-is; a **401** triggers a single `AuthClient.refresh`
and *exactly one* retry with the freshly stored bearer. If the retry is still 401,
the session is genuinely dead and the kernel throws `TomAuthExpiredException`
(never loops); a refresh that itself fails surfaces its own `AuthClientException`.
So a single token expiry is invisible to the caller, while a dead session surfaces
as a typed error. `refresh` itself requires a prior login — with no stored
authorization token it throws `auth.no_token`.

## Pre-login vs authenticated request paths

Two request shapes coexist, divided by whether a bearer is present:

- **Pre-login (public).** `POST /auth/login` and `GET /auth/resources/login` carry
  **no** bearer — they must be reachable before a token exists, because you cannot
  obtain a token without logging in, and you cannot render the login screen without
  its texts. `AuthClient.login` / `loginResources` send these unauthenticated. The
  public login bundle is part [08](README_advanced_08_resources_texts.md); the
  end-to-end request lifecycle is appendix [A3](README_advanced_A3_request_lifecycle.md).
- **Authenticated.** Every other endpoint goes through `AuthorizedHttp`, which
  injects `Authorization: Bearer <authzToken>` and applies the refresh-once policy.
  The server's middleware decodes the bearer into the request-zone principal that
  the contract-declared `TomAuthenticatedAccess` (and the role/field gates of part
  [07](README_advanced_07_authorization.md)) check.

## Primary sources

- [`advanced_auth_server/README.md`](advanced_auth_server/README.md), [`advanced_client_core/README.md`](advanced_client_core/README.md)
- `advanced_auth_server/lib/src/auth/authentication_service.dart`, `.../auth/password_hashing.dart`, `.../endpoints/auth_endpoints.dart`; both servers' `bin/*_start.dart` `initializeJwtSigning()`
- `advanced_client_core/lib/src/auth/auth_client.dart`, `.../http/authorized_http.dart`
- **Two-factor:** `tom_core_server/lib/src/tomserver/authentication/two_factor.dart` (`Tom2FARegistry`, `TomTotp2FAService`) and `.../authentication_server.dart` (`authenticatePass1` / `authenticatePass2`); `tom_core_kernel/lib/src/tombase/security/two_factor.dart` (`Tom2FAChallenge`, `Tom2FAClaims`, `TomTotp`); migrations `[004]-auth_two_factor_columns.sql` / `[005]-auth_two_factor_seed@dev,test.sql`; tests `advanced_auth_server/test/two_factor_login_test.dart`, `advanced_client_core/test/auth_client_two_factor_test.dart`

---

← Prev: [05 · Persistence & the two databases](README_advanced_05_persistence_database.md) · Next: [07 · Authorization](README_advanced_07_authorization.md) →
