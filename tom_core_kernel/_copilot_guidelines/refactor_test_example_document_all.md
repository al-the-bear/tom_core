# Tom Core Kernel — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_core_kernel**. This is the **reference package** for the Tom
Core repository: every other package-style project's refactoring plan targets
the state achieved here (clean code, full dartdoc, per-module documentation,
executable examples, comprehensive tests, generated `api.dart`).

**Project type:** Dart library (`publish_to: none`)
**Source location:** `lib/src/tombase/`

---

## Target Modules

Located in `lib/src/tombase/` (keep this list in sync with the folder — update
the plan whenever a module is added or removed):

| Module | Refactor? | Notes |
| ------ | --------- | ----- |
| `beanlocator/` | yes | Bean locator / dependency injection |
| `context/` | yes | Execution context management |
| `http_connection/` | yes | HTTP connection utilities |
| `isolate_pooling/` | yes | Isolate pool management |
| `json/` | yes | JSON helpers |
| `little_things/` | yes | Small cross-cutting utilities |
| `logging/` | yes | Logging (incl. isolate & remote logging) |
| `observable/` | **no** | Stable — do not refactor (see Prompt 1) |
| `reflection/` | **no** | Stable — do not refactor |
| `resources/` | yes | Resource providers |
| `scope_ids/` | yes | Scope identifier utilities |
| `security/` | yes | Auth, authorization, bearer auth, access control |
| `settings/` | yes | Settings management |
| `shutdown_cleanup/` | yes | Shutdown cleanup hooks |
| `timezoned/` | **no** | Stable — do not refactor |

Crypto lives in the separate `tom_crypto` dependency (not a module here).
The generated `version.versioner.dart` is tooling output — never hand-edit it.

---

## Concrete Step List

Iterate through these steps in order. Each step states its **done** condition.

1. **Meta files.** Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish list of recent changes), and `LICENSE` (BSD 3-Clause —
   copy the wording from the existing `LICENSE`) exist at the project root.
   Create any that are missing; customize a template `README.md`.
   *Done when all three exist and the README describes the package accurately.*
2. **Per-module pass — `beanlocator/`.** Run the Per-Module Workflow below.
3. **Per-module pass — `context/`.**
4. **Per-module pass — `http_connection/`.**
5. **Per-module pass — `isolate_pooling/`.**
6. **Per-module pass — `json/`.**
7. **Per-module pass — `little_things/`.**
8. **Per-module pass — `logging/`.**
9. **Per-module pass — `resources/`.**
10. **Per-module pass — `scope_ids/`.**
11. **Per-module pass — `security/`.**
12. **Per-module pass — `settings/`.**
13. **Per-module pass — `shutdown_cleanup/`.**
14. **Barrel exports.** Verify every public symbol of every module is exported
    from the package barrel(s) in `lib/`. *Done when `dart analyze` is clean and
    no public type is unreachable from the package entrypoint.*
15. **Whole-package QA.** Run `dart analyze` (zero warnings) and `testkit :test`
    (all green). Confirm reflection is initialized for examples/tests and that
    `build.yaml` lists every file needing generation. *Done when analyzer and
    test suite are both clean.*
16. **Final review.** Re-read each module doc and `api.dart`; confirm docs only
    describe features that exist and cover all public API. Update `CHANGELOG.md`
    with a one-line summary of the refactoring pass.

> Modules `observable/`, `reflection/`, and `timezoned/` are intentionally
> **excluded** from the per-module passes — they are stable. Document and test
> coverage for them is maintained, but their implementation is not refactored.

---

## Per-Module Workflow

For each module step above, perform these sub-steps (do not change public
behavior; you may add private members/methods):

1. Refactor and document the files per
   [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md).
   Do not add/remove/rename public methods, members, or accessors.
2. Create comprehensive **executable** examples per
   [`dart/examples.md`](/_copilot_guidelines/dart/examples.md). Scale the count
   to the surface area so every important aspect is demonstrated.
3. Create comprehensive tests per
   [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md). Scale the
   count to the surface area so every important aspect is covered.
4. Make examples and tests run. Add files to `build.yaml` for the reflection
   generator as needed; import and initialize reflection. Fix any bugs found.
5. Create the module documentation file per
   [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md),
   named after the folder (e.g. `doc/http_connection.md`). Length scales with
   complexity.
6. Create / regenerate the module `api.dart` per the API file rules. Delete any
   stale `api.dart` first.
7. Read the generated `api.dart` and verify it matches the code.
8. Verify documentation covers all public classes, methods, and members and
   describes nothing that does not exist. Extract code samples from the docs
   into an example file and confirm they run.

---

## Guidelines References

| Guideline | Location | Scope |
| --------- | -------- | ----- |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) | All Dart |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) | All Dart |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) | All projects |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) | All projects |
| Examples | [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) | All projects |
| API Summary | [`dart/api_summary_creation.md`](/_copilot_guidelines/dart/api_summary_creation.md) | All projects |
