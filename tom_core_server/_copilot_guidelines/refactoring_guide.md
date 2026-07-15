# Tom Core Server — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_core_server**. The **reference target state** is
`tom_core_kernel` (clean code, full dartdoc, per-module documentation,
executable examples, comprehensive tests, generated `api.dart`). See
`tom_core_kernel/_copilot_guidelines/refactor_test_example_document_all.md`.

**Project type:** Dart server library (`publish_to: none`)
**Source location:** `lib/src/tomserver/`

---

## Target Modules

Located in `lib/src/tomserver/` (keep in sync with the folder):

| Module | Description |
| ------ | ----------- |
| `authentication/` | User authentication and identity |
| `authorization/` | Permission and access control |
| `cache/` | Server-side caching mechanisms |
| `cmdline/` | Command-line args and env-file handling |
| `configuration/` | Server configuration (base/tom config, YAML resources) |
| `datasources/` | Data source abstractions (MariaDB, SQL dialects) |
| `db_migration/` | Database migration utilities (MariaDB adapter) |
| `endpoints/` | HTTP endpoint annotations and pipeline |
| ~~`externalapis/`~~ | **Removed (OT3)** — empty placeholder, deleted (CHANGELOG 1.1.0) |
| `healthcheck/` | Health check endpoints |
| `little_things/` | Small utility functions |
| `object_persistence/` | ORM / CRUD repository, query builder, annotations |
| `server/` | Core server framework (diagnostics, forms, monitoring, websocket) |
| `transactions/` | Transaction handling |

> Placeholder modules with no implementation (e.g. an empty `externalapis/`)
> must be either implemented or removed during their step. Record the decision
> in `CHANGELOG.md`.

---

## Reference Projects

Consult these to understand intended usage before refactoring a module:

| Project | Purpose |
| ------- | ------- |
| `tom_uam_server` | Primary server application using tom_core_server |
| `tom_uam_shared` | Shared client/server code patterns |
| `tom_uam_client` | Client side (to understand client-server interaction) |

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

> **OT3 baseline pass done (2026-07-15).** Every bounded step passes its
> automated gate: `dart analyze` is clean and `testkit :test` is 422/422 green.
> The `externalapis/` placeholder module and four empty `server/` placeholder
> files (`diagnostics.dart`, `forms.dart`, `monitoring.dart`, `websocket.dart`)
> were already removed (CHANGELOG 1.1.0 §Removed). All 13 real modules each
> already received a full per-module pass — dartdoc + `doc/{module}.md` +
> executable example + test suite — and a final-review accuracy pass trued up
> the README. The open-ended **deepening** work — scaling test/example surface
> coverage and optional `doc/api/api_summary_{module}.md` files — is tracked as
> quest todo **RCE4** (the kernel reference has no `api.dart`/`doc/api` either).
>
> ✅ **RCE4 done (2026-07-15) — api-summary parity settled + verified.** The
> api-summary question is closed in favour of **symmetry**: all four core
> packages (`tom_core_kernel` per RCE2, this package via OT7, `tom_core_flutter`
> per OT6, `tom_core_d4rt` per OT8) carry a hand-written `doc/api_reference/`
> summary set (`doc/api/` is gitignored for generated HTML, so summaries live in
> `doc/api_reference/`). This package's 13 per-module summaries plus
> `api_summary_index.md` were verified present and accurate against source
> (healthcheck spot-checked exactly); `dart analyze` is clean and — no source or
> doc changed in this pass — the OT3 `testkit :test` 422/422 baseline stands. The
> open-ended depth half (scale example/test surface coverage to the full public
> API of each of the 13 modules) is a genuinely large, low-priority residual with
> no demonstrated defect, so it is tracked as quest todo **RCF4**
> (`rcf4-server-example-test-surface-scaling`) — same character as kernel's RCF1
> and flutter's RCF3 — rather than rushed into this doc-parity pass.

1. **Meta files.** ✅ **Done (OT3, 2026-07-15).** `README.md` (customized, 253
   lines), `CHANGELOG.md` (1.1.0), and `LICENSE` (BSD 3-Clause) all present and
   accurate. Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause — match the existing
   `LICENSE` wording) exist at the project root. Create any missing; customize
   the template `README.md`. *Done when all three exist and the README
   describes the package accurately.*
2. **Per-module pass — `authentication/`.** ✅ **Done (OT3).** Deepening → RCE4.
3. **Per-module pass — `authorization/`.** ✅ **Done (OT3).** Deepening → RCE4.
4. **Per-module pass — `cache/`.** ✅ **Done (OT3).** Deepening → RCE4.
5. **Per-module pass — `cmdline/`.** ✅ **Done (OT3).** Deepening → RCE4.
6. **Per-module pass — `configuration/`.** ✅ **Done (OT3).** Deepening → RCE4.
7. **Per-module pass — `datasources/`.** ✅ **Done (OT3).** Deepening → RCE4.
8. **Per-module pass — `db_migration/`.** ✅ **Done (OT3).** Deepening → RCE4.
9. **Per-module pass — `endpoints/`.** ✅ **Done (OT3).** Deepening → RCE4.
10. **Per-module pass — `externalapis/`.** ✅ **Done (OT3) — removed** (empty
    placeholder, see CHANGELOG 1.1.0 §Removed).
11. **Per-module pass — `healthcheck/`.** ✅ **Done (OT3).** Deepening → RCE4.
12. **Per-module pass — `little_things/`.** ✅ **Done (OT3).** Deepening → RCE4.
13. **Per-module pass — `object_persistence/`.** ✅ **Done (OT3).** Deepening → RCE4.
14. **Per-module pass — `server/`.** ✅ **Done (OT3).** Four empty placeholder
    files removed; `doc/server.md` records the "Not Yet Implemented" surface.
    Deepening → RCE4.
15. **Per-module pass — `transactions/`.** ✅ **Done (OT3).** Deepening → RCE4.
16. **Barrel exports & dead code.** ✅ **Done (OT3, 2026-07-15).** Barrel exports
    every module; `dart analyze` clean. Verify every public symbol is exported from
    `lib/`; remove unused declarations. *Done when `dart analyze` is clean.*
17. **Whole-package QA.** ✅ **Done (OT3, 2026-07-15).** `dart analyze` clean +
    `testkit :test` 422/422 green. Run `dart analyze` (zero warnings) and
    `testkit :test` (all green). Confirm reflection is initialized and
    `build.yaml` lists every file needing generation. *Done when analyzer and
    tests are clean.*
18. **Final review.** ✅ **Done (OT3, 2026-07-15).** Module docs re-read; README
    accuracy pass done (CHANGELOG 1.1.0 §Documentation); CHANGELOG updated.
    Re-read each module doc and `api.dart`; confirm docs only
    describe features that exist and cover all public API. Update `CHANGELOG.md`.

---

## Per-Module Workflow

For each module step, perform these sub-steps (do not change public behavior;
private additions allowed):

1. Read all files in the module; identify the public API surface.
2. Review real-world usage in `tom_uam_server`.
3. Refactor and document per
   [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md).
4. Quality check: no public API change; `dart analyze` clean.
5. Create module documentation in `doc/{module}.md` per
   [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md).
6. Create **executable** examples per
   [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) — server
   init, endpoint config, DB connection handling, auth flows.
7. Create tests per
   [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md); mock
   external services (databases, APIs); test success and error paths; consider
   concurrency.
8. Create / regenerate `api.dart` (or `doc/api/api_summary_{module}.md`) and
   verify it matches the code.
9. Verify documentation covers all public API and describes nothing that does
   not exist.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) |
| Examples | [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) |
