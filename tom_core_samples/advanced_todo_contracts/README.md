# advanced_todo_contracts

Shared wire contracts for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The single definition of the over-the-wire surface, depended on by both servers
(which implement it) and the shared client core (which calls it).

## Status

Service interfaces + wire registry defined (step 5). On top of the step-4 DTOs,
the package now carries the typed service interfaces (`AuthApiService`,
`AdminApiService`, `AppApiService`) and the wire registry — each endpoint's URI,
HTTP method, request/response types, and four-state access policy. The
authorization-model contract is documented in step 6.

### Endpoint model: kernel `TomApi` registry, not server `@tomService`

The plan named the endpoint declarations "`@tomService` interfaces … with
`@TomEndpoint` + access annotations". Those annotations live in
**`tom_core_server`** (`@tomService`, `@TomEndpoint`), and this package depends
only on `tom_core_kernel` + the domain model so the **Flutter-free client core**
can consume it — pulling in `tom_core_server` would break that. The migrated
`tom_uam_codespec` hit the same constraint and resolves it with the kernel's
`TomApi`/`TomApiEndpoint`/`tomRemoteApis` model; this package follows that
precedent. So the wire surface is expressed as:

- **Typed interfaces** (`api_services.dart`) — the implementation seam the
  servers and the client core both implement (plain abstract classes).
- **A wire registry** (`api_registry.dart`) — `authApi`/`adminApi`/`appApi`
  (`TomApi` + `TomApiEndpoint<Return, Request>`) holding URI, method, and types,
  with the four-state access captured in companion `*ApiAccess` maps
  (`TomPublicAccess`/`TomAuthenticatedAccess`/`TomRoleAccess(['admin'])`).
  `registerAdvancedTodoApis()` registers all three with `tomRemoteApis`.

The server-side `@tomService` endpoint classes are re-declared against this
registry inside `tom_core_server` when the servers are built (steps 11+).

## Contents

The DTOs (`lib/src/`, re-exported from `advanced_todo_contracts.dart`) are plain
value records — not reflected entities. Each carries hand-written
`toJson`/`fromJson`, structural `==`/`hashCode`, and a **log-safe** `toString`
(passwords and bearer tokens are never rendered). The endpoints exchange them as
plain JSON maps (mirroring `core_server_sample`'s `Map<String, Object>`
surface); the client core maps them with pure functions. Decoders are
**closed-safe**: an unknown access token degrades to `TomAuthState.none` and an
unknown role to `ProjectRole.viewer`.

- **Auth/login** (`login_dtos.dart`): `LoginRequest`
  (`{username, password, app, org}`), `UserDto` (the password-free user
  projection, with a typed `statusValue`), and `LoginResult`
  (`{user, authToken, authzToken, expiresAt}`).
- **Authorization** (`graded_field_dto.dart`, `grant_matrix_dto.dart`):
  `GradedFieldDto` (`{resourceKey, access}`) and `GrantMatrixDto` — the full
  `role → {resourceKey: TomAuthState}` matrix the admin grant editor reads and
  writes, immutable with copy-on-edit `withAccess` and order-independent
  equality.
- **Sharing** (`share_request.dart`): `ShareRequest`
  (`{resourceType, resourceId, granteeUserId, projectRole}`).
- **Admin CRUD** (`admin_dtos.dart`): `CreateUserRequest`, `RoleDto`,
  `GroupDto` (with an unmodifiable member list), and `AssignmentRequest`.

## The service surface

- **Auth** (`AuthApiService` / `authApi`, `/auth/*`): `login` (public) +
  `refresh`/`logout`/`me` (authenticated).
- **Admin** (`AdminApiService` / `adminApi`, `/admin/*`): user, role, group,
  grant-matrix and assignment management — every endpoint `@TomRoleAccess(['admin'])`.
- **App** (`AppApiService` / `appApi`, the todo board): `health` (public) +
  workspaces, projects, lists, items, comments, field-state and sharing
  endpoints (authenticated; resource- and field-level checks are enforced inside
  the handlers, not by these blanket levels).

The reflection seed (`lib/src/reflection_entry.dart`) stays a stub: nothing in
the contracts package is `@tomReflector` (the DTOs are plain value records and
the service interfaces are plain abstract classes).

## Planned (step 6)

- A written description of the two-layer authorization model (resource-level
  shares + four-state field grants) the servers implement against.
