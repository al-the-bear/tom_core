# Wire contracts & DTOs

*Part 04 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[`advanced_todo_contracts`](advanced_todo_contracts/README.md) is the **single
definition of the over-the-wire surface** — defined once, *implemented* by both
servers and *called* by the shared client core, so a server can never drift from
a client. This part covers the package's three pillars (DTOs, the typed service
interfaces, the wire registry), the specialised grading/grant/resource/login
DTOs, and the **domain↔wire boundary**: which payloads cross the wire as the
reflected domain entities themselves and which cross as reflection-first
wire-projection DTOs — both serialized by the **same** kernel reflection path.

## The contracts package at a glance

The package depends only on `tom_core_kernel` + `advanced_todo_domain`, so it
stays consumable by the Flutter-free client core. Its barrel re-exports three
files, which are the three pillars:

| Pillar | File | What it is |
| --- | --- | --- |
| **DTOs** | `src/dtos.dart` (+ the specialised DTO files) | Reflection-first `@tomReflector` classes — plain non-`final` fields, no hand-written serializer. |
| **Service interfaces** | `src/api_services.dart` | `AuthApiService` / `AdminApiService` / `AppApiService` — the implementation seam servers implement and the client core calls. |
| **Wire registry** | `src/api_registry.dart` | Each endpoint's URI, HTTP method, request/response types, and per-endpoint access policy; `registerAdvancedTodoApis()`. |

Importing the barrel gives both tiers the same, single definition of the wire
surface.

## Reflection-first DTOs

Every wire DTO is **reflection-first** (G-DTO-1): a `@tomReflector` class with
**plain non-`final` fields** (G-DTO-2) and **no hand-written `toJson`/`fromJson`**
(G-DTO-3). The framework serializes them through the **kernel reflection path**
— `TomReflectionInfo.getValues` on the way out, `createInstanceFromJson` on the
way in — *exactly the same* mechanism that serializes, persists and binds the
reflected `advanced_todo_domain` entities (part
[03](README_advanced_03_domain_reflection.md)). The only hand-written member a
DTO carries is a **log-safe `toString`** that never renders a password or bearer
token.

The reflection path is driven from two sides:

- **On a server**, the endpoint pipeline drives reflection directly — a handler
  returns a DTO (or a `List<DTO>`) and the pipeline serializes it, and decodes an
  incoming request DTO the same way.
- **Off a server** — the Flutter-free client core and the contract round-trip
  tests — consumers go through three one-line helpers in `dto_reflection.dart`
  that centralise the `ClassMirror` wiring: `dtoFromJson<T>(map)`,
  `dtoToMap(dto)`, `dtoToJsonString(dto)`. All require the DTO reflection seed to
  have been installed (`initializeReflection()`).

**Enum-valued fields travel as their `.name` token** in a plain `String` (or a
nested `Map`), because a Dart enum cannot cross the wire natively. Each such DTO
exposes a **typed accessor** beside the token field, and the accessor is
**closed-safe** — an absent or unrecognised token resolves to the
least-privileged value rather than throwing: `GradedFieldDto.access` (the
four-state grade) resolves via `accessState` to `TomAuthState.none`
(hidden/denied); `ShareRequest.projectRole` resolves via `projectRoleValue` to
`ProjectRole.viewer`; `UserDto.status` resolves via `statusValue`. The grade key
and the field's `basePath` agree by the one scope/form/field convention (part
[08](README_advanced_08_resources_texts.md)), so no key-translation layer exists.

Two DTOs carry a **single nested-map field** rather than scalar fields —
`GrantMatrixDto.matrix` (`{role: {resourceKey: token}}`) and
`ResourceBundleDto.texts` (`{basePath.suffix: value}`), both typed
`Map<String, Object?>`. Reflection round-trips each as a plain nested/flat map
(`{matrix: {…}}`, `{texts: {…}}`); the typed helpers
(`accessFor`/`withAccess`/`fromGrades`, `flattenResourceTree`) convert tokens ↔
enums around it. There is **no `TomJsonSerializable` implementation anywhere** —
because the fields are non-`final`, the reflection serializer round-trips them
directly, so no manual escape hatch is needed (G-DTO-4).

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
  `addComment`, **`resourceRoles`** (`GET /resource-roles → Map<String,String>`,
  the principal's flat `resourceKey → roleName` map the client grades fields
  from), `share` / `revokeShare`, and `resources`.

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

Crucially, **the per-endpoint four-state access policy lives here too**,
declared directly on each endpoint's `TomApiEndpoint.access` value (G-API-3 —
the endpoint carries an `access` field; there is no companion map). The values
are the kernel `TomAccessControl` types:

- the six pre-session `/auth/*` endpoints — `authLogin`, `authSecondFactor`,
  `authBeginEnrolment`, `authConfirmEnrolment`, `authSkipEnrolment` and
  `authLoginResources` — plus `appHealth` → `TomPublicAccess()` (reachable
  unauthenticated: you must be able to log in, complete a pending second factor,
  enrol or decline an offered one, and fetch login texts before you have a
  usable token — and a health probe answers before any principal exists);
