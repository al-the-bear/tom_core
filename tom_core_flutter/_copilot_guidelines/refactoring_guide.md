# Tom Core Flutter — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_core_flutter**. The **reference target state** is
`tom_core_kernel` (clean code, full dartdoc, per-module documentation,
executable examples, comprehensive tests, generated `api.dart`). See
`tom_core_kernel/_copilot_guidelines/refactor_test_example_document_all.md`.

**Project type:** Flutter library (`publish_to: none`)
**Source location:** `lib/src/tomclient/`

---

## Target Modules

Located in `lib/src/tomclient/` (keep in sync with the folder):

| Module | Description |
| ------ | ----------- |
| `forms/` | Form handling and validation widgets |
| `little_things/` | Small utility widgets and helpers |
| `observing/` | Observable state patterns for Flutter |
| `resources/` | Resource loading and management |
| `runtime/` | Flutter runtime / platform detection |
| `security/` | Security utilities for mobile/web |

> Placeholder modules that contain only a `readme.md` (no implementation) must
> be either implemented or removed during their step — do not leave empty
> module folders. Record the decision in `CHANGELOG.md`.

---

## Reference Projects

Consult these to understand intended usage before refactoring a module:

| Project | Purpose |
| ------- | ------- |
| `tom_uam_client` | Primary Flutter client using tom_core_flutter |
| `tom_uam_shared` | Shared client/server code patterns |
| `tom_uam_server` | Server side (to understand client-server interaction) |

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

