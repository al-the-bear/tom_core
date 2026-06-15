# Tom Core D4rt — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_core_d4rt** — the D4rt bridge library (and bundled `d4rt`
CLI) that exposes Tom Framework classes to sandboxed D4rt scripts. The
**reference target state** is `tom_core_kernel` (clean code, full dartdoc,
per-module documentation, examples, comprehensive tests, generated `api.dart`).
See `tom_core_kernel/_copilot_guidelines/refactor_test_example_document_all.md`.

**Project type:** Dart bridge library + CLI executable (`publish_to: none`)
**Source location:** `lib/src/` (one folder per bridged package)
**CLI entrypoint:** `bin/d4rt.dart`

For bridge mechanics and conventions, also follow the D4rt guidelines in
`/_copilot_guidelines/d4rt/` (especially `d4rt_bridgedclass_guidelines.md`) and
the local [testing.md](testing.md) (replay-based integration tests).

---

## Target Modules (bridge groups)

Located in `lib/src/` — each folder bridges one upstream package (keep in sync
with the folder):

| Module | Bridges |
| ------ | ------- |
| `cli/` | The `d4rt` CLI wiring and REPL bootstrap |
| `tom_basics/` | `tom_basics` classes |
| `tom_build/` | `tom_build` classes |
| `tom_core_kernel/` | `tom_core_kernel` modules |
| `tom_core_server/` | `tom_core_server` modules |
| `tom_dist_ledger/` | `tom_dist_ledger` classes |
| `tom_doc_scanner/` | `tom_doc_scanner` classes |
| `tom_doc_specs/` | `tom_doc_specs` classes |
| `tom_md2latex/` | `tom_md2latex` classes |
| `tom_md2pdf/` | `tom_md2pdf` classes |
| `tom_process_monitor/` | `tom_process_monitor` classes |
| `tom_reflection/` | `tom_reflection` classes |

> Bridge modules track their upstream package. When an upstream public API
> changes, regenerate / update the matching bridge module and its replay tests.

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

1. **Meta files.** Ensure `README.md` (summary + overview, incl. CLI usage),
   `CHANGELOG.md` (short, pre-publish), and `LICENSE` (proprietary) exist at the
   project root. All three are present — verify they are current. *Done when all
   three are present and accurate.*
2. **Per-module pass — `tom_basics/`.** Run the Per-Module Workflow below.
3. **Per-module pass — `tom_reflection/`.**
4. **Per-module pass — `tom_core_kernel/`.**
5. **Per-module pass — `tom_core_server/`.**
6. **Per-module pass — `tom_build/`.**
7. **Per-module pass — `tom_dist_ledger/`.**
8. **Per-module pass — `tom_process_monitor/`.**
9. **Per-module pass — `tom_doc_scanner/`.**
10. **Per-module pass — `tom_doc_specs/`.**
11. **Per-module pass — `tom_md2latex/`.**
12. **Per-module pass — `tom_md2pdf/`.**
13. **Per-module pass — `cli/`.** Refactor and document the CLI wiring; ensure
    `bin/d4rt.dart` is thin and delegates to `lib/src/cli/`.
14. **Registration & dedup.** Verify every bridged class is registered exactly
    once and the bridge resolver cache is invalidated on registration. *Done
    when `dart analyze` is clean and no duplicate-registration warnings appear.*
15. **Whole-package QA.** Run `dart analyze` (zero warnings) and the
    replay-based test suite per [testing.md](testing.md) (all green). *Done when
    analyzer and tests are clean.*
16. **Final review.** Re-read each module doc and the bridge API listing;
    confirm docs only describe bridges that exist and cover all registered
    classes. Update `CHANGELOG.md`.

---

## Per-Module Workflow

For each bridge module step, perform these sub-steps (do not change the bridged
public behavior; private additions allowed):

1. Read all files in the module; list the bridged classes/methods.
2. Compare against the upstream package's current public API; add/update bridges
   for any new or changed members.
3. Refactor and document per
   [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md)
   and the [d4rt bridge guidelines](/_copilot_guidelines/d4rt/d4rt_bridgedclass_guidelines.md).
4. Quality check: `dart analyze` clean; no duplicate registrations.
5. Create / update module documentation in `doc/{module}.md` per
   [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md).
6. Create **executable** D4rt script examples per
   [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) demonstrating the
   bridged API from a script.
7. Create / extend replay-based integration tests per [testing.md](testing.md).
8. Verify documentation lists every bridged class and describes nothing that is
   not actually registered.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| D4rt Bridged Classes | [`d4rt/d4rt_bridgedclass_guidelines.md`](/_copilot_guidelines/d4rt/d4rt_bridgedclass_guidelines.md) |
| Testing bridges (local) | [testing.md](testing.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Examples | [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) |
