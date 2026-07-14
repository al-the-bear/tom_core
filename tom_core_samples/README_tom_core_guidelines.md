# Tom Core — Application Structure Guidelines

**Status:** Normative. These are *opinionated* guidelines: they leave you
freedom in **what** an application does, but not in **how** it is structured
technically. Two Tom applications built by two different teams should look the
same at the architectural level — same layering, same annotations, same
resource discipline, same authorization model. Deviations are defects, not
style choices.

**Scope:** Every `tom_core_*` sample in this folder (`core_*` and `advanced_*`)
is held to these rules. New Tom applications should adopt them wholesale.

**The closed-world premise.** The Tom framework is a *closed but complete*
world. Almost everything an enterprise application needs — dependency
injection, environment abstraction, reflection-based serialization, persistence,
migrations, endpoints, authentication, four-state authorization, resource
resolution, responsive UI, forms, actions — already exists inside `tom_core_*`
and `tom_flutter_ui`. Some pieces are optional (you need not use
`tom_flutter_ui` if you have no Flutter UI), **but if you use a piece, you use
it the Tom way.** Do not reach outside the framework for something the framework
already provides, and do not build a parallel mechanism beside a Tom one.

---

## 0. How to read this document

Each section states **rules** (numbered `G-<area>-<n>`), each rule is a single
enforceable statement. Where a rule points at framework code, the anchor is
given as `package/path.dart:line` so you can verify the contract against the
source. Anchors are workspace-relative from `tom_ai/core/` unless another root
is named.

Rules use RFC-2119 force: **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**.
A **SHOULD** may be broken only with a `// Why:` comment at the break site.

---

## 1. Project layout & dependency direction

A full-stack Tom application is a set of small packages with a strict,
acyclic dependency graph. The canonical shape is:

```
  domain          (reflected entities — the model)
    ▲
  contracts       (wire DTOs + typed API/endpoint declarations + access policy)
    ▲                     ▲
  client_core     server packages (auth_server, app_server)
    ▲
  flutter clients (app_client, admin_client)
```

**Rules**

- **G-LAYOUT-1** — Each deployable tier and each shared concern is its **own
  package**. Minimum set for a secured full-stack app: `*_domain`,
  `*_contracts`, `*_client_core` (Flutter-free), one package per server, one
  package per Flutter client.
- **G-LAYOUT-2** — Dependency arrows point **from higher tier to lower tier
  only**. Domain imports nothing from the app; contracts import only domain +
  `tom_core_kernel`; servers and clients import contracts; no cycles.
- **G-LAYOUT-3** — The **contracts** package MUST depend only on
  `tom_core_kernel` (never Flutter, never a server package, never `dart:io`).
  It is the shared wire vocabulary; keeping it dependency-minimal is what lets
  both a server and a web client link it.
- **G-LAYOUT-4** — Flutter-free client logic (HTTP, token handling, backend
  interface) lives in `*_client_core`; only widget code lives in the Flutter
  client packages. This keeps the authenticated client testable without a
  Flutter binding.

---

## 2. Dependency injection (`TomBean` / `TomBeanLocator`)

Anchor: `tom_core_kernel/lib/src/tombase/beanlocator/bean_locator.dart`
(`withName:253`, `withType:286`, `get:350`).

**Rules**

- **G-DI-1** — All cross-cutting collaborators (services, backends, adapters,
  clients) MUST be obtained through the bean locator, never constructed inline
  at the call site. A consumer asks `TomBean<Interface>().get()`; it does not
  `new` a concrete class.
- **G-DI-2** — Register implementations by the **interface** they satisfy, using
  `@TomComponent(Interface)` / `@tomComponent`. Consumers depend on the
  interface type, not the concrete type.
- **G-DI-3** — **Swap implementations by environment/platform, not by
  branching.** A test double, an in-memory backend, or a platform-specific
  adapter is registered as an alternative bean selected by an environment or
  platform selector (`@environmentDev`, `@environmentProd`, `@platformMacos`,
  …). Application code MUST NOT contain `if (testMode) … else …` to choose a
  collaborator — selection is the locator's job.
