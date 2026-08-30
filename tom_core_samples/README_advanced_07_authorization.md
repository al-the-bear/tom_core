# Authorization

*Part 07 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Authorization is the sample's **headline framework rule**: UI authorization is
driven by **scope/form/field names**, not hand-wired. A field declares *where it
lives* (`todo.item.title`), and that single key is what the server grades and
what the client form resolves against — so granting a role `read` on
`todo.item.title` makes the title field render read-only with no per-screen
glue. This part covers the four-state grade model, how a field's `basePath`
*becomes* its grade key, the grant matrix and the two server resolvers that
compute it, how the item screen stamps each gradable field with a per-field
`TomAuthorizer.fixed` (there is **no** installed authorization adapter), and the
route-level role gate that guards admin CRUD. The state machine itself is the
deep dive in [A1](README_advanced_A1_authorization_state_machine.md).

## The four-state field authorization model

Every gradable field resolves to one of four `TomAuthState` values
(`tom_core_kernel/lib/src/tombase/security/tom_authorization.dart:29`),
declared **most-to-least restrictive** so the ordering itself drives `narrow`
/ `widen`:

| State | Field renders as | Meaning |
| --- | --- | --- |
| `none` | **hidden** | the field does not exist from the user's perspective |
| `disabled` | **greyed out, no content** | data may exist but is not accessible here |
| `read` | **read-only** | the current value is shown but cannot be changed |
| `full` | **editable** | fully interactive |

`none < disabled < read < full`. Two states compose by `narrow` (the more
restrictive wins) — that is how the resolution layers below combine, and why
the closed-safe default is `none`: an unknown grant can only ever *lower* a
field's reach, never raise it.

## scope/form/field → `basePath` → grade key

The whole rule turns on one structural fact (stated once in
[A2](README_advanced_A2_resource_scope_conventions.md), used everywhere). A
field's **`basePath`** is `<scopePath>.<formId>.<tomId>`
(`tom_flutter_ui/.../tom_form.dart:614-617`), and authorization keys on that
**`basePath` alone, no suffix** — `TomAuthorization.resolveAuth(basePath)` is
layer 1 of `TomField.resolveEffectiveAuth()` (`tom_form.dart:807`, the lookup
itself at `:809`).

So when the item form runs under `TomScope.withScope('todo', …)` with
`formId: 'item'`, the field `title` (tomId `title`) self-addresses as
`todo.item.title` — *exactly* the `todo.item.title` key the server's grade
matrix is keyed by (D-A1). One alignment makes the field's
authorization key equal the wire grade key with **zero translation layer**.

