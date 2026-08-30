# advanced_todo_contracts

Shared wire contracts for the **advanced Tom Core full-stack sample**
(see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

The single definition of the over-the-wire surface, depended on by both servers
(which implement it) and the shared client core (which calls it).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[04 · Wire contracts & DTOs](../README_advanced_04_wire_contracts_dtos.md)**.

### Endpoint model: kernel `TomApi` registry, not server `@tomService`

The server-side endpoint annotations (`@tomService`, `@TomEndpoint`) live in
**`tom_core_server`**, and this package depends only on `tom_core_kernel` + the
domain model so the **Flutter-free client core** can consume it — pulling in
`tom_core_server` would break that. The migrated `tom_uam_codespec` meets the
same constraint and resolves it with the kernel's
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
registry inside `tom_core_server` by each server.

## Contents

The DTOs (`lib/src/`, re-exported from `advanced_todo_contracts.dart`) are
**reflection-first** (G-DTO): each is a `@tomReflector` class with plain
non-`final` fields and **no** hand-written `toJson`/`fromJson`. The kernel
reflection path serializes them (`TomReflectionInfo.getValues` /
`createInstanceFromJson`) exactly like the reflected `advanced_todo_domain`
entities — the server endpoint pipeline drives it directly, while off-server
consumers (the Flutter client core, the round-trip tests) go through the
`dtoFromJson` / `dtoToMap` / `dtoToJsonString` helpers in `dto_reflection.dart`.
Every DTO has a **log-safe** `toString` (passwords and bearer tokens are never
rendered). Values that cannot cross the wire as their native type travel as the
enum's `.name` token in a plain `String`, with a typed accessor for callers; the
token readers are **closed-safe**, so an unknown access token degrades to
`TomAuthState.none` and an unknown role to `ProjectRole.viewer`.

- **Auth/login** (`login_dtos.dart`): `LoginRequest`
  (`{username, password, app, org}`), `SecondFactorRequest`,
  `TwoFactorEnrolmentRequest`, `UserDto` (the password-free user projection,
  with a typed `statusValue`), and `LoginResult`
  (`{user, authToken, authzToken, expiresAt}` plus the two-factor challenge and
  enrolment flags).
- **Authorization** (`graded_field_dto.dart`, `grant_matrix_dto.dart`):
  `GradedFieldDto` (`{resourceKey, access}`) and `GrantMatrixDto` — the full
  `role → {resourceKey: TomAuthState}` matrix the admin grant editor reads and
  writes, with a copy-on-edit `withAccess` that leaves the receiver unchanged.
- **Sharing** (`share_request.dart`): `ShareRequest`
  (`{resourceType, resourceId, granteeUserId, projectRole}`).
- **Admin CRUD** (`admin_dtos.dart`): `CreateUserRequest`, `RoleDto`,
  `GroupDto` (name + member ids in display order), and `AssignmentRequest`.
- **By-id requests** (`entity_id_request.dart`): `EntityIdRequest`, the one
  reusable request type every `/…/{id}` endpoint binds its path capture onto
  (G-API-2).
- **Files** (`file_descriptor_dto.dart`): `FileDescriptorDto`, a lossless
  wrapper around the kernel `TomFileMetadata` a `HEAD` against a slot returns,
  plus `AppFileSlots` — the `<table>/<id>/<column>` slot addresses named once so
  both servers and both clients spell them the same way.
- **Resources** (`resource_bundle_dto.dart`): `ResourceBundleDto`, the
  `<basePath>.<suffix>` → text map a server delivers so clients ship no UI
  strings, plus `flattenResourceTree` for servers that store their texts nested.

## The service surface

- **Auth** (`AuthApiService` / `authApi`, `/auth/*`): `login`,
  `submitSecondFactor`, the three enrolment passes and `loginResources`
  (public — exactly the surface a caller reaches *before* it holds a token) +
  `refresh`/`logout`/`me` (authenticated).
- **Admin** (`AdminApiService` / `adminApi`, `/admin/*`): user, role, group,
  grant-matrix and assignment management — every endpoint declares the shared
  `adminAccess` (`TomRoleAccess(['admin'])`) policy.
- **App** (`AppApiService` / `appApi`, the todo board): `health` (public, served
  at `/status`) + workspaces, projects, lists, items, attachments, comments,
  subtasks, resources, resource-roles and sharing endpoints (authenticated;
  resource- and field-level checks are enforced inside the handlers, not by
  these blanket levels).

Reflection is needed only to run this package's own round-trip tests, so the
single seed is
**test-only**: `test/run_all_tests.dart` → `test/run_all_tests.reflection.dart`
(regenerate with `./reflection_generation.sh`). The package ships no runtime seed
(G-REFL-1/2); the servers and clients reflect these DTOs through their own
combined seed.

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

The app server ships the principal's flat `resourceKey → roleName` map via the
`appResourceRoles` endpoint (`GET /resource-roles`); the client installs it as an
`AppResourceRoleAdapter` in the framework registry and grades each form field
**locally** — resolving the item's resource ceiling through the registry and
narrowing it by the shared per-role field-grade rows (`projectRoleFieldGrades`),
then rendering through a `TomAuthorizer.fixed(state)`. Per-field grades never
cross the wire on a read. Writes are still re-checked field-by-field
server-side: a `PUT /items/{id}` touching a field the principal is not `full` on
is rejected. [`GradedFieldDto`](lib/src/graded_field_dto.dart)
(`{resourceKey, access}`) survives only as the per-cell grade of the **admin**
grant matrix ([`GrantMatrixDto`](lib/src/grant_matrix_dto.dart), the auth
server's `/admin/grants` path), rendered in the admin console's grant editor.

### The seed grant matrix (data, not code)

The matrix is **data** owned by the auth server's `auth_db` and edited through
the authadmin client (`adminGetGrants` / `adminPutGrants`, carrying
[`GrantMatrixDto`](lib/src/grant_matrix_dto.dart) — the full
`role → {resourceKey: TomAuthState}` map). The sample seeds it as follows
(rows = the gradable `todo.item.*` keys, columns = `projectRole`):

| Field (`todo.item.*`) | `owner` | `editor` | `commenter` | `viewer` |
| --------------------- | ------- | -------- | ----------- | -------- |
| `title` | `full` | `full` | `read` | `read` |
| `status` | `full` | `full` | `read` | `disabled` |
| `priority` | `full` | `full` | `none` | `read` |
| `assigneeId` | `full` | `read` | `read` | `read` |
| `dueDate` | `full` | `full` | `read` | `read` |
| `estimate` | `full` | `read` | `none` | `none` |
| `description` | `full` | `full` | `read` | `read` |

Reading the matrix: an `owner` edits everything; an `editor` can do likewise
except `assigneeId` and `estimate` (read-only); a `commenter` reads most fields
but cannot see `priority`/`estimate` (`none`); a `viewer` edits nothing — the
`status` control renders `disabled` and the rest are read-only. Read down the
columns and all four states appear, which is what makes this matrix the sample's
worked example of the state machine rather than a two-state permission list.

The same values are declared in code as `projectRoleFieldGrades`
(`advanced_todo_domain`) — the *client's* copy, used to shape the item form
without a round trip. That copy and this seed are independent artifacts (the
client shapes, the server enforces, and an administrator's edit moves only the
server's row), but they must start identical:
`advanced_auth_server/test/grant_matrix_key_consistency_test.dart` parses the
seed SQL and asserts it cell-for-cell against the domain map.

An eighth graded key rides alongside the seven form fields:
`todo.item.attachment`, the item's file column (`full` for `owner`/`editor`,
`read` for `commenter`/`viewer`). It is graded per role like the fields are but
enforced on the **file endpoint** rather than in the item payload — no client
may write a blob key directly — so the seed is 8 keys × 4 roles = 32 rows.

### How the two layers compose per request

1. **Endpoint gate** (wire): `TomPublicAccess` for `appHealth`, else
   `TomAuthenticatedAccess` — a valid bearer token is required.
2. **Resource check** (Layer 1, handler): owner-or-share lookup yields the
   effective `projectRole`, or denies access (404/403).
3. **Field grade** (Layer 2, handler): the `(projectRole, fieldKey)` matrix
   resolves each field's `TomAuthState`. Writes to non-`full` fields are
   rejected; reads carry no per-field grade at all — the client resolves them
   locally from the `appResourceRoles` map.

Role gating that is coarser than the field matrix is also enforced in the
handler: delete is owner/editor-only, commenting requires `commenter` or above.

### Admin authorization (separate axis)

The `/admin/*` surface is a **different** authorization axis: every `adminApi`
endpoint is gated by `TomRoleAccess(['admin'])` (a system role on the `User`,
not a per-resource `projectRole`). Admins manage the accounts, roles, groups,
the grant matrix, and assignments; they do **not** thereby gain `projectRole`
access to end-users' boards. The two never mix.
