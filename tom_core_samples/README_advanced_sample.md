# Advanced Tom Core Full-Stack Sample — the whole secured system

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These sample projects are proprietary and internal (`publish_to: none`).

This is the **secured, full-stack successor** to the basic
[`core_server_sample`](core_server_sample/README.md) /
[`core_client_sample`](core_client_sample/README.md) pair. Where those teach one
server and one client in isolation, this suite is **two servers, two databases,
and two Flutter clients** wired together end-to-end: a JWT auth/admin server, a
secured task-manager app server, an end-user app, and an administrator console —
all sharing one reflected domain and one wire contract, with live four-state
field authorization and cross-user sharing.

> **Reading this map.** This document links the seven packages, draws the
> architecture, and gives the one quickstart that stands the whole system up.
> Every package ships its own article-grade `README.md` with the depth — nothing
> about a package's internals is re-documented here. The build narrative lives in
> the quest plan
> [`advanced_example_specification_plan.md`](../../../_ai/quests/tom_core/advanced_example_specification_plan.md).

---

## User guide

This suite map is the **index**. The long-form **Tom Core user guide** below uses
this sample as the worked example to teach how to build a full-scale, secured,
full-stack application on `tom_core` — its architecture *and* the implementation
rules the framework imposes (texts externalized into server-delivered resources;
UI authorization driven by scope/form/field names). Read the parts top to
bottom; each links to the next.

### Main spine

| Part | Document | Covers |
| --- | --- | --- |
| 00 | [Introduction & how to read this guide](README_advanced_00_introduction.md) | What the sample is and is *not*; who it is for; the seven packages at a glance; reading order; conventions. |
| 01 | [Full-stack architecture](README_advanced_01_architecture.md) | Two servers / two databases / two clients; layering; dependency arrows; the shared JWT key; the request + grant-propagation loop. |
| 02 | [Project layout, packages & build](README_advanced_02_project_layout_build.md) | The seven pubspecs and their wiring; `publish_to: none`; build order; reflection generation; running build_runner; local run. |
| 03 | [Domain model & reflection](README_advanced_03_domain_reflection.md) | The reflected `TomClass` entities; `@tomReflector`; the single reflection seed; enums; `resource_keys.dart` as the scope/form/field source of truth. |
| 04 | [Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) | The contracts package: DTOs, the typed service interfaces, the api registry, the domain↔wire boundary. |
| 05 | [Persistence & the two databases](README_advanced_05_persistence_database.md) | Persistence mapping; CRUD repositories; the two-database design; datasources config; the schema vs sample-data migration split. |
| 06 | [Authentication (JWT)](README_advanced_06_authentication.md) | Token issuance; password hashing; the bearer token and shared signing key; the client auth layer and token refresh. |
| 07 | [Authorization](README_advanced_07_authorization.md) | The four-state field authorization model; scope/form/field → `basePath` → grade; the installed adapter; implicit vs override paths; route gating. |
| 08 | [Resources & text externalization](README_advanced_08_resources_texts.md) | The no-hard-coded-labels rule; server-delivered resources; `<basePath>.<suffix>` keying; the scope/form/field JSON files; bundle bootstrap. |
| 09 | [Forms & UI](README_advanced_09_forms_ui.md) | `TomForm`/`TomField`; `basePath` derivation; bound reflected forms; scoped vs unscoped; the `tom_flutter_ui` components and screens. |
| 10 | [Servers & the secured endpoint pipeline](README_advanced_10_servers_endpoints.md) | The endpoint pipeline; per-endpoint access policies; bearer validation; ownership/share resolution; health; boot order. |
| 11 | [The two Flutter clients](README_advanced_11_clients_app_admin.md) | App client vs admin console; sessions; the in-memory vs live backend seam; bootstrap; the share flow and grant-matrix editor. |
| 12 | [Testing & cross-tier integration](README_advanced_12_testing_integration.md) | Test strategy; serial-Flutter rule; the sentinel render proof; the four-role matrix; the cross-tier runner; the green gate. |

### Appendices (deep dives)

