# Appendix A5 · Glossary & cross-reference

*Appendix A5 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

This closing appendix is the guide's **lookup table**. It gathers in one place
(1) the vocabulary the spine builds up section by section — so a term you meet
mid-guide has a single definition you can jump back to — and (2) two
cross-reference maps: from each **package README** to the guide section that
explains it, and from each **planning document** that drove the sample to the
sections that carry its content. Nothing here is new; every entry points at the
spine part or appendix that establishes it. If you read the guide front to back
you will have met all of it — this appendix just lets you re-find it.

## Glossary

Alphabetical. The **Established in** column is the canonical place the term is
defined; a `file:line` anchor is the enforcement or usage point as of this
writing (the symbol in the same cell still locates it if a line drifts).

| Term | Meaning | Established in |
| --- | --- | --- |
| **adapter** (authorization adapter) | The single `FieldStateAuthorizationAdapter` installed once at startup (`TomAuthorization.adapter = …`) that resolves each field's four-state grade from its `basePath` against the current item's grade matrix. The form holds no auth state of its own. | [07](README_advanced_07_authorization.md), [A1](README_advanced_A1_authorization_state_machine.md); `main.dart:42`, `app_session.dart:160` |
| **basePath** | A field's identity string, `<scopePath>.<formId>.<tomId>`. It is **both** the authorization grade key (bare path) and the prefix for its text keys (path + suffix). One name configures display *and* access. | [A2](README_advanced_A2_resource_scope_conventions.md); `tom_form.dart:146`/`:614-617` |
| **bearer / JWT pair** | The access + refresh JSON Web Token pair the auth server mints at login (2 h access lifetime). The client presents the access token as an HTTP bearer on every app-server request; the app server validates it offline against the shared signing key. | [06](README_advanced_06_authentication.md), [A3](README_advanced_A3_request_lifecycle.md); `auth_endpoints.dart:95-121` |
| **bundle** (resource bundle) | A server-delivered map of `basePath.suffix → text` (`ResourceBundleDto`), installed via `TomTextResourceProvider.setAppResourceProvider`. A small **pre-login** bundle (public `loginResources`) installs first; the **full** bundle replaces it after sign-in. | [08](README_advanced_08_resources_texts.md); `app_session.dart:108`, `app_endpoints.dart:1074` |
| **closed-safe default** | The rule that an unknown or absent grade resolves to `TomAuthState.none` (hidden), enforced independently at three points: the wire codec (`GradedFieldDto.fromJson`), the server resolver, and the client adapter. Failure of any layer hides a field rather than exposing it. | [A1](README_advanced_A1_authorization_state_machine.md), D-A4; `field_grade_resolver.dart:73-80` |
| **cross-tier integration runner** | `run_cross_tier_integration.sh` — the scripted end-to-end harness that boots both MariaDB databases and both servers, runs `cross_tier_integration_test.dart` (TC-37-01), and treats unreachable services as failure (not skip). | [12](README_advanced_12_testing_integration.md) |
| **datasource** (`main` binding) | A per-logical-DB connection configured in YAML. The app server binds the framework's `main` datasource to `auth_db` so it can read the shared grant table; cross-DB references are *logical* (no cross-DB foreign keys). | [05](README_advanced_05_persistence_database.md); `field_grade_resolver.dart:30-39` |
| **field grade** | A field's per-principal authorization state — one `TomAuthState` value. Computed server-side by `FieldGradeResolver.resolveItemFieldStates(role)` from the role's grant row. | [07](README_advanced_07_authorization.md), [A1](README_advanced_A1_authorization_state_machine.md); `field_grade_resolver.dart:73-80` |
| **formId** | A form's identifier and the middle segment of every field `basePath`. For an **unscoped** form (e.g. `LoginForm`, `formId: 'login'`) the `formId` *is* the base path root → `login.username`. | [A2](README_advanced_A2_resource_scope_conventions.md) |
| **four-state** (`TomAuthState`) | The four-value enum declared most-to-least restrictive: `none < disabled < read < full`. It maps a field to a control by resolved state alone — `none` collapses (hidden), `disabled` greys, `read` shows read-only, `full` makes editable. | [A1](README_advanced_A1_authorization_state_machine.md) |
| **graded DTO** (`GradedFieldDto`) | The wire shape carrying one field's value together with its grade. Its `fromJson` applies the closed-safe `none` default for unknown grades, so a tampered or partial payload fails closed. | [04](README_advanced_04_wire_contracts_dtos.md), [A3](README_advanced_A3_request_lifecycle.md); `app_api_client.dart:145` |
| **grant matrix / grant** | The `tom_resource_grant` rows mapping a role to its per-field grades, folded into a `TomGradedAccessControlInformation` via `fromGrants`. The single source of truth for field grades; stored in `auth_db`, read cross-DB by the app server. | [07](README_advanced_07_authorization.md); `field_grade_resolver.dart:65` |
| **green gate** | The completion bar: `dart analyze` clean **and** every test suite green (run serially) **and** the cross-tier runner exits `0`. All three together — not any one alone. | [12](README_advanced_12_testing_integration.md); `advanced_example_completion.md` |
| **principal** (zone principal) | The authenticated identity (`TomPrincipal`) for a request. The **server** reads it from the request zone, `getFromCurrentZone<TomPrincipal>()` — never the client-side `TomBearerAuthentication` singleton, which is not request-scoped. | [A3](README_advanced_A3_request_lifecycle.md); `app_endpoints.dart:981`, `auth_endpoints.dart:206` |
| **reflection seed** | The one `reflection_seed.dart` per package whose `main()` touch-imports the reflected types; the generated `reflection_seed.reflection.dart` is the build output. Regenerated only on signature changes, via the package's `reflection_generation.sh`. | [02](README_advanced_02_project_layout_build.md), [03](README_advanced_03_domain_reflection.md) |
| **resource / text resource** | An externalized UI string keyed by `basePath` + suffix (`.label` / `.hint` / `.error.<code>`). No widget carries a hard-coded label/hint/error; each resolves from the installed bundle. | [08](README_advanced_08_resources_texts.md); `tom_form.dart:855` |
| **role** (`ProjectRole`) | The ownership-or-share access level a principal has on a resource (owner / editor / viewer / commenter). Resolved by `ResourceAccessResolver.resolveRole` by walking item→list→project→workspace ancestry; `null` means no access (→ 404). | [07](README_advanced_07_authorization.md); `resource_access_resolver.dart:115` |
| **scope / scopePath** | The namespace pushed at the *call site* (`TomScope.withScope('todo', TodoItemForm.new)`) so a scoped form's field paths equal the server's grade keys. Constructing a scoped form unscoped silently breaks every grade/text lookup (renders empty, no throw). | [A2](README_advanced_A2_resource_scope_conventions.md), D-RC17-b; `item_detail_screen.dart:88` |
| **`[srv]` sentinel** | A test technique: install a bundle whose every value carries a `[srv]` suffix and assert the suffixed strings render. A hard-coded label would not carry the suffix and so fails the test — proving texts are server-delivered. | [12](README_advanced_12_testing_integration.md) |
| **tomId** | A field's local id within its form — the leaf segment of `basePath`. Independent of the reflected *member* name used by `bind`/`save` (the deliberate `estimate` ↔ `estimateHours` divergence proves the decoupling). | [A2](README_advanced_A2_resource_scope_conventions.md); `todo_item_form.dart:85` |

