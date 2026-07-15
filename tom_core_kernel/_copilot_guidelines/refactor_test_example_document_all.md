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

> **OT1 baseline pass done (2026-07-15).** Steps 1, 14, and 15 are complete —
> the package passes every automated gate (`dart analyze` clean, `testkit :test`
> 1636/1636 green). The per-module deep passes (Steps 2–13) are tracked as a
> resumable iteration under quest todo **RCE2** (one module per iteration); see
> `_ai/quests/tom_core/todos.tom_core.todo.yaml`.
>
> ✅ **RCE2 done (2026-07-15) — documentation half.** The Per-Module Workflow's
> API-documentation deliverable (sub-steps 6–8: the `api.dart`-equivalent
> reference + "docs cover all public API, describe nothing absent") is complete
> for all 15 barrel modules: `doc/api_reference/` now holds one verified
> per-module `api_summary_*.md` plus `api_summary_index.md` (kernel 1.1.1). The
> open-ended internal-refactor + example/test-surface scaling (sub-steps 1–4) is
> deferred as low-priority depth work under quest todo **RCF1**.
>
> ✅ **RCF1 first module done (2026-07-15) — `beanlocator/` sub-steps 1–4.** One
> bounded module iteration: a private-only DRY refactor of `bean_locator.dart`
> (four `_find*Match` methods → one `_findImplementation` chain + `_findSingleMatch`
> helper; public signatures frozen), example surface scaled (new
> `04_type_and_environment_registration_example.dart` covering the type/env-keyed
> API), test surface scaled (`beanlocator_test.dart` 29 → 40 tests, all documented
> exception keys asserted), and 4 latent example-assertion bugs fixed (surfaced by
> running examples under `dart run --enable-asserts`). `dart analyze` clean;
> `testkit :test` 1647/1647 (serial). The remaining 11 modules continue under quest
> todo **RCG1**.
>
> ✅ **RCG1 first module done (2026-07-15) — `security/` sub-steps 1–4.** One
> bounded iteration: private-only DRY refactor of `access_controls.dart`
> (`TomRoleAccess` + `TomGroupAccess` identical bodies → shared private
> `_principalAciContainsAny` helper; `TomEntitlementAccess` left separate as its
> regex rule is genuinely different; public signatures frozen), example surface
> scaled (new `04_graded_access_example.dart` covering the four-state
> `TomGradedAccess`/`TomAuthState` surface that had zero example coverage, wired
> into `00_run_all_examples.dart`), test surface scaled (`security_test.dart`
> 1647 → 1650, pinning the extracted helper's contract), and 1 latent
> example-assertion bug fixed in `02_access_control_example.dart` (stale
> assertions of a since-fixed group-constructor bug, surfaced under
> `--enable-asserts`). `dart analyze` clean; `testkit :test` 1650/1650 (serial).
> The remaining 10 modules continue under quest todo **RCH1**.
>
> ✅ **RCH1 first module done (2026-07-15) — `logging/` sub-steps 1–4.** One
> bounded iteration: private-only DRY refactor of `logging_isolate.dart`
> (`TomIsolateLogOutput.output` + `TomCreatorLogOutput.output` built the
> identical `TomInterIsolateLogMessage` record → shared private
> `_interIsolateMessage(...)` helper; the two dispatch bodies left separate as
> their routing/fallback is genuinely different; public signatures frozen) plus a
> stale `// TODO` in `TomRemoteLogOutput.output` replaced by an explanatory
> comment (retry/replay-queue resilience filed as **RCI2**). Example surface
> scaled (new `04_isolate_and_remote_logging_example.dart` covering the
> kernel-owned isolate/remote surface — inter-isolate record, executor, isolate
> & creator outputs with gating/fallback, worker context, remote message/result/
> context, remote output, and the remote server incl. CWE-117 sanitization —
> which had zero example coverage; wired into `00_run_all_examples.dart`, now
> async). Test surface scaled (`logging_test.dart` closed the
> `TomLoggingWorkerContext.initializeIsolate` gap; 1650 → 1652). `dart analyze`
> clean; every example self-asserts under `--enable-asserts`; `testkit :test`
> 1652/1652 (serial). The remaining 9 modules continue under quest todo **RCI1**.

1. **Meta files.** ✅ **Done (OT1, 2026-07-15).** `README.md` (customized, 252
   lines), `CHANGELOG.md` (1.1.0), and `LICENSE` (BSD 3-Clause) all present and
   accurate. Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish list of recent changes), and `LICENSE` (BSD 3-Clause —
   copy the wording from the existing `LICENSE`) exist at the project root.
   Create any that are missing; customize a template `README.md`.
   *Done when all three exist and the README describes the package accurately.*
2. **Per-module pass — `beanlocator/`.** ✅ **Sub-steps 1–4 done (RCF1, 2026-07-15).** Documentation half done under RCE2. Run the Per-Module Workflow below.
3. **Per-module pass — `context/`.** *(RCE2)*
4. **Per-module pass — `http_connection/`.** *(RCE2)*
5. **Per-module pass — `isolate_pooling/`.** *(RCE2)*
6. **Per-module pass — `json/`.** *(RCE2)*
7. **Per-module pass — `little_things/`.** *(RCE2)*
8. **Per-module pass — `logging/`.** ✅ **Sub-steps 1–4 done (RCH1, 2026-07-15).** Documentation half done under RCE2.
9. **Per-module pass — `resources/`.** *(RCE2)*
10. **Per-module pass — `scope_ids/`.** *(RCE2)*
11. **Per-module pass — `security/`.** ✅ **Sub-steps 1–4 done (RCG1, 2026-07-15).** Documentation half done under RCE2.
12. **Per-module pass — `settings/`.** *(RCE2)*
13. **Per-module pass — `shutdown_cleanup/`.** *(RCE2)*
14. **Barrel exports.** ✅ **Done (OT1, 2026-07-15).** `lib/tom_core_kernel.dart`
    exports all 15 modules (38 directives); analyzer clean ⇒ no unreachable public
    type. Verify every public symbol of every module is exported
    from the package barrel(s) in `lib/`. *Done when `dart analyze` is clean and
    no public type is unreachable from the package entrypoint.*
15. **Whole-package QA.** ✅ **Done (OT1, 2026-07-15).** `dart analyze` clean +
    `testkit :test` 1636/1636 green (serial). Run `dart analyze` (zero warnings)
    and `testkit :test` (all green). Confirm reflection is initialized for
    examples/tests and that `build.yaml` lists every file needing generation.
    *Done when analyzer and test suite are both clean.*
16. **Final review.** *(RCE2 — after the per-module passes.)* Re-read each module
    doc and `api.dart`; confirm docs only describe features that exist and cover
    all public API. Update `CHANGELOG.md` with a one-line summary of the pass.

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
