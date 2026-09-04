# Tom Flutter UI — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_flutter_ui**. The **reference target state** is
`tom_core_kernel` (clean code, full dartdoc, per-module documentation,
executable examples, comprehensive tests, generated `api.dart`). See
`tom_core_kernel/_copilot_guidelines/refactor_test_example_document_all.md`.

**Project type:** Flutter package / widget library (`publish_to: none`)
**Source location:** `lib/src/`
**Description:** Reusable, customizable Flutter business UI components with
semantic-layout separation and observable state integration.

---

## Target Modules

Located in `lib/src/` (keep in sync with the folder):

| Module | Description |
| ------ | ----------- |
| `actions/` | Tom action integration for widgets |
| `advanced_container_layout/` | Advanced container/layout primitives |
| `custom/` | Custom one-off widgets |
| `forms/` | Form widgets, field bindings, authorizers |
| `groups/` | Widget grouping primitives |
| `resource_auth/` | Resource-driven authorization for widgets |
| `theme/` | Theme and FormStyle support |
| `widget_base/` | Base widget classes / mixins |
| `widgets/` | The widget catalogue (fields, containers, etc.) |

Existing design notes live in `doc/` (e.g. `form_authorizers.md`,
`formstyle_migration.md`) — reuse them as module documentation sources.

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

1. **Meta files.** Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause) exist at the project root.
   All three are present — verify they are current; bump the `version` and
   update the README catalogue if the widget set changed. *Done when all three
   are present and accurate.*
2. **Per-module pass — `widget_base/`.** Run the Per-Module Workflow below
   (do this first — other modules build on it).
3. **Per-module pass — `theme/`.**
4. **Per-module pass — `actions/`.**
5. **Per-module pass — `resource_auth/`.**
6. **Per-module pass — `forms/`.**
7. **Per-module pass — `groups/`.**
8. **Per-module pass — `advanced_container_layout/`.**
9. **Per-module pass — `widgets/`.**
10. **Per-module pass — `custom/`.**
11. **Barrel exports & dead code.** Verify every public widget/symbol is
    exported from the package barrel in `lib/`; remove unused declarations.
    *Done when `flutter analyze` is clean.*
12. **Examples app.** Ensure `example/` contains a runnable demo covering the
    main widgets (extend `gallery_demo.dart`). *Done when the example runs.*
13. **Whole-package QA.** Run `flutter analyze` (zero warnings) and `flutter test`
    (all green; never run Flutter test invocations in parallel). *Done when
    analyzer and tests are clean.*
14. **Final review.** Re-read each module doc and `api.dart`; confirm docs only
    describe widgets that exist and cover all public API. Update `CHANGELOG.md`.

---

## Per-Module Workflow

For each module step, perform these sub-steps (do not change public behavior;
private additions allowed):

1. Read all files in the module; identify the public widget/API surface.
2. Refactor and document per
   [`dart/coding_guidelines.md`](../../../../_copilot_guidelines/dart/coding_guidelines.md);
   keep semantic layout separated from presentation.
3. Quality check: no public API change; `flutter analyze` clean.
4. Create / update module documentation in `doc/{module}.md` per
   [`documentation_guidelines.md`](../../../../_copilot_guidelines/documentation_guidelines.md).
5. Create **executable** examples (widget demos) per
   [`dart/examples.md`](../../../../_copilot_guidelines/dart/examples.md).
6. Create / extend widget tests per
   [`dart/unit_tests.md`](../../../../_copilot_guidelines/dart/unit_tests.md) using
   `flutter_test` / `WidgetTester`.
7. Create / regenerate `api.dart` (or `doc/api/api_summary_{module}.md`) and
   verify it matches the code.
8. Verify documentation covers all public API and describes nothing that does
   not exist.

---

## Project-Specific Notes

- **Import convention — always the package barrel.** Tests and examples import
  `package:tom_flutter_ui/tom_flutter_ui.dart`, never
  `package:tom_flutter_ui/src/...`. That barrel is the only path the
  documentation offers a consumer, so it is the only path that verifies what a
  consumer actually gets: a symbol dropped from a module barrel has to fail the
  suite rather than surface downstream. It also makes a `tom_core_kernel`
  import redundant in most files, because the barrel re-exports the kernel
  types through `kernel_types`.

  Reaching into `src/` is therefore a deliberate signal that a test is
  white-box, and needs an entry in the `exempt` map in
  `test/package_barrel_test.dart` giving the reason. There is one today. Never
  widen the public API purely so a test can import differently — if the barrel
  cannot express what the file needs, that is what the exemption is for.
  `test/package_barrel_test.dart` enforces all of this, over `test/` and
  `example/` alike, for `export` as well as `import`.

  The exemption licenses the *imports the reason covers*, not the file. An
  exempt file may still only reach libraries the barrel does not export; the
  suite re-derives that from the export chain rather than taking the list's
  word for it, so an exported library imported by path fails even from an
  exempt file.
- **Observable integration:** widgets bind to observable state; demonstrate the
  ValueListenable / observer patterns in examples.
- **Reflection:** only regenerate reflection on signature changes; use the
  project's reflection generation script.
- **Companion test apps:** `tom_flutter_ui_test` and `tom_flutter_form_test`
  exercise this library end-to-end — keep them green when changing public API.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Coding Guidelines | [`dart/coding_guidelines.md`](../../../../_copilot_guidelines/dart/coding_guidelines.md) |
| Clean Code | [`dart/clean_code_principles.md`](../../../../_copilot_guidelines/dart/clean_code_principles.md) |
| Documentation | [`documentation_guidelines.md`](../../../../_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](../../../../_copilot_guidelines/dart/unit_tests.md) |
| Examples | [`dart/examples.md`](../../../../_copilot_guidelines/dart/examples.md) |