- **G-DI-4** — Configuration values are injected as typed config beans
  (`TomStringConfig` / `TomIntConfig` / `TomBoolConfig`), not read ad-hoc from
  the environment at random call sites. Every tunable is explicit and overridable
  in tests.
- **G-DI-5** — There is **one** installed implementation per concern in
  production, selected by DI. MUST NOT build a registry/dispatcher layer that
  chooses among many implementations at runtime — the locator already selects.

---

## 3. Environment & platform abstraction

Anchors: `tom_basics/lib/src/runtime/platform_environment_runtime.dart`,
`platform_neutral.dart` (`TomRuntime`).

**Rules**

- **G-ENV-1** — Detect platform/host capabilities through `TomRuntime`, never
  through raw `dart:io` `Platform` checks scattered in app code.
- **G-ENV-2** — The **default run mode is "against real local servers."** A
  Flutter client started with no dart-defines MUST target the local servers.
  Do **not** require `--dart-define`s for the normal development loop.
- **G-ENV-3** — The **seeded in-memory backend** is selected **only** by an
  explicit `TEST_MODE` dart-define (`--dart-define=TEST_MODE=true`). In-memory
  fakes are a testing convenience, never a default reached by forgetting a flag.
  Server URLs come from config beans, not from `String.fromEnvironment` calls in
  `main()`.

---

## 4. Wire contracts & endpoint declarations

Anchors: endpoint annotations
`tom_core_server/lib/src/tomserver/endpoints/endpoint_annotation.dart`; pipeline
`endpoint_pipeline.dart:227` (path-param bind), `:277` (`jsonBodyData` merge).

The contract layer declares, once, the **external API** that binds client calls
to server implementations: a typed request type, a typed result type, an
endpoint id, its URI, and its access policy.

**Rules**

- **G-API-1** — Every server endpoint is declared in the contracts package as a
  typed API endpoint (`@TomApiEndpoint`) with a **typed request DTO and a typed
  result DTO**. The server binds an implementation with
  `@TomApiEndpointImplementation(apiId, endpointId)`; the client calls through
  the same declaration. There is no untyped `Map` endpoint.
- **G-API-2** — URL path parameters (`/items/{id}`) MUST be bound to typed
  request fields via a **`urlParameterMapping`** map on the `@TomApiEndpoint`
  annotation. The pipeline injects the mapped path params into `jsonBodyData`
  before `createInstanceFromJson`. A bare-`String` handler parameter is retained
  as **one documented example** only, not the norm.
- **G-API-3** — Per-endpoint **access policy is declared on the API
  declaration** in contracts and applied on the implementation by referencing it
  — e.g. `@appApi.listItemsAccess` used directly as an annotation on the
  implementation class. If not locally overridden, the declared policy is
  extracted on first call. The policy is not hand-re-stated inline on every
  handler.
- **G-API-4** — Role names are defined **once** as centralized constants and
  reused as annotations:
  ```dart
  const adminRole = 'admin';
  const adminAccess = TomRoleAccess([adminRole]);
  // …
  @adminAccess
  class AdminListUsers implements … {}
  ```
  No literal `TomRoleAccess(['admin'])` repeated across handlers.

---

## 5. DTOs & wire serialization (reflection-first)

Anchor: `@tomReflector` from the `tom_reflection` package; kernel JSON
round-trip via reflection.

**Rules**

- **G-DTO-1** — Every wire DTO MUST be `@tomReflectable` and rely on
  **reflection** for JSON serialization. All wire serialization goes through
  reflection unless there is a real technical need for a manual path.
- **G-DTO-2** — DTO members are **non-`final`** (reflection populates them);
  declare them as plain mutable fields.
