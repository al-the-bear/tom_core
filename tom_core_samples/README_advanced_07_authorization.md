# Authorization

*Part 07 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Authorization is the sample's **headline framework rule**: UI authorization is
driven by **scope/form/field names**, not hand-wired. A field declares *where it
lives* (`todo.item.title`), and that single key is what the server grades and
what the client form resolves against — so granting a role `read` on
`todo.item.title` makes the title field render read-only with no per-screen
glue. This part covers the four-state grade model, how a field's `basePath`
*becomes* its grade key, the grant matrix and the two server resolvers that
compute it, the one adapter installed at startup, the implicit (adapter) vs
override (`TomAuthorizer.fixed`) paths, and the route-level role gate that
guards admin CRUD. The state machine itself is the deep dive in
[A1](README_advanced_A1_authorization_state_machine.md).

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
The sample seeds the full §A.4 matrix — **7 gradable item fields × 4 project
roles = 28 rows**:

| `todo.item.*` field | owner | editor | commenter | viewer |
| --- | --- | --- | --- | --- |
| `title` | full | full | read | read |
| `status` | full | full | **full** | read |
| `priority` | full | full | read | read |
| `assigneeId` | full | full | read | **none** |
| `dueDate` | full | full | read | read |
| `estimate` | full | **read** | **none** | none |
| `description` | full | full | read | read |

The shape is intentional: an *owner* edits everything; an *editor* edits all but
the estimate; a *commenter* can change only `status` and otherwise reads (and
cannot see the estimate); a *viewer* reads everything except the assignee and
estimate, which are hidden. Several rows for one key fold to the **most
permissive** grade (`widen`) via the framework's
`TomGradedAccessControlInformation.fromGrants` — the same projection the auth
server's admin API uses, so the two tiers agree on grade semantics.

## The two server resolvers

The app server computes a caller's grades in **two layers** (§A.4), each pure
over a small store seam (`RepositoryGrantStore`/`RepositoryAppResourceStore`
live; `InMemory*` seeded for socket-free tests):

1. **Resource access** — *"may this principal touch this object, and as what
   role?"* `ResourceAccessResolver` (`advanced_app_server/lib/src/access/resource_access_resolver.dart`)
   walks the containment chain `item → list → project → workspace`: owning the
   top workspace (`workspace.ownerId == userId`) short-circuits to
   `ProjectRole.owner`; otherwise the **strongest** `Share` whose target is the
   resource or any ancestor wins (a share on a project covers its lists and
   items); with neither, the result is `null` (no access).
2. **Field grades** — *"for that role, which fields, and how?"*
   `FieldGradeResolver` (`.../access/field_grade_resolver.dart`) loads the
   role's grant rows and folds them, resolving **every** gradable `todo.item.*`
   key to its `TomAuthState`. A field with no grant row
   degrades to `none` — closed-safe (D-A4).

The result is sent to the client as a `List<GradedFieldDto>` from the
`itemFieldStates` endpoint (`advanced_app_server/lib/src/endpoints/app_endpoints.dart`).

> **Authorization is enforced server-side too, not just rendered.** The same
> `FieldGradeResolver` gates **writes**: `AppWriteService._enforceFieldWrites`
> requires every gradable field a payload *changes* to be graded `full` for the
> caller's role, or the whole write is rejected. The client adapter governs what
> the UI *shows*; the server independently re-checks what it *accepts*. A
> tampered client cannot widen its own grades.

## The single installed adapter

On the client, that grade matrix flows into **one** adapter installed **once**
at startup — `FieldStateAuthorizationAdapter`
(`advanced_app_client/lib/app/field_state_authorization_adapter.dart`), set as
`TomAuthorization.adapter = session.authorizationAdapter`
(`advanced_app_client/lib/main.dart:42`). It is a `TomAuthorizationAdapter`
over a **repointable** `Map<String, TomAuthState> states` matrix: as the session
opens each item it assigns that item's freshly fetched matrix
(`AppSession.currentFieldStates`, D-A3), and the installed singleton reflects
the item in view with no reinstall. The adapter never calls the backend — it is
a pure projection of state the session already holds, which keeps `resolveAuth`
synchronous as it must be.

Because the adapter sits on the `TomAuthorization` **singleton**, *every* field
in the app routes its layer-1 lookup through it — the login form, the board, the
dialogs, not just graded item fields. A naive flat map returning the closed-safe
`none` for any unknown path would therefore hide the login screen. So the
adapter guards a single explicit **namespace** (`gradableKeys`, defaulting to
the inline `_gradableItemKeys` set of `todo.item.*` keys) and resolves in four
steps
(`field_state_authorization_adapter.dart:77-100`):

1. an exact grade for the path wins;
2. a structural **ancestor** of a gradable key (the form node `todo.item`, the
   scope `todo`) resolves **permissively** (`full`) so the layer-3 form narrow
   does not clobber the per-field grades;
3. a **known** gradable leaf with no grade in the live matrix → `none`
   (closed-safe);
4. anything **outside** the namespace → `full` (the kernel's no-adapter
   default), staying out of the way of login/board/dialogs.

## Implicit vs override paths

The sample deliberately shows **both** authorization paths, clearly labelled —
because not every form should be driven by a server matrix.

- **Implicit (the adapter path).** The item form (`todo_item_form.dart`) carries
  **no** per-field authorizers: each field's grade comes entirely from the
  installed adapter via layer 1. The realignment *removed* the old
  `TomAuthorizer.fixed(...)` and the `*Override` label arguments rather than
  keeping them as a fallback — a fixed authorizer (layer 4) or a label override
  (highest priority) would re-short-circuit the lookup and the resource/grade
  systems would never be exercised (D-A5, D-A8). This is the headline rule in
  action: scope the form correctly and authorization is automatic.
- **Override (the per-field authorizer path).** The admin user and role forms
  (`advanced_authadmin_client/lib/forms/user_form.dart`, `role_form.dart`)
  **keep** `TomAuthorizer.fixed(...)` — the create-vs-edit shaping (`username`
  read-only on edit, a stable key) is a legitimate **layer-4** concern with no
  server grade matrix behind it. The group form has neither, needing no shaping.
  This is the *correct* use of the override layer (D-A5).

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

- `advanced_app_server/lib/src/access/{resource_access_resolver,field_grade_resolver}.dart`; `tom_flutter_ui/.../tom_form.dart:807`
- `advanced_auth_server/database_migrations/auth_db/auth_schema/[003]-auth_demo_seed@dev,test.sql` (the grant matrix); `advanced_auth_server/lib/src/endpoints/admin_endpoints.dart`
- Appendix [A1](README_advanced_A1_authorization_state_machine.md)

---

← Prev: [06 · Authentication (JWT)](README_advanced_06_authentication.md) · Next: [08 · Resources & text externalization](README_advanced_08_resources_texts.md) →
