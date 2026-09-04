# advanced_app_server

App server for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

A secured task-manager API on `tom_core_server`. It trusts the JWT signing key
shared with `advanced_auth_server`, validates the bearer token on every request,
resolves the principal's resource access (ownership + shares) and four-state
field grades, persists the `app_db`, and lets an owner share a resource with
another user so the grant takes effect on the grantee's next request.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[05 · Persistence & the two databases](../README_advanced_05_persistence_database.md)** and
> [10 · Servers & the secured endpoint pipeline](../README_advanced_10_servers_endpoints.md).

## Architecture

The `AppApiService` implementation is split into pure, database-free logic
classes — each over a store seam — and one thin `@tomComponent` adapter the
endpoint router binds to. Every service is unit-tested against seeded in-memory
stores with no server and no MariaDB; the adapter carries the production wiring
(the repository-backed stores) and the per-endpoint access annotations.

| Logic (unit-tested, no server) | Concern | Surface |
| --- | --- | --- |
| `AppReadService` over `AppReadStore` | List workspaces/projects/lists/items; the principal's flat resource-role map | `GET /workspaces…/items`, `GET /resource-roles` |
| `AppWriteService` over `AppWriteStore` + the resolvers | Create/update/delete items, comments, projects with field-grade enforcement | `POST`/`PUT`/`DELETE /items…`, `POST /projects` |
| `AppShareService` over `ShareDelegationStore` + the resolver | Owner-only share / revoke | `POST /share`, `DELETE /share/{id}` |

Two resolvers underpin authorization (both database-free over their own seam):

- **`ResourceRoleResolver`** — ownership-or-share → the principal's effective
  `ProjectRole` on a resource. It resolves through the framework
  `TomDelegationResolver` (C-5 ownership grants + C-6 `share`-mode
  `TomPrincipalDelegation` rows; strongest role wins), then keeps the strongest
  over the `item → list → project → workspace` containment chain. `null` means no
  access.
- **`FieldGradeResolver`** — `ProjectRole` → per-field `TomAuthState` (the
  grant matrix the auth server owns), so a write touching a field the role is
  not `full` on is rejected server-side.

The per-endpoint access policy is **declared on the contract**
(`TomApiEndpoint.access`, G-API-3), not annotated on `AdvancedAppApiService`'s
handlers: `appHealth` is `TomPublicAccess`, every other endpoint is
`TomAuthenticatedAccess`. The pipeline extracts that declaration on first call
and reads the caller's principal from the
bearer token via the default `tomDefaultAuthenticationMiddleware`; the
resource- and field-level checks then run inside the handlers. The services
throw stable `TomEndpointHandlerException` keys rather than HTTP responses, and
`bin/app_server_start.dart` installs the server-level `appServerErrorHandler`
that maps those keys (and the pipeline's pre-invocation access-denied) onto the
HTTP contract: denials → **403**, an unreachable resource → **404**
(closed/safe, never leaking existence), a `MalformedIdException` from
`persistence/app_mapping.dart` → **400** with body
`{"error": "request.id.malformed"}`, everything else → the framework default.
`AppEndpointErrorHandler`, declared on the `@TomApiImplementation`, applies the
same mapping to rejections raised *inside* a handler — the pipeline catches
those in its per-endpoint `try/catch`, where the server-level handler cannot
reach them.

## Running it

The boot resolves relative asset/migration paths against the CWD, so run it from
the package root — with the **auth server already up** (its DB holds the grant
matrix this server reads, and it mints the tokens this server verifies):

```sh
# 1. Auth server + its DB (separate package) — see ../advanced_auth_server.
( cd ../advanced_auth_server && cp .env.example .env \
    && docker compose up -d auth-db \
    && dart run bin/auth_server_start.dart )   # HTTP 8081, auth_db on 3307

# 2. This app server + its DB.
cp .env.example .env
docker compose up -d app-db                    # MariaDB on host port 3308
dart run bin/app_server_start.dart             # HTTP on port 8080
```

Two datasources are wired (`assets/datasources_default.yaml`): `app_db` (port
3308) holds the app's own tables; `main` points at the auth server's `auth_db`
(port 3307) so the field-grade resolver reads the `tom_resource_grant` matrix.
**The app server only reads grants; it never writes them.** On first boot it
applies the `database_migrations/app_db` tree (the app schema and demo seed).

The seeded users come from the auth server (sample only — never ship them):

| Username | Password | Note |
| --- | --- | --- |
| `admin` | `admin-pass` | global `admin` |
| `alice` | `alice-pass` | owns workspace 1 |
| `bob` | `bob-pass` | shared `editor` on project 1 |
| `carol` | `carol-pass` | shared `viewer` on project 1 |

## Endpoints

`POST` / `PUT` bodies are JSON; `Authorization: Bearer <authzToken>` carries the
auth server login's `authzToken`. All but `/status` (and the framework's
`/health` liveness probe) require an authenticated principal; resource
ownership/share and per-field grade are enforced inside the handlers.

