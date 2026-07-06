# Appendix A1 · Four-state authorization deep dive

*Appendix A1 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[Part 07](README_advanced_07_authorization.md) introduced the four-state model
and named its moving parts. This appendix is the **mechanical** companion: the
state lattice and its `narrow`/`widen` algebra, the exact five-layer resolution
in `TomField.resolveEffectiveAuth()`, the closed-safe default as it actually
falls out of the code, the full grant-matrix → adapter → field data path, and a
**worked resolution trace** of one field for each of the four roles. Where doc 07
says *what*, this appendix says *exactly how, line by line*.

## The four states as a lattice

`TomAuthState` is a four-value enum declared **most-to-least restrictive**, and
that declaration order *is* the algebra
(`tom_core_kernel/lib/src/tombase/security/tom_authorization.dart:29`):

```
none  <  disabled  <  read  <  full
 0        1            2       3      ← enum index
```

The ordering is load-bearing because two operations are defined directly on the
index (`tom_authorization.dart:55`, `:62`):

- **`narrow(other)`** → the **more** restrictive (lower index) of the two.
- **`widen(other)`** → the **less** restrictive (higher index) of the two.

Three derived predicates read the same lattice (`:48`–`:52`): `isVisible`
(`!= none`), `showsContent` (`read || full`), `isInteractive` (`== full`). So a
field maps to a control by its resolved state alone — `none` collapses it,
`disabled` greys it, `read` shows it read-only, `full` makes it editable — with
no separate visibility flag to keep in sync.

Two facts follow from the lattice that the rest of the system relies on:

1. **Composition by `narrow` can only ever lower a field's reach.** Every
   resolution layer below combines by `narrow`, so a later layer is strictly a
   *restriction* — it can hide or read-only a field but never grant it.
2. **The bottom of the lattice is the safe default.** Because `none` is index 0,
   "we don't know" and "denied" are the same value, and any `narrow` against an
   unknown collapses to it. That is why the closed-safe default below is `none`
   rather than a separate sentinel.

## Resolution order: the five layers

A field's effective state is computed by `TomField.resolveEffectiveAuth()`
(`tom_flutter_ui/lib/src/forms/tom_form.dart:807`). The doc-comment and the
`CRITICAL` note there make the contract explicit: **all layers are evaluated;
skipping one (group auth especially) is a severe bug.** Each layer takes the
running `state` and narrows it:

| # | Layer | Source line | What it contributes |
| --- | --- | --- | --- |
| 1 | **Resource-based** | `:809` `TomAuthorization.resolveAuth(basePath)` | the field's own grade, keyed on its `basePath` |
| 2 | **Group auth** | `:812` `tomGroup!.applyMode(state)` | a `TomAuthorizationGroup`'s collective ceiling/floor (`AuthGroupMode`) |
| 3 | **Form narrow** | `:817` `state.narrow(resolveAuth(formPath))` | the form node's grade narrows every field (always `narrow`) |
| 4 | **Per-field authorizer** | `:823` `authorizer!.effectiveAuth(state)` | an explicit `TomAuthorizer` (e.g. `TomAuthorizer.fixed`) |
| 5 | **UI-state controller** | `:827` `uiStateController!.apply(state)` | a build-time `TomUIStateController` callback |

Layer 1 seeds `state`; layers 2–5 each apply only if their hook is present, and
each can only restrict. The item form uses **layer 1 only** (no group, no
authorizer, no controller) — its grades come entirely from the installed adapter
— so for a graded item field the effective state is *exactly* what
`resolveAuth(basePath)` returns, narrowed by the form node (which the adapter
deliberately keeps permissive, below). The admin user/role forms add a **layer 4**
`TomAuthorizer.fixed` for create-vs-edit shaping, which has no server matrix
behind it (see doc 07, "Implicit vs override paths").

> The skeleton called this "layers 1–4"; the live `resolveEffectiveAuth` has
> **five** — the build-time `TomUIStateController` is the fifth. The sample's
> forms exercise layers 1, 3, and (admin only) 4; layers 2 and 5 are framework
> capability the sample does not need.

### Why `basePath` is the key