## Cross-reference: package README → guide section

Each of the seven `advanced_*` packages has its own `README.md` describing that
package in isolation. The guide section in the right column is where the package
is explained *in the context of the whole system*.

| Package README | Summarized in |
| --- | --- |
| [`advanced_todo_domain`](advanced_todo_domain/README.md) | [03 · Domain model & reflection](README_advanced_03_domain_reflection.md) |
| [`advanced_todo_contracts`](advanced_todo_contracts/README.md) | [04 · Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) |
| [`advanced_client_core`](advanced_client_core/README.md) | [06 · Authentication](README_advanced_06_authentication.md) |
| [`advanced_auth_server`](advanced_auth_server/README.md) | [06 · Authentication](README_advanced_06_authentication.md) / [10 · Servers & endpoints](README_advanced_10_servers_endpoints.md) |
| [`advanced_app_server`](advanced_app_server/README.md) | [05 · Persistence & database](README_advanced_05_persistence_database.md) / [10 · Servers & endpoints](README_advanced_10_servers_endpoints.md) |
| [`advanced_app_client`](advanced_app_client/README.md) | [09 · Forms & UI](README_advanced_09_forms_ui.md) / [11 · The two Flutter clients](README_advanced_11_clients_app_admin.md) |
| [`advanced_authadmin_client`](advanced_authadmin_client/README.md) | [09 · Forms & UI](README_advanced_09_forms_ui.md) / [11 · The two Flutter clients](README_advanced_11_clients_app_admin.md) |

