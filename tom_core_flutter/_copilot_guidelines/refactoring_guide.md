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
| `preferences/` | User preferences management |
| `qrcode/` | QR code generation and scanning |
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

1. **Meta files.** Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (proprietary — match the existing
   `LICENSE` wording) exist at the project root. Create any missing; customize
   the template `README.md`. *Done when all three exist and the README
   describes the package accurately.*
2. **Per-module pass — `camera/`.** Run the Per-Module Workflow below
   (implement or remove if placeholder).
3. **Per-module pass — `forms/`.**
4. **Per-module pass — `little_things/`.**
5. **Per-module pass — `localstorage/`.** (Implement or remove if placeholder.)
6. **Per-module pass — `observing/`.**
7. **Per-module pass — `preferences/`.** (Implement or remove if placeholder.)
8. **Per-module pass — `qrcode/`.** (Implement or remove if placeholder.)
9. **Per-module pass — `resources/`.**
10. **Per-module pass — `runtime/`.**
11. **Per-module pass — `security/`.** Verify `security/authentication.dart` is
    exported from the package barrel.
12. **Barrel exports & dead code.** Verify every public symbol is exported from
    `lib/`; remove unused private declarations. *Done when `dart analyze` is
    clean.*
13. **Whole-package QA.** Run `dart analyze` (zero warnings) and `flutter test`
    (all green; never run Flutter test invocations in parallel). *Done when
    analyzer and tests are clean.*
14. **Final review.** Re-read each module doc and `api.dart`; confirm docs only
    describe features that exist and cover all public API. Update `CHANGELOG.md`.

---

## Per-Module Workflow

For each module step, perform these sub-steps (do not change public behavior;
private additions allowed):

1. Read all files in the module; identify the public API surface.
2. Review real-world usage in `tom_uam_client`.
3. Refactor and document per
   [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md).
4. Quality check: no public API change; `dart analyze` clean.
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
  regenerate reflection on signature changes (use the project's
  `reflection_generation.sh`).

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) |
| Examples | [`dart/examples.md`](/_copilot_guidelines/dart/examples.md) |
