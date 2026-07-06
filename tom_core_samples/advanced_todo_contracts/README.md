# advanced_todo_contracts

Shared wire contracts for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The single definition of the over-the-wire surface, depended on by both servers
(which implement it) and the shared client core (which calls it).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[04 · Wire contracts & DTOs](../README_advanced_04_wire_contracts_dtos.md)**.

## Status

Contract complete (step 6). The package carries the step-4 DTOs, the step-5
typed service interfaces (`AuthApiService`, `AdminApiService`, `AppApiService`)
and the wire registry (each endpoint's URI, HTTP method, request/response types,
and four-state access policy), and the [authorization model](#authorization-model)
the servers implement against is documented below. This completes Phase 1 of the
plan; the auth server, app server and clients (Phases 2–4) implement against
this written contract.

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
  with the four-state access declared directly on each endpoint's
  `TomApiEndpoint.access`
  (`TomPublicAccess`/`TomAuthenticatedAccess`/`TomRoleAccess(['admin'])`,
  G-API-3). `registerAdvancedTodoApis()` registers all three with
  `tomRemoteApis`.

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
  grant-matrix and assignment management — every endpoint declares the shared
  `adminAccess` (`TomRoleAccess(['admin'])`) policy.
- **App** (`AppApiService` / `appApi`, the todo board): `health` (public) +
  workspaces, projects, lists, items, comments, field-state and sharing
  endpoints (authenticated; resource- and field-level checks are enforced inside
  the handlers, not by these blanket levels).

The reflection seed (`lib/src/reflection_entry.dart`) stays a stub: nothing in
the contracts package is `@tomReflector` (the DTOs are plain value records and
the service interfaces are plain abstract classes).

## Authorization model

This is the written contract the servers implement against. Authorization is
**two orthogonal layers**: resource-level access ("may this principal touch this
object at all?") and field-level grading ("which of its fields may they
see/edit?"). Both are enforced **server-side**; the wire DTOs here only carry the
*resolved* result to the client.

### Layer 1 — resource-level access (the cross-user share mechanism)

Every app endpoint is gated at the wire by `TomAuthenticatedAccess()` (declared
on each `appApi` endpoint's `TomApiEndpoint.access`), so only a logged-in
principal reaches a handler. Inside the
handler, the app server resolves whether the principal may touch a specific
`Workspace` / `Project` / `TodoList` / `TodoItem`. A principal has access when
either:

- they **own** it — the ownership chain `Workspace.ownerId → Project →
  TodoList → TodoItem` leads back to them; or
- a **`Share`** grants them a `projectRole` on that resource **or an ancestor**
  (a share on a project covers its lists and items).

This is the **cross-user mechanism**: "Alice shares Project X with Bob as
`editor`" writes a `Share` row (`{resourceType, resourceId, granteeUserId,
projectRole, grantedById}`); Bob's later requests resolve their access to X
through that share. On the wire this is the `appShare` /
`appRevokeShare` endpoints carrying [`ShareRequest`](lib/src/share_request.dart)
(`{resourceType, resourceId, granteeUserId, projectRole}`); sharing is
owner-only and revoke is owner-only, enforced in the handler.

The effective **`projectRole`** — whichever of `owner`, `editor`, `commenter`,
`viewer` the principal holds via ownership or the most-privileged matching share
— is the input to Layer 2. (`owner` is the implicit role of the ownership chain;
the other three only arrive via a `Share`.)

### Layer 2 — field-level four-state grading

The effective `projectRole` maps to a per-field
[`TomAuthState`](../../tom_core_kernel/lib/src/tombase/security/tom_authorization.dart)
through `TomResourceGrant` rows keyed by `(projectRole, fieldResourceKey)`,
folded with `TomGradedAccessControlInformation.fromGrants(grants)` and resolved
per field by `resolveState(resourceKey)`. The four states (most → least
restrictive: `none < disabled < read < full`):

| `TomAuthState` | UI render | Meaning |
| -------------- | --------- | ------- |
| `full` | editable | read + write |
| `read` | shown, read-only | visible, not editable |
| `disabled` | shown, greyed | visible control, inoperative |
| `none` | hidden | not shown |

The **gradable fields** are the stable `todo.item.*` resource-key set (addressed
by scope + `tomId`, G-RES-6): `title`, `status`, `priority`, `assigneeId`,
`dueDate`, `estimate`, `description`.

The server projects the resolved per-field states to the client as
[`GradedFieldDto`](lib/src/graded_field_dto.dart)s (`{resourceKey, access}`) via
the `appItemFieldStates` endpoint (`GET /items/{id}/field-states`) — the
four-state matrix for *this* principal. The app client renders each form field
through a `TomAuthorizer.fixed(state)`, driven by these **live, per-principal**
grades rather than an in-memory matrix. Writes are re-checked field-by-field
server-side: a `PUT /items/{id}` touching a field the principal is not `full` on
is rejected.

### The seed grant matrix (data, not code)

The matrix is **data** owned by the auth server's `auth_db` and edited through
the authadmin client (`adminGetGrants` / `adminPutGrants`, carrying
[`GrantMatrixDto`](lib/src/grant_matrix_dto.dart) — the full
`role → {resourceKey: TomAuthState}` map). The sample seeds it as follows
(rows = the gradable `todo.item.*` keys, columns = `projectRole`):

| Field (`todo.item.*`) | `owner` | `editor` | `commenter` | `viewer` |
| --------------------- | ------- | -------- | ----------- | -------- |
| `title` | `full` | `full` | `read` | `read` |
| `status` | `full` | `full` | `full` | `read` |
| `priority` | `full` | `full` | `read` | `read` |
| `assigneeId` | `full` | `full` | `read` | `none` |
| `dueDate` | `full` | `full` | `read` | `read` |
| `estimate` | `full` | `read` | `none` | `none` |
| `description` | `full` | `full` | `read` | `read` |

Reading the matrix: an `owner` edits everything; an `editor` can do likewise
except `estimate` (read-only); a `commenter` may move `status` and read most
fields but cannot see `estimate` (`none`); a `viewer` reads the visible fields
but `assigneeId`/`estimate` are hidden. This is the table the auth-server
migration seeds in step 8 and the field-grade resolver tests against in
step 18.

### How the two layers compose per request

1. **Endpoint gate** (wire): `TomPublicAccess` for `appHealth`, else
   `TomAuthenticatedAccess` — a valid bearer token is required.
2. **Resource check** (Layer 1, handler): owner-or-share lookup yields the
   effective `projectRole`, or denies access (404/403).
3. **Field grade** (Layer 2, handler): the `(projectRole, fieldKey)` matrix
   resolves each field's `TomAuthState`; reads are projected as
   `GradedFieldDto`s, writes to non-`full` fields are rejected.

Role gating that is coarser than the field matrix is also enforced in the
handler: delete is owner/editor-only, commenting requires `commenter` or above.

### Admin authorization (separate axis)

The `/admin/*` surface is a **different** authorization axis: every `adminApi`
endpoint is gated by `TomRoleAccess(['admin'])` (a system role on the `User`,
not a per-resource `projectRole`). Admins manage the accounts, roles, groups,
the grant matrix, and assignments; they do **not** thereby gain `projectRole`
access to end-users' boards. The two never mix.
