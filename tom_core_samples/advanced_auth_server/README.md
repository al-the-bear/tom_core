# advanced_auth_server

Auth server for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

Two surfaces in one boot on `tom_core_server`: a JWT **authentication** issuer
(`/auth/login`, `/auth/second-factor`, `/auth/refresh`, `/auth/me`,
`/auth/logout` — with an optional TOTP second pass) and a role-gated
**administration** API (`/admin/users|roles|groups|grants|assignments`). The
admin endpoints that *mutate* roles and the grant matrix are a primary
deliverable — they do not exist elsewhere in the framework yet.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[06 · Authentication (JWT)](../README_advanced_06_authentication.md)** and
> [10 · Servers & the secured endpoint pipeline](../README_advanced_10_servers_endpoints.md).

## Architecture

Each surface is split into a pure, database-free logic class and a thin
`@tomComponent` adapter the endpoint router binds to:

| Logic (unit-tested, no server) | Adapter (`@TomApiImplementation`) | Surface |
| --- | --- | --- |
| `AuthTokenService` over `AdvancedAuthenticationService` | `AdvancedAuthApiService` | `/auth/*` |
| `AdminService` over `AdminStore` | `AdvancedAdminApiService` | `/admin/*` |

The adapters carry the production wiring (the repository-backed stores); the
per-endpoint access policy is **declared on the contract** (`TomApiEndpoint.access`,
G-API-3), not annotated on the handlers: everything a caller needs *before* it
holds a session token is `TomPublicAccess` — credential exchange, the second
factor, the three enrolment passes and the login screen's resource bundle —
while the session endpoints (`/auth/refresh`, `/auth/me`, `/auth/logout`) are
`TomAuthenticatedAccess`, and every `/admin/*` endpoint is
`TomRoleAccess(['admin'])` (the shared `adminAccess` constant). The
endpoint pipeline extracts that declaration on first call, reads the caller's
principal from the bearer token via the default
`tomDefaultAuthenticationMiddleware`, and rejects a non-admin **before** the
method runs; `bin/auth_server_start.dart` installs the server-level
`forbiddenOnAccessDenied` handler that turns that rejection into **HTTP 403**.

A rejection raised *inside* a handler needs the other handler, because the
pipeline catches it in the per-endpoint `try/catch` and the server-level one
never sees it. `AdminEndpointErrorHandler`, declared on the
`@TomApiImplementation`, maps a `MalformedIdException` from
`persistence/auth_mapping.dart` to **HTTP 400** with body
`{"error": "request.id.malformed"}` — a group create or update whose
`memberUserIds` names something that is not a persisted user key is the caller's
mistake, not a server fault. `AdminService` checks the membership before it
writes anything, because these endpoints declare no transaction and a rejection
further down would leave an orphan group, or a persisted rename, behind a
request the client was told had failed.

## Running it

The boot resolves relative asset/migration paths against the CWD, so run it from
the package root:

```sh
cp .env.example .env
docker compose up -d auth-db          # MariaDB on host port 3307
dart run bin/auth_server_start.dart   # HTTP on port 8081
```

On first boot the server applies the migrations (creating `auth_db` + the
framework `tom_resource_grant` table and seeding its grant matrix), then
hashes a **demo password** onto each seed account that has none. The seeded
credentials are (sample only — never ship them):

| Username | Password | Global role | Notes |
| --- | --- | --- | --- |
| `admin` | `admin-pass` | `admin` | Untagged `[002]` seed — present in **every** environment |
| `alice` | `alice-pass` | — | `@dev,test` `[003]` demo seed |
| `bob` | `bob-pass` | — | `@dev,test` `[003]` demo seed |
| `carol` | `carol-pass` | — | `@dev,test` `[003]` demo seed |
| `dave` | `dave-pass` | `two_factor_required` | `@dev,test` `[005]` seed — **enrolled in TOTP**, so the password only gets him through pass 1 |
| `erin` | `erin-pass` | `two_factor_optional` | `@dev,test` `[005]` seed — holds **no** factor, so her login is *offered* one she may decline or enrol |

## Endpoints

`POST` / `PUT` bodies are JSON; the `Authorization: Bearer <authzToken>` header
carries the login's `authzToken` (the token that carries the encrypted roles and
groups). The token deliberately does **not** carry a per-resource role map: the
bearer is opaque and never read for enforcement, so the effective
`resourceRoles` map (`tom_principal_resource_grant` ownership rows ∪
`share`-mode `tom_principal_delegation` rows) is
resolved **live** instead — the app server re-resolves it from `auth_db` on every
request and exposes it through `GET /resource-roles`, which the client reads.