| Method & path | Access | Purpose |
| --- | --- | --- |
| `GET /status` | public | Typed JSON status (`{status, service}`) |
| `GET /health` | public | Framework plain-text liveness probe (`OK`) — auto-mounted |
| `GET /workspaces` · `POST /workspaces` | authenticated | List (owner-scoped) / create a workspace |
| `PUT /workspaces/{id}` · `DELETE /workspaces/{id}` | authenticated | Update / delete a workspace (owner-scoped at the database) |
| `GET /projects` · `POST /projects` | authenticated | List / create a project (workspace owner/editor) |
| `GET /lists` | authenticated | Lists the caller can reach |
| `GET /items` · `POST /items` | authenticated | List / create items (create: editor+, field-graded) |
| `PUT /items/{id}` · `DELETE /items/{id}` | authenticated | Update (field-graded) / delete (editor+) an item |
| `GET /attachments` | authenticated | Attachment descriptors for the visible items of a list |
| `GET /items/{id}/comments` · `POST /items/{id}/comments` | authenticated | Read / add a comment on an item (add: commenter+) |
| `GET /items/{id}/subtasks` · `POST /items/{id}/subtasks` | authenticated | Read / add a checklist step (add: editor+) |
| `PUT /subtasks/{id}` | authenticated | Update a checklist step (editor+) |
| `GET /resource-roles` | authenticated | The caller's flat `resourceKey → roleName` map (client grades fields locally) |
| `GET /resources` | authenticated | The app client's text resource bundle |
| `POST /share` | authenticated | **Owner-only** — grant a user a role on a resource |
| `DELETE /share/{id}` | authenticated | **Owner-only** — revoke a share |

The framework file endpoint additionally publishes
`POST|GET|HEAD|DELETE /files/app_items/{id}/attachment`, mounted by the boot's
one-line `TomFileSlots.register(itemRepository)`. It is graded per row by the
C-4 column resolver, not by the endpoint access declaration. The item's second
file column, `internal_note`, is deliberately **not** exposed, so
`/files/app_items/{id}/internal_note` is a 404 however privileged the caller is.

## `curl` tour

Get a token from the **auth server** and reach an app-server endpoint with it —
the cross-server JWT trust in action:

```sh
ALICE=$(curl -s http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"alice-pass"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["authzToken"])')

# A token minted by the auth server (8081) verifies at the app server (8080).
curl -s http://localhost:8080/projects -H "Authorization: Bearer $ALICE"
```

A missing/invalid token is rejected with **403** before the handler runs:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/projects
```

Share a project with another user — only its **owner** may, and the grant is
effective immediately (the grantee's very next request resolves the new role):

```sh
# Look up carol's user id (she is the grantee).
curl -s http://localhost:8081/admin/users -H "Authorization: Bearer $ADMIN"

# alice owns project 1; grant carol `editor` on it.
curl -s -X POST http://localhost:8080/share \
  -H "Authorization: Bearer $ALICE" -H 'Content-Type: application/json' \
  -d '{"resourceType":"project","resourceId":"1","granteeUserId":"4","projectRole":"editor"}'

# carol can now create an item in project 1's list — access she lacked a moment ago.
CAROL=$(curl -s http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"carol","password":"carol-pass"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["authzToken"])')

curl -s -X POST http://localhost:8080/items \
  -H "Authorization: Bearer $CAROL" -H 'Content-Type: application/json' \
  -d '{"listId":"1","title":"Filed via a fresh share"}'
```

A non-owner sharing is rejected with **403**; revoking the share
(`DELETE /share/{id}` as the owner) removes the access again.

## JWT signing

The app server applies the **identical** `initializeJwtSigning()` as the auth
server — the framework's bundled sample keypair — so a token the auth server
mints (HS256 + RSA-encrypted authorization payload) verifies here. It also sets
the same `globalSettingJwtOrganization = 'tom'` issuer. This is the standard
"resource server trusts the authorization server" split.

The bundled keypair is a development ("dummy") certificate on both servers, so
the framework emits its development-key warning on every sign and verify and
`warnIfDevelopmentSigningKey()` repeats it at boot — intentionally not
suppressed (G-AUTH-2). **Replace the keys with real ones — built into a
`TomJwtConfiguration` with `isDummy: false` — before any real deployment.**
