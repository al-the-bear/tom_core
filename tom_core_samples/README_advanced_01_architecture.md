# Full-stack architecture

*Part 01 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

This part draws the shape of the system: **two servers, two databases, two
clients**, all agreeing on **one reflected domain** and **one wire contract**. It
shows which package depends on which (and which way the arrows point), why the
two servers can trust each other through a **shared JWT signing key**, and how an
administrator's edit travels all the way to an end-user's screen — the
**grant-propagation loop** the integration test asserts live.

## The shape: two servers, two databases, two clients

The system is split along two seams at once — an **authority seam** (who you are
and what you may do) and an **application seam** (the task data itself) — and each
side of the authority seam gets its own server, database, and Flutter client.

| Node | Role | Runtime |
| --- | --- | --- |
| [`advanced_auth_server`](advanced_auth_server/README.md) | Mints JWTs (`/auth/login\|refresh\|me\|logout`) and owns the **grant matrix** through a role-gated admin API (`/admin/users\|roles\|groups\|grants\|assignments`). | HTTP `:8081`, `auth_db` `:3307` |
| [`advanced_app_server`](advanced_app_server/README.md) | The secured task API. Validates the bearer on every request, resolves ownership + shares + four-state field grades, persists tasks. | HTTP `:8080`, `app_db` `:3308` |
| [`advanced_authadmin_client`](advanced_authadmin_client/README.md) | Administrator console: users, roles, groups, assignments, and the `projectRole` × field grant matrix. | Flutter |
| [`advanced_app_client`](advanced_app_client/README.md) | End-user app: login, a status-column board, a bound item editor with live per-field authorization, and cross-user sharing. | Flutter |

The two databases run on **distinct host ports (3307 vs 3308)** deliberately, so
both servers — and a host-local MariaDB — can run side by side without colliding.
The split is not just operational tidiness: it makes the authority store and the
application store independently ownable, which is exactly the boundary a real
deployment would draw.

## Layering and dependency arrows

Three library packages sit beneath the four runtimes, and every dependency arrow
points **from a higher-level package down to a lower-level one** — runtimes
depend on contracts, contracts depend on the domain, and nothing lower ever
imports something higher. That is the rule from the architecture guidelines made
literal: *core types don't import from transports; transports import from core.*

```
                       advanced_todo_domain
             (shared reflected entities — the model)
                                │
                      advanced_todo_contracts
        (DTOs + AuthApiService / AdminApiService / AppApiService)
                                │
                      advanced_client_core
              (Flutter-free authenticated HTTP layer)
        ┌───────────────┬───────────────┬───────────────┐
        │               │               │               │
 advanced_auth_  advanced_app_   advanced_app_   advanced_authadmin_
   server          server          client            client
 (depends on     (depends on     (depends on      (depends on
  contracts +     contracts +     client_core +    client_core +
  domain)         domain)         contracts)       contracts)
```

Read top-to-bottom, the layers are:

1. **`advanced_todo_domain`** — the reflected entities (`@tomReflector`). The
   single source of truth the whole stack agrees on. Depends only on
   `tom_core_kernel` + `tom_reflection`.
2. **`advanced_todo_contracts`** — the over-the-wire surface: the DTOs and the
   typed service interfaces (`AuthApiService`, `AdminApiService`, `AppApiService`)
   the servers implement and the clients call. Depends on the domain.
3. **`advanced_client_core`** — the Flutter-free authenticated HTTP layer shared
   by both clients: it presents and refreshes the bearer token and maps JSON↔DTO.
   Depends on the contracts. Being Flutter-free is what makes it headless-testable.
4. **The two servers** depend on the contracts + domain (plus `tom_core_server`);
   **the two clients** depend on `advanced_client_core` + the contracts (plus
   `tom_flutter_ui` / `tom_core_flutter` for the UI).

The pay-off of this layering is that **the wire contract is defined exactly once**
and consumed from both ends: a server cannot drift from a client, because both
compile against the same `advanced_todo_contracts` interfaces and the same
`advanced_todo_domain` entities. Part [04](README_advanced_04_wire_contracts_dtos.md)
covers the contract surface; part [03](README_advanced_03_domain_reflection.md)
covers the reflected domain beneath it; part
[02](README_advanced_02_project_layout_build.md) shows the pubspec wiring and
build order that realise these arrows.

## The shared JWT signing key

The two servers never call each other. They cooperate through a **shared JWT
signing key** instead: the auth server mints a token signed with that key, and
the app server verifies the bearer it receives against the *same* key. So a token
minted at `:8081` is trusted at `:8080` without a back-channel — the signature is
the proof.

This is the spine of the authentication story (part
[06](README_advanced_06_authentication.md)): the auth server is the only issuer,
the app server is a pure verifier, and the shared key is the single fact that
binds the two tiers. The grant matrix the app server reads per request is
likewise *sourced from the auth tier* — the app server consumes authority, it
never defines it.

## The end-to-end request + grant-propagation loop

Putting the pieces in motion, the headline scenario is a single loop that crosses
**both** tiers:

1. An **administrator** signs into the admin console and edits the grant matrix
   via `/admin/*` on the auth server — for example, raising a `projectRole`'s
   grade on a field from read-only to editable.
2. An **end-user** (say `alice`) makes their next request to the app server with
   their bearer token. The app server reads the grant matrix (sourced from the
   auth tier) and grades each field **hidden / read-only / disabled / editable**
   for that principal — so the admin's edit is now visible in alice's item editor.
3. An owner **shares** a project; on a *second* user's next request the app server
   resolves the new share and reveals the project on their board.

That admin-edit → field-matrix → share → second-user-sees-it loop is exactly what
the cross-tier integration test asserts live (part
[12](README_advanced_12_testing_integration.md)). The four seeded accounts exist
to exercise it: `admin` (manages roles + grants), `alice` (owns the starter
project, can share), and `bob` / `carol` (an editor and a viewer on alice's
project via seeded shares). The full per-request trace — bearer validation,
principal resolution, ownership + share + grade lookup — is followed end-to-end in
appendix [A3](README_advanced_A3_request_lifecycle.md).

## Architecture diagram

The hub's diagram shows the same system as a wiring diagram rather than a
dependency stack — the two clients on the outside, the two servers in the middle,
and the shared signing key closing the loop underneath:

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
  the bearer token; the app server reads the grant matrix and grades each field
  per request.
- An admin's grant edit reaches an end-user's field matrix on their next request;
  a project share reveals a project to a second user on theirs — the loop the
  cross-tier test asserts.

## Primary sources

- [`README_advanced_sample.md`](README_advanced_sample.md) — Architecture section + diagram, the suite map, and the quickstart.
- The seven package READMEs, for per-node detail.

---

← Prev: [00 · Introduction](README_advanced_00_introduction.md) · Next: [02 · Project layout, packages & build](README_advanced_02_project_layout_build.md) →