| Method & path | Access | Purpose |
| --- | --- | --- |
| `POST /auth/login` | public | Exchange credentials for the token pair (or, for a 2FA account, an interim pair + `requires2FA`) |
| `POST /auth/second-factor` | public | Answer a pending challenge (`code` + `challengeToken` in the **body**, not as a bearer) and complete the login |
| `POST /auth/enrol/begin` | public | Start enrolment — generates a fresh secret and returns it once, with the `clientData` a QR code is built from |
| `POST /auth/enrol/confirm` | public | Confirm enrolment by proving one code against the new secret |
| `POST /auth/enrol/skip` | public | Decline an *offered* factor and complete the login unchanged |
| `GET /auth/resources/login` | public | The login screen's resource bundle — readable before a token exists |
| `POST /auth/refresh` | authenticated | Re-issue a fresh token pair |
| `GET /auth/me` | authenticated | The caller's `UserDto` |
| `POST /auth/logout` | authenticated | No-op (stateless JWT) |
| `GET /admin/users` · `POST /admin/users` | admin | List / create users |
| `PUT /admin/users/{id}` · `DELETE /admin/users/{id}` | admin | Update / delete a user |
| `GET /admin/roles` · `POST /admin/roles` | admin | List / create roles |
| `PUT /admin/roles/{key}` · `DELETE /admin/roles/{key}` | admin | Rename / delete a role |
| `GET /admin/groups` · `POST /admin/groups` | admin | List / create groups |
| `PUT /admin/groups/{id}` · `DELETE /admin/groups/{id}` | admin | Update / delete a group |
| `GET /admin/grants` · `PUT /admin/grants` | admin | Read / write the `(role, resourceKey) → TomAuthState` matrix |
| `POST /admin/assignments` | admin | Assign a user to a role and/or group |
| `GET /admin/resources` | admin | The admin console's resource bundle |

## `curl` tour

Log in as the admin and capture the authorization token:

```sh
AUTHZ=$(curl -s http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin-pass"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["authzToken"])')

# Who am I?
curl -s http://localhost:8081/auth/me -H "Authorization: Bearer $AUTHZ"

# List the seeded users.
curl -s http://localhost:8081/admin/users -H "Authorization: Bearer $AUTHZ"
```

Read the grant matrix, raise a cell to `full`, and write it back — the
admin-only grant edit:

```sh
# The seeded matrix: viewer.title is "read".
curl -s http://localhost:8081/admin/grants -H "Authorization: Bearer $AUTHZ"

# Promote viewer.title to full and persist it.
curl -s -X PUT http://localhost:8081/admin/grants \
  -H "Authorization: Bearer $AUTHZ" -H 'Content-Type: application/json' \
  -d '{"viewer":{"todo.item.title":"full"}}'

# Re-read: viewer.title is now "full" (and a tom_resource_grant row carries it).
curl -s http://localhost:8081/admin/grants -H "Authorization: Bearer $AUTHZ"
```

A non-admin token is rejected with **403** — `alice` holds no global role:

```sh
ALICE=$(curl -s http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"alice-pass"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["authzToken"])')

# 403 Forbidden — the admin gate rejects her before the handler runs.
curl -s -o /dev/null -w '%{http_code}\n' \
  http://localhost:8081/admin/users -H "Authorization: Bearer $ALICE"
```

### Two-factor login (`dave`)

`dave` is enrolled in TOTP with the base32 secret **`JBSWY3DPEHPK3PXP`** (the
RFC test vector — a sample credential, seeded only under `@dev,test`). His login
comes back **pending**:

```sh
# Pass 1: the password is right, but no session is open yet.
INTERIM=$(curl -s http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"dave","password":"dave-pass"}' \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["requires2FA"],d["authzToken"])' \
  | cut -d' ' -f2)          # requires2FA is True

# Pass 2: the current 6-digit code, plus the interim token — in the *body*.
curl -s -X POST http://localhost:8081/auth/second-factor \
  -H 'Content-Type: application/json' \
  -d "{\"code\":\"123456\",\"challengeToken\":\"$INTERIM\"}"
```

Add the secret to any authenticator app to get the code (or generate one with
`TomTotp2FAService.expectedCode('JBSWY3DPEHPK3PXP')`, which applies this server's
own digits/period). A wrong code returns **401** with
`{"error":"login.error.2fa.invalid-code","challengeToken":"<re-issued>"}` — retry
with *that* token; the third failure burns the challenge, as does its 5-minute
expiry. On success you get exactly the pair a password-only login would have
produced. Full walkthrough:
[06 · Two-factor login](../README_advanced_06_authentication.md#two-factor-login-the-second-pass).

### Two-factor enrolment (`erin`)

`erin` holds the `two_factor_optional` role and no factor, so her login is met
with an *offer* rather than a challenge. `POST /auth/enrol/begin` generates a
fresh random secret (`TomTotp2FAService.encodeBase32`) and returns it once with
the `clientData` a QR code is built from; `POST /auth/enrol/confirm` proves one
code against it and stores the enrolment; `POST /auth/enrol/skip` declines and
completes the login unchanged. An account that confirms is challenged on its
*next* login — from `tom_user_two_factor_enrolment`, not from the legacy
`two_factor_type` column that carries dave's.

## JWT signing

The server signs the token pair (HS256) and RSA-encrypts the authorization
payload using the framework's bundled sample keypair, installed by
`initializeJwtSigning()`. That keypair is deliberately left marked as a
**development ("dummy") certificate**, so the framework emits its development-key
warning on every sign and verify and `warnIfDevelopmentSigningKey()` repeats it
at boot — intentionally not suppressed (G-AUTH-2). The app server
(`advanced_app_server`) applies the identical configuration so a token
minted here verifies there. **Replace the keys with real ones — built into a
`TomJwtConfiguration` with `isDummy: false` — before any real deployment.**