| Part | Document | Covers |
| --- | --- | --- |
| A1 | [Four-state authorization deep dive](README_advanced_A1_authorization_state_machine.md) | The four states; resolution layers 1–4; the closed-safe default; the grant matrix → adapter → field path; the worked role matrix. |
| A2 | [Scope, `basePath` & resource-key conventions](README_advanced_A2_resource_scope_conventions.md) | `basePath` derivation; one-path-two-uses; the estimate mismatch; scoped vs unscoped; the JSON-tree ↔ scope mirroring. |
| A3 | [A secured request, end to end](README_advanced_A3_request_lifecycle.md) | One end-user request traced across both tiers, from login to graded field rendering. |
| A4 | [Implementation-rules cheat-sheet](README_advanced_A4_implementation_rules_checklist.md) | The consolidated, copy-pasteable rule list for building a new tom_core app, each with its enforcement anchor. |
| A5 | [Glossary & cross-reference](README_advanced_A5_glossary_crossref.md) | Term glossary; a map from each package README and planning doc to the guide section that summarizes it. |

---

## The seven packages

| # | Package | What it is | Runtime |
| --- | --- | --- | --- |
| 1 | [`advanced_todo_domain`](advanced_todo_domain/README.md) | The shared, reflected domain model (`User`, `Project`, `TodoList`, `TodoItem`, label/priority/state enums). Single source of truth for the whole stack. | library |
| 2 | [`advanced_todo_contracts`](advanced_todo_contracts/README.md) | The over-the-wire surface: DTOs plus the typed `AuthApiService` / `AdminApiService` / `AppApiService` interfaces, implemented by the servers and called by the client core. | library |
| 3 | [`advanced_client_core`](advanced_client_core/README.md) | Flutter-free `dart:io` authenticated HTTP layer shared by both Flutter clients — presents a bearer token, refreshes it, parses JSON↔DTO. Headless-testable (no sockets in tests). | library |
| 4 | [`advanced_auth_server`](advanced_auth_server/README.md) | JWT **authentication** issuer (`/auth/login\|refresh\|me\|logout`) + role-gated **administration** API (`/admin/users\|roles\|groups\|grants\|assignments`). The grant-mutating admin endpoints are a primary deliverable. | HTTP `:8081`, `auth_db` `:3307` |
| 5 | [`advanced_app_server`](advanced_app_server/README.md) | The secured task-manager API. Trusts the JWT signing key shared with the auth server, validates the bearer token on every request, resolves ownership + shares + four-state field grades, and persists `app_db`. | HTTP `:8080`, `app_db` `:3308` |
| 6 | [`advanced_app_client`](advanced_app_client/README.md) | The end-user Flutter app: login, a status-column task board, a bound item-detail editor with per-field four-state authorization driven live over the wire, and cross-user sharing. | Flutter |
| 7 | [`advanced_authadmin_client`](advanced_authadmin_client/README.md) | The administrator Flutter console: manages users, roles, groups, role assignments, and the `projectRole` × field grant matrix via the auth server's `/admin/*` API. | Flutter |

---

## Architecture

One reflected domain (`advanced_todo_domain`) flows into one wire contract
(`advanced_todo_contracts`); both servers implement the contract, both clients
call it through the shared `advanced_client_core`. The two servers share a JWT
signing key, so a token minted by the auth server verifies at the app server.

```
                         advanced_todo_domain
               (shared reflected entities — the model)
                                 │
                         advanced_todo_contracts
        (DTOs + AuthApiService / AdminApiService / AppApiService)
            ┌────────────────────┼─────────────────────┐
            │                    │                      │
   advanced_auth_server   advanced_client_core   advanced_app_server
   JWT issuer + /admin/*  ── authenticated   ──  secured task API
   HTTP :8081                HTTP layer            HTTP :8080
   auth_db  :3307           (Flutter-free)         app_db   :3308
        │   ▲                  ╱        ╲                  ▲   │
        │   │   advanced_authadmin_client    advanced_app_client│
        │   │   admin console (Flutter)      end-user app (Flutter)
        │   └────────── login + /admin/* ──────────┘           │
        │                                  login + board/share  │
        └──── shared JWT signing key: auth-minted token ────────┘
                       verifies at the app server
```

- The **admin console** logs in at the auth server and drives `/admin/*` to edit
  roles and the grant matrix.
- The **end-user app** logs in at the auth server, then calls the app server with
  the bearer token; the app server reads the grant matrix (sourced from the auth
  tier) and grades each field hidden / read-only / disabled / editable per
  request.
- An admin's grant edit reaches an end-user's field matrix on their next
  request; a project share reveals a project to a second user on theirs. That
  full loop is exactly what the cross-tier integration test asserts.

---

## Run the whole thing

**Requirements:** Docker (+ Compose v2) and the Dart/Flutter SDK on `PATH`. Host
ports **3307** / **3308** (databases) and **8080** / **8081** (servers) must be
free.