- **G-DTO-3** — A DTO SHOULD have **no `toJson`/`fromJson` at all**. When one is
  genuinely required (a real technical reason — e.g. a legacy external wire
  shape), it MUST contain **no business or security logic**. It is a shape
  adapter, nothing more.
- **G-DTO-4** — If a member's name cannot match the wire/field name, **adapt the
  member or the field**, do not introduce a manual serializer to bridge the gap.
  A manual override exists (`TomJsonSerializable`) as an escape hatch; it is not
  the design default.
- **G-DTO-5** — DTOs carry data only. No client drafting logic, no server
  authorization logic inside a DTO.

---

## 6. Reflection strategy & generation

Anchors: generator `tom_reflection_generator/bin/tom_reflection_generator.dart`,
`lib/src/v2/reflection_generator_executor.dart:122` (reads `buildkit.yaml`
then `build.yaml` `generate_for`).

**Rules**

- **G-REFL-1** — **Only real entry-points carry a self-reflection seed.** A
  package with a `main()` that bootstraps reflection at startup — the `*_server`
  and `*_client` packages — generates and imports its own reflection seed.
  Libraries do not.
- **G-REFL-2** — **Domain and contracts get reflection only for their tests**,
  through a single `test/run_all_tests.dart` that generates
  `run_all_test.reflection.dart`; every test imports that one seed. Do not
  scatter `reflection_entry.dart` seeds through library `lib/` folders.
- **G-REFL-3** — The reflection generator runs from `buildkit.yaml` /
  `build.yaml` configuration **with no extra flags**; regeneration scripts invoke
  it flag-free.
- **G-REFL-4** — Regenerate a seed **only when a reflected signature changes**
  (member added/removed/renamed/retyped, class added/removed). Never regenerate
  as routine hygiene.

---

## 7. Persistence & CRUD repositories

Anchors:
`tom_core_server/lib/src/tomserver/object_persistence/persistence_annotations.dart`,
`crud_repository.dart`; datasource
`.../datasources/mariadb_datasource.dart`.

**Rules**

- **G-DB-1** — Entities are persisted through the CRUD repository abstraction
  (`TomRepository<T,K>` / `MariadbRepository` / `TomSqlDatasourceRepository`),
  annotated with `@TomDbTable`, `@TomDbColumn`, `@TomEntityId`. No hand-written
  SQL string-building in application code.
- **G-DB-2** — All parameterised reads/writes MUST use **prepared statements**
  end-to-end through the repository.
- **G-DB-3** — The datasource binds the port as an **integer**; a port supplied
  as a string via config is parsed to an integer before binding. Application
  config may express the port either way.

---

## 8. Migrations

Anchor: `tom_core_server/lib/src/tomserver/db_migration/db_migration.dart`
(pattern `:140`, numeric sort `:168`). Filename pattern
`[<numericVersion>]-<description>.<ext>`; the initdb mount re-reads the same
tree; applied versions are skipped (idempotent).

**Rules**

- **G-MIG-1** — Migrations handle **creation, prefill, and upgrade** and are
  numbered with **consecutive integers**: `000`, `001`, `002`, …
- **G-MIG-2** — **Schema-definition** migrations are separated from
  **data/seed** migrations, typically alternating (schema, then its data, then
  next schema…). This is a readability aid, not a functional requirement of the
  engine.
- **G-MIG-3** — **Administrator-account seeding is separate from demo-account
  seeding.** An admin account is needed in production; demo accounts are
  demo-only. They MUST live in different migration files so a production deploy
  applies the admin seed without the demo users.
