# Appendix A4 · Implementation-rules cheat-sheet

*Appendix A4 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The spine teaches the rules in context; this appendix is the **checklist** you
keep open while building a *new* tom_core app. Every rule is one line, stated
imperatively, carrying **(a)** the framework enforcement anchor (where the rule
is *made true* — kernel / `tom_flutter_ui` / `tom_core_server`) and **(b)** a
sample site you can copy from. Nothing here is new: it consolidates what
[07](README_advanced_07_authorization.md),
[08](README_advanced_08_resources_texts.md),
[09](README_advanced_09_forms_ui.md), [A1](README_advanced_A1_authorization_state_machine.md),
[A2](README_advanced_A2_resource_scope_conventions.md), and
[A3](README_advanced_A3_request_lifecycle.md) establish, so you can verify a rule
holds without re-reading the prose.

> **How to read the anchors.** Paths are relative to `tom_core_samples/` unless
> they name `tom_flutter_ui` / `tom_core_kernel` / `tom_core_server` (the
> framework). A `file:line` is the enforcement or usage point as of this writing;
> if a line drifts, the symbol name in the same cell still locates it.

## The two headline rules (read these first)

Everything else is detail around these two. If a new app honours only these, it
is already "doing it the tom_core way":

| # | Rule | Why | Framework anchor | Sample site |
| --- | --- | --- | --- | --- |
| **H1** | **Externalize every UI text.** A widget ships **no** hard-coded label/hint/error string; each resolves from a server-delivered bundle keyed by the field's `basePath`. | One name configures display *and* access; texts change without a client release; the no-strings property is testable. | `tom_flutter_ui` `tom_form.dart:855` — `resolvedLabel => TomCtr.textOrNull(basePath, 'label') ?? tomId` | `advanced_app_server/assets/resources_app.json`; install via `setAppResourceProvider` ([08](README_advanced_08_resources_texts.md)) |
| **H2** | **Drive UI authorization by scope/form/field names**, not hand-wired widget logic. One installed adapter resolves each field's four-state grade from its `basePath`; the form holds no auth state of its own. | The *same* widget renders differently per principal purely from the installed matrix; grades come from the server, enforced where the data lives. | `tom_flutter_ui` `tom_form.dart:807` (`resolveEffectiveAuth`), `:809` (layer-1 `TomAuthorization.resolveAuth(basePath)`) | `advanced_app_client/lib/app/field_state_authorization_adapter.dart`; installed `main.dart:42` |

## Resources & texts

- [ ] **No label/hint/error literal in any widget.** → H1; anchor `tom_form.dart:855`. Sample: `todo_item_form.dart` fields pass only a `tomId`, never a label.
- [ ] **Resources are server-delivered, installed once** via `TomTextResourceProvider.setAppResourceProvider` at bootstrap — pre-login bundle first (public `loginResources`), full bundle after sign-in. → [08](README_advanced_08_resources_texts.md), D-A9; sample `app_session.dart:108`, the two `/resources` endpoints (`auth_endpoints.dart:235`, `app_endpoints.dart:1074`).
- [ ] **Key texts by `<basePath>.<suffix>`** (`.label` / `.hint` / `.error.<code>`). The join is one helper — `TomCtr._key` (`tom_flutter_ui` `tom_construction_helpers.dart`): empty suffix = `basePath` verbatim, else `'$basePath.$suffix'`. → [A2](README_advanced_A2_resource_scope_conventions.md).
- [ ] **Author texts as a nested `scope → form → field → suffix` JSON tree**, flattened server-side to the flat wire map. Keep the flatten *pure* and web-safe — `flattenResourceTree` in `advanced_todo_contracts` (no `dart:io`); the `File` read lives in each **server**. → RC-24, [A2](README_advanced_A2_resource_scope_conventions.md); sample `resource_bundle_dto.dart:110`.
- [ ] **Prove it with the `[srv]` sentinel.** A test installs a bundle whose every value carries a `[srv]` suffix and asserts the suffixed strings render — a hard-coded label would fail it. → [12](README_advanced_12_testing_integration.md); sample `form_label_resolution_test.dart`.

## Authorization

