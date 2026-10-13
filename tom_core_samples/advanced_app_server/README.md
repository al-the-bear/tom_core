# advanced_app_server

App server for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

A secured task-manager API on `tom_core_server`. It trusts the JWT signing key
of `advanced_auth_server` through its public half, validates the bearer token on
every request,
resolves the principal's resource access (ownership + shares) and four-state
field grades, persists the `app_db`, and lets an owner share a resource with
another user so the grant takes effect on the grantee's next request.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[05 · Persistence & the two databases](../README_advanced_05_persistence_database.md)** and
> [10 · Servers & the secured endpoint pipeline](../README_advanced_10_servers_endpoints.md).

**There is no `example/` directory, and that is deliberate: this package is
itself the runnable example.** It is one of the nine `advanced_*` packages that
together form the full-stack sample, so `dart run bin/app_server_start.dart` —
the secured board API — is the demonstration, and an `example/` beside it would
duplicate the entry point.
[The family's index](../README_advanced_sample.md#the-nine-packages) says which of the nine carry an `example/`, and why.

Read instead, in the order a newcomer wants them: [Running it](#running-it)
for the boot and its two databases, the [`curl` tour](#curl-tour) for the
endpoints exercised one at a time against a live server, and
[`advanced_client_core/tool/run_cross_tier_integration.sh`](../advanced_client_core/tool/run_cross_tier_integration.sh)
for the whole stack end to end — it boots both databases and both servers, runs
the live suites against them and tears everything down, which is the one path
that shows this server doing its job with a real client on the other side.

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

## API

The barrel `lib/advanced_app_server.dart` is the package's stable entry point
and exports ten libraries. Each store seam named below is an **extension
point**: the services are written against it, the production wiring binds a
repository-backed implementation, and the unit tests bind a seeded in-memory
one.

| Exported library | What it is | Seam it defines |
| --- | --- | --- |
| `src/endpoints/app_endpoints.dart` | The HTTP surface — the board's read, write and share endpoints, split into database-free services plus the `@tomComponent` adapter the router binds | `AppReadStore`, `AppWriteStore` |
| `src/access/resource_role_resolver.dart` | Ownership-or-share → the principal's effective `ProjectRole` on a resource, kept strongest along the `item → list → project → workspace` chain | `ResourceContainmentStore` |
| `src/access/field_grade_resolver.dart` | `ProjectRole` → the per-field `TomAuthState` grades a write is enforced against | `GrantStore` |
| `src/access/column_grade_resolver.dart` | The same two layers for an authorized *column* — the item's `attachment`, which the file endpoint gates on rather than a JSON field | — |
| `src/access/visible_resource_resolver.dart` | A principal's visible id-set per entity type, the input the async data-scope resolver pushes down to the database | — |
| `src/access/share_delegation_store.dart` | Cross-user shares as framework C-6 `share`-mode delegations — one principal lending another a named role on a named resource | `ShareDelegationStore` |
| `src/access/ownership_grant_writer.dart` | Records C-5 ownership when a principal creates a resource, into the grant table shared with `auth_db` | `OwnershipGrantWriter` |
| `src/persistence/app_persistence_model.dart` | The `app_db` records — the relational view of workspaces, projects, lists, items, comments and subtasks | — |
| `src/persistence/app_mapping.dart` | The one place the domain entities and the persistence records meet, in pure conversions both ways | — |
| `src/resources/app_resource_bundles.dart` | The server-delivered text bundle the client's post-login screens render their labels from | — |

`test/readme_api_section_test.dart` derives both sides of that first column —
the barrel's exports and this table's rows — and fails when they disagree, so
the list cannot drift from the barrel the way a hand-written mirror would.

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

<!-- account-roster: auth-db -->

| Username | Password | Note |
| --- | --- | --- |
| `admin` | `admin-pass` | global `admin` |
| `alice` | `alice-pass` | owns workspace 1 |
| `bob` | `bob-pass` | shared `editor` on project 1 |
| `carol` | `carol-pass` | shared `viewer` on project 1 |
| `dave` | `dave-pass` | no project access; enrolled in TOTP, so his login is challenged for a second factor |
| `erin` | `erin-pass` | no project access; holds no factor, so her login is offered enrolment |

<!-- /account-roster -->

## Endpoints

`POST` / `PUT` bodies are JSON; `Authorization: Bearer <authzToken>` carries the
auth server login's `authzToken`. All but `/status` (and the framework's
`/health` liveness probe and `/openapi.json` document) require an authenticated
principal; resource
ownership/share and per-field grade are enforced inside the handlers.

| Method & path | Access | Purpose |
| --- | --- | --- |
| `GET /status` | public | Typed JSON status (`{status, service}`) |
| `GET /health` | public | Framework plain-text liveness probe (`OK`) — auto-mounted |
| `GET /openapi.json` | public | The server's OpenAPI 3.1 document — framework-mounted; see [OpenAPI document](#openapi-document) |
| `GET /workspaces` · `POST /workspaces` | authenticated | List (owner-scoped) / create a workspace |
| `PUT /workspaces` · `DELETE /workspaces/{id}` | authenticated | Update / delete a workspace (owner-scoped at the database) |
| `GET /projects` · `POST /projects` | authenticated | List / create a project (workspace owner/editor) |
| `GET /lists` | authenticated | Lists the caller can reach |
| `GET /items` · `POST /items` | authenticated | List / create items (create: editor+, field-graded) |
| `PUT /items` · `DELETE /items/{id}` | authenticated | Update (field-graded) / delete (editor+) an item |
| `GET /attachments` | authenticated | Attachment descriptors for the visible items of a list |
| `GET /items/{id}/comments` · `POST /items/{id}/comments` | authenticated | Read / add a comment on an item (add: commenter+) |
| `GET /items/{id}/subtasks` · `POST /items/{id}/subtasks` | authenticated | Read / add a checklist step (add: editor+) |
| `PUT /subtasks` | authenticated | Update a checklist step (editor+) |
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
the endpoints visible — and states the document's title (`Advanced App Server`),
description and server URL (`http://localhost:8080`), so the commands need no
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
carries the `AppApi` client generated from it, depending on `package:http`
alone.

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

The app server calls the **same** `installJwtSigning(configuration)` as the auth
server, reading the `jwt*` configuration fields. Configured for a deployment, it
is **verify-only**:

| Variable | Here |
| --- | --- |
| `JWT_VERIFICATION_KEY_FILES` | the auth server's **public** key (comma-separated, to keep a retired key through a rotation) |
| `JWT_SIGNING_KEY_FILE` | unset — this server issues no tokens, and refuses to |
| `JWT_ISSUER` / `JWT_AUDIENCE` | the auth server's values; a token naming others is rejected |
| `JWT_ALGORITHM` | the auth server's — `RS256` by default |
| `JWT_RSA_PRIV_KEY` / `JWT_RSA_PUB_KEY` | the pair the auth server encrypts the access-control payload with, which this server decrypts |
| `JWT_SHARED_SECRET_KEY` | read only with `JWT_ALGORITHM=HS256`, when both servers hold the same secret instead of key files |

A token the auth server mints (RS256, its `kid` naming the auth server's key,
the authorization payload RSA-encrypted) verifies here without a call back and
without this server holding anything that could mint one. This is the standard
"resource server trusts the authorization server" split.

Neither sample sets any of them, so both fall back to the framework's bundled
sample RSA pair — which is the *only* reason the two servers currently agree.
Point the auth server's `JWT_SIGNING_KEY_FILE` at a private key and this
server's `JWT_VERIFICATION_KEY_FILES` at its public half (see `.env.example`)
and the agreement becomes a deliberate one; give this server another key, or
another issuer or audience, and it rejects the auth server's tokens with
`invalid token`.

The fallback is not quiet. `installJwtSigning` **refuses to boot** on it outside
a development or test environment (`TomSigningKeyException`, naming the
unconfigured fields), which is why the sample is started with `env=dev`; where it
is permitted it warns once at boot, and because the resulting
`TomJwtConfiguration` stays marked as a development ("dummy") certificate the
framework repeats the warning on **every** sign and verify — intentionally not
suppressed (G-AUTH-2). Configure the key material and the certificate is no
longer a dummy one and the warnings stop. **Do that before any real
deployment.**
