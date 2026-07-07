# Tom Flutter UI Test — Refactoring Plan (Application)

Project-specific workflow for cleaning up, documenting, and stabilizing
**tom_flutter_ui_test** — a standalone **Flutter demo / test application**, not a
library. The goal is **clean, well-explained application code** plus clear
documentation of *what the app demonstrates and how each demo works*. It is the
end-to-end exercise harness for `tom_flutter_ui` widgets, forms, and ACL
(resource authorization) behavior.

**Project type:** Flutter application (`publish_to: none`)
**Entrypoint:** `lib/main.dart`

---

## App Structure

| Folder / file | Role |
| ------------- | ---- |
| `widget_demos/` | Demos of the `tom_flutter_ui` widget catalogue |
| `forms_demos/` | Demos of the form widgets and bindings |
| `acl_demos/` | Demos of resource authorization / access control |
| `common/` | Shared scaffolding, theming, helpers |
| `demo_resources.dart` | Resource definitions used across demos |
| `locale_settings.dart` | Locale configuration for the demos |

Existing design notes in `doc/` (e.g. `widget_demo.md`,
`widget_resource_parameters.md`) feed the demo catalogue.

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

1. **Meta files.** Ensure `README.md` (summary + overview: what the app
   demonstrates, how to run it, what each demo group shows), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause) exist at the project root.
   `CHANGELOG.md` and `LICENSE` are **missing** — create both (copy the
   BSD 3-Clause `LICENSE` wording from a sibling project). *Done when all three
   exist and the README orients a new reader.*
2. **Entry + bootstrap clarity.** Review `main.dart`, `demo_resources.dart`, and
   `locale_settings.dart`; document the startup path and resource/locale setup
   with `// Why:` comments where non-obvious. *Done when the startup path is
   clear from the files.*
3. **Per-area clean-up — `common/`, resources, locale.** Apply clean-code
   principles; remove dead code and unused declarations. *Done when
   `dart analyze` is clean for these areas.*
4. **Per-area clean-up — `widget_demos/`, `forms_demos/`, `acl_demos/`.** Each
   demo should have a short doc comment naming the `tom_flutter_ui` feature it
   exercises. *Done when every demo names its target feature.*
5. **Demo catalogue doc.** In `doc/`, consolidate/refresh a catalogue mapping
   each demo to the widget/feature it validates and how to launch it (fold in
   the existing `doc/*.md` notes). *Done when the catalogue covers every demo.*
6. **Whole-app QA.** Run `dart analyze` (zero warnings) and `flutter test` (all
   green; never run Flutter test invocations in parallel — they corrupt
   results). *Done when analyzer and the existing test suite are clean.*
7. **Final review.** Confirm README/CHANGELOG/LICENSE are accurate; update
   `CHANGELOG.md` with a one-line summary of the cleanup pass.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) |