- [ ] **A field's `basePath` *is* its grade key** — `<scopePath>.<formId>.<tomId>`, no suffix. Authorization keys on the bare path; texts add a suffix. → H2; anchor `tom_form.dart:146` (form path), `:614-617` (field path), `:809` (auth lookup).
- [ ] **Install exactly one authorization adapter** at startup (`TomAuthorization.adapter = …`) and feed it the current item's matrix; never scatter per-widget auth checks. → sample `main.dart:42`, `app_session.dart:160` (`authorizationAdapter.states = states`).
- [ ] **Per-field authorizers are a *narrowing override only*.** Composition can only *restrict* (`narrow`), never widen, what the adapter resolved. Use `TomAuthorizer.fixed` for the admin forms; the item form has **none** (implicit path). → [07](README_advanced_07_authorization.md) D-A5/D-A8, [A1](README_advanced_A1_authorization_state_machine.md).
- [ ] **Default closed.** Unknown/absent grade ⇒ `TomAuthState.none` (hidden), enforced at three independent points: wire codec (`GradedFieldDto.fromJson`), server resolver (`field_grade_resolver.dart:73-80`), client adapter. → D-A4, [A1](README_advanced_A1_authorization_state_machine.md).
- [ ] **Enforce writes on the server too.** Field grades are a UX convenience client-side; the server re-checks every changed field is `full` and rejects otherwise. → `app_endpoints.dart:663` (`_enforceFieldWrites`), [A3](README_advanced_A3_request_lifecycle.md).
- [ ] **Role-gate admin routes** by declaring `TomRoleAccess([...])` on the contract endpoint (`TomApiEndpoint.access`) — the pipeline extracts and enforces it *before* the method runs. → `tom_core_server`; sample `api_registry.dart` (`adminApi`, shared `adminAccess`).
- [ ] **Source the server principal from the request zone**, `getFromCurrentZone<TomPrincipal>()` — never the client-side `TomBearerAuthentication` singleton (not request-scoped). → sample `app_endpoints.dart:981`, `auth_endpoints.dart:206`.

## Domain & reflection

- [ ] **Reflect every entity and every form-bound class** with `@tomReflector` so `bind`/`save` and wire serialization work. → [03](README_advanced_03_domain_reflection.md); sample `advanced_todo_domain/`.
- [ ] **One reflection seed per package, last-writer-wins.** A single `reflection_seed.dart` whose `main()` touch-imports the reflected types; the generated `reflection_seed.reflection.dart` is the build output. → [02](README_advanced_02_project_layout_build.md); sample `advanced_app_server/`, `advanced_authadmin_client/lib/reflection_seed.dart`.
- [ ] **Regenerate reflection only on signature changes**, via the package's `reflection_generation.sh` (copy from a sibling if missing) — not on every edit. → memory: reflection-regen rules; sample `*/reflection_generation.sh`.
- [ ] **Pin scope/form/field keys in a domain constants file** so the form, the grade matrix, and the JSON texts read one source of truth. → [A2](README_advanced_A2_resource_scope_conventions.md) D-A1; sample `resource_keys.dart` (`scope`/`formId`/`keyFor`).
- [ ] **Enums carry a stored-name vs label split** — the stored `name` token is the wire/DB value; the label is a resource. → [03](README_advanced_03_domain_reflection.md).

## Forms & UI

- [ ] **Use bound reflected forms** (`TomForm<T>`/`TomField<T>`); fields self-render via `field.widget`, `createFormElements` stays empty. → [09](README_advanced_09_forms_ui.md); sample `todo_item_form.dart`, `user_form.dart`.
- [ ] **Unscoped: `formId` *is* the base path.** A plainly-constructed `LoginForm` (`formId: 'login'`) gives `login.username`. Use this for login + admin editors. → [A2](README_advanced_A2_resource_scope_conventions.md).
- [ ] **Scoped: push the scope at the *call site*** to make field paths equal the server's grade keys — `TomScope.withScope('todo', TodoItemForm.new)`. Constructing the item form unscoped silently breaks every grade/text lookup (renders empty, no throw). → [A2](README_advanced_A2_resource_scope_conventions.md) D-RC17-b; sample `item_detail_screen.dart:88`.
- [ ] **`bind`/`save` round-trip on the reflected *member* name**, independent of `tomId`. The one deliberate divergence (`estimate` tomId ↔ `estimateHours` member) proves the decoupling. → [A2](README_advanced_A2_resource_scope_conventions.md) D-A2; sample `todo_item_form.dart:85`.
- [ ] **Observe state with the two-layer model** — `ListenableBuilder` over a `ChangeNotifier` session, `TomObject` fields for in-form reactivity. → [09](README_advanced_09_forms_ui.md), [11](README_advanced_11_clients_app_admin.md).

## Persistence & migrations

- [ ] **Number migrations consecutively (`000,001,002,…`) and split schema / admin / demo.** DDL untagged, the production admin bootstrap untagged, and demo seeds in a separate `@dev,test`-tagged file (G-MIG-1/2/3) — so a production apply seeds the admin account but omits demo users, and every table exists before it is seeded. → RC-23, [05](README_advanced_05_persistence_database.md); sample `app_db/app_schema/[000]-app_core_schema.sql` + `[001]-app_demo_seed@dev,test.sql` (auth: `[000]`+`[001]` schema, `[002]-auth_admin_seed.sql`, `[003]-auth_demo_seed@dev,test.sql`).
- [ ] **Keep every seed `INSERT` idempotent** (`ON DUPLICATE KEY UPDATE`) so a re-applied migration is a no-op. → [05](README_advanced_05_persistence_database.md); sample `[002]-auth_admin_seed.sql`, `[003]-auth_demo_seed@dev,test.sql`, `[001]-app_demo_seed@dev,test.sql`.
- [ ] **Map columns with `@TomDbColumn`** on the persistence record; the empty-bodied `TomSqlDatasourceRepository` singletons are the CRUD seam. → [05](README_advanced_05_persistence_database.md); sample `app_persistence_model.dart`.
- [ ] **One datasource per logical DB**, configured in YAML (map-key = folder, literal-int port). Cross-DB references are *logical* (no cross-DB FK); the app server binds the framework `main` datasource to `auth_db` to read the shared grant table. → [05](README_advanced_05_persistence_database.md); sample `assets/datasources_*.yaml`, `field_grade_resolver.dart:30-39`.

