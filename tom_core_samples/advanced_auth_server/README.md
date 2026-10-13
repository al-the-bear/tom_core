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

**There is no `example/` directory, and that is deliberate: this package is
itself the runnable example.** It is one of the nine `advanced_*` packages
that together form the full-stack sample, so
`dart run bin/auth_server_start.dart` — the JWT issuer and the admin API — is
the demonstration, and an `example/` beside it would duplicate the entry point.
[The family's index](../README_advanced_sample.md#the-nine-packages) says which of the nine carry an `example/`, and why.

Read instead, in the order a newcomer wants them: [Running it](#running-it)
for the boot and its database, the [`curl` tour](#curl-tour) for login,
`/auth/me`, the admin grant read and write, and the 403 a non-admin gets — and
[`advanced_client_core/tool/run_cross_tier_integration.sh`](../advanced_client_core/tool/run_cross_tier_integration.sh)
for the whole stack end to end, which is where an admin grant edited here is
followed until it changes what the end-user client renders.

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
method runs. The framework answers that rejection itself, with a bare **404**
that carries no error key — so nothing here maps it, and the server-level
handler this sample used to install for it is gone.

A rejection raised *inside* a handler needs the other handler, because the
pipeline catches it in the per-endpoint `try/catch` and the server-level one
never sees it. `AdminEndpointErrorHandler`, declared on the
`@TomApiImplementation`, maps a `MalformedIdException` from
`persistence/auth_mapping.dart` to **HTTP 400** with body
`{"error": "request.id.malformed"}` — an id that is not a database key is the
caller's mistake, not a server fault, wherever it sat: a group's
`memberUserIds`, an `AssignmentRequest`'s user or group id, or a path id
(`/admin/users/{id}`, `/admin/groups/{id}`) on an update or a delete. All of them
go through `persistedId` in `auth_mapping.dart`. A well-formed id that names no
row is `admin.user.not_found` / `admin.group.not_found` instead, and a delete or
assignment is never reported as done when the id could not name anything. `AdminService` checks the membership before it
writes anything, because these endpoints declare no transaction and a rejection
further down would leave an orphan group, or a persisted rename, behind a
request the client was told had failed.

## API

The barrel `lib/advanced_auth_server.dart` is the package's stable entry point
and exports eight libraries. The column that matters for a reader deciding what
to touch is the last one: **two of the eight define a seam to implement**, the
rest are wiring to reuse or records to read.

| Exported library | What it is | For a consumer |
| --- | --- | --- |
| `src/endpoints/auth_endpoints.dart` | The `/auth/*` surface — credential login and the token lifecycle: `AuthTokenService`, the `AdvancedAuthApiService` adapter, `SecondFactorRetryException`, `LoginUnauthorizedErrorHandler` | reuse |
| `src/endpoints/admin_endpoints.dart` | The `/admin/*` surface — account, role and group CRUD, assignments, and the four-state grant matrix: `AdminService` over **`AdminStore`**, its repository and in-memory implementations, the `AdvancedAdminApiService` adapter, `GrantRepository`, `forbiddenOnAccessDenied` | **implement `AdminStore`** |
| `src/auth/authentication_service.dart` | The credential check the framework's `TomAuthenticationServer` delegates each login to: `AdvancedAuthenticationService` over **`AuthUserStore`**, with a repository and an in-memory implementation | **implement `AuthUserStore`** |
| `src/auth/passkeys.dart` | The second factors this server offers (`advancedTwoFactorMechanisms`: TOTP and passkeys) and `installPasskeyRelyingParty`, which binds passkeys to `localhost` and the origins in `ADVANCED_PASSKEY_ORIGINS` | reuse |
| `src/auth/password_hashing.dart` | Four functions over the `auth_db` `UserRecord` shape — `hashPassword`, `verifyPassword`, `applyPassword`, `verifyUserPassword` — a thin adapter over the kernel's `TomPasswordHasher` | reuse |
| `src/auth/two_factor_enrolment_store.dart` | The persistent second-factor enrolment store, with `LegacyBridging2FAEnrolmentStore` over accounts that predate it | reuse |
| `src/persistence/auth_persistence_model.dart` | The `auth_db` records and their repositories — users, roles, groups, the two membership join tables, and the grant/delegation repositories | read |
| `src/persistence/auth_mapping.dart` | Pure conversions between those records and the two shapes the server works with: the observable `advanced_todo_domain.User` and the `advanced_todo_contracts` DTOs | reuse |
| `src/resources/auth_resource_bundles.dart` | `AuthResourceBundles` — the two text sets this server owns, the public login screen's and the authenticated one's | reuse |

A seam is where a consumer substitutes its own storage: `AdminService` and
`AdvancedAuthenticationService` are written against the abstraction, the
production wiring binds the repository-backed implementation and the unit tests
bind the in-memory one. That is why both ship two implementations rather than
one — the in-memory pair is not a test fixture tucked away in `test/`, it is
part of what the package offers.

`test/readme_api_section_test.dart` derives both the barrel's exports and this
table's rows and fails when they disagree, so the list cannot drift from the
barrel the way a hand-written mirror would.

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

<!-- account-roster: auth-db -->

| Username | Password | Global role | Notes |
| --- | --- | --- | --- |
| `admin` | `admin-pass` | `admin` | Untagged `[002]` seed — present in **every** environment |
| `alice` | `alice-pass` | — | `@dev,test` `[003]` demo seed |
| `bob` | `bob-pass` | — | `@dev,test` `[003]` demo seed; reads German (`[009]`), so the ops server's digest mails him in `de` |
| `carol` | `carol-pass` | — | `@dev,test` `[003]` demo seed |
| `dave` | `dave-pass` | `two_factor_required` | `@dev,test` `[005]` seed — **enrolled in TOTP**, so the password only gets him through pass 1 |
| `erin` | `erin-pass` | `two_factor_optional` | `@dev,test` `[005]` seed — holds **no** factor, so her login is *offered* one she may decline or enrol |

<!-- /account-roster -->

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
| `GET /openapi.json` | public | The server's OpenAPI 3.1 document — framework-mounted; see [OpenAPI document](#openapi-document) |
| `POST /auth/refresh` | authenticated | Re-issue a fresh token pair |
| `GET /auth/me` | authenticated | The caller's `UserDto` |
| `POST /auth/logout` | authenticated | No-op (stateless JWT) |
| `GET /admin/users` · `POST /admin/users` | admin | List / create users |
| `PUT /admin/users` · `DELETE /admin/users/{id}` | admin | Update / delete a user |
| `GET /admin/roles` · `POST /admin/roles` | admin | List / create roles |
| `PUT /admin/roles` · `DELETE /admin/roles/{key}` | admin | Rename / delete a role |
| `GET /admin/groups` · `POST /admin/groups` | admin | List / create groups |
| `PUT /admin/groups` · `DELETE /admin/groups/{id}` | admin | Update / delete a group |
| `GET /admin/grants` · `PUT /admin/grants` | admin | Read / write the `(role, resourceKey) → TomAuthState` matrix |
| `POST /admin/assignments` | admin | Assign a user to a role and/or group |
| `GET /admin/resources` | admin | The admin console's resource bundle |

## OpenAPI document

The server publishes its OpenAPI 3.1 document at `GET /openapi.json`. The
document is generated at build time from the endpoint annotations by
`tom_core_openapi` and committed as `openapi/openapi.json`; the server only
serves the file, which `assets/config-resources_default.yaml` names:

```yaml
openApiDocument: "openapi/openapi.json"
```

`tool/openapi.dart` is the generator's entry point for this package. It
registers the contracts and installs this server's reflection seed — what makes
the endpoints visible — and states the document's title (`Advanced Auth Server`),
description and server URL (`http://localhost:8081`), so the commands need no
arguments:

```sh
dart run tool/openapi.dart :document           # rewrite openapi/openapi.json
dart run tool/openapi.dart :document --check   # fail when it is stale
dart run tool/openapi.dart :validate           # OpenAPI 3.1 meta-schema + references
```

`test/openapi_document_test.dart` runs `:document --check` and `:validate`, so
a change to an endpoint fails the suite until the document is regenerated, and
the regeneration is a reviewable diff. Validation needs `python3` with
`jsonschema`. The document lists the framework's endpoints beside the sample's
own, and [`advanced_openapi_client`](../advanced_openapi_client/README.md)
carries the `AuthApi` client generated from it, depending on `package:http`
alone.

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
fresh random secret (`TomTotp2FAService.generateSecret`) and returns it once with
the `clientData` a QR code is built from; `POST /auth/enrol/confirm` proves one
code against it and stores the enrolment; `POST /auth/enrol/skip` declines and
completes the login unchanged. An account that confirms is challenged on its
*next* login — from `tom_user_two_factor_enrolment`, not from the legacy
`two_factor_type` column that carries dave's.

The offer lists two factors: an authenticator app and a **passkey**. Choosing
`webauthn` at `POST /auth/enrol/begin` returns WebAuthn creation options in
`clientData.publicKey`; the browser's authenticator answers them, and the
answer goes to `POST /auth/enrol/confirm` in the `code` field like a typed code
would — `TomWebAuthn2FAService` verifies it and stores the passkey. Passkeys are
bound to the relying party `localhost`, and a ceremony is accepted only from the
origins in the OS environment variable `ADVANCED_PASSKEY_ORIGINS`
(comma-separated, and not read from `.env`; default `http://localhost:8090`, the
port a `flutter run -d chrome --web-port 8090` build is served on). `test/passkey_login_test.dart` drives the whole round —
offer, enrolment, the next login's challenge, sign-in — with the framework's
software authenticator, since a test has no browser.

## JWT signing

The server signs the token pair **RS256** with the private key
`installJwtSigning(configuration)` reads from the file `jwtSigningKeyFile`
names, and RSA-encrypts the authorization payload with the `jwtRsaPrivKey` /
`jwtRsaPubKey` pair. Every token names its key in a `kid` header — the RFC 7638
thumbprint of the public key — and carries the configured `jwtIssuer` and
`jwtAudience`. The public half is published at `GET /.well-known/jwks.json`
(public, cacheable for five minutes), mounted by the framework with nothing to
register here:

```sh
curl -s http://localhost:8081/.well-known/jwks.json
```

| Variable | Here |
| --- | --- |
| `JWT_SIGNING_KEY_FILE` | the PEM (PKCS#8) private key tokens are signed with |
| `JWT_VERIFICATION_KEY_FILES` | public keys this server rotated away from, kept until their tokens expire |
| `JWT_ISSUER` / `JWT_AUDIENCE` | written into every token; the app server must expect the same values |
| `JWT_ALGORITHM` | `RS256` by default; `ES256`, or `HS256` with `JWT_SHARED_SECRET_KEY` |
| `JWT_RSA_PRIV_KEY` / `JWT_RSA_PUB_KEY` | the payload-encryption pair, which the app server holds too |

The app server (`advanced_app_server`) lists this server's public key in its
`JWT_VERIFICATION_KEY_FILES` and holds no signing key, so it verifies a token
minted here and can mint none; that is the standard "resource server trusts the
authorization server" split.

This sample sets none of them, so the key material falls back to the
framework's bundled sample RSA pair — which is the *only* reason the two servers
currently agree. Set `JWT_SIGNING_KEY_FILE` here and the matching public key in
the app server's `JWT_VERIFICATION_KEY_FILES` (see `.env.example`) and the
agreement becomes a deliberate one; a mismatched key, issuer or audience and the
app server rejects this server's tokens.

The fallback is not quiet. `installJwtSigning` **refuses to boot** on it outside
a development or test environment (`TomSigningKeyException`, naming the
unconfigured fields), which is why the sample is started with `env=dev`; where it
is permitted it warns once at boot, and because the resulting
`TomJwtConfiguration` stays marked as a development ("dummy") certificate the
framework repeats the warning on **every** sign and verify — intentionally not
suppressed (G-AUTH-2). Configure the key material and the certificate is no
longer a dummy one and the warnings stop. **Do that before any real
deployment.**
