# Authentication (JWT)

*Part 06 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Authentication is where the two servers meet a single principal: the **auth
server issues** a signed JWT pair on a verified login, and the **app server
verifies** it — without ever calling back to the auth server — because both load
the *same* signing key. This part covers the `/auth/*` endpoints and the token
service that backs them, password hashing, the bearer-token pair and the shared
key that makes cross-server trust work, the Flutter-free client auth layer
(`auth_client.dart` + `authorized_http.dart`) and its refresh-once-on-401, and
the pre-login vs authenticated request paths.

## Token issuance at the auth server

The auth server exposes four `/auth/*` endpoints (plus the public login-resources
endpoint covered in part [08](README_advanced_08_resources_texts.md)), implemented
by `AdvancedAuthApiService` — the `@tomComponent` the endpoint pipeline routes to:

| Endpoint | Access | What it does |
| --- | --- | --- |
| `POST /auth/login` | **public** | Verify credentials, issue the token pair, return a `LoginResult`. |
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
`@TomAuthenticatedAccess` guarantees the pipeline already rejected any request
without a principal, so the zone value is non-null inside those methods.

A rejected login is the *expected* outcome of bad credentials, so the `login`
endpoint declares a `LoginUnauthorizedErrorHandler` that maps `LoginException` to
**HTTP 401** carrying only the stable error key; any other error falls back to the
opaque 500. Crucially, an unknown user and a wrong password are rejected with the
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
that still has none (`admin`/`alice`/`bob`/`carol` → `*-pass`), so the README
`curl`s authenticate on first run; a user that already carries a hash is left
untouched, so a real credential is never clobbered.

## The bearer token and the shared signing key

A successful login mints **two** JWTs, mirroring what
`TomAuthenticationServer.authenticateUser` produces:

- the **authentication token** (`authToken`) — the public principal payload;
- the **authorization token** (`authzToken`) — the same public payload plus the
  *encrypted* access-control data (the roles/groups definition).

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

> **Sample keys only.** The bundled keypair is a development convenience; the
> `false` flag on the config merely suppresses the dummy-key warning — it does not
> change the keys. Replace with real keys before any real deployment.

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

`AuthorizedHttp.send` implements **refresh-once-on-401**: it sends the request with
the current bearer; a 2xx or any non-401 status (403/404/… the API client
interprets itself) returns as-is; a **401** triggers a single `AuthClient.refresh`
and *exactly one* retry with the freshly stored bearer. If the retry is still 401,
the session is genuinely dead and it throws `AuthorizedHttpException` (never
loops); a refresh that itself fails surfaces its own `AuthClientException`. So a
single token expiry is invisible to the caller, while a dead session surfaces as a
typed error. `refresh` itself requires a prior login — with no stored authorization
token it throws `auth.no_token`.

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
  `@TomAuthenticatedAccess` (and the role/field gates of part
  [07](README_advanced_07_authorization.md)) check.

## Primary sources

- [`advanced_auth_server/README.md`](advanced_auth_server/README.md), [`advanced_client_core/README.md`](advanced_client_core/README.md)
- `advanced_auth_server/lib/src/auth/authentication_service.dart`, `.../auth/password_hashing.dart`, `.../endpoints/auth_endpoints.dart`; both servers' `bin/*_start.dart` `initializeJwtSigning()`
- `advanced_client_core/lib/src/auth/auth_client.dart`, `.../http/authorized_http.dart`
- `advanced_example_specification_plan.md` — A.5 Authentication & session flow, A.7, A.11, Phases 2 & 4

---

← Prev: [05 · Persistence & the two databases](README_advanced_05_persistence_database.md) · Next: [07 · Authorization](README_advanced_07_authorization.md) →