## Servers & endpoints

- [ ] **The contract declares the access; the server enforces it** — set each endpoint's `TomApiEndpoint.access` (`TomPublicAccess` / `TomAuthenticatedAccess` / `TomRoleAccess`) in the registry, and the pipeline extracts it on first call (G-API-3/C-12). A handler-side `TomAccessControl` annotation is only a *local override* (`tea ?? ae.access`); the advanced servers declare nothing inline. → [10](README_advanced_10_servers_endpoints.md); sample `api_registry.dart` (`authApi`/`adminApi`/`appApi`).
- [ ] **Validate the bearer on every non-public request** — the pipeline rejects pre-invocation with `endpoint_handler.handle_method_call.access_denied` → 403. → [10](README_advanced_10_servers_endpoints.md); sample `app_endpoints.dart:904`/`:935-939` (`appForbiddenOrNotFound`).
- [ ] **Fail closed/safe: 404 over 403 for unreachable resources.** A resource the caller cannot reach is reported *missing*, never leaking its existence. → [A1](README_advanced_A1_authorization_state_machine.md)/[A3](README_advanced_A3_request_lifecycle.md); sample `app_endpoints.dart:232-237` (`app.item.not_found`).
- [ ] **Keep services server-/zone-free; map error keys at the boundary.** Services throw stable `TomEndpointHandlerException` keys; a server-level handler maps them to HTTP statuses. → sample `appForbiddenOrNotFound` (`app_endpoints.dart:920`), `LoginUnauthorizedErrorHandler` (`auth_endpoints.dart:148`).
- [ ] **Boot servers in dependency order** — the token-issuing auth server before the app server that trusts its key; reserve a distinct path for the typed status (`/status`) vs the framework liveness probe (`/health`). → [10](README_advanced_10_servers_endpoints.md); sample `app_endpoints.dart:987` (`appHealth` at `/status`).

## Testing

- [ ] **Run Flutter suites serially** (`flutter test -j 1`). Parallel isolates corrupt the three process-global singletons (`TomTextResourceProvider` / `TomAuthorization` / `TomBearerAuthentication`). → [12](README_advanced_12_testing_integration.md); memory: tests-serial.
- [ ] **Test each layer against the seam directly below it**, never a live socket — inject an in-memory backend (`AppBackend` / `AdminBackend`) mirroring the server's ownership + four-state model. → [12](README_advanced_12_testing_integration.md); sample `in_memory_app_backend.dart`.
- [ ] **Assert texts with the `[srv]` sentinel and grades with the four-role matrix** (TC-30-01…04). Same widget, four principals, four renderings purely from the installed matrix. → [12](README_advanced_12_testing_integration.md); sample `item_detail_screen_test.dart`.
- [ ] **Exercise the real stack once, end-to-end**, with a scripted runner that boots both DBs + servers and skips-as-failure when unreachable. → [12](README_advanced_12_testing_integration.md); sample `run_cross_tier_integration.sh`, `cross_tier_integration_test.dart` (TC-37-01).
- [ ] **The green gate is all three together:** `dart analyze` clean + every suite green (serial) + the cross-tier runner exits `0`. → `advanced_example_completion.md`.

## Using the checklist

For a *new* app: start at H1/H2, then walk top to bottom. A rule you cannot point
at an anchor for is a rule your app is not yet honouring — open the linked spine
part for the worked example, and copy the named sample site. The order is the
build order the spine follows: domain & reflection → persistence → servers →
resources → authorization → forms → tests.

## Primary sources

- `readme_creation_plan.md` §1 (the two rules the realignment made literal); `advanced_examples_alignment_plan.md` (D-A1…D-A9)
- All spine docs [00](README_advanced_00_introduction.md)–[12](README_advanced_12_testing_integration.md); appendices [A1](README_advanced_A1_authorization_state_machine.md)/[A2](README_advanced_A2_resource_scope_conventions.md)/[A3](README_advanced_A3_request_lifecycle.md)
- Framework anchors: `tom_flutter_ui` `tom_form.dart:807`/`:855`; `tom_core_server` endpoint pipeline + `@TomRoleAccess`
- `advanced_example_completion.md` — the green gate

---

← Prev: [A3 · A secured request, end to end](README_advanced_A3_request_lifecycle.md) · Next: [A5 · Glossary & cross-reference](README_advanced_A5_glossary_crossref.md) →