> **OT2 baseline pass done (2026-07-15).** Every bounded step passes its
> automated gate: `dart analyze` is clean and `flutter test --concurrency=1`
> is 59/59 green. The four placeholder modules (`camera/`, `localstorage/`,
> `preferences/`, `qrcode/`) and the empty `iding/` folder were already removed
> (recorded in `CHANGELOG.md` 1.1.0 — `preferences/` was rebuilt as a real
> module afterwards, see step 7), and all review-findings issues are
> resolved. The six real modules each already received a full per-module pass
> (dartdoc + `doc/{module}.md` + executable example + test suite). The
> open-ended **deepening** work — scaling test/example surface coverage and
> optional `doc/api/api_summary_{module}.md` files — is tracked as quest todo
> **RCE3** (the kernel reference has no `api.dart`/`doc/api` either).
>
> ✅ **RCE3 done (2026-07-15) — api-summary parity settled + verified.** The
> api-summary question is closed in favour of **symmetry**: all four core
> packages (`tom_core_kernel` per RCE2, `tom_core_server`, `tom_core_d4rt`, and
> this package via OT6) now carry a hand-written `doc/api_reference/` summary set
> (`doc/api/` is gitignored for generated HTML, so summaries live in
> `doc/api_reference/`). This package's six per-module summaries
> (`forms`, `little_things`, `observing`, `resources`, `runtime`, `security`)
> plus `api_summary_index.md` were re-verified accurate against current source;
> `dart analyze` is clean and the OT2 59/59 serial baseline stands unchanged.
> Two follow-ups were filed rather than rushed into a doc pass: **RCF2** —
> remove the explicitly-legacy `forms/` module (`TomFormOld`/`TomFieldOld` etc.,
> superseded by `tom_flutter_ui`'s widget-based `TomForm`) and migrate its only
> consumer `tom_uam_client` onto the `tom_flutter_ui` API (medium priority,
> architectural rewrite requiring a `tom_flutter_ui` dependency the client does
> not yet carry); and **RCF3** — scale example/test surface coverage for the
> five remaining modules (low priority, same depth character as kernel's RCF1).
>
> ✅ **RCF2 done (2026-09-02) — `forms/` removed, `tom_uam_client` migrated.**
> Both halves landed: `lib/src/tomclient/forms/` no longer exists, and
> `tom_uam/tom_uam_client` carries the `tom_flutter_ui` path dependency the
> follow-up said it did not yet have. The two facts check each other — the
> client analyzes clean (`flutter analyze`, "No issues found!") *while* the
> module it used to import is gone, which it could not do if the migration were
> partial. `TomFormOld` survives only as a dartdoc contrast in
> `tom_core_samples/advanced_authadmin_client/`, not as code. The package suite
> is **+326 / 0** (`flutter test --concurrency=1`, 2026-09-02); the `59/59`
> figures above are what OT2 ran on 15 July 2026 and stay as written. **RCF3**
> was not assessed in this pass — read its status from the todo, not from
> RCF2's closure.

1. **Meta files.** ✅ **Done (OT2, 2026-07-15).** `README.md` (customized,
   ~10 KB), `CHANGELOG.md` (1.1.0), and `LICENSE` (BSD 3-Clause) all present and
   accurate. Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause — match the existing
   `LICENSE` wording) exist at the project root. Create any missing; customize
   the template `README.md`. *Done when all three exist and the README
   describes the package accurately.*
2. **Per-module pass — `camera/`.** ✅ **Done (OT2) — removed** (placeholder,
   see CHANGELOG 1.1.0 §Removed).
3. **Per-module pass — `forms/`.** ✅ **Done (OT2) — since removed (RCF2,
   2026-09-02).** The legacy module (`TomFormOld`/`TomFieldOld`) is gone and its
   only consumer `tom_uam_client` now uses `tom_flutter_ui`'s widget-based
   `TomForm`. Nothing is pending here; see the RCF2 done-marker above.
4. **Per-module pass — `little_things/`.** ✅ **Done (OT2).** Deepening → RCE3.
5. **Per-module pass — `localstorage/`.** ✅ **Done (OT2) — removed** (placeholder).
6. **Per-module pass — `observing/`.** ✅ **Done (OT2).** Deepening → RCE3.
7. **Per-module pass — `preferences/`.** ✅ **Done (OT2) — removed** (placeholder).
   **Superseded (2026-08-03).** The directory holds a real module again: the
   device-preferences API and its framework client, with barrel exports,
   `doc/preferences.md`, an example and a test suite. What OT2 removed was a
   `readme.md` of research links, so both statements are true of different
   things — read the marker above as "the placeholder is gone", not as "there
   is no preferences module".
8. **Per-module pass — `qrcode/`.** ✅ **Done (OT2) — removed** (placeholder).
9. **Per-module pass — `resources/`.** ✅ **Done (OT2).** Deepening → RCE3.
10. **Per-module pass — `runtime/`.** ✅ **Done (OT2).** Deepening → RCE3.
11. **Per-module pass — `security/`.** ✅ **Done (OT2).** `security/authentication.dart`
    is exported from the package barrel.
12. **Barrel exports & dead code.** ✅ **Done (OT2, 2026-07-15).** Barrel exports
    all six modules incl. `authentication.dart`; the unused `_onChange` is gone;
    `dart analyze` clean. Verify every public symbol is exported from
    `lib/`; remove unused private declarations. *Done when `flutter analyze` is
    clean.*
13. **Whole-package QA.** ✅ **Done (OT2, 2026-07-15).** `dart analyze` clean +
    `flutter test --concurrency=1` 59/59 green; re-verified 2026-09-02 at
    `+326 / 0`. Run `flutter analyze` (zero warnings) and
    `flutter test --concurrency=1` (all green; never run Flutter test
    invocations in parallel). *Done when analyzer and tests are clean.*

    > **Use `flutter analyze`, not `dart analyze`.** The workspace
    > `analysis_options.yaml` enables lints (`unawaited_futures`,
    > `discarded_futures`) that the analyzer reports at `info` severity. Both
    > commands *print* those, but only `flutter analyze` exits non-zero on them —
    > measured in this package: with one planted `unawaited_futures` violation,
    > `flutter analyze` exits 1 and `dart analyze` exits 0. A `dart analyze`
    > gate therefore passes a tree with lint violations in it.
14. **Final review.** ✅ **Done (OT2, 2026-07-15).** Module docs re-read;
    `doc/review_findings.md` annotated as resolved; `CHANGELOG.md` updated.
    Re-read each module doc and `api.dart`; confirm docs only
    describe features that exist and cover all public API. Update `CHANGELOG.md`.

---

## Per-Module Workflow

For each module step, perform these sub-steps (do not change public behavior;
private additions allowed):

1. Read all files in the module; identify the public API surface.
2. Review real-world usage in `tom_uam_client`.
3. Refactor and document per
   [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md).
4. Quality check: no public API change; `flutter analyze` clean (see step 13 —
   `dart analyze` exits 0 on the `info`-severity lints this workspace enables).
5. Create module documentation in `doc/{module}.md` per
   [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md).
6. Create **executable** examples per
   [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) — widget
   integration, observable state, platform considerations.
7. Create tests per
   [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) using
   `flutter_test` / `WidgetTester`; mock platform channels where needed.
8. Create / regenerate `api.dart` (or `doc/api/api_summary_{module}.md`) and
   verify it matches the code.
9. Verify documentation covers all public API and describes nothing that does
   not exist.

---

## Project-Specific Notes

- **Flutter widget testing:** use `flutter_test` and `WidgetTester`; mock
  platform channels; test both Android and iOS behaviors where applicable.
- **Reflection:** import and initialize reflection in examples/tests; only
  regenerate on signature changes. This package has **no**
  `reflection_generation.sh` (nine sibling packages under `tom_ai/core` carry
  one) — regenerate with `dart run tom_reflection_generator` from the package
  root, which takes ~6 minutes. `build.yaml` restricts generation to three
  roots, which is why the companions sit beside them rather than under `lib/`:
  `test/security_test.reflection.dart`, `test/preferences_test.reflection.dart`
  and `example/reflection_seed.reflection.dart`.
  > Regenerating today rewrites all three (~400 k lines) because an upstream
  > Flutter import dropped out and every `prefixNN` alias shifts. The
  > checked-in companions are the ones the green suite was measured against, so
  > do not commit a regeneration as a side effect of unrelated work.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) |
| Examples | [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) |
