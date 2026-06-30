# Wire contracts & DTOs

*Part 04 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[`advanced_todo_contracts`](advanced_todo_contracts/README.md) is the **single
definition of the over-the-wire surface** — defined once, *implemented* by both
servers and *called* by the shared client core, so a server can never drift from
a client. This part covers the package's three pillars (DTOs, the typed service
interfaces, the wire registry), the specialised grading/grant/resource/login
DTOs, and the **domain↔wire boundary**: which payloads cross the wire as reflected
domain entities and which cross as hand-mapped plain DTOs.

## The contracts package at a glance

The package depends only on `tom_core_kernel` + `advanced_todo_domain`, so it
stays consumable by the Flutter-free client core. Its barrel re-exports three
files, which are the three pillars:

| Pillar | File | What it is |
| --- | --- | --- |
| **DTOs** | `src/dtos.dart` (+ the specialised DTO files) | Plain value records with hand-written JSON mapping. |
| **Service interfaces** | `src/api_services.dart` | `AuthApiService` / `AdminApiService` / `AppApiService` — the implementation seam servers implement and the client core calls. |
| **Wire registry** | `src/api_registry.dart` | Each endpoint's URI, HTTP method, request/response types, and per-endpoint access policy; `registerAdvancedTodoApis()`. |

Importing the barrel gives both tiers the same, single definition of the wire
surface.

## `TomJsonSerializable` DTOs

The DTOs are **plain value records, not reflected entities** (the contracts
reflection seed is a deliberate stub — nothing here is `@tomReflector`). Each DTO
carries:

- hand-written `toJson` / `fromJson`,
- structural `==` / `hashCode`,
- a log-safe `toString`.

The endpoints exchange plain JSON maps, mirroring `core_server_sample`'s
`Map<String, Object>` surface, and the client core maps them with **pure
functions**. Decoders are **closed-safe**: an absent or unrecognised value
degrades to a safe default rather than throwing (e.g. `GradedFieldDto.fromJson`
degrades an unknown access token to `TomAuthState.none` — hidden/denied).

Two DTOs additionally **implement `TomJsonSerializable`** — `GrantMatrixDto` and
`ResourceBundleDto`. They do so because the server endpoint pipeline would
otherwise serialize a single-object result through the *reflection* serializer,
which drops their `final` field; implementing `TomJsonSerializable` routes the
result through the DTO's own `toJson` instead.

## The typed service interfaces

`api_services.dart` declares three plain abstract classes — the seam where
servers and client core meet:

- **`AuthApiService`** — the authentication surface: `login`, `loginResources`,
  `refresh`, `logout`, `me`.
- **`AdminApiService`** — the administration surface (the headline mutating
  deliverable): CRUD over users / roles / groups, `getGrants` / `putGrants` (the
  grant matrix), `assign`, and `resources`.
- **`AppApiService`** — the secured task surface: `health`, list/create over
  workspaces / projects / lists / items, `updateItem` / `deleteItem`,
  `addComment`, **`itemFieldStates`** (the per-field grades), `share` /
  `revokeShare`, and `resources`.

Because both ends compile against these interfaces, the request/response types
are agreed by construction. The servers implement them (part
[10](README_advanced_10_servers_endpoints.md)); the client core calls them (part
[11](README_advanced_11_clients_app_admin.md)).

## The api registry

`api_registry.dart` is the **wire metadata** that turns those interfaces into
addressable HTTP. It follows the kernel `TomApi` / `TomApiEndpoint` model (not
server `@tomService`): `authApi` / `adminApi` / `appApi` each hold the
endpoints' URIs, HTTP methods, and request/response types, and
`registerAdvancedTodoApis()` registers them.

Crucially, **the per-endpoint four-state access policy lives here too**, in
companion `*ApiAccess` maps keyed by endpoint id (because `TomApiEndpoint` has no
access field). The values are the kernel `TomAccessControl` types:

- `authLogin` / `authLoginResources` → `TomPublicAccess()` (reachable
  unauthenticated — you must be able to log in and fetch login texts before you
  have a token);