- every other auth/app endpoint → `TomAuthenticatedAccess()`;
- **every `/admin/*` endpoint → the shared `adminAccess`
  (`TomRoleAccess(['admin'])`) constant** — the single policy gating the whole
  admin axis.

This is **layer-1 (resource-level) access** — the route gate. The finer
**field-level** grading is a separate layer (part
[07](README_advanced_07_authorization.md)).

## Graded, grant, resource-bundle & login DTOs

The specialised DTOs carry the sample's two new concerns — field grading and the
grant matrix — plus resources and login:

| DTO | Endpoint | Purpose |
| --- | --- | --- |
| `GradedFieldDto` | `GET /admin/grants` (via `GrantMatrixDto`) | One `resourceKey` + its `access` (`TomAuthState.name` token). It is the per-cell grade of the admin grant matrix `GrantMatrixDto` (`GrantMatrixDto.gradesFor(role)`), served by the auth server's `/admin/grants` path and rendered in the admin console's grant editor. Carries only the kernel `TomAuthState`, so the contract stays dependency-clean. It **no longer travels on any app read** — the app client grades fields locally from the `resourceRoles` map. |
| `GrantMatrixDto` | `GET/PUT /admin/grants` | The full `(role, resourceKey) → TomAuthState` grid the authadmin editor reads and writes. Held in one reflected `matrix` field as `{role: {resourceKey: token}}`; edits produce a new instance via `withAccess`; `accessFor` is closed-safe. The auth server materialises a PUT into `TomResourceGrant` rows. |
| `ResourceBundleDto` | the `resources` / `loginResources` endpoints | A bundle of server-delivered UI texts keyed by `<basePath>.<suffix>` (`todo.item.title.label`, `login.username.hint`, …) — exactly the shape `TomTextResourceProvider.from` accepts. The keys agree with the form fields' `basePath`s because both follow the one domain scope/form/field convention. Part [08](README_advanced_08_resources_texts.md). |
| `LoginRequest` / `LoginResult` / `UserDto` | `POST /auth/login`, `refresh`, `me` | `LoginResult` carries the `UserDto`, the `authToken` + `authzToken`, and `expiresAt`. It also carries `requires2FA` + `twoFactorType` — deliberately *only* the flag: the challenge's hint, attempt counter and expiry live in the interim token's claims and are read via `TomBearerAuthentication.pendingTwoFactorChallenge`, so no client mirrors challenge state. The bearer story is part [06](README_advanced_06_authentication.md). |
| `SecondFactorRequest` | `POST /auth/second-factor` | The `code` the user submitted plus the pending login's `challengeToken`. The token is echoed **in the body**, not as a bearer, because the interim principal is by construction not authenticated — see part [06](README_advanced_06_authentication.md#two-factor-login-the-second-pass). |
| `RoleDto` / `GroupDto` / `CreateUserRequest` / `AssignmentRequest` | `/admin/*` | The admin CRUD payloads. |

## The domain↔wire boundary

Both sides of the boundary serialize through the **same** kernel reflection path,
so the boundary is **not** about *how* a payload is serialized. It is about *what
a shape represents* — **a persisted domain entity, or a wire-only projection?**

- **Domain entities cross the wire directly.** `AppApiService` returns and
  accepts the reflected `advanced_todo_domain` entities themselves —
  `List<TodoItem>`, `Project`, `Workspace`, `TodoList`, `TodoComment`. The model
  is defined once (part [03](README_advanced_03_domain_reflection.md)) and reused
  verbatim as the wire payload; the same reflection that persists and binds it
  serializes it.
- **Wire-only projections are DTOs — equally reflection-first.** Authentication,
  administration, grading, the grant matrix, and resource bundles are *not*
  domain entities: they exist only on the wire, so they live as their own
  `@tomReflector` DTOs in this package (a password-free `UserDto` view, a
  `GradedFieldDto` grade, the `GrantMatrixDto` grid, …). They serialize through
  the identical reflection path as the entities — no hand-mapping, no
  `TomJsonSerializable`. Carrying only kernel/token types keeps the contracts
  package dependency-clean and the client core Flutter-free.

> **No draft DTO.** Edit-in-progress state is **not a wire concept** in this
> sample: a client binds a `TomForm` directly to a domain entity and `save`
> writes it back (part [09](README_advanced_09_forms_ui.md)), so there is no
> client-local "draft" payload to serialize. The only boundary is the
> entity-vs-wire-projection split above.

## Primary sources

- [`advanced_todo_contracts/README.md`](advanced_todo_contracts/README.md) — the endpoint model, the service surface, and the authorization model.
- `advanced_todo_contracts/lib/src/` — `api_services.dart`, `api_registry.dart`, `dtos.dart`, `dto_reflection.dart` (`dtoFromJson`/`dtoToMap`/`dtoToJsonString`), `graded_field_dto.dart`, `grant_matrix_dto.dart`, `resource_bundle_dto.dart`, `login_dtos.dart`, `admin_dtos.dart`, `entity_id_request.dart`, `share_request.dart`.

---

← Prev: [03 · Domain model & reflection](README_advanced_03_domain_reflection.md) · Next: [05 · Persistence & the two databases](README_advanced_05_persistence_database.md) →