Layer 1 keys on `basePath`, and `basePath` is derived structurally when the field
is constructed (`tom_form.dart:614-617`): `scope = form!.basePath`, then
`basePath = scope.isNotEmpty ? '$scope.$tomId' : tomId`. Under
`TomScope.withScope('todo', …)` with `formId: 'item'`, the `title` field
self-addresses as `todo.item.title` — byte-identical to the `todo.item.title`
key the server grades. One scope alignment
makes the field's authorization key equal the wire grade key with no translation
(this is doc 07's headline; the full `basePath` convention is
[A2](README_advanced_A2_resource_scope_conventions.md)).

## The closed-safe default, as it falls out of the code

"Ungraded ⇒ hidden" (D-A4) is enforced at **three** independent points, each
defaulting to `none`, so no single omission can leak an editable control:

1. **Wire codec.** `GradedFieldDto` defaults `access` to `TomAuthState.none`
   (`advanced_todo_contracts/lib/src/graded_field_dto.dart:28`), and decoding an
   unrecognised access token yields `none` (`:53`). The kernel codec agrees —
   `TomAuthStateCodec.fromStored(null)` and `fromStored('bogus')` both return
   `none` (`tom_core_server/test/graded_authorization_test.dart:33`,`:37`).
2. **Server resolver.** `FieldGradeResolver.resolveItemFieldStates` resolves
   **every** gradable `todo.item.*` key, and a field with no grant row
   resolves to `none` via `graded.resolveState(key)`
   (`field_grade_resolver.dart:73-80`). The matrix sent to the client is total
   over the field set — there are no "missing" keys, only explicit `none`s.
3. **Client adapter.** A *known* gradable leaf with no entry in the live matrix
   returns `none` (`field_state_authorization_adapter.dart:95`).

The same value at all three layers is what makes the lattice's "unknown =
denied" property hold end-to-end.

## The grant matrix → adapter → field data path

The grade a field renders at travels a fixed path from a database row to a
widget. Tracing it once makes every other authorization claim in the guide
concrete:

```
auth_db.tom_resource_grant row  (role_name, resource_key, access_level)
   │  RepositoryGrantStore.grantsForRole(role)         field_grade_resolver.dart:93
   ▼
TomGradedAccessControlInformation.fromGrants(grants)   field_grade_resolver.dart:65
   │  (folds duplicate keys by widen — most permissive wins)
   ▼
resolveItemFieldStates(role) → Map<String,TomAuthState>  field_grade_resolver.dart:73
   │  itemFieldStates endpoint → List<GradedFieldDto> over the wire
   ▼
AppSession.loadFieldStates → adapter.states = matrix     (repoint, no reinstall)
   │  installed once: TomAuthorization.adapter = …       main.dart:42
   ▼
TomField.resolveEffectiveAuth() layer 1                  tom_form.dart:809
   │  TomAuthorization.resolveAuth('todo.item.title')
   ▼
FieldStateAuthorizationAdapter.resolveAuth(path)         field_state_authorization_adapter.dart:78
   ▼
TomAuthState  →  the field renders at its grade
```