### 1 — Bring up both databases

Each server bundles its own MariaDB. The default ports differ (3307 vs 3308) so
both — and a host-local MariaDB — can run side by side without colliding.

```sh
# Auth database (auth_db) on host port 3307
cd tom_core_samples/advanced_auth_server
cp .env.example .env
docker compose up -d auth-db

# App database (app_db) on host port 3308
cd ../advanced_app_server
cp .env.example .env
docker compose up -d app-db
```

First boot seeds each schema from its `database_migrations/.../initdb` tree (the
auth server also seeds the demo accounts and the grant matrix).

### 2 — Start both servers

Start the auth server first (it mints tokens and owns the grant matrix), then the
app server (it verifies those tokens and reads grants). Each runs from its own
package root so relative migration/asset paths resolve.

```sh
# Auth server — from advanced_auth_server/
dart run bin/auth_server_start.dart      # HTTP :8081

# App server — from advanced_app_server/ (in a second shell)
dart run bin/app_server_start.dart       # HTTP :8080  (GET /health → 200)
```

### 3 — Run both clients

```sh
# End-user app — from advanced_app_client/
flutter run \
  --dart-define=AUTH_SERVER_URL=http://localhost:8081 \
  --dart-define=APP_SERVER_URL=http://localhost:8080

# Admin console — from advanced_authadmin_client/
flutter run \
  --dart-define=AUTH_SERVER_URL=http://localhost:8081
```

Both clients boot on a **seeded in-memory backend** when launched *without* the
`--dart-define`s — that is how the socket-free widget tests run. The defines
point them at the live servers above.

**Seeded live accounts** (sample only — never ship them):

| Username | Password | Global role | Seeded project access |
| --- | --- | --- | --- |
| `admin` | `admin-pass` | `admin` | manages roles + the grant matrix |
| `alice` | `alice-pass` | — | owns the starter workspace + project; can share |
| `bob` | `bob-pass` | — | editor on alice's project (seeded share) |
| `carol` | `carol-pass` | — | viewer on alice's project (seeded share) |

Sign into the **admin console** as `admin` to edit roles and the grant matrix;
sign into the **end-user app** as `alice` / `bob` / `carol` to see how each
principal's project access and four-state field grades follow the same ownership
+ share model the in-memory fake mirrors.

### One-command end-to-end check

To stand the entire stack up, run the scripted scenario, and tear it all down
again in a single command (fresh database volumes each run):

```sh
tom_core_samples/advanced_client_core/tool/run_cross_tier_integration.sh
```

It boots both databases and both servers, runs
`advanced_client_core/test/cross_tier_integration_test.dart` against them (admin
grant edit → end-user field matrix reflects it → a share reveals a project to a
second user), and tears the stack down on exit. A green run is a genuine
live-stack pass — the runner converts a server-unreachable skip into a failure.

---

## Documentation index

| Topic | Document |
| --- | --- |
| Basic samples map (the predecessor series) | [`README.md`](README.md) |
| Quest build narrative | [`advanced_example_specification_plan.md`](../../../_ai/quests/tom_core/advanced_example_specification_plan.md) |
| Server stack | [`../tom_core_server/README.md`](../tom_core_server/README.md) |
| Kernel (foundation) | [`../tom_core_kernel/README.md`](../tom_core_kernel/README.md) |
| Flutter integration | [`../tom_core_flutter/README.md`](../tom_core_flutter/README.md) |
| Endpoints module | [`../tom_core_server/doc/endpoints.md`](../tom_core_server/doc/endpoints.md) |

---

## Repository layout

```
tom_core_samples/
  README_advanced_sample.md      this map (the secured, full-stack suite)
  advanced_todo_domain/          shared reflected model (User, Project, TodoList, TodoItem)
  advanced_todo_contracts/       wire DTOs + typed service interfaces
  advanced_client_core/          Flutter-free authenticated HTTP client core (+ e2e runner)
  advanced_auth_server/          JWT auth issuer + /admin/* API        (HTTP 8081, auth_db 3307)
  advanced_app_server/           secured task-manager API              (HTTP 8080, app_db 3308)
  advanced_app_client/           end-user Flutter app (board + sharing + field grades)
  advanced_authadmin_client/     administrator Flutter console (users/roles/groups/grants)
```

## License

Proprietary and confidential. Each package carries the same proprietary
[`LICENSE`](../tom_core_kernel/LICENSE) as the rest of Tom Core; see any package
folder for the full text.
