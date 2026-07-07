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
| `externalapis/` | External API integrations |
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

1. **Meta files.** Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause — match the existing
   `LICENSE` wording) exist at the project root. Create any missing; customize
   the template `README.md`. *Done when all three exist and the README
   describes the package accurately.*
2. **Per-module pass — `authentication/`.** Run the Per-Module Workflow below.
3. **Per-module pass — `authorization/`.**
4. **Per-module pass — `cache/`.**
5. **Per-module pass — `cmdline/`.**
6. **Per-module pass — `configuration/`.**
7. **Per-module pass — `datasources/`.**
8. **Per-module pass — `db_migration/`.**
9. **Per-module pass — `endpoints/`.**
10. **Per-module pass — `externalapis/`.** (Implement or remove if placeholder.)
11. **Per-module pass — `healthcheck/`.**
12. **Per-module pass — `little_things/`.**
13. **Per-module pass — `object_persistence/`.**
14. **Per-module pass — `server/`.**
15. **Per-module pass — `transactions/`.**
16. **Barrel exports & dead code.** Verify every public symbol is exported from
    `lib/`; remove unused declarations. *Done when `dart analyze` is clean.*
17. **Whole-package QA.** Run `dart analyze` (zero warnings) and `testkit :test`
    (all green). Confirm reflection is initialized and `build.yaml` lists every
    file needing generation. *Done when analyzer and tests are clean.*
18. **Final review.** Re-read each module doc and `api.dart`; confirm docs only
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