The one deliberate exception is the estimate field (D-A2): its grade key is
`todo.item.estimate`, so the form gives it an explicit `tomId: 'estimate'` for
addressing while keeping the reflected member name `estimateHours` for the
save round-trip — `TomField.tomId` and the Dart member name are independent.
See [03 · Domain model](README_advanced_03_domain_reflection.md#enums-stored-name-vs-display-text-contract);
the `scope`/`formId`/`tomId` segments are plain string literals declared at the
form (`super(formId: 'item')`) and the scope call site
(`TomScope.withScope('todo', …)`), not entries in a key catalogue.

## The grant matrix

A role's field grades are **data**, not code — rows in the auth server's
`auth_db` `tom_resource_grant` table (`(role_name, resource_key, access_level)`),
seeded by `[003]-auth_demo_seed@dev,test.sql` (dev/test only) and editable through
the admin console.
The sample seeds the full §A.4 matrix — **8 graded item keys × 4 project
roles = 32 rows** (the seven form fields below plus the item's file column,
`todo.item.attachment`, covered in
[13 · File transfer](README_advanced_13_file_transfer.md)):

| `todo.item.*` field | owner | editor | commenter | viewer |
| --- | --- | --- | --- | --- |
| `title` | full | full | read | read |
| `status` | full | full | read | **disabled** |
| `priority` | full | full | **none** | read |
| `assigneeId` | full | **read** | read | read |
| `dueDate` | full | full | read | read |
| `estimate` | full | **read** | **none** | **none** |
| `description` | full | full | read | read |

The shape is intentional, and it is the one place all four `TomAuthState` values
are visible at once: an *owner* edits everything; an *editor* edits all but the
assignee and the estimate (`read`); a *commenter* reads most fields but cannot
see `priority`/`estimate` (`none`); a *viewer* edits nothing and cannot see the
`estimate` either (`none`) — `status` renders as a `disabled` control and the
remaining five are read-only. Several rows for one key fold to the **most
permissive** grade (`widen`) via the framework's
`TomGradedAccessControlInformation.fromGrants` — the same projection the auth
server's admin API uses, so the two tiers agree on grade semantics.

**The matrix exists twice, and the two copies are pinned equal at the seam.**
These rows are the *server's* copy — what the app server enforces on a write and
what the authadmin console edits. The app client shapes its item form from a
second copy, `projectRoleFieldGrades` in `advanced_todo_domain`, which never
crosses the wire. The duality is deliberate: the client's shaping is cooperation,
the server's row is enforcement, and an administrator's runtime edit moves the
server's answer alone. But the two must *start* identical, so
`advanced_auth_server/test/grant_matrix_key_consistency_test.dart` parses this
seed file and asserts every cell against the domain map — offline, no database.
Changing a grade on one side alone fails there.

## The two server resolvers

The app server computes a caller's grades in **two layers** (§A.4), each pure
over a small store seam (`RepositoryGrantStore` for the grade matrix; the
framework `RepositoryPrincipalResourceGrantStore` / `RepositoryPrincipalDelegationStore`
plus the app's `RepositoryResourceContainmentStore` for roles — `InMemory*`
seeded for socket-free tests):

1. **Resource access** — *"may this principal touch this object, and as what
   role?"* `ResourceRoleResolver` (`advanced_app_server/lib/src/access/resource_role_resolver.dart`)
   folds the principal's roles through the framework `TomDelegationResolver` —
   the C-5 ownership grants (`tom_principal_resource_grant`) and C-6 `share`-mode
   delegations (`tom_principal_delegation`) — into one flat `resourceKey → role`
   map, then keeps the strongest `ProjectRole` over the containment chain
   `item → list → project → workspace`: an `owner` grant on the workspace flows
   down to its items, and the **strongest** share whose target is the resource or
   any ancestor wins (a share on a project covers its lists and items); with
   neither, the result is `null` (no access).
2. **Field grades** — *"for that role, which fields, and how?"*
   `FieldGradeResolver` (`.../access/field_grade_resolver.dart`) loads the
   role's grant rows and folds them, resolving **every** gradable `todo.item.*`
   key to its `TomAuthState`. A field with no grant row
   degrades to `none` — closed-safe (D-A4).

Server-side these grades feed the **write enforcement** path (below). The app
client obtains what it needs to grade fields locally from a different, flat read:
`resourceRoles` (`GET /resource-roles → Map<String,String>`,
`advanced_app_server/lib/src/endpoints/app_endpoints.dart`), the principal's
`resourceKey → roleName` map.

> **Authorization is enforced server-side too, not just rendered.** The same
> `FieldGradeResolver` gates **writes**: `AppWriteService._enforceFieldWrites`
> requires every gradable field a payload *changes* to be graded `full` for the
> caller's role, or the whole write is rejected. The client adapter governs what
> the UI *shows*; the server independently re-checks what it *accepts*. A
> tampered client cannot widen its own grades.

## Per-field grading on the client (global resource adapter + local narrow)

On the client, field grades are computed **locally**, from two pieces already in
hand — no per-field READ round-trip. At **login** the session snapshots the
principal's `resourceRoles` map and installs an
`AppResourceRoleAdapter(resourceRoles)` as the **global** `TomAuthorization`
adapter (`advanced_app_client/lib/app/app_resource_role_adapter.dart`); on logout
it resets the adapter. That adapter gates only `<type>:<id>` resource keys (those
containing `:`); any dotted path (`todo.item.title`, chrome) stays permissive
(`full`), matching the pre-RCC2 no-adapter behaviour.

When the item detail screen opens an item, `_resolveForm()` grades each gradable
field **synchronously** (`advanced_app_client/lib/screens/item_detail_screen.dart:85-111`):

```dart
final resourceState = TomAuthorization.resolveAuth('todo.item:$id'); // ceiling via the registry
final role = ProjectRole.values.asNameMap()[session.resourceRoles['todo.item:$id']];
final grades = projectRoleFieldGrades[role];                          // shared-domain per-role row
for (final field in form.gradableFields) {
  field.authorizer =
      TomAuthorizer.fixed(resourceState.narrow(grades[field.basePath] ?? TomAuthState.none));
}
```

`resourceState` is the item's resource-level ceiling resolved through the
framework registry via the installed adapter (no role → `none`);
`grades[field.basePath]` is the field's grade from the SHARED-DOMAIN
`projectRoleFieldGrades[role]` row. Because every role's field grades sit at or
below its resource ceiling, `resourceState.narrow(...)` reproduces the field-grade
matrix exactly; a missing role or missing grade collapses the field to
`TomAuthState.none` — **closed-safe** (D-A4). There is **no** per-field installed
adapter; the global `AppResourceRoleAdapter` leaves every *non-gradable* dotted
path (login, board, dialogs) permissive — the screen never has to carve out a
namespace to keep the login screen visible.

This deliberately replaced an earlier design that installed one
`FieldStateAuthorizationAdapter` on the `TomAuthorization` singleton and
repointed its matrix per item. That approach forced the adapter to special-case
a `gradableKeys` namespace (so a closed-safe `none` would not hide the login
form) and routed *every* field's layer-1 lookup through the singleton. Stamping
each gradable field directly is simpler, keeps `none` scoped to the fields that
opt into grading, and needs no global installation step (D-A5).

## Where per-field authorizers also appear

The item screen is not the only place a per-field `TomAuthorizer.fixed(...)`
appears — the admin user and role forms
(`advanced_authadmin_client/lib/forms/user_form.dart`, `role_form.dart`) use it
for **create-vs-edit shaping** (`username` read-only on edit, a stable key),
which is a legitimate **layer-4** concern with no server grade matrix behind it.
The group form has neither, needing no shaping. Both uses — the item screen's
DB-resolved grades and the admin forms' create/edit shaping — are the *correct*
use of the layer-4 authorizer (D-A5).

The full five-layer order is in `TomField.resolveEffectiveAuth()`
(`tom_form.dart:807`): (1) resource-based via `basePath`, (2) group auth, (3)
form-path narrow, (4) per-field authorizer, (5) UI-state controller — each
`narrow`s the running state, so a later layer can only restrict, never widen.

## Route-level role gating for admin CRUD

Field grades govern *content within* a form; whole **operations** are gated at
the route. Every one of the auth server's `/admin/*` endpoints
**declares on the contract** the shared `adminAccess` (`TomRoleAccess(['admin'])`)
policy (`advanced_todo_contracts/lib/src/api_registry.dart`, `adminApi`), so the
endpoint pipeline extracts it and rejects a non-admin caller **before** the
method runs — the role check happens in the pipeline, not in the handler. This is
the coarse-grained companion to the fine-grained field grades: a viewer never
reaches `adminCreateUser` at all, and even an admin's field-level edits to a
graded item are still subject to the matrix above. (Contrast the app server's
task endpoints, whose contract declares only `TomAuthenticatedAccess()` — any
signed-in user may call them,
with per-resource role and per-field grade decided inside by the two resolvers.)
The endpoint pipeline and annotations are part
[10](README_advanced_10_servers_endpoints.md).

## Primary sources

- `advanced_app_server/lib/src/access/{resource_role_resolver,field_grade_resolver}.dart`; `tom_flutter_ui/.../tom_form.dart:807`
- `advanced_auth_server/database_migrations/auth_db/auth_schema/[003]-auth_demo_seed@dev,test.sql` (the grant matrix); `advanced_auth_server/lib/src/endpoints/admin_endpoints.dart`
- Appendix [A1](README_advanced_A1_authorization_state_machine.md)

---

← Prev: [06 · Authentication (JWT)](README_advanced_06_authentication.md) · Next: [08 · Resources & text externalization](README_advanced_08_resources_texts.md) →