- **G-MIG-4** — **Environment-selective migrations are expressed by a filename
  tag**, not by application branching. A migration whose description carries a
  `@<env>[,<env>…]` suffix (e.g. `[003]-app_demo_seed@dev,test.sql`) applies
  **only** in the named environments; an untagged migration applies everywhere.
  The active environment is resolved from `TomRuntime` (never a raw `Platform`
  read, G-ENV-1), defaulting production-safe when uninitialized, so a production
  apply omits every `@dev`/`@test`-tagged seed while all schema (untagged)
  migrations still run. Anchor:
  `tom_core_server/.../db_migration/db_migration.dart:103`
  (`appliesInEnvironment`), `:222` (`resolveActiveEnvironment`). This is the
  mechanism that makes G-MIG-3's "production applies the admin seed without the
  demo users" enforceable — the admin seed is untagged, the demo seed is tagged.

---

## 9. Authentication, keys & token refresh

Anchor:
`tom_core_server/lib/src/tomserver/authentication/authentication_server.dart:209`.

**Rules**

- **G-AUTH-1** — Authentication is issued by `TomAuthenticationServer` (JWT
  authentication + authorization tokens). Both servers share one signing key.
- **G-AUTH-2** — Dev-key warnings **MUST print, not be suppressed**. The
  documentation MUST explain *why* (the key is a non-fresh, non-production
  development certificate) and *how* a real production certificate is installed.
- **G-AUTH-3** — Token **refresh/retry** is a **pluggable error-handling
  mechanism inside `tom_core_kernel`/`tom_core_flutter`**, transparent to
  application code. Application code never manually catches "401 → refresh →
  retry"; it is a kernel/flutter retry policy.

---

## 10. Authorization (four-state, DB-resolved)

Anchors: `TomAuthState` (`tom_core_kernel/.../security`); AclBuilder
`tom_flutter_ui/lib/src/advanced_container_layout/acl_builder.dart`
(`setAclDefaultHideUnauthorized:835`).

The authorization model is **four-state** — `none < disabled < read < full`
(`TomAuthState`) — resolved per (principal, resourceKey).

**Rules**

- **G-AUTHZ-1** — Authorization keys come **straight from the database** after
  resolving the principal's **roles and groups** against **explicit resource
  authorizations**. There is **no fallback chain**: a resource is either
  authorized (to some state) or it resolves to `none`.
- **G-AUTHZ-2** — Public fields are exposed via an **implicit guest login** or an
  **everyone-Authorizer**, not via a special-case bypass in application code.
- **G-AUTHZ-3** — **Shared resources use the same form with a different
  `formId`.** A shared todo is the same field definition addressed under a
  different scope/formId, not a duplicated form.
- **G-AUTHZ-4** — Server-side write enforcement is authoritative
  (`_enforceFieldWrites`); the client's `TomAuthState` only drives presentation.
  Never trust a client-side grant.
- **G-AUTHZ-5** — Authorization changes take effect on the **next JWT token
  refresh**. Because the token carries the resolved grants, a role/grant change
  reaches a session only when a fresh token is issued — which happens **either**
  on re-authentication (re-login) **or** on the automatic token refresh
  (G-AUTH-3). It does not reach a live session mid-token. Document this
  explicitly; it is by design.

---

## 11. Resources & user-facing text

Anchors: `tom_flutter_ui_test/lib/widget_demos/demo_21_resource_resolution.dart`
+ `demo_resources.dart`; `TomCtr`
`tom_flutter_ui/lib/src/widget_base/tom_construction_helpers.dart:22`; scope
`tom_core_kernel/lib/src/tombase/scope_ids/scope_ids.dart:24` (`withScope`).

**Rules**

- **G-RES-1** — **No hardcoded user-facing text anywhere** — not labels, not
  hints, not error messages, not titles, not dialog copy. Every visible string is
  a resource key resolved through `TomCtr` / the text-resource provider.
- **G-RES-2** — **Scopes are implicit** via `TomScope.withScope(id, body)`. A
  field's `basePath` = scopePath + `tomId`; a form's basePath = scopePath +
  `formId`. Scope names are not enumerated in a constants class.
- **G-RES-3** — A field defines its `tomId` **in its constructor** (a plain
  `String`). `form.field.tomId` and `basePath` addressing work directly — there
  is no mapping/duplication layer between member names and resource keys. A
  member name diverging from its `tomId` is normal and needs no special handling.
