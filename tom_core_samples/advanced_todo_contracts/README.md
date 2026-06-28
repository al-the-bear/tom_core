# advanced_todo_contracts

Shared wire contracts for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The single definition of the over-the-wire surface, depended on by both servers
(which implement it) and the shared client core (which calls it).

## Status

DTOs defined (step 4). The wire DTOs, their hand-written JSON mapping, and the
DTO test suite are implemented; the `@tomService` interfaces and the reflection
seed land in step 5, and the authorization-model contract is documented in
step 6.

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

## Planned (steps 5–6)

- `@tomService` endpoint interfaces: `AuthApiService`, `AdminApiService`,
  `AppApiService` — with `@TomEndpoint` + access annotations
  (`@TomPublicAccess`, `@TomAuthenticatedAccess`, `@TomRoleAccess(['admin'])`) —
  plus the reflection seed (`lib/src/reflection_entry.dart`).
- A written description of the two-layer authorization model (resource-level
  shares + four-state field grants) the servers implement against.