## Cross-reference: planning doc → guide section

The sample was built from four **planning documents** in the `tom_core` quest
folder (`_ai/quests/tom_core/`). They are internal build-planning artifacts — not
shipped with the sample, hence named here rather than linked — but if you want
the original rationale behind a guide section, this is where it came from. The
mapping is the source-coverage matrix from RC-1 (`readme_creation_plan_decisions.md`
§"RC-1", in the same quest folder).

| Planning doc | Primary sections | Secondary sections |
| --- | --- | --- |
| `advanced_example_specification_plan.md` (SPEC-*) | [01](README_advanced_01_architecture.md), [02](README_advanced_02_project_layout_build.md), [03](README_advanced_03_domain_reflection.md), [04](README_advanced_04_wire_contracts_dtos.md), [05](README_advanced_05_persistence_database.md), [06](README_advanced_06_authentication.md), [10](README_advanced_10_servers_endpoints.md) | [00](README_advanced_00_introduction.md), [07](README_advanced_07_authorization.md), [09](README_advanced_09_forms_ui.md), [11](README_advanced_11_clients_app_admin.md), [12](README_advanced_12_testing_integration.md), [A3](README_advanced_A3_request_lifecycle.md) |
| `advanced_examples_alignment_plan.md` (ALIGN-*) | [07](README_advanced_07_authorization.md), [08](README_advanced_08_resources_texts.md), [09](README_advanced_09_forms_ui.md) | [A1](README_advanced_A1_authorization_state_machine.md), [A2](README_advanced_A2_resource_scope_conventions.md), [A4](README_advanced_A4_implementation_rules_checklist.md) |
| `advanced_examples_alignment_plan_decisions.md` (ALDEC-*) | [07](README_advanced_07_authorization.md), [08](README_advanced_08_resources_texts.md), [A1](README_advanced_A1_authorization_state_machine.md), [A2](README_advanced_A2_resource_scope_conventions.md) | [09](README_advanced_09_forms_ui.md), [12](README_advanced_12_testing_integration.md), [A4](README_advanced_A4_implementation_rules_checklist.md) |
| `advanced_example_completion.md` (COMP-*) | [12](README_advanced_12_testing_integration.md), [A4](README_advanced_A4_implementation_rules_checklist.md) | [07](README_advanced_07_authorization.md), [08](README_advanced_08_resources_texts.md), [09](README_advanced_09_forms_ui.md), [11](README_advanced_11_clients_app_admin.md) |

## Primary sources

- All seven package `README.md` files (the per-package descriptions)
- The four planning docs in `_ai/quests/tom_core/`: `advanced_example_specification_plan.md`, `advanced_examples_alignment_plan.md`, `advanced_examples_alignment_plan_decisions.md`, `advanced_example_completion.md`
- The RC-1 source-coverage matrix in `readme_creation_plan_decisions.md`
- The spine docs [00](README_advanced_00_introduction.md)–[12](README_advanced_12_testing_integration.md) and appendices [A1](README_advanced_A1_authorization_state_machine.md)–[A4](README_advanced_A4_implementation_rules_checklist.md) (each term's defining section)

---

← Prev: [A4 · Implementation-rules cheat-sheet](README_advanced_A4_implementation_rules_checklist.md) · Next: [Guide index](README_advanced_sample.md#user-guide) →