- **G-RES-4** — When a field name and a resource key disagree, **adapt the field
  name or the resource file** so they line up under the scope/basePath
  convention — never add an indirection map.
- **G-RES-5** — **Enum text representations are resource keys**, e.g.
  `global.todostatus.inreview`, resolved through the server-sent resource bundle
  via the resource-access API. Enums MUST NOT carry hardcoded display strings in
  Dart extensions.
- **G-RES-6** — Addressing is by scope + `tomId`/`formId`, resolved at use. MUST
  NOT create a class that catalogues resource keys as constants.

---

## 12. Forms, UI & responsive layout

Anchors: `TomForm`/`TomField`
`tom_flutter_ui/lib/src/forms/tom_form.dart:593` (field), `:23` (form),
error resolution `:868`; `ScreenElementsProvider`
`.../widget_base/tom_screen_elements_provider.dart:28`; AclBuilder
`.../advanced_container_layout/acl_builder.dart`; Tom base classes
`.../widget_base/tom_family_base.dart`, `tom_node_base.dart`.

**Rules**

- **G-UI-1** — If the app has a Flutter UI, **`tom_flutter_ui` provides ALL UI
  needs**. Raw Material/Cupertino widgets for app-level UI are not used where a
  Tom component exists.
- **G-UI-2** — **New UI components derive from the `Tom*` base classes**
  (`TomNodeBase` → `TomPolicyNodeBase` → `TomFamilyBase` → family bases) so they
  inherit authorization, scope, and resource behavior. A component that extends
  `StatelessWidget` directly, bypassing the hierarchy, is a defect.
- **G-UI-3** — Layout uses **`AclBuilder`**. Unauthorized components are
  **hidden** when `setAclDefaultHideUnauthorized()` is set (drops
  `TomAuthState.none` components). Application code does not manually check auth
  state to decide whether to render.
- **G-UI-4** — **Standard breakpoints** are supported and used: supply responsive
  values as `(minWidth, value)` tuples / `AclRowBreakpoint`
  (`acl_responsive.dart:19`). Do not hand-roll `MediaQuery` width branching.
- **G-UI-5** — A form separates **definition**, **implementation**, and
  **layout**. Fields are created in `createFormElements()` (called from the
  constructor). Fields need **not** be `late final` — plain fields typed by their
  **base field type** are correct. Non-form screen elements use a
  `ScreenElementsProvider`.
- **G-UI-6** — A form declares field ids **directly as `String`s** in
  `createFormElements()`; there is **no class defining tomIds**. A form's **scope
  is usually a Flutter route**.
- **G-UI-7** — **Field validators are declared as resources and resolved by
  name**, not hand-coded as one-off closures per field. A field's
  `<basePath>.validators` resource declaration is resolved through the DI-swappable
  `TomValidatorRegistry` (built-ins `required`/`email`/`minLength`/`maxLength`/
  `pattern`/`min`/`max`, plus app-registered ones via `register(name, factory)`);
  `TomField` merges code-supplied and resource-declared validators. Validation
  **error messages are resources** (G-RES-1), resolved through the scoped→global
  resource path — never a hardcoded message string. Anchor:
  `tom_flutter_ui/lib/src/forms/validation/validator_registry.dart:35`.

---

## 13. Actions framework

Anchor: `TomAction`
`tom_flutter_ui/lib/src/actions/tom_action.dart:29`; example
`.../actions/form_actions.dart:13`.

**Rules**

- **G-ACT-1** — User-triggered operations (save, share, delete, submit) are
  implemented as **`TomAction`s**, not as inline button callbacks with business
  logic.
- **G-ACT-2** — Actions carry their **own authorization** via the action
  framework: `canonicalPath = controllerId.actionId`, resolved through
  `TomAuthorization.resolveAuth(canonicalPath)`. Add action authorizations
  alongside resource authorizations.

