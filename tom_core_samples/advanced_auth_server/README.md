# advanced_auth_server

Auth server for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Two surfaces in one boot on `tom_core_server`: a JWT **authentication** issuer
(`/auth/login`, `/auth/refresh`, `/auth/me`, `/auth/logout`) and a role-gated
**administration** API (`/admin/users|roles|groups|grants|assignments`). The
admin endpoints that *mutate* roles and the grant matrix are a primary
deliverable — they do not exist elsewhere in the framework yet.

## Architecture

Each surface is split into a pure, database-free logic class and a thin
`@tomComponent` adapter the endpoint router binds to:

| Logic (unit-tested, no server) | Adapter (`@TomApiImplementation`) | Surface |
| --- | --- | --- |
| `AuthTokenService` over `AdvancedAuthenticationService` | `AdvancedAuthApiService` | `/auth/*` |
| `AdminService` over `AdminStore` | `AdvancedAdminApiService` | `/admin/*` |

The adapters carry the production wiring (the repository-backed stores) and the
explicit per-endpoint access annotations: `/auth/login` is `@TomPublicAccess`,
the rest of `/auth/*` is `@TomAuthenticatedAccess`, and every `/admin/*`
endpoint is `@TomRoleAccess(['admin'])`. The endpoint pipeline reads the caller's
principal from the bearer token via the default
`tomDefaultAuthenticationMiddleware`, and rejects a non-admin **before** the
method runs; `bin/auth_server_start.dart` installs the server-level
`forbiddenOnAccessDenied` handler that turns that rejection into **HTTP 403**.

## Running it

The boot resolves relative asset/migration paths against the CWD, so run it from
the package root:

```sh
cp .env.example .env
docker compose up -d auth-db          # MariaDB on host port 3307
dart run bin/auth_server_start.dart   # HTTP on port 8081
```

On first boot the server applies the migrations (creating `auth_db` + the
framework `tom_resource_grant` table and seeding the §A.4 grant matrix), then
hashes a **demo password** onto each seed account that has none. The seeded
credentials are (sample only — never ship them):

| Username | Password | Global role |
| --- | --- | --- |
| `admin` | `admin-pass` | `admin` |
| `alice` | `alice-pass` | — |
| `bob` | `bob-pass` | — |
| `carol` | `carol-pass` | — |

## Endpoints

`POST` / `PUT` bodies are JSON; the `Authorization: Bearer <authzToken>` header
carries the login's `authzToken` (the token that carries the resolved roles).

| Method & path | Access | Purpose |
| --- | --- | --- |
| `POST /auth/login` | public | Exchange credentials for the token pair |
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
# The §A.4 seed: viewer.title is "read".
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

## JWT signing

The server signs the token pair (HS256) and RSA-encrypts the authorization
payload using the framework's bundled sample keypair, configured non-dummy in
`initializeJwtSigning()`. The app server (advanced_app_server, step 21) applies
the identical configuration so a token minted here verifies there. **Replace the
keys with real ones before any real deployment.**