- every other auth/app endpoint → `TomAuthenticatedAccess()`;
- **every `/admin/*` endpoint → `TomRoleAccess(['admin'])`** — the single
  `_adminOnly` policy gating the whole admin axis.

This is **layer-1 (resource-level) access** — the route gate. The finer
**field-level** grading is a separate layer (part
[07](README_advanced_07_authorization.md)).

## Graded, grant, resource-bundle & login DTOs

The specialised DTOs carry the sample's two new concerns — field grading and the
grant matrix — plus resources and login:

| DTO | Endpoint | Purpose |
| --- | --- | --- |
| `GradedFieldDto` | `GET /items/{id}/field-states` | One `resourceKey` + its resolved `TomAuthState`. The app server projects a principal's per-field grade into a list of these; both clients render `access` onto field visibility/interactivity. Carries only the kernel `TomAuthState`, so the contract stays dependency-clean — the resolver itself never crosses the wire. |
| `GrantMatrixDto` | `GET/PUT /admin/grants` | The full `(role, resourceKey) → TomAuthState` grid the authadmin editor reads and writes. Held as a deep-unmodifiable copy; edits produce a new instance via `withAccess`; `accessFor` is closed-safe. The auth server materialises a PUT into `TomResourceGrant` rows. |
| `ResourceBundleDto` | the `resources` / `loginResources` endpoints | A bundle of server-delivered UI texts keyed by `<basePath>.<suffix>` (`todo.item.title.label`, `login.username.hint`, …) — exactly the shape `TomTextResourceProvider.from` accepts. The keys agree with the form fields' `basePath`s because both follow the one domain scope/form/field convention. Part [08](README_advanced_08_resources_texts.md). |
| `LoginRequest` / `LoginResult` / `UserDto` | `POST /auth/login`, `refresh`, `me` | `LoginResult` carries the `UserDto`, the `authToken` + `authzToken`, and `expiresAt`. The bearer story is part [06](README_advanced_06_authentication.md). |
| `RoleDto` / `GroupDto` / `CreateUserRequest` / `AssignmentRequest` | `/admin/*` | The admin CRUD payloads. |

## The domain↔wire boundary

The boundary is drawn by a single question — **is the payload a reflected domain
entity, or not?**

- **Domain entities cross the wire directly.** `AppApiService` returns and
  accepts the reflected `advanced_todo_domain` entities themselves —
  `List<TodoItem>`, `Project`, `Workspace`, `TodoList`, `TodoComment`. These
  serialize through the kernel **reflection** serializer (the same reflection
  that persists and binds them, part [03](README_advanced_03_domain_reflection.md)),
  so the model is defined once and reused as the wire payload.
- **Everything else is a hand-mapped DTO.** Authentication, administration,
  grading, the grant matrix, and resource bundles are *not* domain entities, so
  they are plain value records in this package with hand-written `toJson` /
  `fromJson`. They deliberately do **not** reflect — keeping the contracts
  package dependency-clean and the client core Flutter-free.

> **Boundary note (deviation from the skeleton).** This part's skeleton
> anticipated a "drafts are client-local plain records folded by hand" section.
> The implemented sample has **no draft DTO**: edit-in-progress state is not a
> wire concept — the clients bind a `TomForm` directly to a domain entity and
> `save` writes it back (part [09](README_advanced_09_forms_ui.md)). The real
> boundary is the reflected-entity-vs-hand-mapped-DTO split above, which is what
> this section documents. Recorded as decision D-RC7-c.

## Primary sources

- [`advanced_todo_contracts/README.md`](advanced_todo_contracts/README.md) — the endpoint model, the service surface, and the authorization model.
- `advanced_todo_contracts/lib/src/` — `api_services.dart`, `api_registry.dart`, `dtos.dart`, `graded_field_dto.dart`, `grant_matrix_dto.dart`, `resource_bundle_dto.dart`, `login_dtos.dart`, `admin_dtos.dart`, `share_request.dart`.
- `advanced_example_specification_plan.md` — A.6 (services), Phase 1.

---

← Prev: [03 · Domain model & reflection](README_advanced_03_domain_reflection.md) · Next: [05 · Persistence & the two databases](README_advanced_05_persistence_database.md) →