---

## 14. Local run & testing

**Rules**

- **G-RUN-1** — The normal loop: start the local servers, run the Flutter client
  **with no dart-defines**, and it talks to those servers.
- **G-RUN-2** — Seeded in-memory operation is opt-in via `TEST_MODE`.
- **G-RUN-3** — Domain/contracts tests bootstrap reflection through the single
  `run_all_tests.dart` → `run_all_test.reflection.dart` seed.
- **G-RUN-4** — The end-to-end scenario (admin grant edit → end-user field
  matrix → project share → second user sees it) is exercised by a scripted runner
  that boots both DBs and both servers. Keep it green.

---

## 15. Documentation hygiene

**Rules**

- **G-DOC-1** — Documentation inside the `tom_core` repo (READMEs, guides) MUST
  **not reference any document or source outside the repo**. If information from
  an external doc is needed, **inline it**.
- **G-DOC-2** — Workspace/build documentation MUST NOT reference
  `tom_master.yaml`, `tom_workspace.yaml`, or `tom_project.yaml`.
- **G-DOC-3** — Docs describe the **current** design only — no
  backward-compatibility notes, no deprecated-state descriptions.
- **G-DOC-4** — Every architecture illustration is an **SVG** with (a) an HTML
  comment giving a textual description and (b) a text/mermaid equivalent
  alongside, so the diagram is legible to both humans and tools. Diagrams
  required in `README_advanced_01_architecture.md`: layering/dependency arrows;
  shared JWT signing key; the end-to-end request + grant-propagation loop
  (annotated that an authorization change applies on the next JWT refresh —
  re-login or automatic refresh); the
  overall architecture; the client-call ↔ API-definition ↔ service-impl ↔ routing
  relationship; the token refresh mechanism; the two round-trips of the request
  lifecycle.

---

## 16. External dependencies

- **G-DEP-1** — External dependencies MUST be **published pub.dev versions**,
  referenced by version constraint — never a `path:` override or
  `pubspec_overrides.yaml`. If a needed API is missing from a Tom package,
  publish it there first, then bump the constraint.

---

## Appendix A — Guideline-area anchor map

| Guideline area | Primary framework anchor |
| --- | --- |
| DI | `bean_locator.dart` |
| Environment / TEST_MODE | `platform_environment_runtime.dart` |
| Contracts / endpoints | `endpoint_annotation.dart`, `endpoint_pipeline.dart:277` |
| DTOs / reflection | `@tomReflector` |
| Reflection generation | `reflection_generator_executor.dart:122` |
| Persistence | `persistence_annotations.dart`, `mariadb_datasource.dart` |
| Migrations | `db_migration.dart:140` |
| Auth / keys / refresh | `authentication_server.dart:209` |
| Authorization | `TomAuthState`, `acl_builder.dart:835` |
| Resources / text | `demo_21_resource_resolution.dart`, `scope_ids.dart:24` |
| Forms / UI | `tom_form.dart:593`, `tom_family_base.dart` |
| Actions | `tom_action.dart:29` |

## Appendix B — Reference implementations to study

- **`tom_uam`** — a real application applying these guidelines:
  `tom_uam_codespec` (contract layer), `tom_uam_server`
  (`uam_persistence_model.dart`, `ae_internal_services.dart`), `tom_uam_client`
  (`application.dart`, `uam_graded_access_adapter.dart`).
- **`tom_flutter_ui_test`** — `demo_21_resource_resolution.dart` +
  `demo_resources.dart` for the resource/scope model.
- **`tom_flutter_form_test`** — form construction patterns.
- **`_doc/tom`** — `acl_design_specification.md`,
  `container_widget_resources_authorization.md`,
  `tom_flutter_ui_user_guide.md`, `tom_ui_design_architecture.md`,
  `tom_observable_state_management.md`.
- **`_doc/flutter`** — `flutter_dart_listener_patterns.md`.