Two server layers feed the matrix at the top. **Resource access**
(`ResourceAccessResolver`) answers *"may this principal touch this object, and as
what role?"* by walking the containment chain `item → list → project →
workspace`: owning the top workspace short-circuits to `ProjectRole.owner`,
else the **strongest** covering `Share` wins (`ProjectRole` is declared
`owner, editor, commenter, viewer` — most-to-least privileged, so the lowest
index is strongest, `enums.dart:75`), else `null` (no access → closed/safe 404).
**Field grades** (`FieldGradeResolver`) then maps that role to the per-field
matrix above. Both resolvers are pure over a small store seam
(`RepositoryGrantStore`/`RepositoryAppResourceStore` live; `InMemory*` seeded for
tests), which is what lets the socket-free suites reproduce the exact matrix.

### The adapter's four-step resolution

The adapter is installed on the `TomAuthorization` **singleton**, so *every*
field — login, board, dialogs, not just graded item fields — routes its layer-1
lookup through it. A flat map returning the closed-safe `none` for any unknown
path would hide the login screen. So the adapter resolves in four explicit steps
(`field_state_authorization_adapter.dart:78-99`):

| Step | Condition | Result | Why |
| --- | --- | --- | --- |
| 1 | exact entry in `states` | that grade | the common case for a graded leaf |
| 2 | path is a structural **ancestor** of a gradable key (`todo`, `todo.item`) | `full` | keeps the **layer-3 form narrow** a no-op; the matrix carries no `todo.item` row |
| 3 | path **is** a gradable leaf, absent from the matrix | `none` | closed-safe (D-A4) |
| 4 | path **outside** the gradable namespace | `full` | the kernel's no-adapter default — stays out of login/board/dialogs |

Step 2 is the subtle one. Layer 3 of `resolveEffectiveAuth` narrows every field
by the **form node** `todo.item` (`tom_form.dart:817`). The server's matrix is
keyed only by leaf field keys and carries no `todo.item` row, so if the adapter
resolved that ancestor to the closed-safe `none`, layer 3 would narrow *every*
field to `none` and hide the whole form. Resolving a gradable-key ancestor
permissively (`full`) makes the form narrow a no-op while a genuinely ungraded
leaf still degrades to `none` at step 3. The `gradableKeys` namespace (defaulting
to the inline `_gradableItemKeys` set of `todo.item.*` keys) is exactly the
boundary between "this
adapter's concern" (closed-safe) and "everything else" (permissive).

## Worked role matrix

Take one field — `assigneeId` (`todo.item.assigneeId`) — and trace its effective
state for each role, using the seeded §A.4 grant matrix (doc 07) and the
resolution layers above. The item form has no group, no authorizer, no
controller, so the effective state is `layer1.narrow(layer3)`, and layer 3
(`todo.item`) resolves to `full` (adapter step 2) — a no-op. So the effective
state equals the **layer-1 grade**:

| Role | grant row `todo.item.assigneeId` | adapter step | layer 1 | effective | renders as |
| --- | --- | --- | --- | --- | --- |
| owner | `full` | 1 (exact) | `full` | `full` | editable |
| editor | `full` | 1 (exact) | `full` | `full` | editable |
| commenter | `read` | 1 (exact) | `read` | `read` | read-only |
| viewer | *(no row → `none`)* | 1 (exact, server sent `none`) | `none` | `none` | **hidden** |

The viewer row is the instructive one: the server's `FieldGradeResolver` sent an
explicit `none` for `assigneeId` (it resolves *every* key, `field_grade_resolver.dart:78`),
so the adapter hits at step 1 with that explicit `none` — the field collapses. A
different field tells the rest of the story:

- **`estimate`** is `full / read / none / none` for owner / editor / commenter /
  viewer — the editor reads it, both commenter and viewer lose it entirely. This
  is what TC-30-02/04 assert ([Part 12](README_advanced_12_testing_integration.md)).
- **`status`** is `full / full / full / read` — uniquely, the **commenter** can
  edit status (the one field a commenter changes) while everything else is read.

Crucially the same rendering is **re-checked server-side on write**:
`AppWriteService._enforceFieldWrites` requires every field a payload *changes* to
be graded `full` for the caller's role ([Part 10](README_advanced_10_servers_endpoints.md)).
The client adapter governs what the UI *shows*; the server independently governs
what it *accepts* — a tampered client that renders `assigneeId` editable for a
commenter still has its write rejected.

## Primary sources

- `tom_core_kernel/lib/src/tombase/security/tom_authorization.dart` (the `TomAuthState` lattice + `narrow`/`widen`)
- `tom_flutter_ui/lib/src/forms/tom_form.dart:614-617` (basePath), `:807` (`resolveEffectiveAuth` five layers)
- `advanced_app_client/lib/app/field_state_authorization_adapter.dart:78-99` (the four-step resolution)
- `advanced_app_server/lib/src/access/{field_grade_resolver,resource_access_resolver}.dart`; `advanced_todo_contracts/lib/src/graded_field_dto.dart`
- `advanced_examples_alignment_plan.md` — D-A1…D-A8; `advanced_example_completion.md` — After Todos 2, 5, 11
- Companion: [07 · Authorization](README_advanced_07_authorization.md)

---

← Prev: [12 · Testing & cross-tier integration](README_advanced_12_testing_integration.md) · Next: [A2 · Scope, basePath & resource-key conventions](README_advanced_A2_resource_scope_conventions.md) →
